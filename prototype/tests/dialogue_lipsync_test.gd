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
const I01 = preload("res://scripts/story/i01_three_cups.gd")
const MixerTeardown := preload("res://tests/audio_mixer_teardown.gd")
const VoiceLines = preload("res://scripts/audio/voice_lines.gd")
const Dialogue = preload("res://scripts/audio/dialogue_player.gd")
const Face = preload("res://scripts/audio/face_driver.gd")
const Head = preload("res://scripts/audio/procedural_test_head.gd")
const FRAME := 1.0 / 60.0
const ONSET_DB := -40.0

var checks := 0
var failures: Array[String] = []
var _report: Array = []
var _authored_count: int = 0
var _authored_missing: Array[String] = []
var _authored_present: int = 0


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


## Reject wrong phoneme-index order, invalid timing and duplicate catalogue
## identities before the runtime can send them to the facial animation.
func _check_voice_contract() -> void:
	var known := VoiceLines.find_line_id("I-00.i00_caesar")
	var track := VoiceLines.viseme_track(known)
	_check(not known.is_empty() and not track.is_empty(), "Known shipped Caesar recording has valid contract")
	if known.is_empty() or track.is_empty():
		return
	var swapped := track.duplicate(true)
	var first: Variant = swapped.visemes[0]
	swapped.visemes[0] = swapped.visemes[1]
	swapped.visemes[1] = first
	_check(not VoiceLines.validate_viseme_track(swapped, known), "Reordered viseme indices cannot drive incorrect mouths")
	var wrong_duration := track.duplicate(true)
	wrong_duration.duration_s = float(known.duration_s) + 0.5
	_check(not VoiceLines.validate_viseme_track(wrong_duration, known), "Track duration must match the recording metadata")
	var wrong_onset := track.duplicate(true)
	wrong_onset.first_phoneme_s = float(track.audio_onset_s) + 0.1
	_check(not VoiceLines.validate_viseme_track(wrong_onset, known), "Audio and phoneme onset must agree")
	var negative_onset := track.duplicate(true)
	negative_onset.audio_onset_s = -0.1
	negative_onset.first_phoneme_s = -0.1
	_check(not VoiceLines.validate_viseme_track(negative_onset, known), "Negative onset cannot be accepted")
	var wrong_type := track.duplicate(true)
	wrong_type.duration_s = "invalid"
	_check(not VoiceLines.validate_viseme_track(wrong_type, known), "Malformed duration is rejected without conversion")
	var wrong_index := track.duplicate(true)
	wrong_index.segments[0][2] = 15
	_check(not VoiceLines.validate_viseme_track(wrong_index, known), "Out-of-range mouth index is rejected")
	var wrong_speaker := track.duplicate(true)
	wrong_speaker.speaker_id = "julia"
	_check(not VoiceLines.validate_viseme_track(wrong_speaker, known), "Wrong speaker track is rejected")
	var same_key := known.duplicate(true)
	same_key.line_id = "duplicate-story-entry"
	var duplicated := VoiceLines.index_lines([known, same_key])
	_check(duplicated.by_key[known.text_key][known.speaker_id].is_empty(), "Two recordings for the same speaker and subtitle are ambiguous")
	var duplicate_id := VoiceLines.index_lines([known, known.duplicate(true)])
	_check(duplicate_id.by_id[known.line_id].is_empty(), "Duplicate line IDs cannot overwrite each other")
	var another_speaker := known.duplicate(true)
	another_speaker.line_id = "other-speaker"
	another_speaker.speaker_id = "julia"
	var distinct := VoiceLines.index_lines([known, another_speaker])
	_check(distinct.by_key[known.text_key].size() == 2 and not distinct.by_key[known.text_key]["julia"].is_empty(), "Same words spoken by different characters stay distinct")
	var stale := known.duplicate(true)
	stale.text = "Changed dialogue."
	_check(VoiceLines.index_lines([stale]).by_id.is_empty(), "A stale text hash cannot index a changed dialogue line")
	_check(VoiceLines.stream_for({"file": "../voice/lines/I-00.i00_caesar.ogg"}) == null, "Audio path cannot escape its catalogue")
	_check(VoiceLines.viseme_track({"visemes": "../voice/visemes/I-00.i00_caesar.json"}).is_empty(), "Viseme path cannot escape its catalogue")
	for row: Dictionary in VoiceLines.all_lines():
		_check(not VoiceLines.viseme_track(row).is_empty(), "Shipped viseme contract: " + str(row.line_id))


