#!/usr/bin/env bash
# Lint and format-check all GDScript, honoring .gdlintrc / .gdformatrc.
#
# Creates/reuses a local virtualenv with a pinned gdtoolkit, then runs
# `gdformat --check` and `gdlint` over every .gd file outside addons/.
#
# Usage:
#   ./hack/lint.sh
#
# Requires python3.

set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

VENV_DIR="${VENV_DIR:-.venv-gdtoolkit}"

if [ ! -d "$VENV_DIR" ]; then
	echo "Creating gdtoolkit virtualenv in ${VENV_DIR} ..."
	python3 -m venv "$VENV_DIR"
fi

# shellcheck disable=SC1091
source "$VENV_DIR/bin/activate"
pip install --quiet --upgrade pip
pip install --quiet -r hack/requirements-gdtoolkit.txt

# Collect .gd files, excluding third-party addons and the import cache.
# Use a read loop (not mapfile) so this runs on stock macOS bash 3.2.
gd_files=()
while IFS= read -r file; do
	gd_files+=("$file")
done < <(find . -name '*.gd' -not -path './addons/*' -not -path './.godot/*' | sort)

if [ "${#gd_files[@]}" -eq 0 ]; then
	echo "No GDScript files to lint."
	exit 0
fi

echo "Checking formatting (gdformat --check) on ${#gd_files[@]} file(s) ..."
gdformat --check "${gd_files[@]}"

echo "Linting (gdlint) ..."
gdlint "${gd_files[@]}"

echo "Lint OK."
