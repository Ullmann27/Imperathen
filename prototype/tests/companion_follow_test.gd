extends SceneTree
## Echte Missionsbefehle, bestehende Körper, Beobachtung und Save/Load.
## Fixture-Reisen sind ausdrücklich keine gemessenen Spielerdurchläufe.

const Model = preload("res://scripts/domain/world_model.gd")
const World = preload("res://scripts/world/game_world.gd")
const Main = preload("res://scripts/main.gd")
const UI = preload("res://scripts/ui/game_ui.gd")
const Childhood = preload("res://scripts/story/village_childhood.gd")
const I03Support = preload("res://tests/i03_support.gd")
const Story = preload("res://scripts/story/companion_story.gd")
const Life = preload("res://scripts/story/village_life.gd")
const Layout = preload("res://scripts/world/village/village_layout.gd")
var checks := 0
var failures: Array[String] = []
var snapshots: Dictionary = {}


func _initialize() -> void:
	_run.call_deferred()


func _check(ok: bool, message: String) -> bool:
	checks += 1
	if not ok:
		failures.append(message)
		printerr("COMPANION_FAIL: " + message)
	return ok


func _run() -> void:
	_test_story()
	if failures.is_empty():
		await _test_world()
	print("COMPANION_FOLLOW_RESULT checks=%d failures=%d" % [checks, failures.size()])
	for message: String in failures:
		printerr("FAIL: " + message)
	print("COMPANION_FOLLOW_PASS" if failures.is_empty() else "COMPANION_FOLLOW_FAIL")
	quit(0 if failures.is_empty() else 1)


func _test_story() -> void:
	var model := Model.new()
	model.new_game("italia", true, true)
	_check(Childhood.companion_specs(model.data).is_empty(), "Am ersten Familienmorgen wird niemand vorzeitig als Begleiter aktiviert")
	for stage: String in ["deliver_kindling", "market_trade", "i08_tracks", "night_rest"]:
		if not _reach(model, stage):
			return
		snapshots[stage] = model.data.duplicate(true)
		var expected := "silvanus" if stage == "deliver_kindling" else "marcus"
		var specs := Childhood.companion_specs(model.data)
		_check(specs.size() == 1 and specs.has(expected), "Genau der belegte Begleiter ist aktiv: " + stage)
		var dialog := Childhood.companion_dialogue(model.data, expected)
		_check(not dialog.is_empty() and str(dialog.source).contains("Band 1"), "Belegte Dialogquelle für " + stage)
		_check(not str(dialog.text).contains("Armeen"), "Keine zeitlich unpassende Rückblende in " + stage)
	var friend: Dictionary = Childhood.companion_dialogue(snapshots.market_trade, "marcus")
	var rival := Model.new()
	rival.new_game("italia", true, true)
	if _reach(rival, "market_trade", true):
		var opposed: Dictionary = Childhood.companion_dialogue(rival.data, "marcus")
		_check(friend.tone == "friend" and opposed.tone == "rival" and friend.text != opposed.text, "Die tatsächliche I-03-Wahl wählt verschiedene belegte Marktzeilen")
		var before_choice: String = rival.data.companion.choice
		var before_trust: int = rival.data.companion.trust
		rival.data.companion.trust = 80
		_check(Childhood.companion_dialogue(rival.data, "marcus").tone == "rival" and rival.data.companion.choice == before_choice, "Ton folgt der konkreten Entscheidung, nicht dem veränderbaren Vertrauenswert")
		rival.data.companion.trust = before_trust
		for stage: String in ["i08_tracks", "night_rest"]:
			if _reach(rival, stage, true):
				var quiet := Childhood.companion_dialogue(rival.data, "marcus")
				var known := Childhood.companion_dialogue(snapshots[stage], "marcus")
				_check(quiet.text == known.text and quiet.title != known.title, "Ein belegter Satz mit unterschiedlicher Regie statt erfundener Zweitzeile: " + stage)
	_check(Story.display_name(model.data, "severus", "Severus") == "Wachmann", "Unbelegter Eigenname wird im Kindheitsabschnitt ersetzt")
	var legacy := Model.new()
	legacy.new_game("italia", true)
	_check(Story.display_name(legacy.data, "severus", "Severus") == "Severus" and Childhood.companion_specs(legacy.data).is_empty(), "Bestehende andere Karriere behält Namen und Verhalten")
	for npc: Dictionary in Life.npc_catalog(model.data):
		if npc.id == "severus":
			_check(npc.name == "Wachmann", "Auch das Bewohnerverzeichnis verwendet den gesicherten Anzeigenamen")


