@tool
class_name ToolProviderUpdateNodeTransform
extends MCPToolProviderBase

func get_definition() -> ToolDefinition:
	return ToolDefinition.new(
		"update_node_transform",
		"Update a node's position, rotation, or scale.",
		{
			"type": "object",
			"properties": {
				"node_path": { "type": "string", "description": "Path to the target node" },
				"position": { "description": "Position as [x,y] or {x,y}" },
				"rotation": { "type": "number", "description": "Rotation in radians" },
				"scale": { "description": "Scale as [x,y] or {x,y}" },
			},
			"required": ["node_path"],
		},
		"update_node_transform",
	)


func execute(params: Dictionary) -> Dictionary:
	var np: String = params.get("node_path", "")
	var pos = params.get("position", null)
	var rot = params.get("rotation", null)
	var scl = params.get("scale", null)

	var ei = _get_editor_interface()
	if not ei:
		return _error("Could not access EditorInterface")
	var root = ei.get_edited_scene_root()
	if not root:
		return _error("No scene open")
	var node = root.get_node_or_null(np)
	if not node:
		return _error("Node not found")

	if pos != null and node.has_method("set_position"):
		if pos is Array and pos.size() >= 2:
			node.set_position(Vector2(pos[0], pos[1]))
		elif typeof(pos) == TYPE_DICTIONARY and "x" in pos:
			node.set_position(Vector2(pos.x, pos.y))
	if rot != null and node.has_method("set_rotation"):
		node.set_rotation(rot)
	if scl != null and node.has_method("set_scale"):
		if scl is Array and scl.size() >= 2:
			node.set_scale(Vector2(scl[0], scl[1]))
		elif typeof(scl) == TYPE_DICTIONARY and "x" in scl:
			node.set_scale(Vector2(scl.x, scl.y))

	ei.mark_scene_as_unsaved()
	return _ok(
		{
			"success": true,
			"node_path": np,
			"updated": {
				"position": pos != null,
				"rotation": rot != null,
				"scale": scl != null,
			},
		},
	)
