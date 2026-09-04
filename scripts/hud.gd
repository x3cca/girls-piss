extends Control

class_name StreamHUD

var input_controller: InputController
var stream: LiquidStream
var target_nodes: Array[WettableTarget] = []
var show_touch_controls := false
var safe_margin := 28.0
@onready var aim_reticle: TouchReticle = $AimReticle
@onready var completion_card: CompletionCard = $CompletionCard
var _wired_input_controller: InputController
var gameplay_controls_visible := true


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_process(true)
	_layout_controls()


func _process(_delta: float) -> void:
	process_frame(_delta)


func process_frame(_delta: float) -> void:
	if input_controller:
		show_touch_controls = input_controller.touch_controls_visible
	_wire_input_controller()
	if is_instance_valid(aim_reticle):
		aim_reticle.set_aim_target(
			input_controller.get_target_position() if input_controller else Vector2.ZERO,
			gameplay_controls_visible,
		)
	_layout_controls()
	queue_redraw()


func set_gameplay_controls_visible(enabled: bool) -> void:
	gameplay_controls_visible = enabled
	if is_instance_valid(aim_reticle):
		aim_reticle.set_aim_target(aim_reticle.position, enabled)
	queue_redraw()


func show_completion_card() -> void:
	set_gameplay_controls_visible(false)
	completion_card.show_card()


func hide_completion_card() -> void:
	completion_card.hide_card()


func _wire_input_controller() -> void:
	if input_controller == _wired_input_controller:
		return
	if is_instance_valid(_wired_input_controller):
		if _wired_input_controller.touch_target_changed.is_connected(
			_on_touch_target_changed,
		):
			_wired_input_controller.touch_target_changed.disconnect(_on_touch_target_changed)
	_wired_input_controller = input_controller
	if not is_instance_valid(_wired_input_controller):
		return
	if not _wired_input_controller.touch_target_changed.is_connected(
		_on_touch_target_changed,
	):
		_wired_input_controller.touch_target_changed.connect(_on_touch_target_changed)


func _on_touch_target_changed(position: Vector2, active: bool) -> void:
	if gameplay_controls_visible and active:
		aim_reticle.set_aim_target(position, true)


func _layout_controls() -> void:
	# The crosshair is a viewport-space target, so no hidden aim or pressure track
	# needs to intercept the pointer.
	pass


func _draw() -> void:
	if not gameplay_controls_visible:
		return
	var viewport := get_viewport_rect()
	var safe := viewport.grow(-minf(safe_margin, minf(viewport.size.x, viewport.size.y) * 0.04))
	var font := ThemeDB.fallback_font
	draw_string(
		font,
		safe.position + Vector2(0, 24),
		"PISSER",
		HORIZONTAL_ALIGNMENT_LEFT,
		-1,
		22,
		Color("#fff0a0"),
	)
	draw_string(
		font,
		safe.position + Vector2(0, 48),
		"crosshair aim",
		HORIZONTAL_ALIGNMENT_LEFT,
		-1,
		16,
		Color("#b2a77a"),
	)
	draw_string(
		font,
		safe.position + Vector2(0, 78),
		"WASD / TOUCH  AIM     SPACE / HOLD  PISS",
		HORIZONTAL_ALIGNMENT_LEFT,
		-1,
		16,
		Color("#b2a77a"),
	)
