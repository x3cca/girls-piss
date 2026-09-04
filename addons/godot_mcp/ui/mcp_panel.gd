@tool
extends Control
## MCP Server panel docked in the editor bottom panel.
##
## Layout mirrors the editor Output tab:
##   Left:  RichTextLabel (monospace log) + bottom toolbar (filter, toggleable via sidebar button)
##   Right: Sidebar with [Clear] [Search], status, port, start/stop, connected clients

enum MessageType {
	STD,
	ERROR,
	WARNING,
	INFO,
}

var http_server: HttpServer = null
var mcp_sse: MCPSse = null

# -- UI node references --
var log: RichTextLabel
var status_label: Label
var port_input: SpinBox
var start_button: Button
var stop_button: Button
var count_label: Label
var search_box: LineEdit
var search_toggle: Button
var clear_button: Button

# -- Log state --
var _messages: Array[Dictionary] = [] # [{text: String, type: MessageType}]
var _filter_text: String = ""
var _line_limit: int = 10000

# -- Theme cache (mirrors Output tab pattern) --
var _theme_error_color: Color
var _theme_warning_color: Color
var _theme_info_color: Color

#region Lifecycle

func _ready() -> void:
	log = $MainHBox/LogArea/LogText
	status_label = $MainHBox/SidebarPanel/SidebarVBox/StatusLabel
	port_input = $MainHBox/SidebarPanel/SidebarVBox/PortSpinBox
	start_button = $MainHBox/SidebarPanel/SidebarVBox/StartButton
	stop_button = $MainHBox/SidebarPanel/SidebarVBox/StopButton
	count_label = $MainHBox/SidebarPanel/SidebarVBox/CountLabel
	search_box = $MainHBox/LogArea/BottomBar/FilterBox
	search_toggle = $MainHBox/SidebarPanel/SidebarVBox/ToolRow/SearchToggle
	clear_button = $MainHBox/SidebarPanel/SidebarVBox/ToolRow/ClearButton

	start_button.pressed.connect(_on_start_pressed)
	stop_button.pressed.connect(_on_stop_pressed)
	port_input.value_changed.connect(_on_port_changed)
	search_box.text_changed.connect(_on_filter_changed)
	search_toggle.toggled.connect(_on_search_toggled)
	clear_button.pressed.connect(_on_clear_pressed)

	_update_ui()
	_update_theme()
	_rebuild_log()
	_apply_min_height()

	await get_tree().process_frame
	if http_server and http_server.is_listening():
		log_message(
			"Server configured on port %d — already listening" % http_server.port,
			MessageType.INFO,
		)


func _notification(p_what: int) -> void:
	if p_what == NOTIFICATION_THEME_CHANGED and log:
		_update_theme()
		_rebuild_log()
		_apply_min_height()


func _update_theme() -> void:
	# Apply editor output fonts (same as Output tab) for monospace appearance.
	# Fall back to a system monospace font if editor theme items are unavailable.
	var normal_font := get_theme_font(&"output_source", &"EditorFonts")
	if not normal_font:
		normal_font = _create_mono_fallback()
	log.add_theme_font_override(&"normal_font", normal_font)

	var bold_font := get_theme_font(&"output_source_bold", &"EditorFonts")
	if not bold_font:
		bold_font = _create_mono_fallback()
	log.add_theme_font_override(&"bold_font", bold_font)

	var mono_font := get_theme_font(&"output_source_mono", &"EditorFonts")
	if not mono_font:
		mono_font = _create_mono_fallback()
	log.add_theme_font_override(&"mono_font", mono_font)

	var font_size := get_theme_font_size(&"output_source_size", &"EditorFonts")
	if font_size <= 0:
		font_size = 13
	log.add_theme_font_size_override(&"normal_font_size", font_size)
	log.add_theme_font_size_override(&"bold_font_size", font_size)
	log.add_theme_font_size_override(&"mono_font_size", font_size)

	# Zero padding on highlights to prevent overlapping on adjacent lines
	log.add_theme_constant_override(&"text_highlight_h_padding", 0)
	log.add_theme_constant_override(&"text_highlight_v_padding", 0)

	# Theme colors
	_theme_error_color = get_theme_color(&"error_color", &"Editor")
	_theme_warning_color = get_theme_color(&"warning_color", &"Editor")
	_theme_info_color = get_theme_color(&"font_color", &"Editor") * Color(1, 1, 1, 0.55)

	clear_button.icon = _get_icon(&"Clear")
	search_toggle.icon = _get_icon(&"Search")
	search_box.right_icon = _get_icon(&"Search")

