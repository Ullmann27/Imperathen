extends RefCounted
## Offline authority for the first playable chapter. Renderers only read `data`.
## Command transactions are atomic; construction is a sequence of paid work steps.
## Save hashes detect corruption, not deliberate editing by the owner of a save.

signal changed

const BattleModel = preload("res://scripts/battle/battle_model.gd")
const SCHEMA_VERSION := 2
const SAVE_FORMAT := "imperathen-offline-save"
const MAX_SAVE_BYTES := 2097152
const MAX_COMMAND_IDS := 1024
const MAX_CHRONICLE := 256
const YEAR_SECONDS := 31536000.0
const HUT_COST := 8
const HUT_SECONDS := 12.0
const INTERACTION_RANGE := 3.0
const WORK_RANGE := 4.5
const ENEMY_RANGE := 2.3
const ATTACK_COOLDOWN := 0.6
const DAMAGE_COOLDOWN := 1.25
const STAGES := ["prologue", "settlement", "training", "trained", "skirmish", "aftermath", "ended", "fallen"]
const NODE_POSITIONS := [[-8.0, 2.0], [-11.0, -3.0], [-5.0, -7.0]]
const ENEMY_POSITIONS := [[6.0, -10.0], [10.0, -11.0], [14.0, -10.0]]
const COMMAND_FIELDS := {
	"gather": ["node_id"], "choose_companion": ["choice"], "build": ["x", "z"],
	"train": [], "training_hit": [], "recruit": [], "start_skirmish": [],
	"strike_enemy": ["enemy_id"], "receive_damage": ["amount"],
	"resolve_skirmish": [], "choose_story": ["choice"]
}

var data: Dictionary = {}


func _init() -> void:
	new_game()


func new_game() -> void:
	data = {
		"schema_version": SCHEMA_VERSION,
		"world_id": "%s-%s" % [Time.get_ticks_usec(), randi()],
		"revision": 0, "world_seconds": 0.0,
		"resources": {"wood": 0, "grain": 12, "denarii": 30},
		"player": {"position": [0.0, 1.0, 8.0], "health": 100, "age": 12, "role": "child"},
		"companion": {"id": "marcus", "met": false, "choice": "", "trust": 0, "age": 12},
		"progress": {"stage": "prologue", "training_hits": 0, "training_complete": false,
			"skirmish_won": false, "years_elapsed": 0, "chapter_complete": false, "career_terminal": false},
		"buildings": [], "resource_nodes": [],
		"squad": {"recruits": 0, "alive": 0, "morale": 60},
		"population": {"total": 4, "workers": 4, "soldiers": 0, "dead": 0},
		"encounter": {"started": false, "active": false, "resolved": false, "damage_taken": 0, "enemies": []},
		"timers": {"training": 0.0, "strike": 0.0, "damage": 0.0},
		"chronicle": [{"time": 0.0, "text": "Du erreichst die Grenzsiedlung. Ein geliehenes Werkzeug und eine erlaubte Baufläche sind dein Anfang."}],
		"story": {"title": "Ein Anfang am Fluss", "text": "Sammle Holz, sprich mit Marcus und baue deine erste Unterkunft östlich des Weges.", "choices": [], "choice": ""},
		"valley": {}, "command_log": {}
	}
	for index in NODE_POSITIONS.size():
		data.resource_nodes.append({"id": "timber_%d" % index, "x": NODE_POSITIONS[index][0], "z": NODE_POSITIONS[index][1], "amount": 16})
	changed.emit()


func execute(command: String, args: Dictionary = {}, command_id: String = "") -> Dictionary:
	if not COMMAND_FIELDS.has(command):
		return _fail("Unbekannter Spielbefehl: %s" % command)
	if not _exact_keys(args, COMMAND_FIELDS[command]):
		return _fail("Der Befehl enthält fehlende oder unerlaubte Angaben.")
	if command_id.length() > 96:
		return _fail("Die Befehlskennung ist zu lang.")
	var argument_error := _validate_arguments(command, args)
	if not argument_error.is_empty():
		return _fail(argument_error)
	var state_error := _validate_state(data)
	if not state_error.is_empty():
		return _fail("Ungültiger Weltzustand; keine Änderung: " + state_error)
	var fingerprint := JSON.stringify([command, args]).sha256_text()
	if not command_id.is_empty() and data.command_log.has(command_id):
		var previous: Dictionary = data.command_log[command_id]
		if previous.fingerprint != fingerprint:
			return _fail("Diese Befehlskennung wurde bereits für einen anderen Inhalt verwendet.")
		return previous.result.duplicate(true)
	if not command_id.is_empty() and data.command_log.size() >= MAX_COMMAND_IDS:
		return _fail("Das Wiederholungsprotokoll ist voll; ein neuer Auftrag benötigt eine neue Spielwelt.")
	if data.progress.career_terminal:
		return _fail("Dieser Lebensbogen ist abgeschlossen. Ein neues Leben beginnt im Hauptmenü.")
	var candidate := _world_copy()
	var result := _apply_command(candidate, command, args)
	if not result.ok:
		return result
	candidate.revision = int(data.revision) + 1
	result["revision"] = candidate.revision
	if not command_id.is_empty():
		candidate.command_log[command_id] = {"fingerprint": fingerprint, "result": result.duplicate(true)}
	state_error = _validate_state(candidate)
	if not state_error.is_empty():
		return _fail("Der Vorgang wurde vollständig verworfen: " + state_error)
	data = candidate
	changed.emit()
	return result


func set_player_position(position: Vector3) -> void:
	var values := [position.x, position.y, position.z]
	if not _valid_position(values) or data.is_empty() or data.progress.career_terminal:
		return
	var old: Array = data.player.position
	if old == values:
		return
	data.player.position = values
	data.revision = int(data.revision) + 1
	# The renderer already owns this observed movement. Avoid rebuilding UI per step.


