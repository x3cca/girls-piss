@tool
## Tool provider for "list_project_resources" — List project resources categorized by type.
class_name ToolProviderListProjectResources
extends MCPToolProviderBase

func get_definition() -> ToolDefinition:
	return ToolDefinition.new(
		"list_project_resources",
		"List project resources categorized by type.",
		{
			"type": "object",
			"properties": { },
		},
		"list_project_resources",
	)


func execute(_params: Dictionary) -> Dictionary:
	var resources = {
		"scenes": [],
		"scripts": [],
		"textures": [],
		"audio": [],
		"models": [],
		"resources": [],
	}

	var dir = DirAccess.open("res://")
	if dir:
		_scan_resources(dir, "", resources)
	else:
		return _error("Failed to open res:// directory")

	return _ok(resources)


func _scan_resources(dir: DirAccess, current_path: String, resources: Dictionary) -> void:
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
				_scan_resources(sub_dir, full_path, resources)
		else:
			var ext := file_name.get_extension().to_lower()
			if ext in ["tscn", "scn", "escn"]:
				resources["scenes"].append("res://" + full_path)
			elif ext in ["gd", "cs"]:
				resources["scripts"].append("res://" + full_path)
			elif ext in ["png", "jpg", "jpeg", "svg", "webp", "bmp", "tga", "exr"]:
				resources["textures"].append("res://" + full_path)
			elif ext in ["ogg", "mp3", "wav", "flac"]:
				resources["audio"].append("res://" + full_path)
			elif ext in ["glb", "gltf", "obj", "dae", "fbx"]:
				resources["models"].append("res://" + full_path)
			elif ext in ["tres", "res", "theme", "material", "shader", "font"]:
				resources["resources"].append("res://" + full_path)

		file_name = dir.get_next()

	dir.list_dir_end()
