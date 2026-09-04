@tool
## Base class for all tool providers. Provides shared editor utilities and
## defines the interface: get_definition() + execute(params) -> Dictionary.
class_name MCPToolProviderBase
extends RefCounted

## Override in subclass to return a ToolDefinition describing the tool.
func get_definition() -> ToolDefinition:
	push_error("ToolProviderBase.get_definition() not overridden")
	return null


## Override in subclass to implement the tool's execution logic.
## Returns {"ok": true, "data": {...}} on success, or {"ok": false, "error": "..."} on failure.
func execute(_params: Dictionary) -> Dictionary:
	push_error("ToolProviderBase.execute() not overridden")
	return _error("Not implemented")


# ---------------------------------------------------------------------------
# Response helpers
# ---------------------------------------------------------------------------
func _ok(data: Dictionary = { }) -> Dictionary:
	return { "ok": true, "data": data }


func _error(message: String) -> Dictionary:
	return { "ok": false, "error": message }


# ---------------------------------------------------------------------------
# Editor access helpers
# ---------------------------------------------------------------------------
func _get_plugin():
	return Engine.get_meta("GodotMCPPlugin", null)


func _get_editor_interface():
	var plugin = _get_plugin()
	if plugin and plugin.has_method("get_editor_interface"):
		return plugin.get_editor_interface()
	return null


func _get_edited_scene_root() -> Node:
	var ei = _get_editor_interface()
	if ei:
		return ei.get_edited_scene_root()
	return null


func _get_undo_redo():
	var plugin = _get_plugin()
	if plugin and plugin.has_method("get_undo_redo"):
		return plugin.get_undo_redo()
	return null


# ---------------------------------------------------------------------------
# Node resolution helpers
# ---------------------------------------------------------------------------
func _get_editor_node(path: String) -> Node:
	var root = _get_edited_scene_root()
	if not root:
		return null

	var normalized = _normalize_node_path(path)
	if normalized.is_empty():
		return root

	var node = root.get_node_or_null(normalized)
	if node:
		return node

	var root_name = root.name
	if normalized == root_name:
		return root

	var root_prefix = root_name + "/"
	if normalized.begins_with(root_prefix):
		var trimmed = normalized.substr(root_prefix.length())
		if trimmed.is_empty():
			return root
		node = root.get_node_or_null(trimmed)
		if node:
			return node

	return null


func _get_editor_node_enhanced(path: String) -> Node:
	var node = _get_editor_node(path)
	if node:
		return node

	var root = _get_edited_scene_root()
	if not root:
		return null

	var normalized = _normalize_node_path(path)
	if normalized.is_empty():
		return root

	# Case-insensitive fallback for node name
	var lower_path = normalized.to_lower()
	if lower_path == root.name.to_lower():
		return root

	var parts = normalized.split("/")
	if parts.size() > 1 and parts[0].to_lower() == root.name.to_lower():
		var sub_path = ""
		for i in range(1, parts.size()):
			if i > 1:
				sub_path += "/"
			sub_path += parts[i]
		if sub_path.is_empty():
			return root
		node = root.get_node_or_null(sub_path)
		if node:
			return node
		normalized = sub_path
		lower_path = normalized.to_lower()

	# Try direct child match by name (case-insensitive)
	if normalized.find("/") == -1:
		for child in root.get_children():
			if child.name.to_lower() == lower_path:
				return child

	return null


func _normalize_node_path(path: String) -> String:
	var normalized = path.strip_edges()
	if normalized.is_empty() or normalized == "." or normalized == "/root":
		return ""
	while normalized.begins_with("/root/"):
		normalized = normalized.substr(6)
	while normalized.begins_with("./"):
		normalized = normalized.substr(2)
	if normalized.begins_with("/"):
		normalized = normalized.substr(1)
	if normalized.begins_with("."):
		normalized = normalized.substr(1)
	return normalized.strip_edges()


# ---------------------------------------------------------------------------
# Property / type helpers
# ---------------------------------------------------------------------------
func _parse_property_value(value):
	if typeof(value) != TYPE_STRING:
		return value

	var str_val: String = value
	if (
			str_val.begins_with("Vector") or
			str_val.begins_with("Transform") or
			str_val.begins_with("Rect") or
			str_val.begins_with("Color") or
			str_val.begins_with("Quat") or
			str_val.begins_with("Basis") or
			str_val.begins_with("Plane") or
			str_val.begins_with("AABB") or
			str_val.begins_with("Projection") or
			str_val.begins_with("Callable") or
			str_val.begins_with("Signal") or
			str_val.begins_with("PackedVector") or
			str_val.begins_with("PackedString") or
			str_val.begins_with("PackedFloat") or
			str_val.begins_with("PackedInt") or
			str_val.begins_with("PackedColor") or
			str_val.begins_with("PackedByteArray") or
			str_val.begins_with("Dictionary") or
			str_val.begins_with("Array")
	):
		var expression = Expression.new()
		var error = expression.parse(str_val, [])
		if error == OK:
			var result = expression.execute([], null, true)
			if not expression.has_execute_failed():
				return result

	return value


func _mark_scene_modified() -> void:
	var ei = _get_editor_interface()
	if ei and ei.get_edited_scene_root():
		ei.mark_scene_as_unsaved()

# ---------------------------------------------------------------------------
# Script file resolution
# ---------------------------------------------------------------------------


## Search for a script file by name or partial path.
## Returns the full res:// path if found, or an empty string.
func _find_script_file(path: String) -> String:
	# Strip res:// prefix if present for searching
	var search_name := path.trim_prefix("res://")

	# Try direct match first
	if ResourceLoader.exists(path):
		return path

	var dir := DirAccess.open("res://")
	if not dir:
		return ""

	var found := _search_dir_for_script(dir, search_name)
	if not found.is_empty():
		return found

	# Try with .gd extension if not present
	if not search_name.ends_with(".gd"):
		search_name += ".gd"
		found = _search_dir_for_script(dir, search_name)

	return found


func _search_dir_for_script(dir: DirAccess, target: String) -> String:
	dir.list_dir_begin()
	var file_name := dir.get_next()
	while not file_name.is_empty():
		if file_name == "." or file_name == "..":
			file_name = dir.get_next()
			continue

		var full_path := dir.get_current_dir().trim_prefix("res://") + "/" + file_name
		full_path = full_path.trim_prefix("/")

		if dir.current_is_dir():
			var sub_dir := DirAccess.open(dir.get_current_dir() + "/" + file_name)
			if sub_dir:
				var sub_result := _search_dir_for_script(sub_dir, target)
				if not sub_result.is_empty():
					return sub_result
		elif file_name.ends_with(".gd") and file_name == target:
			return "res://" + full_path
		elif file_name.ends_with(".gd") and full_path.ends_with(target):
			return "res://" + full_path

		file_name = dir.get_next()

	dir.list_dir_end()
	return ""

# ---------------------------------------------------------------------------
# Type coercion helpers
# ---------------------------------------------------------------------------


## Coerce a value to bool.
func _coerce(v, d: bool) -> bool:
	if typeof(v) == TYPE_BOOL:
		return v
	if typeof(v) == TYPE_STRING:
		return v.to_lower() in ["true", "1", "yes"]
	if typeof(v) == TYPE_INT or typeof(v) == TYPE_FLOAT:
		return v != 0
	return d
