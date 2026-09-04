@tool
## MCP Protocol Core — JSON-RPC 2.0 engine, tool/resource registry.
##
## Handles the MCP protocol lifecycle: initialize, tools/list,
## tools/call, resources/list, resources/read. Tool calls are routed
## directly to tool provider instances (self-contained schema + logic).
class_name MCPServerCore
extends Node

# ---------------------------------------------------------------------------
# Signals
# ---------------------------------------------------------------------------
## Emitted when a JSON-RPC response is ready to be sent back via HTTP
signal jsonrpc_response(response: Dictionary)

## Emitted when an SSE notification should be broadcast
signal sse_notification(notification: Dictionary)

# ---------------------------------------------------------------------------
# State
# ---------------------------------------------------------------------------
var is_initialized: bool = false
var client_capabilities: Dictionary = { }
var server_capabilities: Dictionary = {
	"tools": { },
	"resources": { },
}

# Tracks which SSE client performed the initialize (for per-session reset).
var _initialized_client_id: int = -1

# Internal — tool registry
var _command_handler = null # Kept for backward compat during transition
var _tools: Array[ToolDefinition] = []
var _resources: Array = []
var _tool_map: Dictionary = { } # tool_name → ToolDefinition
var _provider_map: Dictionary = { } # tool_name → MCPToolProviderBase (or MCPNodeToolProviderBase)
var _pending_async_results: Dictionary = { } # tool_name → {req_id, coro} for async resolution


# ---------------------------------------------------------------------------
# Lifecycle
# ---------------------------------------------------------------------------
func _ready() -> void:
	_register_builtin_tools()


## Set the command handler reference. Deprecated — tools are now called directly.
## Kept for backward compatibility during transition.
func set_command_handler(handler) -> void:
	_command_handler = handler


## Connect to an MCPSse instance to track client disconnects.
func bind_sse(sse: MCPSse) -> void:
	if sse:
		sse.sse_client_disconnected.connect(_on_sse_client_disconnected)


func _on_sse_client_disconnected(client_id: int) -> void:
	if client_id == _initialized_client_id:
		is_initialized = false
		_initialized_client_id = -1
		client_capabilities = { }
		return

	if sse_client_count() == 0:
		is_initialized = false
		_initialized_client_id = -1
		client_capabilities = { }


func sse_client_count() -> int:
	var parent_node = get_parent()
	if parent_node:
		for child in parent_node.get_children():
			if child is MCPSse:
				return child.get_client_count()
	return 0


func _get_active_sse_client_id() -> int:
	var parent_node = get_parent()
	if parent_node:
		for child in parent_node.get_children():
			if child is MCPSse:
				var ids: Array = child.get_client_ids()
				if not ids.is_empty():
					return ids[-1]
	return -1


func _is_sse_client_connected(client_id: int) -> bool:
	var parent_node = get_parent()
	if parent_node:
		for child in parent_node.get_children():
			if child is MCPSse:
				return child.is_client_connected(client_id)
	return false

# ---------------------------------------------------------------------------
# MCP Method Handlers
# ---------------------------------------------------------------------------


## Handle an incoming MCP JSON-RPC request. Returns the response dict,
## or null for notifications (no response expected).
func handle_mcp_request(request: Dictionary) -> Variant:
	var method: String = request.get("method", "")
	var params: Dictionary = request.get("params", { })
	var req_id = request.get("id", null)

	var is_notification := req_id == null

	match method:
		"initialize":
			return _handle_initialize(params, req_id)
		"initialized":
			_handle_initialized_notification(params)
			if is_notification:
				return null
			return MCPTypes.make_success_response(req_id, { })
		"tools/list":
			return _handle_tools_list(params, req_id)
		"tools/call":
			return _handle_tools_call(params, req_id)
		"resources/list":
			return _handle_resources_list(params, req_id)
		"resources/read":
			return _handle_resources_read(params, req_id)
		"ping":
			return MCPTypes.make_success_response(req_id, { })
		_:
			if is_notification:
				return null
			return MCPTypes.make_error_response(
				req_id,
				MCPTypes.ErrorCode.METHOD_NOT_FOUND,
				"Unknown method: %s" % method,
			)


