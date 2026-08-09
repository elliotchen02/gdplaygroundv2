#!/usr/bin/env bash
# Launch a headless multiplayer session for log-based testing: one host and
# N-1 clients, each writing its console to hack/logs/peer_<i>.log.
#
# Usage:
#   ./hack/run-headless.sh                              # 2 peers, idle
#   ./hack/run-headless.sh 3                            # 1 host, 2 clients
#   ./hack/run-headless.sh 2 --auto-move                # every peer walks and jumps
#   ./hack/run-headless.sh 2 --auto-move --duration 15  # auto-stop after 15s
#
# --auto-move goes to EVERY peer including the host, so host and client traces
# are directly comparable — the whole point of the harness is diffing them.
#
# Read the results with, e.g.:
#   grep -nE 'REJECT|force_state|strikes' hack/logs/*.log
#
# NOTE: the MCPGameBridge autoload competes with the editor for the single MCP
# bridge slot. For clean headless runs, close the editor first.
#
# Requires GODOT_BIN or a Godot install at the default macOS path.

set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

GODOT_BIN="${GODOT_BIN:-/Applications/Godot.app/Contents/MacOS/Godot}"

if [ ! -x "$GODOT_BIN" ]; then
	echo "Godot binary not found at '$GODOT_BIN'. Set GODOT_BIN to your Godot executable." >&2
	exit 1
fi

peer_count=2
auto_move=""
duration=0

while [ "$#" -gt 0 ]; do
	case "$1" in
	--auto-move)
		auto_move="--auto-move"
		;;
	--duration)
		shift
		duration="${1:-0}"
		;;
	--duration=*)
		duration="${1#--duration=}"
		;;
	[0-9]*)
		peer_count="$1"
		;;
	*)
		echo "Unknown argument: $1" >&2
		echo "Usage: $0 [peer_count] [--auto-move] [--duration N]" >&2
		exit 1
		;;
	esac
	shift
done

if [ "$peer_count" -lt 2 ]; then
	echo "peer_count must be >= 2 (one host and at least one client)." >&2
	exit 1
fi

LOG_DIR="$ROOT/hack/logs"
mkdir -p "$LOG_DIR"

declare -a pids=()

cleanup() {
	trap - INT TERM EXIT
	for pid in "${pids[@]:-}"; do
		kill "$pid" 2>/dev/null || true
	done
}
trap cleanup INT TERM EXIT

echo "Launching $peer_count headless peers (logs in hack/logs/):"
for ((i = 0; i < peer_count; i++)); do
	log="$LOG_DIR/peer_${i}.log"
	: >"$log"
	if [ "$i" -eq 0 ]; then
		net_arg="--host"
		role="host"
	else
		net_arg="--join=127.0.0.1"
		role="client"
	fi
	# shellcheck disable=SC2086
	"$GODOT_BIN" --headless --path "$ROOT" -- "$net_arg" $auto_move >"$log" 2>&1 &
	pids+=("$!")
	printf '  peer %d (%-6s) pid=%-7d log=%s\n' "$i" "$role" "$!" "$log"
done

if [ "$duration" -gt 0 ]; then
	echo "Running for ${duration}s, then stopping..."
	sleep "$duration"
else
	echo "Running. Press Ctrl-C to stop."
	wait
fi
