extends Control

class_name StrikeWarning

## Immediate, short-lived warning bubbles for the first three mistakes.
##
## The warning art is intentionally kept as three independently visible panels:
## the red treatment has a different text layout from the yellow and orange
## treatments, and direct visibility changes make the feedback appear on the
## same frame as the strike.

const YELLOW_WARNING := 1
const ORANGE_WARNING := 2
const RED_WARNING := 3

@export_range(0.0, 10.0, 0.01) var warning_duration := 4.0
@export_range(0.0, 0.2, 0.005) var top_margin_ratio := 0.025
@export_range(0.0, 0.2, 0.005) var right_margin_ratio := 0.035
@export_range(0.2, 0.6, 0.01) var bubble_width_ratio := 0.44
@export_range(180.0, 480.0, 1.0) var max_bubble_width := 360.0
@export_range(0.1, 1.0, 0.01) var min_bubble_width := 220.0

@onready var yellow_warning: Control = $YellowWarning
@onready var orange_warning: Control = $OrangeWarning
@onready var red_warning: Control = $RedWarning

var _active_warning := 0
var _remaining := 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_process(true)
	hide_warning()
	_layout_warnings()


func _process(delta: float) -> void:
	process_frame(delta)


func process_frame(delta: float) -> void:
	_layout_warnings()
	if _active_warning == 0:
		return
	_remaining = maxf(_remaining - maxf(delta, 0.0), 0.0)
	if is_zero_approx(_remaining):
		_remaining = 0.0
		hide_warning()


func show_warning(strike: int, duration := -1.0) -> void:
	hide_warning()
	if strike < YELLOW_WARNING or strike > RED_WARNING:
		return
	_active_warning = strike
	_remaining = warning_duration if duration < 0.0 else maxf(duration, 0.0)
	_warning_for(strike).visible = true
	_layout_warnings()
	if _remaining <= 0.0:
		hide_warning()


func hide_warning() -> void:
	_active_warning = 0
	_remaining = 0.0
	if is_instance_valid(yellow_warning):
		yellow_warning.visible = false
	if is_instance_valid(orange_warning):
		orange_warning.visible = false
	if is_instance_valid(red_warning):
		red_warning.visible = false


func get_active_warning() -> int:
	return _active_warning


func get_remaining_duration() -> float:
	return _remaining


func is_warning_visible(strike: int) -> bool:
	return strike == _active_warning and is_instance_valid(_warning_for(strike)) and _warning_for(strike).visible


func get_warning_assets(strike: int) -> Dictionary:
	## Exposes the authored selection so tests and future HUD tooling can inspect it.
	match strike:
		YELLOW_WARNING:
			return {
				"bubble": $YellowWarning/Bubble.texture,
				"text": $YellowWarning/Text.texture,
			}
		ORANGE_WARNING:
			return {
				"bubble": $OrangeWarning/Bubble.texture,
				"text": $OrangeWarning/Text.texture,
			}
		RED_WARNING:
			return {
				"bubble": $RedWarning/Bubble.texture,
				"text": $RedWarning/RedText1.texture,
				"row": [
					$RedWarning/RedTextRow/RedText2.texture,
					$RedWarning/RedTextRow/RedText3.texture,
					$RedWarning/RedTextRow/RedText4.texture,
				],
			}
	return {}


func get_warning_rect(strike: int) -> Rect2:
	var warning := _warning_for(strike)
	if not is_instance_valid(warning):
		return Rect2()
	return Rect2(warning.position, warning.size)


func _warning_for(strike: int) -> Control:
	match strike:
		YELLOW_WARNING:
			return yellow_warning
		ORANGE_WARNING:
			return orange_warning
		RED_WARNING:
			return red_warning
	return null


func _layout_warnings() -> void:
	if not is_instance_valid(yellow_warning):
		return
	var viewport_size := get_viewport_rect().size
	if viewport_size.x <= 1.0 or viewport_size.y <= 1.0:
		return
	var bubble_width := clampf(
		viewport_size.x * bubble_width_ratio,
		min_bubble_width,
		max_bubble_width,
	)
	var right_margin := maxf(viewport_size.x * right_margin_ratio, 16.0)
	var top_margin := maxf(viewport_size.y * top_margin_ratio, 16.0)
	var right_position := viewport_size.x - right_margin - bubble_width

	_layout_simple_warning(
		yellow_warning,
		yellow_warning.get_node("Bubble") as TextureRect,
		yellow_warning.get_node("Text") as TextureRect,
		Vector2(right_position, top_margin),
		bubble_width,
		0.27,
	)
	_layout_simple_warning(
		orange_warning,
		orange_warning.get_node("Bubble") as TextureRect,
		orange_warning.get_node("Text") as TextureRect,
		Vector2(right_position, top_margin),
		bubble_width,
		0.14,
	)
	_layout_red_warning(
		red_warning,
		red_warning.get_node("Bubble") as TextureRect,
		red_warning.get_node("RedText1") as TextureRect,
		red_warning.get_node("RedTextRow") as Control,
		Vector2(right_position, top_margin),
		bubble_width,
	)


func _layout_simple_warning(
	warning: Control,
	bubble: TextureRect,
	text: TextureRect,
	origin: Vector2,
	bubble_width: float,
	text_top_ratio: float,
) -> void:
	var bubble_height := _texture_height(bubble.texture, bubble_width)
	warning.position = origin
	warning.size = Vector2(bubble_width, bubble_height)
	bubble.position = Vector2.ZERO
	bubble.size = warning.size
	var text_width := bubble_width * 0.76
	var text_height := _texture_height(text.texture, text_width)
	text.size = Vector2(text_width, text_height)
	text.position = Vector2(
		(bubble_width - text_width) * 0.5,
		bubble_height * text_top_ratio,
	)


func _layout_red_warning(
	warning: Control,
	bubble: TextureRect,
	heading: TextureRect,
	row: Control,
	origin: Vector2,
	bubble_width: float,
) -> void:
	var bubble_height := _texture_height(bubble.texture, bubble_width)
	warning.position = origin
	warning.size = Vector2(bubble_width, bubble_height)
	bubble.position = Vector2.ZERO
	bubble.size = warning.size

	var heading_width := bubble_width * 0.78
	var heading_height := _texture_height(heading.texture, heading_width)
	heading.size = Vector2(heading_width, heading_height)
	heading.position = Vector2((bubble_width - heading_width) * 0.5, bubble_height * 0.16)

	row.position = Vector2(bubble_width * 0.075, bubble_height * 0.52)
	row.size = Vector2(bubble_width * 0.85, bubble_height * 0.28)
	var row_nodes: Array[TextureRect] = [
		row.get_node("RedText2") as TextureRect,
		row.get_node("RedText3") as TextureRect,
		row.get_node("RedText4") as TextureRect,
	]
	var widths := [row.size.x * 0.16, row.size.x * 0.14, row.size.x * 0.52]
	var gap := row.size.x * 0.04
	var cursor := 0.0
	for index in row_nodes.size():
		var node := row_nodes[index]
		var width: float = widths[index]
		var height := _texture_height(node.texture, width)
		node.position = Vector2(cursor, (row.size.y - height) * 0.5)
		node.size = Vector2(width, height)
		cursor += width + gap


func _texture_height(texture: Texture2D, width: float) -> float:
	if not is_instance_valid(texture) or texture.get_width() <= 0:
		return 0.0
	return width * texture.get_height() / float(texture.get_width())
