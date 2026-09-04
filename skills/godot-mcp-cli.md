# Godot MCP workflow

The included addons/godot_mcp/ plugin exposes the Godot editor and runtime
debugger through a local MCP HTTP/SSE endpoint.

## Start

1. Open the project in Godot 4.7.2+.
2. Enable Godot MCP under Project → Project Settings → Plugins.
3. Start the server from the plugin panel.
4. Point the MCP client at http://localhost:9080/mcp.

The repository includes .mcp.json with that URL for MCP clients that read
project-local configuration.

## Useful checks

~~~text
godot --headless --editor --check-only
godot --headless --editor --quit --import .
godot --headless --export-release "Web" build/web/index.html
~~~

The addon is for development only and is excluded from the Web export.
