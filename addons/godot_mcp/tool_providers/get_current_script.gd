@tool
## Tool provider for "get_current_script" — Get the currently edited script in the script editor.
class_name ToolProviderGetCurrentScript
extends MCPToolProviderBase

func get_definition() -> ToolDefinition:
	return ToolDefinition.new(
		"get_current_script",
		"Get the currently edited script in the script editor.",
		{
			"type": "object",
			"properties": { },
		},
		"get_current_script",
	)


func execute(_params: Dictionary) -> Dictionary:
	# Get editor plugin and interfaces
	var plugin = Engine.get_meta("GodotMCPPlugin")
	if not plugin:
		return _error("GodotMCPPlugin not found in Engine metadata")

	var editor_interface = plugin.get_editor_interface()
	var script_editor = editor_interface.get_script_editor()
	var current_script = script_editor.get_current_script()

	if not current_script:
		return _ok(
			{
				"script_found": false,
				"message": "No script is currently being edited",
			},
		)

	var script_path = current_script.resource_path

	# Read the script content
	var file = FileAccess.open(script_path, FileAccess.READ)
	if not file:
		return _error("Failed to open script file: %s" % script_path)

	var content = file.get_as_text()
	file = null # Close the file

	return _ok(
		{
			"script_found": true,
			"script_path": script_path,
			"content": content,
		},
	)
