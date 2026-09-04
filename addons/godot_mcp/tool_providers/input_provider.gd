@tool
## Input simulation tool provider — 9 tools for simulating input in running games.
class_name InputProvider
extends MCPNodeToolProviderBase

const INPUT_CAPTURE_NAME := "mcp_input"
const DEFAULT_TIMEOUT_MS := 2000

var _next_request_id: int = 1
var _pending_requests: Dictionary = { }


func get_definitions() -> Array:
	return [
		ToolDefinition.new(
			"simulate_action_press",
			"Press an input action in the running project.",
			{
				"type": "object",
				"properties": {
					"action": {
						"type": "string",
						"description": "Input action name (e.g. ui_accept)",
					},
					"strength": {
						"type": "number",
						"description": "Action strength 0.0-1.0 (default: 1.0)",
					},
				},
				"required": ["action"],
			},
			"simulate_action_press",
		),
		ToolDefinition.new(
			"simulate_action_release",
			"Release an input action.",
			{
				"type": "object",
				"properties": {
					"action": { "type": "string", "description": "Input action name" },
				},
				"required": ["action"],
			},
			"simulate_action_release",
		),
		ToolDefinition.new(
			"simulate_action_tap",
			"Tap an input action (press then release).",
			{
				"type": "object",
				"properties": {
					"action": {
						"type": "string",
						"description": "Input action name",
					},
					"duration_ms": {
						"type": "number",
						"description": "Duration in ms (default: 100)",
					},
				},
				"required": ["action"],
			},
			"simulate_action_tap",
		),
		ToolDefinition.new(
			"simulate_mouse_click",
			"Simulate a mouse click at coordinates.",
			{
				"type": "object",
				"properties": {
					"x": {
						"type": "number",
						"description": "X coordinate",
					},
					"y": {
						"type": "number",
						"description": "Y coordinate",
					},
					"button": {
						"type": "string",
						"description": "left, right, or middle (default: left)",
					},
					"double_click": {
						"type": "boolean",
						"description": "Double click (default: false)",
					},
				},
				"required": ["x", "y"],
			},
			"simulate_mouse_click",
		),
		ToolDefinition.new(
			"simulate_mouse_move",
			"Move the mouse to coordinates.",
			{
				"type": "object",
				"properties": {
					"x": { "type": "number", "description": "X coordinate" },
					"y": { "type": "number", "description": "Y coordinate" },
				},
				"required": ["x", "y"],
			},
			"simulate_mouse_move",
		),
		ToolDefinition.new(
			"simulate_drag",
			"Simulate a mouse drag from start to end.",
			{
				"type": "object",
				"properties": {
					"start_x": { "type": "number" },
					"start_y": { "type": "number" },
					"end_x": { "type": "number" },
					"end_y": { "type": "number" },
					"duration_ms": {
						"type": "number",
						"description": "Duration in ms (default: 200)",
					},
					"steps": {
						"type": "number",
						"description": "Number of intermediate steps (default: 10)",
					},
					"button": {
						"type": "string",
						"description": "left, right, or middle (default: left)",
					},
				},
				"required": ["start_x", "start_y", "end_x", "end_y"],
			},
			"simulate_drag",
		),
		ToolDefinition.new(
			"simulate_key_press",
			"Simulate a key press.",
			{
				"type": "object",
				"properties": {
					"key": {
						"type": "string",
						"description": "Key identifier",
					},
					"duration_ms": {
						"type": "number",
						"description": "Duration in ms (default: 100)",
					},
					"modifiers": { "type": "object", "description": "Modifier keys" },
				},
				"required": ["key"],
			},
			"simulate_key_press",
		),
		ToolDefinition.new(
			"simulate_input_sequence",
			"Simulate a sequence of input events.",
			{
				"type": "object",
				"properties": {
					"sequence": { "type": "array", "description": "Array of input event objects" },
				},
				"required": ["sequence"],
			},
			"simulate_input_sequence",
		),
		ToolDefinition.new(
			"get_input_actions",
			"Get available input actions.",
			{
				"type": "object",
				"properties": { },
			},
			"get_input_actions",
		),
	]


func execute_tool(tool_name: String, params: Dictionary) -> Dictionary:
	match tool_name:
		"simulate_action_press":
			return await _action_press(params)
		"simulate_action_release":
			return await _action_release(params)
		"simulate_action_tap":
			return await _action_tap(params)
		"simulate_mouse_click":
			return await _mouse_click(params)
		"simulate_mouse_move":
			return await _mouse_move(params)
		"simulate_drag":
			return await _drag(params)
		"simulate_key_press":
			return await _key_press(params)
		"simulate_input_sequence":
			return await _input_sequence(params)
		"get_input_actions":
			return await _get_actions()
	return _error("Unknown tool: %s" % tool_name)


# ---------------------------------------------------------------------------
# Per-tool handlers
# ---------------------------------------------------------------------------
func _action_press(params: Dictionary) -> Dictionary:
	var action := str(params.get("action", ""))
	if action.is_empty():
		return _error("Action name is required")
	var r := await _send_input_cmd("action_press", [action, float(params.get("strength", 1.0))])
	return _error(r["error"]) if r.has("error") else _ok(r)


func _action_release(params: Dictionary) -> Dictionary:
	var action := str(params.get("action", ""))
	if action.is_empty():
		return _error("Action name is required")
	var r := await _send_input_cmd("action_release", [action])
	return _error(r["error"]) if r.has("error") else _ok(r)


func _action_tap(params: Dictionary) -> Dictionary:
	var action := str(params.get("action", ""))
	if action.is_empty():
		return _error("Action name is required")
	var r := await _send_input_cmd("action_tap", [action, int(params.get("duration_ms", 100))])
	return _error(r["error"]) if r.has("error") else _ok(r)


