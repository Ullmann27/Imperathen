#!/usr/bin/env bash
# Run against the same imported production project, with a separate save per test.
set -euo pipefail
cd "$(dirname "$0")/../.."
godot=${GODOT_BIN:-godot}
version=$("$godot" --version)
[[ "$version" == 4.7.2.* ]] || { echo "Expected Godot 4.7.2, got $version" >&2; exit 2; }
logs=${PRIMA_RESULTS:-$(mktemp -d)}
mkdir -p "$logs"
logs=$(cd "$logs" && pwd)
echo "Godot $version; $(git rev-parse HEAD); logs: $logs"
export GODOT_SILENCE_ROOT_WARNING=1 IMPERATHEN_ISOLATED_TEST=1
run() {
  local name=$1; shift
  local home
  home=$(mktemp -d "$logs/$name.XXXXXX")
  XDG_DATA_HOME="$home/data" XDG_CONFIG_HOME="$home/config" XDG_CACHE_HOME="$home/cache" \
    timeout --kill-after=10s 600s "$godot" "$@" 2>&1 | tee "$home/run.log"
  if grep -Eq '^(SCRIPT ERROR|ERROR):|Parse Error:' "$home/run.log"; then return 1; fi
  local marker=''
  case "$name" in
    genesis_mission_event_batch) marker=GENESIS_MISSION_BATCH_PASS ;;
    city_resident_departure) marker=CITY_RESIDENT_DEPARTURE_PASS ;;
    city_life) marker=CITY_LIFE_PASS ;;
    resident_activity) marker=RESIDENT_ACTIVITY_PASS ;;
    city_ambient_people) marker=CITY_AMBIENT_PEOPLE_PASS ;;
  esac
  if [[ -n "$marker" ]] && ! grep -Eq "^${marker}([[:space:]]|$)" "$home/run.log"; then
    echo "Missing success marker $marker in $name" >&2
    return 1
  fi
}
run import --headless --path prototype --import --quit
node tools/architecture/test_index.mjs
node tools/architecture/build_index.mjs --check
tests=(character_core_phase1 character_equipment_phase2 roman_menu opening_story
       opening_overlay i00_stage opening_director opening_flow opening_voice
       i01_well_asset_contract i01_slice i01_flow
       dialogue_lipsync house_interiors fold7_graphics_policy)
tests+=(genesis_mission_event_batch i04_slice campaign_forge_continuity)
tests+=(city_resident_departure city_life resident_activity city_ambient_people)
for path in prototype/tests/operation_prima_*_test.gd; do
  name=${path##*/}; tests+=("${name%_test.gd}")
done
for test in "${tests[@]}"; do
  run "$test" --headless --path prototype --audio-driver Dummy --fixed-fps 60 --script "res://tests/${test}_test.gd"
done
