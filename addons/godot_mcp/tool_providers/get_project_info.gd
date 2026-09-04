@tool
## Tool provider for "get_project_info" — Get project information.
class_name ToolProviderGetProjectInfo
extends MCPToolProviderBase

func get_definition() -> ToolDefinition:
	return ToolDefinition.new(
		"get_project_info",
		"Get project information.",
		{
			"type": "object",
			"properties": { },
		},
		"get_project_info",
	)


func execute(_params: Dictionary) -> Dictionary:
	var project_name = ProjectSettings.get_setting("application/config/name", "Untitled Project")
	var project_version = ProjectSettings.get_setting("application/config/version", "1.0.0")
	var project_path = ProjectSettings.globalize_path("res://")

	# Get Godot version info and structure it as expected by the server
	var version_info = Engine.get_version_info()
	print("Raw Godot version info: ", version_info)

	# Create structured version object with the expected properties
	var structured_version = {
		"major": version_info.get("major", 0),
		"minor": version_info.get("minor", 0),
		"patch": version_info.get("patch", 0),
	}

	return _ok(
		{
			"project_name": project_name,
			"project_version": project_version,
			"project_path": project_path,
			"godot_version": structured_version,
			"current_scene": (
					_get_editor_interface().get_edited_scene_root().scene_file_path
					if _get_editor_interface() and _get_editor_interface().get_edited_scene_root()
					else ""
			),
		},
	)
