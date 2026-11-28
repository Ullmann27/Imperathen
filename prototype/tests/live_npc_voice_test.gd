extends SceneTree
## Main's real named-figure conversation voice lifecycle using shipped audio.
const Entry = preload("res://main.tscn")
const Voice = preload("res://scripts/audio/voice_lines.gd")
const MixerTeardown = preload("res://tests/audio_mixer_teardown.gd")
var checks: int = 0
var failures: Array[String] = []

func _initialize() -> void:
	if OS.get_environment("IMPERATHEN_ISOLATED_TEST") != "1":
		quit(2)
		return
	_run.call_deferred()

func _check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures.append(label)
		printerr("FAIL: ",label)

func _frames(count: int) -> void:
	for _index in count:
		await process_frame

func _run() -> void:
	root.size = Vector2i(1280,720)
	var game: Variant = Entry.instantiate()
	root.add_child(game)
	await _frames(3)
	game.ui._finish_intro()
	game.model.new_game("italia",true,true,false,true)
	game.world.setup(game.model.data)
	game.session_started = true
	game._resume()
	await _frames(3)
	var figure: Node3D = game.world.get_cinematic_figure("julia")
	var first: Dictionary = Voice.find_line_id("I01_A_BED")
	var second: Dictionary = Voice.find_line_id("I01_A_REACT_HELP")
	_check(is_instance_valid(figure) and not first.is_empty() and not second.is_empty(), "Real mother and both original recordings available")
	if is_instance_valid(figure) and not first.is_empty() and not second.is_empty():
		game.world.set_active(false)
		game.screen = "village_dialog"
		game.world.focus_village_npc("julia")
		var text: String = "Dynamische Begrüßung.\n\n" + str(first.text) + "\n\n" + str(second.text) + "\n\nVertrauen: 12"
		game.ui.show_village_dialog({"title":"Julia","text":text,"choices":[]})
		var before: String = JSON.stringify(game.model.data)
		game._play_live_dialogue(text,"julia",figure)
		_check(game.opening_voice.is_active() and game.opening_voice.current.line_id == first.line_id, "Exact recorded paragraph plays, not generated status or greeting")
		_check(game._live_dialogue_queue.size() == 1, "Second exact paragraph queued")
		_check(game.opening_voice.current.lip_sync_valid, "Actual imported viseme track is connected")
		_check(figure.detail == 0 and figure._cinematic_detail, "Speaking named figure uses its original near LOD")
		_check(game.opening_voice.current.mouth_output_bound and is_instance_valid(game.opening_voice.face), "Real mother has an actual mouth output, not merely a valid track")
		var real_body: MeshInstance3D = figure.body.find_child("HeroBody", true, false) as MeshInstance3D
		var jaw_slot: int = real_body.find_blend_shape_by_name("JawOpen") if is_instance_valid(real_body) else -1
		_check(jaw_slot >= 0 and figure._face._audio_jaw_owned, "Real imported mother morph is owned by recorded speech")
		if jaw_slot >= 0 and is_instance_valid(game.opening_voice.face):
			var speech = game.opening_voice.face
			var track: Dictionary = Voice.viseme_track(first)
			var strongest: float = 0.0
			var peak: float = 0.0
			for segment: Array in track.segments:
				var t: float = (float(segment[0])+float(segment[1]))*0.5
				speech.sample(t)
				if float(speech.params.jaw_open) > peak:
					peak = float(speech.params.jaw_open)
					strongest = t
			speech.sample(strongest)
			speech._apply()
			var jaw_before: float = real_body.get_blend_shape_value(jaw_slot)
			figure._face.pose("talk",0.32,0)
			_check(peak > 0.1 and jaw_before > 0.1 and is_equal_approx(real_body.get_blend_shape_value(jaw_slot),jaw_before), "Audio morph visibly opens on actual imported mesh and cannot be overwritten by expressive talk")
			# Restore the live audio clock after the deterministic morph sample.
			speech._process(0.0)
		var player: Node = game.opening_voice._player
		game._play_live_dialogue(text,"julia",figure)
		_check(game.opening_voice._player == player, "Same dialogue refresh cannot restart audio")
		game._notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
		_check(game._live_dialogue_paused and player.stream_paused, "Focus loss pauses existing conversation")
		game._notification(Node.NOTIFICATION_APPLICATION_FOCUS_IN)
		_check(not game._live_dialogue_paused and not player.stream_paused, "Focus return resumes same stream")
		game.opening_voice.stop()
		game._advance_live_dialogue()
		_check(game.opening_voice.is_active() and game.opening_voice.current.line_id == second.line_id, "Second paragraph uses same exact speaker")
		_check(JSON.stringify(game.model.data) == before, "Audio changes no story or domain state")
		game._resume()
		_check(not game.opening_voice.is_active() and game._live_dialogue_queue.is_empty() and game.opening_voice.face == null, "Closing dialog removes all audio and face ownership")
		_check(not figure._face._audio_jaw_owned and not figure._cinematic_detail, "Closing restores the actor's usual expression and LOD ownership")
		game.screen = "village_dialog"
		game._play_live_dialogue(str(first.text),"silvanus",figure)
		_check(not game.opening_voice.is_active(), "Text cannot play as wrong speaker")
		game._play_live_dialogue("Nicht vertonter dynamischer Text.","julia",figure)
		_check(not game.opening_voice.is_active(), "Unrecorded text remains silent")
		game._play_live_dialogue(str(first.text),"julia",figure)
		game.screen = "playing"
		game._advance_live_dialogue()
		_check(not game.opening_voice.is_active(), "Any screen departure cancels the recording")
	game._stop_opening_voice()
	game.free()
	await process_frame
	await MixerTeardown.drain(self)
	print("LIVE_NPC_VOICE_RESULT checks=%d failures=%d" % [checks,failures.size()])
	if failures.is_empty():
		print("LIVE_NPC_VOICE_PASS")
	quit(0 if failures.is_empty() else 1)
