@tool
class_name ToolProviderGetEditorErrors
extends MCPToolProviderBase

func get_definition() -> ToolDefinition:
	return ToolDefinition.new(
		"get_editor_errors",
		"Get current editor errors.",
		{
			"type": "object",
			"properties": { },
		},
		"get_editor_errors",
	)


func execute(_params: Dictionary) -> Dictionary:
	var p = _get_publisher()
	if p and p.has_method("get_errors_panel_snapshot"):
		return _ok(p.get_errors_panel_snapshot())
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
