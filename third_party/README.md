# Third-party components

## Godot MCP

addons/godot_mcp/ is imported from the MCP addon in x3cca/Date-or-Mate-2,
which is the pure-GDScript godot-mcp-cli bridge, under its MIT license.

Keep upstream license and attribution files with the addon when updating it.
The addon is an editor/development dependency and is excluded from Web export.
Codex CLI uses the separately downloaded mcp-remote npm package as a local
SSE-to-stdio adapter; it is not vendored in this repository.
