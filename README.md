# girl-pisser

Small Godot 4 game-jam starter focused on plugins and developer workflow.

This combines the useful pieces found in dating-chess, the current tooling
from Date-or-Mate-2, and the itch.io build shape from fvf.x3c.ca. It leaves
the game code intentionally empty so a jam project can start cleanly.

## Included

- Godot MCP editor bridge in addons/godot_mcp/.
- GUT v9.7.1 unit/integration test plugin in addons/gut/.
- .codex/config.toml so Codex CLI discovers the local MCP server per project.
- .mcp.json for other MCP clients using the same local MCP adapter.
- Web export preset targeting build/web/index.html.
- GitHub Actions for Godot checks and HTML5/Butler deployment.
- A local/CI test wrapper at tools/run-tests.sh with JUnit output.
- A minimal smoke-test scene to confirm the project opens.
- Agent and MCP workflow notes.

Open the folder in Godot 4.7.2+ and replace scenes/smoke_test.tscn when the
actual game begins.

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

addons/ editor plugins, scenes/ smoke-test scene, tests/ GUT tests, tools/
developer scripts, assets/ project assets, .github/ automation, docs/ workflow
notes, and skills/ AI workflow notes.

## Attribution

The structure and workflow ideas were adapted from dating-chess,
Date-or-Mate-2, and fvf.x3c.ca. The included Godot MCP addon comes from
godot-mcp-cli and is kept under its MIT license. See third_party/.
