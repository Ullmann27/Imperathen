extends SceneTree
## Raiders approach through the real north gate of the production village.
## Real GameWorld geometry and colliders, 60-Hz physics, the authoritative raid
## clock in WorldModel.advance and the production observe/advance/sync order.
## Usage: --script res://tests/raid_route_world_test.gd -- part=a|b|c
##   part a: obstacle-model drift guard, street edges swept in physics,
##           rules-only route (raids 1-4), physical raids 1 and 2.
##   part b: physical raids 3 and 4 (five and six raiders).
##   part c: childhood night raid played through its real chapter commands,
##           pursuit through the gate when the player stands behind the palisade.

const Model = preload("res://scripts/domain/world_model.gd")
const World = preload("res://scripts/world/game_world.gd")
const Life = preload("res://scripts/story/village_life.gd")
const Route = preload("res://scripts/domain/raid_route.gd")
const Strike = preload("res://scripts/domain/raider_strike.gd")
const Layout = preload("res://scripts/world/village/village_layout.gd")
const Childhood = preload("res://scripts/story/village_childhood.gd")
const SCREENPLAY_ACTIONS := {"i02_basket":"basket_check", "i02_correct":"basket_correct", "i03_marcus":"marcus_friend",
	"i07_water_fetch":"i07_water_fetch", "i07_water_bring":"i07_water_bring", "i08_tracks":"i08_inspect", "i08_report":"i08_report"}
const DT := 1.0/60.0
const PLAYER_AT := Vector3(-14.0,0.91,-2.0)
const HOLD_AFTER_ARRIVAL := 5.0
var checks := 0
var failures: Array[String] = []
var report := {}


func _initialize() -> void:
	_run.call_deferred()


func _check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures.append(message)
		push_error(message)


func _run() -> void:
	var part := "a"
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("part="):
			part = argument.trim_prefix("part=")
	if part == "a":
		await _check_obstacle_model()
		_check_rules_route()
		_check_guard_sight()
		report["physical_raids"] = [await _physical_raid(1,false), await _physical_raid(2,false)]
	elif part == "b":
		report["physical_raids"] = [await _physical_raid(3,false), await _physical_raid(4,false)]
	else:
		report["physical_raids"] = [await _physical_raid(1,true)]
		await _check_pursuit_through_gate()
	var evidence := OS.get_environment("IMPERATHEN_RAID_EVIDENCE")
	if not evidence.is_empty():
		var file := FileAccess.open(evidence,FileAccess.WRITE)
		file.store_string(JSON.stringify(report,"  "))
		file.close()
	for raid: Dictionary in report.physical_raids:
		print("RAID %d %s raiders=%d arrivals_s=%s defeated=%s house_inside=%d max_static_penetration_m=%.4f gate_crossings=%s min_player_m=%.2f" % [raid.number,raid.mode,raid.raiders,str(raid.arrival_s),str(raid.defeated_by_guards),raid.house_inside_samples,raid.max_static_penetration_m,str(raid.gate_crossing_x),raid.min_player_distance_m])
	print("Raid route world (%s): %d checks, %d failed" % [part,checks,failures.size()])
	for failure in failures:
		print("FAIL ",failure)
	quit(0 if failures.is_empty() else 1)


func _new_world(model: Model) -> Node3D:
	var world := World.new()
	root.add_child(world)
	world.setup(model.data)
	world.set_active(true)
	world.set_mode("person")
	world.set_raid_physics_authority(true)
	model.raid_observations = world.raid_observations
	model.combat_sight_check = world.combat_sight_clear
	model.combat_motion_check = world.combat_safe_motion
	model.npc_sight_check = world.npc_sight_clear
	model.npc_observations = world.npc_observations
	return world


func _raid_model(number: int, childhood: bool, action_combat := true) -> Model:
	var model := Model.new()
	if childhood:
		# The production new game, played through its real chapter commands up
		# to the explicitly released night raid (raid number 1).
		model.new_game("italia",true,true)
		_check(_play_childhood_to_night(model),"The childhood chapter reaches its released night raid through real commands")
	else:
		# Legacy village career with the modern combat clock: raids 1-4 occur here.
		model.new_game("italia",true,false,action_combat)
	# Navigation measurement: an empty granary (booked through the ledger) keeps
	# the raid running, so every raider has to reach the loot point itself.
	Life._pay(model.data,{"grain":int(model.data.resources.grain)})
	if not childhood:
		model.data.village.raid.number = number-1
		Life._begin_warning(model.data)
		Life._begin_raid(model.data)
	model.set_player_position(PLAYER_AT)
	return model