func advance(delta: float) -> void:
	if not is_finite(delta) or delta <= 0.0 or delta > 3600.0 or data.is_empty():
		return
	if data.progress.career_terminal:
		return
	if float(data.world_seconds) + delta > 1000000000000.0:
		return
	var candidate := _world_copy()
	var notify_ui := int(candidate.world_seconds) != int(float(candidate.world_seconds) + delta)
	candidate.world_seconds = float(candidate.world_seconds) + delta
	for key in candidate.timers:
		candidate.timers[key] = maxf(0.0, float(candidate.timers[key]) - delta)
	# One player supplies one work budget, even when two work sites are nearby.
	var work_budget := delta
	while work_budget > 0.000001:
		var index := _nearest_unfinished_hut(candidate)
		if index < 0:
			break
		var hut: Dictionary = candidate.buildings[index]
		var needed := (1.0 - float(hut.progress)) * HUT_SECONDS
		var applied := minf(needed, work_budget)
		hut.progress = minf(1.0, float(hut.progress) + applied / HUT_SECONDS)
		work_budget -= applied
		notify_ui = true
		if float(hut.progress) >= 1.0 - 0.000001:
			hut.progress = 1.0
			hut.completed = true
			_record(candidate, "Die Unterkunft %s ist fertig. Ihr Bau hat tatsächlich Material und Arbeit verbraucht." % hut.id)
			if candidate.progress.stage == "prologue":
				candidate.progress.stage = "settlement"
				_set_story(candidate, "Ein Dach über dem Kopf", "Deine Hütte steht. Triff Marcus und suche danach den Ausbilder am Übungsplatz auf.")
		else:
			break
	candidate.revision = int(data.revision) + 1
	data = candidate
	if notify_ui:
		changed.emit()


## Regional troops are a separate contingent from the village recruits.
## Only the live rules object publishes a checkpoint. Counters derive from its roster.
func checkpoint_valley(battle) -> bool:
	if not data.progress.skirmish_won or data.progress.career_terminal:
		return false
	var previous: Dictionary = data.valley
	var summary: Dictionary = battle.summary()
	var previous_steps := int(previous.get("snapshot", {}).get("steps", 0))
	if battle.steps < previous_steps or previous.get("outcome","ongoing") != "ongoing":
		return false
	data.world_seconds += (battle.steps - previous_steps) * BattleModel.STEP
	data.valley = {"snapshot":battle.snapshot(), "outcome":battle.outcome,
		"allied_losses":summary.ally.losses, "enemy_losses":summary.enemy.losses}
	if battle.outcome != "ongoing":
		var result: String = {"victory":"Die Grenzlegion hält die Talstraße.", "defeat":"Der Höhenbund kontrolliert die Talstraße.", "draw":"Die Talstraße bleibt umkämpft."}[battle.outcome]
		_record(data, "%s Ausfälle: Legion %d, Höhenbund %d." % [result,summary.ally.losses,summary.enemy.losses])
	data.revision += 1
	changed.emit()
	return true


func _valid_valley(state: Dictionary) -> bool:
	if typeof(state.valley) != TYPE_DICTIONARY:
		return false
	if state.valley.is_empty():
		return true
	var valley: Dictionary = state.valley
	if not state.progress.skirmish_won or not _exact_keys(valley, ["snapshot","outcome","allied_losses","enemy_losses"]):
		return false
	var battle = BattleModel.new()
	if typeof(valley.snapshot) != TYPE_DICTIONARY or not battle.restore(valley.snapshot):
		return false
	var summary: Dictionary = battle.summary()
	return valley.outcome == summary.outcome and valley.allied_losses == summary.ally.losses and valley.enemy_losses == summary.enemy.losses


func save_game(path: String) -> Dictionary:
	var absolute := _save_path(path)
	if absolute.is_empty():
		return _fail("Speichern benötigt einen Benutzerpfad oder absoluten Dateipfad außerhalb der Projektressourcen.")
	var state_error := _validate_state(data)
	if not state_error.is_empty():
		return _fail("Der Spielstand wurde nicht gespeichert: " + state_error)
	var directory_error := DirAccess.make_dir_recursive_absolute(absolute.get_base_dir())
	if directory_error != OK:
		return _fail("Der Speicherordner kann nicht angelegt werden (Fehler %d)." % directory_error)
	var payload := JSON.stringify(data)
	var envelope := JSON.stringify({"format": SAVE_FORMAT, "format_version": 1, "payload": payload, "sha256": payload.sha256_text()})
	if envelope.to_utf8_buffer().size() > MAX_SAVE_BYTES:
		return _fail("Der Spielstand überschreitet die erlaubte Dateigröße.")
	var temporary := absolute + ".tmp"
	var backup := absolute + ".bak"
	var backup_temporary := backup + ".tmp"
	var written := _write_file(temporary, envelope)
	if not written.ok:
		return written
	var verified := _read_save(temporary)
	if not verified.ok:
		_remove_if_present(temporary)
		return _fail("Die neue Speicherdatei konnte nicht verifiziert werden.")
	# Preserve the previous *valid* main file. Never overwrite a good backup with corruption.
	var old_main := _read_save(absolute)
	var old_backup := _read_save(backup)
	var backup_text := ""
	if old_main.ok:
		backup_text = old_main.envelope
	elif not old_backup.ok:
		backup_text = envelope
	if not backup_text.is_empty():
		written = _write_file(backup_temporary, backup_text)
		if not written.ok or not _read_save(backup_temporary).ok:
			_remove_if_present(temporary)
			_remove_if_present(backup_temporary)
			return _fail("Die Sicherung konnte nicht geschrieben werden; der bisherige Spielstand bleibt erhalten.")
		var backup_error := DirAccess.rename_absolute(backup_temporary, backup)
		if backup_error != OK:
			_remove_if_present(temporary)
			_remove_if_present(backup_temporary)
			return _fail("Die Sicherung konnte nicht übernommen werden (Fehler %d)." % backup_error)
	# Same-directory replacement: readers see a complete old or new main file.
	var rename_error := DirAccess.rename_absolute(temporary, absolute)
	if rename_error != OK:
		_remove_if_present(temporary)
		return _fail("Die Speicherdatei konnte nicht übernommen werden (Fehler %d)." % rename_error)
	return _ok("Spiel gespeichert. Eine geprüfte Sicherung des letzten Speichervorgangs liegt bereit.")


