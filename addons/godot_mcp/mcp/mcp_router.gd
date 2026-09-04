@tool
## MCP HTTP Router — routes /mcp endpoints for MCP protocol.
##
## Handles:
##   POST /mcp  — JSON-RPC request body, delegates to MCPServerCore
##   GET  /mcp  — SSE (Server-Sent Events) or health check
##
## Extends GodotTPD's HttpRouter to integrate with the HTTP server.
class_name MCPRouter
extends HttpRouter

var _sse: MCPSse = null
var _core: MCPServerCore = null


func _init(path: String, sse: MCPSse, core: MCPServerCore):
	_sse = sse
	_core = core

	# Register event connections
	if _core:
		_core.sse_notification.connect(_on_sse_notification)

	super(
		path,
		{
			"get": _on_get,
			"post": _on_post,
		},
	)


## Handle GET /mcp
func _on_get(request: HttpRequest, response: HttpResponse) -> bool:
	var accept := ""
	if request.headers.has("Accept"):
		accept = request.headers["Accept"]
	elif request.headers.has("accept"):
		accept = request.headers["accept"]

	# Check for SSE request
	if "text/event-stream" in accept:
		return _handle_sse(request, response)

	# Default: health check
	response.json(
		200,
		{
			"status": "ok",
			"server": "godot-mcp",
			"transport": "sse+http",
		},
	)
	return true


## Handle POST /mcp — JSON-RPC request
func _on_post(request: HttpRequest, response: HttpResponse) -> bool:
	# Parse the JSON body
	var body := request.get_body_parsed()
	if body == null or typeof(body) != TYPE_DICTIONARY:
		response.json(
			400,
			MCPTypes.make_error_response(
				null,
				MCPTypes.ErrorCode.PARSE_ERROR,
				"Invalid JSON-RPC request body",
			),
		)
		return true

	# Delegate to core
	var result := _core.handle_mcp_request(body)

	if result != null:
		response.json(200, result)
	else:
		# Notification (no response expected) — return 202 Accepted
		response.send(202, "", "text/plain")

	return true


## Establish an SSE connection for the client.
## Writes the SSE headers, registers the client with MCPSse,
## then keeps the connection alive.
func _handle_sse(_request: HttpRequest, response: HttpResponse) -> bool:
	var stream: StreamPeerTCP = response.client
	if not stream:
		response.send(500, "Internal error: no client stream")
		return true

	# Write SSE response headers directly to the stream
	# We use send_raw to avoid Connection: close from standard send()
	var headers := PackedByteArray()
	headers += "HTTP/1.1 200 OK\r\n".to_utf8_buffer()
	headers += "Content-Type: text/event-stream\r\n".to_utf8_buffer()
	headers += "Cache-Control: no-cache\r\n".to_utf8_buffer()
	headers += "Connection: keep-alive\r\n".to_utf8_buffer()
	headers += "Access-Control-Allow-Origin: *\r\n".to_utf8_buffer()
	headers += "\r\n".to_utf8_buffer()

	var err := stream.put_data(headers)
	if err != OK:
		response.send(500, "Failed to write SSE headers")
		return true

	# Register with SSE manager
	var client_id := _sse.register_client(stream)

	# Signal to the server to NOT close this connection
	# (HttpServer would normally close it after send())
	# We handle the SSE lifecycle entirely in MCPSse
	return true


## Forward SSE notifications from core to all connected clients
func _on_sse_notification(notification: Dictionary) -> void:
	if _sse:
		_sse.broadcast_mcp_message(notification)
