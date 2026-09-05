extends Control

class_name CompletionCard

signal play_again_pressed

@onready var _play_again_button: Button = $PlayAgainButton


func _ready() -> void:
	_play_again_button.pressed.connect(_on_play_again_pressed)
	_layout_card()
	queue_redraw()


func _process(_delta: float) -> void:
	_layout_card()


func show_card() -> void:
	visible = true
	_layout_card()
	_play_again_button.grab_focus()
	queue_redraw()


func hide_card() -> void:
	visible = false


func _on_play_again_pressed() -> void:
	play_again_pressed.emit()


func _layout_card() -> void:
	var card := _card_rect()
	_play_again_button.position = card.position + Vector2(card.size.x * 0.5 - 92.0, 142.0)
	_play_again_button.size = Vector2(184.0, 52.0)
	queue_redraw()


func _draw() -> void:
	var card := _card_rect()
	draw_style_box(_make_box(Color("#182347"), 18), card)
	draw_string(
		ThemeDB.fallback_font,
		card.position + Vector2(0.0, 92.0),
		"LEVEL COMPLETE",
		HORIZONTAL_ALIGNMENT_CENTER,
		card.size.x,
		30,
		Color("#fff0a0"),
	)
	draw_string(
		ThemeDB.fallback_font,
		card.position + Vector2(0.0, 126.0),
		"YOUR LINE, PLAYED BACK",
		HORIZONTAL_ALIGNMENT_CENTER,
		card.size.x,
		14,
		Color("#aebce0"),
	)


func _card_rect() -> Rect2:
	var viewport_size := get_viewport_rect().size
	var card_width := minf(360.0, maxf(viewport_size.x - 48.0, 220.0))
	var card_height := 220.0
	var card_position := Vector2(
		maxf(viewport_size.x - card_width - 24.0, 24.0),
		maxf(viewport_size.y - card_height - 24.0, 24.0),
	)
	return Rect2(card_position, Vector2(card_width, card_height))


func _make_box(color: Color, radius: int) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = color
	box.border_color = Color(0.95, 0.82, 0.34, 0.35)
	box.set_border_width_all(2)
	box.corner_radius_top_left = radius
	box.corner_radius_top_right = radius
	box.corner_radius_bottom_left = radius
	box.corner_radius_bottom_right = radius
	return box
