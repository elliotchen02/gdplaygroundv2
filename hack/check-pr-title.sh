#!/usr/bin/env bash
# Validate a pull-request title against the repo's Conventional Commits rules.
#
# Only the PR title is checked: PRs are squash-merged, so the title becomes the
# single commit that lands on main. Mirrors the convention in
# docs/CONTRIBUTING.md (scope = the top-level directory touched).
#
# Usage:
#   ./hack/check-pr-title.sh "feat(systems): add snapshot buffer"
#   PR_TITLE="fix(src): correct spawn point" ./hack/check-pr-title.sh

set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

TITLE="${1:-${PR_TITLE:-}}"

if [ -z "$TITLE" ]; then
	echo "check-pr-title: no title provided (pass as an argument or set PR_TITLE)." >&2
	exit 1
fi

# type(scope): description — scope required, optional '!' for a breaking change,
# description starts lowercase (imperative mood).
PATTERN='^(feat|fix|docs|refactor|chore)\((systems|src|ui|sandbox|assets|hack|docs|cursor)\)(!)?: [a-z].+'

if [[ ! "$TITLE" =~ $PATTERN ]]; then
	cat >&2 <<EOF
check-pr-title: invalid PR title

  Title: ${TITLE}

Expected: type(scope): description
  Types:  feat, fix, docs, refactor, chore
  Scopes: systems, src, ui, sandbox, assets, hack, docs, cursor
  Add '!' before the colon for a breaking change: feat(src)!: ...

Examples:
  feat(systems): add snapshot buffer component
  fix(src): correct player spawn transform
  chore(hack): add PR validation CI

Description must start with a lowercase letter (imperative mood).
EOF
	exit 1
fi

echo "PR title OK: ${TITLE}"
