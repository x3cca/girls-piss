@tool
## Debugger tool provider — 12 tools for Godot debugger control.
class_name DebuggerProvider
extends MCPNodeToolProviderBase

var _debugger_bridge = null


func _ready():
	_debugger_bridge = _get_debugger_bridge()
	if _debugger_bridge:
		_debugger_bridge.breakpoint_hit.connect(_on_breakpoint_hit)
		_debugger_bridge.execution_paused.connect(_on_execution_paused)
		_debugger_bridge.execution_resumed.connect(_on_execution_resumed)
		_debugger_bridge.stack_frame_changed.connect(_on_stack_frame_changed)
		_debugger_bridge.breakpoint_set.connect(_on_breakpoint_set)
		_debugger_bridge.breakpoint_removed.connect(_on_breakpoint_removed)


func get_definitions() -> Array:
	return [
		ToolDefinition.new(
			"debugger_set_breakpoint",
			"Set a breakpoint at a script line.",
			{
				"type": "object",
				"properties": {
					"script_path": { "type": "string", "description": "Path to the script file" },
					"line": { "type": "number", "description": "Line number for the breakpoint" },
				},
				"required": ["script_path", "line"],
			},
			"debugger_set_breakpoint",
		),
		ToolDefinition.new(
			"debugger_remove_breakpoint",
			"Remove a breakpoint.",
			{
				"type": "object",
				"properties": {
					"script_path": { "type": "string", "description": "Path to the script file" },
					"line": { "type": "number", "description": "Line number of the breakpoint" },
				},
				"required": ["script_path", "line"],
			},
			"debugger_remove_breakpoint",
		),
		ToolDefinition.new(
			"debugger_get_breakpoints",
			"Get all breakpoints.",
			{
				"type": "object",
				"properties": { },
			},
			"debugger_get_breakpoints",
		),
		ToolDefinition.new(
			"debugger_clear_all_breakpoints",
			"Clear all breakpoints.",
			{
				"type": "object",
				"properties": { },
			},
			"debugger_clear_all_breakpoints",
		),
		ToolDefinition.new(
			"debugger_pause_execution",
			"Pause execution.",
			{
				"type": "object",
				"properties": { },
			},
			"debugger_pause_execution",
		),
		ToolDefinition.new(
			"debugger_resume_execution",
			"Resume execution.",
			{
				"type": "object",
				"properties": { },
			},
			"debugger_resume_execution",
		),
		ToolDefinition.new(
			"debugger_step_over",
			"Step over the current line.",
			{
				"type": "object",
				"properties": { },
			},
			"debugger_step_over",
		),
		ToolDefinition.new(
			"debugger_step_into",
			"Step into the current function.",
			{
				"type": "object",
				"properties": { },
			},
			"debugger_step_into",
		),
		ToolDefinition.new(
			"debugger_get_call_stack",
			"Get the current call stack.",
			{
				"type": "object",
				"properties": {
					"session_id": {
						"type": "string",
						"description": "Optional session identifier",
					},
				},
			},
			"debugger_get_call_stack",
		),
		ToolDefinition.new(
			"debugger_get_current_state",
			"Get the current debugger state.",
			{
				"type": "object",
				"properties": { },
			},
			"debugger_get_current_state",
		),
		ToolDefinition.new(
			"debugger_enable_events",
			"Enable debugger events for this client.",
			{
				"type": "object",
				"properties": { },
			},
			"debugger_enable_events",
		),
		ToolDefinition.new(
			"debugger_disable_events",
			"Disable debugger events for this client.",
			{
				"type": "object",
				"properties": { },
			},
			"debugger_disable_events",
		),
	]


