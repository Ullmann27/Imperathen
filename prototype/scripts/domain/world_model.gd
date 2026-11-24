extends RefCounted
## Offline authority for the first playable chapter. Renderers only read `data`.
## Command transactions are atomic; construction is a sequence of paid work steps.
## Save hashes detect corruption, not deliberate editing by the owner of a save.

signal changed

const BattleModel = preload("res://scripts/battle/battle_model.gd")
const Seasons = preload("res://scripts/strategy/season_campaign.gd")
const Origins = preload("res://scripts/strategy/origins.gd")
const Frontier = preload("res://scripts/story/frontier_chapter.gd")
const VillageEconomy = preload("res://scripts/domain/village_economy.gd")
const VillageLife = preload("res://scripts/story/village_life.gd")
const CombatActions = preload("res://scripts/domain/combat_actions.gd")
const Childhood = preload("res://scripts/story/village_childhood.gd")
const NpcBehavior = preload("res://scripts/domain/npc_behavior.gd")
const Abilities = preload("res://scripts/story/chapter_abilities.gd")
const SCHEMA_VERSION := 5
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
	"resolve_skirmish": [], "choose_story": ["choice"],
	"frontier_talk": ["npc_id"], "frontier_choice": ["npc_id", "choice"]
}

var data: Dictionary = {}
var combat_sight_check: Callable
var combat_motion_check: Callable
var npc_observations: Callable
var npc_sight_check: Callable


func _init() -> void:
	new_game()


func new_game(origin_id := "italia", extended_village := false, childhood_enabled := false, action_combat := false) -> void:
	if not Origins.PEOPLES.has(origin_id):
		origin_id = "italia"
	var origin: Dictionary = Origins.PEOPLES[origin_id]
	data = {
		"schema_version": SCHEMA_VERSION,
		"world_id": "%s-%s" % [Time.get_ticks_usec(), randi()],
		"revision": 0, "world_seconds": 0.0,
		"resources": {"wood": 0, "grain": 12, "denarii": 30},
		"player": {"position": [0.0, 1.0, 8.0], "health": 100, "age": 12, "role": "child"},
		"companion": {"id": origin.companion.to_lower(), "met": false, "choice": "", "trust": 0, "age": 12},
		"progress": {"stage": "prologue", "training_hits": 0, "training_complete": false,
			"skirmish_won": false, "years_elapsed": 0, "chapter_complete": false, "career_terminal": false},
		"buildings": [], "resource_nodes": [],
		"squad": {"recruits": 0, "alive": 0, "morale": 60},
		"population": {"total": 4, "workers": 4, "soldiers": 0, "dead": 0},
		"encounter": {"started": false, "active": false, "resolved": false, "damage_taken": 0, "enemies": []},
		"timers": {"training": 0.0, "strike": 0.0, "damage": 0.0},
		"chronicle": [{"time": 0.0, "text": origin.intro}],
		"story": {"title": origin.calling, "text": "Sammle Holz, sprich mit %s und baue deine erste Unterkunft östlich des Weges." % origin.companion, "choices": [], "choice": ""},
		"origin_id":origin_id, "strategy":Seasons.new_game(origin_id), "valley": {}, "command_log": {},
		"frontier": Frontier.new_state()
	}
	for index in NODE_POSITIONS.size():
		data.resource_nodes.append({"id": "timber_%d" % index, "x": NODE_POSITIONS[index][0], "z": NODE_POSITIONS[index][1], "amount": 16})
	VillageEconomy.ensure(data)
	VillageLife.ensure(data)
	data.village.enabled = extended_village and origin_id == "italia"
	data.village.health_delta = 0
	data.village.militia = []
	if data.village.enabled and childhood_enabled:
		Childhood.start(data)
		for place: Dictionary in data.village.economy.workplaces.values():
			place.condition = 100
		for person: Dictionary in data.village.economy.people:
			if person.id in ["fabius","drusa"]:
				person.assignment="woodcamp"
			elif person.id in ["cassia", "antonia"]:
				# The existing potter helps Cassia at the market in new childhood
				# games. Two actual residents meet the unchanged staffing contract.
				person.assignment="trade"
		data.village.economy.last_report = "Markt, Felder und Werkstätten arbeiten bereits. Decimus verwaltet das Dorf; du beginnst als Kind deiner Familie."
		data.player.position = [-12.0, 1.35, 11.7]
		data.story.title = "Ein Morgen zu Hause"
		data.story.text = "Deine Familie und das Dorf sind schon da. Geh zu deiner Mutter vor dem Haus. Heute beginnt deine Geschichte mit den Menschen, die dich kennen."
		data.chronicle = [{"time":0.0,"text":"Du bist zwölf. In Valdora beginnt ein gewöhnlicher Morgen zwischen Familie, Handwerk und Markt."}]
	# The third argument retains the family chapter's published contract.
	# An explicit fourth argument also enables modern combat in legacy careers.
	if data.village.enabled and (childhood_enabled or action_combat):
		CombatActions.start(data)
	if data.village.enabled and childhood_enabled:
		NpcBehavior.start(data)
	changed.emit()


