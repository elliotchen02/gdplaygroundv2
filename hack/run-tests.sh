#!/usr/bin/env bash
# Run the full gdUnit4 suite.
#
# Runs every gdUnit4 test under the given roots (default: systems + src).
# Complements run-changed-tests.sh, which only runs suites affected by a diff.
#
# Usage:
#   ./hack/run-tests.sh                          # res://systems res://src
#   ./hack/run-tests.sh res://systems res://ui   # custom roots
#
# Requires GODOT_BIN or a Godot install at the default macOS path.
# On a display-less host (CI) the runner is wrapped in xvfb-run, since gdUnit4's
# runtest.sh launches Godot windowed.

set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

GODOT_BIN="${GODOT_BIN:-/Applications/Godot.app/Contents/MacOS/Godot}"
export GODOT_BIN

if [ ! -x "$GODOT_BIN" ]; then
	echo "Godot binary not found at '$GODOT_BIN'. Set GODOT_BIN to your Godot executable." >&2
	exit 1
fi

# Test roots to scan (override by passing res:// paths as arguments).
roots=("$@")
if [ "${#roots[@]}" -eq 0 ]; then
	roots=(res://systems res://src)
fi

# Fresh checkouts (CI) have no .godot/; import resources once so the runner does
# not fail on unimported assets. --import runs the editor headless, imports, and
# quits. timeout guards against a hang (absent on stock macOS, so guard it too).
echo "Importing project resources ..."
if command -v timeout >/dev/null 2>&1; then
	timeout 300 "$GODOT_BIN" --headless --import --path .
else
	"$GODOT_BIN" --headless --import --path .
fi

args=()
for root in "${roots[@]}"; do
	args+=(-a "$root")
done

echo "Running gdUnit4 suites under: ${roots[*]}"
if [ -z "${DISPLAY:-}" ] && command -v xvfb-run >/dev/null 2>&1; then
	xvfb-run -a ./addons/gdUnit4/runtest.sh "${args[@]}"
else
	./addons/gdUnit4/runtest.sh "${args[@]}"
fi
