# Addons

This directory contains editor/development plugins used by the template.

godot_mcp/ is the Date-or-Mate-2 Godot MCP bridge. It is enabled in
project.godot and excluded from Web exports because it is development tooling.
Codex CLI reaches it through the npx mcp-remote adapter configured in
.codex/config.toml.

gut/ is GUT (Godot Unit Test) v9.7.1, pinned for the Godot 4.x project. It
provides the editor test panel, assertions, doubles, and the headless CLI used
by the local test command and GitHub Actions. See tests/README.md and
third_party/README.md before updating vendored files.
