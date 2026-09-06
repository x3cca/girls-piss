extends Control

class_name InputPrompt

## One reusable HUD notification for the currently active control scheme.
## Calling show_prompt again replaces the icons and restarts the same tween.
# TODO: Replace the temporary Aim/Piss action label art with final descriptive
# assets once those can explain the actions more directly.

enum PromptSource { KEYBOARD, MOUSE, TOUCH, CONTROLLER }

const BOIL_MATERIAL := preload("res://resources/materials/boil_effect.tres")
const ICON_SIZE := Vector2(64.0, 64.0)
const ACTION_LABEL_PATHS := {
	"aim": "res://assets/placeholders/input_prompts/aim.png",
	"piss": "res://assets/placeholders/input_prompts/piss.png",
}
const ICON_PATHS := {
	PromptSource.KEYBOARD: [
		"res://assets/placeholders/input_prompts/Keyboard & Mouse/Default/keyboard_w.png",
		"res://assets/placeholders/input_prompts/Keyboard & Mouse/Default/keyboard_a.png",
		"res://assets/placeholders/input_prompts/Keyboard & Mouse/Default/keyboard_s.png",
		"res://assets/placeholders/input_prompts/Keyboard & Mouse/Default/keyboard_d.png",
		"res://assets/placeholders/input_prompts/Keyboard & Mouse/Default/keyboard_space.png",
	],
	PromptSource.MOUSE: [
		"res://assets/placeholders/input_prompts/Keyboard & Mouse/Default/mouse_left.png",
	],
	PromptSource.TOUCH: [
		"res://assets/placeholders/input_prompts/Touch/Default/touch_tap.png",
	],
	PromptSource.CONTROLLER: [
		"res://assets/placeholders/input_prompts/Generic/Default/generic_joystick.png",
		"res://assets/placeholders/input_prompts/Generic/Default/generic_button_trigger_a.png",
	],
}
const ICON_TEXTURES := {
	"res://assets/placeholders/input_prompts/Keyboard & Mouse/Default/keyboard_w.png": preload(
		"res://assets/placeholders/input_prompts/Keyboard & Mouse/Default/keyboard_w.png"
	),
	"res://assets/placeholders/input_prompts/Keyboard & Mouse/Default/keyboard_a.png": preload(
		"res://assets/placeholders/input_prompts/Keyboard & Mouse/Default/keyboard_a.png"
	),
	"res://assets/placeholders/input_prompts/Keyboard & Mouse/Default/keyboard_s.png": preload(
		"res://assets/placeholders/input_prompts/Keyboard & Mouse/Default/keyboard_s.png"
	),
	"res://assets/placeholders/input_prompts/Keyboard & Mouse/Default/keyboard_d.png": preload(
		"res://assets/placeholders/input_prompts/Keyboard & Mouse/Default/keyboard_d.png"
	),
	"res://assets/placeholders/input_prompts/Keyboard & Mouse/Default/keyboard_space.png": preload(
		"res://assets/placeholders/input_prompts/Keyboard & Mouse/Default/keyboard_space.png"
	),
	"res://assets/placeholders/input_prompts/Keyboard & Mouse/Default/mouse_left.png": preload(
		"res://assets/placeholders/input_prompts/Keyboard & Mouse/Default/mouse_left.png"
	),
	"res://assets/placeholders/input_prompts/Touch/Default/touch_tap.png": preload(
		"res://assets/placeholders/input_prompts/Touch/Default/touch_tap.png"
	),
	"res://assets/placeholders/input_prompts/Generic/Default/generic_joystick.png": preload(
		"res://assets/placeholders/input_prompts/Generic/Default/generic_joystick.png"
	),
	"res://assets/placeholders/input_prompts/Generic/Default/generic_button_trigger_a.png": preload(
		"res://assets/placeholders/input_prompts/Generic/Default/generic_button_trigger_a.png"
	),
}
const AIM_ICON_PATHS := {
	PromptSource.KEYBOARD: [
		"res://assets/placeholders/input_prompts/Keyboard & Mouse/Default/keyboard_w.png",
		"res://assets/placeholders/input_prompts/Keyboard & Mouse/Default/keyboard_a.png",
		"res://assets/placeholders/input_prompts/Keyboard & Mouse/Default/keyboard_s.png",
		"res://assets/placeholders/input_prompts/Keyboard & Mouse/Default/keyboard_d.png",
	],
	PromptSource.MOUSE: [],
	PromptSource.TOUCH: [
		"res://assets/placeholders/input_prompts/Touch/Default/touch_tap.png",
	],
	PromptSource.CONTROLLER: [
		"res://assets/placeholders/input_prompts/Generic/Default/generic_joystick.png",
	],
}
const PISS_ICON_PATHS := {
	PromptSource.KEYBOARD: [
		"res://assets/placeholders/input_prompts/Keyboard & Mouse/Default/keyboard_space.png",
	],
	PromptSource.MOUSE: [
		"res://assets/placeholders/input_prompts/Keyboard & Mouse/Default/mouse_left.png",
	],
	PromptSource.TOUCH: [],
	PromptSource.CONTROLLER: [
		"res://assets/placeholders/input_prompts/Generic/Default/generic_button_trigger_a.png",
	],
}

@export_range(0.1, 1.0, 0.05) var enter_duration := 0.35
@export_range(0.5, 5.0, 0.05) var hold_duration := 2.25
@export_range(0.1, 1.0, 0.05) var hide_duration := 0.45
@export var right_margin := 28.0
@export var top_margin := 112.0

