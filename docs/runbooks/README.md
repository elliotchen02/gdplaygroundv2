# docs/runbooks/

Step-by-step operational procedures — the things done repeatedly, written down
so they are done the same way each time.

Fit for a runbook: exporting a build, reproducing a multiplayer bug across two
peers, profiling a frame-time regression, upgrading the Godot version or an
addon, bisecting a failing test.

Not fit for a runbook: how a directory is organised (that is its `README.md`),
or the design of an unbuilt feature (that is `../plans/`).

## Shape

Each file states its **purpose**, its **preconditions** (tools, env vars, open
editor or not), then **numbered steps with the exact commands**, and finally how
to **verify** it worked and how to **roll back** if it did not.

Name files after the task in kebab-case: `run-headless-multiplayer.md`.
