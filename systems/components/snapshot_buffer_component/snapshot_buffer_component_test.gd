extends GdUnitTestSuite

## Unit tests for SnapshotBufferComponent. Pure arithmetic, so no scene, no
## physics loop and no network: each test pushes a handful of states by hand and
## asserts what the buffer reports back at a given point on the timeline.

const _APPROX: Vector3 = Vector3(0.001, 0.001, 0.001)


func _make() -> SnapshotBufferComponent:
	return auto_free(SnapshotBufferComponent.new())


## Pushes `count` states one tick apart, walking +1 on X per tick from `first_tick`.
func _push_walk(buffer: SnapshotBufferComponent, first_tick: int, count: int) -> void:
	for i: int in count:
		var tick: int = first_tick + i
		buffer.push(tick, Vector3(float(tick), 0.0, 0.0), Vector3(60.0, 0.0, 0.0), 0.0)


func test_empty_buffer_reports_no_sample() -> void:
	var buffer: SnapshotBufferComponent = _make()
	assert_bool(buffer.is_empty()).is_true()
	# False, not a zero vector: a caller must be able to tell "nothing yet" from
	# "the actor is at the origin", or every remote actor teleports on spawn.
	assert_bool(buffer.sample(10.0)).is_false()


func test_sample_on_a_recorded_tick_returns_that_state() -> void:
	var buffer: SnapshotBufferComponent = _make()
	_push_walk(buffer, 10, 3)
	assert_bool(buffer.sample(11.0)).is_true()
	assert_vector(buffer.sampled_position).is_equal_approx(Vector3(11.0, 0.0, 0.0), _APPROX)


func test_sample_between_two_ticks_interpolates() -> void:
	var buffer: SnapshotBufferComponent = _make()
	buffer.push(10, Vector3.ZERO, Vector3.ZERO, 0.0)
	buffer.push(20, Vector3(10.0, 0.0, 0.0), Vector3.ZERO, 0.0)
	assert_bool(buffer.sample(15.0)).is_true()
	assert_vector(buffer.sampled_position).is_equal_approx(Vector3(5.0, 0.0, 0.0), _APPROX)


func test_yaw_interpolates_the_short_way_around() -> void:
	# 3.0 to -3.0 is 0.28 radians across the wrap, not 6.0 radians back through
	# zero. Getting this wrong spins a remote player on the spot.
	var buffer: SnapshotBufferComponent = _make()
	buffer.push(1, Vector3.ZERO, Vector3.ZERO, 3.0)
	buffer.push(2, Vector3.ZERO, Vector3.ZERO, -3.0)
	assert_bool(buffer.sample(1.5)).is_true()
	assert_float(absf(buffer.sampled_yaw)).is_equal_approx(PI, 0.01)


func test_stale_and_duplicate_pushes_are_ignored() -> void:
	var buffer: SnapshotBufferComponent = _make()
	buffer.push(10, Vector3(1.0, 0.0, 0.0), Vector3.ZERO, 0.0)
	buffer.push(9, Vector3(99.0, 0.0, 0.0), Vector3.ZERO, 0.0)
	buffer.push(10, Vector3(99.0, 0.0, 0.0), Vector3.ZERO, 0.0)
	assert_int(buffer.size()).is_equal(1)
	assert_int(buffer.newest_tick()).is_equal(10)
	assert_bool(buffer.sample(10.0)).is_true()
	assert_vector(buffer.sampled_position).is_equal_approx(Vector3(1.0, 0.0, 0.0), _APPROX)


func test_ring_drops_the_oldest_once_full() -> void:
	var buffer: SnapshotBufferComponent = _make()
	buffer.capacity = 4
	_push_walk(buffer, 1, 10)
	assert_int(buffer.size()).is_equal(4)
	assert_int(buffer.oldest_tick()).is_equal(7)
	assert_int(buffer.newest_tick()).is_equal(10)
	# Interpolation still works across the wraparound seam.
	assert_bool(buffer.sample(8.5)).is_true()
	assert_vector(buffer.sampled_position).is_equal_approx(Vector3(8.5, 0.0, 0.0), _APPROX)


func test_sample_before_the_oldest_retained_tick_clamps() -> void:
	var buffer: SnapshotBufferComponent = _make()
	_push_walk(buffer, 10, 3)
	assert_bool(buffer.sample(2.0)).is_true()
	assert_vector(buffer.sampled_position).is_equal_approx(Vector3(10.0, 0.0, 0.0), _APPROX)


func test_extrapolation_projects_along_velocity_then_holds() -> void:
	var buffer: SnapshotBufferComponent = _make()
	buffer.max_extrapolation_ticks = 4
	buffer.seconds_per_tick = 1.0 / 60.0
	# 60 m/s is exactly 1 metre per tick, so ticks ahead read off as metres.
	buffer.push(10, Vector3.ZERO, Vector3(60.0, 0.0, 0.0), 0.0)
	assert_bool(buffer.sample(12.0)).is_true()
	assert_vector(buffer.sampled_position).is_equal_approx(Vector3(2.0, 0.0, 0.0), _APPROX)
	# Past the cap it stops projecting rather than sliding away forever.
	assert_bool(buffer.sample(30.0)).is_true()
	assert_vector(buffer.sampled_position).is_equal_approx(Vector3(4.0, 0.0, 0.0), _APPROX)


func test_extrapolation_can_be_switched_off() -> void:
	var buffer: SnapshotBufferComponent = _make()
	buffer.max_extrapolation_ticks = 0
	buffer.push(10, Vector3.ZERO, Vector3(60.0, 0.0, 0.0), 0.0)
	assert_bool(buffer.sample(14.0)).is_true()
	assert_vector(buffer.sampled_position).is_equal_approx(Vector3.ZERO, _APPROX)


func test_clear_empties_the_timeline() -> void:
	var buffer: SnapshotBufferComponent = _make()
	_push_walk(buffer, 10, 3)
	buffer.clear()
	assert_bool(buffer.is_empty()).is_true()
	assert_bool(buffer.sample(11.0)).is_false()


func test_pitch_interpolates_the_short_way_around() -> void:
	var buffer: SnapshotBufferComponent = _make()
	buffer.push(1, Vector3.ZERO, Vector3.ZERO, 0.0, 3.0)
	buffer.push(2, Vector3.ZERO, Vector3.ZERO, 0.0, -3.0)
	assert_bool(buffer.sample(1.5)).is_true()
	assert_float(absf(buffer.sampled_pitch)).is_equal_approx(PI, 0.01)


func test_pitch_is_carried_through_extrapolation_and_clamping() -> void:
	var buffer: SnapshotBufferComponent = _make()
	buffer.push(10, Vector3.ZERO, Vector3(60.0, 0.0, 0.0), 0.0, 0.5)
	# Held past the newest state, and held before the oldest one too.
	assert_bool(buffer.sample(12.0)).is_true()
	assert_float(buffer.sampled_pitch).is_equal_approx(0.5, 0.001)
	buffer.push(20, Vector3.ZERO, Vector3.ZERO, 0.0, 0.25)
	assert_bool(buffer.sample(2.0)).is_true()
	assert_float(buffer.sampled_pitch).is_equal_approx(0.5, 0.001)
