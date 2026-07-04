import { useState } from 'react';
import type { Client, DaemonErrorShape } from '../lib/protocol';
import { errorShape } from '../lib/protocol';
import { ErrorNote, HexMark } from './ui';

/** No identity yet → create one. No rooms yet → create or join by ticket.
 *  Mirrors identity.create / room.create / room.join exactly. */
export function Onboarding({
  step,
  client,
  onAdvance,
}: {
  step: 'identity' | 'rooms';
  client: Client;
  onAdvance(): void;
}) {
  return (
    <div className="onboarding">
      <div className="onboarding-brand">
        <HexMark size={44} />
        <h1>Bantaba</h1>
        <p className="onboarding-tag">Your rooms, your data. Private by default — built for humans &amp; agents.</p>
      </div>
      {step === 'identity' ? <IdentityStep client={client} onAdvance={onAdvance} /> : <RoomsStep client={client} onAdvance={onAdvance} />}
    </div>
  );
}

function IdentityStep({ client, onAdvance }: { client: Client; onAdvance(): void }) {
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<DaemonErrorShape | null>(null);

  const create = async () => {
    setBusy(true);
    setError(null);
    try {
      await client.call('identity.create', {});
      onAdvance();
    } catch (e) {
      const err = errorShape(e);
      if (err.code === 'identity_exists') {
        onAdvance(); // someone else created it — just re-sync
      } else {
        setError(err);
      }
    } finally {
      setBusy(false);
    }
  };

  return (
    <div className="onboarding-card">
      <h2>Create your identity</h2>
      <p className="muted">
        A keypair generated and stored by your local daemon. No account, no server — the private key never leaves this
        machine.
      </p>
      <button type="button" className="btn btn-primary btn-lg" disabled={busy} onClick={() => void create()}>
        {busy ? 'Creating…' : 'Create identity'}
      </button>
      <ErrorNote error={error} />
    </div>
  );
}

function RoomsStep({ client, onAdvance }: { client: Client; onAdvance(): void }) {
  const [name, setName] = useState('');
  const [creating, setCreating] = useState(false);
  const [createError, setCreateError] = useState<DaemonErrorShape | null>(null);

  const [ticket, setTicket] = useState('');
  const [peerAddr, setPeerAddr] = useState('');
  const [joining, setJoining] = useState(false);
  const [joinError, setJoinError] = useState<DaemonErrorShape | null>(null);

  const create = async () => {
    if (!name.trim()) return;
    setCreating(true);
    setCreateError(null);
    try {
      await client.call('room.create', { name: name.trim() });
      onAdvance();
    } catch (e) {
      setCreateError(errorShape(e));
    } finally {
      setCreating(false);
    }
  };

  const join = async () => {
    if (!ticket.trim()) return;
    setJoining(true);
    setJoinError(null);
    try {
      const addr = peerAddr.trim();
      await client.call('room.join', {
        ticket: ticket.trim(),
        ...(addr ? { peers: [addr] } : {}),
      });
      onAdvance();
    } catch (e) {
      setJoinError(errorShape(e));
    } finally {
      setJoining(false);
    }
  };

  return (
    <div className="onboarding-columns">
      <form
        className="onboarding-card"
        onSubmit={(e) => {
          e.preventDefault();
          void create();
        }}
      >
        <h2>Create a room</h2>
        <p className="muted">Start a space and invite people or agents with tickets.</p>
        <label className="field">
          <span>Room name</span>
          <input
            value={name}
            onChange={(e) => setName(e.target.value)}
            placeholder="Build Iroh Rooms MVP"
            autoFocus
          />
        </label>
        <button type="submit" className="btn btn-primary" disabled={creating || !name.trim()}>
          {creating ? 'Creating…' : 'Create room'}
        </button>
        <ErrorNote error={createError} />
      </form>

      <form
        className="onboarding-card"
        onSubmit={(e) => {
          e.preventDefault();
          void join();
        }}
      >
        <h2>Join with a ticket</h2>
        <p className="muted">Paste the invite ticket you received. Add the inviter&apos;s address to dial directly.</p>
        <label className="field">
          <span>Ticket</span>
          <textarea
            value={ticket}
            onChange={(e) => setTicket(e.target.value)}
            placeholder="roomtkt1…"
            rows={3}
            spellCheck={false}
          />
        </label>
        <label className="field">
          <span>
            Peer address <em className="muted">(optional)</em>
          </span>
          <input
            value={peerAddr}
            onChange={(e) => setPeerAddr(e.target.value)}
            placeholder="<endpoint_id>@203.0.113.7:4242"
            spellCheck={false}
          />
        </label>
        <button type="submit" className="btn btn-primary" disabled={joining || !ticket.trim()}>
          {joining ? 'Joining…' : 'Join room'}
        </button>
        <ErrorNote error={joinError} />
      </form>
    </div>
  );
}
