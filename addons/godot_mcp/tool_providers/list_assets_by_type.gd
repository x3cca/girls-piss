@tool
class_name ToolProviderListAssetsByType
extends MCPToolProviderBase

func get_definition() -> ToolDefinition:
	return ToolDefinition.new(
		"list_assets_by_type",
		"List project assets grouped by type.",
		{
			"type": "object",
			"properties": {
				"type": {
					"type": "string",
					"description": "Asset type: scenes, scripts, textures, audio, models, or all",
				},
			},
		},
		"list_assets_by_type",
	)


func execute(params: Dictionary) -> Dictionary:
	var asset_type: String = params.get("type", "all")
	var result: Dictionary = { }
	if asset_type == "all" or asset_type == "scenes":
		result["scenes"] = _find_by_ext([".tscn", ".scn"])
	if asset_type == "all" or asset_type == "scripts":
		result["scripts"] = _find_by_ext([".gd", ".cs"])
	if asset_type == "all" or asset_type == "textures":
		result["textures"] = _find_by_ext([".png", ".jpg", ".jpeg", ".webp", ".bmp"])
	if asset_type == "all" or asset_type == "audio":
		result["audio"] = _find_by_ext([".wav", ".ogg", ".mp3", ".import"])
	if asset_type == "all" or asset_type == "models":
		result["models"] = _find_by_ext([".obj", ".glb", ".gltf"])
	if asset_type == "all" or asset_type == "resources":
		result["resources"] = _find_by_ext([".tres", ".res"])
	return _ok(result)


func _find_by_ext(exts: Array) -> Array:
	var r: Array = []
	_scan("res://", exts, r)
	return r


func _scan(dir_path: String, exts: Array, results: Array) -> void:
	var d := DirAccess.open(dir_path)
	if not d:
		return
	d.list_dir_begin()
	var fn := d.get_next()
	while fn != "":
		if fn == "." or fn == "..":
			fn = d.get_next()
			continue
		var fp := dir_path + fn
		if d.current_is_dir():
			if not fn.begins_with("."):
				_scan(fp + "/", exts, results)
		else:
			for e in exts:
				if fn.ends_with(e):
					results.append(fp)
					break
		fn = d.get_next()
	d.list_dir_end()