func load_game(path: String) -> Dictionary:
	var absolute := _save_path(path)
	if absolute.is_empty():
		return _fail("Ungültiger Speicherpfad.")
	var loaded := _read_save(absolute)
	var recovered := false
	var primary_error: String = loaded.message
	if not loaded.ok:
		loaded = _read_save(absolute + ".bak")
		recovered = loaded.ok
	if not loaded.ok:
		return _fail("Kein gültiger Spielstand geladen. Hauptdatei: %s Sicherung: %s" % [primary_error, loaded.message])
	# Validate the entire candidate before touching the active world.
	data = loaded.state.duplicate(true)
	changed.emit()
	var result := _ok("Geprüfte Sicherung geladen; die Hauptdatei war nicht nutzbar." if recovered else "Spielstand geladen.")
	result["recovered_backup"] = recovered
	return result


func _apply_command(state: Dictionary, command: String, args: Dictionary) -> Dictionary:
	match command:
		"gather":
			var index := _find_id(state.resource_nodes, args.node_id)
			if index < 0:
				return _fail("Diese Holzstelle gibt es nicht.")
			var node: Dictionary = state.resource_nodes[index]
			if _distance_to(state, float(node.x), float(node.z)) > INTERACTION_RANGE:
				return _fail("Gehe näher an die Holzstelle heran (höchstens 3 Meter).")
			if int(node.amount) < 4:
				return _fail("Diese Holzstelle ist erschöpft. Suche eine andere.")
			node.amount = int(node.amount) - 4
			state.resources.wood = int(state.resources.wood) + 4
			_record(state, "Du sammelst vier Holz an %s." % node.id)
			return _ok("4 Holz gesammelt.")
		"choose_companion":
			if state.companion.met:
				return _fail("Diese Begegnung ist bereits entschieden.")
			if _distance_to(state, -3.0, 4.0) > INTERACTION_RANGE:
				return _fail("Gehe zu Marcus, um mit ihm zu sprechen.")
			if args.choice == "help" and int(state.resources.wood) < 4:
				return _fail("Zum Teilen benötigst du 4 Holz.")
			state.companion.met = true
			state.companion.choice = args.choice
			if args.choice == "help":
				state.resources.wood = int(state.resources.wood) - 4
				state.companion.trust = 20
				_record(state, "Du teilst vier Holz mit Marcus. Er merkt sich deine Hilfe.")
				return _ok("Marcus nimmt deine Hilfe an. Vertrauen +20.")
			state.companion.trust = -5
			_record(state, "Du behältst dein Holz. Marcus sucht seinen eigenen Weg.")
			return _ok("Du lehnst ab. Marcus merkt sich deine Entscheidung.")
		"build":
			var x := float(args.x)
			var z := float(args.z)
			if not _inside_plot(x, z):
				return _fail("Hier besteht kein Baurecht. Die freie Fläche liegt östlich des Weges.")
			if state.buildings.size() >= 16:
				return _fail("Die Baugrenze dieses kleinen Dorfabschnitts ist erreicht.")
			for hut in state.buildings:
				if Vector2(x, z).distance_to(Vector2(hut.x, hut.z)) < 5.0:
					return _fail("Halte mindestens 5 Meter Abstand zur nächsten Unterkunft.")
			if int(state.resources.wood) < HUT_COST:
				return _fail("Eine Unterkunft benötigt 8 Holz.")
			state.resources.wood = int(state.resources.wood) - HUT_COST
			state.buildings.append({"id": "hut_%d" % (state.buildings.size() + 1), "x": x, "z": z, "progress": 0.0, "completed": false})
			_record(state, "Du setzt einen Bauauftrag und verbrauchst acht Holz. Die Arbeit beginnt erst bei deiner Anwesenheit.")
			return _ok("Bauauftrag gesetzt. Bleibe für die Arbeit höchstens 4,5 Meter entfernt.")
		"train":
			if state.player.age >= 18:
				return _fail("Du befindest dich bereits im erwachsenen Ausbildungsabschnitt.")
			if not state.companion.met or not _has_completed_hut(state):
				return _fail("Baue zuerst eine Unterkunft fertig und entscheide die Begegnung mit Marcus.")
			for hut in state.buildings:
				if not hut.completed:
					return _fail("Beende deine offenen Baustellen vor dem Übergang in die nächsten Jahre.")
			if _distance_to(state, 0.0, -7.0) > INTERACTION_RANGE:
				return _fail("Der Ausbilder wartet am Übungsplatz nördlich des Dorfes.")
			state.world_seconds = float(state.world_seconds) + 6.0 * YEAR_SECONDS
			state.player.age = 18
			state.player.role = "trainee"
			state.companion.age = 18
			state.progress.years_elapsed = 6
			state.progress.stage = "training"
			_record(state, "Sechs Jahre später: Du und Marcus sind erwachsen. Deine Unterkunft und deine frühere Entscheidung bleiben Teil dieser Welt.")
			_set_story(state, "Sechs Jahre später", "Du bist jetzt 18. Übe am Ziel drei kontrollierte Treffer. Abstand und Erholung zählen.")
			return _ok("Sechs Jahre später: Die erwachsene Ausbildung beginnt.")
		"training_hit":
			if state.progress.stage != "training":
				return _fail("Beginne zuerst die Ausbildung beim Übungsplatz.")
			if _distance_to(state, 0.0, -7.0) > INTERACTION_RANGE:
				return _fail("Das Übungsziel liegt außerhalb deiner Reichweite.")
			if float(state.timers.training) > 0.000001:
				return _fail("Lass den Übungsschlag erst ausklingen.")
			state.timers.training = ATTACK_COOLDOWN
			state.progress.training_hits = int(state.progress.training_hits) + 1
			if int(state.progress.training_hits) == 3:
				state.progress.training_complete = true
				state.progress.stage = "trained"
				state.player.role = "soldier"
				_record(state, "Du beendest die erste Waffenübung. Als ausgebildeter Soldat darfst du einen kleinen Wachtrupp anwerben.")
				_set_story(state, "Eine erste Verantwortung", "Wirb bis zu drei Freiwillige an. Jeder kostet 5 Denarii und 2 Getreide und fehlt anschließend als zivile Arbeitskraft.")
				return _ok("Ausbildung abgeschlossen. Du darfst einen kleinen Trupp anwerben.")
			return _ok("Gültiger Übungstreffer %d/3." % int(state.progress.training_hits))
		"recruit":
			if not state.progress.training_complete:
				return _fail("Beende zuerst die erwachsene Ausbildung.")
			if state.encounter.started:
				return _fail("Die Besetzung dieses Gefechts ist bereits festgelegt.")
			if int(state.squad.recruits) >= 3:
				return _fail("Dieser Wachtrupp umfasst höchstens drei Freiwillige.")
			if int(state.resources.denarii) < 5 or int(state.resources.grain) < 2:
				return _fail("Ein Freiwilliger benötigt 5 Denarii und 2 Getreide.")
			state.resources.denarii = int(state.resources.denarii) - 5
			state.resources.grain = int(state.resources.grain) - 2
			state.squad.recruits = int(state.squad.recruits) + 1
			state.squad.alive = int(state.squad.alive) + 1
			state.population.workers = int(state.population.workers) - 1
			state.population.soldiers = int(state.population.soldiers) + 1
			_update_morale(state)
			_record(state, "Ein Freiwilliger wechselt aus der Dorfarbeit in deinen Wachtrupp.")
			return _ok("Ein Freiwilliger angeworben. 5 Denarii und 2 Getreide verbraucht.")
		"start_skirmish":
			if not state.progress.training_complete or int(state.squad.alive) < 1:
				return _fail("Du brauchst eine abgeschlossene Ausbildung und mindestens einen Freiwilligen.")
			if state.encounter.started:
				return _fail("Dieses Gefecht wurde bereits begonnen.")
			state.encounter.started = true
			state.encounter.active = true
			state.progress.stage = "skirmish"
			for index in ENEMY_POSITIONS.size():
				state.encounter.enemies.append({"id": "enemy_%d" % index, "x": ENEMY_POSITIONS[index][0], "z": ENEMY_POSITIONS[index][1], "health": 60})
			_record(state, "Drei Bewaffnete bedrohen den nördlichen Zugang. Dein Wachtrupp tritt mit dir an.")
			_set_story(state, "Der nördliche Zugang", "Nähere dich den Angreifern. Deine Reichweite beträgt 3 Meter; Treffer auf große Distanz zählen nicht. Verluste bleiben gespeichert.")
			return _ok("Das kleine Gefecht hat begonnen. Die Gegner stehen nördlich des Dorfes.")
		"strike_enemy":
			if not state.encounter.active:
				return _fail("Es läuft kein Gefecht.")
			var index := _find_id(state.encounter.enemies, args.enemy_id)
			if index < 0:
				return _fail("Dieser Gegner gehört nicht zum Gefecht.")
			var enemy: Dictionary = state.encounter.enemies[index]
			if int(enemy.health) <= 0:
				return _fail("Dieser Gegner ist bereits ausgeschaltet.")
			if _distance_to(state, float(enemy.x), float(enemy.z)) > INTERACTION_RANGE:
				return _fail("Der Schlag verfehlt: Der Gegner ist weiter als 3 Meter entfernt.")
			if float(state.timers.strike) > 0.000001:
				return _fail("Der vorherige Angriff ist noch nicht beendet.")
			state.timers.strike = ATTACK_COOLDOWN
			var damage := 26 + 2 * int(state.squad.alive)
			enemy.health = maxi(0, int(enemy.health) - damage)
			if int(enemy.health) == 0:
				_record(state, "Der Gegner %s ist ausgeschaltet; sein Zustand bleibt in der Chronik des Gefechts erhalten." % enemy.id)
			if _all_enemies_defeated(state):
				return _resolve_skirmish(state)
			return _ok("Treffer: %d Schaden. Verbleibende Gegnergesundheit: %d." % [damage, int(enemy.health)])
		"receive_damage":
			if not state.encounter.active:
				return _fail("Außerhalb eines Gefechts wird kein Kampfschaden gebucht.")
			if not _enemy_in_range(state, ENEMY_RANGE):
				return _fail("Kein lebender Gegner ist nah genug für diesen Treffer.")
			if float(state.timers.damage) > 0.000001:
				return _fail("Dieser gegnerische Angriff wurde bereits berücksichtigt.")
			state.timers.damage = DAMAGE_COOLDOWN
			var actual := mini(int(args.amount), int(state.player.health))
			state.player.health = int(state.player.health) - actual
			state.encounter.damage_taken = int(state.encounter.damage_taken) + actual
			var expected_dead := mini(int(state.squad.recruits), int(state.encounter.damage_taken) / 32)
			var newly_dead := expected_dead - int(state.population.dead)
			if newly_dead > 0:
				state.population.dead = expected_dead
				state.population.soldiers = int(state.population.soldiers) - newly_dead
				state.squad.alive = int(state.squad.alive) - newly_dead
				_record(state, "Unter dem anhaltenden gegnerischen Druck fällt ein Freiwilliger. Er kehrt nicht durch einen Kamerwechsel zurück.")
			_update_morale(state)
			if int(state.player.health) == 0:
				state.encounter.active = false
				state.progress.stage = "fallen"
				state.progress.career_terminal = true
				_record(state, "Du fällst im Gefecht. Dieser Lebensbogen endet; ein neues Leben ist im Hauptmenü möglich.")
				_set_story(state, "Ein Leben endet", "Du bist im Gefecht gefallen. Die Verluste und Entscheidungen dieses Lebens bleiben gespeichert. Beginne im Hauptmenü ein neues Leben.")
				return _ok("Du bist gefallen. Dieses Leben ist abgeschlossen.")
			return _ok("Du erleidest %d Schaden." % actual)
		"resolve_skirmish":
			return _resolve_skirmish(state)
		"choose_story":
			if not state.progress.skirmish_won or state.progress.stage != "aftermath":
				return _fail("Diese Folgeentscheidung ist noch nicht verfügbar oder bereits getroffen.")
			state.story.choice = args.choice
			state.story.choices = []
			state.progress.chapter_complete = true
			state.progress.stage = "ended"
			if args.choice == "protect":
				state.resources.grain = int(state.resources.grain) + 4
				state.companion.trust = int(state.companion.trust) + 5
				state.story.title = "Hüter der Siedlung"
				state.story.text = "Du sicherst Vorräte und schützt das Dorf. " + ("Marcus erinnert sich an deine frühere Hilfe und steht dir bei." if state.companion.choice == "help" else "Marcus bleibt vorsichtig, erkennt aber deinen Schutz der Siedlung an.") + " Dieser erste spielbare Abschnitt ist abgeschlossen. Bauen und Erkundung bleiben möglich."
				_record(state, "Du wählst den Schutz der Siedlung. Vier Getreide werden aus der gesicherten Lieferung eingebucht; Marcus' Vertrauen steigt.")
			else:
				state.resources.denarii = int(state.resources.denarii) + 12
				state.companion.trust = int(state.companion.trust) - 5
				state.story.title = "Der Blick nach Norden"
				state.story.text = "Du verfolgst die Spur der Angreifer und sicherst zwölf Denarii. " + ("Marcus unterstützt dich, warnt aber vor den Risiken weiterer Feldzüge." if state.companion.choice == "help" else "Marcus verfolgt eigene Pläne. Eure unterschiedlichen Interessen zeichnen sich deutlicher ab.") + " Dieser erste spielbare Abschnitt ist abgeschlossen. Ein Kaisertitel ist damit nicht verbunden."
				_record(state, "Du wählst die Verfolgung. Zwölf Denarii werden einmalig gebucht; Marcus beurteilt deinen Ehrgeiz kritisch.")
			return _ok("Deine Entscheidung und ihre Folgen wurden dauerhaft im Weltzustand festgehalten.")
	return _fail("Befehl nicht unterstützt.")


