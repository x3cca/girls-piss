extends ScreenOverlayEffect

class_name RadialVignetteEffect

## A short procedural radial flash used by the gameplay feedback cues. The
## transparent center keeps the playfield readable while the colored rim makes
## the event visible without needing another bitmap asset.

@export var vignette_color := Color(1.0, 0.2, 0.25, 0.72)
@export_range(0.05, 3.0, 0.01) var duration := 0.42
@export_range(0.0, 1.0, 0.01) var peak_opacity := 0.82

var _elapsed := 0.0
var _vignette: ColorRect
var _aspect_ratio := -1.0


func _ready() -> void:
	super._ready()
	_vignette = get_node_or_null("Vignette") as ColorRect
	resized.connect(_on_resized)
	set_process(true)
	_update_vignette_color()
	_update_vignette_aspect()


func play() -> void:
	_has_finished = false
	_elapsed = 0.0
	visible = true
	self_modulate = Color(1.0, 1.0, 1.0, 0.0)
	_update_vignette_color()
	_update_vignette_aspect()
	queue_redraw()


func stop() -> void:
	visible = false
	set_process(false)


func _process(delta: float) -> void:
	_update_vignette_aspect()
	_elapsed += maxf(delta, 0.0)
	var progress := clampf(_elapsed / maxf(duration, 0.001), 0.0, 1.0)
	var envelope := sin(progress * PI)
	self_modulate = Color(1.0, 1.0, 1.0, envelope * peak_opacity)
	if progress >= 1.0:
		_finish()


func _update_vignette_color() -> void:
	if not is_instance_valid(_vignette):
		return
	var material := _vignette.material as ShaderMaterial
	if material:
		material.set_shader_parameter("vignette_color", vignette_color)


func _on_resized() -> void:
	_update_vignette_aspect()


func _update_vignette_aspect() -> void:
	if not is_instance_valid(_vignette) or size.x <= 0.0 or size.y <= 0.0:
		return
	var aspect_ratio := size.x / size.y
	if is_equal_approx(aspect_ratio, _aspect_ratio):
		return
	var material := _vignette.material as ShaderMaterial
	if material:
		material.set_shader_parameter("aspect_ratio", aspect_ratio)
		_aspect_ratio = aspect_ratio


func _finish() -> void:
	if _has_finished:
		return
	_has_finished = true
	visible = false
	set_process(false)
	effect_finished.emit(self)
