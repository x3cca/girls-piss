@tool
class_name ToolProviderGetDebugOutput
extends MCPToolProviderBase

func get_definition() -> ToolDefinition:
	return ToolDefinition.new(
		"get_debug_output",
		"Get recent debug output.",
		{
			"type": "object",
			"properties": {
				"max_lines": { "type": "number", "description": "Max lines (default 100)" },
			},
		},
		"get_debug_output",
	)


func execute(params: Dictionary) -> Dictionary:
	var max_lines := int(params.get("max_lines", 100))
	var output := ""
	var diagnostics: Dictionary = { }
	var publisher = _get_publisher()
	if publisher:
		output = publisher.get_full_log_text()
		if publisher.has_method("get_capture_diagnostics"):
			diagnostics = publisher.get_capture_diagnostics()
	if max_lines > 0 and not output.is_empty():
		var lines := output.split("\n")
		if lines.size() > max_lines:
			output = "\n".join(lines.slice(lines.size() - max_lines))
	return _ok({ "output": output, "diagnostics": diagnostics })


func _get_publisher():
	if Engine.has_meta("MCPDebugOutputPublisher"):
		return Engine.get_meta("MCPDebugOutputPublisher")
	return null
