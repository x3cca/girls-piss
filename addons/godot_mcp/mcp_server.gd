@tool
extends EditorPlugin

var http_server: HttpServer = null
var mcp_sse: MCPSse = null
var mcp_core: MCPServerCore = null

var panel = null # Reference to the MCP panel
var runtime_debugger_bridge = null # Runtime scene inspection bridge
var debugger_bridge = null # Debugger control bridge
var debug_output_publisher = null # Live debug output broadcaster
var _runtime_bridge_warning_logged := false
var _debugger_bridge_warning_logged := false
const SCENE_CAPTURE_NAMES := ["scene", "limboai", "mcp_eval", "mcp_input"]
const STACK_CAPTURE_NAMES := ["stack", "call_stack", "callstack"]

const INPUT_HANDLER_AUTOLOAD_NAME := "MCPInputHandler"
const INPUT_HANDLER_SCRIPT_PATH := "res://addons/godot_mcp/mcp/mcp_input_handler.gd"


func _enter_tree():
	# Store plugin instance for EditorInterface access
	Engine.set_meta("GodotMCPPlugin", self)
	_runtime_bridge_warning_logged = false
	_debugger_bridge_warning_logged = false
	_try_register_runtime_bridge()
	_try_register_debugger_bridge()
	_register_input_handler_autoload()

	print("\n=== MCP HTTP+SSE SERVER STARTING ===")

	# Initialize the SSE manager (before HTTP server)
	mcp_sse = load("res://addons/godot_mcp/mcp/mcp_sse.gd").new()
	mcp_sse.name = "MCPSse"
	add_child(mcp_sse)

	# Initialize the MCP protocol core
	mcp_core = load("res://addons/godot_mcp/mcp_server_core.gd").new()
	mcp_core.name = "MCPServerCore"
	add_child(mcp_core)

	# Bind SSE session lifecycle to core — resets init state on disconnect
	mcp_core.bind_sse(mcp_sse)

	# Initialize the HTTP server with GodotTPD
	http_server = HttpServer.new()
	http_server.port = MCPTypes.DEFAULT_PORT
	http_server.bind_address = MCPTypes.DEFAULT_BIND
	add_child(http_server)

	# Create and register the MCP Router
	var mcp_router = MCPRouter.new("/mcp", mcp_sse, mcp_core)
	http_server.register_router(mcp_router)

	# Initialize the control panel
	panel = load("res://addons/godot_mcp/ui/mcp_panel.tscn").instantiate()
	panel.http_server = http_server
	panel.mcp_sse = mcp_sse
	add_control_to_bottom_panel(panel, "MCP Server")

	# Initialize live debug output publisher
	var publisher_script = load("res://addons/godot_mcp/debugger/mcp_debug_output_publisher.gd")
	if publisher_script:
		debug_output_publisher = publisher_script.new()
		debug_output_publisher.name = "DebugOutputPublisher"
		debug_output_publisher.mcp_sse = mcp_sse
		add_child(debug_output_publisher)
		Engine.set_meta("MCPDebugOutputPublisher", debug_output_publisher)

	print("MCP HTTP+SSE Server plugin initialized")


func _ready():
	# Auto-start the server after the editor is fully initialized
	call_deferred("_auto_start_server")


func _auto_start_server(attempt: int = 0):
	# Check if running in --check-only mode — exit cleanly instead of starting the server
	if OS.get_cmdline_args().has("--check-only"):
		print("✓ MCP server: --check-only detected, exiting cleanly")
		get_tree().quit()
		return

	# Use a timer delay instead of await process_frame — more reliable in the editor
	await get_tree().create_timer(0.5).timeout

	if not http_server:
		return

	print("Attempting to start MCP HTTP server...")
	http_server.start()

	# Verify and report
	await get_tree().create_timer(0.5).timeout
	if http_server.is_listening():
		print(
			"✓ MCP HTTP server auto-started on http://%s:%d" % [
				http_server.bind_address,
				http_server.port,
			],
		)
		_sync_panel_ui()
	else:
		if attempt < 3:
			print("✗ MCP server start failed, retrying... (attempt %d/3)" % [attempt + 1])
			await get_tree().create_timer(1.0).timeout
			_auto_start_server(attempt + 1)
		else:
			printerr("✗ Failed to auto-start MCP server after 3 attempts")
			printerr("Use the Start button in the MCP Server bottom panel")


func _sync_panel_ui():
	# Sync the panel UI to reflect the server state after auto-start
	if panel and panel.has_method(&"update_ui"):
		panel.update_ui()
	if panel and panel.has_method(&"log_message"):
		panel.log_message("Server auto-started on port " + str(http_server.port))


func _exit_tree():
	# Remove plugin instance from Engine metadata
	if Engine.has_meta("GodotMCPPlugin"):
		Engine.remove_meta("GodotMCPPlugin")
	if Engine.has_meta("MCPRuntimeDebuggerBridge"):
		Engine.remove_meta("MCPRuntimeDebuggerBridge")
	if Engine.has_meta("MCPDebuggerBridge"):
		Engine.remove_meta("MCPDebuggerBridge")
	if Engine.has_meta("MCPDebugOutputPublisher"):
		Engine.remove_meta("MCPDebugOutputPublisher")
	_update_debugger_captures(false)
	_remove_input_handler_autoload()

	if runtime_debugger_bridge:
		remove_debugger_plugin(runtime_debugger_bridge)
		runtime_debugger_bridge = null

	if debugger_bridge:
		remove_debugger_plugin(debugger_bridge)
		debugger_bridge = null

	# Clean up the panel
	if panel:
		remove_control_from_bottom_panel(panel)
		panel.queue_free()
		panel = null

	# Clean up debug output publisher
	if debug_output_publisher:
		debug_output_publisher.unsubscribe_all()
		debug_output_publisher.queue_free()
		debug_output_publisher = null

	# Clean up SSE connections
	if mcp_sse:
		mcp_sse.clear_all()
		mcp_sse.queue_free()
		mcp_sse = null

	# Clean up HTTP server
	if http_server:
		http_server.stop()
		http_server.queue_free()
		http_server = null

	# Clean up MCP core
	if mcp_core:
		mcp_core.queue_free()
		mcp_core = null

	print("=== MCP HTTP+SSE SERVER SHUTDOWN ===")


