#!/usr/bin/env bash
# One-time per-clone setup: gdtoolkit venv + version-controlled git hooks.
# Run: ./hack/setup.sh
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO_ROOT"

if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
	echo "error: not a git repository (run from within the repo)" >&2
	exit 1
fi

if ! command -v python3 >/dev/null 2>&1; then
	echo "error: python3 is required (install via Xcode CLT, Homebrew, or python.org)" >&2
	exit 1
fi

VENV_DIR=".venv"
REQ_FILE="hack/requirements-gdtoolkit.txt"
HOOKS_DIR=".githooks"

if [[ ! -f "$REQ_FILE" ]]; then
	echo "error: $REQ_FILE not found" >&2
	exit 1
fi

if [[ ! -d "$HOOKS_DIR" ]]; then
	echo "error: $HOOKS_DIR/ not found at repo root" >&2
	exit 1
fi

# --- gdtoolkit venv (gdlint + gdformat for pre-commit) ---
if [[ ! -d "$VENV_DIR" ]]; then
	echo "Creating $VENV_DIR ..."
	python3 -m venv "$VENV_DIR"
fi

"$VENV_DIR/bin/pip" install --upgrade pip
"$VENV_DIR/bin/pip" install -r "$REQ_FILE"

echo "GDScript toolkit ready in $VENV_DIR/"

# --- git hooks ---
chmod +x "$HOOKS_DIR"/*
git config core.hooksPath "$HOOKS_DIR"

configured="$(git config --get core.hooksPath || true)"
if [[ "$configured" != "$HOOKS_DIR" ]]; then
	echo "error: failed to set core.hooksPath (got '${configured:-unset}')" >&2
	exit 1
fi

echo "Git hooks installed: core.hooksPath -> $HOOKS_DIR"
ls -1 "$HOOKS_DIR"

# --- inkscape-mcp (optional; project-local Cursor MCP) ---
if command -v uv >/dev/null 2>&1; then
	"$REPO_ROOT/hack/setup-inkscape-mcp.sh"
else
	echo "Skipping inkscape-mcp (uv not installed; optional for Cursor Inkscape MCP)"
fi
