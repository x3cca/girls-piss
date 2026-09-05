# girl-pisser

Small Godot 4 game-jam prototype focused on a portrait liquid-stream loop and
developer workflow.

The playable sample traces an authored loop with a continuous inertial urine
stream entering from below the bottom-center of the frame, then replays the
recorded line in a roughly ten-second time-lapse, capped at 3× speed for very
long demos. The crosshair starts at the first trace point.
Desktop uses WASD, mouse motion, or the controller's left stick to aim. Space,
the left mouse button, touch, or the right trigger starts the persistent stream.

## Included

- Godot MCP editor bridge in addons/godot_mcp/.
- GUT v9.7.1 unit/integration test plugin in addons/gut/.
- .codex/config.toml so Codex CLI discovers the local MCP server per project.
- .mcp.json for other MCP clients using the same local MCP adapter.
- Web export preset targeting build/web/index.html.
- GitHub Actions for Godot checks and HTML5/Butler deployment.
- A local/CI test wrapper at tools/run-tests.sh with JUnit output.
- A portrait liquid-stream sample scene with animated trace targets and lighting.
- An inertial stream model where emitted flow keeps its launch velocity while
  the visible stream eases toward the crosshair target.
- An offline alpha-silhouette normal-map baker in `tools/`.
- Agent and MCP workflow notes.

Open the folder in Godot 4.7.2+ and run `scenes/smoke_test.tscn` (the historical
filename is retained so existing export presets keep working).

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

Run `./tools/run-tests.sh` from the repository root. It runs GUT headlessly,
and GitHub Actions runs the same command on pull requests and pushes. See
tests/README.md and docs/testing.md for test conventions.

## itch.io deployment

The workflow pushes the Web export to the html-staging channel on pushes to
main or master. Add these GitHub Actions secrets:

- BUTLER_API_KEY
- ITCH_USERNAME
- ITCH_GAME

For the current itch page, ITCH_USERNAME is cooldotty and ITCH_GAME is
girl-pisser. See docs/pipeline.md for setup details.

## Layout

addons/ editor plugins, scenes/ prototype and component scenes, tests/ GUT
tests, tools/ developer scripts, assets/ project assets, .github/ automation,
docs/ workflow notes, and skills/ AI workflow notes.

## Attribution

The structure and workflow ideas were adapted from dating-chess,
Date-or-Mate-2, and fvf.x3c.ca. The included Godot MCP addon comes from
godot-mcp-cli and is kept under its MIT license. See third_party/.

The included UI sound effects are from [Case Portman Audio's Cute & Cozy UI
Audio Free Sample](https://caseportman.itch.io/cute-cozy-ui-sfx) and are used
under its royalty-free, attribution-required license. See
`assets/audio/cute_cozy_ui/license.txt`.

The placeholder input prompts are from [Kenney's Input Prompts
pack](https://kenney.nl/assets/input-prompts) and are released under CC0. See
`assets/placeholders/input_prompts/License.txt`.

The placeholder cursor art is from [Kenney's Cursor Pixel
Pack](https://kenney.nl/assets/cursor-pixel-pack) and is released under CC0.
See `assets/placeholders/cursor_pixel_pack/License.txt`.
