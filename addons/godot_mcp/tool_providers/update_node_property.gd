@tool
## Tool provider for "update_node_property" — Update a property on a node.
class_name ToolProviderUpdateNodeProperty
extends MCPToolProviderBase

func get_definition() -> ToolDefinition:
	return ToolDefinition.new(
		"update_node_property",
		"Update a property on a node.",
		{
			"type": "object",
			"properties": {
				"node_path": {
					"type": "string",
					"description": "Path to the node",
				},
				"property": {
					"type": "string",
					"description": "Name of the property to update",
				},
				"value": {
					"description": "New value for the property",
				},
			},
			"required": ["node_path", "property", "value"],
		},
		"update_node_property",
	)


func execute(params: Dictionary) -> Dictionary:
	var node_path = params.get("node_path", "")
	var property_name = params.get("property", "")
	var property_value = params.get("value")

	# Validation
	if node_path.is_empty():
		return _error("Node path cannot be empty")

	if property_name.is_empty():
		return _error("Property name cannot be empty")

	if property_value == null:
		return _error("Property value cannot be null")

	# Get editor plugin and interfaces
	var plugin = Engine.get_meta("GodotMCPPlugin")
	if not plugin:
		return _error("GodotMCPPlugin not found in Engine metadata")

	# Get the node using the editor node helper
	var node = _get_editor_node(node_path)
	if not node:
		return _error("Node not found: %s" % node_path)

	# Check if the property exists
	if not property_name in node:
		return _error("Property %s does not exist on node %s" % [property_name, node_path])

	# Parse property value for Godot types
	var parsed_value = _parse_property_value(property_value)

	# Get current property value for undo
	var old_value = node.get(property_name)

	# Get undo/redo system
	var undo_redo = _get_undo_redo()
	if not undo_redo:
		# Fallback method if we can't get undo/redo
		node.set(property_name, parsed_value)
		_mark_scene_modified()
	else:
		# Use undo/redo for proper editor integration
		undo_redo.create_action("Update Property: " + property_name)
		undo_redo.add_do_property(node, property_name, parsed_value)
		undo_redo.add_undo_property(node, property_name, old_value)
		undo_redo.commit_action()

	# Mark the scene as modified
	_mark_scene_modified()

	return _ok(
		{
			"node_path": node_path,
			"property": property_name,
			"value": property_value,
			"parsed_value": str(parsed_value),
		},
	)
