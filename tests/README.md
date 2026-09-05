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

    ./tools/run-tests.sh -gtest=res://tests/unit/test_liquid_stream_scene.gd

You can also run the suite from the GUT panel in the Godot editor. Keep tests
deterministic and put unit tests in tests/unit/; use tests/integration/ for
scene-level or multi-system tests when the game grows. GUT discovers scripts
whose names start with test_ and end in .gd.

The tests verify that the prototype scene builds and that direct crosshair
targeting and inertial parcel behavior remain deterministic as systems are
added. They also cover the title gate and skip path, input-source detection,
contextual prompt mappings and animation, baked depth sampling, stream pulse
feedback, and replay behavior.

Useful focused runs include:

    ./tools/run-tests.sh -gtest=res://tests/unit/test_title_screen.gd
    ./tools/run-tests.sh -gtest=res://tests/unit/test_input_prompt.gd
    ./tools/run-tests.sh -gtest=res://tests/unit/test_aim_controls.gd
