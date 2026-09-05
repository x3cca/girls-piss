extends Control

class_name StreamHUD

var input_controller: InputController
var stream: LiquidStream
var target_nodes: Array[WettableTarget] = []
var show_touch_controls := false
var safe_margin := 28.0
@onready var aim_reticle: TouchReticle = $AimReticle
@onready var carrot_marker: TextureRect = $CarrotMarker
@onready var completion_card: CompletionCard = $CompletionCard
@onready var input_prompt: InputPrompt = $InputPrompt
@onready var strike_indicator: StrikeIndicator = $StrikeIndicator
@onready var piss_meter: PissMeter = $PissMeter
var _wired_input_controller: InputController
var gameplay_controls_visible := true
var aim_zone_state := TouchReticle.ReticleState.NEUTRAL


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	piss_meter.input_controller = input_controller
	piss_meter.stream = stream
	set_process(true)
	_layout_controls()


func _process(_delta: float) -> void:
	process_frame(_delta)


func process_frame(_delta: float) -> void:
	if input_controller:
		show_touch_controls = input_controller.touch_controls_visible
	if is_instance_valid(piss_meter):
		piss_meter.input_controller = input_controller
		piss_meter.stream = stream
	_wire_input_controller()
	if is_instance_valid(aim_reticle):
		aim_reticle.set_zone_state(aim_zone_state)
		aim_reticle.set_aim_target(
			input_controller.get_target_position() if input_controller else Vector2.ZERO,
			gameplay_controls_visible,
		)
	if is_instance_valid(carrot_marker):
		carrot_marker.visible = gameplay_controls_visible
		if stream:
			carrot_marker.rotation = Vector2.UP.angle_to(stream.get_current_stream_direction())
	_layout_controls()
	queue_redraw()


func set_gameplay_controls_visible(enabled: bool) -> void:
	gameplay_controls_visible = enabled
	if is_instance_valid(aim_reticle):
		aim_reticle.set_aim_target(aim_reticle.position, enabled)
	if is_instance_valid(carrot_marker):
		carrot_marker.visible = enabled
	if is_instance_valid(input_prompt) and not enabled:
		input_prompt.hide_prompt()
	if is_instance_valid(strike_indicator):
		strike_indicator.visible = enabled
	if is_instance_valid(piss_meter):
		# The meter stays on screen during the title transition, but only drains
		# after gameplay has been released by the title gate.
		piss_meter.set_gameplay_active(enabled)
	queue_redraw()


func show_input_prompt(source: int) -> void:
	if not gameplay_controls_visible or not is_instance_valid(input_prompt):
		return
	input_prompt.show_prompt(source)


func hide_input_prompt() -> void:
	if is_instance_valid(input_prompt):
		input_prompt.hide_prompt()


func show_completion_card() -> void:
	set_gameplay_controls_visible(false)
	completion_card.show_card()


func show_failure_card() -> void:
	set_gameplay_controls_visible(false)
	completion_card.show_failure_card()


func hide_completion_card() -> void:
	completion_card.hide_card()


func reset_piss_meter() -> void:
	if is_instance_valid(piss_meter):
		piss_meter.reset_meter()


func set_strikes(value: int) -> void:
	if is_instance_valid(strike_indicator):
		strike_indicator.set_strikes(value)


func set_aim_zone_state(next_state: int) -> void:
	aim_zone_state = next_state
	if is_instance_valid(aim_reticle):
		aim_reticle.set_zone_state(next_state)


func set_reticle_state(next_state: int) -> void:
	set_aim_zone_state(next_state)


func play_success_burst() -> void:
	if is_instance_valid(aim_reticle):
		aim_reticle.play_success_burst()


func _wire_input_controller() -> void:
	if input_controller == _wired_input_controller:
		return
	if is_instance_valid(_wired_input_controller):
		if _wired_input_controller.touch_target_changed.is_connected(
			_on_touch_target_changed,
		):
			_wired_input_controller.touch_target_changed.disconnect(_on_touch_target_changed)
		if _wired_input_controller.input_source_changed.is_connected(
			_on_input_source_changed,
		):
			_wired_input_controller.input_source_changed.disconnect(_on_input_source_changed)
	_wired_input_controller = input_controller
	if not is_instance_valid(_wired_input_controller):
		return
	if not _wired_input_controller.touch_target_changed.is_connected(
		_on_touch_target_changed,
	):
		_wired_input_controller.touch_target_changed.connect(_on_touch_target_changed)
	if not _wired_input_controller.input_source_changed.is_connected(
		_on_input_source_changed,
	):
		_wired_input_controller.input_source_changed.connect(_on_input_source_changed)


func _on_touch_target_changed(position: Vector2, active: bool) -> void:
	if gameplay_controls_visible and active:
		aim_reticle.set_aim_target(position, true)


func _on_input_source_changed(source: int) -> void:
	if gameplay_controls_visible:
		show_input_prompt(source)


func _layout_controls() -> void:
	# The crosshair is a viewport-space target, so no hidden aim or pressure track
	# needs to intercept the pointer. The carrot is only the centered player marker.
	if not is_instance_valid(carrot_marker):
		return
	var viewport := get_viewport_rect()
	var safe := viewport.grow(-minf(safe_margin, minf(viewport.size.x, viewport.size.y) * 0.04))
	carrot_marker.pivot_offset = Vector2(carrot_marker.size.x * 0.5, carrot_marker.size.y)
	carrot_marker.position = Vector2(
		viewport.get_center().x - carrot_marker.size.x * 0.5,
		safe.end.y - 32.0 - carrot_marker.size.y,
	)
