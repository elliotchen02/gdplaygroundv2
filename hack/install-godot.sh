#!/usr/bin/env bash
# Download a Linux Godot editor build for CI and export GODOT_BIN.
#
# Idempotent: skips the download when the target binary already exists, so an
# actions/cache hit on $GODOT_DIR makes this a near no-op. Linux/CI only —
# locally on macOS use the editor at the default path (see run-tests.sh).
#
# Usage:
#   ./hack/install-godot.sh                       # installs GODOT_VERSION (default below)
#   GODOT_VERSION=4.7-stable ./hack/install-godot.sh
#
# On GitHub Actions it appends GODOT_BIN=<path> to $GITHUB_ENV for later steps.

set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

GODOT_VERSION="${GODOT_VERSION:-4.7-stable}"
GODOT_DIR="${GODOT_DIR:-$HOME/.cache/godot}"
BIN_NAME="Godot_v${GODOT_VERSION}_linux.x86_64"
GODOT_BIN="${GODOT_DIR}/${BIN_NAME}"
ZIP_URL="https://github.com/godotengine/godot/releases/download/${GODOT_VERSION}/${BIN_NAME}.zip"

if [ ! -x "$GODOT_BIN" ]; then
	echo "Downloading Godot ${GODOT_VERSION} ..."
	mkdir -p "$GODOT_DIR"
	tmp_zip="$(mktemp)"
	curl -fsSL "$ZIP_URL" -o "$tmp_zip"
	unzip -o -q "$tmp_zip" -d "$GODOT_DIR"
	rm -f "$tmp_zip"
	chmod +x "$GODOT_BIN"
else
	echo "Godot ${GODOT_VERSION} already present at ${GODOT_BIN}"
fi

"$GODOT_BIN" --version

# Hand GODOT_BIN to subsequent workflow steps when running on GitHub Actions.
if [ -n "${GITHUB_ENV:-}" ]; then
	echo "GODOT_BIN=${GODOT_BIN}" >>"$GITHUB_ENV"
fi

echo "GODOT_BIN=${GODOT_BIN}"
