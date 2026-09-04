#!/usr/bin/env bash
set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
GODOT_BIN="${GODOT_BIN:-godot}"
RESULTS_DIR="${PROJECT_DIR}/build/test-results"

mkdir -p "${RESULTS_DIR}"

"${GODOT_BIN}" \
	--headless \
	--path "${PROJECT_DIR}" \
	--script addons/gut/gut_cmdln.gd \
	-gexit \
	-gignore_pause \
	-glog=1 \
	-gdisable_colors \
	-gjunit_xml_file="${RESULTS_DIR}/godot-tests.xml" \
	"$@"