func _play_childhood_to_night(model: Model) -> bool:
	# Same command sequence as tests/village_childhood_test.gd (_complete).
	for _attempt in Childhood.STEPS.size()+16:
		var view: Dictionary = Childhood.view(model.data)
		if view.is_empty():
			return false
		if bool(view.get("night_raid_pending",false)):
			return model.execute("village_childhood_begin_raid").ok and model.data.village.raid.active
		var stage := str(view.get("stage",""))
		var point: Vector2 = view.point
		model.set_player_position(Vector3(point.x,1.0,point.y))
		if SCREENPLAY_ACTIONS.has(stage):
			if not _meet(model,str(view.get("target_npc",""))):
				return false
			if not model.execute("village_childhood_action",{"action_id":SCREENPLAY_ACTIONS[stage]}).ok:
				return false
			continue
		if int(view.completed_steps) >= Childhood.STEPS.size():
			return false
		var step: Dictionary = Childhood.STEPS[int(view.completed_steps)]
		if step.has("npc") and not _meet(model,str(step.npc)):
			return false
		if step.has("seconds"):
			if not model.execute("village_childhood_action",{"action_id":"begin_"+str(step.id)}).ok:
				return false
			model.advance(float(step.seconds))
		var action := "market_fair" if step.id == "market_trade" else str(step.id)
		if not model.execute("village_childhood_action",{"action_id":action}).ok:
			return false
	return false


func _meet(model: Model, id: String) -> bool:
	if id.is_empty():
		return true
	var at := Life.actor_position(model.data,id)
	model.set_player_position(Vector3(at.x,1.0,at.y))
	return Life.relationship(model.data,id).get("met",false) or model.execute("village_talk",{"npc_id":id,"choice":"meet"}).ok


