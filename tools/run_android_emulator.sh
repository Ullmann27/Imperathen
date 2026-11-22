#!/usr/bin/env bash
set -euo pipefail
image='system-images;android-35;google_apis;x86_64'
"$ANDROID_HOME/cmdline-tools/latest/bin/sdkmanager" 'emulator' "$image"
export ANDROID_USER_HOME="$RUNNER_TEMP/android-user"
export ANDROID_AVD_HOME="$RUNNER_TEMP/android-avd"
mkdir -p "$ANDROID_USER_HOME" "$ANDROID_AVD_HOME"
echo no | "$ANDROID_HOME/cmdline-tools/latest/bin/avdmanager" create avd --force --name imperathen --device pixel_6 --path "$ANDROID_AVD_HOME/imperathen.avd" --package "$image"
test -f "$ANDROID_AVD_HOME/imperathen.ini"
"$ANDROID_HOME/emulator/emulator" -list-avds
sudo chmod a+rw /dev/kvm
"$ANDROID_HOME/emulator/emulator" -accel-check
"$ANDROID_HOME/platform-tools/adb" start-server
df -h "$RUNNER_TEMP"
"$ANDROID_HOME/emulator/emulator" -avd imperathen -no-window -no-audio -no-boot-anim -no-snapshot -gpu swangle -memory 3072 -partition-size 2048 > "$RUNNER_TEMP/android-emulator.log" 2>&1 &
emulator_pid=$!
trap 'tail -80 "$RUNNER_TEMP/android-emulator.log"; kill "$emulator_pid" 2>/dev/null || true' EXIT
python3 tools/android_runtime_smoke.py --adb "$ANDROID_HOME/platform-tools/adb" --apk "artifacts/${IMPERATHEN_BUILD}-emulator.apk" --output android-runtime --device-apk "artifacts/${IMPERATHEN_BUILD}-arm64.apk"
if [[ "${IMPERATHEN_GRAPHICS_QA:-0}" == 1 ]]; then
  python3 tools/android_graphics_benchmark.py --mode soak --adb "$ANDROID_HOME/platform-tools/adb" --apk "artifacts/${IMPERATHEN_BUILD}-emulator.apk" --output android-runtime/soak
  python3 tools/android_graphics_benchmark.py --mode renderer --adb "$ANDROID_HOME/platform-tools/adb" --apk "artifacts/${IMPERATHEN_BUILD}-emulator-vulkan.apk" --output android-runtime/vulkan
  python3 tools/android_graphics_benchmark.py --mode renderer --abi arm64-v8a --adb "$ANDROID_HOME/platform-tools/adb" --apk "artifacts/${IMPERATHEN_BUILD}-arm64-vulkan.apk" --output android-runtime/vulkan-arm64
fi
