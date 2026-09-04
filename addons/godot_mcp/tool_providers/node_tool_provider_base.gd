@tool
## Node-based base class for tool providers that need HTTP requests, timers,
## signals, or other scene-tree features. Provides the same interface as
## MCPToolProviderBase (get_definition + execute) but is a Node so it can
## be added as a child of the plugin for async operations.
class_name MCPNodeToolProviderBase
extends Node

## Override in subclass to return one or more ToolDefinitions.
## For single-tool providers: return one ToolDefinition.
## For multi-tool providers: return an Array[ToolDefinition].
func get_definitions() -> Array:
	push_error("MCPNodeToolProviderBase.get_definitions() not overridden")
	return []


## Override: execute a tool by name. Returns { ok, data } or { ok, error }.
## May be async (caller should await).
func execute_tool(_tool_name: String, _params: Dictionary) -> Dictionary:
	push_error("MCPNodeToolProviderBase.execute_tool() not overridden")
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
# Debugger bridge access (for debugger + input + enhanced tools)
# ---------------------------------------------------------------------------
func _get_debugger_bridge():
	if Engine.has_meta("MCPDebuggerBridge"):
		return Engine.get_meta("MCPDebuggerBridge")
	return null


func _get_runtime_bridge():
	if Engine.has_meta("MCPRuntimeDebuggerBridge"):
		return Engine.get_meta("MCPRuntimeDebuggerBridge")
	return null


# ---------------------------------------------------------------------------
# Node helpers
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


func _mark_scene_modified() -> void:
	var ei = _get_editor_interface()
	if ei and ei.get_edited_scene_root():
		ei.mark_scene_as_unsaved()
