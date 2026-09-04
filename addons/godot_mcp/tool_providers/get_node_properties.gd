@tool
## Tool provider for "get_node_properties" — Get all properties of a node.
class_name ToolProviderGetNodeProperties
extends MCPToolProviderBase

func get_definition() -> ToolDefinition:
	return ToolDefinition.new(
		"get_node_properties",
		"Get all properties of a node.",
		{
			"type": "object",
			"properties": {
				"node_path": {
					"type": "string",
					"description": "Path to the node",
				},
			},
			"required": ["node_path"],
		},
		"get_node_properties",
	)


func execute(params: Dictionary) -> Dictionary:
	var node_path = params.get("node_path", "")

	# Validation
	if node_path.is_empty():
		return _error("Node path cannot be empty")

	# Get the node using the editor node helper
	var node = _get_editor_node(node_path)
	if not node:
		return _error("Node not found: %s" % node_path)

	# Get all properties
	var properties = { }
	var property_list = node.get_property_list()

	for prop in property_list:
		var name = prop["name"]
		if not name.begins_with("_"): # Skip internal properties
			properties[name] = node.get(name)

	return _ok(
		{
			"node_path": node_path,
			"properties": properties,
		},
	)
