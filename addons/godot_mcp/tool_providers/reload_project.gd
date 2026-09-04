@tool
## Tool provider for "reload_project" — Restart the Godot editor (reload the entire project).
class_name ToolProviderReloadProject
extends MCPToolProviderBase

func get_definition() -> ToolDefinition:
	return ToolDefinition.new(
		"reload_project",
		"Restart the Godot editor (reload the entire project).",
		{
			"type": "object",
			"properties": {
				"save": {
					"type": "boolean",
					"description": "Save before restarting (default: true)",
				},
			},
		},
		"reload_project",
	)


func execute(params: Dictionary) -> Dictionary:
	var plugin = Engine.get_meta("GodotMCPPlugin")
	if not plugin:
		return _error("GodotMCPPlugin not found in Engine metadata")

	var editor_interface = plugin.get_editor_interface()
	var save_before_restart: bool = params.get("save", true)

	# Send success response before restarting (since restart will disconnect)
	return _ok(
		{
			"status": "restarting",
			"save": save_before_restart,
			"message": "Godot editor is restarting...",
		},
	)

	# Use call_deferred to allow the response to be sent before restart
	editor_interface.call_deferred("restart_editor", save_before_restart)
