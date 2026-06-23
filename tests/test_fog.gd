extends SceneTree

## Headless checks for fog state. Run with:
##   godot --headless --script tests/test_fog.gd

var _failures: int = 0


func _init() -> void:
	var fog := FogState.new(Vector2i(64, 64))

	var revealed_rects: Array[Rect2i] = []
	fog.region_revealed.connect(func(rect: Rect2i) -> void: revealed_rects.append(rect))

	fog.reveal_circle(Vector2i(10, 10), 3)
	_check(fog.is_revealed(10, 10), "circle reveals its center")
	_check(fog.is_revealed(12, 10), "circle reveals within radius")
	_check(not fog.is_revealed(20, 10), "outside radius stays hidden")
	_check(not fog.is_revealed(40, 40), "untouched area hidden")
	_check(revealed_rects.size() == 1, "one region_revealed signal per reveal")

	# Persistence: a second reveal elsewhere must not un-reveal the first.
	fog.reveal_circle(Vector2i(40, 40), 2)
	_check(fog.is_revealed(10, 10), "earlier reveal persists")
	_check(fog.is_revealed(40, 40), "new reveal applied")

	# Bounds safety.
	_check(not fog.is_revealed(-1, -1), "out-of-bounds query is safe")
	fog.reveal_circle(Vector2i(0, 0), 2)
	_check(fog.is_revealed(0, 0), "corner reveal clamps without error")

	if _failures == 0:
		print("fog: ALL TESTS PASSED")
	else:
		printerr("fog: %d FAILURE(S)" % _failures)
	quit(1 if _failures > 0 else 0)


func _check(condition: bool, label: String) -> void:
	if condition:
		print("  PASS: ", label)
	else:
		_failures += 1
		printerr("  FAIL: ", label)
