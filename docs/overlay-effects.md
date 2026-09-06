# Full-screen overlay effects

The `ScreenOverlay` scene provides a timeline for full-screen animated sprite
effects. It is already present in `scenes/smoke_test.tscn` above the HUD and
ignores mouse/touch input.

## Authoring an effect

1. Create a scene from `scenes/screen_overlay_effect.tscn`.
2. Assign the effect's `sprite_frames` resource and `animation_name` on the
   root `ScreenOverlayEffect` node.
3. Keep the animation non-looping. The overlay manager removes the effect after
   `AnimatedSprite2D` emits `animation_finished`.

The effect root is anchored to the full viewport. On every resize and animation
frame change, the `AnimatedSprite2D` is scaled independently on X and Y to the
current visible size. This intentionally stretches the authored sprite to fill
portrait, desktop, and expanded aspect ratios.

For an effect that pulses, enable `opacity_sine_enabled` on the root and tune
`opacity_sine_frequency`, `opacity_sine_min`, `opacity_sine_max`, and
`opacity_sine_phase`. The wave is evaluated in the effect itself, so it can run
at the same time as the sprite-frame animation.

## Scheduling an effect

Add `ScreenOverlayCue` resources to `ScreenOverlay.timeline_cues` in the
inspector, setting `start_time` in seconds and assigning an effect scene. For a
runtime schedule:

```gdscript
var cue := $ScreenOverlay.schedule_effect(preload("res://effects/splash.tscn"), 3.5)
$ScreenOverlay.start_timeline()
```

Effects can also be started immediately with
`$ScreenOverlay.play_effect(effect_scene)`.

The gameplay layer also exposes `play_strike_feedback()` and
`play_success_feedback()`. Bad-zone strikes use the authored dread overlay;
checkpoint completions use the authored two-frame action-line overlay.
