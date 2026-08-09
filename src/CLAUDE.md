# src/

The game. Composes `systems/` and `assets/` into playable content. Game-specific
logic that is not reusable belongs here, never in `systems/`.

Read `net/README.md` and `player/README.md` before changing multiplayer code —
they carry the reasoning these rules compress.

## The network model

Client-simulated, server-validated. Each client simulates its own player exactly
as in single player (zero input latency, no prediction machinery) and reports the
*resulting* transform. The server never simulates a player and never sees an
input; it only checks that each reported position was reachable, and corrects
what was not. Other clients see the server's accepted state.

Each player copy resolves to one of three roles — owner, server record, observer
— in `player/player_network.gd`, which gates the components to match.
