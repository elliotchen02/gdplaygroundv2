#!/usr/bin/env bash
# Run GDUnit4 tests affected by changed GDScript files.
#
# Usage:
#   ./hack/run-changed-tests.sh              # unstaged + staged changes vs HEAD
#   ./hack/run-changed-tests.sh --staged     # only staged files (pre-commit)
#   ./hack/run-changed-tests.sh --base main  # branch diff vs main
#
# Requires GODOT_BIN or a Godot install at the default macOS path.

set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

GODOT_BIN="${GODOT_BIN:-/Applications/Godot.app/Contents/MacOS/Godot}"
export GODOT_BIN

if [ ! -x "$GODOT_BIN" ]; then
	echo "Godot binary not found at '$GODOT_BIN'. Set GODOT_BIN to your Godot executable." >&2
	exit 1
fi

mode="${1:---working-tree}"
base_ref="${2:-}"

collect_changed_gd_files() {
	case "$mode" in
	--staged)
		git diff --cached --name-only --diff-filter=ACMR -- '*.gd'
		;;
	--base)
		if [ -z "$base_ref" ]; then
			echo "Usage: $0 --base <ref>" >&2
			exit 1
		fi
		git diff --name-only --diff-filter=ACMR "${base_ref}"...HEAD -- '*.gd'
		;;
	--working-tree | *)
		{
			git diff --name-only --diff-filter=ACMR HEAD -- '*.gd'
			git diff --cached --name-only --diff-filter=ACMR -- '*.gd'
		} | sort -u
		;;
	esac
}

declare -a test_files=()

add_test_file() {
	local candidate="$1"
	for existing in "${test_files[@]:-}"; do
		if [ "$existing" = "$candidate" ]; then
			return
		fi
	done
	test_files+=("$candidate")
}

while IFS= read -r file; do
	[ -z "$file" ] && continue
	case "$file" in
	addons/*) continue ;;
	esac

	if [[ "$file" == *_test.gd ]] || [[ "$file" == test_*.gd ]]; then
		add_test_file "res://$file"
		continue
	fi

	if [[ "$file" == *.gd ]]; then
		dir="$(dirname "$file")"
		base="$(basename "$file" .gd)"
		colocated="${dir}/${base}_test.gd"
		prefixed="${dir}/test_${base}.gd"

		if [ -f "$colocated" ]; then
			add_test_file "res://$colocated"
		elif [ -f "$prefixed" ]; then
			add_test_file "res://$prefixed"
		fi
	fi
done < <(collect_changed_gd_files)

if [ "${#test_files[@]}" -eq 0 ]; then
	echo "No GDUnit4 test files matched the changed GDScript files."
	exit 0
fi

echo "Running ${#test_files[@]} test file(s):"
printf '  %s\n' "${test_files[@]}"

args=()
for test_file in "${test_files[@]}"; do
	args+=(-a "$test_file")
done

./addons/gdUnit4/runtest.sh "${args[@]}"