func execute_tool(tool_name: String, params: Dictionary) -> Dictionary:
	match tool_name:
		"debugger_set_breakpoint":
			return _do_breakpoint_op(params, "set_breakpoint", "Failed to set breakpoint")
		"debugger_remove_breakpoint":
			return _do_breakpoint_op(params, "remove_breakpoint", "Failed to remove breakpoint")
		"debugger_get_breakpoints":
			return _get_breakpoints()
		"debugger_clear_all_breakpoints":
			return _call_bridge("clear_all_breakpoints", "Failed to clear all breakpoints")
		"debugger_pause_execution":
			return _call_bridge("pause_execution", "Failed to pause execution")
		"debugger_resume_execution":
			return _call_bridge("resume_execution", "Failed to resume execution")
		"debugger_step_over":
			return _call_bridge("step_over", "Failed to step over")
		"debugger_step_into":
			return _call_bridge("step_into", "Failed to step into")
		"debugger_get_call_stack":
			return await _get_call_stack(params)
		"debugger_get_current_state":
			return _get_current_state()
		"debugger_enable_events":
			return _enable_events()
		"debugger_disable_events":
			return _disable_events()
	return _error("Unknown tool: %s" % tool_name)


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------
func _ensure_bridge() -> bool:
	if _debugger_bridge:
		return true
	_debugger_bridge = _get_debugger_bridge()
	return _debugger_bridge != null


func _normalize_script_path(sp: String) -> String:
	if sp.is_empty():
		return sp
	if sp.begins_with("res://"):
		return sp
	if sp.begins_with("/"):
		return "res://" + sp.substr(1)
	return "res://" + sp


func _do_breakpoint_op(params: Dictionary, method: String, fail_msg: String) -> Dictionary:
	if not _ensure_bridge():
		return _error("Debugger bridge not available")
	var sp: String = params.get("script_path", "")
	var line: int = params.get("line", -1)
	if sp.is_empty():
		return _error("script_path parameter is required")
	if line < 0:
		return _error("line parameter must be >= 0")
	sp = _normalize_script_path(sp)
	var result = _debugger_bridge.call(method, sp, line)
	if result is Dictionary and not result.get("success", true):
		return _error(result.get("message", fail_msg))
	return _ok(result)


func _call_bridge(method: String, fail_msg: String) -> Dictionary:
	if not _ensure_bridge():
		return _error("Debugger bridge not available")
	var result = _debugger_bridge.call(method)
	if result is Dictionary and not result.get("success", true):
		return _error(result.get("message", fail_msg))
	return _ok(result)


func _get_breakpoints() -> Dictionary:
	if not _ensure_bridge():
		return _error("Debugger bridge not available")
	return _ok(_debugger_bridge.get_breakpoints())


func _get_call_stack(params: Dictionary) -> Dictionary:
	if not _ensure_bridge():
		return _error("Debugger bridge not available")
	var session_id = null
	if params.has("session_id"):
		var raw = params["session_id"]
		if typeof(raw) == TYPE_INT:
			session_id = raw
		elif typeof(raw) == TYPE_FLOAT:
			session_id = int(raw)
		elif typeof(raw) == TYPE_STRING:
			var s: String = raw
			session_id = int(s) if s.is_valid_int() else s.strip_edges()
	var result = await _debugger_bridge.get_call_stack(session_id)
	if typeof(result) == TYPE_DICTIONARY and result.has("error"):
		var err_msg = str(result.get("message", result.get("error", "unknown")))
		return _error("Failed to capture call stack: %s" % err_msg)
	return _ok(result)


func _get_current_state() -> Dictionary:
	if not _ensure_bridge():
		return _error("Debugger bridge not available")
	return _ok(_debugger_bridge.get_current_state())


func _enable_events() -> Dictionary:
	if not _ensure_bridge():
		return _error("Debugger bridge not available")
	return _ok({ "message": "Debugger events enabled", "client_id": 0 })


func _disable_events() -> Dictionary:
	if not _ensure_bridge():
		return _error("Debugger bridge not available")
	return _ok({ "message": "Debugger events disabled" })


# Signal handlers
func _on_breakpoint_hit(id: int, sp: String, line: int, _info: Dictionary) -> void:
	print("Breakpoint hit in session %s at %s:%d" % [id, sp, line])


func _on_execution_paused(id: int, reason: String) -> void:
	print("Execution paused in session %s: %s" % [id, reason])


func _on_execution_resumed(id: int) -> void:
	print("Execution resumed in session %s" % id)


func _on_stack_frame_changed(id: int, _info: Dictionary) -> void:
	print("Stack frame changed in session %s" % id)


func _on_breakpoint_set(_id: int, sp: String, line: int, ok: bool) -> void:
	print("Breakpoint %s at %s:%d" % ["set" if ok else "failed", sp, line])


func _on_breakpoint_removed(_id: int, sp: String, line: int, ok: bool) -> void:
	print("Breakpoint %s at %s:%d" % ["removed" if ok else "failed", sp, line])
