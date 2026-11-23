extends SceneTree
## Migration and routing between the two actually published childhood formats.

const Model = preload("res://scripts/domain/world_model.gd")
const Childhood = preload("res://scripts/story/childhood_story.gd")
const LegacyChildhood = preload("res://scripts/story/village_childhood.gd")
const Format = preload("res://scripts/domain/childhood_format.gd")
const Economy = preload("res://scripts/domain/village_economy.gd")
const Life = preload("res://scripts/story/village_life.gd")
const Combat = preload("res://scripts/domain/unarmed_combat.gd")
const Fixture = preload("res://tests/base_childhood_fixture.gd")
const StoryCases = preload("res://tests/childhood_story_test.gd")
var checks := 0
var failures: Array[String] = []
var files: Array[String] = []


func _initialize() -> void:
	_test_disjoint_new_games()
	_test_legacy_work_and_clock()
	_test_legacy_pending_combat()
	_test_modern_roundtrip_and_optional_combat()
	_test_modern_live_combat_support()
	_test_invalid_mixed_saves()
	for path: String in files:
		for suffix: String in ["", ".bak", ".tmp", ".bak.tmp"]:
			if FileAccess.file_exists(path+suffix):
				DirAccess.remove_absolute(ProjectSettings.globalize_path(path+suffix))
	print("CHILDHOOD_MERGE_MIGRATION_RESULT checks=%d failures=%d" % [checks,failures.size()])
	for failure: String in failures:
		printerr(failure)
	print("CHILDHOOD_MERGE_MIGRATION_PASS" if failures.is_empty() else "CHILDHOOD_MERGE_MIGRATION_FAIL")
	quit(0 if failures.is_empty() else 1)


func _test_disjoint_new_games() -> void:
	var modern = Model.new()
	modern.new_game("italia",true,true)
	_check(Childhood.enabled(modern.data) and not LegacyChildhood.enabled(modern.data),"The real new-game entry selects only the Julia/Silvanus/Sextus story")
	_check(modern.data.village.childhood.scene_id=="family_morning" and Combat.enabled(modern.data),"The current opening keeps its actual first scene and integrated unarmed combat")
	_check(Economy.day_length(modern.data)==120.0,"The published modern world's economic clock is not reinterpreted as an hour")
	_check(_role(modern.data,"sextus").contains("Schmied") and _role(modern.data,"julia").contains("Mutter"),"The modern world assigns the user's actual family and smith roles")
	var snapshot: Dictionary = modern.data.duplicate(true)
	_check(not LegacyChildhood.start(modern.data) and _same(modern.data,snapshot),"The older initializer cannot overwrite a current family story")
	_check(not modern.execute("village_childhood_action",{"action_id":"mother_morning"}).ok and _same(modern.data,snapshot),"An old chapter command cannot run a second plot beside a new game")
	_check(not modern.execute("village_childhood_begin_raid").ok and _same(modern.data,snapshot),"The older night-release command cannot skip the new explicit night choice")
	var inactive = Model.new()
	inactive.new_game("italia",true)
	_check(not Childhood.enabled(inactive.data) and not LegacyChildhood.enabled(inactive.data),"An inactive current-shaped contract enables neither childhood")
	_check(Economy.day_length(inactive.data)==120.0 and not Combat.enabled(inactive.data),"Mere presence of a childhood dictionary changes neither old clock nor old controls")
	inactive.advance(121.0)
	_check(inactive.data.village.economy.day==1 and is_equal_approx(inactive.data.village.economy.day_seconds,1.0),"The earlier non-childhood village still advances its actual 120-second cycle")


