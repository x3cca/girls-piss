@tool
## Tool provider for "edit_script" — Edit a script's source code by overwriting the file content.
class_name ToolProviderEditScript
extends MCPToolProviderBase

func get_definition() -> ToolDefinition:
	return ToolDefinition.new(
		"edit_script",
		"Edit a script's source code by overwriting the file content.",
		{
			"type": "object",
			"properties": {
				"script_path": {
					"type": "string",
					"description": "Path to the script file to edit",
				},
				"content": {
					"type": "string",
					"description": "New source code content for the script",
				},
			},
			"required": ["script_path", "content"],
		},
		"edit_script",
	)


func execute(params: Dictionary) -> Dictionary:
	var script_path = params.get("script_path", "")
	var content = params.get("content", "")

	# Validation
	if script_path.is_empty():
		return _error("Script path cannot be empty")

	if content.is_empty():
		return _error("Content cannot be empty")

	# Make sure we have an absolute path
	if not script_path.begins_with("res://"):
		script_path = "res://" + script_path

	# Try to find the script if not found directly
	if not FileAccess.file_exists(script_path):
		var found_path = _find_script_file(script_path)
		if not found_path.is_empty():
			script_path = found_path
		else:
			return _error("Script file not found: %s" % script_path)

	# Edit the script file
	var file = FileAccess.open(script_path, FileAccess.WRITE)
	if file == null:
		return _error("Failed to open script file: %s" % script_path)

	file.store_string(content)
	file = null # Close the file

	return _ok(
		{
			"script_path": script_path,
		},
	)
