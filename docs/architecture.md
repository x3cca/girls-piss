# Scene architecture

`scenes/app.tscn` is the project entry point. Its `App` script owns the active
screen and an ordered catalog of `LevelDefinition` resources. Screens emit
requests; the app decides where to go. The active screen never changes the
scene tree directly.

The active route is title → Level 1 → failure screen. Level 1 keeps its
authored completion card. After the failure raid, the app captures the final
frame and replaces the level with a dedicated game-over scene. A snapshot
layer spins offscreen over that scene. The persistent `GameAudio` autoload creates all playback nodes before they
start. Scenes hold references to those players and can be freed without moving
playing nodes or changing playback positions.
Retry stops the retained music and creates a fresh level; one-shot effects
finish naturally even when retry is pressed. Returning to the menu also resets
the retained music. A
directly run Level 1 handles failure in place. The menu opens separate credits.
Esc or controller B returns to the menu from gameplay, completion, failure,
or credits. The results scene remains for future progression; switching to it
on replay completion would interrupt Level 1's authored credit/retry animation.
It plays the room track on navigation screens; each level owns its gameplay
music and beat response.

`scenes/gameplay_base.tscn` contains shared input, stream, objective, HUD,
recording, replay, audio, and effect nodes. It has no title or bathroom art.
`Level1` adds its own environment, toilet, targets, and hazard. The smoke-test
fixture inherits the same base and adds test zones. Hazard lookup stays within
the active level's subtree.

## Add a level

1. Create a scene that inherits `scenes/gameplay_base.tscn`. Add its art,
   target layout, and negative zones under that root. Use a level script for
   content rules that differ from Level 1.
2. Create a `LevelDefinition` resource with a stable `level_id`, display name,
   scene, and `progression_order`.
3. Add the definition to `App.level_definitions` in `scenes/app.tscn` or its
   exported default in `scripts/app.gd`. Ensure IDs and orders are unique.
4. Add the level scene to the Web preset's `export_files` list. The preset
   exports selected scenes, so a scene loaded from a resource catalog must be
   explicitly included. Extend the Web bundle check for critical new assets.
5. Exercise title → level, credits, retry, and return to menu.
   Before enabling progression, test next level routing. Test that
   the new level sees only its own targets and hazards.

`Main.begin_attempt(source)` starts a prepared level after it enters the tree.
It emits `level_completed` after replay and `level_failed` after the failure
presentation. A level run directly in the editor can use `skip_title_screen`
or call `begin_attempt` from a tool or test.

## Audio lifetime and Web startup

`GameAudio` creates the level music controller and effect players under its
own root. Scene audio nodes supply settings (stream, mix, pitch, and volume);
their scripts use references to global players for playback. No players are
reparented. When a scene exits, idle players are freed, active one-shots finish
and then free themselves, and looping gameplay effects such as spray stop.
Music continues through game over until retry or return to menu. The existing music crossfade logic and mix assets are unchanged.

`AudioResources` preloads and warms all 16 runtime audio streams, including the
spray loop, at startup. Loop flags are configured at startup. Music and continuous spray use streamed
playback from the preloaded resources; short effects use warmed Web samples.
It retains their resources and warms additional scene
players as they enter the tree. Web exports include these resources in the PCK;
CI checks the manager, preloader, music, spray, and raid sounds are bundled.
Browser audio still requires the normal first user gesture to unlock playback.
