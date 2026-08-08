# hack/

Developer and test tooling. Never shipped, and nothing in the game depends on
this directory (see the dependency rules in `../CLAUDE.md`).

- `run-changed-tests.sh` — runs the gdUnit4 suites affected by changed `.gd`
  files. `--staged` limits it to the index, for use from a pre-commit hook;
  `--base <ref>` diffs a branch instead.
- `logs/` — scratch output from headless runs. Git-ignored; safe to delete.

Both entry points need `GODOT_BIN`, or a Godot install at the default macOS
path `/Applications/Godot.app/Contents/MacOS/Godot`.

## Headless multiplayer

There is no wrapper script for this — run the engine directly, once per peer,
and capture each process's stdout. The whole contract is the flags parsed in
`../src/net/net_session.gd`, passed after the `--` separator: `--host`,
`--join[=address]`, `--port=N` (default `24545`). No network flag means host.

```bash
"$GODOT_BIN" --headless --path .. -- --host           > logs/host.log 2>&1 &
"$GODOT_BIN" --headless --path .. -- --join=127.0.0.1 > logs/client.log 2>&1 &
```

`../docs/runbooks/runtime-testing.md` covers when to reach for this instead of
a gdUnit4 suite, which log holds which signal, and why a healthy peer on `main`
currently prints almost nothing.