## Measure the FINAL imported Ogg, not the pre-encode WAV master.
## Only explicitly staged, receipt-bound recordings may be re-anchored.
func _measure_staged_onsets(receipt_path: String, output_path: String) -> void:
	var receipt: Variant = JSON.parse_string(FileAccess.get_file_as_string(receipt_path))
	var measurements: Array[Dictionary] = []
	var valid: bool = receipt is Dictionary and receipt.get("rows") is Array and not output_path.is_empty()
	if valid:
		for item: Variant in receipt.rows:
			if not item is Dictionary:
				valid = false
				break
			var row: Dictionary = item
			var entry: Dictionary = VoiceLines.find_line_id(str(row.get("line_id","")))
			if entry.is_empty() or entry.get("sha256") != row.get("sha256") or entry.get("visemes_sha256") != row.get("visemes_sha256") or entry.get("speaker_id") != row.get("speaker_id"):
				valid = false
				break
			var raw_audio: String = "res://assets/audio/voice/" + str(entry.file)
			if FileAccess.get_sha256(raw_audio) != row.sha256 or VoiceLines.viseme_track(entry).is_empty():
				valid = false
				break
			var stream: AudioStream = VoiceLines.stream_for(entry)
			if stream == null:
				valid = false
				break
			var audio: Dictionary = _audio_onset(stream)
			if audio.is_empty() or not is_finite(float(audio.get("onset",-1))) or float(audio.onset) < 0.0:
				valid = false
				break
			measurements.append({"line_id":entry.line_id,"speaker_id":entry.speaker_id,"sha256":entry.sha256,
				"visemes_sha256":entry.visemes_sha256,"decoded_onset_s":audio.onset,"stream_length_s":stream.get_length()})
	if valid and measurements.size() == int(receipt.get("staged",-1)):
		var file: FileAccess = FileAccess.open(output_path,FileAccess.WRITE)
		if file != null:
			file.store_string(JSON.stringify({"engine":Engine.get_version_info().string,"mix_rate":AudioServer.get_mix_rate(),
				"method":"Godot imported playback; 10 ms RMS, 5 ms hop, -40 dB", "rows":measurements}))
			file.close()
			await MixerTeardown.drain(self)
			print("IMPORTED_VOICE_ONSETS_PASS count=%d" % measurements.size())
			quit(0)
			return
	await MixerTeardown.drain(self)
	printerr("IMPORTED_VOICE_ONSETS_FAIL")
	quit(1)


