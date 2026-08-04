class_name Main
extends Node3D

## Game entry point. Wires the network session to player spawning and owns
## app-level policy — mouse capture, and letting the server place each player —
## that no single actor should decide.

const _PLAYER_SCENE: PackedScene = preload("res://src/player/player.tscn")

@export var net_session: NetSession
## Container the MultiplayerSpawner replicates spawned players under.
@export var players: Node3D
## Optional Marker3D parent; players spawn at its children in round-robin order.
@export var spawn_points: Node3D

var _next_spawn: int = 0


func _ready() -> void:
	# A headless/dedicated server has no window and must not grab the mouse.
	if DisplayServer.get_name() != "headless":
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	net_session.session_started.connect(_on_session_started)
	net_session.session_ended.connect(_on_session_ended)
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"ui_cancel"):
		if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		else:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _on_session_started() -> void:
	# `peer_connected` never fires for the host itself, so spawn peer 1 by hand.
	if multiplayer.is_server():
		_spawn_player(multiplayer.get_unique_id())


func _on_session_ended() -> void:
	for child: Node in players.get_children():
		child.queue_free()


func _on_peer_connected(id: int) -> void:
	if multiplayer.is_server():
		_spawn_player(id)


func _on_peer_disconnected(id: int) -> void:
	if not multiplayer.is_server():
		return
	var node: Node = players.get_node_or_null(str(id))
	if node != null:
		node.queue_free()


func _spawn_player(id: int) -> void:
	# Name is the peer id: every peer derives the player's authority from it, and
	# the MultiplayerSpawner replicates the node — name and all — to clients.
	var player: Player = _PLAYER_SCENE.instantiate()
	player.name = str(id)
	player.position = _next_spawn_position()
	players.add_child(player)


func _next_spawn_position() -> Vector3:
	if spawn_points == null or spawn_points.get_child_count() == 0:
		return Vector3.ZERO
	var index: int = _next_spawn % spawn_points.get_child_count()
	_next_spawn += 1
	var marker: Node3D = spawn_points.get_child(index) as Node3D
	return marker.position