func execute(command: String, args: Dictionary = {}, command_id: String = "") -> Dictionary:
	var command_fields: Dictionary = COMMAND_FIELDS.duplicate()
	command_fields.merge(VillageEconomy.COMMAND_FIELDS)
	command_fields.merge(VillageLife.COMMAND_FIELDS)
	command_fields.merge(CombatActions.COMMAND_FIELDS)
	if not command_fields.has(command):
		return _fail("Unbekannter Spielbefehl: %s" % command)
	if not _exact_keys(args, command_fields[command]):
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
	if npc_observations.is_valid():
		NpcBehavior.observe(candidate, npc_observations.call(), true)
	var result := _apply_command(candidate, command, args)
	result.message = _regional_text(candidate, result.message)
	if not result.ok:
		return result
	candidate.story.text = _regional_text(candidate,candidate.story.text)
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


func capture_npc_observations() -> void:
	if not data.is_empty() and npc_observations.is_valid():
		NpcBehavior.observe(data, npc_observations.call(), true)


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


func interrupt_combat() -> void:
	if CombatActions.interrupt(data):
		data.revision = int(data.revision) + 1
		changed.emit()


func advance(delta: float) -> void:
	if not is_finite(delta) or delta <= 0.0 or delta > 3600.0 or data.is_empty():
		return
	if not _validate_state(data).is_empty() or data.progress.career_terminal:
		return
	if float(data.world_seconds) + delta > 1000000000000.0:
		return
	var candidate := _world_copy()
	var notify_ui := int(candidate.world_seconds) != int(float(candidate.world_seconds) + delta)
	if npc_observations.is_valid():
		NpcBehavior.observe(candidate,npc_observations.call(),true)
	for key in candidate.timers:
		candidate.timers[key] = maxf(0.0, float(candidate.timers[key]) - delta)
	if candidate.village.enabled:
		# All ongoing systems share the actual life-tick boundaries. Resources
		# produced before an alarm remain valid; an attack cannot cancel earlier work.
		Childhood.advance(candidate, delta)
		var remaining := delta
		while remaining > 0.0:
			var until_tick := maxf(0.00000001, VillageLife.STEP - float(candidate.village.social.accumulator))
			var step := minf(remaining, until_tick)
			candidate.world_seconds = float(candidate.world_seconds) + step
			if not candidate.village.raid.active:
				notify_ui = _advance_construction(candidate, step) or notify_ui
			var frontier_event := "" if Childhood.enabled(candidate) else Frontier.advance(candidate, step)
			if not frontier_event.is_empty():
				_record(candidate, frontier_event)
			var previous_health := int(candidate.player.health)
			if not VillageEconomy.advance(candidate, step):
				return
			VillageLife.advance(candidate, step, combat_sight_check, combat_motion_check)
			NpcBehavior.advance(candidate, step, npc_sight_check)
			if int(candidate.player.health) < previous_health:
				CombatActions.interrupt(candidate)
			var contact := CombatActions.advance(candidate, step, combat_sight_check, _apply_combat_hit)
			if contact.practice and int(candidate.player.age) >= 18 and candidate.progress.stage == "training":
				_apply_training_contact(candidate)
			candidate.village.health_delta += int(candidate.player.health) - previous_health
			remaining = maxf(0.0, remaining - step)
		notify_ui = true
	else:
		candidate.world_seconds = float(candidate.world_seconds) + delta
		notify_ui = _advance_construction(candidate, delta) or notify_ui
		var frontier_event := Frontier.advance(candidate, delta)
		if not frontier_event.is_empty():
			_record(candidate, frontier_event)
	candidate.revision = int(data.revision) + 1
	if not _validate_state(candidate).is_empty():
		return
	data = candidate
	if notify_ui:
		changed.emit()


