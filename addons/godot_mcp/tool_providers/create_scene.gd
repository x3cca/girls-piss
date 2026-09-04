@tool
## Tool provider for "create_scene" — Create a new scene file.
class_name ToolProviderCreateScene
extends MCPToolProviderBase

func get_definition() -> ToolDefinition:
	return ToolDefinition.new(
		"create_scene",
		"Create a new scene file.",
		{
			"type": "object",
			"properties": {
				"path": {
					"type": "string",
					"description": "Path for the new scene file (e.g. res://scenes/level.tscn)",
				},
				"root_node_type": {
					"type": "string",
					"description": "Root node class name (Node2D, Node3D, Control). Default: Node",
				},
			},
			"required": ["path"],
		},
		"create_scene",
	)


func execute(params: Dictionary) -> Dictionary:
	var path = params.get("path", "")
	var root_node_type = params.get("root_node_type", "Node")

	# Validation
	if path.is_empty():
		return _error("Scene path cannot be empty")

	# Make sure we have an absolute path
	if not path.begins_with("res://"):
		path = "res://" + path

	# Ensure path ends with .tscn
	if not path.ends_with(".tscn"):
		path += ".tscn"

	# Create directory structure if it doesn't exist
	var dir_path = path.get_base_dir()
	if not DirAccess.dir_exists_absolute(dir_path):
		var dir = DirAccess.open("res://")
		if dir:
			dir.make_dir_recursive(dir_path.trim_prefix("res://"))

	# Check if file already exists
	if FileAccess.file_exists(path):
		return _error("Scene file already exists: %s" % path)

	# Create the root node of the specified type
	var root_node = null

	match root_node_type:
		"Node":
			root_node = Node.new()
		"Node2D":
			root_node = Node2D.new()
		"Node3D", "Spatial":
			root_node = Node3D.new()
		"Control":
			root_node = Control.new()
		"CanvasLayer":
			root_node = CanvasLayer.new()
		"Panel":
			root_node = Panel.new()
		_:
			# Attempt to create a custom class if built-in type not recognized
			if ClassDB.class_exists(root_node_type):
				root_node = ClassDB.instantiate(root_node_type)
			else:
				return _error("Invalid root node type: %s" % root_node_type)

	# Give the root node a name based on the file name
	var file_name = path.get_file().get_basename()
	root_node.name = file_name

	# Create a packed scene
	var packed_scene = PackedScene.new()
	var result = packed_scene.pack(root_node)
	if result != OK:
		root_node.free()
		return _error("Failed to pack scene: %d" % result)

	# Save the packed scene to disk
	result = ResourceSaver.save(packed_scene, path)
	if result != OK:
		root_node.free()
		return _error("Failed to save scene: %d" % result)

	# Clean up
	root_node.free()

	# Try to open the scene in the editor
	var plugin = Engine.get_meta("GodotMCPPlugin") if Engine.has_meta("GodotMCPPlugin") else null
	if plugin and plugin.has_method("get_editor_interface"):
		var editor_interface = plugin.get_editor_interface()
		editor_interface.open_scene_from_path(path)

	return _ok(
		{
			"scene_path": path,
			"root_node_type": root_node_type,
		},
	)
