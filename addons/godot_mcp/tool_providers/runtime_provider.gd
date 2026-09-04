@tool
## Runtime tool provider — async tools using the runtime debugger bridge.
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
				},
				"required": [],
			},
			"evaluate_runtime",
		),
	]


func execute_tool(tool_name: String, params: Dictionary) -> Dictionary:
	match tool_name:
		"get_runtime_scene_structure":
			return await _runtime_scene(params)
		"evaluate_runtime":
			return await _eval_runtime(params)
	return _error("Unknown tool: %s" % tool_name)


func _runtime_scene(params: Dictionary) -> Dictionary:
	var rb = _get_runtime_bridge()
	if rb == null:
		return _error("Runtime debugger bridge not available. Ensure the project is running.")
	var timeout := int(params.get("timeout_ms", 3000))
	if timeout < 100:
		timeout = 100
	elif timeout > 5000:
		timeout = 5000

	var req = rb.request_runtime_scene_snapshot()
	if req.has("error"):
		return _ok(req)
	var sid: int = req.get("session_id", -1)
	var bv: int = req.get("baseline_version", 0)
	if not get_tree():
		return _error("Scene tree unavailable for polling.")

	var dl := Time.get_ticks_msec() + timeout
	var snap: Dictionary = { }
	while Time.get_ticks_msec() <= dl:
		if rb.has_new_runtime_snapshot(sid, bv):
			var opts := {
				"include_properties": params.get("include_properties", false),
				"include_scripts": params.get("include_scripts", false),
			}
			snap = rb.build_runtime_snapshot(sid, opts)
			if not snap.is_empty():
				break
		await get_tree().process_frame
	if snap.is_empty():
		return _ok({ "error": "Timed out waiting for runtime scene data." })
	return _ok(snap)


func _eval_runtime(params: Dictionary) -> Dictionary:
	var rb = _get_runtime_bridge()
	if rb == null:
		return _ok({ "error": "Runtime bridge not available. Ensure the project is running." })

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

	var timeout := int(params.get("timeout_ms", 3000))
	if timeout < 100:
		timeout = 100
	elif timeout > 5000:
		timeout = 5000

	var req = rb.evaluate_runtime_expression(expr, opts)
	if req.has("error"):
		return _ok(req)
	var sid: int = req.get("session_id", -1)
	var rid: int = req.get("request_id", -1)
	if sid < 0 or rid < 0:
		return _ok({ "error": "Failed to enqueue runtime evaluation." })
	if not get_tree():
		return _ok({ "error": "Scene tree unavailable." })

	var dl := Time.get_ticks_msec() + timeout
	var resp: Dictionary = { }
	while Time.get_ticks_msec() <= dl:
		if rb.has_eval_result(sid, rid):
			resp = rb.take_eval_result(sid, rid)
			;break
		await get_tree().process_frame
	if resp.is_empty():
		return _ok(
			{
				"error": "Timed out waiting for runtime evaluation.",
				"hint": "Ensure the running project registers mcp_eval debugger capture.",
			},
		)
	if not resp.get("success", true) and not resp.has("error"):
		resp["error"] = "Runtime evaluation failed."
	return _ok(resp)


func _coerce(v, d: bool) -> bool:
	if typeof(v) == TYPE_BOOL:
		return v
	if typeof(v) == TYPE_STRING:
		return v.to_lower() == "true"
	return d
