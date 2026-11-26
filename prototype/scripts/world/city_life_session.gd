extends RefCounted
## Integration boundary for the city domain. The caller owns the calendar and
## persistence. This object never creates a second campaign clock or save file.
const Life := preload("res://scripts/domain/city_life.gd")
const Calendar := preload("res://scripts/domain/world_calendar.gd")
const MAX_FRAME_BUDGET_USEC := 2000

var life: Life
var last_sync: Dictionary = {}
var error := ""

func start(clock: Dictionary, seed: int, scene_nodes: Callable = Callable()) -> bool:
	if life != null or not Calendar.validate_clock(clock):
		error = "invalid_start"
		return false
	var candidate := Life.new()
	candidate.present_nodes = scene_nodes
	if not candidate.found(seed, int(clock.jdn), int(clock.second)):
		error = candidate.error
		return false
	life = candidate
	error = ""
	return true

func restore(clock: Dictionary, saved: Dictionary, scene_nodes: Callable = Callable()) -> bool:
	if life != null or not Calendar.validate_clock(clock):
		error = "invalid_restore"
		return false
	var candidate := Life.new()
	candidate.present_nodes = scene_nodes
	if not candidate.load_state(saved):
		error = candidate.error
		return false
	var offset := (int(clock.jdn) - int(candidate.state.origin_jdn)) * Calendar.DAY_SECONDS + int(clock.second)
	if offset < int(candidate.state.now) or Calendar.year_of(int(clock.jdn)) != candidate.year:
		error = "incompatible_restore_clock"
		return false
	life = candidate
	error = ""
	return true

## Synchronize only to a supplied, validated, monotonic world clock. A change
## of historical year requires a separate population/anchor migration; fail
## closed instead of running the previous era's buildings into a new year.
func _reject_clock(reason: String) -> Dictionary:
	last_sync = {"ok": false, "done": false, "error": reason}
	return last_sync.duplicate(true)

func sync_to(clock: Dictionary, budget_usec: int = MAX_FRAME_BUDGET_USEC) -> Dictionary:
	if life == null or not Calendar.validate_clock(clock):
		return _reject_clock("invalid_clock")
	var offset := (int(clock.jdn) - int(life.state.origin_jdn)) * Calendar.DAY_SECONDS + int(clock.second)
	if offset < int(life.state.now):
		return _reject_clock("clock_reversed")
	if Calendar.year_of(int(clock.jdn)) != life.year:
		return _reject_clock("era_rebuild_required")
	last_sync = life.advance_to(offset, clampi(budget_usec, 1, MAX_FRAME_BUDGET_USEC))
	last_sync["ok"] = true
	return last_sync.duplicate(true)

func trade_error(shop_id: String, item_id: String, quantity: int, denarii: int, buying: bool) -> String:
	if life == null or not bool(last_sync.get("done", false)):
		return "simulation_pending"
	return life.player_trade_error(shop_id, item_id, quantity, denarii, buying)

func book_trade(shop_id: String, item_id: String, quantity: int, denarii: int, buying: bool) -> bool:
	if not trade_error(shop_id, item_id, quantity, denarii, buying).is_empty():
		return false
	return life.record_player_trade(shop_id, item_id, quantity, denarii, buying)

func save_state() -> Dictionary:
	return {} if life == null else life.save_state()

func summary() -> Dictionary:
	return {} if life == null else life.summary()
