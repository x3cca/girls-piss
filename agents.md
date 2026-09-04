# girl-pisser

This is a Godot 4.7.2 game-jam starter.

Always use Godot 4+ syntax.

Always follow `skills/godot-best-practices.md`.

When making nodes and scenes, make them bespoke scenes encapsulating the
high-level concept in an object-oriented manner.

Resources can be inline as a scene resource unless it makes sense to separate
them out for reuse in more scenes.

For example, when asked to make a goblin: make a new goblin scene, add its
essential child nodes, attach a `goblin.gd` script to the root, and keep the
goblin-specific code in that script.

Always follow "signal up, call down." Nodes talking to siblings or parents
should do so by broadcasting signals.

When in doubt, add a signal to a global script so that the event can be emitted
and any interested listeners can connect to it.

For calling down, if a node is concerned about a child, that child should be a
part of the node's scene and the parent can call it with a direct child path.

If you need a placeholder texture, use `assets/placeholders/DevTextures`. If
you need a more specific placeholder, ask the user to add it under
`assets/placeholders/`.

`assets/placeholders/icon.svg` is also available as a generic placeholder.

When adding new input types, make new actions in the InputMap on the project
settings. Keep action names semantic.

## MCP

The local Godot MCP server listens at `http://127.0.0.1:9080/mcp`. Check
`.mcp.json` for client configuration.

Codex CLI connects through `npx mcp-remote`, so Node.js 20+ must be installed.
If it does not connect, make sure Godot is open, the plugin is enabled, and the
project-scoped Codex configuration is trusted. If the editor is not running,
ask the user to start it.

## Headless error checking

Run Godot headless with `--check-only` to detect tool script parse errors,
compile errors, and runtime initialization failures. The MCP addon detects
`--check-only` and exits cleanly after loading.

```bash
godot --headless --editor --check-only
```

Look for lines prefixed with `SCRIPT ERROR:`, `ERROR:`, or `WARNING:`. A clean
run should report the loaded tool count with no skipped files and then exit.

## GDScript formatter and linter

Get the latest binary from:
<https://github.com/GDQuest/GDScript-formatter/releases/latest>

Pick the asset matching the platform, extract it, and place the binary at
`.godot/gdscript-formatter` (or `.godot/gdscript-formatter.exe` on Windows).
Rename versioned binaries to `gdscript-formatter`.

Always exclude `addons/`; third-party code must not be reformatted or linted.

```bash
find . -name "*.gd" -not -path "./.godot/*" -not -path "./addons/*" -print0 \
  | xargs -0 .godot/gdscript-formatter --safe

find . -name "*.gd" -not -path "./.godot/*" -not -path "./addons/*" -print0 \
  | xargs -0 .godot/gdscript-formatter lint
```

After a run, check headlessly for GDScript errors. Once scripts are
error-free, format and lint them, then fix any remaining errors and warnings.
