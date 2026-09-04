@tool
## Tool provider for "create_resource" — Create a new resource file (e.g. Material, Shader, etc.).
class_name ToolProviderCreateResource
extends MCPToolProviderBase

func get_definition() -> ToolDefinition:
	return ToolDefinition.new(
		"create_resource",
		"Create a new resource file (e.g. Material, Shader, etc.).",
		{
			"type": "object",
			"properties": {
				"resource_type": {
					"type": "string",
					"description": "Resource class name (e.g. StandardMaterial3D, ShaderMaterial)",
				},
				"resource_path": {
					"type": "string",
					"description": "Path for the new resource file",
				},
				"properties": {
					"type": "object",
					"description": "Optional initial properties",
				},
			},
			"required": ["resource_type", "resource_path"],
		},
		"create_resource",
	)


func execute(params: Dictionary) -> Dictionary:
	var resource_type = params.get("resource_type", "")
	var resource_path = params.get("resource_path", "")
	var properties = params.get("properties", { })

	# Validation
	if resource_type.is_empty():
		return _error("Resource type cannot be empty")

	if resource_path.is_empty():
		return _error("Resource path cannot be empty")

	# Make sure we have an absolute path
	if not resource_path.begins_with("res://"):
		resource_path = "res://" + resource_path

	# Get editor interface
	var plugin = Engine.get_meta("GodotMCPPlugin")
	if not plugin:
		return _error("GodotMCPPlugin not found in Engine metadata")

	var editor_interface = plugin.get_editor_interface()

	# Create the resource
	var resource

	if ClassDB.class_exists(resource_type):
		if ClassDB.is_parent_class(resource_type, "Resource"):
			resource = ClassDB.instantiate(resource_type)
			if not resource:
				return _error("Failed to instantiate resource: %s" % resource_type)
		else:
			return _error("Type is not a Resource: %s" % resource_type)
	else:
		return _error("Invalid resource type: %s" % resource_type)

	# Set properties
	for key in properties:
		resource.set(key, properties[key])

	# Create directory if needed
	var dir = resource_path.get_base_dir()
	if not DirAccess.dir_exists_absolute(dir):
		var err = DirAccess.make_dir_recursive_absolute(dir)
		if err != OK:
			return _error("Failed to create directory: %s (Error code: %d)" % [dir, err])

	# Save the resource
	var result = ResourceSaver.save(resource, resource_path)
	if result != OK:
		return _error("Failed to save resource: %d" % result)

	# Refresh the filesystem
	editor_interface.get_resource_filesystem().scan()

	return _ok(
		{
			"resource_path": resource_path,
			"resource_type": resource_type,
		},
	)
