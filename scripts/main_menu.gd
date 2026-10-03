extends Control

class_name MainMenu

signal play_requested(source: int)
signal credits_requested(source: int)

const SOURCE_KEYBOARD := 0
const SOURCE_MOUSE := 1
const SOURCE_TOUCH := 2
const SOURCE_CONTROLLER := 3

@onready var _play_button: Button = $Content/Column/PlayButton
@onready var _credits_button: Button = $Content/Column/CreditsButton

var last_input_source := SOURCE_KEYBOARD


func _ready() -> void:
	_style_button(_play_button, Color("f2bb57"), Color("281c31"))
	_style_button(_credits_button, Color("483454"), Color("f4e9ff"))
	_play_button.pressed.connect(_on_play_pressed)
	_credits_button.pressed.connect(_on_credits_pressed)
	_play_button.grab_focus()


func set_input_source(source: int) -> void:
	if source >= SOURCE_KEYBOARD and source <= SOURCE_CONTROLLER:
		last_input_source = source


func _input(event: InputEvent) -> void:
	var source := _source_for_event(event)
	if source >= SOURCE_KEYBOARD:
		last_input_source = source


func _on_play_pressed() -> void:
	play_requested.emit(last_input_source)


func _on_credits_pressed() -> void:
	credits_requested.emit(last_input_source)


func _style_button(button: Button, fill: Color, text_color: Color) -> void:
	button.add_theme_color_override("font_color", text_color)
	button.add_theme_color_override("font_hover_color", text_color)
	button.add_theme_color_override("font_pressed_color", text_color)
	button.add_theme_color_override("font_focus_color", text_color)
	button.add_theme_font_size_override("font_size", 24)
	button.add_theme_stylebox_override("normal", _button_style(fill, Color("8f76a0")))
	button.add_theme_stylebox_override("hover", _button_style(fill.lightened(0.1), Color("f2bb57")))
	button.add_theme_stylebox_override("pressed", _button_style(fill.darkened(0.14), Color("f2bb57")))
	button.add_theme_stylebox_override("focus", _button_style(fill, Color("f2bb57")))
	button.add_theme_stylebox_override("disabled", _button_style(fill.darkened(0.28), Color("776c7b")))


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
