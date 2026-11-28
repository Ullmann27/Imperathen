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

func _initialize() -> void:
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
	quit(0 if failures == 0 else 1)
