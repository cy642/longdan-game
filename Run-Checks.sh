#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")"
engine="${1:-${GODOT_EXE:-godot}}"
mkdir -p .qa/runtime/{cache,data,config}
export XDG_CACHE_HOME="$PWD/.qa/runtime/cache"
export XDG_DATA_HOME="$PWD/.qa/runtime/data"
export XDG_CONFIG_HOME="$PWD/.qa/runtime/config"
"$engine" --headless --path godot --editor --import --quit 2>&1 | tee .qa/import.log
for suite in verify hero_scale_verify audio_verify map_verify map_view_verify atmosphere_verify theme_atmosphere_verify enemy_animation_verify hanshui_layout_verify hanshui_world_layout_verify hanshui_enemy_verify hanshui_visual_verify hanshui_flow_verify combat_loop_verify battle_art_verify hanshui_pacing_verify chapter_progression_verify first_minutes_verify combat_clarity_verify huangzhong_support_verify scenery_occlusion_verify painted_assets_verify jigu_layout_verify jigu_flow_verify jigu_campaign_verify vanguard_enemy_verify vanguard_visual_verify; do
  "$engine" --headless --path godot --script "res://tests/$suite.gd" 2>&1 | tee ".qa/$suite.log"
done
