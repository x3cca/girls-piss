@tool
## Tool provider for "get_scene_structure" — Get the full scene tree structure with properties.
class_name ToolProviderGetSceneStructure
extends MCPToolProviderBase

func get_definition() -> ToolDefinition:
	return ToolDefinition.new(
		"get_scene_structure",
		"Get the full scene tree structure with properties.",
		{
			"type": "object",
			"properties": {
				"path": {
					"type": "string",
					"description": "Path to the .tscn file",
				},
			},
			"required": ["path"],
		},
		"get_scene_structure",
	)


func execute(params: Dictionary) -> Dictionary:
	var path = params.get("path", "")

	# Validation
	if path.is_empty():
		return _error("Scene path cannot be empty")

	if not path.begins_with("res://"):
		path = "res://" + path

	if not FileAccess.file_exists(path):
		return _error("Scene file not found: " + path)

	# Load the scene to analyze its structure
	var packed_scene = load(path)
	if not packed_scene:
		return _error("Failed to load scene: " + path)

	# Create a temporary instance to analyze
	var scene_instance = packed_scene.instantiate()
	if not scene_instance:
		return _error("Failed to instantiate scene: " + path)

	# Get the scene structure
	var structure = _get_node_structure(scene_instance)

	# Clean up the temporary instance
	scene_instance.queue_free()

	# Return the structure
	return _ok(
		{
			"path": path,
			"structure": structure,
		},
	)


func _get_node_structure(node: Node) -> Dictionary:
	var info: Dictionary = {
		"name": node.name,
		"type": node.get_class(),
		"children": [],
	}

	if node.get_child_count() > 0:
		for child in node.get_children():
			info["children"].append(_get_node_structure(child))

	# Include script info if attached
	var script = node.get_script()
	if script:
		info["script"] = script.resource_path if "resource_path" in script else ""

	return info
