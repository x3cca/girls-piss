@tool
## Tool provider for "get_node_warnings" — Inspect scene for node configuration warnings.
class_name ToolProviderGetNodeWarnings
extends MCPToolProviderBase

func get_definition() -> ToolDefinition:
	return ToolDefinition.new(
		"get_node_warnings",
		"Inspect the current scene for node configuration warnings.",
		{
			"type": "object",
			"properties": {
				"debug": {
					"type": "boolean",
					"description": "Include traversal debug stats",
				},
			},
		},
		"get_node_warnings",
	)


func execute(params: Dictionary) -> Dictionary:
	var plugin = Engine.get_meta("GodotMCPPlugin")
	if not plugin:
		return _error("GodotMCPPlugin not found in Engine metadata")

	var editor_interface = plugin.get_editor_interface()
	var edited_scene_root = editor_interface.get_edited_scene_root()
	if not edited_scene_root:
		return _error("No scene is currently being edited")

	var debug = _coerce(params.get("debug", false), false)
	var scene_path = edited_scene_root.scene_file_path
	if scene_path.is_empty():
		scene_path = "Unsaved Scene"

	var scene_tree = EditorUtils.find_scene_tree_editor_tree(
		editor_interface,
		edited_scene_root.name,
	)
	if not scene_tree:
		return _error("Scene tree dock not found")

	var scan = EditorUtils.collect_scene_tree_warning_entries(scene_tree, edited_scene_root.name)
	var warnings = scan.get("warnings", [])
	if warnings == null:
		warnings = []

	var result = {
		"scene_path": scene_path,
		"root_node_name": edited_scene_root.name,
		"root_node_type": edited_scene_root.get_class(),
		"tree_path": scan.get("tree_path", ""),
		"warnings": warnings,
		"warnings_count": warnings.size(),
		"items_scanned": scan.get("items_scanned", 0),
		"buttons_scanned": scan.get("buttons_scanned", 0),
	}

	if debug:
		result["debug"] = {
			"enabled": true,
			"tree_path": scan.get("tree_path", ""),
			"items_scanned": scan.get("items_scanned", 0),
			"buttons_scanned": scan.get("buttons_scanned", 0),
			"warnings_found": warnings.size(),
		}

	return _ok(result)
