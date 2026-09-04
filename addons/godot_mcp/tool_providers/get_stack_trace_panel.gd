@tool
class_name ToolProviderGetStackTracePanel
extends MCPToolProviderBase

func get_definition() -> ToolDefinition:
	return ToolDefinition.new(
		"get_stack_trace_panel",
		"Get stack trace panel contents.",
		{
			"type": "object",
			"properties": {
				"session_id": { "type": "number", "description": "Optional session ID" },
			},
		},
		"get_stack_trace_panel",
	)


func execute(params: Dictionary) -> Dictionary:
	var p = _get_publisher()
	if p and p.has_method("get_stack_trace_snapshot"):
		var sid := int(params.get("session_id", -1))
		return _ok(p.get_stack_trace_snapshot(sid))
	return _ok(
		{
			"text": "",
			"lines": [],
			"line_count": 0,
			"diagnostics": { "error": "publisher_unavailable" },
		},
	)


func _get_publisher():
	if Engine.has_meta("MCPDebugOutputPublisher"):
		return Engine.get_meta("MCPDebugOutputPublisher")
	return null
