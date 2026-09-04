@tool
## Tool provider for "run_specific_scene" — Run a specific scene by path.
class_name ToolProviderRunSpecificScene
extends MCPToolProviderBase

func get_definition() -> ToolDefinition:
	return ToolDefinition.new(
		"run_specific_scene",
		"Run a specific scene by path.",
		{
			"type": "object",
			"properties": {
				"scene_path": {
					"type": "string",
					"description": "Path to the scene to run",
				},
			},
			"required": ["scene_path"],
		},
		"run_specific_scene",
	)


func execute(params: Dictionary) -> Dictionary:
	var editor_interface = _get_editor_interface()
	if not editor_interface:
		return _error("Editor interface not available")

	var scene_path: String = params.get("scene_path", "")
	if scene_path.is_empty():
		return _error("scene_path parameter is required")

	if not ResourceLoader.exists(scene_path):
		return _error("Scene does not exist: %s" % scene_path)

	editor_interface.play_custom_scene(scene_path)
	return _ok(
		{
			"status": "running",
			"scene_path": scene_path,
		},
	)
