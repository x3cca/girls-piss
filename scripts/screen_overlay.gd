extends CanvasLayer

class_name ScreenOverlay

## Timeline-driven layer for full-screen animated sprite effects.
##
## Add [ScreenOverlayCue] resources to [member timeline_cues] in the inspector,
## or call [method schedule_effect] from gameplay code. Each effect scene must
## have a [ScreenOverlayEffect] root.

signal effect_started(effect: ScreenOverlayEffect, cue: ScreenOverlayCue)
signal effect_finished(effect: ScreenOverlayEffect, cue: ScreenOverlayCue)

@export var autoplay := false
@export var timeline_cues: Array[ScreenOverlayCue] = []

@onready var _effect_host: Control = $EffectHost
var _elapsed := 0.0
var _timeline_playing := false
var _started_cues: Array[bool] = []
var _active_effects: Array[ScreenOverlayEffect] = []


func _ready() -> void:
	_effect_host.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_reset_started_cues()
	if autoplay:
		start_timeline()


func _process(delta: float) -> void:
	advance_timeline(delta)


func start_timeline(from_time := 0.0) -> void:
	stop_timeline()
	_elapsed = maxf(from_time, 0.0)
	_timeline_playing = true
	_reset_started_cues()
	for index in timeline_cues.size():
		var cue := timeline_cues[index]
		if cue != null and cue.start_time < _elapsed:
			_started_cues[index] = true
	_activate_due_cues()


func stop_timeline(stop_effects := true) -> void:
	_timeline_playing = false
	if stop_effects:
		stop_all_effects()


func advance_timeline(delta: float) -> void:
	if not _timeline_playing or delta <= 0.0:
		return
	_elapsed += delta
	_activate_due_cues()


func schedule_effect(effect_scene: PackedScene, start_time: float) -> ScreenOverlayCue:
	var cue := ScreenOverlayCue.new()
	cue.effect_scene = effect_scene
	cue.start_time = maxf(start_time, 0.0)
	timeline_cues.append(cue)
	_started_cues.append(false)
	if _timeline_playing:
		_activate_due_cues()
	return cue


func play_effect(effect_scene: PackedScene, cue: ScreenOverlayCue = null) -> ScreenOverlayEffect:
	if effect_scene == null:
		return null
	var instance := effect_scene.instantiate()
	var effect := instance as ScreenOverlayEffect
	if effect == null:
		if is_instance_valid(instance):
			instance.queue_free()
		push_warning("Screen overlay effect scenes must use ScreenOverlayEffect as their root.")
		return null

	_effect_host.add_child(effect)
	effect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	effect.effect_finished.connect(_on_effect_finished.bind(cue))
	_active_effects.append(effect)
	effect_started.emit(effect, cue)
	effect.play()
	return effect


func stop_all_effects() -> void:
	for effect in _active_effects:
		if is_instance_valid(effect):
			effect.stop()
			effect.queue_free()
	_active_effects.clear()


func get_elapsed_time() -> float:
	return _elapsed


func is_timeline_playing() -> bool:
	return _timeline_playing


func get_active_effect_count() -> int:
	return _active_effects.size()


func _reset_started_cues() -> void:
	_started_cues.clear()
	for _cue in timeline_cues:
		_started_cues.append(false)


func _activate_due_cues() -> void:
	for index in timeline_cues.size():
		if _started_cues[index]:
			continue
		var cue := timeline_cues[index]
		if cue == null:
			_started_cues[index] = true
			continue
		if cue.start_time > _elapsed:
			continue
		_started_cues[index] = true
		play_effect(cue.effect_scene, cue)


func _on_effect_finished(effect: ScreenOverlayEffect, cue: ScreenOverlayCue) -> void:
	_active_effects.erase(effect)
	effect_finished.emit(effect, cue)
	effect.queue_free()
