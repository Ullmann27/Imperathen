extends SceneTree
const Policy = preload("res://scripts/story/life_path_policy.gd")
var checks := 0
var failures := 0

func check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(label)

func _initialize() -> void:
	var original: Dictionary = Policy.new_state("existing-world")
	check(Policy.validate(original), "new state valid")
	check(Policy.new_state("").is_empty(), "blank world rejected")
	check(Policy.new_state("w", "bad").is_empty(), "unknown mode rejected")
	check(Policy.new_state("w", "story", "emperor").is_empty(), "emperor is office, not selectable career")
	check(not Policy.validate({}), "missing fields rejected")
	var state: Dictionary = original.duplicate(true)
	for career in ["soldier", "farmer", "trader", "soldier"]:
		var result: Dictionary = Policy.choose_career(state, career, [career])
		check(result.ok, "earned career accepted: " + career)
		check(result.state.world_id == original.world_id, "world remains continuous")
		check(not result.new_save_slot_required, "career does not restart life")
		state = result.state
	check(original.career == "undecided" and original.revision == 0, "input state is not mutated")
	check(state.known_careers == ["undecided", "soldier", "farmer", "trader"], "career history is stable and deduplicated")
	check(not Policy.choose_career(state, "guard", []).ok, "unearned offers rejected")
	check(not Policy.choose_career(state, "emperor", ["emperor"]).ok, "office cannot be selected as trade")
	check(not Policy.choose_career(state, "soldier", ["soldier"], false).ok, "ended life cannot change profession")
	var open: Dictionary = Policy.choose_continuation(state, "open_world")
	check(open.ok and open.state.continuation == "open_world", "open world remains optional")
	check(not Policy.choose_continuation(state, "realm_campaign", "soldier").ok, "soldier cannot open ruler campaign")
	check(not Policy.choose_continuation(state, "realm_campaign", "general").ok, "general is not emperor")
	var ruler: Dictionary = Policy.choose_continuation(state, "realm_campaign", "emperor")
	check(ruler.ok, "confirmed emperor can enter realm campaign")
	check(Policy.effective_continuation(ruler.state, "emperor") == "realm_campaign", "ruler campaign persists while in office")
	check(Policy.effective_continuation(ruler.state, "none") == "open_world", "loss of office keeps world playable")
	check(ruler.state.continuation == "realm_campaign", "effective fallback does not corrupt save")
	check(Policy.effective_continuation(state, "none", false) == "life_ended", "death is not resurrection")
	var restart: Dictionary = Policy.choose_continuation(state, "new_life")
	check(restart.ok and restart.new_save_slot_required, "new life requires separate slot")
	check(restart.state == state, "restart request leaves old world intact")
	check(Policy.continuation_options(state).has("open_world"), "ordinary career can keep playing")
	check(not Policy.continuation_options(state).has("realm_campaign"), "ruler option hidden until emperor")
	check(Policy.continuation_options(state, "emperor").has("realm_campaign"), "ruler option unlocks")
	var sandbox: Dictionary = Policy.new_state("sandbox", "sandbox")
	check(Policy.validate(sandbox), "sandbox state valid")
	check(not Policy.choose_career(sandbox, "soldier", ["soldier"]).ok, "sandbox cannot advance careers")
	check(not Policy.choose_continuation(sandbox, "personal_story").ok, "sandbox does not enter saved story")
	check(not Policy.choose_continuation(sandbox, "realm_campaign", "emperor").ok, "sandbox bypass does not open campaign")
	check(Policy.validate(JSON.parse_string(JSON.stringify(state))), "JSON round trip survives number conversion")
	for bad_revision in [-1, 1.25, "0"]:
		var invalid: Dictionary = state.duplicate(true)
		invalid.revision = bad_revision
		check(not Policy.validate(invalid), "invalid revision rejected")
	check(Policy.elapsed_years(-58, -52) == 6, "six childhood years")
	check(Policy.elapsed_years(-1, 1) == 1, "historical calendar has no year zero")
	check(Policy.elapsed_years(-58, 80) == 137, "Colosseum chronology")
	check(Policy.age_at_year(12, -58, 80) == 149, "same boy cannot plausibly span Colosseum date")
	check(Policy.age_at_year(12, -58, -27) == 43, "Augustan transition age")
	check(Policy.elapsed_years(0, 80) == -1, "year zero rejected")
	check(Policy.elapsed_years(80, -58) == -1, "reverse life chronology rejected")
	check(not Policy.asset_available("story", -58, 80), "Colosseum unavailable in childhood story")
	check(Policy.asset_available("sandbox", -58, 80), "mixed-era sandbox permits Colosseum")
	check(Policy.asset_available("story", 80, 80), "construction boundary inclusive")
	check(not Policy.asset_available("story", 81, -27, 80), "late date bound respected")
	check(not Policy.asset_available("story", -58, 0), "unknown date requires curation")
	print("LIFE_PATH_POLICY_RESULT checks=%d failures=%d" % [checks, failures])
	quit(0 if failures == 0 else 1)
