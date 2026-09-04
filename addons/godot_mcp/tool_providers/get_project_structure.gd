@tool
## Tool provider for "get_project_structure" — Get project file structure summary.
class_name ToolProviderGetProjectStructure
extends MCPToolProviderBase

func get_definition() -> ToolDefinition:
	return ToolDefinition.new(
		"get_project_structure",
		"Get a summary of the project file structure (directories and file counts by extension).",
		{
			"type": "object",
			"properties": { },
		},
		"get_project_structure",
	)


func execute(_params: Dictionary) -> Dictionary:
	var structure = {
		"directories": [],
		"file_counts": { },
		"total_files": 0,
	}

	var dir = DirAccess.open("res://")
	if dir:
		_scan_structure(dir, "", structure)
	else:
		return _error("Failed to open res:// directory")

	return _ok(structure)


func _scan_structure(dir: DirAccess, dir_path: String, structure: Dictionary) -> void:
	dir.list_dir_begin()
	var file_name := dir.get_next()
	while not file_name.is_empty():
		if file_name == "." or file_name == "..":
			file_name = dir.get_next()
			continue

		var full_path := dir_path + "/" + file_name
		if full_path.begins_with("/"):
			full_path = full_path.substr(1)

		if dir.current_is_dir():
			structure["directories"].append(full_path)
			var sub_dir := DirAccess.open("res://" + full_path)
			if sub_dir:
				_scan_structure(sub_dir, full_path, structure)
		else:
			structure["total_files"] += 1
			var ext := file_name.get_extension()
			if not ext.is_empty():
				ext = "." + ext
				if structure["file_counts"].has(ext):
					structure["file_counts"][ext] += 1
				else:
					structure["file_counts"][ext] = 1

		file_name = dir.get_next()

	dir.list_dir_end()