func _reach(model: RefCounted, goal: String, rival := false) -> bool:
	for attempt in 100:
		var view: Dictionary = Childhood.view(model.data)
		if not _check(not view.is_empty(), "Gültiger Missionszustand auf dem Weg zu " + goal):
			return false
		if view.stage == goal:
			return true
		if str(view.stage).begins_with("i03_"):
			# I-03 errand: the stored memories decide the later tone.
			var errand: Dictionary = I03Support.play_stage(model, I03Support.RIVAL if rival else I03Support.FRIEND)
			if not _check(errand.ok, "I-03-Abschnitt " + str(view.stage) + ": " + str(errand.get("message", ""))):
				return false
			continue
		var point: Vector2 = view.point
		model.set_player_position(Vector3(point.x, 1.0, point.y))
		var npc: String = view.get("target_npc", "")
		if not npc.is_empty() and not Life.relationship(model.data, npc).get("met", false):
			if not _check(model.execute("village_talk", {"npc_id":npc, "choice":"meet"}).ok, "Gesprächspartner real kennenlernen: " + npc):
				return false
		view = Childhood.view(model.data)
		var action: String = view.actions[0].payload.action_id
		var result: Dictionary = model.execute("village_childhood_action", {"action_id":action})
		if not _check(result.ok, "Echter Missionsbefehl " + action + ": " + str(result.message)):
			return false
		if action.begins_with("begin_"):
			model.advance(float(view.work_required)+0.05)
	return _check(false, "Zielschritt wird erreicht: " + goal)


