extends Control

class_name StreamHUD

var input_controller: InputController
var pressure_model: PressureModel
var stream: LiquidStream
var target_nodes: Array[WettableTarget] = []
var show_touch_controls := false
var safe_margin := 28.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_process(true)


func _process(_delta: float) -> void:
	if input_controller:
		show_touch_controls = input_controller.touch_controls_visible
	queue_redraw()


func _draw() -> void:
	var viewport := get_viewport_rect()
	var safe := viewport.grow(-minf(safe_margin, minf(viewport.size.x, viewport.size.y) * 0.04))
	var font := ThemeDB.fallback_font
	var small := 16
	var medium := 22
	# Header and compact pressure cards.
	draw_string(
		font,
		safe.position + Vector2(0, 24),
		"PISSER",
		HORIZONTAL_ALIGNMENT_LEFT,
		-1,
		medium,
		Color("#fff0a0"),
	)
	draw_string(
		font,
		safe.position + Vector2(0, 48),
		"aim • squeeze • soak",
		HORIZONTAL_ALIGNMENT_LEFT,
		-1,
		small,
		Color("#b2a77a"),
	)
	_draw_meter(
		Rect2(safe.position + Vector2(0, 72), Vector2(196, 18)),
		pressure_model.requested_pressure if pressure_model else 0.0,
		Color("#f1d34f"),
		"PRESSURE",
	)
	_draw_meter(
		Rect2(safe.position + Vector2(218, 72), Vector2(196, 18)),
		pressure_model.reserve if pressure_model else 0.0,
		Color("#c3b57a"),
		"RESERVE",
	)
	if pressure_model and pressure_model.exhausted:
		draw_string(
			font,
			safe.position + Vector2(0, 120),
			"RECOVERING",
			HORIZONTAL_ALIGNMENT_LEFT,
			-1,
			small,
			Color("#ffbf7a"),
		)
	else:
		draw_string(
			font,
			safe.position + Vector2(0, 120),
			"W / S  pressure     A / D  aim",
			HORIZONTAL_ALIGNMENT_LEFT,
			-1,
			small,
			Color("#b2a77a"),
		)

	# Small target progress tags remain readable on wide and tall portrait ratios.
	for index in target_nodes.size():
		var target := target_nodes[index]
		if is_instance_valid(target):
			var label_position := target.position + Vector2(
				-target.target_size.x * 0.5,
				-target.target_size.y * 0.5 - 16.0,
			)
			draw_string(
				font,
				label_position,
				"TARGET %02d  %d%%" % [index + 1, roundi(target.wetness * 100.0)],
				HORIZONTAL_ALIGNMENT_LEFT,
				-1,
				13,
				Color("#d5c77f"),
			)

	if show_touch_controls:
		_draw_touch_controls(safe)


func _draw_meter(rect: Rect2, value: float, color: Color, title: String) -> void:
	var font := ThemeDB.fallback_font
	draw_string(
		font,
		rect.position + Vector2(0, -7),
		title,
		HORIZONTAL_ALIGNMENT_LEFT,
		-1,
		12,
		Color("#8396bb"),
	)
	draw_style_box(_box(Color(0.06, 0.09, 0.18, 0.85), 7), rect)
	var fill := rect.grow(-3.0)
	fill.size.x *= clampf(value, 0.0, 1.0)
	if fill.size.x > 0:
		draw_style_box(_box(color, 5), fill)


func _draw_touch_controls(safe: Rect2) -> void:
	var joystick_center := Vector2(safe.end.x - 112.0, safe.end.y - 156.0)
	var fader_x := safe.position.x + 72.0
	var fader_top := safe.position.y + 178.0
	var fader_bottom := safe.end.y - 188.0
	draw_line(
		Vector2(fader_x, fader_top),
		Vector2(fader_x, fader_bottom),
		Color(0.5, 0.65, 0.86, 0.28),
		18.0,
	)
	draw_line(Vector2(fader_x, fader_top), Vector2(fader_x, fader_bottom), Color("#f1d34f"), 4.0)
	var pressure := pressure_model.requested_pressure if pressure_model else 0.55
	var knob_y := lerpf(fader_bottom, fader_top, inverse_lerp(0.15, 1.0, pressure))
	draw_circle(Vector2(fader_x, knob_y), 17.0, Color("#fff3a0"))
	draw_circle(Vector2(fader_x, knob_y), 11.0, Color("#d0b52f"))
	draw_string(
		ThemeDB.fallback_font,
		Vector2(fader_x - 35.0, fader_top - 22.0),
		"PRESSURE",
		HORIZONTAL_ALIGNMENT_LEFT,
		-1,
		13,
		Color("#d5c77f"),
	)
	draw_circle(joystick_center, 86.0, Color(0.08, 0.12, 0.25, 0.74))
	draw_arc(joystick_center, 86.0, 0.0, TAU, 64, Color(0.46, 0.61, 0.9, 0.55), 3.0)
	var aim := input_controller.aim_direction if input_controller else Vector2.UP
	draw_circle(joystick_center + aim * 47.0, 23.0, Color("#f1d34f"))
	draw_string(
		ThemeDB.fallback_font,
		joystick_center + Vector2(-41.0, 112.0),
		"AIM",
		HORIZONTAL_ALIGNMENT_LEFT,
		-1,
		13,
		Color("#d5c77f"),
	)


func _box(color: Color, radius: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.corner_radius_top_left = radius
	style.corner_radius_top_right = radius
	style.corner_radius_bottom_left = radius
	style.corner_radius_bottom_right = radius
	return style