@onready var prompt_body: PanelContainer = $PromptBody
@onready var icon_row: VBoxContainer = $PromptBody/IconRow
@onready var aim_group: HBoxContainer = $PromptBody/IconRow/AimGroup
@onready var aim_icon_row: HBoxContainer = $PromptBody/IconRow/AimGroup/AimIcons
@onready var piss_group: HBoxContainer = $PromptBody/IconRow/PissGroup
@onready var piss_icon_row: HBoxContainer = $PromptBody/IconRow/PissGroup/PissIcons

var current_source := -1
var _prompt_tween: Tween
var _final_position := Vector2.ZERO
var _exit_position := Vector2.ZERO
var _last_texture_paths: Array[String] = []
var _last_layout_size := Vector2.ZERO
var _last_body_size := Vector2.ZERO


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	prompt_body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_process(true)
	visible = false
	prompt_body.modulate.a = 0.0
	_layout_prompt()
	# The HUD can receive its final stretched size one frame after the Web
	# canvas is created. Recalculate after that layout pass as well.
	call_deferred("_layout_prompt")


func _process(_delta: float) -> void:
	_layout_prompt()


func show_prompt(source: int) -> void:
	var paths := get_texture_paths(source)
	if paths.is_empty():
		return
	current_source = source
	_last_texture_paths = paths.duplicate()
	_set_action_icons(source)
	_layout_prompt()
	if _prompt_tween:
		_prompt_tween.kill()

	var was_visible := visible
	visible = true
	if not was_visible:
		prompt_body.position = _exit_position
		prompt_body.modulate.a = 0.0
	_prompt_tween = create_tween()
	var show_time := enter_duration if not was_visible else minf(enter_duration, 0.2)
	_prompt_tween.tween_property(
		prompt_body,
		"position",
		_final_position,
		show_time,
	).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_prompt_tween.parallel().tween_property(prompt_body, "modulate:a", 1.0, minf(show_time, 0.18))
	_prompt_tween.tween_interval(hold_duration)
	_prompt_tween.tween_property(
		prompt_body,
		"position",
		_exit_position,
		hide_duration,
	).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	_prompt_tween.parallel().tween_property(
		prompt_body,
		"modulate:a",
		0.0,
		hide_duration,
	)
	_prompt_tween.finished.connect(_hide_after_tween)


func hide_prompt(immediate := true) -> void:
	if _prompt_tween:
		_prompt_tween.kill()
	if immediate:
		visible = false
		current_source = -1
		prompt_body.modulate.a = 0.0
		prompt_body.position = _exit_position
	else:
		_prompt_tween = create_tween()
		_prompt_tween.tween_property(prompt_body, "modulate:a", 0.0, hide_duration)
		_prompt_tween.parallel().tween_property(prompt_body, "position", _exit_position, hide_duration)
		_prompt_tween.finished.connect(_hide_after_tween)


func is_showing() -> bool:
	return visible


func get_texture_paths(source: int) -> Array[String]:
	if not ICON_PATHS.has(source):
		return []
	var paths: Array[String] = []
	for path in ICON_PATHS[source]:
		paths.append(path)
	return paths


func get_action_texture_paths(source: int, action: String) -> Array[String]:
	var mapping: Dictionary = AIM_ICON_PATHS if action == "aim" else PISS_ICON_PATHS
	if not mapping.has(source):
		return []
	var paths: Array[String] = []
	for path in mapping[source]:
		paths.append(path)
	return paths


func get_current_texture_paths() -> Array[String]:
	return _last_texture_paths.duplicate()


func _set_action_icons(source: int) -> void:
	var aim_paths := get_action_texture_paths(source, "aim")
	var piss_paths := get_action_texture_paths(source, "piss")
	_set_icons(aim_icon_row, aim_paths)
	_set_icons(piss_icon_row, piss_paths)
	# Touch uses one gesture for both actions, so do not duplicate its icon.
	aim_group.visible = not aim_paths.is_empty()
	piss_group.visible = not piss_paths.is_empty() or source == PromptSource.TOUCH


func _set_icons(row: HBoxContainer, paths: Array[String]) -> void:
	for child in row.get_children():
		child.free()
	for path in paths:
		var icon := TextureRect.new()
		icon.name = path.get_file().get_basename()
		icon.custom_minimum_size = ICON_SIZE
		icon.size = ICON_SIZE
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		var texture := ICON_TEXTURES.get(path) as Texture2D
		if texture == null:
			texture = load(path) as Texture2D
		icon.texture = texture
		icon.material = BOIL_MATERIAL
		row.add_child(icon)


func _layout_prompt() -> void:
	if not is_instance_valid(prompt_body):
		return
	var viewport_size := size
	if viewport_size.x <= 1.0 or viewport_size.y <= 1.0:
		viewport_size = get_viewport().get_visible_rect().size
	if viewport_size.x <= 1.0 or viewport_size.y <= 1.0:
		return
	var body_size := prompt_body.get_combined_minimum_size()
	if body_size.x <= 1.0 or body_size.y <= 1.0:
		return
	var layout_changed := viewport_size != _last_layout_size or body_size != _last_body_size
	prompt_body.size = body_size
	_final_position = Vector2(
		viewport_size.x - body_size.x - right_margin,
		top_margin,
	)
	_exit_position = Vector2(viewport_size.x + body_size.x * 0.35, top_margin)
	_last_layout_size = viewport_size
	_last_body_size = body_size
	if not visible or (_prompt_tween == null and layout_changed):
		prompt_body.position = _exit_position
	elif layout_changed:
		# A browser resize changes the local canvas coordinates. Do not leave the
		# notification at its pre-resize/default position while a tween is active.
		prompt_body.position = _final_position


func _hide_after_tween() -> void:
	visible = false
	current_source = -1
