# Third-party components

## Godot MCP

addons/godot_mcp/ is imported from the MCP addon in x3cca/Date-or-Mate-2,
which is the pure-GDScript godot-mcp-cli bridge, under its MIT license.

Keep upstream license and attribution files with the addon when updating it.
The addon is an editor/development dependency and is excluded from Web export.
Codex CLI uses the separately downloaded mcp-remote npm package as a local
SSE-to-stdio adapter; it is not vendored in this repository.

## GUT

addons/gut/ is GUT (Godot Unit Test) v9.7.1 from
https://github.com/bitwes/Gut, pinned at commit
aeb5d4f3f7f0a6c9b5e178876d6c99b791fda605. It is included under its MIT
license, retained at addons/gut/LICENSE.md. The plugin supplies the editor
test panel and the headless runner used by tools/run-tests.sh.

## Boil effect shader

shaders/boil_effect.gdshader is adapted from the squigglevision shader used by
the related dating-chess project. The original reference is
https://godotshaders.com/shader/squigglevision/.
