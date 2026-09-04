# girl-pisser

Small Godot 4 game-jam starter focused on plugins and developer workflow.

This combines the useful pieces found in dating-chess, the current tooling
from Date-or-Mate-2, and the itch.io build shape from fvf.x3c.ca. It leaves
the game code intentionally empty so a jam project can start cleanly.

## Included

- Godot MCP editor bridge in addons/godot_mcp/.
- .codex/config.toml so Codex CLI discovers the local MCP server per project.
- .mcp.json for other MCP clients that support the local HTTP/SSE server.
- Web export preset targeting build/web/index.html.
- GitHub Actions for Godot checks and HTML5/Butler deployment.
- A minimal smoke-test scene to confirm the project opens.
- Agent and MCP workflow notes.

Open the folder in Godot 4.7.2+ and replace scenes/smoke_test.tscn when the
actual game begins.

## Local MCP

Enable the Godot MCP plugin in the Godot editor, then start its local server
from the plugin panel. The MCP client configuration points to:

http://localhost:9080/mcp

See skills/godot-mcp-cli.md for the short command/tool reference. Codex CLI
only loads the project-scoped file after the project is trusted.

## itch.io deployment

The workflow pushes the Web export to the html-staging channel on pushes to
main or master. Add these GitHub Actions secrets:

- BUTLER_API_KEY
- ITCH_USERNAME
- ITCH_GAME

For the current itch page, ITCH_USERNAME is cooldotty and ITCH_GAME is
girl-pisser. See docs/pipeline.md for setup details.

## Layout

addons/ editor plugins, scenes/ smoke-test scene, assets/ project assets,
.github/ automation, docs/ workflow notes, and skills/ AI workflow notes.

## Attribution

The structure and workflow ideas were adapted from dating-chess,
Date-or-Mate-2, and fvf.x3c.ca. The included Godot MCP addon comes from
godot-mcp-cli and is kept under its MIT license. See third_party/.
