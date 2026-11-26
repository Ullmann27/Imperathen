extends "res://tests/campaign_market_visit_test.gd"
## Enters and leaves the real market from a migrated I-02 save. The player
## fixture starts by the family house. Only ordinary movement controls move
## the party between the city entry and baker.


func _visit() -> void:
	var father: CharacterBody3D = game.world._story_companions.actor("silvanus")
	var village_parent := father.get_parent()
	var hero: CharacterBody3D = game.world.get_node("Player")
	hero.position = father.position + Vector3(0.9, 0.9, 0)
	game.model.set_player_position(hero.position)
	var result: Dictionary = game.model.execute("party_invite", {"actor_uid":"vil:silvanus"})
	if not expect(result.ok, "Silvanus akzeptiert vor der Reise im Dorf: " + str(result.message)):
		return
	game.world.sync_state(game.model.data)
	game.ui.action_requested.emit("pause", {})
	var travel := button(game.ui, "Stadtmarkt besuchen")
	if not expect(travel != null, "Die Kampagnenreise ist verfügbar"):
		return
	var home := father.position
	travel.pressed.emit()
	var city = game.city_exploration
	if not expect(city != null and city.market.available, "Die bewohnte Kampagnenstadt ist geladen"):
		return
	for tick in 30:
		await physics_frame
		if father.get_parent() == city:
			break
	if not expect(father.get_parent() == city and father.is_visible_in_tree() and father.get_meta("actor_uid") == "vil:silvanus", "Derselbe Silvanus-Körper ist in der Marktstraße angekommen"):
		city._request_leave()
		return
	var original := father.position
	var oldest := original
	var length := 0.0
	var largest_step := 0.0
	var target: Vector3 = city.market.sites.bakery
	for tick in 500:
		var to_stall := Vector2(target.x - city.player.position.x, target.z - city.player.position.z)
		city._touch_move = to_stall.normalized().rotated(city._yaw) if to_stall.length() > 1.9 else Vector2.ZERO
		await physics_frame
		var distance := Vector2(father.position.x-oldest.x,father.position.z-oldest.z).length()
		length += distance
		largest_step = maxf(largest_step, distance)
		oldest = father.position
		if tick > 130 and to_stall.length() <= 1.95 and father.position.distance_to(city.player.position) < 2.2:
			break
	city._touch_move = Vector2.ZERO
	expect(original.distance_to(father.position) > 2.5 and largest_step < 0.13, "Silvanus geht auf derselben Straße ohne Positionssprung zum Bäcker")
	print("PARTY_CITY_METRICS ", JSON.stringify({"walked_m":length, "max_step_m":largest_step, "gap_m":father.position.distance_to(city.player.position)}))
	if not capture_dir.is_empty():
		# The market toolbar waits on the same world clock as the village.
		for hour in 4:
			city._wait_button.pressed.emit()
			if not await _settle(city):
				break
	await capture("04-silvanus-marktweg")
	city._request_leave()
	expect(game.screen == "playing" and father.get_parent() == village_parent and father.position.distance_to(home) < 0.01, "Derselbe Körper kehrt an den Dorfanker zurück")
	expect(game.model.npc_observations.is_valid() and game.model.data.world_state.party.members.has("vil:silvanus"), "Dorfbeobachtung und Personenvertrag sind nach dem Besuch intakt")
	result = game.model.execute("party_order", {"actor_uid":"vil:silvanus", "order":"wait"})
	if not expect(result.ok, "Silvanus wartet auf Wunsch zu Hause"):
		return
	game.ui.action_requested.emit("pause", {})
	button(game.ui, "Stadtmarkt besuchen").pressed.emit()
	city = game.city_exploration
	await physics_frame
	expect(father.get_parent() == village_parent and not father.is_inside_tree() and city.party_visit.passengers.is_empty(), "Der wartende Vater bleibt ohne zweite Darstellung am Dorfanker")
	city._request_leave()
	if errors.is_empty():
		print("PARTY_CITY_PASS")