func _test_legacy_work_and_clock() -> void:
	var original := _original("mid_work")
	var model = Model.new()
	if not _load_fixture(model,"mid_work"):
		return
	_check(original.schema_version==5 and model.data.schema_version==Model.SCHEMA_VERSION,"An actual original schema-5 envelope migrates through the public loader")
	_check(LegacyChildhood.enabled(model.data) and not Childhood.enabled(model.data),"Only the legacy story is active after loading a previous childhood")
	for section: String in ["childhood","economy","social","raid","history","unarmed"]:
		_check(_same(model.data.village[section],original.village[section]),"Migration preserves the entire original village section: "+section)
	for section: String in ["resources","player","world_seconds","revision","command_log","chronicle","frontier"]:
		_check(_same(model.data[section],original[section]),"Migration preserves the original root section: "+section)
	_check(model.data.village.trade.ledger=={"wood":0,"grain":0,"denarii":0,"stone":0} and model.data.village.trade.change_asses==0,"The newly supported market adds no invented income or old wages")
	_check(_role(model.data,"antonia").contains("Mutter") and _role(model.data,"sextus").contains("Vater") and _role(model.data,"quintus").to_lower().contains("schmied"),"Previously saved Antonia/Sextus/Quintus roles remain intact")
	_check(not model.get_childhood_view().enabled and LegacyChildhood.view(model.data).stage=="forge_bellows","Presentation routing keeps the pending earlier workshop task")
	var snapshot: Dictionary = model.data.duplicate(true)
	_check(not model.execute("childhood_choose",{"scene_id":"family_morning","choice":"promise"}).ok and _same(model.data,snapshot),"A current-family choice cannot restart a loaded earlier childhood")
	var replay: Dictionary = model.execute("village_childhood_action",{"action_id":"mother_morning"},"fixture_step_mother_morning")
	_check(replay.ok and _same(model.data,snapshot),"An original cached command receipt stays idempotent after migration")
	model.advance(4.75)
	_check(is_equal_approx(model.data.village.childhood.work_seconds,8.0) and LegacyChildhood.view(model.data).stage=="forge_bellows","The saved 3.25 seconds resume into actual work without auto-completing its action")
	_check(model.execute("village_childhood_action",{"action_id":"forge_bellows"},"migrated_finish_work").ok and LegacyChildhood.view(model.data).stage=="forge_anvil","The previous quest continues at its real next station through the current transaction API")
	var path := _path("legacy_again")
	_check(model.save_game(path).ok,"The continued legacy path saves under schema 6")
	var restored = Model.new()
	_check(restored.load_game(path).ok and _same(restored.data,model.data),"A second load preserves the entire migrated world rather than converting its plot")
	restored.advance(121.0)
	_check(Economy.day_length(restored.data)==3600.0 and restored.data.village.economy.day==0 and is_equal_approx(restored.data.village.economy.day_seconds,129.0),"The real resumed earlier village retains its 3600-second economic clock")
	_check(restored.data.village.childhood.day==2 and restored.data.village.raid.number==0 and restored._validate_state(restored.data).is_empty(),"The inherited clock neither skips narrated days nor starts an automatic raid")


func _test_legacy_pending_combat() -> void:
	var original := _original("pending_unarmed")
	var model = Model.new()
	if not _load_fixture(model,"pending_unarmed"):
		return
	_check(_same(original.village.unarmed,model.data.village.unarmed),"Loading preserves the prior combat's actual stamina, practice and unresolved swing")
	_check(model.data.village.unarmed.practice_hits==1 and is_equal_approx(model.data.village.unarmed.elapsed,0.1) and not model.data.village.unarmed.resolved,"The fixture contains an actual earlier completed hit and a separate pending windup")
	var snapshot: Dictionary = model.data.duplicate(true)
	var args := {"technique":"jab_left","target_id":"practice","facing_x":0.0,"facing_z":-1.0}
	_check(model.execute("village_unarmed_attack",args,"fixture_pending_attack").ok and _same(model.data,snapshot),"Replaying the saved attack command cannot charge stamina or restart its windup")
	model.advance(0.6)
	_check(model.data.village.unarmed.practice_hits==2,"The older pending swing resolves once under the integrated current model")
	model.advance(0.6)
	_check(model.data.village.unarmed.practice_hits==2 and model.data.village.childhood.completed.is_empty(),"Recovery neither repeats the hit nor advances a different childhood plot")


func _test_modern_roundtrip_and_optional_combat() -> void:
	var model = Model.new()
	model.new_game("italia",true,true)
	var point := Childhood.actor_position(model.data,"julia")
	model.set_player_position(Vector3(point.x,1.0,point.y))
	_check(model.execute("childhood_choose",{"scene_id":"family_morning","choice":"promise"}).ok,"The modern story still reserves its actual parcel through the normal command")
	var child: Dictionary = model.data.village.childhood.duplicate(true)
	var resources: Dictionary = model.data.resources.duplicate(true)
	var previous: Dictionary = model.data.duplicate(true)
	previous.village.erase("unarmed")
	var path := _path("previous_modern")
	_write_envelope(path,previous)
	var restored = Model.new()
	_check(restored.load_game(path).ok,"A published modern schema-6 shape without the later combat extension loads")
	_check(Childhood.enabled(restored.data) and not LegacyChildhood.enabled(restored.data) and _same(restored.data.village.childhood,child) and _same(restored.data.resources,resources),"Adding combat capability preserves the modern parcel, family memories, ledger and scene")
	_check(Combat.enabled(restored.data) and restored.data.village.unarmed.practice_hits==0,"Only the previously absent optional combat module is initialized")
	restored.set_player_position(Vector3(0,1,-5.7))
	_check(restored.execute("village_unarmed_attack",{"technique":"jab_left","target_id":"practice","facing_x":0.0,"facing_z":-1.0}).ok,"The added unarmed controls work in the actual current family chapter")
	restored.advance(0.1)
	path = _path("modern_windup")
	_check(restored.save_game(path).ok,"The modern pending combat action saves alongside the family story")
	var again = Model.new()
	_check(again.load_game(path).ok and _same(again.data,restored.data),"Existing modern combat is preserved without a second initialization")
	again.advance(0.6)
	_check(again.data.village.unarmed.practice_hits==1 and _same(again.data.village.childhood,child),"A current pending hit completes without replaying or changing family decisions")


