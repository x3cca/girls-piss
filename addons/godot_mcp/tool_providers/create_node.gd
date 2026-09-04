@tool
## Tool provider for "create_node" — Create a new node in the scene tree.
class_name ToolProviderCreateNode
extends MCPToolProviderBase

func get_definition() -> ToolDefinition:
	return ToolDefinition.new(
		"create_node",
		"Create a new node in the scene tree.",
		{
			"type": "object",
			"properties": {
				"parent_path": {
					"type": "string",
					"description": "Path to the parent node (default: root)",
				},
				"node_type": {
					"type": "string",
					"description": "Node class name (e.g. Node2D, Sprite2D)",
				},
				"node_name": {
					"type": "string",
					"description": "Name for the new node",
				},
			},
			"required": ["node_type", "node_name"],
		},
		"create_node",
	)


func execute(params: Dictionary) -> Dictionary:
	var parent_path = params.get("parent_path", ".")
	var node_type = params.get("node_type", "Node")
	var node_name = params.get("node_name", "NewNode")

	# Validation
	if not ClassDB.class_exists(node_type):
		return _error("Invalid node type: %s" % node_type)

	# Get editor plugin and interfaces
	var plugin = Engine.get_meta("GodotMCPPlugin")
	if not plugin:
		return _error("GodotMCPPlugin not found in Engine metadata")

	var editor_interface = plugin.get_editor_interface()
	var edited_scene_root = editor_interface.get_edited_scene_root()

	if not edited_scene_root:
		return _error("No scene is currently being edited")

	# Get the parent node using the editor node helper
	var parent = _get_editor_node(parent_path)
	if not parent:
		return _error("Parent node not found: %s" % parent_path)

	# Create the node
	var node
	if ClassDB.can_instantiate(node_type):
		node = ClassDB.instantiate(node_type)
	else:
		return _error("Cannot instantiate node of type: %s" % node_type)

	if not node:
		return _error("Failed to create node of type: %s" % node_type)

	# Set the node name
	node.name = node_name

	# Add the node to the parent
	parent.add_child(node)

	# Set owner for proper serialization
	node.owner = edited_scene_root

	# Mark the scene as modified
	_mark_scene_modified()

	return _ok(
		{
			"node_path": parent_path + "/" + node_name,
		},
	)
