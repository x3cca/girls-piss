@tool
## Tool provider for "get_script" — Get the source code of a script attached to a node or resource.
class_name ToolProviderGetScript
extends MCPToolProviderBase

func get_definition() -> ToolDefinition:
	return ToolDefinition.new(
		"get_script",
		"Get the source code of a script attached to a node or resource.",
		{
			"type": "object",
			"properties": {
				"script_path": {
					"type": "string",
					"description": "Path to the script file",
				},
				"node_path": {
					"type": "string",
					"description": "Path to the node with a script attached",
				},
			},
			"oneOf": [
				{
					"required": ["script_path"],
				},
				{
					"required": ["node_path"],
				},
			],
		},
		"get_script",
	)


func execute(params: Dictionary) -> Dictionary:
	var script_path = params.get("script_path", "")
	var node_path = params.get("node_path", "")

	# Validation - either script_path or node_path must be provided
	if script_path.is_empty() and node_path.is_empty():
		return _error("Either script_path or node_path must be provided")

	# If node_path is provided, get the script from the node
	if not node_path.is_empty():
		var node = _get_editor_node(node_path)
		if not node:
			# Try enhanced node resolution
			node = _get_editor_node_enhanced(node_path)
			if not node:
				return _error("Node not found: %s" % node_path)

		var script = node.get_script()
		if not script:
			return _error("Node does not have a script: %s" % node_path)

		# Handle various script types safely
		if typeof(script) == TYPE_OBJECT and "resource_path" in script:
			script_path = script.resource_path
		elif typeof(script) == TYPE_STRING:
			script_path = script
		else:
			# Try to handle other script types gracefully
			print("Script type is not directly supported: ", typeof(script))
			if script.has_method("get_path"):
				script_path = script.get_path()
			elif script.has_method("get_source_code"):
				# Return the script content directly
				return _ok(
					{
						"script_path": node_path + " (embedded script)",
						"content": script.get_source_code(),
					},
				)
			else:
				return _error("Cannot extract script path from node: %s" % node_path)

	# Try to find the script if it's not found directly
	if not FileAccess.file_exists(script_path):
		var found_path = _find_script_file(script_path)
		if not found_path.is_empty():
			script_path = found_path
		else:
			return _error("Script file not found: %s" % script_path)

	# Read the script file
	var file = FileAccess.open(script_path, FileAccess.READ)
	if file == null:
		return _error("Failed to open script file: %s" % script_path)

	var content = file.get_as_text()
	file = null # Close the file

	return _ok(
		{
			"script_path": script_path,
			"content": content,
		},
	)
