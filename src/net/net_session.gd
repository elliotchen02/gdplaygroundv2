class_name NetSession
extends Node

## Owns the multiplayer session lifecycle: standing up, connecting, and tearing
## down an ENet peer. Spawning and gameplay live elsewhere; this node only brings
## the transport up and reports when a session begins or ends, so a future UI
## menu and the command line drive it through the very same methods.

## A peer became active — a server started or a client connected.
signal session_started
## The peer was torn down; multiplayer is back to a single local instance.
signal session_ended

## ENet port used when the command line omits one.
const DEFAULT_PORT: int = 24545
## Highest number of clients this scaffolding server accepts.
const MAX_CLIENTS: int = 7

@export_group("Tuning")
## Address a valueless `--join` or a bare `join()` falls back to.
@export var default_address: String = "127.0.0.1"


func _ready() -> void:
	# Defer so every sibling's `_ready` — and the signal connections made there —
	# runs before a command-line session can fire `session_started`.
	_apply_command_line.call_deferred()


## Starts an ENet server on `port`. Returns `OK` or a Godot error code.
func host(port: int = DEFAULT_PORT) -> Error:
	var peer: ENetMultiplayerPeer = ENetMultiplayerPeer.new()
	var err: Error = peer.create_server(port, MAX_CLIENTS)
	if err != OK:
		push_error("NetSession: could not host on port %d (error %d)." % [port, err])
		return err
	multiplayer.multiplayer_peer = peer
	session_started.emit()
	return OK


## Connects to an ENet server. Returns `OK` or a Godot error code.
func join(address: String = "", port: int = DEFAULT_PORT) -> Error:
	var resolved: String = address if not address.is_empty() else default_address
	var peer: ENetMultiplayerPeer = ENetMultiplayerPeer.new()
	var err: Error = peer.create_client(resolved, port)
	if err != OK:
		push_error("NetSession: could not join %s:%d (error %d)." % [resolved, port, err])
		return err
	multiplayer.multiplayer_peer = peer
	session_started.emit()
	return OK


## Tears the peer down and returns to a local, single-instance state.
func leave() -> void:
	if multiplayer.multiplayer_peer == null:
		return
	multiplayer.multiplayer_peer.close()
	multiplayer.multiplayer_peer = null
	session_ended.emit()


func _apply_command_line() -> void:
	var args: PackedStringArray = OS.get_cmdline_args() + OS.get_cmdline_user_args()
	var port: int = DEFAULT_PORT
	for arg: String in args:
		if arg.begins_with("--port="):
			port = arg.trim_prefix("--port=").to_int()
	for arg: String in args:
		if arg == "--host":
			host(port)
			return
		if arg == "--join":
			join("", port)
			return
		if arg.begins_with("--join="):
			join(arg.trim_prefix("--join="), port)
			return
	# Default to hosting when no network CLI argument is provided, so pressing
	# F5 or running the main scene directly starts a local session and spawns a player.
	host(port)
