extends SceneTree
## I-01 voice lines play with subtitle and mouth on one clock.
## Run with --fixed-fps 60. For every I-01 line:
##   * the runtime text has a voiced manifest entry (text hash, file, track);
##   * the real audio onset is decoded in-engine from the imported Ogg stream;
##   * the subtitle (line_started) appears on the first frame of the clock;
##   * the mouth onset (articulation >= 0.5 on the procedural head, driven via
##     Jaw bone + blend shapes) is within +-1 frame (1/60 s) of the audio onset;
##   * the subtitle ends within 1 frame of the audio end.

const Opening = preload("res://scripts/story/opening_story.gd")
const MissionData = preload("res://scripts/story/mission_data.gd")
const VoiceLines = preload("res://scripts/audio/voice_lines.gd")
const Dialogue = preload("res://scripts/audio/dialogue_player.gd")
const Face = preload("res://scripts/audio/face_driver.gd")
const Head = preload("res://scripts/audio/procedural_test_head.gd")
const FRAME := 1.0 / 60.0
const ONSET_DB := -40.0

var checks := 0
var failures: Array[String] = []
var _report: Array = []


func _initialize() -> void:
	_run.call_deferred()


func _i01_lines() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for beat: Dictionary in Opening.childhood().beats:
		if beat.get("await_choice", false):
			_check(beat.line_id.is_empty() and not beat.choices.is_empty() and not beat.text.is_empty(), "Player choice carries options and its prompt")
			continue
		if beat.get("silent", false):
			continue
		result.append({"speaker": str(beat.speaker), "text": str(beat.text)})
	for mission: Dictionary in MissionData.mission_files("band1"):
		if mission.mission != "I-01":
			continue
		for step: Dictionary in mission.steps:
			if not str(step.get("text", "")).is_empty():
				result.append({"speaker": str(step.npc), "text": str(step.text)})
			if not str(step.get("result", "")).is_empty():
				result.append({"speaker": "Chronik", "text": str(step.result)})
	return result


## Audio onset of the imported stream: first 5 ms hop whose 10 ms RMS is
## within ONSET_DB of the loudest window (same definition as the aligner).
func _audio_onset(stream: AudioStream) -> Dictionary:
	var playback := stream.instantiate_playback()
	playback.start(0.0)
	var rate := AudioServer.get_mix_rate()
	var frames := int(ceil(stream.get_length() * rate))
	var samples: PackedVector2Array = PackedVector2Array()
	while samples.size() < frames:
		var batch := playback.mix_audio(1.0, mini(4096, frames - samples.size()))
		if batch.is_empty():
			break
		samples.append_array(batch)
	playback.stop()
	if samples.size() < int(0.010 * rate):
		return {}
	var win := int(0.010 * rate)
	var hop := int(0.005 * rate)
	var rms := PackedFloat32Array()
	var i := 0
	while i + win < samples.size():
		var acc := 0.0
		for k in win:
			acc += samples[i + k].x * samples[i + k].x
		rms.append(sqrt(acc / win + 1e-12))
		i += hop
	var peak := 0.0
	for v in rms:
		peak = maxf(peak, v)
	var last := 0
	var onset := -1.0
	for n in rms.size():
		if 20.0 * log(rms[n] / peak) / log(10.0) > ONSET_DB:
			if onset < 0.0:
				onset = n * hop / rate
			last = n
	return {"onset": onset, "end": (last * hop + win) / rate}