func _advance_construction(candidate: Dictionary, delta: float) -> bool:
	var changed_work := false
	# One player supplies one work budget, even when two sites are nearby.
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
		changed_work = true
		if float(hut.progress) >= 1.0 - 0.000001:
			hut.progress = 1.0
			hut.completed = true
			_record(candidate, "Die Unterkunft %s ist fertig. Ihr Bau hat tatsächlich Material und Arbeit verbraucht." % hut.id)
			if candidate.progress.stage == "prologue":
				candidate.progress.stage = "settlement"
				_set_story(candidate, "Ein Dach über dem Kopf", "Deine Hütte steht. Triff Marcus und suche danach den Ausbilder am Übungsplatz auf.")
		else:
			break
	return changed_work


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
	if npc_observations.is_valid():
		NpcBehavior.observe(data,npc_observations.call(),true)
	var directory_error := DirAccess.make_dir_recursive_absolute(absolute.get_base_dir())
	if directory_error != OK:
		return _fail("Der Speicherordner kann nicht angelegt werden (Fehler %d)." % directory_error)
	var payload := JSON.stringify(data, "", true, true)
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


func get_frontier_dialog(npc_id: String) -> Dictionary:
	return Frontier.dialog(data, npc_id)


func get_frontier_objective() -> Dictionary:
	return Frontier.objective(data)


func _apply_combat_hit(state: Dictionary, target_id: String, damage: int) -> bool:
	# Only CombatActions calls this after its active-window and geometry checks.
	if VillageLife.apply_unarmed_hit(state, target_id, damage):
		return true
	if not state.encounter.active or damage <= 0 or damage > 32:
		return false
	var index := _find_id(state.encounter.enemies, target_id)
	if index < 0 or int(state.encounter.enemies[index].health) <= 0:
		return false
	var enemy: Dictionary = state.encounter.enemies[index]
	enemy.health = maxi(0, int(enemy.health) - damage)
	if int(enemy.health) == 0:
		_record(state, "Der Gegner %s ist ausgeschaltet; sein Zustand bleibt gespeichert." % target_id)
	if _all_enemies_defeated(state):
		_resolve_skirmish(state)
	return true


func _apply_training_contact(state: Dictionary) -> Dictionary:
	if state.progress.stage != "training" or int(state.player.age) < 18:
		return _fail("Beginne zuerst die erwachsene Ausbildung beim Übungsplatz.")
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
		_record(state, "Du beendest die erste Kampfausbildung. Als ausgebildeter Soldat darfst du einen kleinen Wachtrupp anwerben.")
		_set_story(state, "Eine erste Verantwortung", "Wirb bis zu drei Freiwillige an. Jeder kostet 5 Denarii und 2 Getreide und fehlt anschließend als zivile Arbeitskraft.")
		return _ok("Ausbildung abgeschlossen. Du darfst einen kleinen Trupp anwerben.")
	return _ok("Gültiger Übungstreffer %d/3." % int(state.progress.training_hits))


