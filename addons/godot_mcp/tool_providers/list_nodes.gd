@tool
## Tool provider for "list_nodes" — List all nodes in the current scene.
class_name ToolProviderListNodes
extends MCPToolProviderBase

func get_definition() -> ToolDefinition:
	return ToolDefinition.new(
		"list_nodes",
		"List all nodes in the current scene.",
		{
			"type": "object",
			"properties": {
				"parent_path": {
					"type": "string",
					"description": "Optional parent path to list children of",
				},
			},
		},
		"list_nodes",
	)


func execute(params: Dictionary) -> Dictionary:
	var parent_path = params.get("parent_path", ".")

	# Get the parent node using the editor node helper
	var parent = _get_editor_node(parent_path)
	if not parent:
		return _error("Parent node not found: %s" % parent_path)

	# Get children
	var children = []
	for child in parent.get_children():
		children.append(
			{
				"name": child.name,
				"type": child.get_class(),
				"path": str(child.get_path()).replace(str(parent.get_path()), parent_path),
			},
		)

	return _ok(
		{
			"parent_path": parent_path,
			"children": children,
		},
	)
