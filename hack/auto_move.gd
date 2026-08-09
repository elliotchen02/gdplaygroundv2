extends Node

## Dev-only test autoload. With `--auto-move` on the command line, holds
## `move_forward` and pulses `jump` on a fixed period, so a headless peer walks
## and bunny-hops without a keyboard. Inert without the flag, so it costs a
## shipped build nothing but an idle node.
##
## No `class_name`: Godot rejects a global class whose name collides with an
## autoload singleton, and this script is only ever reached as the `AutoMove`
## autoload registered in `project.godot`.

const _MOVE_ACTION: StringName = &"move_forward"
const _JUMP_ACTION: StringName = &"jump"
## Ticks between jumps. 90 at 60 Hz is 1.5 s — long enough that a full ballistic
## arc (~0.5 s for a 1.2 m jump) completes and is legible in a log.
const _JUMP_PERIOD_TICKS: int = 90

var _tick: int = 0


func _ready() -> void:
	var args: PackedStringArray = OS.get_cmdline_args() + OS.get_cmdline_user_args()
	if not args.has("--auto-move"):
		set_physics_process(false)
		return
	Input.action_press(_MOVE_ACTION)


func _physics_process(_delta: float) -> void:
	_tick += 1
	# Press on one tick and release on the next: InputComponent listens for the
	# press edge in _unhandled_input, so a held action would never re-fire.
	if _tick % _JUMP_PERIOD_TICKS == 0:
		_send_jump(true)
	elif _tick % _JUMP_PERIOD_TICKS == 1:
		_send_jump(false)


func _send_jump(pressed: bool) -> void:
	var event: InputEventAction = InputEventAction.new()
	event.action = _JUMP_ACTION
	event.pressed = pressed
	event.device = -1
	Input.parse_input_event(event)
