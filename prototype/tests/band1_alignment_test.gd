extends SceneTree
## Band 1 screenplay alignment for the childhood chapter (I-01 ff.).
## Checks authored registry data, step-to-mission mapping and the HUD heading
## through the real WorldModel. Known deviations from the screenplay cast are
## listed explicitly in DOCUMENTED_CAST_DEVIATIONS and in docs/22_band1_alignment.

const WorldModel = preload("res://scripts/domain/world_model.gd")
const Childhood = preload("res://scripts/story/village_childhood.gd")
const Bible = preload("res://scripts/story/campaign_bible.gd")

const ACTOR_NAMES := {"julia":"Julia", "silvanus":"Silvanus", "sextus":"Sextus", "marcus":"Marcus",
	"cassia":"Cassia", "aurelia":"Aurelia", "decimus":"Decimus"}
## step id -> reason. These steps use people the Band 1 cast table does not name.
const DOCUMENTED_CAST_DEVIATIONS := {
	"deliver_food":"I-03 lists Marcus and Cassia; the returning delivery goes to Julia.",
	"smith_apprentice":"I-06 lists Cassia and Marcus; the apprenticeship talk is with Sextus.",
	"family_report":"I-07 lists Decimus and Silvanus; the code uses Julia at home.",
	"healer_request":"I-07 lists Decimus and Silvanus; the code uses Aurelia.",
	"deliver_medicine":"I-07 lists Decimus and Silvanus; the code uses Severus.",
	"borrow_gear":"I-07 lists Decimus and Silvanus; the code uses Severus.",
	"watch_message":"I-07 lists Decimus and Silvanus; the code uses Cassia.",
	"return_gear":"I-07 lists Decimus and Silvanus; the code uses Severus.",
}
var checks := 0
var failures: Array[String] = []


func _initialize() -> void:
	Bible.reset_cache_for_tests()
	_test_registry()
	_test_mapping()
	_test_heading_and_texts()
	print("BAND1_ALIGNMENT_RESULT checks=%d failures=%d" % [checks, failures.size()])
	for failure: String in failures:
		printerr("FAIL: " + failure)
	print("BAND1_ALIGNMENT_PASS" if failures.is_empty() else "BAND1_ALIGNMENT_FAIL")
	quit(0 if failures.is_empty() else 1)


func _check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures.append(message)


func _test_registry() -> void:
	var expected := {
		"I-01":["Die drei Becher", "Familienhaus Valdora", ["Julia", "Silvanus", "Spieler"]],
		"I-02":["Der falsche Korb", "Nachbarhaus und Backgasse", ["Julia", "Aurelia", "Spieler"]],
		"I-03":["Marcus kennt eine Abkürzung", "Gassen, Brunnen, Markt", ["Marcus", "Cassia", "Spieler"]],
		"I-04":["Der Freund meines Vaters", "Schmiede des Sextus", ["Silvanus", "Sextus", "Spieler"]],
		"I-05":["Sieh hin, bevor du Kraft brauchst", "Schmiede", ["Sextus", "Spieler"]],
		"I-06":["Ein Preis ist eine Zusage", "Markt Valdora", ["Cassia", "Marcus", "Spieler"]],
	}
	for id: String in expected:
		var row := Bible.mission(id)
		_check(row.get("title", "") == expected[id][0], id + " title follows Band 1")
		_check(row.get("location", "") == expected[id][1], id + " location follows Band 1")
		_check(row.get("cast", []) == expected[id][2], id + " cast follows Band 1")
		_check(str(row.get("source_section", "")).begins_with("Band 1 · Abschnitt „" + id), id + " keeps its screenplay source section")
		_check(not str(row.get("story_core", "")).is_empty(), id + " keeps the authored story core")
	for row: Variant in Bible.band(1).get("main_missions", []):
		_check(row.has("location") and row.has("cast") and row.has("source_section"), "Every Band 1 mission has screenplay metadata: " + str(row.get("id", "")))


func _test_mapping() -> void:
	var step_ids := {}
	for step: Dictionary in Childhood.STEPS:
		step_ids[step.id] = step
	for step_id: String in Childhood.SOURCE_MISSION_BY_STEP:
		_check(step_ids.has(step_id), "Mission map names an existing childhood step: " + step_id)
		_check(not Bible.mission(Childhood.SOURCE_MISSION_BY_STEP[step_id]).is_empty(), "Mapped mission exists: " + step_id)
	_check(Childhood.SOURCE_MISSION_BY_STEP.get("rest_first", "") == "I-05", "Night before the forge lesson belongs to I-05")
	_check(Childhood.SOURCE_MISSION_BY_STEP.get("deliver_hinge", "") == "I-06", "Delivery promise to Cassia belongs to I-06")
	for step_id: String in Childhood.SOURCE_MISSION_BY_STEP:
		var npc := str(step_ids[step_id].get("npc", ""))
		if npc.is_empty() or DOCUMENTED_CAST_DEVIATIONS.has(step_id):
			continue
		var cast: Array = Bible.mission(Childhood.SOURCE_MISSION_BY_STEP[step_id]).get("cast", [])
		_check(ACTOR_NAMES.has(npc) and cast.has(ACTOR_NAMES[npc]), "Speaker of %s is in the Band 1 cast of %s" % [step_id, Childhood.SOURCE_MISSION_BY_STEP[step_id]])


