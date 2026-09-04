@tool
## Tool provider for "create_script" — Create a new script file and optionally attach it to a node.
class_name ToolProviderCreateScript
extends MCPToolProviderBase

func get_definition() -> ToolDefinition:
	return ToolDefinition.new(
		"create_script",
		"Create a new script file and optionally attach it to a node.",
		{
			"type": "object",
			"properties": {
				"script_path": {
					"type": "string",
					"description": "Path for the new script (e.g. res://scripts/player.gd)",
				},
				"content": {
					"type": "string",
					"description": "Script source code content",
				},
				"node_path": {
					"type": "string",
					"description": "Optional node path to attach the script to",
				},
			},
			"required": ["script_path", "content"],
		},
		"create_script",
	)


func execute(params: Dictionary) -> Dictionary:
	var script_path = params.get("script_path", "")
	var content = params.get("content", "")
	var node_path = params.get("node_path", "")

	# Validation
	if script_path.is_empty():
		return _error("Script path cannot be empty")

	# Make sure we have an absolute path
	if not script_path.begins_with("res://"):
		script_path = "res://" + script_path

	if not script_path.ends_with(".gd"):
		script_path += ".gd"

	# Get editor plugin and interfaces
	var plugin = Engine.get_meta("GodotMCPPlugin")
	if not plugin:
		return _error("GodotMCPPlugin not found in Engine metadata")

	var editor_interface = plugin.get_editor_interface()
	var script_editor = editor_interface.get_script_editor()

	# Create the directory if it doesn't exist
	var dir = script_path.get_base_dir()
	if not DirAccess.dir_exists_absolute(dir):
		var err = DirAccess.make_dir_recursive_absolute(dir)
		if err != OK:
			return _error("Failed to create directory: %s (Error code: %d)" % [dir, err])

	# Create the script file
	var file = FileAccess.open(script_path, FileAccess.WRITE)
	if file == null:
		return _error("Failed to create script file: %s" % script_path)

	file.store_string(content)
	file = null # Close the file

	# Refresh the filesystem
	editor_interface.get_resource_filesystem().scan()

	# Attach the script to a node if specified
	if not node_path.is_empty():
		var node = _get_editor_node(node_path)
		if not node:
			# Try enhanced node resolution
			node = _get_editor_node_enhanced(node_path)
			if not node:
				return _error("Node not found: %s" % node_path)

		# Wait for script to be recognized in the filesystem
		await Engine.get_main_loop().create_timer(0.5).timeout

		var script = load(script_path)
		if not script:
			return _error("Failed to load script: %s" % script_path)

		# Use undo/redo for script assignment
		var undo_redo = _get_undo_redo()
		if not undo_redo:
			# Fallback method if we can't get undo/redo
			node.set_script(script)
			_mark_scene_modified()
		else:
			# Use undo/redo for proper editor integration
			undo_redo.create_action("Assign Script")
			undo_redo.add_do_method(node, "set_script", script)
			undo_redo.add_undo_method(node, "set_script", node.get_script())
			undo_redo.commit_action()

		# Mark the scene as modified
		_mark_scene_modified()

	# Open the script in the editor
	var script_resource = load(script_path)
	if script_resource:
		editor_interface.edit_script(script_resource)

	return _ok(
		{
			"script_path": script_path,
			"node_path": node_path,
		},
	)
