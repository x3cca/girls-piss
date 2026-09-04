# girl-pisser

This is a Godot 4.7.2 game-jam starter.

Always use Godot 4+ syntax and semantic input action names.
Use bespoke scenes for high-level concepts.
Follow signal up, call down: children broadcast signals and parents call
their own child scenes directly.

Run this before committing:
    godot --headless --editor --check-only

The Date-or-Mate-2 MCP addon listens at http://127.0.0.1:9080/mcp. Codex
connects through npx mcp-remote, so Node.js 20+ must be installed. If it
does not connect, make sure Godot is open, the plugin is enabled, and the
project-scoped Codex config is trusted.

Third-party code in addons/ must not be reformatted or linted.