func _test_world() -> void:
	var model := Model.new()
	var world := World.new()
	root.add_child(world)
	world.set_physics_process(false)
	var cases := {
		"deliver_kindling":{"id":"silvanus", "player":Vector3(31.4, 0.94, -21.9), "stop":Vector2(30.4,-23.2), "ticks":2100},
		"market_trade":{"id":"marcus", "player":Vector3(24.4,0.94,28.0), "stop":Vector2(22.8,26.8), "ticks":1200},
		"i08_tracks":{"id":"marcus", "player":Vector3(0.0,0.94,-35.0), "stop":Vector2(-1.7,-34.2), "ticks":1500},
		"night_rest":{"id":"marcus", "player":Vector3(-12.5,0.94,18.0), "stop":Vector2(-13.8,17.1), "ticks":1200}
	}
	for stage: String in cases:
		model.data = snapshots[stage].duplicate(true)
		model.set_player_position(cases[stage].player)
		world.setup(model.data)
		world.set_active(true)
		model.npc_observations = world.npc_observations
		await physics_frame
		await physics_frame
		var id: String = cases[stage].id
		var actor: CharacterBody3D = world._story_companions.actor(id)
		_check(actor != null and actor.collision_layer == Layout.CITIZEN_LAYER, "Bestehende Figur besitzt genau einen realen Begleitkörper: " + stage)
		_check(world.population.actors.size() == 26 and world.village_life_world.actors.size() == 15, "Begleitung erzeugt keine doppelten Dorfbewohner: " + stage)
		var before := actor.global_position
		for tick in int(cases[stage].ticks):
			await physics_frame
			world._update_story_companions(1.0/60.0)
			if Vector2(actor.global_position.x,actor.global_position.z).distance_to(cases[stage].stop) < 0.35:
				break
		var actual := actor.global_position
		var gap := Vector2(actual.x,actual.z).distance_to(cases[stage].stop)
		_check(actual.distance_to(before) > 1.0, "Begleiter ist tatsächlich gelaufen: " + stage)
		_check(gap < 0.6, "Begleiter erreicht den definierten Haltepunkt " + stage + "; Abstand=" + str(gap))
		_check(actor.global_position.y > -0.1, "Begleiter bleibt über dem Boden: " + stage)
		world.sync_state(model.data)
		_check(actor.global_position.distance_to(actual) < 0.001, "Normaler State-Sync teleportiert den Begleiter nicht zurück: " + stage)
		model.capture_npc_observations()
		var observed: Variant = Story.observed_position(model.data, id)
		_check(observed != null and observed.distance_to(Vector2(actual.x,actual.z)) < 0.001, "Auftrag und Körper verwenden dieselbe beobachtete Position: " + stage)
		if id == "silvanus":
			_check(Life.actor_position(model.data, id).distance_to(observed) < 0.001, "Silvanus kann an seiner wirklichen Position angesprochen werden")
		world.set_active(false)
		for tick in 10:
			await physics_frame
			world._update_story_companions(1.0/60.0)
		_check(actor.global_position.distance_to(actual) < 0.001, "Dialog-/Menüpause hält den Begleiter an seinem wirklichen Standort: " + stage)
		var path := "user://companion_" + stage + ".json"
		var progression := _save_json(model.data.village.childhood)
		var relationship := _save_json(model.data.companion)
		_check(model.save_game(path).ok, "Begleitposition im bestehenden v5-Envelope speichern: " + stage)
		var restored := Model.new()
		_check(restored.load_game(path).ok, "Begleitposition laden: " + stage)
		_check(_save_json(restored.data.village.childhood) == progression and _save_json(restored.data.companion) == relationship, "Save/Load bewahrt Aufgaben und I-03-Wahl ohne neue Statusfelder: " + stage)
		world.setup(restored.data)
		_check(actor.global_position.distance_to(actual) < 0.001, "Laden stellt denselben Körper am gespeicherten Standort her: " + stage)
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path + ".bak"))
		await _test_dialog(model, world, stage)
	var legacy := Model.new()
	legacy.new_game("italia", true)
	world.setup(legacy.data)
	var father: CharacterBody3D = world._story_companions.actor("silvanus")
	var workplace: Vector2 = Life.actor_position(legacy.data, "silvanus")
	_check(Vector2(father.position.x, father.position.z).distance_to(workplace) < 0.001, "Andere Karriere behält Silvanus' tatsächlichen Arbeitsplatz beim Laden")
	_check(not father.get_meta("companion_controlled", false), "Andere Karriere aktiviert keine Kindheitsregie")
	legacy.new_game("italia")
	world.setup(legacy.data)
	_check(not world.village_life_world.visible and father.collision_layer == 0, "Ausgeblendetes Dorf lässt keinen unsichtbar kollidierenden Silvanus zurück")
	world.queue_free()
	await process_frame


func _save_json(value: Variant) -> String:
	# JSON kennt keinen getrennten Integer-Typ. Gleicher vollständiger Rundlauf
	# normalisiert ausschließlich Zahlentypen; alle Felder und Werte bleiben im Vergleich.
	return JSON.stringify(JSON.parse_string(JSON.stringify(value, "", true, true)), "", true, true)


func _test_dialog(model: RefCounted, world: Node3D, stage: String) -> void:
	if stage != "market_trade":
		return
	var session := Main.new()
	session.model = model
	session.world = world
	session.session_started = true
	session.screen = "playing"
	var ui := UI.new()
	root.add_child(ui)
	session.ui = ui
	await process_frame
	world.set_active(true)
	session._show_companion()
	_check(session.screen == "dialog", "Marcus öffnet über die echte Main-Aktion seinen Begleitdialog")
	_check(ui._dialog_data.text == Childhood.companion_dialogue(model.data, "marcus").text, "Dialogwidget zeigt ausschließlich die belegte Marcus-Zeile")
	_check(not world._active, "Begleitgespräch pausiert die Welt")
	session.screen = "playing"
	world._player.position += Vector3(20.0,0.0,0.0)
	session._show_companion()
	_check(session.screen == "playing", "Entfernter Marcus kann nicht aus der Ferne angesprochen werden")
	# This dialog session was instantiated off-tree. Its audio player must
	# still share its lifetime when a user closes the dialogue fixture.
	var voice_id := session.opening_voice.get_instance_id()
	ui.queue_free()
	session.free()
	_check(not is_instance_id_valid(voice_id), "Das Beenden der Dialogsitzung gibt deren Sprachspieler frei")
	await process_frame
