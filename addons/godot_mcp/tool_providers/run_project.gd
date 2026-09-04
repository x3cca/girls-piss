@tool
## Tool provider for "run_project" — Launch the project's main scene (same as F5).
class_name ToolProviderRunProject
extends MCPToolProviderBase

func get_definition() -> ToolDefinition:
	return ToolDefinition.new(
		"run_project",
		"Launch the project's main scene (same as F5).",
		{
			"type": "object",
			"properties": { },
		},
		"run_project",
	)


func execute(_params: Dictionary) -> Dictionary:
	var editor_interface = _get_editor_interface()
	if not editor_interface:
		return _error("Editor interface not available")

	var main_scene: String = ProjectSettings.get_setting("application/run/main_scene", "")
	if main_scene.is_empty():
		return _error("No main scene configured in project settings")

	editor_interface.play_main_scene()
	return _ok(
		{
			"status": "running",
			"scene_path": main_scene,
		},
	)
