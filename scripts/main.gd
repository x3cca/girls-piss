extends Node2D

## Playable portrait-first sample level. All world positions are derived from the
## visible rectangle, so expand stretching and taller phone ratios stay usable.
## The stream source is deliberately below the frame: the player controls the
## jet, never a visible wand or nozzle.

var input_controller: InputController
var pressure_model: PressureModel
var stream: LiquidStream
var hud: StreamHUD
var targets: Array[WettableTarget] = []
var _broad_light: PointLight2D
var _impact_light: PointLight2D
var _world_size := Vector2(720.0, 1280.0)
var _layout_signature := Vector2.ZERO

func _ready() -> void:
	input_controller = InputController.new()
	add_child(input_controller)
	pressure_model = PressureModel.new()
	add_child(pressure_model)
	pressure_model.requested_pressure = input_controller.requested_pressure

	stream = LiquidStream.new()
	stream.input_controller = input_controller
	stream.pressure_model = pressure_model
	stream.wet_target_hit.connect(_on_wet_target_hit)
	add_child(stream)

	_create_targets()
	_create_lighting()
	_create_hud()
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

func _create_targets() -> void:
	for i in 3:
		var target := WettableTarget.new()
		target.name = "WettablePlot%02d" % (i + 1)
		target.target_size = Vector2(174.0, 112.0) if i != 1 else Vector2(188.0, 120.0)
		target.base_color = [Color("#68724b"), Color("#79634b"), Color("#4f7060")][i]
		target.accent_color = [Color("#e4d15d"), Color("#efd66a"), Color("#d6c34d")][i]
		target.required_liquid = 1.25
		target.soaked.connect(_on_target_soaked.bind(target))
		add_child(target)
		targets.append(target)

func _create_lighting() -> void:
	var ambient := CanvasModulate.new()
	ambient.color = Color("#566080")
	add_child(ambient)
	_broad_light = PointLight2D.new()
	_broad_light.name = "BroadMoonLight"
	_broad_light.texture = _light_texture()
	_broad_light.texture_scale = 3.4
	_broad_light.energy = 0.72
	_broad_light.color = Color("#91a9ff")
	_broad_light.position = Vector2(_world_size.x * 0.50, _world_size.y * 0.34)
	add_child(_broad_light)
	_impact_light = PointLight2D.new()
	_impact_light.name = "StreamImpactLight"
	_impact_light.texture = _light_texture()
	_impact_light.texture_scale = 0.82
	_impact_light.energy = 1.1
	_impact_light.color = Color("#ffe589")
	_impact_light.position = stream.source_position
	add_child(_impact_light)

func _light_texture() -> GradientTexture2D:
	var gradient := Gradient.new()
	gradient.colors = PackedColorArray([Color(1, 1, 1, 0.95), Color(1, 1, 1, 0.0)])
	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.width = 256
	texture.height = 256
	texture.fill = GradientTexture2D.FILL_RADIAL
	texture.fill_from = Vector2(0.5, 0.5)
	texture.fill_to = Vector2(1.0, 0.5)
	return texture

func _create_hud() -> void:
	var layer := CanvasLayer.new()
	layer.name = "HUDLayer"
	add_child(layer)
	hud = StreamHUD.new()
	hud.name = "HUD"
	hud.input_controller = input_controller
	hud.pressure_model = pressure_model
	hud.stream = stream
	hud.target_nodes = targets
	hud.show_touch_controls = input_controller.touch_controls_visible
	hud.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layer.add_child(hud)

func _on_wet_target_hit(target: WettableTarget, amount: float, position: Vector2, normal: Vector2) -> void:
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