func _physical_raid(number: int, childhood: bool) -> Dictionary:
	var started := Time.get_ticks_msec()
	var model := _raid_model(number,childhood)
	var mode := "childhood" if childhood else "legacy"
	_check(model._validate_state(model.data).is_empty(),"Raid %d (%s) fixture is a valid authoritative world" % [number,mode])
	var world := _new_world(model)
	await physics_frame
	# Only cosmetic skeletal animation is paused; every collider, resident route
	# and the raid bodies keep running on the physics clock.
	for figure: Node in get_nodes_in_group("village_people"):
		figure.set_process(false)
	var ids: Array[String] = []
	var spawns := {}
	for enemy: Dictionary in model.data.village.raid.enemies:
		ids.append(str(enemy.id))
		spawns[str(enemy.id)] = [float(enemy.x),float(enemy.z)]
	var arrival := {}
	var gate := {}
	var previous := {}
	var house_inside := 0
	var max_penetration := 0.0
	var penetration_where := ""
	var min_player_distance := INF
	var tracks := {}
	for id in ids:
		tracks[id] = []
	var space := world.get_world_3d().direct_space_state
	var probe := CapsuleShape3D.new()
	probe.radius = Route.RADIUS
	probe.height = 1.8
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = probe
	query.collision_mask = 1
	query.margin = 0.0
	var refresh := 0.0
	var all_arrived_at := INF
	var frames := int((Life.RAID_SECONDS+1.0)/DT)
	for frame in frames:
		await physics_frame
		# Same order as main.gd: observed bodies -> authoritative tick -> projection.
		model.set_player_position(world.get_player_position())
		model.advance(DT)
		world.sync_combat_state(model.data)
		world.set_frontier_time(float(model.data.world_seconds))
		refresh += DT
		if refresh >= .12:
			refresh = 0.0
			world.sync_state(model.data)
		if not model.data.village.raid.active:
			break
		var raiders: Dictionary = world.village_life_world.raiders
		var exclude: Array[RID] = []
		for id in ids:
			if raiders.has(id):
				exclude.append((raiders[id] as CollisionObject3D).get_rid())
		var player: Vector3 = world.get_player_position()
		for id in ids:
			if not raiders.has(id):
				continue
			var actor: CharacterBody3D = raiders[id]
			var at := Vector2(actor.global_position.x,actor.global_position.z)
			min_player_distance = minf(min_player_distance,at.distance_to(Vector2(player.x,player.z)))
			if not arrival.has(id) and at.distance_to(Route.LOOT) < Route.LOOT_RADIUS:
				arrival[id] = snappedf(float(frame+1)*DT,.01)
			if previous.has(id) and (previous[id] as Vector2).y < -49.0 and at.y >= -49.0:
				gate[id] = snappedf(at.x,.01)
			previous[id] = at
			if Route._house_index(at) >= 0:
				house_inside += 1
			query.transform = Transform3D(Basis.IDENTITY,actor.global_position+Vector3.UP*.9)
			query.exclude = exclude
			var pairs := space.collide_shape(query,16)
			for index in range(0,pairs.size(),2):
				var depth: float = (pairs[index] as Vector3).distance_to(pairs[index+1])
				if depth > max_penetration:
					max_penetration = depth
					penetration_where = "%s at (%.2f,%.2f)" % [id,at.x,at.y]
			if frame % 60 == 0:
				tracks[id].append([snappedf(at.x,.01),snappedf(at.y,.01)])
		var settled := arrival.size()
		for enemy: Dictionary in model.data.village.raid.enemies:
			if int(enemy.health) <= 0 and not arrival.has(str(enemy.id)):
				settled += 1
		if settled == ids.size() and not is_finite(all_arrived_at):
			all_arrived_at = float(frame+1)*DT
		if float(frame+1)*DT >= all_arrived_at+HOLD_AFTER_ARRIVAL:
			break
	var arrivals := []
	var gates := []
	var defeated := []
	for id in ids:
		arrivals.append(arrival.get(id,-1.0))
		gates.append(gate.get(id,null))
		var health := 0
		for enemy: Dictionary in model.data.village.raid.enemies:
			if str(enemy.id) == id:
				health = int(enemy.health)
		if health <= 0:
			defeated.append(id)
		if childhood and health <= 0 and not arrival.has(id):
			# The childhood village has a ready, staffed watch post; its guards
			# may legitimately stop a raider on the way in.
			continue
		_check(arrival.has(id),"Raid %d (%s): raider %s from %s reaches the loot radius within %d s" % [number,mode,id,str(spawns[id]),int(Life.RAID_SECONDS)])
		_check(gate.has(id) and absf(float(gate[id])) < 1.75,"Raid %d (%s): raider %s crosses the palisade line inside the north gate (x=%s)" % [number,mode,id,str(gate.get(id,"none"))])
		if raiders_still(world,id):
			var actor: Node3D = world.village_life_world.raiders[id]
			_check(Vector2(actor.global_position.x,actor.global_position.z).distance_to(Route.LOOT) < Route.LOOT_RADIUS,"Raid %d (%s): raider %s stays at the granary after arriving" % [number,mode,id])
	_check(min_player_distance > Life.RAIDER_CHASE_RADIUS,"Raid %d (%s): the player stays farther than 7 m from every raider (%.2f m)" % [number,mode,min_player_distance])
	_check(house_inside == 0,"Raid %d (%s): no raider centre is ever inside a house footprint (%d samples)" % [number,mode,house_inside])
	_check(max_penetration < .005,"Raid %d (%s): no raider capsule overlaps static geometry (max %.4f m %s)" % [number,mode,max_penetration,penetration_where])
	_check(model._validate_state(model.data).is_empty(),"Raid %d (%s): the observed raid keeps the complete save schema" % [number,mode])
	for enemy: Dictionary in model.data.village.raid.enemies:
		_check(enemy.keys().size() == 7,"Raid %d (%s): saved raider entries keep exactly their seven v1 fields" % [number,mode])
	var result := {"number":number,"mode":mode,"raiders":ids.size(),"spawns":spawns,"arrival_s":arrivals,"gate_crossing_x":gates,"defeated_by_guards":defeated,
		"house_inside_samples":house_inside,"max_static_penetration_m":max_penetration,"penetration_where":penetration_where,
		"min_player_distance_m":min_player_distance,"tracks_1hz":tracks,"wall_seconds":float(Time.get_ticks_msec()-started)/1000.0}
	world.queue_free()
	await process_frame
	await process_frame
	return result


func raiders_still(world: Node3D, id: String) -> bool:
	return world.village_life_world.raiders.has(id) and (world.village_life_world.raiders[id] as Node3D).visible


