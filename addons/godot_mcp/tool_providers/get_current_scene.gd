@tool
## Tool provider for "get_current_scene" — Get information about the currently open scene.
class_name ToolProviderGetCurrentScene
extends MCPToolProviderBase

func get_definition() -> ToolDefinition:
	return ToolDefinition.new(
		"get_current_scene",
		"Get information about the currently open scene.",
		{
			"type": "object",
			"properties": { },
		},
		"get_current_scene",
	)


func execute(_params: Dictionary) -> Dictionary:
	# Get editor plugin and interfaces
	var plugin = Engine.get_meta("GodotMCPPlugin")
	if not plugin:
		return _error("GodotMCPPlugin not found in Engine metadata")

	var editor_interface = plugin.get_editor_interface()
	var edited_scene_root = editor_interface.get_edited_scene_root()

	if not edited_scene_root:
		print("No scene is currently being edited")
		# Instead of returning an error, return a valid response with empty/default values
		return _ok(
			{
				"scene_path": "None",
				"root_node_type": "None",
				"root_node_name": "None",
			},
		)

	var scene_path = edited_scene_root.scene_file_path
	if scene_path.is_empty():
		scene_path = "Untitled"

	print("Current scene path: ", scene_path)
	print("Root node type: ", edited_scene_root.get_class())
	print("Root node name: ", edited_scene_root.name)

	return _ok(
		{
			"scene_path": scene_path,
			"root_node_type": edited_scene_root.get_class(),
			"root_node_name": edited_scene_root.name,
		},
	)
