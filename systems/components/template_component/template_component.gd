@tool
class_name TemplateComponent
extends Node

## ONE sentence naming the single responsibility this component owns.
##
## Copy this folder, rename it, and replace the placeholder behaviour. Attach as
## a child of the node it acts upon. Extend a different Godot node (Area3D,
## RayCast3D, Node3D) when the component needs those capabilities.

## Past tense, and passes the minimum a listener needs.
signal charge_completed(actor: Node)

@export_group("Wiring")
## Node this component acts upon. Leave empty to use the parent.
@export var actor: Node:
	set(value):
		actor = value
		update_configuration_warnings()

@export_group("Tuning")
## Seconds to reach a full charge.
@export_range(0.1, 30.0, 0.1) var charge_duration: float = 2.0
## Whether charging begins as soon as the component enters the tree.
@export var starts_charging: bool = false

var _elapsed: float = 0.0


func _ready() -> void:
	set_process(false)
	if Engine.is_editor_hint():
		return
	if actor == null:
		actor = get_parent()
	if starts_charging:
		start_charging()


func _process(delta: float) -> void:
	_elapsed += delta
	if _elapsed < charge_duration:
		return
	set_process(false)
	charge_completed.emit(actor)


## The host drives the component downwards through calls like this one.
func start_charging() -> void:
	_elapsed = 0.0
	set_process(true)


func is_charging() -> bool:
	return is_processing()


func _get_configuration_warnings() -> PackedStringArray:
	if actor == null and get_parent() == null:
		return ["Needs a parent, or an explicit actor assigned."]
	return []
