extends GdUnitTestSuite

## Unit tests for PlayerNetwork. It takes a body and a peer id and nothing else,
## so the whole network stack drives a bare CharacterBody3D here — no Player, no
## cameras, no InputMap, no floor, and no multiplayer peer. That is the point of
## keeping it in its own scene.
##
## Role is resolved explicitly before the subtree enters the tree, exactly as
## Player does it in `_enter_tree`, which is what lets a test pick a local peer
## id the default MultiplayerAPI would never report.

const _SCENE: PackedScene = preload("res://src/player/player_network.tscn")
const _DELTA: float = 1.0 / 60.0
const _APPROX: Vector3 = Vector3(0.001, 0.001, 0.001)

var _body: CharacterBody3D


## Builds a copy owned by `owner_id` as peer `local_peer_id` sees it. Properties
## are set before the subtree is added, because `_enter_tree` pins authority off
## `owner_id` and never reads it again.
func _make(owner_id: int, local_peer_id: int) -> PlayerNetwork:
	_body = auto_free(CharacterBody3D.new())
	var network: PlayerNetwork = _SCENE.instantiate()
	network.body = _body
	network.owner_id = owner_id
	network.resolve_role(local_peer_id)
	_body.add_child(network)
	add_child(_body)
	return network


func test_peer_owns_the_player_it_was_spawned_for() -> void:
	var network: PlayerNetwork = _make(7, 7)
	assert_int(network.role()).is_equal(PlayerNetwork.Role.OWNER)


func test_server_keeps_a_record_of_another_peers_player() -> void:
	var network: PlayerNetwork = _make(7, PlayerNetwork.SERVER_PEER_ID)
	assert_int(network.role()).is_equal(PlayerNetwork.Role.SERVER_RECORD)


func test_client_observes_another_peers_player() -> void:
	var network: PlayerNetwork = _make(7, 9)
	assert_int(network.role()).is_equal(PlayerNetwork.Role.OBSERVER)


func test_authority_is_pinned_from_owner_id() -> void:
	var network: PlayerNetwork = _make(7, 9)
	# Claims flow up from the owner, accepted state flows down from the server.
	assert_int(network.claim_synchronizer.get_multiplayer_authority()).is_equal(7)
	assert_int(network.state_synchronizer.get_multiplayer_authority()).is_equal(
		PlayerNetwork.SERVER_PEER_ID
	)


func test_owner_mirrors_the_moved_body_into_the_claim_block() -> void:
	var network: PlayerNetwork = _make(7, 7)
	_body.global_position = Vector3(1.0, 2.0, 3.0)
	_body.velocity = Vector3(4.0, 0.0, 5.0)
	_body.rotation.y = 0.75
	network._physics_process(_DELTA)
	assert_vector(network.claimed_position).is_equal_approx(Vector3(1.0, 2.0, 3.0), _APPROX)
	assert_vector(network.claimed_velocity).is_equal_approx(Vector3(4.0, 0.0, 5.0), _APPROX)
	assert_float(network.claimed_yaw).is_equal_approx(0.75, 0.001)
	assert_int(network.claimed_tick).is_equal(1)


func test_owner_ignores_server_state_written_onto_it() -> void:
	# The defect this design exists to prevent: the server broadcasts accepted
	# state to every peer, the owning one included, and an owner that applied it
	# would be dragged back onto a lagged echo of its own claim every tick.
	var network: PlayerNetwork = _make(7, 7)
	_body.global_position = Vector3(0.0, 0.0, -5.0)
	network.net_tick = 99
	network.net_position = Vector3(0.0, 0.0, 0.0)
	network.net_velocity = Vector3.ZERO
	network._physics_process(_DELTA)
	assert_vector(_body.global_position).is_equal_approx(Vector3(0.0, 0.0, -5.0), _APPROX)


func test_server_record_applies_the_claim_and_republishes_it() -> void:
	var network: PlayerNetwork = _make(7, PlayerNetwork.SERVER_PEER_ID)
	network.claimed_tick = 12
	network.claimed_position = Vector3(0.0, 0.0, -8.0)
	network.claimed_velocity = Vector3(0.0, 0.0, -10.0)
	network.claimed_yaw = 1.25
	network._physics_process(_DELTA)
	assert_vector(_body.global_position).is_equal_approx(Vector3(0.0, 0.0, -8.0), _APPROX)
	assert_int(network.net_tick).is_equal(12)
	assert_vector(network.net_position).is_equal_approx(Vector3(0.0, 0.0, -8.0), _APPROX)
	assert_float(network.net_yaw).is_equal_approx(1.25, 0.001)


func test_listen_server_publishes_the_players_it_owns_itself() -> void:
	# A host owns a player and is also the authority observers read from, so
	# nothing else is in a position to publish that player's state.
	var network: PlayerNetwork = _make(PlayerNetwork.SERVER_PEER_ID, PlayerNetwork.SERVER_PEER_ID)
	_body.global_position = Vector3(0.0, 0.0, -3.0)
	network._physics_process(_DELTA)
	assert_int(network.role()).is_equal(PlayerNetwork.Role.OWNER)
	assert_int(network.net_tick).is_equal(1)
	assert_vector(network.net_position).is_equal_approx(Vector3(0.0, 0.0, -3.0), _APPROX)


func test_observer_shows_published_state() -> void:
	var network: PlayerNetwork = _make(7, 9)
	network.net_tick = 4
	network.net_position = Vector3(2.0, 0.0, -6.0)
	network.net_yaw = 0.5
	network._physics_process(_DELTA)
	assert_vector(_body.global_position).is_equal_approx(Vector3(2.0, 0.0, -6.0), _APPROX)
	assert_float(_body.rotation.y).is_equal_approx(0.5, 0.001)


func test_observer_holds_still_until_the_first_snapshot_arrives() -> void:
	# net_tick 0 means nothing has been received; adopting the default would
	# teleport a freshly spawned remote player to the world origin.
	var network: PlayerNetwork = _make(7, 9)
	_body.global_position = Vector3(3.0, 0.1, 0.0)
	network._physics_process(_DELTA)
	assert_vector(_body.global_position).is_equal_approx(Vector3(3.0, 0.1, 0.0), _APPROX)
