extends SceneTree

const Batch := preload("res://scripts/story/mission_event_batch.gd")
const Forge := preload("res://scripts/story/i04_workshop.gd")
const Model := preload("res://scripts/domain/world_model.gd")
const Childhood := preload("res://scripts/story/village_childhood.gd")
var checks: int = 0
var failures: int = 0

func _check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("GENESIS_FAIL: ", message)


func _test_defensive_boundaries() -> void:
	var fields: Array[String] = ["items", "receipts"]
	var events: Array[String] = ["trade.b"]
	var state: Dictionary = {"items":{"basket":"counter"}, "receipts":["trade.a"]}
	var draft: Dictionary = Batch.stage(state, fields)
	_check(Batch.stage(state, ["items", "receipts", "items"]).is_empty(), "duplicate field declaration rejected")
	_check(Batch.stage(state, ["items", 42]).is_empty(), "non-string field declaration rejected without a runtime error")
	_check(Batch.stage(state, [""]).is_empty(), "empty field declaration rejected")
	_check(not Batch.commit(state, ["items", 42], draft, "receipts", events), "commit rejects malformed field declarations")
	_check(state.items.basket == "counter" and state.receipts == ["trade.a"], "malformed declarations cannot change state")

	var wrong_type: Array[int] = []
	var bad_cases: Array = [[42], ["trade.a", "trade.a"], [""], [" "], wrong_type]
	for bad_ledger: Array in bad_cases:
		var damaged: Dictionary = {"items":{"basket":"counter"}, "receipts":bad_ledger}
		var proposal: Dictionary = Batch.stage(damaged, fields)
		proposal.items.basket = "customer"
		var before: String = JSON.stringify(damaged)
		_check(not Batch.commit(damaged, fields, proposal, "receipts", events), "malformed existing ledger rejected: " + str(bad_ledger))
		_check(JSON.stringify(damaged) == before, "malformed existing ledger leaves all fields intact")

	var locked_receipts: Array[String] = ["trade.a"]
	locked_receipts.make_read_only()
	var locked_ledger_state: Dictionary = {"items":{"basket":"counter"}, "receipts":locked_receipts}
	draft = Batch.stage(locked_ledger_state, fields)
	draft.items.basket = "customer"
	_check(not Batch.commit(locked_ledger_state, fields, draft, "receipts", events), "read-only receipt array rejected before item publication")
	_check(locked_ledger_state.items.basket == "counter" and locked_receipts == ["trade.a"], "read-only ledger cannot cause a partial transfer")

	var locked_state: Dictionary = {"items":{"basket":"counter"}, "receipts":["trade.a"]}
	locked_state.make_read_only()
	draft = Batch.stage(locked_state, fields)
	draft.items.basket = "customer"
	_check(not Batch.commit(locked_state, fields, draft, "receipts", events), "read-only state rejected before receipt publication")
	_check(locked_state.items.basket == "counter" and locked_state.receipts == ["trade.a"], "read-only state cannot cause a stray receipt")

	var valid_receipts: Array[String] = ["trade.a"]
	var valid: Dictionary = {"items":{"basket":"counter"}, "receipts":valid_receipts}
	draft = Batch.stage(valid, fields)
	draft.items.basket = "customer"
	var whitespace: Array[String] = [" trade.b "]
	_check(not Batch.commit(valid, fields, draft, "receipts", whitespace), "noncanonical receipt ID rejected")
	_check(valid.items.basket == "counter" and valid_receipts == ["trade.a"], "noncanonical ID cannot transfer an item")
	_check(Batch.commit(valid, fields, draft, "receipts", events), "valid typed string receipt array supported")
	_check(valid.items.basket == "customer" and valid_receipts == ["trade.a","trade.b"], "typed ledger records exactly one transfer")
	draft.items.basket = "tampered"
	draft.receipts.clear()
	_check(valid.items.basket == "customer" and valid.receipts == ["trade.a","trade.b"], "committed state remains detached from scratch data")
	draft = Batch.stage(valid, fields)
	draft.items.basket = "shelf"
	var no_events: Array[String] = []
	_check(Batch.commit(valid, fields, draft, "receipts", no_events), "valid action without a new receipt remains supported")
	_check(valid.items.basket == "shelf" and valid.receipts == ["trade.a","trade.b"], "receiptless action leaves previous ledger unchanged")


