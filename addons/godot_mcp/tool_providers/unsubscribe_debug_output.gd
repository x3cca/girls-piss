@tool
class_name ToolProviderUnsubscribeDebugOutput
extends MCPToolProviderBase

func get_definition() -> ToolDefinition:
	return ToolDefinition.new(
		"unsubscribe_debug_output",
		"Unsubscribe from live debug output.",
		{
			"type": "object",
			"properties": { },
		},
		"unsubscribe_debug_output",
	)


func execute(_params: Dictionary) -> Dictionary:
	var p = _get_publisher()
	if p == null:
		return _error("Debug output publisher unavailable.")
	p.unsubscribe(-1)
	return _ok({ "subscribed": false, "message": "Live debug output streaming disabled." })


func _get_publisher():
	if Engine.has_meta("MCPDebugOutputPublisher"):
		return Engine.get_meta("MCPDebugOutputPublisher")
	return null
