extends SceneTree
## Existing exact mission outcome audio in Main, with actual HUD notice.
const Entry = preload("res://main.tscn")
const Voice = preload("res://scripts/audio/voice_lines.gd")
const MissionData = preload("res://scripts/story/mission_data.gd")
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

func _run() -> void:
	var game: Variant = Entry.instantiate()
	root.add_child(game)
	await process_frame
	game.ui._finish_intro()
	game.model.new_game("italia",true,true,false,true)
	game.world.setup(game.model.data)
	game.session_started = true
	game._resume()
	await process_frame
	game.set_process(false)
	game.set_physics_process(false)
	game.world.set_physics_process(false)
	var steps: Array = MissionData.steps("band1")
	var previous: Dictionary = {}
	var following: Dictionary = {}
	for i: int in range(steps.size()-1):
		if steps[i].get("id") == "fill_water":
			previous=steps[i]
			following=steps[i+1]
			break
	var line: Dictionary = Voice.find(str(previous.get("result","")),"Chronik")
	_check(not previous.is_empty() and not following.is_empty() and not line.is_empty(),"Existing exact source result is voiced")
	if not line.is_empty():
		var before: String = JSON.stringify(game.model.data)
		game._play_mission_notice(str(previous.result),previous,following)
		_check(game.opening_voice.is_active() and game.opening_voice.current.line_id == line.line_id,"Actual Main plays exact existing narrator recording")
		_check(game.opening_voice.face == null and game.opening_voice.current.speaker_id == "narrator","Notice is narrator speech, not an unrelated NPC")
		_check(game.ui._toast_panel.visible and game.ui._toast_panel.modulate.a == 1.0 and game.ui._toast_label.text==previous.result,"Exact visible notice exists from first audio frame")
		_check(game.ui._toast_tween.get_total_elapsed_time() <= 1.0/60.0,"Notice lifetime starts with recording")
		# Independently progress the real UI tween; long speech must outlive
		# the old seven-second maximum notice hold.
		game.ui._toast_tween.pause()
		game.ui._toast_tween.custom_step(float(line.duration_s)-0.02)
		_check(game.ui._toast_panel.visible and game.ui._toast_panel.modulate.a > 0.99,"Notice stays fully legible to actual recording end")
		_check(JSON.stringify(game.model.data)==before,"Narration cannot alter quest, reward, or save state")
		game.ui.notify("Andere Meldung")
		game._advance_mission_notice()
		_check(not game.opening_voice.is_active(),"Replacement notice cancels old speech")
		game._play_mission_notice(str(previous.result),previous,previous)
		_check(not game.opening_voice.is_active(),"Incomplete or repeated step does not narrate")
		game._play_mission_notice("Anderes, nicht aufgezeichnetes Ergebnis",previous,following)
		_check(not game.opening_voice.is_active(),"Branch text is never replaced with an unrelated authored recording")
		game._play_mission_notice(str(previous.result),previous,following)
		game._pause()
		_check(not game.opening_voice.is_active() and game._mission_notice_text.is_empty(),"Pausing cancels the gameplay notice voice")
	game.free()
	await process_frame
	await MixerTeardown.drain(self)
	print("MISSION_RESULT_VOICE_RESULT checks=%d failures=%d" % [checks,failures.size()])
	if failures.is_empty():
		print("MISSION_RESULT_VOICE_PASS")
	quit(0 if failures.is_empty() else 1)
