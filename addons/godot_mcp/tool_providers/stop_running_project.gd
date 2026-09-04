@tool
## Tool provider for "stop_running_project" — Stop the currently running project.
class_name ToolProviderStopRunningProject
extends MCPToolProviderBase

func get_definition() -> ToolDefinition:
	return ToolDefinition.new(
		"stop_running_project",
		"Stop the currently running project.",
		{
			"type": "object",
			"properties": { },
		},
		"stop_running_project",
	)


func execute(_params: Dictionary) -> Dictionary:
	var editor_interface = _get_editor_interface()
	if not editor_interface:
		return _error("Editor interface not available")

	if not editor_interface.is_playing_scene():
		return _ok(
			{
				"status": "idle",
				"message": "Editor is not currently running a scene",
			},
		)

	editor_interface.stop_playing_scene()
	return _ok(
		{
			"status": "stopped",
		},
	)