func _mouse_click(params: Dictionary) -> Dictionary:
	var btn_str := str(params.get("button", "left")).to_lower()
	var btn := MOUSE_BUTTON_LEFT
	if btn_str == "right":
		btn = MOUSE_BUTTON_RIGHT
	elif btn_str == "middle":
		btn = MOUSE_BUTTON_MIDDLE
	var opts := {
		"x": float(params.get("x", 0)),
		"y": float(params.get("y", 0)),
		"button": btn,
		"double_click": bool(params.get("double_click", false)),
	}
	var r := await _send_input_cmd("mouse_click", [opts])
	return _error(r["error"]) if r.has("error") else _ok(r)


func _mouse_move(params: Dictionary) -> Dictionary:
	var opts := { "x": float(params.get("x", 0)), "y": float(params.get("y", 0)) }
	var r := await _send_input_cmd("mouse_move", [opts])
	return _error(r["error"]) if r.has("error") else _ok(r)


func _drag(params: Dictionary) -> Dictionary:
	var btn_str := str(params.get("button", "left")).to_lower()
	var btn := MOUSE_BUTTON_LEFT
	if btn_str == "right":
		btn = MOUSE_BUTTON_RIGHT
	elif btn_str == "middle":
		btn = MOUSE_BUTTON_MIDDLE
	var opts := {
		"start_x": float(params.get("start_x", 0)),
		"start_y": float(params.get("start_y", 0)),
		"end_x": float(params.get("end_x", 0)),
		"end_y": float(params.get("end_y", 0)),
		"duration_ms": int(params.get("duration_ms", 200)),
		"steps": int(params.get("steps", 10)),
		"button": btn,
	}
	var timeout := int(params.get("duration_ms", 200)) + 1000
	var r := await _send_input_cmd("drag", [opts], timeout)
	return _error(r["error"]) if r.has("error") else _ok(r)


func _key_press(params: Dictionary) -> Dictionary:
	var key := str(params.get("key", ""))
	if key.is_empty():
		return _error("Key is required")
	var mods := params.get("modifiers", { })
	if typeof(mods) != TYPE_DICTIONARY:
		mods = { }
	var opts := {
		"key": key,
		"duration_ms": int(params.get("duration_ms", 100)),
		"modifiers": mods,
	}
	var r := await _send_input_cmd("key_press", [opts])
	return _error(r["error"]) if r.has("error") else _ok(r)


func _input_sequence(params: Dictionary) -> Dictionary:
	var seq := params.get("sequence", [])
	if typeof(seq) != TYPE_ARRAY:
		return _error("Sequence must be an array")
	if seq.is_empty():
		return _error("Sequence cannot be empty")
	var total_wait := 0
	for step in seq:
		if typeof(step) == TYPE_DICTIONARY:
			total_wait += int(step.get("duration_ms", 100))
	var r := await _send_input_cmd("input_sequence", [seq], total_wait + 2000)
	return _error(r["error"]) if r.has("error") else _ok(r)


func _get_actions() -> Dictionary:
	var r := await _send_input_cmd("get_input_actions", [])
	return _error(r["error"]) if r.has("error") else _ok(r)


# ---------------------------------------------------------------------------
# Core input command sender
# ---------------------------------------------------------------------------
func _send_input_cmd(action: String, data: Array, timeout: int = DEFAULT_TIMEOUT_MS) -> Dictionary:
	var rb = _get_runtime_bridge()
	if rb == null:
		return { "error": "Runtime debugger bridge not available. Ensure the project is running." }

	var sessions = rb.get_sessions()
	var active_session = null
	var session_id := -1
	for i in range(sessions.size()):
		var s = sessions[i]
		if s and s.has_method("is_active") and s.is_active():
			active_session = s
			session_id = i
			break
	if active_session == null:
		return { "error": "No active runtime session. Start the project with debugger attached." }

	var req_id := _next_request_id
	_next_request_id += 1
	var payload := Array()
	payload.append(req_id)
	for item in data:
		payload.append(item)

	_pending_requests[req_id] = {
		"session_id": session_id,
		"action": action,
		"timestamp": Time.get_ticks_msec(),
	}
	var msg_name := "%s:%s" % [INPUT_CAPTURE_NAME, action]
	active_session.send_message(msg_name, payload)

	var deadline := Time.get_ticks_msec() + timeout
	var result: Dictionary = { }
	while Time.get_ticks_msec() < deadline:
		if _has_input_result(session_id, req_id):
			result = _take_input_result(session_id, req_id)
			break
		if get_tree():
			await get_tree().process_frame
		else:
			break

	_pending_requests.erase(req_id)
	if result.is_empty():
		return { "error": "Input command timed out. Ensure the game has the MCP input handler." }
	return result


func _has_input_result(session_id: int, request_id: int) -> bool:
	var rb = _get_runtime_bridge()
	if rb == null:
		return false
	if rb.has_method("has_input_result"):
		return rb.has_input_result(session_id, request_id)
	var sd = rb.get("_sessions")
	if sd and sd.has(session_id):
		var state: Dictionary = sd[session_id]
		return state.get("input_results", { }).has(request_id)
	return false


func _take_input_result(session_id: int, request_id: int) -> Dictionary:
	var rb = _get_runtime_bridge()
	if rb == null:
		return { }
	if rb.has_method("take_input_result"):
		return rb.take_input_result(session_id, request_id)
	var sd = rb.get("_sessions")
	if sd and sd.has(session_id):
		var state: Dictionary = sd[session_id]
		var results: Dictionary = state.get("input_results", { })
		if results.has(request_id):
			var r: Dictionary = results[request_id]
			results.erase(request_id)
			state["input_results"] = results
			sd[session_id] = state
			return r
	return { }