func _resolve_skirmish(state: Dictionary) -> Dictionary:
	if state.encounter.resolved:
		return _fail("Dieses Gefecht wurde bereits abgerechnet.")
	if not state.encounter.active or not _all_enemies_defeated(state) or int(state.player.health) <= 0:
		return _fail("Das Gefecht ist noch nicht gewonnen; alle Gegner müssen tatsächlich ausgeschaltet sein.")
	state.encounter.active = false
	state.encounter.resolved = true
	state.progress.skirmish_won = true
	state.progress.stage = "aftermath"
	state.resources.denarii = int(state.resources.denarii) + 15
	state.resources.grain = int(state.resources.grain) + 4
	_update_morale(state)
	_record(state, "Der Zugang ist gesichert. Die Siedlung stellt einmalig fünfzehn Denarii und vier Getreide bereit. Gefallene bleiben gefallen.")
	_set_story(state, "Nach dem Gefecht", ("Marcus vertraut dir nach eurer gemeinsamen Vorgeschichte." if state.companion.choice == "help" else "Marcus hat deine frühere Ablehnung nicht vergessen.") + " Sicherst du das Dorf oder verfolgst du die Spur nach Norden?")
	state.story.choices = [{"id": "protect", "label": "Die Siedlung schützen"}, {"id": "pursue", "label": "Die Spur nach Norden verfolgen"}]
	return _ok("Gefecht gewonnen. 15 Denarii und 4 Getreide erhalten. Entscheide, wie dein Weg weitergeht.")


