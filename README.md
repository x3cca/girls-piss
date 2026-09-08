# girl-pisser

Small Godot 4 game-jam prototype focused on a portrait liquid-stream loop and
developer workflow.

The playable sample opens with a transparent title overlay over the first
level. The logo is positioned around the upper third of the portrait frame
(roughly two-thirds up from the bottom), while the press-start art enters from
below. A recognized input starts the exit transition; that first input is
consumed so it cannot also move the aimer or start the stream. Its contextual
prompt appears immediately for the input source that started the game.

The level traces an authored loop with a continuous inertial stream entering
from below the bottom-center of the frame, then replays the recorded line in a
roughly five-second time-lapse, capped at 3× speed for very long demos. The
stream's aim bloom follows a horizontal figure-eight path, and large aim jumps
can briefly produce a second stream while the bloom settles. The crosshair
starts at the first trace point.

See [docs/gameplay.md](docs/gameplay.md) for the complete startup, controls,
prompt, and scene behavior reference.

## Controls

| Input source | Aim | Start the stream |
| --- | --- | --- |
| Keyboard | WASD | Space |
| Mouse | Mouse motion | Left mouse button |
| Touch | Tap or drag | Tap |
| Controller | Left stick | Right trigger |

Keyboard, mouse-click, touch-down, controller-button, and meaningful controller
axis events select the corresponding prompt scheme. Mouse motion still aims but
is intentionally ignored for prompt source changes.

The stream starts on the first stream input and keeps going after that control
is released. It ends only when the pee meter is empty or gameplay explicitly
resets it (for example after a strike, retry, or completion).

## Included

- Godot MCP editor bridge in addons/godot_mcp/.
- GUT v9.7.1 unit/integration test plugin in addons/gut/.
- .codex/config.toml so Codex CLI discovers the local MCP server per project.
- .mcp.json for other MCP clients using the same local MCP adapter.
- Web export preset targeting build/web/index.html.
- GitHub Actions for Godot checks and HTML5/Butler deployment.
- A local/CI test wrapper at tools/run-tests.sh with JUnit output.
- A real Level 1 portrait scene with the authored bathroom, toilet, object
  targets, lighting, and a baked depth-aware environment.
- An inertial stream model where emitted flow keeps its launch velocity while
  the visible stream eases toward the crosshair target.
- A figure-eight aim-bloom model with a temporary double-stream state for large
  aim changes.
- Offline alpha-silhouette normal-map and environment depth-map bakers in
  `tools/`.
- A reusable title screen and contextual input-prompt HUD that transition in
  place over the same Level 1 scene.
- An authored game-over overlay with failure feedback and retry behavior.
- Agent and MCP workflow notes.

Open the folder in Godot 4.7.2+ and run the project; it starts at
`scenes/level_1.tscn`. `scenes/smoke_test.tscn` remains available as the
debug scene with authored negative zones. The authored viewport is 540×960.

For direct-level testing, enable `Main.skip_title_screen` on the root node of
the scene. Tests and tools can use `Main.start_gameplay_immediately()` for the
same bypass without changing the scene default.

## Local MCP

Enable the Godot MCP plugin in the Godot editor. Its local server listens at:

http://127.0.0.1:9080/mcp

Date-or-Mate-2's addon is pure GDScript. Codex CLI uses the Node.js
mcp-remote package declared in .codex/config.toml to adapt the addon's
legacy SSE/HTTP transport to stdio. Install Node.js 20+; no npm project
install is required. Codex CLI only loads the project-scoped file after the
project is trusted.

After opening Godot and enabling the plugin, restart Codex or run:

    codex mcp list

See skills/godot-mcp-cli.md for the short command/tool reference.

## Tests

Run the complete suite from the repository root:

    ./tools/run-tests.sh

Run the editor/project check as well:

    godot --headless --editor --check-only

The suite covers the title transition and skip path, input-source detection,
contextual prompt replacement/animation, depth sampling, stream parcels and
the replay loop. GitHub Actions runs the same test and project-check commands
on pull requests and pushes. See `tests/README.md` and `docs/testing.md` for
test conventions.

## itch.io deployment

The workflow pushes the Web export to the html-staging channel on pushes to
main or master. Add these GitHub Actions secrets:

- BUTLER_API_KEY
- ITCH_USERNAME

The workflow deploys to `https://cooldotty.itch.io/girls-piss`. Set
`ITCH_USERNAME` to `cooldotty`. See docs/pipeline.md for setup details.

## Layout

addons/ editor plugins, scenes/ prototype and component scenes, tests/ GUT
tests, tools/ developer scripts, assets/ project assets, .github/ automation,
docs/ workflow notes, and skills/ AI workflow notes. `scenes/level_1.tscn` is
the main scene; `scenes/smoke_test.tscn` is retained for gameplay tests.

## Attribution

Project source code by Dot Phillips is available under the [MIT License](LICENSES/MIT.md).
Original project 2D artwork by Raquel Stone is licensed under CC BY-NC 4.0;
see
[`LICENSES/RAQUEL_STONE_CUSTOM_ASSETS.md`](LICENSES/RAQUEL_STONE_CUSTOM_ASSETS.md).
Third-party assets and plugins remain subject to their own license notices.

The structure and workflow ideas were adapted from dating-chess,
Date-or-Mate-2, and fvf.x3c.ca. The included Godot MCP addon comes from
godot-mcp-cli and is kept under its MIT license. See third_party/.

The included UI sound effects are from [Case Portman Audio's Cute & Cozy UI
Audio Free Sample](https://caseportman.itch.io/cute-cozy-ui-sfx) and are used
under its royalty-free, attribution-required license. See
`assets/audio/cute_cozy_ui/license.txt`.

The placeholder input prompts are from [Kenney's Input Prompts
pack](https://kenney.nl/assets/input-prompts) and are released under CC0. See
`assets/placeholders/input_prompts/License.txt`. The `aim.png` and `piss.png`
action labels are temporary placeholders; they currently identify the two
actions visually but are not yet descriptive instructional art.

The placeholder cursor art is from [Kenney's Cursor Pixel
Pack](https://kenney.nl/assets/cursor-pixel-pack) and is released under CC0.
See `assets/placeholders/cursor_pixel_pack/License.txt`.

The spray loop is derived from [WATRSpray-Samsung Galaxy Smartphone, MCU_Water
Hose, Mist Mode_Nicholas Judy_TDC by designerschoice](https://freesound.org/s/811446/)
under Creative Commons Attribution 4.0. It is high-passed and pitch-raised for
gameplay; see `LICENSES/` for the attribution note.

The launch crash uses `door_kick.ogg`, derived from [Kicking/Forcing/Breaking
Wooden Door by qubodup](https://freesound.org/people/qubodup/sounds/160213/) and
available under CC0. See `LICENSES/door_kick.md` for provenance.

The failure transition uses audio from
[Gaming Sound FX's FBI Open Up - Sound Effect (HD)](https://www.youtube.com/watch?v=QQR7t712Mhg).
The source video is not marked with a permissive license; see
`LICENSES/fbi_open_up.md` before redistributing the project.

The strike warning wall-pound variants are derived from [Heavy Wall Pounding by
LunaFarrowe](https://freesound.org/people/LunaFarrowe/sounds/448374/) and are
available under CC0. See `LICENSES/wall_pounding.md` for processing notes.
