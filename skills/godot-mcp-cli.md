# Godot MCP workflow

The included addons/godot_mcp/ plugin is the pure-GDScript addon used by
Date-or-Mate-2. It exposes the Godot editor and debugger through a local
legacy MCP HTTP/SSE endpoint.

## Start

1. Install Node.js 20+ so node and npx are available.
2. Open the project in Godot 4.7.2+.
3. Enable Godot MCP under Project → Project Settings → Plugins.
4. Confirm the plugin panel is listening on http://127.0.0.1:9080/mcp.

Codex CLI uses .codex/config.toml. It launches npx mcp-remote to adapt the
Godot addon's SSE/HTTP endpoint to Codex's stdio MCP transport. .mcp.json
contains the same command for other MCP clients.

When Codex asks whether to trust the project, accept it so the project-scoped
MCP configuration loads. Verify it with:

~~~text
cd /path/to/girl-pisser
codex mcp list
codex mcp get godot-mcp
~~~

## Useful checks

~~~text
godot --headless --editor --check-only
godot --headless --editor --quit --import .
godot --headless --export-release "Web" build/web/index.html
~~~

The addon and proxy are development tooling. The addon is excluded from the
Web export.