# ---------------------------------------------------------------------------
# Initialize
# ---------------------------------------------------------------------------
func _handle_initialize(params: Dictionary, req_id: Variant) -> Dictionary:
	if is_initialized and _initialized_client_id >= 0:
		if not _is_sse_client_connected(_initialized_client_id):
			is_initialized = false
			_initialized_client_id = -1
			client_capabilities = { }

	if is_initialized:
		return MCPTypes.make_success_response(
			req_id,
			{
				"protocolVersion": MCPTypes.PROTOCOL_VERSION,
				"capabilities": server_capabilities,
				"serverInfo": {
					"name": "godot-mcp",
					"version": "1.1.0",
				},
			},
		)

	client_capabilities = params.get("capabilities", { })
	is_initialized = true
	_initialized_client_id = _get_active_sse_client_id()

	return MCPTypes.make_success_response(
		req_id,
		{
			"protocolVersion": MCPTypes.PROTOCOL_VERSION,
			"capabilities": server_capabilities,
			"serverInfo": {
				"name": "godot-mcp",
				"version": "1.1.0",
			},
		},
	)


func _handle_initialized_notification(_params: Dictionary) -> void:
	is_initialized = true


# ---------------------------------------------------------------------------
# Tools — list
# ---------------------------------------------------------------------------
func _handle_tools_list(_params: Dictionary, req_id: Variant) -> Dictionary:
	var tools_list: Array[Dictionary] = []
	for tool in _tools:
		tools_list.append(
			{
				"name": tool.name,
				"description": tool.description,
				"inputSchema": tool.input_schema,
			},
		)

	return MCPTypes.make_success_response(req_id, { "tools": tools_list })


# ---------------------------------------------------------------------------
# Tools — call
# ---------------------------------------------------------------------------
func _handle_tools_call(params: Dictionary, req_id: Variant) -> Variant:
	var name: String = params.get("name", "")
	var arguments: Dictionary = params.get("arguments", { })

	if not _provider_map.has(name):
		return MCPTypes.make_error_response(
			req_id,
			MCPTypes.ErrorCode.TOOL_NOT_FOUND,
			"Tool not found: %s" % name,
		)

	var provider = _provider_map[name]

	if not provider.has_method("execute"):
		return MCPTypes.make_error_response(
			req_id,
			MCPTypes.ErrorCode.INTERNAL_ERROR,
			"Tool provider missing execute(): %s" % name,
		)

	# Call execute — may return Dictionary (sync) or awaitable (coroutine)
	var result
	if provider is MCPNodeToolProviderBase:
		result = provider.execute_tool(name, arguments)
	else:
		result = provider.execute(arguments)

	# Sync result — format and return immediately
	if result is Dictionary:
		return _format_tool_result(result, name, req_id)

	# Async result (coroutine) — schedule resolution, return 202 Accepted
	_pending_async_results[name] = { "req_id": req_id, "coro": result }
	_resolve_async(name)
	return null


## Format a tool execution result into a JSON-RPC response.
func _format_tool_result(result: Dictionary, _tool_name: String, req_id: Variant):
	if result.get("ok", false):
		return MCPTypes.make_success_response(
			req_id,
			{
				"content": [
					{
						"type": "text",
						"text": JSON.stringify(result.get("data", { })),
					},
				],
			},
		)
	return MCPTypes.make_error_response(
		req_id,
		MCPTypes.ErrorCode.TOOL_EXECUTION_ERROR,
		result.get("error", "Tool execution failed"),
	)


## Resolve an async tool call in the background. This is a coroutine
## that awaits the result and emits the JSON-RPC response when done.
func _resolve_async(tool_name: String) -> void:
	if not _pending_async_results.has(tool_name):
		return
	var entry: Dictionary = _pending_async_results[tool_name]
	var coro = entry["coro"]
	var req_id = entry["req_id"]
	_pending_async_results.erase(tool_name)
	# Await the coroutine result
	var result = await coro
	if not result is Dictionary:
		jsonrpc_response.emit(
			MCPTypes.make_error_response(
				req_id,
				MCPTypes.ErrorCode.TOOL_EXECUTION_ERROR,
				"Async tool %s returned unexpected type" % tool_name,
			),
		)
		return
	var resp = _format_tool_result(result, tool_name, req_id)
	if resp != null:
		jsonrpc_response.emit(resp)


