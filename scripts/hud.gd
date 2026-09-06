extends Control

class_name StreamHUD

signal retry_pressed

var input_controller: InputController
var stream: LiquidStream
var target_nodes: Array[WettableTarget] = []
var show_touch_controls := false
@onready var aim_reticle: TouchReticle = $AimReticle
@onready var completion_card: CompletionCard = $CompletionCard
@onready var input_prompt: InputPrompt = $InputPrompt
@onready var strike_warning: StrikeWarning = $StrikeWarning
@onready var piss_meter: PissMeter = $PissMeter
@onready var game_over: GameOver = $GameOver
var _wired_input_controller: InputController
var gameplay_controls_visible := true
var aim_pointer_blocked := false
var aim_zone_state := TouchReticle.ReticleState.NEUTRAL


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	completion_card.play_again_pressed.connect(_on_retry_pressed)
	game_over.retry_pressed.connect(_on_retry_pressed)
	piss_meter.input_controller = input_controller
	piss_meter.stream = stream
	set_process(true)


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
			gameplay_controls_visible and not aim_pointer_blocked,
		)
	queue_redraw()


func set_gameplay_controls_visible(enabled: bool) -> void:
	gameplay_controls_visible = enabled
	# Once gameplay controls are hidden, the HUD has no per-frame aim preview to
	# update. Keeping this process loop alive during the failure launch only adds
	# redraw work on top of the rotating level and game-over card.
	set_process(enabled)
	if is_instance_valid(aim_reticle):
		aim_reticle.set_aim_target(
			aim_reticle.position,
			enabled and not aim_pointer_blocked,
		)
	if is_instance_valid(input_prompt) and not enabled:
		input_prompt.hide_prompt()
	if is_instance_valid(strike_warning) and not enabled:
		strike_warning.hide_warning()
	if is_instance_valid(piss_meter):
		# The meter stays on screen during the title transition, but only drains
		# after gameplay has been released by the title gate.
		piss_meter.set_gameplay_active(enabled)
	queue_redraw()


func set_aim_pointer_blocked(blocked: bool) -> void:
	aim_pointer_blocked = blocked
	if is_instance_valid(aim_reticle):
		aim_reticle.set_aim_target(
			aim_reticle.position,
			gameplay_controls_visible and not aim_pointer_blocked,
		)
	queue_redraw()


func show_input_prompt(source: int) -> void:
	if not gameplay_controls_visible or not is_instance_valid(input_prompt):
		return
	input_prompt.show_prompt(source)


func show_start_prompt(source: int) -> void:
	## The title gate hides gameplay controls, but the start gesture still tells
	## us which control scheme to explain immediately.
	if not is_instance_valid(input_prompt):
		return
	input_prompt.show_prompt(source)


func hide_input_prompt() -> void:
	if is_instance_valid(input_prompt):
		input_prompt.hide_prompt()


func show_completion_card() -> void:
	set_gameplay_controls_visible(false)
	game_over.hide_card()
	completion_card.show_card()


func show_failure_card() -> void:
	set_gameplay_controls_visible(false)
	completion_card.hide_card()
	game_over.show_card()


func show_game_over() -> void:
	show_failure_card()


func hide_completion_card() -> void:
	completion_card.hide_card()
	game_over.hide_card()


func reset_piss_meter() -> void:
	if is_instance_valid(piss_meter):
		piss_meter.reset_meter()


func set_strikes(value: int) -> void:
	# Kept as a HUD boundary for the gameplay controller. Strike warnings are
	# event-driven, so the count itself does not leave a persistent marker.
	if is_instance_valid(strike_warning) and value <= 0:
		strike_warning.hide_warning()


func show_strike_warning(strike: int, duration := -1.0) -> void:
	if not gameplay_controls_visible or not is_instance_valid(strike_warning):
		return
	strike_warning.show_warning(strike, duration)


func set_aim_zone_state(next_state: int) -> void:
	aim_zone_state = next_state
	if is_instance_valid(aim_reticle):
		aim_reticle.set_zone_state(next_state)


func set_reticle_state(next_state: int) -> void:
	set_aim_zone_state(next_state)


func play_success_burst() -> void:
	if is_instance_valid(aim_reticle):
		aim_reticle.play_success_burst()


func _on_retry_pressed() -> void:
	retry_pressed.emit()


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