func _apply_command(state: Dictionary, command: String, args: Dictionary) -> Dictionary:
	if CombatActions.COMMAND_FIELDS.has(command):
		if not state.village.enabled:
			return _fail("Diese Partie verwendet den bisherigen regionalen Dorfabschnitt.")
		return CombatActions.execute(state, command, args)
	if CombatActions.enabled(state) and command in ["village_strike", "village_block", "village_dodge", "strike_enemy", "training_hit"]:
		return _fail("Verwende die gewählte Technik. Treffer zählen erst während der tatsächlichen Bewegung.")
	if command.begins_with("village_"):
		if not state.village.enabled:
			return _fail("Dieser Lebensweg verwendet den bisherigen regionalen Dorfabschnitt.")
		if Childhood.enabled(state) and command in ["village_request_work","village_assign","village_shift","village_repair","village_resow"]:
			return _fail("Die Erwachsenen organisieren das Dorf. Du hilfst mit deinen eigenen Aufträgen und lernst ihre Arbeit kennen.")
		if command in ["village_assign", "village_shift"] and state.village.militia.has(args.resident_id):
			return _fail("Diese Person gehört bereits zum angeworbenen Trupp und kann nicht zugleich eine Dorfstelle übernehmen.")
		var village_result: Dictionary
		var previous_health := int(state.player.health)
		if VillageEconomy.COMMAND_FIELDS.has(command):
			village_result = VillageEconomy.execute(state, command, args)
		else:
			village_result = VillageLife.execute(state, command, args)
		state.village.health_delta += int(state.player.health) - previous_health
		if village_result.get("ok", false) and command not in ["village_strike", "village_block", "village_dodge", "village_unarmed_attack", "village_unarmed_guard", "village_unarmed_dodge"]:
			_record(state, str(village_result.message))
		return village_result
	if command in ["frontier_talk", "frontier_choice"]:
		if Childhood.enabled(state):
			return _fail("Die Straße zur Legion gehört zu einem späteren Lebensabschnitt. Jetzt stehen Familie und Dorf im Mittelpunkt.")
		var frontier_result := Frontier.talk(state, args.npc_id) if command == "frontier_talk" else Frontier.choose(state, args.npc_id, args.choice)
		if frontier_result.has("chronicle"):
			_record(state, frontier_result.chronicle)
			frontier_result.erase("chronicle")
		return frontier_result
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
			if Childhood.enabled(state):
				return _fail("Marcus gehört im Kindheitskapitel zur Drehbuchmission I-03. Sprich mit ihm am Marktweg.")
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
			if Childhood.enabled(state) and state.village.childhood.night_event!="released":
				return _fail("Deine Familie hat ein Zuhause. Lerne zuerst das Dorf und seine Handwerker kennen.")
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
			if Childhood.enabled(state):
				return _fail("Du bleibst zwölf. Am Übungspfahl kannst du Fausttechniken lernen; ein Sprung in die erwachsene Militärlaufbahn findet hier nicht statt.")
			if state.player.age >= 18:
				return _fail("Du befindest dich bereits im erwachsenen Ausbildungsabschnitt.")
			if state.village.enabled and state.village.raid.status in ["warning", "active"]:
				return _fail("Kläre zuerst die unmittelbare Gefahr. Ein Überfall kann nicht durch einen Zeitsprung übersprungen werden.")
			if state.village.enabled and not VillageLife.training_ready(state):
				return _fail("Lebe zuerst im Dorf: lerne drei Menschen kennen, hilf beim Wiederaufbau und erlebe die erste Verteidigung. Der nächste Lebensabschnitt beginnt frühestens nach zwei Dorftagen.")
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
			return _apply_training_contact(state)
		"recruit":
			if not state.progress.training_complete:
				return _fail("Beende zuerst die erwachsene Ausbildung.")
			if state.encounter.started:
				return _fail("Die Besetzung dieses Gefechts ist bereits festgelegt.")
			if int(state.squad.recruits) >= 3:
				return _fail("Dieser Wachtrupp umfasst höchstens drei Freiwillige.")
			if int(state.resources.denarii) < 5 or int(state.resources.grain) < 2:
				return _fail("Ein Freiwilliger benötigt 5 Denarii und 2 Getreide.")
			var recruit_name := "Ein Freiwilliger"
			if state.village.enabled:
				var person := _available_village_recruit(state)
				if person.is_empty():
					return _fail("Für den Trupp fehlt ein gesunder freier Helfer. Gib zuerst einen Nicht-Mentor aus seiner Arbeit für die Reserve frei.")
				state.village.militia.append(person.id)
				person.previous_assignment = "idle"
				person.assignment = "defense"
				recruit_name = person.name
			state.resources.denarii = int(state.resources.denarii) - 5
			state.resources.grain = int(state.resources.grain) - 2
			state.squad.recruits = int(state.squad.recruits) + 1
			state.squad.alive = int(state.squad.alive) + 1
			state.population.workers = int(state.population.workers) - 1
			state.population.soldiers = int(state.population.soldiers) + 1
			_update_morale(state)
			_record(state, "%s wechselt aus der Dorfarbeit in deinen Wachtrupp." % recruit_name)
			return _ok("%s angeworben. 5 Denarii und 2 Getreide verbraucht." % recruit_name)
		"start_skirmish":
			if state.village.enabled and state.village.raid.status in ["warning", "active"]:
				return _fail("Die laufende Dorfgefahr muss zuerst enden. Derselbe Trupp kann nicht zwei Gefechte gleichzeitig führen.")
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
			if CombatActions.enabled(state):
				if float(state.village.raid.dodge_window) > 0.0:
					state.village.raid.dodge_window = 0.0
					return _ok("Du bist dem tatsächlichen gegnerischen Treffer ausgewichen.")
				if float(state.village.raid.block_window) > 0.0:
					state.village.raid.block_window = 0.0
					return _ok("Deine Deckung fängt den tatsächlichen gegnerischen Treffer ab.")
				CombatActions.interrupt(state)
			var actual := mini(int(args.amount), int(state.player.health))
			state.player.health = int(state.player.health) - actual
			state.encounter.damage_taken = int(state.encounter.damage_taken) + actual
			var expected_dead := mini(int(state.squad.recruits), int(state.encounter.damage_taken) / 32)
			var newly_dead := expected_dead - int(state.population.dead)
			if newly_dead > 0:
				if state.village.enabled:
					for casualty in range(int(state.population.dead), expected_dead):
						var resident := _village_resident(state, state.village.militia[casualty])
						resident.alive = false
						resident.health = 0
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
	if CombatActions.COMMAND_FIELDS.has(command):
		return CombatActions.validate_arguments(command, args)
	if command.begins_with("village_"):
		# Reject NaN and foreign types before JSON fingerprinting, not only in
		# the subordinate command handler after the replay record was prepared.
		for key in args:
			if not _text(args[key], 1, 64):
				return "Der Dorfauftrag benötigt gültige Personen-, Ziel- und Antwortkennungen."
	elif command in ["frontier_talk", "frontier_choice"]:
		if not _text(args.npc_id, 1, 32) or not Frontier.NPCS.has(args.npc_id):
			return "Eine gültige Dorfperson fehlt."
		if command == "frontier_choice" and not _text(args.choice, 1, 32):
			return "Eine gültige Gesprächsantwort fehlt."
	elif command in ["gather", "strike_enemy"]:
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
	if not _exact_keys(state, ["schema_version", "world_id", "revision", "world_seconds", "resources", "player", "companion", "progress", "buildings", "resource_nodes", "squad", "population", "encounter", "timers", "chronicle", "story", "command_log", "valley", "origin_id", "strategy", "frontier", "village"]):
		return "Unvollständiger oder unbekannter Datenvertrag."
	if not _integer(state.schema_version, SCHEMA_VERSION, SCHEMA_VERSION):
		return "Diese Schemaversion wird nicht unterstützt; es wurde keine Migration ausgeführt."
	if typeof(state.origin_id) != TYPE_STRING or not Origins.PEOPLES.has(state.origin_id) or typeof(state.strategy) != TYPE_DICTIONARY or not Seasons.validate(state.strategy) or state.strategy.home != state.origin_id:
		return "Unbekannte Herkunft oder ungültige Regionalkampagne."
	if state.strategy.turn > 0 and (typeof(state.progress) != TYPE_DICTIONARY or not state.progress.get("skirmish_won",false)):
		return "Der Regionalauftrag setzt eine abgeschlossene Dorfverteidigung voraus."
	if not _text(state.world_id, 1, 100) or not _integer(state.revision, 0, 9007199254740990) or not _number(state.world_seconds, 0.0, 1000000000000.0):
		return "Ungültige Weltkennung, Revision oder Zeit."
	if not _exact_keys(state.resources, ["wood", "grain", "denarii", "stone"]):
		return "Ungültiger Güterbestand."
	if typeof(state.village) != TYPE_DICTIONARY or typeof(state.village.get("enabled")) != TYPE_BOOL:
		return "Der Dorfvertrag fehlt."
	if not _integer(state.village.get("health_delta"), -1000000, 1000000):
		return "Die Gesundheitsbilanz des Dorflebens ist ungültig."
	if typeof(state.village.get("militia")) != TYPE_ARRAY or state.village.militia.size() > 3:
		return "Die persönliche Dorfmiliz ist ungültig."
	if state.village.enabled and state.origin_id != "italia":
		return "Der römische Dorfabschnitt passt nicht zur Herkunft."
	if CombatActions.enabled(state) and not state.village.enabled:
		return "Die neue Kampfsteuerung benötigt den zugehörigen Dorfabschnitt."
	var combat_error := CombatActions.validate(state)
	if not combat_error.is_empty():
		return combat_error
	var economy_error := VillageEconomy.validate(state)
	if not economy_error.is_empty():
		return economy_error
	var life_error := VillageLife.validate(state)
	if not life_error.is_empty():
		return life_error
	var behavior_error := NpcBehavior.validate(state)
	if not behavior_error.is_empty():
		return behavior_error
	if float(state.village.social.accumulator) >= VillageLife.STEP + 0.00000001:
		return "Die Dorfzeit enthält einen nicht abgearbeiteten Zeitsprung."
	var economic_seconds := int(state.village.economy.day) * VillageEconomy.day_length(state) + float(state.village.economy.day_seconds)
	var social_seconds := float(state.village.social.seconds) + float(state.village.social.accumulator)
	if absf(economic_seconds - social_seconds) > 0.0001:
		return "Arbeitszeit und Dorfereignisse laufen nicht auf derselben Uhr."
	for key in state.resources:
		if not _integer(state.resources[key], 0, 1000000):
			return "Güter müssen endliche nichtnegative ganze Mengen sein."
	if not _exact_keys(state.player, ["position", "health", "age", "role"]):
		return "Ungültige Spielerfigur."
	if not _valid_position(state.player.position) or not _integer(state.player.health, 0, 100) or not _integer(state.player.age, 12, 250018) or not _text(state.player.role, 1, 20):
		return "Ungültiger Ort, Gesundheit, Alter oder Rolle."
	if not _exact_keys(state.companion, ["id", "met", "choice", "trust", "age"]):
		return "Ungültiger Gefährtenzustand."
	var companion: Dictionary = state.companion
	if companion.id != Origins.PEOPLES[state.origin_id].companion.to_lower() or typeof(companion.met) != TYPE_BOOL or not _text(companion.choice, 0, 16) or companion.choice not in ["", "help", "decline"]:
		return "Ungültige Gefährtenidentität oder Auswahl."
	if companion.met != (companion.choice != "") or not _integer(companion.trust, -100, 100) or not _integer(companion.age, 12, 250018) or companion.age != state.player.age:
		return "Gefährtenentscheidung, Vertrauen oder Alter widersprechen sich."
	if not _exact_keys(state.progress, ["stage", "training_hits", "training_complete", "skirmish_won", "years_elapsed", "chapter_complete", "career_terminal"]):
		return "Ungültiger Kapitelzustand."
	var progress: Dictionary = state.progress
	if not _text(progress.stage, 1, 32) or progress.stage not in STAGES or not _integer(progress.training_hits, 0, 3) or not _integer(progress.years_elapsed, 0, 250006):
		return "Unbekannte Spielphase oder Ausbildung."
	for key in ["training_complete", "skirmish_won", "chapter_complete", "career_terminal"]:
		if typeof(progress[key]) != TYPE_BOOL:
			return "Kapitelmerkmale müssen Wahrheitswerte sein."
	var adult: bool = progress.stage not in ["prologue", "settlement"]
	var elapsed_years := (6 if adult else 0) + floori(state.strategy.turn / 4.0)
	if state.player.age != 12 + elapsed_years or progress.years_elapsed != elapsed_years:
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
	if state.village.enabled:
		if state.village.militia.size() != int(state.squad.recruits):
			return "Ein Rekrut besitzt keine tatsächliche Dorfperson."
		var seen_militia := {}
		for index in state.village.militia.size():
			var id: Variant = state.village.militia[index]
			if not _text(id, 1, 48) or seen_militia.has(id):
				return "Eine Dorfperson wurde mehrfach angeworben."
			seen_militia[id] = true
			var resident := _village_resident(state, id)
			if resident.is_empty() or resident.assignment != "defense" or resident.previous_assignment != "idle":
				return "Der Truppangehörige fehlt nicht an seiner zivilen Arbeitsstelle."
			var casualty: bool = int(index) < dead
			if resident.alive == casualty or (casualty and int(resident.health) != 0):
				return "Truppverluste und tatsächliche Dorfpersonen widersprechen sich."
	elif not state.village.militia.is_empty():
		return "Die bisherige Karriere hat keine neue Dorfmiliz."
	if not _exact_keys(state.encounter, ["started", "active", "resolved", "damage_taken", "enemies"]):
		return "Ungültiger Gefechtszustand."
	var encounter: Dictionary = state.encounter
	for key in ["started", "active", "resolved"]:
		if typeof(encounter[key]) != TYPE_BOOL:
			return "Gefechtsmerkmale müssen Wahrheitswerte sein."
	if not _integer(encounter.damage_taken, 0, 1000000) or typeof(encounter.enemies) != TYPE_ARRAY:
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
	if int(encounter.damage_taken) != 100 + int(state.village.health_delta) - int(state.player.health) or dead != mini(int(state.squad.recruits), int(encounter.damage_taken) / 32):
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
	var frontier_error := Frontier.validate(state)
	if not frontier_error.is_empty():
		return frontier_error
	var frontier_effects := Frontier.effects(state.frontier)
	var village_ledger := {"wood":0, "grain":0, "denarii":0, "stone":0}
	for key in village_ledger:
		village_ledger[key] = int(state.village.economy.ledger[key]) + int(state.village.social.ledger[key])
	var childhood_marcus_friend := Childhood.enabled(state) and str(state.village.childhood.screenplay.get("i03_outcome", "")) == "friend"
	var help_cost := 0 if childhood_marcus_friend else (4 if companion.choice == "help" else 0)
	if int(state.resources.wood) + HUT_COST * state.buildings.size() + help_cost != 48 - remaining_wood + int(village_ledger.wood):
		return "Die Holzbilanz wurde verletzt."
	if int(state.resources.stone) != int(village_ledger.stone):
		return "Die Steinbilanz wurde verletzt."
	var expected_grain := 12 - 2 * int(state.squad.recruits) + (4 if progress.skirmish_won else 0) + (4 if state.story.choice == "protect" else 0)
	var expected_money := 30 - 5 * int(state.squad.recruits) + (15 if progress.skirmish_won else 0) + (12 if state.story.choice == "pursue" else 0)
	expected_grain += int(frontier_effects.grain)
	expected_money += int(frontier_effects.denarii)
	expected_grain += int(village_ledger.grain)
	expected_money += int(village_ledger.denarii)
	if state.resources.grain != expected_grain or state.resources.denarii != expected_money:
		return "Die Versorgungs- oder Geldbilanz wurde verletzt."
	var expected_trust := (20 if companion.choice == "help" else (-5 if companion.choice == "decline" else 0)) + (5 if state.story.choice == "protect" else (-5 if state.story.choice == "pursue" else 0))
	expected_trust += int(frontier_effects.trust)
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
		state.schema_version = 2
		state.valley = {}
	if typeof(state) == TYPE_DICTIONARY and state.get("schema_version") == 2 and not state.has("strategy") and not state.has("origin_id"):
		state.schema_version = 3
		state.origin_id = "italia"
		state.strategy = Seasons.new_game("italia")
	if typeof(state) == TYPE_DICTIONARY and state.get("schema_version") == 3 and not state.has("frontier"):
		state.schema_version = 4
		state.frontier = Frontier.new_state()
	if typeof(state) == TYPE_DICTIONARY and state.get("schema_version") == 4 and not state.has("village"):
		VillageEconomy.ensure(state)
		VillageLife.ensure(state)
		# Old careers continue without retroactively imposing the new prologue.
		state.village.enabled = false
		state.village.health_delta = 0
		state.village.militia = []
		state.schema_version = SCHEMA_VERSION
	# Nested childhood actor IDs changed when the production screenplay fixed
	# Julia/Silvanus/Sextus as mother/father/smith. Migrate only version-1
	# childhood saves before strict state validation; all other saves are untouched.
	if typeof(state) == TYPE_DICTIONARY:
		Childhood.migrate_legacy_ids(state)
		# Screenplay bridge v2 -> v3 (I-07 water); nothing is completed retroactively.
		Childhood.migrate_screenplay(state)
		# Schema v5 saves written before chapter abilities existed gain the record
		# derived from their already saved story facts; the schema stays v5.
		Abilities.ensure(state)
	var error := _validate_state(state)
	# Only an already valid old childhood save may initialize decisions. The
	# initializer reads family and economy data, so malformed legacy input must
	# be rejected before it reaches that code. Present behavior is never replaced.
	if error.is_empty() and Childhood.enabled(state) and not state.village.has("behavior"):
		NpcBehavior.start(state)
		error = _validate_state(state)
	if error.is_empty() and NpcBehavior.enabled(state):
		# Old valid saves gain an empty social history. Existing malformed
		# relationships must fail validation before any migration is attempted.
		NpcBehavior.ensure_social(state)
		error = _validate_state(state)
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
	state.frontier.schema = int(state.frontier.schema)
	state.frontier.step = int(state.frontier.step)
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
	state.village.health_delta = int(state.village.health_delta)
	if NpcBehavior.enabled(state):
		state.village.behavior.version = int(state.village.behavior.version)
		for behavior: Dictionary in state.village.behavior.people.values():
			behavior.last_trust = int(behavior.last_trust)
			behavior.route_direction = int(behavior.route_direction)
		if state.village.behavior.has("social"):
			state.village.behavior.social.version = int(state.village.behavior.social.version)
			for relation: Dictionary in state.village.behavior.social.pairs.values():
				relation.encounters = int(relation.encounters)
	if CombatActions.enabled(state):
		for key in ["version", "practice_hits", "resolved_hits"]:
			state.village.unarmed[key] = int(state.village.unarmed[key])
	var economy: Dictionary = state.village.economy
	for key in ["version", "day", "meal_offset", "meals_served", "grain_shortfall", "patrols_completed", "repair_count"]:
		economy[key] = int(economy[key])
	for section in ["stocks", "ledger"]:
		for key in economy[section]:
			economy[section][key] = int(economy[section][key])
	for person in economy.people:
		person.health = int(person.health)
		person.hunger = int(person.hunger)
	for place in economy.workplaces.values():
		place.condition = int(place.condition)
		place.produced_cycles = int(place.produced_cycles)
	state.village.social.version = int(state.village.social.version)
	for key in state.village.social.ledger:
		state.village.social.ledger[key] = int(state.village.social.ledger[key])
	for relation in state.village.social.npcs.values():
		relation.trust = int(relation.trust)
	for key in ["number", "completed", "won", "participation", "player_hits", "blocks", "dodges", "stolen"]:
		state.village.raid[key] = int(state.village.raid[key])
	for enemy in state.village.raid.enemies:
		enemy.health = int(enemy.health)
		enemy.max_health = int(enemy.max_health)
	for key in state.village.attributes:
		state.village.attributes[key] = int(state.village.attributes[key])
	state.village.history.start_year = int(state.village.history.start_year)
	if typeof(state.village.get("abilities")) == TYPE_DICTIONARY:
		state.village.abilities.version = int(state.village.abilities.version)
	if Childhood.enabled(state):
		state.village.childhood.version=int(state.village.childhood.version)
		state.village.childhood.day=int(state.village.childhood.day)
		state.village.childhood.guard_absence.previous_health=int(state.village.childhood.guard_absence.previous_health)
		for relation:Dictionary in state.village.childhood.relationships.values():
			relation.trust=int(relation.trust)


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
	return typeof(value) == TYPE_ARRAY and value.size() == 3 and _number(value[0], -16000.0, 16000.0) and _number(value[1], -100.0, 500.0) and _number(value[2], -16000.0, 16000.0)


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


