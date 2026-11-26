extends RefCounted
## Test support: plays one stage of the I-03 errand through the real
## childhood command on a WorldModel. Bodies are placed like the other model
## tests place the player (fixture placement, no path walking).
const Childhood = preload("res://scripts/story/village_childhood.gd")
const I03 = preload("res://scripts/story/i03_shortcut.gd")
const FRIEND := {"i03_marcus":"i03_together", "i03_coin":"i03_watch", "i03_resolve":"i03_clarify", "i03_farewell":"i03_home_together"}
## An open dispute: contradicted Marcus, no clarification, no apology.
const RIVAL := {"i03_marcus":"i03_apart", "i03_coin":"i03_object", "i03_resolve":"i03_refuse", "i03_farewell":"i03_home_apart"}


static func place_player(model, point: Vector2) -> void:
	model.set_player_position(Vector3(point.x, 1.0, point.y))


static func place_marcus(model, point: Vector2) -> void:
	var people: Dictionary = model.data.village.behavior.people
	if people.has("marcus"):
		people.marcus.position = [point.x, 0.9, point.y]


static func stage(model) -> String:
	return str(Childhood.view(model.data).get("stage", ""))


## Plays the current I-03 stage. `choices` maps stage -> action for the
## decision stages; physical stages have exactly one action.
static func play_stage(model, choices: Dictionary = FRIEND) -> Dictionary:
	var current := stage(model)
	var action := str(choices.get(current, FRIEND.get(current, current)))
	match current:
		"i03_marcus":
			place_marcus(model, I03.POINTS.lane)
			place_player(model, I03.POINTS.lane + Vector2(1.0, 0.0))
		"i03_coin", "i03_resolve", "i03_measure", "i03_service_bring", "i03_farewell":
			var ctx: Dictionary = Childhood.i03_ctx(model.data)
			place_marcus(model, I03.marcus_stall(ctx))
			place_player(model, (ctx.cassia as Vector2) + Vector2(0.0, 2.0))
			if not bool(Childhood.relationship(model.data, "cassia").get("met", false)):
				model.execute("village_talk", {"npc_id":"cassia", "choice":"meet"})
		"i03_service_fetch":
			place_player(model, I03.POINTS.well + Vector2(1.0, 0.0))
		_:
			return {"ok":false, "message":"Not an I-03 stage: " + current}
	return model.execute("village_childhood_action", {"action_id":action})


## Plays the whole Marcus part that precedes Julia's order (lane to the
## agreement at the stall). Returns false when a stage fails.
static func play_errand(model, choices: Dictionary = FRIEND) -> bool:
	for _index in 8:
		var current := stage(model)
		if not current.begins_with("i03_") or current == "i03_farewell":
			return true
		if not bool(play_stage(model, choices).get("ok", false)):
			return false
	return false
