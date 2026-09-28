@tool
## Runtime tool provider — two-step scene snapshots and expression evaluation.
class_name RuntimeProvider
extends MCPNodeToolProviderBase

func get_definitions() -> Array:
	return [
		ToolDefinition.new(
			"get_runtime_scene_structure",
			"Get the scene tree structure from the running project.",
			{
				"type": "object",
				"properties": {
					"include_properties": { "type": "boolean" },
					"include_scripts": { "type": "boolean" },
					"max_depth": { "type": "number" },
					"timeout_ms": {
						"type": "number",
						"description": "Polling timeout in ms (default 3000)",
					},
				},
			},
			"get_runtime_scene_structure",
		),
		ToolDefinition.new(
			"evaluate_runtime",
			"Evaluate a GDScript expression in the running project.",
			{
				"type": "object",
				"properties": {
					"expression": {
						"type": "string",
						"description": "GDScript expression to evaluate",
					},
					"code": { "type": "string", "description": "Alternative to expression" },
					"node_path": { "type": "string", "description": "Optional context node path" },
					"capture_prints": {
						"type": "boolean",
						"description": "Capture print() output (default: true)",
					},
					"timeout_ms": {
						"type": "number",
						"description": "Timeout in ms (default 3000)",
					},
					"session_id": { "type": "number" },
					"request_id": { "type": "number" },
				},
				"required": [],
			},
			"evaluate_runtime",
		),
	]


func execute_tool(tool_name: String, params: Dictionary) -> Dictionary:
	match tool_name:
		"get_runtime_scene_structure":
			return _runtime_scene(params)
		"evaluate_runtime":
			return _eval_runtime(params)
	return _error("Unknown tool: %s" % tool_name)


func _runtime_scene(params: Dictionary) -> Dictionary:
	var rb = _get_runtime_bridge()
	if rb == null:
		return _error("Runtime debugger bridge not available. Ensure the project is running.")
	var req = rb.request_runtime_scene_snapshot()
	if req.has("error"):
		return _ok(req)
	var sid: int = req.get("session_id", -1)
	var opts := {
		"include_properties": params.get("include_properties", false),
		"include_scripts": params.get("include_scripts", false),
	}
	var snap: Dictionary = rb.build_runtime_snapshot(sid, opts)
	if snap.is_empty():
		return _ok({ "pending": true, "session_id": sid, "message": "Runtime snapshot requested; call again shortly." })
	return _ok(snap)


func _eval_runtime(params: Dictionary) -> Dictionary:
	var rb = _get_runtime_bridge()
	if rb == null:
		return _ok({ "error": "Runtime bridge not available. Ensure the project is running." })
	if params.has("session_id") and params.has("request_id"):
		var sid := int(params.get("session_id", -1))
		var rid := int(params.get("request_id", -1))
		if rb.has_eval_result(sid, rid):
			var response: Dictionary = rb.take_eval_result(sid, rid)
			if not response.get("success", true) and not response.has("error"):
				response["error"] = "Runtime evaluation failed."
			return _ok(response)
		return _ok({ "pending": true, "session_id": sid, "request_id": rid })

	var expr := ""
	if params.has("expression"):
		expr = str(params.get("expression", ""))
	elif params.has("code"):
		expr = str(params.get("code", ""))
	if expr.strip_edges().is_empty():
		return _error("Expression cannot be empty")

	var opts: Dictionary = { }
	if params.has("node_path"):
		opts["node_path"] = str(params.get("node_path"))
	opts["capture_prints"] = _coerce(params.get("capture_prints"), true)

	var req = rb.evaluate_runtime_expression(expr, opts)
	if req.has("error"):
		return _ok(req)
	var sid: int = req.get("session_id", -1)
	var rid: int = req.get("request_id", -1)
	if sid < 0 or rid < 0:
		return _ok({ "error": "Failed to enqueue runtime evaluation." })
	return _ok({ "pending": true, "session_id": sid, "request_id": rid })


func _coerce(v, d: bool) -> bool:
	if typeof(v) == TYPE_BOOL:
		return v
	if typeof(v) == TYPE_STRING:
		return v.to_lower() == "true"
	return d
