@abstract class_name WorldGenPass
extends Resource

## A single composable step in the generation pipeline. Implementations read and
## write GenContext fields. Keep passes stateless: all state lives on the context.

@abstract func apply(context: GenContext) -> void
