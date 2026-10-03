extends Control

class_name ResultsScreen

signal retry_requested(source: int)
signal next_requested(source: int)
signal credits_requested(source: int)
signal menu_requested(source: int)

const SOURCE_KEYBOARD := 0
const SOURCE_MOUSE := 1
const SOURCE_TOUCH := 2
const SOURCE_CONTROLLER := 3

@onready var _headline: Label = $Content/Column/Headline
@onready var _detail: Label = $Content/Column/Detail
@onready var _retry_button: Button = $Content/Column/RetryButton
@onready var _next_button: Button = $Content/Column/NextButton
@onready var _menu_button: Button = $Content/Column/MenuButton

var last_input_source := SOURCE_KEYBOARD
var is_success := false
var has_next_level := false
var level_name := "Level 1"


func _ready() -> void:
	_retry_button.pressed.connect(_on_retry_pressed)
	_next_button.pressed.connect(_on_next_pressed)
	_menu_button.pressed.connect(_on_menu_pressed)
	_apply_button_style(_retry_button, Color("f2bb57"), Color("281c31"))
	_apply_button_style(_next_button, Color("483454"), Color("f4e9ff"))
	_apply_button_style(_menu_button, Color("30263c"), Color("e9dfef"))
	_refresh_copy()
	_retry_button.grab_focus()


func configure(success: bool, completed_level_name: String, can_advance: bool) -> void:
	is_success = success
	has_next_level = can_advance
	level_name = completed_level_name
	if is_node_ready():
		_refresh_copy()


func set_input_source(source: int) -> void:
	if source >= SOURCE_KEYBOARD and source <= SOURCE_CONTROLLER:
		last_input_source = source


func _input(event: InputEvent) -> void:
	var source := _source_for_event(event)
	if source >= SOURCE_KEYBOARD:
		last_input_source = source


func _refresh_copy() -> void:
	if is_success:
		_headline.text = "NICE AIM!"
		_headline.add_theme_color_override("font_color", Color("f2bb57"))
		_detail.text = "%s complete. The night is still young." % level_name
	else:
		_headline.text = "BUSTED"
		_headline.add_theme_color_override("font_color", Color("f0809b"))
		_detail.text = "The run in %s is over. Take another shot?" % level_name
	_next_button.text = "NEXT LEVEL" if has_next_level else "CREDITS"
	_next_button.visible = is_success


func _on_retry_pressed() -> void:
	retry_requested.emit(last_input_source)


func _on_next_pressed() -> void:
	if has_next_level:
		next_requested.emit(last_input_source)
	else:
		credits_requested.emit(last_input_source)


func _on_menu_pressed() -> void:
	menu_requested.emit(last_input_source)


func _apply_button_style(button: Button, fill: Color, text_color: Color) -> void:
	button.add_theme_color_override("font_color", text_color)
	button.add_theme_color_override("font_hover_color", text_color)
	button.add_theme_color_override("font_pressed_color", text_color)
	button.add_theme_color_override("font_focus_color", text_color)
	button.add_theme_font_size_override("font_size", 21)
	button.add_theme_stylebox_override("normal", _button_style(fill, Color("8f76a0")))
	button.add_theme_stylebox_override("hover", _button_style(fill.lightened(0.1), Color("f2bb57")))
	button.add_theme_stylebox_override("pressed", _button_style(fill.darkened(0.14), Color("f2bb57")))
	button.add_theme_stylebox_override("focus", _button_style(fill, Color("f2bb57")))


func _button_style(fill: Color, edge: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = edge
	style.set_border_width_all(2)
	style.set_corner_radius_all(12)
	style.content_margin_left = 20.0
	style.content_margin_right = 20.0
	style.content_margin_top = 12.0
	style.content_margin_bottom = 12.0
	return style


func _source_for_event(event: InputEvent) -> int:
	if event is InputEventKey:
		var key := event as InputEventKey
		return SOURCE_KEYBOARD if key.pressed and not key.echo else -1
	if event is InputEventMouseButton:
		var mouse_button := event as InputEventMouseButton
		return SOURCE_MOUSE if mouse_button.button_index == MOUSE_BUTTON_LEFT and mouse_button.pressed and not mouse_button.canceled else -1
	if event is InputEventScreenTouch:
		return SOURCE_TOUCH if (event as InputEventScreenTouch).pressed else -1
	if event is InputEventJoypadButton:
		return SOURCE_CONTROLLER if (event as InputEventJoypadButton).pressed else -1
	if event is InputEventJoypadMotion:
		var motion := event as InputEventJoypadMotion
		if absf(motion.axis_value) >= 0.2:
			return SOURCE_CONTROLLER
	return -1