func _test_heading_and_texts() -> void:
	var model = WorldModel.new()
	model.new_game("italia", true, true)
	var view := Childhood.view(model.data)
	_check(view.get("title", "") == "I-01 · Die drei Becher", "Fresh childhood HUD heading is I-01 · Die drei Becher")
	_check(view.get("chapter", "") == "Ein Morgen zu Hause", "Scene chapter remains available")
	_check(view.get("source_mission_id", "") == "I-01", "Fresh childhood starts in I-01")
	_check(Childhood.mission_heading("", "Die Nacht im Dorf") == "Die Nacht im Dorf", "Unmapped steps keep their scene chapter")
	_check(Childhood.mission_heading("I-99", "Kapitel") == "Kapitel", "Unknown mission IDs keep their scene chapter")
	var texts := {}
	for step: Dictionary in Childhood.STEPS:
		texts[step.id] = "%s %s %s %s" % [step.label, step.objective, step.text, step.result]
	_check(texts.mother_morning.contains("sag mir wohin. Nicht weil ich dich halten will – weil du zurückkommen sollst."), "Julia carries her Band 1 I-01 line")
	_check(texts.fill_water.contains("drei Becher"), "I-01 water task fills the three cups")
	_check(texts.father_morning.contains("Mach erst die Arbeit. Reden können wir danach immer noch."), "Silvanus carries his Band 1 I-01 line")
	_check(texts.deliver_food.contains("seinen ältesten Freund"), "I-04 introduces Sextus as Silvanus' oldest friend")
	_check(texts.deliver_kindling.contains("Wenn du etwas nicht kannst, sag es. Dann kann ich es dir zeigen."), "Sextus carries his Band 1 I-04 line")
	_check(texts.smith_trial.contains("Sieh hin, bevor du Kraft brauchst."), "Sextus states the I-05 leitmotiv")
	_check(texts.forge_anvil.contains("Griff") and texts.forge_anvil.contains("Riss"), "I-05 inspects a damaged grip before working it")
	_check(texts.deliver_hinge.contains("Ein Versprechen wiegt genau so viel wie die Ware, die am Ende wirklich ankommt."), "Cassia carries her Band 1 I-06 line")
	_check(Childhood.ITEM_NAMES.checked_hinge == "Geprüfter Truhengriff", "Carried I-05 item is the checked grip")
	# Round 2 alignment (I-04, I-06, I-07, I-09): Band 1 cast and lines, no Fabius/Valeria.
	_check(_npc("woodcutter_request") == "silvanus" and texts.woodcutter_request.contains("Mach erst die Arbeit"), "I-04: Silvanus, not Fabius, sends the player to Sextus")
	_check(texts.market_trade.contains("fünf Säcke aus drei"), "Cassia carries her Band 1 I-06 line 01")
	_check(_npc("patrol_brief") == "decimus" and texts.patrol_brief.contains("Ich brauche eine Zahl, einen Ort und jemanden, der dort wirklich steht."), "I-07: Decimus briefs the patrol with line 07")
	_check(_npc("patrol_report") == "decimus" and texts.patrol_report.contains("Zeig mir, was du weißt. Nicht, was du vermutest."), "I-07: Decimus receives the report with line 01")
	_check(texts.watch_permission.contains("Du musst wissen, wann du stehenbleibst."), "I-07: Silvanus carries line 02")
	_check(texts.family_evening.contains("die wissen, wo du deinen Becher abstellst"), "I-09: Julia carries line 01")
	var all_text := ""
	for step: Dictionary in Childhood.STEPS:
		all_text += JSON.stringify(step)
	_check(not all_text.contains("Valeria") and not all_text.contains("Fabius"), "No authored step names a person absent from all four volumes")
	var evening: Dictionary = Childhood.STEPS.filter(func(step): return step.id == "family_evening")[0]
	_check(evening.visits.sextus.contains("Eine Klinge verzeiht dir keinen Gedanken, den du zu spät hattest."), "I-09: optional visit to Sextus carries line 03")


func _npc(step_id: String) -> String:
	for step: Dictionary in Childhood.STEPS:
		if step.id == step_id:
			return str(step.get("npc", ""))
	return ""
