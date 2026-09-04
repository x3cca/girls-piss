@tool
## Tool provider for "list_project_files" — List project files, optionally filtered by extension.
class_name ToolProviderListProjectFiles
extends MCPToolProviderBase

func get_definition() -> ToolDefinition:
	return ToolDefinition.new(
		"list_project_files",
		"List project files, optionally filtered by extension.",
		{
			"type": "object",
			"properties": {
				"extensions": {
					"type": "array",
					"items": {
						"type": "string",
					},
					"description": "File extensions to filter by (e.g. ['.gd', '.tscn'])",
				},
			},
		},
		"list_project_files",
	)


func execute(params: Dictionary) -> Dictionary:
	var extensions = params.get("extensions", [])
	var files = []

	# Get all files with the specified extensions
	var dir = DirAccess.open("res://")
	if dir:
		_scan_directory(dir, "", extensions, files)
	else:
		return _error("Failed to open res:// directory")

	return _ok(
		{
			"files": files,
		},
	)


func _scan_directory(dir: DirAccess, current_path: String, extensions: Array, files: Array) -> void:
	dir.list_dir_begin()
	var file_name := dir.get_next()
	while not file_name.is_empty():
		if file_name == "." or file_name == "..":
			file_name = dir.get_next()
			continue

		var full_path := current_path + "/" + file_name
		if full_path.begins_with("/"):
			full_path = full_path.substr(1)

		if dir.current_is_dir():
			var sub_dir := DirAccess.open("res://" + full_path)
			if sub_dir:
				_scan_directory(sub_dir, full_path, extensions, files)
		else:
			if extensions.is_empty():
				files.append("res://" + full_path)
			else:
				for ext in extensions:
					if file_name.ends_with(str(ext)):
						files.append("res://" + full_path)
						break

		file_name = dir.get_next()

	dir.list_dir_end()
