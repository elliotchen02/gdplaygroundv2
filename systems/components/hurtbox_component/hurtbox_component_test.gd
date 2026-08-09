extends GdUnitTestSuite

## Unit tests for HurtboxComponent: it names the actor a hit belongs to.


func test_actor_defaults_to_parent() -> void:
	var parent: Node3D = auto_free(Node3D.new())
	var hurtbox: HurtboxComponent = HurtboxComponent.new()
	parent.add_child(hurtbox)
	add_child(parent)
	assert_object(hurtbox.actor).is_same(parent)


func test_explicit_actor_is_kept() -> void:
	var actor: Node = auto_free(Node.new())
	var hurtbox: HurtboxComponent = auto_free(HurtboxComponent.new())
	hurtbox.actor = actor
	add_child(hurtbox)
	assert_object(hurtbox.actor).is_same(actor)
