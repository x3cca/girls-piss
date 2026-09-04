extends Node2D
## Playable portrait-first sample level. All world positions are derived from the
## visible rectangle, so expand stretching and taller phone ratios stay usable.
## The stream source is deliberately below the frame: the player controls the
## jet, never a visible wand or nozzle.

@onready var input_controller: InputController = $InputController
@onready var pressure_model: PressureModel = $PressureModel
@onready var stream: LiquidStream = $LiquidStream
@onready var hud: StreamHUD = $HUDLayer/HUD
var targets: Array[WettableTarget] = []
@onready var _broad_light: PointLight2D = $BroadMoonLight
@onready var _impact_light: PointLight2D = $StreamImpactLight
var _world_size := Vector2(720.0, 1280.0)
var _layout_signature := Vector2.ZERO


func _ready() -> void:
	targets = [$WettablePlot01, $WettablePlot02, $WettablePlot03]
	pressure_model.requested_pressure = input_controller.requested_pressure

	stream.input_controller = input_controller
	stream.pressure_model = pressure_model
	stream.wet_target_hit.connect(_on_wet_target_hit)
	for target in targets:
		target.soaked.connect(_on_target_soaked.bind(target))
	_wire_hud()
	_layout_world()
	queue_redraw()


func _process(_delta: float) -> void:
	_world_size = get_viewport().get_visible_rect().size
	pressure_model.requested_pressure = input_controller.requested_pressure
	_layout_world()
	queue_redraw()


func _layout_world() -> void:
	if _world_size.x <= 1.0 or _world_size.y <= 1.0:
		return
	# The source stays just below the visible rectangle; only the jet enters frame.
	stream.source_position = Vector2(_world_size.x * 0.5, _world_size.y + 48.0)
	stream.minimum_length = minf(190.0, _world_size.y * 0.18)
	stream.maximum_length = minf(1080.0, _world_size.y * 0.84)
	var positions := [
		Vector2(_world_size.x * 0.24, _world_size.y * 0.32),
		Vector2(_world_size.x * 0.72, _world_size.y * 0.45),
		Vector2(_world_size.x * 0.34, _world_size.y * 0.58),
	]
	for i in mini(targets.size(), positions.size()):
		targets[i].position = positions[i]
	if _layout_signature != _world_size:
		_layout_signature = _world_size
		if _broad_light:
			_broad_light.position = Vector2(_world_size.x * 0.50, _world_size.y * 0.34)
		if _impact_light:
			_impact_light.position = stream.source_position


func _wire_hud() -> void:
	hud.input_controller = input_controller
	hud.pressure_model = pressure_model
	hud.stream = stream
	hud.target_nodes = targets
	hud.show_touch_controls = input_controller.touch_controls_visible


func _on_wet_target_hit(
		target: WettableTarget,
		amount: float,
		position: Vector2,
		normal: Vector2,
) -> void:
	if is_instance_valid(target):
		target.apply_liquid(amount, position)
		_impact_light.position = position + normal * 12.0


func _on_target_soaked(target: WettableTarget) -> void:
	target.base_color = target.base_color.lightened(0.12)
	target.queue_redraw()


func _draw() -> void:
	# Low-contrast bands give the stream readable depth without painted textures.
	draw_rect(Rect2(Vector2.ZERO, _world_size), Color("#111a35"))
	for band in 8:
		var top := float(band) / 8.0 * _world_size.y
		var color := Color(0.08 + band * 0.006, 0.11 + band * 0.007, 0.22 + band * 0.012, 1.0)
		draw_rect(Rect2(0.0, top, _world_size.x, _world_size.y / 8.0 + 1.0), color)
	for i in 18:
		var x := fmod(float(i * 113 + 47), maxf(_world_size.x, 1.0))
		var y := fmod(float(i * 71 + 31), maxf(_world_size.y * 0.72, 1.0))
		draw_circle(Vector2(x, y), 1.5 if i % 3 else 2.5, Color(0.48, 0.66, 0.91, 0.20))