func _run() -> void:
	var receipt_path: String = ""
	var output_path: String = ""
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--measure-staged-onsets="):
			receipt_path = arg.trim_prefix("--measure-staged-onsets=")
		elif arg.begins_with("--onset-output="):
			output_path = arg.trim_prefix("--onset-output=")
	if not receipt_path.is_empty():
		await _measure_staged_onsets(receipt_path,output_path)
		return
	_check_voice_contract()
	# The current film includes alternate family reactions and topic branches,
	# not only the default VID-A path. Every authored spoken line must have
	# its own exact text, correct speaker, imported audio and matching track.
	for line_id: String in I01.slice().get("lines", {}):
		var authored: Dictionary = I01.line(line_id)
		var entry := VoiceLines.find(str(authored.text), str(authored.speaker_id))
		_check(not entry.is_empty(), "I-01 branch recording: " + line_id)
		if not entry.is_empty():
			var expected := VoiceLines.speaker_id(str(authored.speaker_id))
			_check(entry.speaker_id == expected, "I-01 branch cast: " + line_id)
			var track := VoiceLines.viseme_track(entry)
			_check(VoiceLines.stream_for(entry) != null and track.get("text_key", "") == entry.text_key and track.get("speaker_id", "") == expected, "I-01 branch audio/visemes: " + line_id)
	var lines := _i01_lines()
	var seen := {}
	for line: Dictionary in lines:
		seen[VoiceLines.speaker_id(str(line.speaker)) + ":" + VoiceLines.text_key(str(line.text))] = true
	for line_id: String in I01.slice().get("lines", {}):
		var authored: Dictionary = I01.line(line_id)
		var text_key := VoiceLines.speaker_id(str(authored.speaker_id)) + ":" + VoiceLines.text_key(str(authored.text))
		if not seen.has(text_key):
			lines.append({"speaker":str(authored.speaker_id), "text":str(authored.text)})
			seen[text_key] = true
	# Optional exact inventory: use the same actual decoder, DialoguePlayer,
	# one-frame audio/mouth/subtitle bounds and face driver for every authored
	# recording, not just the original I-01 subset. Release mode never skips
	# an unavailable recording; diagnostic mode records missing lines explicitly.
	var args := OS.get_cmdline_user_args()
	var inventory_path := ""
	var diagnostic := "--allow-missing-authored" in args
	for arg: String in args:
		if arg.begins_with("--authored="):
			inventory_path = arg.trim_prefix("--authored=")
	if not inventory_path.is_empty():
		var inventory: Variant = JSON.parse_string(FileAccess.get_file_as_string(inventory_path))
		_check(inventory is Dictionary and inventory.get("lines") is Array and not inventory.lines.is_empty(), "Exact authored inventory exists")
		if inventory is Dictionary and inventory.get("lines") is Array:
			var identities: Dictionary = {}
			for item: Variant in inventory.lines:
				if not item is Dictionary:
					_check(false, "Malformed authored inventory line")
					continue
				var row: Dictionary = item
				var text: String = str(row.get("text", ""))
				var speaker: String = str(row.get("speaker_id", ""))
				var key: String = speaker + ":" + VoiceLines.text_key(text)
				var valid: bool = not text.is_empty() and not speaker.is_empty() and row.get("text_key") == VoiceLines.text_key(text) and not identities.has(key)
				_check(valid, "Unique exact authored speaker/text identity: " + str(row.get("line_id", "")))
				if not valid:
					continue
				identities[key] = true
				_authored_count += 1
				var record: Dictionary = VoiceLines.find(text, speaker)
				if record.is_empty():
					_authored_missing.append(str(row.get("line_id", "")))
					if not diagnostic:
						_check(false, "Missing authored recording: " + str(row.get("line_id", "")))
					continue
				_authored_present += 1
				if not seen.has(key):
					lines.append({"speaker":speaker, "text":text})
					seen[key] = true
			_check(_authored_count > 0 and _authored_present + _authored_missing.size() == _authored_count, "All authored identities are accounted for")
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
		var entry := VoiceLines.find(line.text, line.speaker)
		_check(not entry.is_empty(), "voiced: %s" % line.text.left(50))
		if entry.is_empty():
			var subtitle := dialogue.play(line.text, line.speaker)
			_check(subtitle.text == line.text and not subtitle.voiced and dialogue._player == null, "An unavailable recording keeps the exact subtitle")
			dialogue.stop()
			continue
		_check(VoiceLines.find(line.text, "__unregistered_speaker__").is_empty(), "Exact text cannot play in an unrelated speaker's voice")
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
	await MixerTeardown.drain(self)
	if not inventory_path.is_empty():
		print("DIALOGUE_AUTHORED_COVERAGE " + JSON.stringify({"authored":_authored_count,"present":_authored_present,"missing":_authored_missing,"diagnostic_only":diagnostic}))
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
