extends GutTest

const EFFECT_SCENE := preload("res://scenes/screen_overlay_effect.tscn")
const OVERLAY_SCENE := preload("res://scenes/screen_overlay.tscn")


func test_effect_stretches_each_frame_to_the_full_control_size() -> void:
	var effect := EFFECT_SCENE.instantiate() as ScreenOverlayEffect
	add_child_autofree(effect)
	var sprite := effect.get_node("AnimatedSprite2D") as AnimatedSprite2D
	sprite.sprite_frames = _make_frames(Vector2i(200, 100))
	effect.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	effect.size = Vector2(800.0, 600.0)
	effect.update_layout()

	assert_almost_eq(sprite.scale.x, 4.0, 0.001)
	assert_almost_eq(sprite.scale.y, 6.0, 0.001)
	assert_eq(sprite.position, Vector2.ZERO)
	assert_false(sprite.centered)


func test_effect_plays_a_non_looping_series_of_sprite_frames() -> void:
	var effect := EFFECT_SCENE.instantiate() as ScreenOverlayEffect
	add_child_autofree(effect)
	var sprite := effect.get_node("AnimatedSprite2D") as AnimatedSprite2D
	sprite.sprite_frames = _make_frames(Vector2i(100, 100), 2)
	effect.play()

	assert_true(sprite.is_playing())
	assert_eq(sprite.frame, 0)
	assert_eq(sprite.sprite_frames.get_frame_count(&"default"), 2)
	assert_false(sprite.sprite_frames.get_animation_loop(&"default"))


func test_timeline_activates_cues_when_their_start_time_is_reached() -> void:
	var overlay := OVERLAY_SCENE.instantiate() as ScreenOverlay
	add_child_autofree(overlay)
	var cue := ScreenOverlayCue.new()
	cue.effect_scene = EFFECT_SCENE
	cue.start_time = 1.0
	overlay.timeline_cues = [cue]
	var started_count := [0]
	overlay.effect_started.connect(func(_effect, _cue): started_count[0] += 1)
	overlay.start_timeline()

	overlay.advance_timeline(0.99)
	assert_eq(started_count[0], 0)
	overlay.advance_timeline(0.01)
	assert_eq(started_count[0], 1)
	assert_almost_eq(overlay.get_elapsed_time(), 1.0, 0.001)


func test_starting_timeline_after_a_cue_skips_that_cue() -> void:
	var overlay := OVERLAY_SCENE.instantiate() as ScreenOverlay
	add_child_autofree(overlay)
	var cue := ScreenOverlayCue.new()
	cue.effect_scene = EFFECT_SCENE
	cue.start_time = 1.0
	overlay.timeline_cues = [cue]
	var started_count := [0]
	overlay.effect_started.connect(func(_effect, _cue): started_count[0] += 1)
	overlay.start_timeline(2.0)

	overlay.advance_timeline(1.0)
	assert_eq(started_count[0], 0)


func test_sine_opacity_uses_configured_bounds() -> void:
	var effect := EFFECT_SCENE.instantiate() as ScreenOverlayEffect
	add_child_autofree(effect)
	effect.opacity_sine_enabled = true
	effect.opacity_sine_frequency = 1.0
	effect.opacity_sine_min = 0.2
	effect.opacity_sine_max = 0.8
	effect.opacity_sine_phase = 0.0
	effect.opacity = 1.0
	effect.advance_opacity(0.0)

	assert_almost_eq(effect.self_modulate.a, 0.5, 0.001)
	effect.advance_opacity(0.25)
	assert_almost_eq(effect.self_modulate.a, 0.8, 0.001)


func _make_frames(size: Vector2i, frame_count := 1) -> SpriteFrames:
	var gradient := Gradient.new()
	gradient.colors = PackedColorArray([Color.WHITE, Color.TRANSPARENT])
	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.width = size.x
	texture.height = size.y
	var frames := SpriteFrames.new()
	for frame_index in frame_count:
		frames.add_frame(&"default", texture)
	frames.set_animation_loop(&"default", false)
	return frames
