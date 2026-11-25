class_name LifePathPolicy
extends RefCounted
## Opt-in design component. Does not migrate or advance existing world saves.

const VERSION := 1
const CAREERS := ["undecided", "farmer", "trader", "artisan", "soldier", "mason", "scout", "woodcutter", "healer", "guard"]
const MODES := ["story", "sandbox"]
const CONTINUATIONS := ["personal_story", "open_world", "realm_campaign"]

static func new_state(world_id: String, play_mode: String = "story", initial_career: String = "undecided") -> Dictionary:
	if world_id.strip_edges().is_empty() or play_mode not in MODES or initial_career not in CAREERS:
		return {}
	return {"version": VERSION, "world_id": world_id, "play_mode": play_mode,
		"career": initial_career, "known_careers": [initial_career],
		"continuation": "open_world" if play_mode == "sandbox" else "personal_story", "revision": 0}

static func validate(state: Dictionary) -> bool:
	if state.get("version") != VERSION or not state.get("world_id") is String:
		return false
	if state.world_id.strip_edges().is_empty() or state.get("play_mode") not in MODES:
		return false
	if state.get("career") not in CAREERS or state.get("continuation") not in CONTINUATIONS:
		return false
	if not state.get("known_careers") is Array or state.career not in state.known_careers:
		return false
	for career in state.known_careers:
		if career not in CAREERS:
			return false
	var revision: Variant = state.get("revision")
	if not (revision is int or revision is float) or revision < 0 or revision != floor(revision):
		return false
	if state.play_mode == "sandbox" and state.continuation != "open_world":
		return false
	return true

static func _rejected(reason: String) -> Dictionary:
	return {"ok": false, "reason": reason}

static func choose_career(state: Dictionary, target: String, earned_offers: Array, alive: bool = true) -> Dictionary:
	if not validate(state):
		return _rejected("invalid_state")
	if not alive:
		return _rejected("life_ended")
	if state.play_mode == "sandbox":
		return _rejected("sandbox_has_no_career_progression")
	if target not in CAREERS or target == "undecided":
		return _rejected("invalid_career")
	if target not in earned_offers:
		return _rejected("career_offer_required")
	var candidate: Dictionary = state.duplicate(true)
	candidate.career = target
	if target not in candidate.known_careers:
		candidate.known_careers.append(target)
	candidate.revision += 1
	return {"ok": true, "state": candidate, "new_save_slot_required": false}

static func choose_continuation(state: Dictionary, choice: String, confirmed_office: String = "none", alive: bool = true) -> Dictionary:
	if not validate(state):
		return _rejected("invalid_state")
	if choice == "new_life":
		return {"ok": true, "state": state.duplicate(true), "new_save_slot_required": true}
	if not alive:
		return _rejected("life_ended")
	if choice not in CONTINUATIONS:
		return _rejected("invalid_continuation")
	if state.play_mode == "sandbox" and choice != "open_world":
		return _rejected("sandbox_is_isolated")
	if choice == "realm_campaign" and confirmed_office != "emperor":
		return _rejected("emperor_office_required")
	var candidate: Dictionary = state.duplicate(true)
	candidate.continuation = choice
	candidate.revision += 1
	return {"ok": true, "state": candidate, "new_save_slot_required": false}

static func effective_continuation(state: Dictionary, confirmed_office: String = "none", alive: bool = true) -> String:
	if not validate(state):
		return "invalid_state"
	if not alive:
		return "life_ended"
	if state.continuation == "realm_campaign" and confirmed_office != "emperor":
		return "open_world"
	return state.continuation

static func continuation_options(state: Dictionary, confirmed_office: String = "none", alive: bool = true) -> Array:
	if not validate(state):
		return []
	if not alive:
		return ["new_life"]
	if state.play_mode == "sandbox":
		return ["open_world", "new_life"]
	var options := ["personal_story", "open_world", "new_life"]
	if confirmed_office == "emperor":
		options.insert(2, "realm_campaign")
	return options

static func elapsed_years(from_year: int, to_year: int) -> int:
	if from_year == 0 or to_year == 0 or to_year < from_year:
		return -1
	return to_year - from_year - (1 if from_year < 0 and to_year > 0 else 0)

static func age_at_year(initial_age: int, initial_year: int, year: int) -> int:
	var elapsed := elapsed_years(initial_year, year)
	return -1 if initial_age < 0 or elapsed < 0 else initial_age + elapsed

static func asset_available(play_mode: String, year: int, earliest_year: int, latest_year: int = 0) -> bool:
	if play_mode == "sandbox":
		return true
	if play_mode != "story" or year == 0 or earliest_year == 0:
		return false
	if latest_year != 0 and latest_year < earliest_year:
		return false
	return year >= earliest_year and (latest_year == 0 or year <= latest_year)