func _village_resident(state: Dictionary, id: String) -> Dictionary:
	for person in state.village.economy.people:
		if person.id == id:
			return person
	return {}


func _available_village_recruit(state: Dictionary) -> Dictionary:
	for person in state.village.economy.people:
		if VillageLife.NPCS.has(person.id):
			continue
		if person.alive and int(person.health) > 30 and int(person.hunger) < 2 and person.assignment == "idle":
			return person
	return {}


func _has_completed_hut(state: Dictionary) -> bool:
	for hut in state.buildings:
		if hut.completed:
			return true
	return false


func _enemy_in_range(state: Dictionary, reach: float) -> bool:
	for enemy in state.encounter.enemies:
		if int(enemy.health) > 0 and _distance_to(state, float(enemy.x), float(enemy.z)) <= reach:
			if CombatActions.enabled(state):
				var source := Vector2(float(enemy.x), float(enemy.z))
				var target := Vector2(float(state.player.position[0]), float(state.player.position[2]))
				if not combat_sight_check.is_valid() or not bool(combat_sight_check.call(source, target)):
					continue
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


func _regional_text(state: Dictionary, text: String) -> String:
	return text.replace("Marcus", Origins.PEOPLES[state.origin_id].companion)


func _record(state: Dictionary, text: String) -> void:
	text = _regional_text(state,text)
	state.chronicle.append({"time": state.world_seconds, "text": text})
	while state.chronicle.size() > MAX_CHRONICLE:
		state.chronicle.pop_front()