func _test_modern_live_combat_support() -> void:
	var model = _modern_night("defend")
	if model==null:
		return
	model.advance(32.1)
	_check(model.data.village.raid.active and not model.data.village.childhood.night_raid.support_confirmed,"The genuine modern raid begins without fabricated unarmed support")
	var enemy: Dictionary = model.data.village.raid.enemies[0]
	var health := int(enemy.health)
	model.set_player_position(Vector3(float(enemy.x),1.0,float(enemy.z)+1.1))
	_check(model.execute("village_unarmed_attack",{"technique":"jab_left","target_id":enemy.id,"facing_x":0.0,"facing_z":-1.0}).ok,"The integrated unarmed attack targets an actual living raider")
	_check(not model.data.village.childhood.night_raid.support_confirmed,"An accepted attack animation alone still proves no defense")
	model.advance(0.3)
	_check(model.data.village.raid.enemies[0].health<health and model.data.village.childhood.night_raid.support_kind=="combat","Only the observed unarmed hit becomes evidence for the modern mother's branch")
	model.set_player_position(Vector3(Childhood.REFUGE.x,1.0,Childhood.REFUGE.y))
	model.advance(180.0)
	_check(model.data.village.childhood.night_raid.outcome=="mother_survived","The actual newer combat implementation feeds the authored survivor outcome")
	var hidden = _modern_night("hide")
	if hidden==null:
		return
	var snapshot: Dictionary = hidden.data.duplicate(true)
	for command: String in ["village_unarmed_attack","village_unarmed_guard","village_unarmed_dodge"]:
		var args := {"technique":"jab_left","target_id":"air","facing_x":0.0,"facing_z":-1.0} if command=="village_unarmed_attack" else {}
		_check(not hidden.execute(command,args).ok and _same(hidden.data,snapshot),"The newer combat command cannot bypass the saved hiding decision: "+command)


func _modern_night(choice: String):
	var model = Model.new()
	model.new_game("italia",true,true)
	for item: Array in StoryCases.PATH_TO_NIGHT+[["night_decision",choice]]:
		var objective: Dictionary = model.get_childhood_objective()
		model.set_player_position(Vector3(objective.position[0],1.0,objective.position[1]))
		var result: Dictionary = model.execute("childhood_choose",{"scene_id":item[0],"choice":item[1]})
		if not result.ok:
			_check(false,"Modern night preparation failed through real commands: "+result.message)
			return null
	return model


func _test_invalid_mixed_saves() -> void:
	var live = Model.new()
	live.new_game("italia",true,true)
	var snapshot: Dictionary = live.data.duplicate(true)
	for extra: Dictionary in [{"enabled":true},{"scene_id":"family_morning","journal":[]},{"ledger":{"wood":12,"grain":16,"denarii":0,"stone":8}}]:
		var bad := _original("mid_work")
		bad.village.childhood.merge(extra,true)
		var path := _path("invalid_%d" % files.size())
		_write_envelope(path,bad)
		_check(not live.load_game(path).ok and _same(live.data,snapshot),"A mixed or unknown legacy story shape cannot overwrite the active world")
	var bad: Dictionary = snapshot.duplicate(true)
	bad.village.childhood.completed = []
	_check(Format.kind(bad)==Format.INVALID and not Childhood.enabled(bad) and not LegacyChildhood.enabled(bad),"Mixed format markers never enable two story systems")
	_check(not live._validate_state(bad).is_empty(),"The full authority rejects an ambiguous current-save payload")
	bad = _original("start")
	bad.village.childhood = {}
	var path := _path("missing_history")
	_write_envelope(path,bad)
	_check(not live.load_game(path).ok and _same(live.data,snapshot),"A present but erased old childhood is rejected instead of silently starting over")


func _original(checkpoint: String) -> Dictionary:
	var envelope: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(Fixture.PATHS[checkpoint]))
	return JSON.parse_string(envelope.payload)


func _load_fixture(model, checkpoint: String) -> bool:
	var loaded := Fixture.restore(model,checkpoint)
	_check(loaded.ok,"Normal fixture load "+checkpoint+": "+loaded.message)
	return loaded.ok


func _role(data: Dictionary, id: String) -> String:
	for row: Dictionary in Life.npc_catalog(data):
		if row.id==id:
			return row.role
	return ""


func _same(a: Variant, b: Variant) -> bool:
	return Childhood._equivalent(a,b)


func _path(label: String) -> String:
	var path := "user://childhood_merge_%s_%s.json" % [Time.get_ticks_usec(),label]
	files.append(path)
	return path


func _write_envelope(path: String, state: Dictionary) -> void:
	var payload := JSON.stringify(state,"",true,true)
	var envelope := {"format":Model.SAVE_FORMAT,"format_version":1,"payload":payload,"sha256":payload.sha256_text()}
	var file := FileAccess.open(path,FileAccess.WRITE)
	file.store_string(JSON.stringify(envelope))
	file.close()


func _check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures.append(message)
