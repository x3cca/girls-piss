@tool
class_name ToolProviderClearEditorErrors
extends MCPToolProviderBase

func get_definition() -> ToolDefinition:
	return ToolDefinition.new(
		"clear_editor_errors",
		"Clear the editor errors tab.",
		{
			"type": "object",
			"properties": { },
		},
		"clear_editor_errors",
	)


func execute(_params: Dictionary) -> Dictionary:
	var p = _get_publisher()
	if p == null or not p.has_method("clear_errors_panel"):
		return _error("Debug output publisher unavailable.")
	var r = p.clear_errors_panel()
	return _ok(r)


func _get_publisher():
	if Engine.has_meta("MCPDebugOutputPublisher"):
		return Engine.get_meta("MCPDebugOutputPublisher")
	return null
