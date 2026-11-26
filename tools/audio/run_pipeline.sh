#!/usr/bin/env bash
# Full, reproducible audio pipeline. Requires: Godot 4.7.2 ($G), Python venv with
# qwen-tts 0.1.1, torch (CPU), transformers, soundfile, librosa, praat-parselmouth,
# pyloudnorm, scipy; espeak-ng and ffmpeg (libvorbis) on PATH. Models are
# downloaded from Hugging Face at the pinned revisions in docs/41_audio/LICENSES.md.
#   G=/path/to/godot WORK=/tmp/audio_work tools/audio/run_pipeline.sh
set -euo pipefail
cd "$(dirname "$0")/../.."
: "${G:?set G to the Godot binary}"
: "${WORK:?set WORK to a scratch directory}"
OUT=prototype/assets/audio/voice
mkdir -p "$WORK"
export GODOT_SILENCE_ROOT_WARNING=1 IMPERATHEN_ISOLATED_TEST=1
"$G" --headless --path prototype --script res://tests/tools/export_dialogue_lines.gd -- "$WORK/lines.json"
python3 tools/audio/build_pool_cast.py --work "$WORK"
python3 -I tools/audio/generate_voices.py --lines "$WORK/lines.json" --cast "$WORK/cast_all.json" --work "$WORK" --out "$OUT"
python3 -I tools/audio/generate_voices.py --lines "$WORK/lines_pool.json" --cast "$WORK/cast_all.json" --work "$WORK" --out "$OUT"
python3 -I tools/audio/align_visemes.py --work "$WORK" --out "$OUT"
python3 tools/audio/build_manifest.py --work "$WORK" --out "$OUT" --cast "$WORK/cast_all.json"
python3 -I tools/audio/synth_sfx.py --out prototype/assets/audio/sfx
python3 -I tools/audio/verify_sfx.py --out-json docs/41_audio/evidence/sfx_verification.json --out-md docs/41_audio/SFX_VERIFICATION.md
"$G" --headless --path prototype --import
python3 -I tools/audio/measure_loudness.py --out docs/41_audio/evidence/loudness.json
