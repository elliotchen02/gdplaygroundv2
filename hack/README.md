# hack/

Developer and test tooling. Never shipped, and nothing in the game depends on
this directory (see the dependency rules in `../CLAUDE.md`).

- `run-changed-tests.sh` — runs the gdUnit4 suites affected by changed `.gd`
  files. `--staged` limits it to the index, for a pre-commit hook; `--base <ref>`
  diffs a branch instead.
- `logs/` — scratch output from headless runs. Git-ignored; safe to delete.

Needs `GODOT_BIN`, or a Godot install at the default macOS path.

There is no headless-multiplayer wrapper script here: run the engine directly,
once per peer. `../docs/runbooks/runtime-testing.md` covers when to do that
rather than write a gdUnit4 suite, and which log holds which signal.
