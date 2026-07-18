/** Display words for protocol wire enums (issue #74; `docs/i18n.md` rule 3).
 *
 *  PROTOCOL.md values in, UI copy out. This is the only place in the React
 *  client that turns a role, a member status, a peer path, a daemon mode or a
 *  connection state into a word on the screen, and it mirrors Flutter's
 *  `app/lib/src/l10n/wire_display.dart` map for map so the two clients cannot
 *  drift into different words for the same protocol value.
 *
 *  Why the seam exists at all
 *  --------------------------
 *  The wire says `active`; the screen says **Member**. The roster used to
 *  title-case the wire value straight onto the screen, so one word ("Active")
 *  meant three different things: signed membership here, a live local session
 *  in the room rail, and a live forwarding session on a pipe chip. Display
 *  labels and wire values are never the same constant — renaming a label must
 *  rename no wire value, and translating one must not change what the daemon
 *  is told (`docs/room-workbench.md`, decision 4).
 *
 *  Raw passthrough is the contract, not a gap
 *  ------------------------------------------
 *  Every map's default returns the value ITSELF. A daemon newer than this
 *  client will send statuses and paths this build has never heard of; the
 *  honest rendering of an unrecognized fact is the fact. Not "Unknown" (which
 *  claims the daemon said nothing — `memberStatusUnknown` is reserved for the
 *  genuinely-empty status), and not a crash. Forward compatibility here is a
 *  one-line default, and it is the difference between a client that ages and a
 *  client that breaks.
 *
 *  Peer path is a passthrough seam, not a translation
 *  --------------------------------------------------
 *  `direct` / `relay` are Tier 2 in `docs/glossary-fr.md`: never translated,
 *  because the badge reports what the DAEMON observed about the network. The
 *  French catalog therefore holds `direct` and `relay` verbatim. So why route
 *  them through the catalog at all? Because the honesty rule is about the
 *  VALUE, not the mechanism — a locale that does have an established local term
 *  for a network relay may use it, while French deliberately does not, and only
 *  a catalog entry lets a translator record that decision instead of a
 *  hardcoded string silently deciding for every language at once. The rule this
 *  file enforces is that the badge never shows a path the daemon did not
 *  report; it is not "the badge is exempt from the catalog".
 *
 *  What this file must NOT be used for
 *  -----------------------------------
 *  `labelTone()` in `lib/format.ts` is an ENGLISH-TOKEN CONTRACT (docs/
 *  PROTOCOL.md, `docs/glossary-fr.md` decision 3, mirrored in Dart): it derives
 *  chip and dot tone from known English tokens in a free-form agent-status
 *  label. It must keep receiving the RAW wire label. Translating before
 *  `labelTone` would make every French label render neutral — or worse,
 *  fabricate green for a word that happened to match. Green is earned. Feed
 *  `labelTone` the wire value and this file's output to the eye, never the
 *  reverse.
 *
 *  Resolved at render time: every function takes the catalog the caller already
 *  got from `useStrings()`, so a language switch re-resolves on the next render
 *  (rule 1). Nothing here is cached.
 */

import type { Catalog } from './catalog';

/** The catalog subset these functions read. Typed as the fragment rather than
 *  the whole `Catalog` so a caller can pass either, and so the dependency is
 *  legible: this file needs nineteen keys, not the catalog. */
type S = Catalog;

/** Mid-sentence role word — "… joined as owner". Pills use {@link rolePill}.
 *  Unknown roles pass through raw. */
export function roleInline(s: S, role: string): string {
  switch (role) {
    case 'owner':
      return s.wireRoleOwnerInline;
    case 'agent':
      return s.wireRoleAgentInline;
    case 'member':
      return s.wireRoleMemberInline;
    default:
      return role;
  }
}

/** Capitalized role pill / roster label. Unknown roles pass through raw.
 *
 *  Replaces `displayRole()` in `components/RightPanel.tsx`, which returned
 *  'Member' for anything that was not owner or agent — mislabeling a future
 *  role as an ordinary member rather than showing what the daemon actually
 *  said. */
export function rolePill(s: S, role: string): string {
  switch (role) {
    case 'owner':
      return s.panelRoleOwner;
    case 'agent':
      return s.panelRoleAgent;
    case 'member':
      return s.panelRoleMember;
    default:
      return role;
  }
}

/** Member status pill / agent-card footer word — signed membership, and nothing
 *  else.
 *
 *  The empty string is the one value that maps to "Unknown": a daemon that
 *  reported NO status told us nothing, and saying so is honest. A status this
 *  build does not recognize is different — the daemon did say something, so it
 *  passes through raw.
 *
 *  Replaces `displayStatus()` in `components/RightPanel.tsx`, whose `default`
 *  branch collapsed every unrecognized status into 'Unknown' and so erased a
 *  fact the daemon had actually sent. */
export function memberStatus(s: S, status: string): string {
  switch (status) {
    case 'active':
      return s.memberStatusMember;
    case 'invited':
      return s.wireStatusInvited;
    case 'left':
      return s.wireStatusLeft;
    case 'removed':
      return s.wireStatusRemoved;
    case '':
      return s.memberStatusUnknown;
    default:
      return status;
  }
}

/** Peer connection path — the room-header chip's state label.
 *
 *  Takes a non-null path on purpose. `PeerStatus.path` is nullable WHILE
 *  `state` is already `connected`: the SDK knows the link is up before it knows
 *  how it got there, and "not claimed yet" is a different fact from "direct" or
 *  "relay" (`components/RoomHeader.tsx` records this). Resolve that absence at
 *  the call site — this function will not invent a path for you.
 *
 *  Unknown paths pass through raw; see the file docstring for why that is the
 *  honest behavior here specifically. */
export function peerPath(s: S, path: string): string {
  switch (path) {
    case 'direct':
      return s.wirePathDirect;
    case 'relay':
      return s.wirePathRelay;
    default:
      return path;
  }
}

/** Daemon mode, for the Settings daemon summary. Unknown modes pass through
 *  raw.
 *
 *  `components/SettingsPanel.tsx` renders `{status?.mode ?? '-'}` today — the
 *  wire value straight onto the screen. */
export function daemonMode(s: S, mode: string): string {
  switch (mode) {
    case 'loopback':
      return s.wireModeLoopback;
    case 'real':
      return s.wireModeReal;
    default:
      return mode;
  }
}

/** Client connection state, mid-sentence. Standalone capitalized badges (the
 *  Sidebar's `CONN_LABEL`) use the shell area's `shellConn*` keys instead —
 *  Flutter draws the same line, and a badge is not a clause.
 *
 *  `ConnectionState` is a closed union in `lib/protocol.ts`, so all four arms
 *  are covered; the parameter is widened to `string` and the default passes
 *  through anyway, because the value crosses a JSON boundary before it gets
 *  here and a type is not a runtime guarantee.
 *
 *  `components/SettingsPanel.tsx` renders `{conn}` raw today. */
export function connStateInline(s: S, state: string): string {
  switch (state) {
    case 'connected':
      return s.wireConnConnectedInline;
    case 'connecting':
      return s.wireConnConnectingInline;
    case 'reconnecting':
      return s.wireConnReconnectingInline;
    case 'disconnected':
      return s.wireConnDisconnectedInline;
    default:
      return state;
  }
}