# ---------------------------------------------------------------------------
# Resources
# ---------------------------------------------------------------------------
func _handle_resources_list(_params: Dictionary, req_id: Variant) -> Dictionary:
	var resources_list: Array[Dictionary] = []
	for res in _resources:
		resources_list.append(res)

	return MCPTypes.make_success_response(req_id, { "resources": resources_list })


func _handle_resources_read(_params: Dictionary, req_id: Variant) -> Variant:
	var uri: String = _params.get("uri", "")
	return MCPTypes.make_error_response(
		req_id,
		MCPTypes.ErrorCode.RESOURCE_NOT_FOUND,
		"Resource not found: %s" % uri,
	)

# ---------------------------------------------------------------------------
# Tool Registration
# ---------------------------------------------------------------------------


## Register a tool provider (definition + instance).
## Accepts both RefCounted (MCPToolProviderBase) and Node (MCPNodeToolProviderBase) providers.
func register_tool(tool: ToolDefinition, provider: Object) -> void:
	_tools.append(tool)
	_tool_map[tool.name] = tool
	_provider_map[tool.name] = provider


## Register a resource definition.
func register_resource(resource: Dictionary) -> void:
	_resources.append(resource)


# ---------------------------------------------------------------------------
# Built-in tools — dynamically load from tool_providers/
# ---------------------------------------------------------------------------
func _register_builtin_tools() -> void:
	_load_tool_providers()


## Dynamically load all tool provider scripts from the tool_providers/ directory.
func _load_tool_providers() -> void:
	var dir := "res://addons/godot_mcp/tool_providers/"
	var da := DirAccess.open(dir)
	if da == null:
		push_error("Could not open tool_providers directory: " + dir)
		return

	da.list_dir_begin()
	var file_name := da.get_next()
	var loaded := 0
	var skipped := 0

	while not file_name.is_empty():
		if (
				file_name.ends_with(".gd")
				and file_name != ".gd"
				and file_name != "tool_provider_base.gd"
				and file_name != "node_tool_provider_base.gd"
		):
			var full_path := dir + file_name
			var count := _try_load_tool_provider(full_path)
			loaded += count
			if count == 0:
				skipped += 1
		file_name = da.get_next()

	da.list_dir_end()
	print("MCP Core: loaded %d tools, skipped %d files" % [loaded, skipped])


## Attempt to load a single tool provider script. Returns count of tools registered.
## Supports both RefCounted (one tool per file) and Node-based (multi-tool) providers.
func _try_load_tool_provider(path: String) -> int:
	if not ResourceLoader.exists(path):
		push_warning("Tool provider not found: " + path)
		return 0

	var script := load(path) as GDScript
	if script == null:
		push_warning("Failed to load tool provider: " + path)
		return 0

	if not script.can_instantiate():
		push_warning("Tool provider has compile errors, skipping: " + path)
		return 0

	var instance = script.new()
	if instance == null:
		push_warning("Could not instantiate tool provider: " + path)
		return 0

	# Node-based provider (multi-tool)
	if instance is MCPNodeToolProviderBase:
		if not instance.has_method("get_definitions"):
			push_warning("Node tool provider missing get_definitions(): " + path)
			return 0
		add_child(instance)
		var defs: Array = instance.get_definitions()
		var count := 0
		for def in defs:
			if def is ToolDefinition:
				register_tool(def, instance)
				count += 1
		return count

	# RefCounted provider (single tool)
	if not instance.has_method("get_definition"):
		push_warning("Tool provider missing get_definition(): " + path)
		return 0

	var def: ToolDefinition = instance.get_definition()
	if def == null:
		push_warning("Tool provider returned null definition: " + path)
		return 0

	register_tool(def, instance)
	return 1
