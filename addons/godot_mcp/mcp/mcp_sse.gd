@tool
## Server-Sent Events (SSE) extension for MCP over HTTP.
##
## Manages persistent SSE connections and sends MCP events/notifications
## to connected clients in text/event-stream format.
class_name MCPSse
extends Node

## Emitted when an SSE client disconnects (client_id)
signal sse_client_disconnected(client_id: int)

## SSE keepalive interval in seconds
var keepalive_interval: float = MCPTypes.SSE_KEEPALIVE_INTERVAL

# Active SSE connections: client_id -> StreamPeerTCP
var _sse_clients: Dictionary = { }

# Incremental client ID counter
var _next_client_id: int = 1

# Timer reference for keepalive
var _keepalive_timer: Timer = null

# Proactive polling for dead clients
var _poll_accumulator: float = 0.0
var _poll_interval: float = 0.5


func _ready() -> void:
	_keepalive_timer = Timer.new()
	_keepalive_timer.wait_time = keepalive_interval
	_keepalive_timer.one_shot = false
	_keepalive_timer.timeout.connect(_send_keepalive)
	add_child(_keepalive_timer)
	set_process(true)


## Register a new SSE client connection. Returns the assigned client_id.
func register_client(stream: StreamPeerTCP) -> int:
	var client_id := _next_client_id
	_next_client_id += 1
	_sse_clients[client_id] = stream

	# Send the initial SSE endpoint event (per MCP SSE spec)
	send_sse_event(
		client_id,
		"endpoint",
		{
			"uri": "/mcp",
		},
	)

	# Start keepalive timer on first client
	if _sse_clients.size() == 1:
		_keepalive_timer.start()

	return client_id


## Remove a client (called on disconnect or error)
func unregister_client(client_id: int) -> bool:
	if _sse_clients.has(client_id):
		_sse_clients.erase(client_id)
		sse_client_disconnected.emit(client_id)
		# Stop keepalive timer if no more clients
		if _sse_clients.is_empty():
			_keepalive_timer.stop()
		return true
	return false


## Check if a client is still connected
func is_client_connected(client_id: int) -> bool:
	return _sse_clients.has(client_id)


## Send an SSE event to a specific client
func send_sse_event(client_id: int, event_type: String, data: Variant = null) -> bool:
	if not _sse_clients.has(client_id):
		return false

	var stream: StreamPeerTCP = _sse_clients[client_id]
	stream.poll()

	if stream.get_status() != StreamPeerTCP.STATUS_CONNECTED:
		unregister_client(client_id)
		return false

	var payload := ""
	if event_type != "":
		payload += "event: %s\n" % event_type
	if data != null:
		var json_str := JSON.stringify(data)
		for line in json_str.split("\n"):
			payload += "data: %s\n" % line
	payload += "\n"

	var err := stream.put_data(payload.to_utf8_buffer())
	if err != OK:
		unregister_client(client_id)
		return false

	return true


## Send an MCP JSON-RPC message as an SSE event to a specific client
func send_mcp_message(client_id: int, message: Dictionary) -> bool:
	return send_sse_event(client_id, "message", message)


## Broadcast an MCP JSON-RPC message to all connected SSE clients
func broadcast_mcp_message(message: Dictionary) -> void:
	var disconnected: Array[int] = []
	for cid in _sse_clients.keys():
		if not send_mcp_message(cid, message):
			disconnected.append(cid)
	# Clean up disconnected clients
	for cid in disconnected:
		unregister_client(cid)


## Get the number of connected SSE clients
func get_client_count() -> int:
	return _sse_clients.size()


## Get all connected client IDs
func get_client_ids() -> Array:
	return _sse_clients.keys()


# Send keepalive comments to all connected clients
func _send_keepalive() -> void:
	var disconnected: Array[int] = []
	for cid in _sse_clients.keys():
		var stream: StreamPeerTCP = _sse_clients[cid]
		stream.poll()
		if stream.get_status() != StreamPeerTCP.STATUS_CONNECTED:
			disconnected.append(cid)
			continue
		# Send a keepalive comment line
		var err := stream.put_data(": keepalive\n\n".to_utf8_buffer())
		if err != OK:
			disconnected.append(cid)
	for cid in disconnected:
		unregister_client(cid)


## Proactively poll all SSE clients and unregister dead ones.
## Runs every _poll_interval seconds to catch disconnections quickly
## instead of waiting up to 30s for the keepalive timer.
func _process(delta: float) -> void:
	_poll_accumulator += delta
	if _poll_accumulator < _poll_interval:
		return
	_poll_accumulator = 0.0

	var disconnected: Array[int] = []
	for cid in _sse_clients.keys():
		var stream: StreamPeerTCP = _sse_clients[cid]
		stream.poll()
		if stream.get_status() != StreamPeerTCP.STATUS_CONNECTED:
			disconnected.append(cid)
	for cid in disconnected:
		unregister_client(cid)


## Clean up all connections
func clear_all() -> void:
	for cid in _sse_clients.keys():
		var stream: StreamPeerTCP = _sse_clients[cid]
		if stream and stream.get_status() == StreamPeerTCP.STATUS_CONNECTED:
			stream.disconnect_from_host()
	_sse_clients.clear()
	_keepalive_timer.stop()


func _exit_tree() -> void:
	clear_all()