func _validate_arguments(command: String, args: Dictionary) -> String:
	if command in ["gather", "strike_enemy"]:
		var key := "node_id" if command == "gather" else "enemy_id"
		if not _text(args[key], 1, 64):
			return "Eine gültige Zielkennung fehlt."
	elif command == "choose_companion":
		if not _text(args.choice, 1, 16) or args.choice not in ["help", "decline"]:
			return "Wähle Hilfe oder Ablehnung."
	elif command == "choose_story":
		if not _text(args.choice, 1, 16) or args.choice not in ["protect", "pursue"]:
			return "Diese Geschichtenoption ist nicht erlaubt."
	elif command == "build":
		if not _number(args.x, -1000.0, 1000.0) or not _number(args.z, -1000.0, 1000.0):
			return "Der Bauplatz enthält ungültige Koordinaten."
	elif command == "receive_damage":
		if not _integer(args.amount, 1, 8):
			return "Schaden muss eine ganze Zahl zwischen 1 und 8 sein."
	return ""


func _validate_state(state: Variant) -> String:
	if not _exact_keys(state, ["schema_version", "world_id", "revision", "world_seconds", "resources", "player", "companion", "progress", "buildings", "resource_nodes", "squad", "population", "encounter", "timers", "chronicle", "story", "command_log", "valley"]):
		return "Unvollständiger oder unbekannter Datenvertrag."
	if not _integer(state.schema_version, SCHEMA_VERSION, SCHEMA_VERSION):
		return "Diese Schemaversion wird nicht unterstützt; es wurde keine Migration ausgeführt."
	if not _text(state.world_id, 1, 100) or not _integer(state.revision, 0, 9007199254740990) or not _number(state.world_seconds, 0.0, 1000000000000.0):
		return "Ungültige Weltkennung, Revision oder Zeit."
	if not _exact_keys(state.resources, ["wood", "grain", "denarii"]):
		return "Ungültiger Güterbestand."
	for key in state.resources:
		if not _integer(state.resources[key], 0, 1000000):
			return "Güter müssen endliche nichtnegative ganze Mengen sein."
	if not _exact_keys(state.player, ["position", "health", "age", "role"]):
		return "Ungültige Spielerfigur."
	if not _valid_position(state.player.position) or not _integer(state.player.health, 0, 100) or not _integer(state.player.age, 12, 18) or not _text(state.player.role, 1, 20):
		return "Ungültiger Ort, Gesundheit, Alter oder Rolle."
	if not _exact_keys(state.companion, ["id", "met", "choice", "trust", "age"]):
		return "Ungültiger Gefährtenzustand."
	var companion: Dictionary = state.companion
	if companion.id != "marcus" or typeof(companion.met) != TYPE_BOOL or not _text(companion.choice, 0, 16) or companion.choice not in ["", "help", "decline"]:
		return "Ungültige Gefährtenidentität oder Auswahl."
	if companion.met != (companion.choice != "") or not _integer(companion.trust, -100, 100) or not _integer(companion.age, 12, 18) or companion.age != state.player.age:
		return "Gefährtenentscheidung, Vertrauen oder Alter widersprechen sich."
	if not _exact_keys(state.progress, ["stage", "training_hits", "training_complete", "skirmish_won", "years_elapsed", "chapter_complete", "career_terminal"]):
		return "Ungültiger Kapitelzustand."
	var progress: Dictionary = state.progress
	if not _text(progress.stage, 1, 32) or progress.stage not in STAGES or not _integer(progress.training_hits, 0, 3) or not _integer(progress.years_elapsed, 0, 6):
		return "Unbekannte Spielphase oder Ausbildung."
	for key in ["training_complete", "skirmish_won", "chapter_complete", "career_terminal"]:
		if typeof(progress[key]) != TYPE_BOOL:
			return "Kapitelmerkmale müssen Wahrheitswerte sein."
	var adult: bool = progress.stage not in ["prologue", "settlement"]
	if state.player.age != (18 if adult else 12) or progress.years_elapsed != (6 if adult else 0):
		return "Alterssprung und Weltphase widersprechen sich."
	if float(state.world_seconds) < float(progress.years_elapsed) * YEAR_SECONDS:
		return "Der Alterssprung fehlt in der gemeinsamen Weltzeit."
	var expected_role := "child" if not adult else ("trainee" if progress.stage == "training" else "soldier")
	if state.player.role != expected_role:
		return "Die Rolle passt nicht zur Ausbildung."
	if progress.training_complete != (int(progress.training_hits) == 3) or progress.training_complete != (progress.stage in ["trained", "skirmish", "aftermath", "ended", "fallen"]):
		return "Ausbildung und Phase widersprechen sich."
	if (not adult and int(progress.training_hits) != 0) or (progress.career_terminal != (progress.stage == "fallen")) or (progress.chapter_complete != (progress.stage == "ended")):
		return "Unzulässiger Ausbildungs- oder Abschlusszustand."
	if (int(state.player.health) == 0) != progress.career_terminal:
		return "Tod und terminaler Zustand widersprechen sich."
	if typeof(state.buildings) != TYPE_ARRAY or state.buildings.size() > 16:
		return "Ungültige Gebäudeliste."
	var completed_count := 0
	for index in state.buildings.size():
		var hut: Variant = state.buildings[index]
		if not _exact_keys(hut, ["id", "x", "z", "progress", "completed"]):
			return "Ungültiger Gebäudedatensatz."
		if hut.id != "hut_%d" % (index + 1) or not _number(hut.x, 5.0, 24.0) or not _number(hut.z, -4.0, 13.0) or not _number(hut.progress, 0.0, 1.0) or typeof(hut.completed) != TYPE_BOOL:
			return "Ungültige Gebäudeidentität, Lage oder Baustufe."
		if hut.completed != (float(hut.progress) == 1.0):
			return "Fertigmeldung und Baufortschritt widersprechen sich."
		if hut.completed:
			completed_count += 1
		for other_index in index:
			var other: Dictionary = state.buildings[other_index]
			if Vector2(hut.x, hut.z).distance_to(Vector2(other.x, other.z)) < 4.99999:
				return "Gebäude überschneiden den erforderlichen Abstand."
	if (adult or progress.stage == "settlement") and completed_count == 0:
		return "Der erforderliche fertige Wohnplatz fehlt."
	if adult and not companion.met:
		return "Der erwachsene Abschnitt überspringt die Gefährtenentscheidung."
	if progress.stage == "prologue" and completed_count > 0:
		return "Fertige Unterkunft und Einstiegsphase widersprechen sich."
	if typeof(state.resource_nodes) != TYPE_ARRAY or state.resource_nodes.size() != 3:
		return "Ungültige Rohstoffstellen."
	var remaining_wood := 0
	for index in 3:
		var node: Variant = state.resource_nodes[index]
		if not _exact_keys(node, ["id", "x", "z", "amount"]):
			return "Ungültige Holzstelle."
		if node.id != "timber_%d" % index or not _number(node.x, -100.0, 100.0) or not _number(node.z, -100.0, 100.0) or node.x != NODE_POSITIONS[index][0] or node.z != NODE_POSITIONS[index][1] or not _integer(node.amount, 0, 16):
			return "Rohstoffidentität, Ort oder Vorrat ist ungültig."
		if int(node.amount) % 4 != 0:
			return "Der Holzbestand passt nicht zu den Sammelvorgängen."
		remaining_wood += int(node.amount)
	if not _exact_keys(state.squad, ["recruits", "alive", "morale"]) or not _integer(state.squad.recruits, 0, 3) or not _integer(state.squad.alive, 0, 3) or not _integer(state.squad.morale, 0, 100):
		return "Ungültiger Wachtrupp."
	if int(state.squad.alive) > int(state.squad.recruits) or (int(state.squad.recruits) > 0 and not progress.training_complete):
		return "Truppenstärke oder Befehlsrecht widersprechen sich."
	if not _exact_keys(state.population, ["total", "workers", "soldiers", "dead"]):
		return "Ungültige Personalbilanz."
	for key in state.population:
		if not _integer(state.population[key], 0, 4):
			return "Personal muss aus ganzen nichtnegativen Mengen bestehen."
	var dead := int(state.squad.recruits) - int(state.squad.alive)
	if state.population.total != 4 or state.population.workers != 4 - int(state.squad.recruits) or state.population.soldiers != state.squad.alive or state.population.dead != dead:
		return "Arbeiter, Soldaten und Gefallene sind nicht bilanziert."
	if not _exact_keys(state.encounter, ["started", "active", "resolved", "damage_taken", "enemies"]):
		return "Ungültiger Gefechtszustand."
	var encounter: Dictionary = state.encounter
	for key in ["started", "active", "resolved"]:
		if typeof(encounter[key]) != TYPE_BOOL:
			return "Gefechtsmerkmale müssen Wahrheitswerte sein."
	if not _integer(encounter.damage_taken, 0, 100) or typeof(encounter.enemies) != TYPE_ARRAY:
		return "Ungültige Gegner- oder Schadensdaten."
	if encounter.enemies.size() != (3 if encounter.started else 0):
		return "Die Gegnerliste passt nicht zum begonnenen Gefecht."
	for index in encounter.enemies.size():
		var enemy: Variant = encounter.enemies[index]
		if not _exact_keys(enemy, ["id", "x", "z", "health"]):
			return "Ungültiger Gegnerdatensatz."
		if enemy.id != "enemy_%d" % index or not _number(enemy.x, -100.0, 100.0) or not _number(enemy.z, -100.0, 100.0) or enemy.x != ENEMY_POSITIONS[index][0] or enemy.z != ENEMY_POSITIONS[index][1] or not _integer(enemy.health, 0, 60):
			return "Unbekannter Gegner, Ort oder Gesundheitswert."
	if encounter.active != (progress.stage == "skirmish") or encounter.resolved != progress.skirmish_won or progress.skirmish_won != (progress.stage in ["aftermath", "ended"]):
		return "Gefecht, Sieg und Kapitel widersprechen sich."
	if encounter.started != (progress.stage in ["skirmish", "aftermath", "ended", "fallen"]):
		return "Gefechtsbeginn und Spielphase widersprechen sich."
	if encounter.started and int(state.squad.recruits) == 0:
		return "Das Gefecht benötigt einen tatsächlich angeworbenen Trupp."
	if encounter.resolved != _all_enemies_defeated(state):
		return "Der Sieg ist nicht durch tatsächliche Gegnerzustände belegt."
	if int(encounter.damage_taken) != 100 - int(state.player.health) or dead != mini(int(state.squad.recruits), int(encounter.damage_taken) / 32):
		return "Schaden, Gesundheit und Verluste widersprechen sich."
	var expected_morale := mini(100, 60 + 5 * int(state.squad.recruits) - 15 * dead + (10 if progress.skirmish_won else 0))
	if int(state.squad.morale) != expected_morale:
		return "Die Moral passt nicht zu den bestätigten Ereignissen."
	if not _exact_keys(state.timers, ["training", "strike", "damage"]) or not _number(state.timers.training, 0.0, ATTACK_COOLDOWN) or not _number(state.timers.strike, 0.0, ATTACK_COOLDOWN) or not _number(state.timers.damage, 0.0, DAMAGE_COOLDOWN):
		return "Ungültige Angriffs- oder Erholungszeiten."
	if not _exact_keys(state.story, ["title", "text", "choices", "choice"]) or not _text(state.story.title, 1, 160) or not _text(state.story.text, 1, 4000) or not _text(state.story.choice, 0, 16) or typeof(state.story.choices) != TYPE_ARRAY:
		return "Ungültige Geschichtenstruktur."
	if state.story.choice not in ["", "protect", "pursue"] or (state.story.choice != "") != progress.chapter_complete:
		return "Folgeentscheidung und Kapitelabschluss widersprechen sich."
	if state.story.choices.size() != (2 if progress.stage == "aftermath" else 0):
		return "Die verfügbaren Optionen passen nicht zum Spielstand."
	for index in state.story.choices.size():
		var choice: Variant = state.story.choices[index]
		if not _exact_keys(choice, ["id", "label"]) or choice.id != ["protect", "pursue"][index] or not _text(choice.label, 1, 160):
			return "Ungültige Geschichtenoption."
	var help_cost := 4 if companion.choice == "help" else 0
	if int(state.resources.wood) + HUT_COST * state.buildings.size() + help_cost != 48 - remaining_wood:
		return "Die Holzbilanz wurde verletzt."
	var expected_grain := 12 - 2 * int(state.squad.recruits) + (4 if progress.skirmish_won else 0) + (4 if state.story.choice == "protect" else 0)
	var expected_money := 30 - 5 * int(state.squad.recruits) + (15 if progress.skirmish_won else 0) + (12 if state.story.choice == "pursue" else 0)
	if state.resources.grain != expected_grain or state.resources.denarii != expected_money:
		return "Die Versorgungs- oder Geldbilanz wurde verletzt."
	var expected_trust := (20 if companion.choice == "help" else (-5 if companion.choice == "decline" else 0)) + (5 if state.story.choice == "protect" else (-5 if state.story.choice == "pursue" else 0))
	if int(companion.trust) != expected_trust:
		return "Die Beziehung ist nicht durch gewählte Ereignisse belegt."
	if typeof(state.chronicle) != TYPE_ARRAY or state.chronicle.is_empty() or state.chronicle.size() > MAX_CHRONICLE:
		return "Ungültige Chronik."
	var previous_time := -1.0
	for event in state.chronicle:
		if not _exact_keys(event, ["time", "text"]) or not _number(event.time, 0.0, float(state.world_seconds)) or not _text(event.text, 1, 1200):
			return "Ungültiges Chronikereignis."
		if float(event.time) < previous_time:
			return "Die Chronik ist nicht zeitlich geordnet."
		previous_time = float(event.time)
	if typeof(state.command_log) != TYPE_DICTIONARY or state.command_log.size() > MAX_COMMAND_IDS:
		return "Ungültiges Wiederholungsprotokoll."
	for key in state.command_log:
		var entry: Variant = state.command_log[key]
		if not _text(key, 1, 96) or not _exact_keys(entry, ["fingerprint", "result"]) or not _text(entry.fingerprint, 64, 64):
			return "Ungültige Befehlskennung oder Prüfsumme."
		if not _exact_keys(entry.result, ["ok", "message", "revision"]) or typeof(entry.result.ok) != TYPE_BOOL or not entry.result.ok or not _text(entry.result.message, 1, 1200) or not _integer(entry.result.revision, 1, int(state.revision)):
			return "Ungültiger gespeicherter Befehlserfolg."
	return ""