func _set_story(state: Dictionary, title: String, text: String) -> void:
	state.story.title = title
	state.story.text = _regional_text(state,text)
	state.story.choices = []


func _ok(message: String) -> Dictionary:
	return {"ok": true, "message": message}


func _fail(message: String) -> Dictionary:
	return {"ok": false, "message": message}

func _world_copy() -> Dictionary:
	var candidate := {}
	for key in data:
		var value: Variant = data[key]
		if key not in ["strategy","valley"] and typeof(value) in [TYPE_DICTIONARY, TYPE_ARRAY]:
			candidate[key] = value.duplicate(true)
		else:
			candidate[key] = value
	return candidate

func act_region(command: String,target: String) -> Dictionary:
	if not data.progress.skirmish_won or data.progress.career_terminal or not data.story.choices.is_empty():
		return _fail("Erfülle zuerst den Auftrag zur Dorfverteidigung.")
	var result: Dictionary = Seasons.act(data.strategy,command,target)
	if result.ok:
		if command == "supply" and data.valley.get("outcome","") == "defeat":
			data.strategy.supply -= 1
			result.message += " Wegen der verlorenen Talstraße verbraucht der Umweg einen Reisevorrat."
			data.strategy.last_event = result.message
		if command == "advance":
			data.world_seconds += YEAR_SECONDS/4.0
			data.progress.years_elapsed = 6 + floori(data.strategy.turn/4.0)
			data.player.age = 12 + data.progress.years_elapsed
			data.companion.age = data.player.age
		_record(data,result.message)
		data.revision += 1
		changed.emit()
	return result