func _check_obstacle_model() -> void:
	# Drift guard: the stateless route plans with a static village plan. Every
	# real static collider at body height inside the village and on the north
	# approach must lie inside that plan, otherwise a shortcut could be planned
	# through an unmodelled prop.
	var model := _raid_model(1,false)
	var world := _new_world(model)
	await physics_frame
	await physics_frame
	var plan: Array[Rect2] = Route.obstacles()
	var uncovered := PackedStringArray()
	var region := Rect2(-30.0,-110.0,86.0,146.0)
	for shape_node: CollisionShape3D in world.find_children("*","CollisionShape3D",true,false):
		var body := shape_node.get_parent() as CollisionObject3D
		if body == null or not (body is StaticBody3D) or body.collision_layer & 1 == 0 or shape_node.disabled or not body.is_visible_in_tree():
			continue
		var box := _shape_aabb(shape_node)
		if box.end.y < .1 or box.position.y > 1.9 or box.size.x > 40.0 or box.size.z > 40.0:
			continue
		var footprint := Rect2(box.position.x,box.position.z,box.size.x,box.size.z)
		if not region.intersects(footprint):
			continue
		var covered := false
		for rect: Rect2 in plan:
			if rect.grow(.06).encloses(footprint):
				covered = true
				break
		if not covered:
			uncovered.append("%s %s" % [str(world.get_path_to(body)),str(footprint)])
	_check(uncovered.is_empty(),"Every static collider at body height is part of the raid route plan: %s" % ", ".join(uncovered))
	# Every street edge is walkable by the real raider capsule (static geometry).
	var space := world.get_world_3d().direct_space_state
	var capsule := CapsuleShape3D.new()
	capsule.radius = Route.RADIUS
	capsule.height = 1.7
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = capsule
	query.collision_mask = 1
	query.margin = .01
	var edges := 0
	var blocked := PackedStringArray()
	for a in Route.NODES.size():
		var node: Vector2 = Route.NODES[a]
		query.transform = Transform3D(Basis.IDENTITY,Vector3(node.x,.95,node.y))
		query.motion = Vector3.ZERO
		_check(space.intersect_shape(query,1).is_empty(),"Street point %d %s is free for a raider capsule" % [a,str(node)])
		for b in range(a+1,Route.NODES.size()):
			if not Route.edge(a,b):
				continue
			edges += 1
			var other: Vector2 = Route.NODES[b]
			query.motion = Vector3(other.x-node.x,0,other.y-node.y)
			var fraction := space.cast_motion(query)
			if fraction.size() != 2 or float(fraction[0]) < 1.0:
				blocked.append("%d-%d" % [a,b])
	_check(edges >= 60 and blocked.is_empty(),"All %d street edges are swept free of static geometry (blocked: %s)" % [edges,",".join(blocked)])
	report["street_edges"] = edges
	world.queue_free()
	await process_frame


func _shape_aabb(shape_node: CollisionShape3D) -> AABB:
	var shape := shape_node.shape
	var local := AABB()
	if shape is BoxShape3D:
		local = AABB(-shape.size*.5,shape.size)
	elif shape is CylinderShape3D or shape is CapsuleShape3D:
		local = AABB(Vector3(-shape.radius,-shape.height*.5,-shape.radius),Vector3(shape.radius*2.0,shape.height,shape.radius*2.0))
	elif shape is SphereShape3D:
		local = AABB(Vector3.ONE*-shape.radius,Vector3.ONE*shape.radius*2.0)
	else:
		var mesh := shape.get_debug_mesh()
		local = mesh.get_aabb() if mesh != null else AABB()
	return shape_node.global_transform*local


func _check_rules_route() -> void:
	# Without a world (rules-only simulation) raiders follow the same route.
	var rules := []
	for number in [1,2,3,4]:
		# The older combat has no world motion check, so the rules move the raiders.
		var model := _raid_model(number,false,false)
		var data: Dictionary = model.data
		var arrival := {}
		var gate := {}
		var inside := 0
		for tick in int(Life.RAID_SECONDS/Life.STEP):
			var before := {}
			for enemy: Dictionary in data.village.raid.enemies:
				before[enemy.id] = Vector2(enemy.x,enemy.z)
			Life.advance(data,Life.STEP)
			if not data.village.raid.active:
				break
			for enemy: Dictionary in data.village.raid.enemies:
				var at := Vector2(enemy.x,enemy.z)
				if not arrival.has(enemy.id) and at.distance_to(Route.LOOT) < Route.LOOT_RADIUS:
					arrival[enemy.id] = snappedf(float(tick+1)*Life.STEP,.01)
				if (before[enemy.id] as Vector2).y < -49.0 and at.y >= -49.0:
					gate[enemy.id] = at.x
				for rect: Rect2 in Route.obstacles():
					if rect.has_point(at):
						inside += 1
		for enemy: Dictionary in data.village.raid.enemies:
			_check(arrival.has(enemy.id),"Rules-only raid %d: %s reaches the loot radius within 150 s" % [number,enemy.id])
			_check(gate.has(enemy.id) and absf(float(gate[enemy.id])) < 1.75,"Rules-only raid %d: %s enters through the north gate" % [number,enemy.id])
		_check(inside == 0,"Rules-only raid %d: no rule position lies inside a wall, house or yard" % number)
		rules.append({"number":number,"arrival_s":arrival})
	report["rules_only"] = rules
	# Stateless: the next waypoint is a pure function of position and goal.
	var at := Vector2(10.0,-60.0)
	var goal := Route.loot_point("raid_4_3")
	_check(Route.next_waypoint(at,goal) == Route.next_waypoint(at,goal) and Route.next_waypoint(at,goal) == Route.NODES[0],"A raider in the northern field heads for the outer gate point")
	_check(Route.next_waypoint(Vector2(10.0,-49.8),goal) == Route.NODES[0],"A raider pressed against the fence walks back to the gate instead of into the palisade")
	_check(Route.next_waypoint(Vector2(0.0,-52.5),goal) != Vector2(0.0,-52.5),"Standing on a street point never yields a zero-length leg")


