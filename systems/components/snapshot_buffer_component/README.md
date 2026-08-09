# snapshot_buffer_component

Holds the last N states an actor was reported in, keyed by tick, and answers what
it looked like at any point on that timeline — including between two reports.

## Why a buffer at all

Networked state does not arrive on a metronome. Several updates land in one
frame, then none for three. Applying each one the moment it arrives copies that
irregularity straight onto the body: measured on this project over loopback,
with no packet loss and no latency worth the name, a remote player's per-tick
movement swung between **0.000 m and 0.333 m** against a true 0.167 m — frozen
one tick, double the next.

Buffering the arrivals and reading back a fixed delay behind the newest one
turned the same motion into **0.157 m – 0.185 m with no frozen ticks**. Nothing
about the network changed; only when the states were read.

## Choosing the read-behind delay

The delay must exceed the gap between arrivals, or there is no second state to
interpolate towards and the buffer has nothing to offer. Past that it is a
straight trade: more delay absorbs more jitter, and shows remote players further
behind where they truly are.

[Gaffer On Games](https://gafferongames.com/post/snapshot_interpolation/) puts
the practical floor at roughly 150 ms for 10 snapshots/s, 150 ms at 30/s for
equivalent packet-loss protection, and 85 ms at 60/s. This project sends at 20 Hz
and reads 6 ticks (100 ms at 60 Hz) behind. Raise it for a worse connection.

## Extrapolation is a patch, not a feature

Past the newest state the buffer projects along the last known velocity for at
most `max_extrapolation_ticks`, then holds. Extrapolation is wrong the instant
the actor turns, jumps or lands — Gaffer's point that it "doesn't work very well
for rigid bodies because their motion is non-linear" applies just as much to a
player. It exists to cover a dropped packet. Holding a stale pose reads as a
brief pause; projecting indefinitely reads as an actor sliding through walls, so
the cap is the lesser evil. Set it to `0` to disable it outright.

## It has no clock

The component stores and interpolates. It does not decide what "now" is — the
caller passes a tick to `sample()`. That is deliberate: knowing the current
moment means knowing about connections, latency and clock offset, none of which
belong in `systems/`. It is what keeps this pure arithmetic, unit-testable with
no `MultiplayerAPI` and no scene, and reusable for anything replayed on a
timeline — a ghost, a killcam, a recorded demo — not just a network.

The caller in this project is `src/player/player_network.gd`, which runs a render
clock that advances one tick per tick and is *slewed* toward
`newest_tick - delay` rather than assigned from it. Assigning would hand the
jitter straight back.

## API

| | |
|---|---|
| `push(tick, position, velocity, yaw, pitch = 0.0)` | Records a state. Ignores anything not newer than what is held, so a duplicate or an overtaking packet cannot drag the timeline backwards. |
| `sample(render_tick) -> bool` | Reads the timeline, fractional ticks included. Writes `sampled_position` / `sampled_yaw` / `sampled_pitch`. Returns `false` only when nothing has been recorded — leave the actor alone rather than adopting a default, or it teleports to the origin on spawn. |
| `newest_tick()` / `oldest_tick()` / `size()` / `is_empty()` | Timeline extent. |
| `clear()` | Drops everything; use on reconnect. |

`sample` returns a bool and writes to fields rather than returning a struct so a
per-tick call for every remote actor allocates nothing.

## Tuning

- `capacity` — states retained. Must cover the read-behind delay plus the worst
  burst gap. 32 is a little over half a second at 60 Hz. Changing it clears the
  buffer.
- `max_extrapolation_ticks` — see above.
- `seconds_per_tick` — only used to turn a velocity in units-per-second into a
  distance while extrapolating. The game sets it from its own tick rate; the
  component names no rate of its own.

## Not yet

- **Delta compression.** Positions go on the wire in full. Worth revisiting when
  the actor count makes bandwidth the constraint, not before.
- **Interpolating anything but position, yaw and pitch.** Angles share a blend
  rule (`lerp_angle`, so a turn across ±π takes the short way rather than
  spinning the long way round), which is why pitch cost one field. Animation
  state and crouch height would each want a different rule; add them when
  something needs them rather than guessing now.