func _read_save(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return _fail("Datei fehlt.")
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return _fail("Datei ist nicht lesbar.")
	var length := file.get_length()
	if length <= 0 or length > MAX_SAVE_BYTES:
		file.close()
		return _fail("Dateigröße ist ungültig.")
	var text := file.get_as_text()
	file.close()
	var parser := JSON.new()
	if parser.parse(text) != OK:
		return _fail("Speicherdatei ist kein gültiges JSON.")
	var envelope: Variant = parser.data
	if not _exact_keys(envelope, ["format", "format_version", "payload", "sha256"]):
		return _fail("Unbekanntes Speicherformat.")
	if envelope.format != SAVE_FORMAT or not _integer(envelope.format_version, 1, 1) or not _text(envelope.payload, 1, MAX_SAVE_BYTES) or not _text(envelope.sha256, 64, 64):
		return _fail("Formatversion oder Speicherinhalt ist ungültig.")
	if envelope.payload.sha256_text() != envelope.sha256:
		return _fail("Die Prüfsumme stimmt nicht; die Datei ist beschädigt.")
	var payload_parser := JSON.new()
	if payload_parser.parse(envelope.payload) != OK:
		return _fail("Der gespeicherte Weltzustand ist kein gültiges JSON.")
	var state: Variant = payload_parser.data
	if typeof(state) == TYPE_DICTIONARY and state.get("schema_version") == 1 and not state.has("valley"):
		state.schema_version = SCHEMA_VERSION
		state.valley = {}
	var error := _validate_state(state)
	if error.is_empty() and not _valid_valley(state):
		error = "Das gespeicherte Talgefecht enthält widersprüchliche Daten."
	if not error.is_empty():
		return _fail(error)
	# JSON numbers may arrive as floats. Restore schema-defined integer types only
	# after strict validation, including cached command results returned verbatim.
	_restore_integer_fields(payload_parser.data)
	return {"ok": true, "message": "Spielstand vollständig geprüft.", "state": payload_parser.data, "envelope": text}


func _restore_integer_fields(state: Dictionary) -> void:
	for key in ["schema_version", "revision"]:
		state[key] = int(state[key])
	for key in state.resources:
		state.resources[key] = int(state.resources[key])
	for key in ["health", "age"]:
		state.player[key] = int(state.player[key])
	for key in ["trust", "age"]:
		state.companion[key] = int(state.companion[key])
	for key in ["training_hits", "years_elapsed"]:
		state.progress[key] = int(state.progress[key])
	for key in state.squad:
		state.squad[key] = int(state.squad[key])
	for key in state.population:
		state.population[key] = int(state.population[key])
	state.encounter.damage_taken = int(state.encounter.damage_taken)
	for enemy in state.encounter.enemies:
		enemy.health = int(enemy.health)
	for node in state.resource_nodes:
		node.amount = int(node.amount)
	for key in state.command_log:
		state.command_log[key].result.revision = int(state.command_log[key].result.revision)


func _write_file(path: String, text: String) -> Dictionary:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return _fail("Datei konnte nicht zum Schreiben geöffnet werden (Fehler %d)." % FileAccess.get_open_error())
	var stored := file.store_string(text)
	file.flush()
	var error := file.get_error()
	file.close()
	if not stored or error != OK:
		_remove_if_present(path)
		return _fail("Schreiben der Speicherdatei ist fehlgeschlagen (Fehler %d)." % error)
	return _ok("Datei geschrieben.")


func _save_path(path: String) -> String:
	if path.is_empty() or path.begins_with("res://") or path.length() > 2048:
		return ""
	if not path.begins_with("user://") and not path.is_absolute_path():
		return ""
	return ProjectSettings.globalize_path(path)


func _remove_if_present(path: String) -> void:
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(path)


func _exact_keys(value: Variant, keys: Array) -> bool:
	if typeof(value) != TYPE_DICTIONARY or value.size() != keys.size():
		return false
	for key in keys:
		if not value.has(key):
			return false
	return true


func _number(value: Variant, low: float, high: float) -> bool:
	return typeof(value) in [TYPE_INT, TYPE_FLOAT] and is_finite(float(value)) and float(value) >= low and float(value) <= high


func _integer(value: Variant, low: int, high: int) -> bool:
	return _number(value, float(low), float(high)) and float(value) == floorf(float(value))


func _text(value: Variant, low: int, high: int) -> bool:
	return typeof(value) == TYPE_STRING and value.length() >= low and value.length() <= high


func _valid_position(value: Variant) -> bool:
	return typeof(value) == TYPE_ARRAY and value.size() == 3 and _number(value[0], -200.0, 200.0) and _number(value[1], -10.0, 50.0) and _number(value[2], -200.0, 200.0)


func _inside_plot(x: float, z: float) -> bool:
	return x >= 5.0 and x <= 24.0 and z >= -4.0 and z <= 13.0


func _distance_to(state: Dictionary, x: float, z: float) -> float:
	var position: Array = state.player.position
	return Vector3(position[0], position[1], position[2]).distance_to(Vector3(x, 1.0, z))


func _find_id(items: Array, target: String) -> int:
	for index in items.size():
		if items[index].id == target:
			return index
	return -1


func _nearest_unfinished_hut(state: Dictionary) -> int:
	var nearest := -1
	var best := WORK_RANGE + 0.000001
	for index in state.buildings.size():
		var hut: Dictionary = state.buildings[index]
		if hut.completed:
			continue
		var distance := _distance_to(state, float(hut.x), float(hut.z))
		if distance <= WORK_RANGE and distance < best:
			nearest = index
			best = distance
	return nearest


func _has_completed_hut(state: Dictionary) -> bool:
	for hut in state.buildings:
		if hut.completed:
			return true
	return false


func _enemy_in_range(state: Dictionary, reach: float) -> bool:
	for enemy in state.encounter.enemies:
		if int(enemy.health) > 0 and _distance_to(state, float(enemy.x), float(enemy.z)) <= reach:
			return true
	return false


func _all_enemies_defeated(state: Dictionary) -> bool:
	if state.encounter.enemies.is_empty():
		return false
	for enemy in state.encounter.enemies:
		if int(enemy.health) > 0:
			return false
	return true


func _update_morale(state: Dictionary) -> void:
	state.squad.morale = mini(100, 60 + 5 * int(state.squad.recruits) - 15 * int(state.population.dead) + (10 if state.progress.skirmish_won else 0))


func _record(state: Dictionary, text: String) -> void:
	state.chronicle.append({"time": state.world_seconds, "text": text})
	while state.chronicle.size() > MAX_CHRONICLE:
		state.chronicle.pop_front()


func _set_story(state: Dictionary, title: String, text: String) -> void:
	state.story.title = title
	state.story.text = text
	state.story.choices = []


func _ok(message: String) -> Dictionary:
	return {"ok": true, "message": message}


func _fail(message: String) -> Dictionary:
	return {"ok": false, "message": message}

func _world_copy() -> Dictionary:
	var candidate := {}
	for key in data:
		var value: Variant = data[key]
		if key != "valley" and typeof(value) in [TYPE_DICTIONARY, TYPE_ARRAY]:
			candidate[key] = value.duplicate(true)
		else:
			candidate[key] = value
	return candidate