func _guard_damage(raider_at: Vector2) -> int:
	# Two ready watch-post guards at (+-1.2,-45.9); one live raider at
	# raider_at, the player far away; exactly one guard support cycle.
	var model := _raid_model(1,false,false)
	var data: Dictionary = model.data
	data.village.economy.workplaces.watchpost.condition = 100
	var guards := 0
	for person: Dictionary in data.village.economy.people:
		if guards < 2 and bool(person.alive) and str(person.id) != str(data.village.raid.rescue_person_id):
			person.assignment = "watchpost"
			person.health = 100
			person.hunger = 0
			guards += 1
		elif person.assignment in ["watchpost","defense"]:
			person.assignment = "idle"
	for index in data.village.raid.enemies.size():
		var enemy: Dictionary = data.village.raid.enemies[index]
		enemy.x = raider_at.x if index == 0 else -60.0
		enemy.z = raider_at.y if index == 0 else -105.0
		if index > 0:
			enemy.health = 0
	data.village.raid.guard_clock = 2.95
	Life.advance(data,Life.STEP)
	return 45-int(data.village.raid.enemies[0].health)


func _check_guard_sight() -> void:
	var behind := _guard_damage(Vector2(8.0,-51.0))
	var gate := _guard_damage(Vector2(0.0,-50.5))
	var inside := _guard_damage(Vector2(0.0,-48.0))
	_check(behind == 0,"Guards behind the palisade do no damage to a raider outside it (%d)" % behind)
	_check(gate == 4 and inside == 4,"Guards with a free line through the open gate keep their damage (%d, %d)" % [gate,inside])
	report["guard_damage_behind_palisade"] = behind
	report["guard_damage_free_line"] = [gate,inside]


func _check_pursuit_through_gate() -> void:
	# The player stands inside, 6 m from a raider outside the palisade: the
	# raider must go round through the gate, not press against the fence.
	var model := _raid_model(1,false)
	for index in model.data.village.raid.enemies.size():
		var enemy: Dictionary = model.data.village.raid.enemies[index]
		enemy.x = 6.0 if index == 0 else -40.0-index*3.0
		enemy.z = -53.0 if index == 0 else -100.0
	var inside := Vector3(3.6,.91,-47.6)
	model.set_player_position(inside)
	var world := _new_world(model)
	world.get_node("Player").position = inside
	await physics_frame
	for figure: Node in get_nodes_in_group("village_people"):
		figure.set_process(false)
	var first: String = model.data.village.raid.enemies[0].id
	var actor: CharacterBody3D = world.village_life_world.raiders[first]
	var reached := -1.0
	var min_fence_distance := INF
	for frame in int(30.0/DT):
		await physics_frame
		model.set_player_position(world.get_player_position())
		model.advance(DT)
		world.sync_combat_state(model.data)
		var at := Vector2(actor.global_position.x,actor.global_position.z)
		if at.y < -49.0:
			min_fence_distance = minf(min_fence_distance,absf(at.y+49.0))
		if at.distance_to(Vector2(inside.x,inside.z)) <= Strike.reach():
			reached = float(frame+1)*DT
			break
	_check(reached > 0.0 and reached < 25.0,"A pursuing raider walks round through the gate to a player behind the palisade (%.1f s)" % reached)
	report["pursuit_through_gate_s"] = reached
	world.queue_free()
	await process_frame
