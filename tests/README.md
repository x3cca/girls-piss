# Tests

This project uses GUT (Godot Unit Test) v9.7.1. It provides assertions,
test doubles, signal/input helpers, an editor panel, and a headless CLI. The
plugin is already enabled in project.godot.

## Run tests

From the repository root:

    ./tools/run-tests.sh

The same command is run by GitHub Actions. It writes a JUnit report to
build/test-results/godot-tests.xml; build/ is ignored so local reports do not
enter commits. Pass GUT CLI options after the wrapper when narrowing a run,
for example:

    ./tools/run-tests.sh -gtest=res://tests/unit/test_starter_project.gd

You can also run the suite from the GUT panel in the Godot editor. Keep tests
deterministic and put unit tests in tests/unit/; use tests/integration/ for
scene-level or multi-system tests when the game grows. GUT discovers scripts
whose names start with test_ and end in .gd.

The starter test only verifies that the project opens and its smoke scene is
usable. Replace or extend it with game-specific coverage as systems are added.
