# Gameplay reference

`scenes/level_1.tscn` is the project's main scene. It shares the startup and
gameplay controller with `scenes/smoke_test.tscn`, which remains available as a
debug scene with authored negative zones.

## Startup flow

`Main` starts with `skip_title_screen = false`. The level is already visible
behind the high-layer `TitleScreen` CanvasLayer, but gameplay input and the
gameplay HUD are disabled until the title transition finishes.

The title uses the transparent `TitleComposition` scene over the Level 1
scene. It layers `GirlsTitle.png` and `PissTitle.png` over the three title
flares, then swaps the matching `StartBacker1`/`Start1` and
`StartBacker2`/`Start2` pairs as a small press-start treatment. The authored
layers retain their 1080x1920 reference positions and receive the shared boil
material. `StartMenuExample.png` remains a visual reference only. The title
composition fades out on the first recognized input.

The first input is handled by `InputController`, starts the title exit, and is
consumed. Its source-specific controls prompt appears immediately while the
title fades. Duplicate requests are ignored while the exit tween is running.
Once the transition completes, `Main` resets held input state and enables
gameplay.

To bypass the title in the editor, enable `skip_title_screen` on the root
`Main` node. Code-driven startup should call `start_gameplay_immediately()`;
both paths leave the scene in the same playable state.

## Controls and source detection

| Source | Aim | Stream |
| --- | --- | --- |
| Keyboard | W/A/S/D | Space held |
| Mouse | Motion | Left click held |
| Touch | Tap or drag | Touch held |
| Controller | Left stick | Right trigger held |

`InputController` emits `input_detected` for recognized activity and
`input_source_changed` only when the source changes. Keyboard key presses,
left mouse clicks, touch-down events, controller button presses, and meaningful
controller stick/trigger movement are recognized. Mouse motion is intentionally
not a source-change event, even though it continues to move the target.

While the title is active, input is still detected for startup, but
`gameplay_input_enabled` prevents aiming, touch reticle updates, and stream
state changes. This keeps the start gesture from leaking into the first frame
of play.

## Contextual prompts

`scenes/input_prompt.tscn` is one reusable HUD notification. It shows two
stacked action rows at once where the source supports them: aim icons above the
stream icon(s). Keyboard W/A/S/D remain separate icons within the aim row, and
Space remains in the stream row. Replacing a visible prompt cancels its old
timer and repopulates the same node, so source changes do not stack duplicate
notifications.

The prompt enters from the right, holds for about 2.25 seconds, then slides and
fades out over about 0.45 seconds. Its Kenney icons and the temporary `aim.png`
/ `piss.png` action labels use the shared boil material. The action labels are
currently placeholders rather than fully descriptive instructional art; replace
them when final UI assets are available.

## Play loop and rendering

The player follows the authored `ShapeTrace` path with an inertial stream whose
emitted parcels preserve their launch velocity while the visible ribbon eases
toward the current target. Completing the path stops live input, replays the
recorded line as a time-lapse, and then shows the completion card.

Level 1 uses the small bathroom-object sprites as its ordered checkpoint
targets. The authored floor is a bad region, while the wall, tank, and seat
remain neutral; the smoke-test scene retains its separate `NegativeZone`
polygon/area nodes for validating bad-region behavior. The reticle uses
`Crosshair2.png` for neutral space and `Crosshair1.png` over a bad region.
Successful target contact flashes a white radial vignette around the screen
edges while keeping the target area clear. Actual contact is evaluated from
the stream endpoint rather than the requested reticle position.

Checkpoint contact requires `0.35` seconds of continuous endpoint contact. A
negative-zone overlap is fully sensitive: the first committed endpoint frame in
the region immediately gives a strike, even if contact lasts only briefly. A
bad hit starts a `4` second safety cooldown while stopping the stream. The first
three strikes show a
yellow, orange, or red warning bubble in the top-right corner, and each bubble
is hidden when that cooldown ends. If the endpoint remains in the bad region,
another strike is possible as soon as that safety cooldown ends. Four strikes
stop the attempt and show the authored game-over treatment: the dread frame,
layered GAME/OVER artwork, failure sound, and Piss Again arrow. Retry resets
the trace, meter, strike count, stream, and all overlay effects.

The Level 1 Piss-O-Meter begins with one minute of stream time and drains only
while the stream input is held. The stream uses the baked
`resources/depth_map_baked.png` through `DepthMap2D`.
The environment is split into four depth bands so stream ribbons, particles,
and the world can be ordered consistently in the portrait scene. The offline
depth baker and normal-map baker live in `tools/`.

Aim changes expand a bloom radius that decays over time. Parcel offsets trace a
horizontal Gerono lemniscate (a figure eight), and an extreme bloom temporarily
renders a second stream until the radius falls below the release threshold.
