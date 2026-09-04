@tool
## MCP Tool Definition — describes a single tool's name, schema, and command mapping.
class_name ToolDefinition
extends RefCounted

var name: String
var description: String
var input_schema: Dictionary ## JSON Schema
var command_type: String ## Maps to command_handler command type


func _init(p_name: String, p_description: String, p_schema: Dictionary, p_command: String):
	name = p_name
	description = p_description
	input_schema = p_schema
	command_type = p_command
