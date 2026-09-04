@tool
## Shared types, constants, and enums for the MCP protocol implementation.
class_name MCPTypes

## Current MCP protocol version supported
const PROTOCOL_VERSION := "2025-03-26"

## Default HTTP port for the MCP server
const DEFAULT_PORT := 9080

## Default bind address
const DEFAULT_BIND := "127.0.0.1"

## SSE keepalive interval in seconds
const SSE_KEEPALIVE_INTERVAL := 30.0

## JSON-RPC error codes (standard + MCP-specific)
enum ErrorCode {
	# JSON-RPC standard
	PARSE_ERROR = -32700,
	INVALID_REQUEST = -32600,
	METHOD_NOT_FOUND = -32601,
	INVALID_PARAMS = -32602,
	INTERNAL_ERROR = -32603,

	# MCP-specific (from spec)
	TOOL_NOT_FOUND = -32000,
	TOOL_EXECUTION_ERROR = -32001,
	RESOURCE_NOT_FOUND = -32002,
	RESOURCE_ACCESS_ERROR = -32003,

	# Custom
	NOT_INITIALIZED = -32010,
	ALREADY_INITIALIZED = -32011,
}

## MCP notification method constants
enum Notification {
	TOOLS_LIST_CHANGED,
	RESOURCES_LIST_CHANGED,
	RESOURCE_UPDATED,
	INITIALIZED,
	STOPPED,
}

const NOTIFICATION_METHODS := {
	Notification.TOOLS_LIST_CHANGED: "notifications/tools/list_changed",
	Notification.RESOURCES_LIST_CHANGED: "notifications/resources/list_changed",
	Notification.RESOURCE_UPDATED: "notifications/resources/updated",
	Notification.INITIALIZED: "notifications/initialized",
	Notification.STOPPED: "notifications/stopped",
}


## Create a standard MCP JSON-RPC request
static func make_request(
		method: String,
		params: Dictionary = { },
		id: Variant = null,
) -> Dictionary:
	var req := {
		"jsonrpc": "2.0",
		"method": method,
	}
	if not params.is_empty():
		req["params"] = params
	if id != null:
		req["id"] = id
	return req


## Create a standard MCP JSON-RPC success response
static func make_success_response(id: Variant, result: Dictionary = { }) -> Dictionary:
	return {
		"jsonrpc": "2.0",
		"id": id,
		"result": result,
	}


## Create a standard MCP JSON-RPC error response
static func make_error_response(
		id: Variant,
		code: int,
		message: String,
		data: Variant = null,
) -> Dictionary:
	var err := {
		"jsonrpc": "2.0",
		"id": id,
		"error": {
			"code": code,
			"message": message,
		},
	}
	if data != null:
		err["error"]["data"] = data
	return err


## Create a standard MCP JSON-RPC notification (no id)
static func make_notification(method: String, params: Dictionary = { }) -> Dictionary:
	var notif := {
		"jsonrpc": "2.0",
		"method": method,
	}
	if not params.is_empty():
		notif["params"] = params
	return notif


## Build a JSON Schema for a tool parameter
static func make_param_schema(
		_name: String,
		description: String,
		param_type: String = "string",
		_required: bool = true,
) -> Dictionary:
	var schema := {
		"type": param_type,
		"description": description,
	}
	# Just return the schema fragment — caller assembles full object
	return schema
