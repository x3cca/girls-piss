# Testing

The starter uses [GUT](https://github.com/bitwes/Gut) v9.7.1 for Godot 4.x
unit and integration tests. GUT is vendored at `addons/gut/` so a fresh clone
has both the editor panel and the command-line runner without an Asset Library
install.

## Local workflow

Run the complete suite from the repository root:

    ./tools/run-tests.sh

Run an individual script by passing GUT options through the wrapper:

    ./tools/run-tests.sh -gtest=res://tests/unit/test_title_screen.gd

For an input-prompt-focused run:

    ./tools/run-tests.sh -gtest=res://tests/unit/test_input_prompt.gd

Run the Godot project/editor check separately:

    godot --headless --editor --check-only

In Godot, use the GUT panel to run or filter tests interactively. New test
scripts must use the `test_*.gd` naming convention. Keep fast, isolated logic
tests in `tests/unit/`; put scene or multi-system coverage in
`tests/integration/` and add that directory to `.gutconfig.json` when it is
introduced.

## CI workflow

The `GUT unit tests` job in `.github/workflows/gdchecks.yml` runs the same
wrapper on every pull request and push to `main`/`master`. A JUnit XML report
is uploaded as the `godot-test-results` artifact even when a test fails, so a
failed run can be inspected from the Actions page.

The test runner is headless and does not require the Godot MCP plugin or Node.js
connection. MCP remains available for editor-driven development; GUT is the
automated test runner.

## Current coverage

The title tests cover the default active state, shared title materials, entry
layout, duplicate-start locking, exit completion, and direct skip behavior. The
input tests cover keyboard, mouse, touch, controller button, controller-axis,
and mouse-motion source behavior. Prompt tests cover Kenney asset mappings,
the shared boil material, separate stacked action rows, replacement without
stacking, and the show/hold/hide timing.
