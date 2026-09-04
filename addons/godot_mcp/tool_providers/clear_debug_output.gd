@tool
class_name ToolProviderClearDebugOutput
extends MCPToolProviderBase

func get_definition() -> ToolDefinition:
	return ToolDefinition.new(
		"clear_debug_output",
		"Clear the debug output panel.",
		{
			"type": "object",
			"properties": { },
		},
		"clear_debug_output",
	)


func execute(_params: Dictionary) -> Dictionary:
	var p = _get_publisher()
	if p == null or not p.has_method("clear_log_output"):
		return _error("Debug output publisher unavailable.")
	var r = p.clear_log_output()
	return _ok(r)


func _get_publisher():
	if Engine.has_meta("MCPDebugOutputPublisher"):
		return Engine.get_meta("MCPDebugOutputPublisher")
	return null
