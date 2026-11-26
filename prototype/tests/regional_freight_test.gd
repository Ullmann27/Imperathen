extends "res://tests/campaign_market_visit_test.gd"
## The normal Main interaction at the loading desk pays and saves. This fixture
## then observes the production wagon along the real terrain as the model runs.
const Freight = preload("res://scripts/domain/regional_freight.gd")
const Economy = preload("res://scripts/domain/village_economy.gd")
const Model = preload("res://scripts/domain/world_model.gd")
const Road = preload("res://scripts/world/regional_footpath.gd")
const Checkpoint := "user://fracht_unterwegs.json"
const AtGate := "user://fracht_am_osttor.json"

func _visit() -> void:
	var world: Node3D = game.world
	var terrain: Node3D = world.regional_terrain
	var player: CharacterBody3D = world.get_node("Player")
	var stop: Node3D = terrain.waystation
	game.set_process(false)
	game.set_physics_process(false)
	world.set_physics_process(false)
	var original: Dictionary = game.model.data.duplicate(true)
	expect(not game.model.execute("village_dispatch_grain",{},"fern").ok and game.model.data == original,"Fernbestellung außerhalb des Frachttisches vollständig verworfen")
	var poor := Model.new()
	poor.new_game("italia",true,true,false,true)
	poor.set_player_position(Vector3(Freight.DESK.x,1,Freight.DESK.y))
	var no_money: Dictionary = poor.data.duplicate(true)
	expect(not poor.execute("village_dispatch_grain",{},"ohne_denare").ok and poor.data == no_money,"Ohne Denare bleiben Vorrat und Kasse unberührt")
	var start := Vector3(Freight.DESK.x,float(terrain.surface_height(Freight.DESK))+1,Freight.DESK.y-1.35)
	player.position = start
	game.model.set_player_position(start)
	terrain.follow(start,"low")
	stop.update_nearby(start,{})
	world._update_context_hint()
	var price := Economy.emergency_food_price(game.model.data)
	expect(str(world._hint.text).contains(str(price)+" Denare"),"Interaktionshinweis nennt verbindlichen Preis")
	world.perform_interaction()
	var state: Dictionary = game.model.data
	if not expect(state.village.economy.has("freight"),"Tisch löst den regionalen Frachtauftrag über Main aus"):
		return
	var receipt: Dictionary = state.village.economy.freight
	var command_id := "%s_%d" % [game.run_id,game.command_serial]
	expect(receipt.sent == 1 and receipt.received == 0 and receipt.leg == Freight.OUTBOUND and receipt.price == price,"Ein einzelner Ladeschein startet eine Fahrt")
	expect(state.resources.denarii == original.resources.denarii-price and state.resources.grain == original.resources.grain and state.village.economy.stocks.emergency_grain == original.village.economy.stocks.emergency_grain-Freight.LOAD and state.village.economy.stocks.merchant_denarii == original.village.economy.stocks.merchant_denarii+price,"Abgang von 16 Getreide und ausgeglichene Zahlung zwischen zwei bestehenden Beständen")
	var paid: Dictionary = state.duplicate(true)
	expect(game.model.execute("village_dispatch_grain",{},command_id).ok and game.model.data == paid and not game.model.execute("village_dispatch_grain",{},"zweiter_wagen").ok and game.model.data == paid,"Wiederholung und Zweitbestellung verursachen keine weitere Buchung")
	var elapsed := 0.0
	var length := 0.0
	var poses := 0
	var sectors := {}
	var ground_error := 0.0
	var previous := Freight.LOADING_BAY
	var reloaded := false
	var received_gain := 0
	var return_balance := 0
	var capture_camera: Camera3D
	if not capture_dir.is_empty():
		capture_camera = Camera3D.new()
		root.add_child(capture_camera)
	var travel_time := Freight.length_m()/Freight.SPEED
	while elapsed < travel_time-.00001:
		# The final step touches the loading boundary exactly. Background
		# businesses cannot receive an additional time slice before inspection.
		var dt := minf(1.0,travel_time-elapsed)
		var before_grain: int = game.model.data.resources.grain
		game.model.advance(dt)
		elapsed += dt
		state = game.model.data
		receipt = state.village.economy.freight
		var here: Vector2 = Freight.pose(receipt).position
		var observation := Vector3(here.x,terrain.surface_height(here)+1,here.y)
		terrain.follow(observation,"low")
		stop.update_nearby(observation,receipt,dt)
		var wagon: AnimatableBody3D = stop.get_node("FreightWagon")
		var real := Vector2(wagon.global_position.x,wagon.global_position.z)
		length += previous.distance_to(real)
		ground_error = maxf(ground_error,absf(wagon.global_position.y-terrain.surface_height(real)))
		sectors[preload("res://scripts/world/world_stream_plan.gd").sector_for_position(observation)] = true
		poses += 1
		previous = real
		if not reloaded and elapsed > travel_time*.36:
			expect(wagon.get_node("SixGrainSacks").visible,"Gebuchte Ladung sitzt sichtbar auf dem Wagen")
			var before_reload: Dictionary = receipt.duplicate(true)
			var saved: Dictionary = game.model.save_game(Checkpoint)
			var restored: Dictionary = game.model.load_game(Checkpoint)
			var after_load: Dictionary = game.model.data.village.economy.freight
			expect(saved.ok and restored.ok and after_load.leg == before_reload.leg and is_equal_approx(after_load.metres,before_reload.metres) and int(after_load.sent) == int(before_reload.sent) and int(after_load.received) == int(before_reload.received) and int(after_load.price) == int(before_reload.price),"Unterwegs gespeichert und mit derselben Fracht und Position geladen")
			# Stream the vehicle out, then back at its current point.
			stop.update_nearby(Vector3(-300,0,-300),before_reload)
			stop.update_nearby(observation,before_reload)
			wagon = stop.get_node("FreightWagon")
			expect(wagon.get_node("SixGrainSacks").visible and Vector2(wagon.global_position.x,wagon.global_position.z).distance_to(real) < .01,"Ein Wagen nach erneutem Laden des Sektors")
			# Standalone capacity boundary at the last ten centimetres: no credit
			# or unloading while the village stock is full.
			var full: Dictionary = game.model.data.duplicate(true)
			full.village.economy.freight.metres = Freight.length_m()-.10
			full.resources.grain = Economy.MAX_RESOURCE
			expect(Economy.advance(full,1.0) and full.village.economy.freight.leg == Freight.OUTBOUND and full.resources.grain == Economy.MAX_RESOURCE and full.village.economy.freight.received == 0,"Volles Ziel hält die ganze Ladung am Tor zurück")
			full.resources.grain -= Freight.LOAD
			expect(Economy.advance(full,.1) and full.village.economy.freight.received == 1 and full.resources.grain == Economy.MAX_RESOURCE,"Bei freiem Platz kommt dieselbe Ladung genau einmal an")
			if is_instance_valid(capture_camera):
				game.ui.hide()
				capture_camera.current = true
				capture_camera.global_position = wagon.global_position + Vector3(-6.3,3.1,4.8)
				capture_camera.look_at(wagon.global_position + Vector3.UP*.9)
				world.look.set_time_of_day(12)
				await capture("getreidewagen")
				game.ui.show()
			reloaded = true
		if receipt.leg == Freight.RETURNING:
			received_gain = int(state.resources.grain)-before_grain
			return_balance = int(state.resources.grain)
	expect(previous.distance_to(Freight.RECEIVING_BAY) < .015 and ground_error < .05 and absf(length-Freight.length_m()) < 1.0,"Wagen fährt den Straßenverlauf bis zum tatsächlichen Osttor und bleibt auf dem Boden")
	expect(receipt.sent == 1 and receipt.received == 1 and received_gain == Freight.LOAD and not stop.get_node("FreightWagon/SixGrainSacks").visible,"Ein Empfang der 16 Getreide am Osttor und sichtbar leerer Rückwagen")
	expect(is_instance_valid(stop.get_node_or_null("EastGateReceivingDesk")) and Freight.status(state.village.economy).contains("quittiert"),"Erreichbarer Empfangstisch und zugehörige Quittung am Ziel")
	var delivered: Dictionary = receipt.duplicate(true)
	expect(game.model.save_game(AtGate).ok and game.model.load_game(AtGate).ok and game.model.data.resources.grain == return_balance and game.model.data.village.economy.freight == delivered,"Quittung übersteht das Laden ohne zweites Ausladen")
	game.model.advance(travel_time+.01)
	expect(game.model.data.village.economy.freight.leg == Freight.READY and game.model.data.village.economy.freight.received == 1,"Leere Rückfahrt zum selben Ausgangspunkt, weiterhin genau eine Quittung")
	var previous_receipts := int(game.model.data.village.economy.freight.received)
	var previous_coins := int(game.model.data.resources.denarii)
	expect(game.model.execute("village_dispatch_grain",{},"neue_fahrt").ok and game.model.data.village.economy.freight.sent == 2 and game.model.data.village.economy.freight.received == previous_receipts and game.model.data.resources.denarii == previous_coins-price,"Nach dem Rückweg kann derselbe Wagen wieder beladen werden")
	if is_instance_valid(capture_camera):
		capture_camera.free()
		world.get_node("WorldCamera").current = true
	print("REGIONAL_FREIGHT ",JSON.stringify({"samples":poses,"length_m":snappedf(length,.01),"duration_s":snappedf(elapsed,.01),"sectors":sectors.size(),"max_ground_error_m":snappedf(ground_error,.0001),"charged":price,"delivered":received_gain,"receipt":receipt.received}))