func _run() -> void:
	var lines := _i01_lines()
	_check(lines.size() >= 6, "I-01 has at least six spoken lines (found %d)" % lines.size())
	var world := Node3D.new()
	root.add_child(world)
	var head := Head.new()
	world.add_child(head)
	var face := Face.new()
	face.blink_enabled = false
	world.add_child(face)
	var bound: Dictionary = face.bind(head)
	_check(bound.jaw_bone and int(bound.blend_shapes) >= 5, "face driver binds Jaw bone and lip blend shapes: %s" % bound)
	var dialogue := Dialogue.new()
	dialogue.face = face
	world.add_child(dialogue)
	var speaker_ids := {}
	for line: Dictionary in lines:
		var entry := VoiceLines.find(line.text)
		_check(not entry.is_empty(), "voiced: %s" % line.text.left(50))
		if entry.is_empty():
			var subtitle := dialogue.play(line.text, line.speaker)
			_check(subtitle.text == line.text and not subtitle.voiced and dialogue._player == null, "An unavailable recording keeps the exact subtitle")
			dialogue.stop()
			continue
		_check(entry.speaker_id == VoiceLines.speaker_id(line.speaker), "%s speaker %s == %s" % [entry.line_id, entry.speaker_id, line.speaker])
		speaker_ids[entry.speaker_id] = true
		var stream := VoiceLines.stream_for(entry)
		var track := VoiceLines.viseme_track(entry)
		_check(stream != null and not track.is_empty(), "%s has audio and viseme track" % entry.line_id)
		if stream == null or track.is_empty():
			continue
		_check(track.text_key == entry.text_key, "%s track belongs to this text" % entry.line_id)
		var audio := _audio_onset(stream)
		_check(not audio.is_empty(), "%s exposes decoded audio samples" % entry.line_id)
		if audio.is_empty():
			continue
		var stamps := {"start":-1.0, "start_frame":-1, "finish":-1.0}
		var mouth_at := -1.0
		var max_jaw := 0.0
		var shapes_follow := true
		var clocks: Array[float] = []
		var on_start := func(_l: Dictionary) -> void:
			stamps.start = dialogue.clock()
			stamps.start_frame = clocks.size()
		var on_end := func(_l: Dictionary) -> void:
			stamps.finish = dialogue._last_clock
		dialogue.line_started.connect(on_start)
		dialogue.line_finished.connect(on_end)
		dialogue.play(line.text, line.speaker)
		var guard := 0
		while dialogue.is_active() and guard < 60 * 60:
			await process_frame
			guard += 1
			if not dialogue.is_active():
				break
			var t := dialogue.clock()
			clocks.append(t)
			if mouth_at < 0.0 and face.activity >= 0.5:
				mouth_at = t
			if face._jaw != -1:
				var angle := face._skeleton.get_bone_pose_rotation(face._jaw).get_angle()
				max_jaw = maxf(max_jaw, angle)
			var lips: MeshInstance3D = head.lips
			if absf(lips.get_blend_shape_value(0) - float(face.params.jaw_open)) > 0.001:
				shapes_follow = false
		dialogue.line_started.disconnect(on_start)
		dialogue.line_finished.disconnect(on_end)
		var started_at := float(stamps.start)
		var started_frame := int(stamps.start_frame)
		var finished_at := float(stamps.finish)
		var monotonic := true
		for k in range(1, clocks.size()):
			if clocks[k] < clocks[k - 1]:
				monotonic = false
		var mouth_delta := mouth_at - float(audio.onset)
		var end_delta := finished_at - float(audio.end)
		_check(started_frame == 0 and started_at >= 0.0 and started_at <= FRAME + 0.0001, "%s subtitle on first clock frame (t=%.4f)" % [entry.line_id, started_at])
		_check(mouth_at >= 0.0 and absf(mouth_delta) <= FRAME + 0.0001, "%s mouth onset %.4f vs audio onset %.4f (delta %.1f ms, limit 16.7)" % [entry.line_id, mouth_at, audio.onset, mouth_delta * 1000.0])
		_check(finished_at >= 0.0 and absf(finished_at - stream.get_length()) <= FRAME + 0.0001, "%s subtitle ends with the stream (%.3f vs %.3f)" % [entry.line_id, finished_at, stream.get_length()])
		_check(end_delta >= -FRAME, "%s subtitle stays until audible speech ends (%.3f vs %.3f)" % [entry.line_id, finished_at, audio.end])
		_check(monotonic, "%s clock monotonic" % entry.line_id)
		_check(max_jaw > deg_to_rad(3.0), "%s jaw bone opens (max %.1f deg)" % [entry.line_id, rad_to_deg(max_jaw)])
		_check(shapes_follow, "%s lip blend shape follows jaw_open parameter" % entry.line_id)
		_report.append({"line_id": entry.line_id, "speaker_id": entry.speaker_id, "audio_onset_s": snappedf(audio.onset, 0.0001),
			"mouth_onset_s": snappedf(mouth_at, 0.0001), "delta_ms": snappedf(mouth_delta * 1000.0, 0.1),
			"subtitle_start_s": snappedf(started_at, 0.0001), "subtitle_end_s": snappedf(finished_at, 0.0001),
			"stream_length_s": snappedf(stream.get_length(), 0.0001), "audio_end_s": snappedf(audio.end, 0.0001),
			"max_jaw_deg": snappedf(rad_to_deg(max_jaw), 0.1), "clock_source": dialogue.clock_source})
	for sid in ["narrator", "julia", "silvanus"]:
		_check(speaker_ids.has(sid), "I-01 casts %s" % sid)
	# Unvoiced text still yields a subtitle with a reading duration.
	var record := dialogue.play("Diese Zeile hat keine Aufnahme.", "Chronik")
	_check(not record.voiced, "unknown text is reported as unvoiced")
	dialogue.stop()
	world.queue_free()
	await process_frame
	# AudioServer releases stopped Ogg playback from its mixer thread. The
	# fixed-step test can finish several minutes of story in one mixer tick.
	var periods := 0
	var since_mix := AudioServer.get_time_since_last_mix()
	var deadline := Time.get_ticks_msec() + 500
	while periods < 4 and Time.get_ticks_msec() < deadline:
		OS.delay_msec(2)
		await process_frame
		var elapsed := AudioServer.get_time_since_last_mix()
		if elapsed < since_mix:
			periods += 1
		since_mix = elapsed
	print("DIALOGUE_LIPSYNC_REPORT " + JSON.stringify(_report))
	print("DIALOGUE_LIPSYNC_RESULT checks=%d failures=%d" % [checks, failures.size()])
	for failure in failures:
		printerr("FAIL: " + failure)
	print("DIALOGUE_LIPSYNC_PASS" if failures.is_empty() else "DIALOGUE_LIPSYNC_FAIL")
	quit(0 if failures.is_empty() else 1)


func _check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures.append(label)
