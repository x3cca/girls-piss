@tool
## Tool provider for "get_selected_node" — Get the selected node in the editor with its properties.
class_name ToolProviderGetSelectedNode
extends MCPToolProviderBase

func get_definition() -> ToolDefinition:
	return ToolDefinition.new(
		"get_selected_node",
		"Get the currently selected node in the editor with its properties.",
		{
			"type": "object",
			"properties": { },
		},
		"get_selected_node",
	)


func execute(_params: Dictionary) -> Dictionary:
	# Get editor plugin and interfaces
	var plugin = Engine.get_meta("GodotMCPPlugin")
	if not plugin:
		return _error("GodotMCPPlugin not found in Engine metadata")

	var editor_interface = plugin.get_editor_interface()
	var selection = editor_interface.get_selection()
	var selected_nodes = selection.get_selected_nodes()

	if selected_nodes.size() == 0:
		return _ok(
			{
				"selected": false,
				"message": "No node is currently selected",
			},
		)

	var node = selected_nodes[0] # Get the first selected node

	# Get node info
	var node_data = {
		"selected": true,
		"name": node.name,
		"type": node.get_class(),
		"path": str(node.get_path()),
	}

	# Get script info if available
	var script = node.get_script()
	if script:
		node_data["script_path"] = script.resource_path

	# Get important properties
	var properties = { }
	var property_list = node.get_property_list()

	for prop in property_list:
		var name = prop["name"]
		if not name.begins_with("_"): # Skip internal properties
			# Only include some common properties to avoid overwhelming data
			if name in ["position", "rotation", "scale", "visible", "modulate", "z_index"]:
				properties[name] = node.get(name)

	node_data["properties"] = properties

	return _ok(node_data)
