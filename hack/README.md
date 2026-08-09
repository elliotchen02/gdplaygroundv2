# hack/

Developer and test tooling. Never shipped, and nothing in the game depends on
this directory (see the dependency rules in `../CLAUDE.md`).

- `run-changed-tests.sh` — runs the gdUnit4 suites affected by changed `.gd`
  files. `--staged` limits it to the index, for a pre-commit hook; `--base <ref>`
  diffs a branch instead.
- `run-headless.sh` — launches N headless peers, peer 0 hosting and the rest
  joining `127.0.0.1`. `--auto-move` drives them, `--duration N` stops them.
- `auto_move.gd` — the `AutoMove` autoload behind `--auto-move`: holds
  `move_forward` and pulses `jump` every 90 ticks. Inert without the flag.
- `logs/` — scratch output from headless runs. Git-ignored; safe to delete.

Needs `GODOT_BIN`, or a Godot install at the default macOS path.

```bash
./hack/run-headless.sh 2 --auto-move --duration 12
grep -nE 'net|spawn|despawn' hack/logs/*.log
```

`--auto-move` goes to **every** peer including the host: the harness exists to
diff a host trace against a client trace, which only works if both are driven
alike. A healthy run prints one `[spawn]` line per player on *both* peers, each
at its own marker — that, not silence, is what proves replication.

Registering a `hack/` script as an autoload is the one place the dependency rule
bends. It is a `project.godot` entry, not a code reference, and Godot offers no
other way to inject a node before the main scene without a `src/` script
reaching into `hack/`.

`../docs/runbooks/runtime-testing.md` covers when to reach for a headless run
rather than a gdUnit4 suite, and which log holds which signal.
