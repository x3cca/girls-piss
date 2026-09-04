@tool
## Tool provider for "reload_scene" — Reload scene from disk, discarding unsaved changes.
class_name ToolProviderReloadScene
extends MCPToolProviderBase

func get_definition() -> ToolDefinition:
	return ToolDefinition.new(
		"reload_scene",
		"Reload the current scene from disk, discarding unsaved changes.",
		{
			"type": "object",
			"properties": {
				"scene_path": {
					"type": "string",
					"description": "Optional scene path to reload (default: current scene)",
				},
			},
		},
		"reload_scene",
	)


func execute(params: Dictionary) -> Dictionary:
	var plugin = Engine.get_meta("GodotMCPPlugin")
	if not plugin:
		return _error("GodotMCPPlugin not found in Engine metadata")

	var editor_interface = plugin.get_editor_interface()
	var scene_path: String = params.get("scene_path", "")

	# If no scene path provided, reload the current scene
	if scene_path.is_empty():
		var edited_scene_root = editor_interface.get_edited_scene_root()
		if not edited_scene_root:
			return _error("No scene is currently open in the editor")

		scene_path = edited_scene_root.scene_file_path
		if scene_path.is_empty():
			return _error("Current scene has not been saved yet")

	# Validate scene path
	if not scene_path.begins_with("res://"):
		scene_path = "res://" + scene_path

	if not ResourceLoader.exists(scene_path):
		return _error("Scene does not exist: %s" % scene_path)

	# Reload the scene from disk
	editor_interface.reload_scene_from_path(scene_path)

	return _ok(
		{
			"status": "reloaded",
			"scene_path": scene_path,
			"message": "Scene reloaded from disk",
		},
	)
