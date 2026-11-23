extends SceneTree

const Bible = preload("res://scripts/story/campaign_bible.gd")
var checks := 0
var failed := 0


func _initialize() -> void:
	run.call_deferred()


func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failed += 1
		push_error(message)


func run() -> void:
	Bible.reset_cache_for_tests()
	check(Bible.project() == "IMPERATHEN — RISE OF AN EMPIRE", "campaign project title")
	check(Bible.main_mission_count() == 113, "113 authored main missions")
	check(Bible.side_quest_count() == 96, "96 authored side quests")
	check(Bible.canonical_actor("mother").get("actor_id", "") == "julia", "Julia is canonical mother actor")
	check(Bible.canonical_actor("father").get("actor_id", "") == "silvanus", "Silvanus is canonical father actor")
	check(Bible.canonical_actor("smith_mentor").get("actor_id", "") == "sextus", "Sextus is canonical smith mentor actor")
	check(Bible.mission("I-10").get("title", "") == "Die Nacht der Reiter", "I-10 raid anchor")
	check(Bible.mission("I-14").get("title", "") == "Der Schwur", "I-14 oath anchor")
	check(Bible.mission("IV-30").get("title", "") == "Die Chronik deines Lebens", "IV-30 final authored mission")
	check(Bible.side_quest("NQ-1-01").get("title", "") == "Ein Pferd kennt seinen Weg", "first side quest")
	check(Bible.band(1).get("main_missions", []).size() == 32, "Band 1 mission count")
	check(Bible.rules().get("start_year_bce", 0) == 58 and Bible.rules().get("start_age", 0) == 12, "campaign starts 58 BCE at age 12")
	check(Bible.mission("not-a-mission").is_empty(), "unknown mission returns empty data")
	print("CAMPAIGN_BIBLE_TEST checks=", checks, " failed=", failed)
	quit(1 if failed else 0)