func _initialize() -> void:
	_test_defensive_boundaries()
	var source: Dictionary = {"items":{"basket":"counter"}, "receipts":["trade.a"], "age":12}
	var fields: Array[String] = ["items", "receipts"]
	var draft: Dictionary = Batch.stage(source, fields)
	draft.items.basket = "customer"
	var pair: Array[String] = ["trade.b", "trade.a"]
	_check(not Batch.commit(source, fields, draft, "receipts", pair), "late replay rejected")
	_check(source.items.basket == "counter" and source.receipts == ["trade.a"], "no partial item transfer or receipt")
	pair.assign(["trade.b", "trade.b"])
	_check(not Batch.commit(source, fields, draft, "receipts", pair), "in-batch duplicate rejected")
	pair.assign(["trade.b"])
	draft.receipts.clear()
	_check(not Batch.commit(source, fields, draft, "receipts", pair), "cannot erase history")
	draft = Batch.stage(source, fields)
	draft.items.basket = "customer"
	_check(Batch.commit(source, fields, draft, "receipts", pair), "same API accepts another domain vocabulary")
	_check(source.items.basket == "customer" and source.receipts == ["trade.a","trade.b"] and source.age == 12, "only declared fields change")
	_check(not Batch.commit(source, fields, draft, "receipts", pair), "replaying a committed batch fails")
	var corrupt: Dictionary = {"items":{}, "receipts":"not a receipt list"}
	_check(Batch.stage(source, ["typo"]).is_empty(), "missing fields are not invented")
	_check(not Batch.commit(corrupt, fields, Batch.stage(corrupt, fields), "receipts", pair), "corrupt ledger is rejected")
	draft = Batch.stage(source, fields)
	draft.items = "broken"
	_check(not Batch.commit(source, fields, draft, "receipts", pair), "types cannot change")
	draft = Batch.stage(source, fields)
	pair.assign([""])
	_check(not Batch.commit(source, fields, draft, "receipts", pair), "empty receipt rejected")
	var model := Model.new()
	model.new_game("italia", true, true, false, true)
	var world: Dictionary = model.data
	var ctx: Dictionary = Childhood.i04_ctx(world)
	# Place this production domain adapter at the forge gate without changing the live save.
	var fixture: Dictionary = world.duplicate(true)
	fixture.village.childhood.completed.resize(int(ctx.index))
	fixture.village.childhood.screenplay.merge(Forge.fresh_state(), true)
	fixture.player.position = [ctx.sextus.x, 0.0, ctx.sextus.y]
	ctx.sextus_here = true
	fixture.village.childhood.screenplay.i04_events.append("I-04.work.message")
	var before: String = JSON.stringify(fixture)
	_check(not Forge.apply(fixture, "i04_message", ctx).ok and JSON.stringify(fixture) == before, "rejected note never becomes a carried item")
	fixture.village.childhood.screenplay.i04_events.clear()
	var result: Dictionary = Forge.apply(fixture, "i04_message", ctx)
	_check(result.ok and result.carry_add == ["sextus_note"], "approved note uses existing carry authority")
	_check(fixture.village.childhood.screenplay.i04_note == "carried" and result.events == ["I-04.work.message"], "one note, one committed receipt")
	print("GENESIS_MISSION_BATCH_RESULT checks=%d failures=%d" % [checks, failures])
	print("GENESIS_MISSION_BATCH_PASS" if failures == 0 else "GENESIS_MISSION_BATCH_FAIL")
	quit(0 if failures == 0 else 1)
