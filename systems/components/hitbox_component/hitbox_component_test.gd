extends GdUnitTestSuite

## Unit tests for HitboxComponent: filtering, self-ignore, once-per-target, clear.
## The engine emits `area_entered` from the physics loop; these drive that signal
## directly, so the filtering logic is under test without staging real overlaps.

var _hits: Array[HurtboxComponent] = []


func before_test() -> void:
	_hits = []


func _make_hitbox(ignored: Node = null) -> HitboxComponent:
	var hitbox: HitboxComponent = auto_free(HitboxComponent.new())
	hitbox.ignored_actor = ignored
	add_child(hitbox)
	hitbox.hit_detected.connect(func(hurtbox: HurtboxComponent) -> void: _hits.append(hurtbox))
	return hitbox


func _make_hurtbox(actor: Node) -> HurtboxComponent:
	var hurtbox: HurtboxComponent = auto_free(HurtboxComponent.new())
	hurtbox.actor = actor
	add_child(hurtbox)
	return hurtbox


func test_reports_a_hurtbox_that_enters() -> void:
	var hitbox: HitboxComponent = _make_hitbox()
	var hurtbox: HurtboxComponent = _make_hurtbox(auto_free(Node.new()))
	hitbox.area_entered.emit(hurtbox)
	assert_int(_hits.size()).is_equal(1)
	assert_object(_hits[0]).is_same(hurtbox)


func test_non_hurtbox_area_is_ignored() -> void:
	var hitbox: HitboxComponent = _make_hitbox()
	var area: Area3D = auto_free(Area3D.new())
	add_child(area)
	hitbox.area_entered.emit(area)
	assert_int(_hits.size()).is_equal(0)


func test_same_hurtbox_reported_once_until_cleared() -> void:
	var hitbox: HitboxComponent = _make_hitbox()
	var hurtbox: HurtboxComponent = _make_hurtbox(auto_free(Node.new()))
	hitbox.area_entered.emit(hurtbox)
	hitbox.area_entered.emit(hurtbox)
	assert_int(_hits.size()).is_equal(1)
	hitbox.clear()
	hitbox.area_entered.emit(hurtbox)
	assert_int(_hits.size()).is_equal(2)


func test_ignored_actor_is_skipped() -> void:
	var attacker: Node = auto_free(Node.new())
	var hitbox: HitboxComponent = _make_hitbox(attacker)
	var own_hurtbox: HurtboxComponent = _make_hurtbox(attacker)
	hitbox.area_entered.emit(own_hurtbox)
	assert_int(_hits.size()).is_equal(0)
	# A hurtbox belonging to someone else still lands.
	var other: HurtboxComponent = _make_hurtbox(auto_free(Node.new()))
	hitbox.area_entered.emit(other)
	assert_int(_hits.size()).is_equal(1)
