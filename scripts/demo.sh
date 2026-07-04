#!/usr/bin/env bash
# Bantaba developer demo:
#   1. builds the workspace
#   2. starts the human daemon on ws://127.0.0.1:7420/ws (data: .bantaba-demo/human)
#   3. starts a simulated agent (its own daemon on 7421) that joins the demo
#      room and posts periodic agent.status updates
#   4. prints how to open the UI against the live daemon
#
# Ctrl-C stops everything. Data persists in .bantaba-demo/ across runs;
# `rm -rf .bantaba-demo` for a fresh demo.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
HUMAN_PORT="${HUMAN_PORT:-7420}"
AGENT_PORT="${AGENT_PORT:-7421}"
DEMO_DIR="$REPO_ROOT/.bantaba-demo"

cd "$REPO_ROOT"

echo "demo: building the workspace…"
cargo build --workspace

mkdir -p "$DEMO_DIR/human"

PIDS=()
cleanup() {
  echo
  echo "demo: shutting down…"
  for pid in "${PIDS[@]:-}"; do
    kill "$pid" 2>/dev/null || true
  done
  wait 2>/dev/null || true
}
trap cleanup EXIT INT TERM

echo "demo: starting the human daemon on ws://127.0.0.1:$HUMAN_PORT/ws"
"$REPO_ROOT/target/debug/bantabad" \
  --loopback --port "$HUMAN_PORT" --data-dir "$DEMO_DIR/human" &
PIDS+=($!)

# The agent orchestrator (creates identities/room as needed, spawns the agent
# daemon on $AGENT_PORT, joins it to the room, posts statuses forever).
node "$REPO_ROOT/scripts/demo-agent.mjs" \
  --human-port "$HUMAN_PORT" \
  --agent-port "$AGENT_PORT" \
  --agent-data-dir "$DEMO_DIR/agent" &
PIDS+=($!)

sleep 2
cat <<EOF

============================================================
 Bantaba demo is running.

   Daemon (human):  ws://127.0.0.1:$HUMAN_PORT/ws
   Daemon (agent):  ws://127.0.0.1:$AGENT_PORT/ws
   Data:            $DEMO_DIR

 Open the UI against the live daemon:

   cd ui
   npm install        # first time only
   npm run dev
   open http://localhost:5173/?daemon=$HUMAN_PORT

 The room "Build Iroh Rooms MVP" fills with agent statuses
 every few seconds. Ctrl-C here stops the demo.
============================================================

EOF

wait