#endregion

#region Public API (called by mcp_server.gd)

## Refresh sidebar controls to match server state.
func update_ui() -> void:
	_update_ui()


## Append a message to the server log.
func log_message(p_text: String, p_type: MessageType = MessageType.STD) -> void:
	_add_message(p_text, p_type)

#endregion

func _apply_min_height() -> void:
	var sidebar := $MainHBox/SidebarPanel
	custom_minimum_size.y = sidebar.get_combined_minimum_size().y

#region UI Updates

func _update_ui() -> void:
	if not http_server:
		status_label.text = "Not initialized"
		status_label.remove_theme_color_override(&"font_color")
		start_button.disabled = true
		stop_button.disabled = true
		port_input.editable = true
		count_label.text = "—"
		return

	var running := http_server.is_listening()

	status_label.text = "Running" if running else "Stopped"
	status_label.add_theme_color_override(
		&"font_color",
		Color.GREEN if running else get_theme_color(&"error_color", &"Editor"),
	)

	start_button.disabled = running
	stop_button.disabled = not running
	port_input.editable = not running

	if running:
		var count := 0
		if mcp_sse:
			count = mcp_sse.get_client_count()
		count_label.text = str(count)
	else:
		count_label.text = "0"

#endregion

#region Button / Input Callbacks

func _on_start_pressed() -> void:
	if http_server:
		http_server.port = int(port_input.value)
		http_server.start()
		_add_message("Server started on port %d" % http_server.port, MessageType.INFO)
		_update_ui()


func _on_stop_pressed() -> void:
	if http_server:
		http_server.stop()
		_add_message("Server stopped", MessageType.WARNING)
		_update_ui()


func _on_port_changed(p_new: float) -> void:
	_add_message("Port changed to %d" % int(p_new), MessageType.INFO)
	_update_ui()


func _on_clear_pressed() -> void:
	log.clear()
	_messages.clear()


func _on_search_toggled(p_pressed: bool) -> void:
	search_box.visible = p_pressed
	if p_pressed:
		search_box.grab_focus()
		search_box.select_all()


func _on_filter_changed(p_text: String) -> void:
	_filter_text = p_text
	_rebuild_log()

#endregion

#region Log Rendering

func _add_message(p_text: String, p_type: MessageType) -> void:
	# Break multi-line messages into individual entries
	var lines := p_text.split("\n", true)
	for i in lines.size():
		_append_and_store(lines[i], p_type)


func _append_and_store(p_text: String, p_type: MessageType) -> void:
	var entry := { "text": p_text, "type": p_type }
	_messages.push_back(entry)

	if not is_inside_tree():
		return

	# Only draw if it passes the current filter
	if not _message_passes_filter(entry):
		return

	_draw_log_line(entry)
	_trim_to_line_limit()


func _draw_log_line(p_entry: Dictionary) -> void:
	match p_entry.type:
		MessageType.ERROR:
			log.push_color(_theme_error_color)
			log.push_bold()
			log.add_text("ERROR: ")
			log.pop() # bold
		MessageType.WARNING:
			log.push_color(_theme_warning_color)
			log.push_bold()
			log.add_text("WARNING: ")
			log.pop() # bold
		MessageType.INFO:
			log.push_color(_theme_info_color)
		MessageType.STD:
			pass # default color

	log.add_text(p_entry.text)

	if p_entry.type != MessageType.STD:
		log.pop_all()

	log.newline()


func _rebuild_log() -> void:
	log.clear()
	for entry in _messages:
		if _message_passes_filter(entry):
			_draw_log_line(entry)
	_trim_to_line_limit()


func _message_passes_filter(p_entry: Dictionary) -> bool:
	if _filter_text.is_empty():
		return true
	return (p_entry.text as String).containsn(_filter_text)


func _trim_to_line_limit() -> void:
	while log.get_paragraph_count() > _line_limit + 1:
		log.remove_paragraph(0, true)

#endregion

#region Helpers

func _create_mono_fallback() -> Font:
	var sf := SystemFont.new()
	sf.font_names = PackedStringArray(
		[
			"JetBrains Mono",
			"Cascadia Code",
			"Fira Code",
			"Consolas",
			"Courier New",
			"monospace",
		],
	)
	sf.font_weight = 400
	return sf


func _get_icon(p_name: StringName) -> Texture2D:
	if not Engine.has_singleton(&"EditorInterface"):
		return null
	var ed_theme := EditorInterface.get_editor_theme()
	if not ed_theme:
		return null
	return ed_theme.get_icon(p_name, &"EditorIcons")

#endregion
