@tool
## Tool provider for "get_editor_state" — Get current editor state information.
class_name ToolProviderGetEditorState
extends MCPToolProviderBase

func get_definition() -> ToolDefinition:
	return ToolDefinition.new(
		"get_editor_state",
		"Get current editor state information.",
		{
			"type": "object",
			"properties": { },
		},
		"get_editor_state",
	)


func execute(_params: Dictionary) -> Dictionary:
	# Get editor plugin and interfaces
	var plugin = Engine.get_meta("GodotMCPPlugin")
	if not plugin:
		return _error("GodotMCPPlugin not found in Engine metadata")

	var editor_interface = plugin.get_editor_interface()

	var state = {
		"current_scene": "",
		"current_script": "",
		"selected_nodes": [],
		"is_playing": editor_interface.is_playing_scene(),
	}

	# Get current scene
	var edited_scene_root = editor_interface.get_edited_scene_root()
	if edited_scene_root:
		state["current_scene"] = edited_scene_root.scene_file_path

	# Get current script if any is being edited
	var script_editor = editor_interface.get_script_editor()
	var current_script = script_editor.get_current_script()
	if current_script:
		state["current_script"] = current_script.resource_path

	# Get selected nodes
	var selection = editor_interface.get_selection()
	var selected_nodes = selection.get_selected_nodes()

	for node in selected_nodes:
		state["selected_nodes"].append(
			{
				"name": node.name,
				"path": str(node.get_path()),
			},
		)

	return _ok(state)
