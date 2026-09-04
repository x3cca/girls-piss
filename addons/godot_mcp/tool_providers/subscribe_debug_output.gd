@tool
class_name ToolProviderSubscribeDebugOutput
extends MCPToolProviderBase

func get_definition() -> ToolDefinition:
	return ToolDefinition.new(
		"subscribe_debug_output",
		"Subscribe to live debug output streaming.",
		{
			"type": "object",
			"properties": { },
		},
		"subscribe_debug_output",
	)


func execute(_params: Dictionary) -> Dictionary:
	var p = _get_publisher()
	if p == null:
		return _error("Debug output publisher unavailable.")
	p.subscribe(-1) # All clients
	return _ok({ "subscribed": true, "message": "Live debug output streaming enabled." })


func _get_publisher():
	if Engine.has_meta("MCPDebugOutputPublisher"):
		return Engine.get_meta("MCPDebugOutputPublisher")
	return null
