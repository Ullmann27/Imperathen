"""Shared validation of the actual forced-alignment format used by Godot."""
import math

def number(x):
    return type(x) in (int, float) and math.isfinite(x)

def track_errors(track, line):
    if not isinstance(track, dict) or any(track.get(k) != line.get(k) for k in ("line_id", "speaker_id", "text_key")):
        return ["viseme_identity_mismatch"]
    duration = track.get("duration_s")
    if track.get("schema_version") != 1 or not number(duration) or duration <= 0:
        return ["viseme_schema_invalid"]
    expected = line.get("duration_s")
    if not number(expected) or abs(duration - expected) > .002:
        return ["viseme_duration_mismatch"]
    names, segments = track.get("visemes"), track.get("segments")
    if not isinstance(names, list) or len(names) != 15 or len(set(names)) != 15 or not isinstance(segments, list) or not segments:
        return ["viseme_segments_missing"]
    last = -1.0
    for item in segments:
        if not isinstance(item, list) or len(item) != 3:
            return ["viseme_segment_invalid"]
        start, end, index = item
        # The aligner deliberately extends a final segment up to 60 ms.
        if not number(start) or not number(end) or start < 0 or end < start or start < last or end > duration + .061 or type(index) is not int or not 0 <= index < len(names):
            return ["viseme_segment_invalid"]
        last = start
    onset, first = track.get("audio_onset_s"), track.get("first_phoneme_s")
    if not number(onset) or not number(first) or abs(onset-first) > .0167:
        return ["viseme_onset_mismatch"]
    return []


def recording_errors(row, speaker_ids):
    """Validate manifest ownership and the stored transcription receipt."""
    errors = []
    if row.get("speaker_id") not in speaker_ids:
        errors.append("unregistered_speaker")
    wer = row.get("asr_wer")
    text = row.get("asr_text")
    if type(wer) not in (int, float) or not 0 <= wer <= 0.12 or not isinstance(text, str) or not text.strip():
        errors.append("unaccepted_transcription")
    return errors
