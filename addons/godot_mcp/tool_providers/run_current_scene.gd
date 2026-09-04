@tool
## Tool provider for "run_current_scene" — Play the current scene in the editor (same as F6).
class_name ToolProviderRunCurrentScene
extends MCPToolProviderBase

func get_definition() -> ToolDefinition:
	return ToolDefinition.new(
		"run_current_scene",
		"Play the current scene in the editor (same as F6).",
		{
			"type": "object",
			"properties": { },
		},
		"run_current_scene",
	)


func execute(_params: Dictionary) -> Dictionary:
	var editor_interface = _get_editor_interface()
	if not editor_interface:
		return _error("Editor interface not available")

	var scene_root = editor_interface.get_edited_scene_root()
	if not scene_root:
		return _error("No scene is currently open in the editor")

	var scene_path: String = scene_root.scene_file_path
	if scene_path.is_empty():
		return _error("Current scene must be saved before it can be run")

	editor_interface.play_current_scene()
	return _ok(
		{
			"status": "running",
			"scene_path": scene_path,
		},
	)
