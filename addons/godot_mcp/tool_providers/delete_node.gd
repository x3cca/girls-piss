@tool
## Tool provider for "delete_node" — Delete a node from the scene tree.
class_name ToolProviderDeleteNode
extends MCPToolProviderBase

func get_definition() -> ToolDefinition:
	return ToolDefinition.new(
		"delete_node",
		"Delete a node from the scene tree.",
		{
			"type": "object",
			"properties": {
				"node_path": {
					"type": "string",
					"description": "Path to the node to delete",
				},
			},
			"required": ["node_path"],
		},
		"delete_node",
	)


func execute(params: Dictionary) -> Dictionary:
	var node_path = params.get("node_path", "")

	# Validation
	if node_path.is_empty():
		return _error("Node path cannot be empty")

	# Get editor plugin and interfaces
	var plugin = Engine.get_meta("GodotMCPPlugin")
	if not plugin:
		return _error("GodotMCPPlugin not found in Engine metadata")

	var editor_interface = plugin.get_editor_interface()
	var edited_scene_root = editor_interface.get_edited_scene_root()

	if not edited_scene_root:
		return _error("No scene is currently being edited")

	# Get the node using the editor node helper
	var node = _get_editor_node(node_path)
	if not node:
		return _error("Node not found: %s" % node_path)

	# Cannot delete the root node
	if node == edited_scene_root:
		return _error("Cannot delete the root node")

	# Get parent for operation
	var parent = node.get_parent()
	if not parent:
		return _error("Node has no parent: %s" % node_path)

	# Remove the node
	parent.remove_child(node)
	node.queue_free()

	# Mark the scene as modified
	_mark_scene_modified()

	return _ok(
		{
			"deleted_node_path": node_path,
		},
	)