# Method to get the debugger bridge for other components
func get_debugger_bridge():
	return debugger_bridge


# Helper function for command processors to access EditorInterface
func get_editor_interface():
	return super.get_editor_interface()


# Helper function for command processors to get undo/redo manager
func get_undo_redo():
	return super.get_undo_redo()


func _try_register_runtime_bridge() -> bool:
	if runtime_debugger_bridge:
		return true

	var runtime_bridge_script = load(
		"res://addons/godot_mcp/debugger/mcp_runtime_debugger_bridge.gd",
	)
	if not runtime_bridge_script:
		if not _runtime_bridge_warning_logged:
			_runtime_bridge_warning_logged = true
			print("Godot MCP runtime scene inspection unavailable (bridge script not found).")
		return false

	if not ClassDB.class_exists("EditorDebuggerPlugin"):
		if not _runtime_bridge_warning_logged:
			_runtime_bridge_warning_logged = true
			print("Godot MCP runtime scene inspection unavailable on this editor version.")
		return false

	var runtime_bridge_instance = runtime_bridge_script.new()
	if runtime_bridge_instance == null:
		if not _runtime_bridge_warning_logged:
			_runtime_bridge_warning_logged = true
			print("Godot MCP runtime scene inspection disabled (bridge instantiation failed).")
		return false

	runtime_debugger_bridge = runtime_bridge_instance
	add_debugger_plugin(runtime_debugger_bridge)
	Engine.set_meta("MCPRuntimeDebuggerBridge", runtime_debugger_bridge)
	_update_debugger_captures(true)
	_runtime_bridge_warning_logged = false
	print("Godot MCP runtime scene inspection enabled.")
	return true


func _try_register_debugger_bridge() -> bool:
	if debugger_bridge:
		return true

	var debugger_bridge_script = load("res://addons/godot_mcp/debugger/mcp_debugger_bridge.gd")
	if not debugger_bridge_script:
		if not _debugger_bridge_warning_logged:
			_debugger_bridge_warning_logged = true
			print("Godot MCP debugger bridge unavailable (bridge script not found).")
		return false

	if not ClassDB.class_exists("EditorDebuggerPlugin"):
		if not _debugger_bridge_warning_logged:
			_debugger_bridge_warning_logged = true
			print("Godot MCP debugger bridge unavailable on this editor version.")
		return false

	var debugger_bridge_instance = debugger_bridge_script.new()
	if debugger_bridge_instance == null:
		if not _debugger_bridge_warning_logged:
			_debugger_bridge_warning_logged = true
			print("Godot MCP debugger bridge disabled (bridge instantiation failed).")
		return false

	debugger_bridge = debugger_bridge_instance
	add_debugger_plugin(debugger_bridge)
	Engine.set_meta("MCPDebuggerBridge", debugger_bridge)
	_debugger_bridge_warning_logged = false
	print("Godot MCP debugger bridge enabled.")
	return true


func _update_debugger_captures(enable: bool) -> void:
	if not Engine.has_singleton("EngineDebugger"):
		return
	var engine_debugger = Engine.get_singleton("EngineDebugger")
	if engine_debugger == null:
		return
	if not engine_debugger.has_method("set_capture"):
		return
	var has_query := engine_debugger.has_method("has_capture")
	for name in SCENE_CAPTURE_NAMES + STACK_CAPTURE_NAMES:
		if enable:
			if not has_query or not engine_debugger.has_capture(name):
				engine_debugger.set_capture(name, true)
		else:
			if not has_query or engine_debugger.has_capture(name):
				engine_debugger.set_capture(name, false)


func _register_input_handler_autoload() -> void:
	# Check if autoload already exists
	if ProjectSettings.has_setting("autoload/" + INPUT_HANDLER_AUTOLOAD_NAME):
		print("MCP Input Handler autoload already registered.")
		return

	# Verify the script exists
	if not FileAccess.file_exists(INPUT_HANDLER_SCRIPT_PATH):
		printerr("MCP Input Handler script not found at: " + INPUT_HANDLER_SCRIPT_PATH)
		return

	# Add the autoload
	ProjectSettings.set_setting(
		"autoload/" + INPUT_HANDLER_AUTOLOAD_NAME,
		"*" + INPUT_HANDLER_SCRIPT_PATH,
	)
	ProjectSettings.save()
	print("MCP Input Handler autoload registered. Restart the game for input simulation to work.")


func _remove_input_handler_autoload() -> void:
	# Check if autoload exists before removing
	if not ProjectSettings.has_setting("autoload/" + INPUT_HANDLER_AUTOLOAD_NAME):
		return

	# Remove the autoload
	ProjectSettings.set_setting("autoload/" + INPUT_HANDLER_AUTOLOAD_NAME, null)
	ProjectSettings.save()
	print("MCP Input Handler autoload removed.")
