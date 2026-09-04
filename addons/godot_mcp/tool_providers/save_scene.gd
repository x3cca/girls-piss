@tool
## Tool provider for "save_scene" — Save the current scene.
class_name ToolProviderSaveScene
extends MCPToolProviderBase

func get_definition() -> ToolDefinition:
	return ToolDefinition.new(
		"save_scene",
		"Save the current scene.",
		{
			"type": "object",
			"properties": {
				"path": {
					"type": "string",
					"description": "Optional path to save to",
				},
			},
		},
		"save_scene",
	)


func execute(params: Dictionary) -> Dictionary:
	var path = params.get("path", "")

	# Get editor plugin and interfaces
	var plugin = Engine.get_meta("GodotMCPPlugin")
	if not plugin:
		return _error("GodotMCPPlugin not found in Engine metadata")

	var editor_interface = plugin.get_editor_interface()
	var edited_scene_root = editor_interface.get_edited_scene_root()

	# If no path provided, use the current scene path
	if path.is_empty() and edited_scene_root:
		path = edited_scene_root.scene_file_path

	# Validation
	if path.is_empty():
		return _error("Scene path cannot be empty")

	# Make sure we have an absolute path
	if not path.begins_with("res://"):
		path = "res://" + path

	if not path.ends_with(".tscn"):
		path += ".tscn"

	# Check if we have an edited scene
	if not edited_scene_root:
		return _error("No scene is currently being edited")

	# Save the scene
	var packed_scene = PackedScene.new()
	var result = packed_scene.pack(edited_scene_root)
	if result != OK:
		return _error("Failed to pack scene: %d" % result)

	result = ResourceSaver.save(packed_scene, path)
	if result != OK:
		return _error("Failed to save scene: %d" % result)

	return _ok(
		{
			"scene_path": path,
		},
	)
