@tool
## Tool provider for "delete_scene" — Delete a scene file. Cannot delete the currently open scene.
class_name ToolProviderDeleteScene
extends MCPToolProviderBase

func get_definition() -> ToolDefinition:
	return ToolDefinition.new(
		"delete_scene",
		"Delete a scene file from the project. Cannot delete the currently open scene.",
		{
			"type": "object",
			"properties": {
				"path": {
					"type": "string",
					"description": "Path to the scene file to delete",
				},
			},
			"required": ["path"],
		},
		"delete_scene",
	)


func execute(params: Dictionary) -> Dictionary:
	var path = params.get("path", "")

	# Validation
	if path.is_empty():
		return _error("Scene path cannot be empty")

	# Make sure we have an absolute path
	if not path.begins_with("res://"):
		path = "res://" + path

	# Ensure path ends with .tscn
	if not path.ends_with(".tscn"):
		path += ".tscn"

	# Check if file exists
	if not FileAccess.file_exists(path):
		return _error("Scene file not found: %s" % path)

	# Check if this is the currently open scene
	var plugin = Engine.get_meta("GodotMCPPlugin") if Engine.has_meta("GodotMCPPlugin") else null
	if plugin and plugin.has_method("get_editor_interface"):
		var editor_interface = plugin.get_editor_interface()
		var edited_scene_root = editor_interface.get_edited_scene_root()

		if edited_scene_root and edited_scene_root.scene_file_path == path:
			return _error("Cannot delete currently open scene: %s. Close it first." % path)

	# Delete the file
	var dir = DirAccess.open("res://")
	if not dir:
		return _error("Failed to access project directory")

	var result = dir.remove(path)
	if result != OK:
		return _error("Failed to delete scene file: %d" % result)

	# Rescan the filesystem to update the editor
	if plugin and plugin.has_method("get_editor_interface"):
		var editor_interface = plugin.get_editor_interface()
		var filesystem = editor_interface.get_resource_filesystem()
		if filesystem:
			filesystem.scan()

	return _ok(
		{
			"scene_path": path,
		},
	)
