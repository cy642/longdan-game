#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")"
engine="${1:-${GODOT_EXE:-godot}}"
mkdir -p .qa/runtime/{cache,data,config}
export XDG_CACHE_HOME="$PWD/.qa/runtime/cache"
export XDG_DATA_HOME="$PWD/.qa/runtime/data"
export XDG_CONFIG_HOME="$PWD/.qa/runtime/config"
"$engine" --headless --path godot --editor --import --quit 2>&1 | tee .qa/import.log
for suite in verify audio_verify map_verify map_view_verify atmosphere_verify enemy_animation_verify; do
  "$engine" --headless --path godot --script "res://tests/$suite.gd" 2>&1 | tee ".qa/$suite.log"
done
