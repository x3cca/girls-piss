@tool
class_name ToolProviderGetEditorSceneStructure
extends MCPToolProviderBase

func get_definition() -> ToolDefinition:
	return ToolDefinition.new(
		"get_editor_scene_structure",
		"Get the structure of the currently edited scene.",
		{
			"type": "object",
			"properties": {
				"include_properties": {
					"type": "boolean",
					"description": "Include node properties",
				},
				"include_scripts": { "type": "boolean", "description": "Include script info" },
				"max_depth": {
					"type": "number",
					"description": "Maximum tree depth (-1 = unlimited)",
				},
			},
		},
		"get_editor_scene_structure",
	)


func execute(params: Dictionary) -> Dictionary:
	var opts := _build_opts(params)
	var ei = _get_editor_interface()
	if not ei:
		return _error("Could not access EditorInterface")
	var root = ei.get_edited_scene_root()
	if not root:
		return _error("No scene is currently being edited")
	var sp: String = ""
	if "scene_file_path" in root:
		var sp_type = typeof(root.scene_file_path)
		sp = str(root.scene_file_path) if sp_type != TYPE_STRING \
		else root.scene_file_path
	if sp.is_empty():
		sp = "Unsaved Scene"
	return _ok(
		{
			"scene_path": sp,
			"path": sp,
			"root_node_type": root.get_class(),
			"root_node_name": root.name,
			"structure": _build_info(root, opts, 0),
		},
	)


func _build_opts(params: Dictionary) -> Dictionary:
	return {
		"include_properties": _coerce(params.get("include_properties"), false),
		"include_scripts": _coerce(params.get("include_scripts"), false),
		"max_depth": int(params.get("max_depth", -1)),
	}


func _build_info(node: Node, opts: Dictionary, depth: int) -> Dictionary:
	var info := {
		"name": node.name,
		"type": node.get_class(),
		"path": node.get_path(),
		"children": [],
	}
	if opts.get("include_properties", false):
		var props := { }
		if node.has_method("get_property_list"):
			for p in node.get_property_list():
				if p.usage & PROPERTY_USAGE_EDITOR and not (p.usage & PROPERTY_USAGE_CATEGORY):
					if p.name in ["position", "rotation", "scale", "text", "visible"]:
						props[p.name] = node.get(p.name)
		if props.size() > 0:
			info["properties"] = props
	if opts.get("include_scripts", false):
		var script = node.get_script()
		if script:
			var sp: String = script.resource_path if "resource_path" in script else ""
			info["script"] = { "path": sp, "class_name": "" }
	var md := opts.get("max_depth", -1)
	if md >= 0 and depth >= md:
		return info
	for child in node.get_children():
		info["children"].append(_build_info(child, opts, depth + 1))
	return info


func _coerce(v, d: bool) -> bool:
	if typeof(v) == TYPE_BOOL:
		return v
	if typeof(v) == TYPE_STRING:
		return v.to_lower() == "true"
	return d
