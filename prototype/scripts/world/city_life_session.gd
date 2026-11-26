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
	if offset < int(candidate.state.now) or (world_id.is_empty() and Calendar.year_of(int(clock.jdn)) != candidate.year):
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
		if world_id.is_empty():
			return _reject_clock("era_rebuild_required")
		# Finish the old year under its own rules before changing its index.
		var next_year := Calendar.add_years(life.year, 1)
		var boundary := (Calendar.first_day_of_year(next_year) - int(life.state.origin_jdn)) * Calendar.DAY_SECONDS
		if int(life.state.t) < boundary - 1:
			last_sync = life.advance_to(boundary - 1, clampi(budget_usec, 1, MAX_FRAME_BUDGET_USEC))
			last_sync["ok"] = true
			last_sync["done"] = false
			return last_sync.duplicate(true)
		if not life.enter_year(next_year):
			return _reject_clock("era_rebuild_required")
		# Persist the new year only after its boundary has actually been reached.
		last_sync = life.advance_to(boundary, clampi(budget_usec, 1, MAX_FRAME_BUDGET_USEC))
		last_sync["ok"] = true
		last_sync["done"] = false
		return last_sync.duplicate(true)
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


## A specific campaign generation owns this simulation. A second open view
## may catch up independently, but may never overwrite a newer checkpoint.
var world_id := ""
var generation := 0
var opening_trade_balance := 0
const Trade := preload("res://scripts/city_trade.gd")
const Checkpoint := preload("res://scripts/domain/city_checkpoint.gd")

func open_campaign(world: Dictionary, scene_nodes: Callable) -> bool:
	var clock: Dictionary = world.calendar.clock
	var record: Dictionary = world.world_state.get("city", {})
	world_id = str(world.world_id)
	if record.is_empty():
		opening_trade_balance = Trade.money_effect(world, true)
		return start(clock, 20261126, scene_nodes)
	var saved := Checkpoint.unpack_city(record)
	if saved.is_empty() or not restore(clock, saved, scene_nodes):
		return false
	generation = int(record.generation)
	opening_trade_balance = int(record.opening_denarii)
	return true

func owns(world: Dictionary) -> bool:
	return life != null and world_id == str(world.world_id) and generation == int(world.world_state.get("city", {}).get("generation", 0))

func quote(shop_id: String, item_id: String) -> Dictionary:
	var number := life.business_for_shop(shop_id)
	if number < 0:
		return {}
	var good := life.player_trade_good(number, item_id)
	if good.is_empty():
		return {}
	var business: Dictionary = life.state.businesses[number]
	var reason := ""
	if not bool(last_sync.get("done", false)):
		reason = "Der Stadtbetrieb holt die Weltzeit auf."
	elif not life.business_open(number, int(life.state.t)):
		reason = "Der Stand ist geschlossen oder noch unbesetzt."
	return {"stock": int(business.stock[good]), "reason": reason,
		"funds": (int(business.till) + int(life.state.households[int(business.owner)].funds)) / int(life.economy.currency.per_denarius)}

## Only a successful atomic save adopts these cloned billing records.
## Booking never touches routing, occupancy or the scheduler.
func stage_trade(shop_id: String, item_id: String, quantity: int, denarii: int, buying: bool) -> Dictionary:
	var stage := Life.new()
	stage.economy = life.economy
	stage.state = life.save_state()
	return stage.state if stage.record_player_trade(shop_id, item_id, quantity, denarii, buying) else {}

static var _quadrantes := 0

static func quadrantes_per_denarius() -> int:
	if _quadrantes == 0:
		var catalogue: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(Life.ECONOMY_PATH))
		_quadrantes = int(catalogue.currency.per_denarius)
	return _quadrantes
