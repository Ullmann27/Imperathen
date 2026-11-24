#!/usr/bin/env bash
set -euo pipefail
run_story_test() {
  local test_state
  test_state="$(mktemp -d "$RUNNER_TEMP/story-contract.XXXXXX")"
  mkdir -p "$test_state/data" "$test_state/config" "$test_state/cache"
  XDG_DATA_HOME="$test_state/data" \
  XDG_CONFIG_HOME="$test_state/config" \
  XDG_CACHE_HOME="$test_state/cache" \
  IMPERATHEN_ISOLATED_TEST=1 \
    timeout --kill-after=10s 120s "$GODOT_BIN" --headless --path prototype "$@"
}
run_story_test "$@"
