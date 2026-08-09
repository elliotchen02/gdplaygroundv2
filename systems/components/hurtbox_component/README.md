# hurtbox_component

An `Area3D` marking a region of an actor as hittable, tagged with the actor a hit belongs to. The receive side of the hitbox↔hurtbox pair; `hitbox_component` does the detecting.

## Responsibility

Be a detectable volume that names its owner. Keeping the vulnerable region separate from the physical collider lets a body's capsule stay one simple shape for movement while its hurtbox is tuned — or split into several boxes — independently.

## Wiring

`actor: Node` — whom a hit on this box counts against. Defaults to the parent.

The game puts this Area3D on the hurtbox layer and supplies the `CollisionShape3D`. Keep it `monitorable` (the default) so hitboxes can see it; it needs no `monitoring` of its own, since it is passive.

## API

Passive — no methods. A `HitboxComponent` reads `actor` off the hurtbox it overlapped to learn whom it struck.
