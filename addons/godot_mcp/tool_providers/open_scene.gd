@tool
## Tool provider for "open_scene" — Open a scene file in the editor.
class_name ToolProviderOpenScene
extends MCPToolProviderBase

func get_definition() -> ToolDefinition:
	return ToolDefinition.new(
		"open_scene",
		"Open a scene file in the editor.",
		{
			"type": "object",
			"properties": {
				"path": {
					"type": "string",
					"description": "Path to the .tscn file",
				},
			},
			"required": ["path"],
		},
		"open_scene",
	)


func execute(params: Dictionary) -> Dictionary:
	var path = params.get("path", "")

	# Validation
	if path.is_empty():
		return _error("Scene path cannot be empty")

	# Make sure we have an absolute path
	if not path.begins_with("res://"):
		path = "res://" + path

	# Check if the file exists
	if not FileAccess.file_exists(path):
		return _error("Scene file not found: %s" % path)

	# Since we can't directly open scenes in tool scripts,
	# we need to defer to the plugin which has access to EditorInterface
	var plugin = Engine.get_meta("GodotMCPPlugin") if Engine.has_meta("GodotMCPPlugin") else null

	if plugin and plugin.has_method("get_editor_interface"):
		var editor_interface = plugin.get_editor_interface()
		editor_interface.open_scene_from_path(path)
		return _ok(
			{
				"scene_path": path,
			},
		)

	return _error("Cannot access EditorInterface. Please open the scene manually: %s" % path)
