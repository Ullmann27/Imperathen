extends SceneTree
## Raider blows are telegraphed by the visible swing (D-026): the swing starts
## exactly the wind-up before the blow resolves, the weapon's contact frame
## meets the damage tick, a block shortly after the swing start catches the
## blow, resets never swing, a received hit interrupts the swing with its own
## reaction and a standing raider turns to face the player.
## Real GameWorld, physical raiders, 60-Hz physics, production update order.

const Model = preload("res://scripts/domain/world_model.gd")
const World = preload("res://scripts/world/game_world.gd")
const Life = preload("res://scripts/story/village_life.gd")
const Strike = preload("res://scripts/domain/raider_strike.gd")
const Person = preload("res://scripts/visuals/village_person.gd")
const DT := 1.0/60.0
# Open ground east of the palisade, south of the north ridge foot.
const FIELD := Vector2(40.0,-58.0)
var checks := 0
var failures: Array[String] = []
var report := {}
var model: Model
var world: Node3D
var raider: CharacterBody3D
var figure: Node3D
var enemy_id := ""
var clock := 0.0
var log_events: Array = []
var _open_swing := -1.0
var _open_clip := 0.0
var _last_cues := 0
var _last_health := 0
var _last_blocks := 0
var _last_dodges := 0
var _last_timer := 0.0
var swings := 0
var orphan_swings := 0
var misses := 0
var interrupted := 0
var windups: Array[float] = []
var contact_errors: Array[float] = []
var hit_distances: Array[float] = []


func _initialize() -> void:
	_run.call_deferred()


func _check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures.append(message)
		push_error(message)


func _run() -> void:
	await _measure_clips()
	await _blow_continuity()
	await _setup()
	await _scenario_standing()
	await _scenario_block()
	await _scenario_dodge()
	await _scenario_reset_without_swing()
	await _scenario_step_out_during_swing()
	await _scenario_interrupt()
	await _scenario_facing()
	var w := Strike.windup_seconds()
	_check(w >= .35 and w <= .6,"Wind-up %.2f s lies within 0.35-0.6 s" % w)
	var lo := INF
	var hi := -INF
	for value: float in windups:
		lo = minf(lo,value)
		hi = maxf(hi,value)
	_check(windups.size() >= 6 and lo >= w-DT-.001 and hi <= w+DT+.001,"Every swing starts %.2f s (+-1 frame) before its blow resolves (measured %.3f-%.3f s over %d blows)" % [w,lo,hi,windups.size()])
	var worst := 0.0
	for value: float in contact_errors:
		worst = maxf(worst,value)
	_check(not contact_errors.is_empty() and worst <= .034,"The weapon's contact frame meets the damage tick (max clip-time error %.3f s)" % worst)
	_check(orphan_swings == 0,"No swing is left without a following hit, block or dodge (%d)" % orphan_swings)
	var far := 0.0
	for value: float in hit_distances:
		far = maxf(far,value)
	_check(not hit_distances.is_empty() and far <= Strike.reach()+.001,"No damaging blow lands from beyond the weapon reach (max %.2f m, reach %.2f m)" % [far,Strike.reach()])
	report["windup_s"] = w
	report["reach_m"] = Strike.reach()
	report["measured_windup_min_max_s"] = [lo,hi]
	report["max_contact_clip_error_s"] = worst
	report["swings"] = swings
	report["orphan_swings"] = orphan_swings
	report["missed_after_step_out"] = misses
	report["interrupted_by_hit"] = interrupted
	report["max_damaging_distance_m"] = far
	report["events"] = log_events
	var evidence := OS.get_environment("IMPERATHEN_STRIKE_EVIDENCE")
	if not evidence.is_empty():
		var file := FileAccess.open(evidence,FileAccess.WRITE)
		file.store_string(JSON.stringify(report,"  "))
		file.close()
	print("STRIKE windup=%.2f reach=%.2f measured=%.3f..%.3f contact_error=%.3f swings=%d orphan=%d step_out_misses=%d interrupted=%d max_hit_distance=%.2f" % [w,Strike.reach(),lo,hi,worst,swings,orphan_swings,misses,interrupted,far])
	print("Raid strike timing: %d checks, %d failed" % [checks,failures.size()])
	for failure in failures:
		print("FAIL ",failure)
	quit(0 if failures.is_empty() else 1)


func _measure_clips() -> void:
	# Re-measure the contact frame and forward weapon reach the timing module
	# uses, on the actual raider rigs and clips.
	for variant in [0,1]:
		var holder := Node3D.new()
		root.add_child(holder)
		var person := Person.new()
		person.position.y = .9
		holder.add_child(person)
		person.configure("enemy","germania",28)
		person.configure_appearance("spearman",variant)
		if variant == 0:
			person.configure_meshy("unit_germanic_axe_fighter")
		await process_frame
		person.set_process(false)
		for k in 20:
			person._process(DT)
		var rig: Skeleton3D = person.find_children("*","Skeleton3D",true,false)[0]
		var axe: MeshInstance3D = null
		var found := person.find_children("MeshyEquipment_weap_germanic_hand_axe","MeshInstance3D",true,false)
		if not found.is_empty():
			axe = found[0]
		var kit: MeshInstance3D = null
		var shaft: Array[int] = []
		var arrays: Array = []
		if axe == null:
			kit = person.find_children("FrontierRomanKit","MeshInstance3D",true,false)[0]
			var highest := -INF
			for surface in kit.mesh.get_surface_count():
				var candidate := kit.mesh.surface_get_arrays(surface)
				for vertex: Vector3 in (candidate[Mesh.ARRAY_VERTEX] as PackedVector3Array):
					if vertex.y > highest:
						highest = vertex.y
						arrays = candidate
			var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			var top := 0
			for index in vertices.size():
				if vertices[index].y > vertices[top].y:
					top = index
			for index in vertices.size():
				if absf(vertices[index].x-vertices[top].x) < .04 and absf(vertices[index].z-vertices[top].z) < .04:
					shaft.append(index)
		person.cue("attack")
		var best := -INF
		var best_at := 0.0
		var t := 0.0
		for frame in 50:
			rig.force_update_all_bone_transforms()
			var forward := -INF
			if axe != null:
				var attachment := axe.get_parent().get_parent().get_parent() as BoneAttachment3D
				attachment.on_skeleton_update()
				var box := axe.get_aabb()
				for y: float in [box.position.y,box.end.y]:
					var point := holder.global_transform.affine_inverse()*(axe.global_transform*Vector3(0,y,0))
					forward = maxf(forward,-point.z)
			else:
				forward = _spear_forward(kit,rig,arrays,shaft,holder)
			if forward > best:
				best = forward
				best_at = t
			person._process(DT)
			await process_frame
			t += DT
		var path: String = person.active_model_path
		var expected := Strike.clip_contact_seconds(path,0.8)
		var expected_reach := 0.0
		for prefix: String in Strike.CLIP_WEAPON_REACH_M:
			if path.begins_with(prefix):
				expected_reach = float(Strike.CLIP_WEAPON_REACH_M[prefix])
		_check(absf(best_at-expected) <= 2.0*DT+.001,"%s: measured contact frame %.3f s matches RaiderStrike %.3f s" % [path,best_at,expected])
		_check(absf(best-expected_reach) <= .05,"%s: measured forward weapon reach %.2f m matches RaiderStrike %.2f m" % [path,best,expected_reach])
		report["clip_%d" % variant] = {"model":path,"contact_s":best_at,"forward_reach_m":best}
		holder.queue_free()
		await process_frame


func _blow_continuity() -> void:
	# A telegraphed blow has to be readable frame by frame. Every blow variant
	# of both raider kits, a flinch and a guard are played on the real rigs at
	# 60 Hz; no joint may move or turn further within one frame than the
	# motion contract allows a person in the world (0.06 m, 20 degrees).
	var rows := []
	for variant in [0,1]:
		for sequence: Array in [["strike","strike","strike","strike"],["strike","hit"],["block"]]:
			var holder := Node3D.new()
			root.add_child(holder)
			var person := Person.new()
			person.position.y = .9
			holder.add_child(person)
			person.configure("enemy","germania",28)
			person.configure_appearance("spearman",variant)
			if variant == 0:
				person.configure_meshy("unit_germanic_axe_fighter")
			await process_frame
			person.set_process(false)
			for k in 30:
				person._process(DT)
			var rig: Skeleton3D = person.find_children("*","Skeleton3D",true,false)[0]
			var previous: Array[Transform3D] = []
			for action: String in sequence:
				var frames := 110
				if action == "strike":
					person.cue_strike(Strike.windup_seconds())
				elif action == "hit":
					# Interrupt the following blow inside its wind-up.
					person.cue_strike(Strike.windup_seconds())
					for k in 12:
						previous = _pose_step(person,rig,previous,{})
					person.cue("hit")
				else:
					person.cue(action)
				var worst := {"action":action,"style":person._armed_style,"model":person.active_model_path,"position_m":0.0,"rotation_deg":0.0}
				for k in frames:
					previous = _pose_step(person,rig,previous,worst)
				rows.append(worst)
				_check(float(worst.position_m) <= .06 and float(worst.rotation_deg) <= 20.0,"%s %s on %s stays readable frame by frame (max %.4f m at %s, %.2f deg at %s per 60-Hz frame)" % [action,str(worst.style),str(worst.model).get_file(),worst.position_m,str(worst.get("position_bone","")),worst.rotation_deg,str(worst.get("rotation_bone",""))])
			holder.free()
	report["blow_continuity"] = rows


func _pose_step(person: Node3D, rig: Skeleton3D, previous: Array[Transform3D], worst: Dictionary) -> Array[Transform3D]:
	person._process(DT)
	rig.force_update_all_bone_transforms()
	var pose: Array[Transform3D] = []
	for bone in rig.get_bone_count():
		var transform := rig.global_transform*rig.get_bone_global_pose(bone)
		pose.append(transform)
		if previous.size() != rig.get_bone_count() or worst.is_empty():
			continue
		var moved := transform.origin.distance_to(previous[bone].origin)
		if moved > float(worst.position_m):
			worst.position_m = moved
			worst["position_bone"] = rig.get_bone_name(bone)
		var turned := rad_to_deg(transform.basis.orthonormalized().get_rotation_quaternion().angle_to(previous[bone].basis.orthonormalized().get_rotation_quaternion()))
		if turned > float(worst.rotation_deg):
			worst.rotation_deg = turned
			worst["rotation_bone"] = rig.get_bone_name(bone)
	return pose


func _spear_forward(kit: MeshInstance3D, rig: Skeleton3D, arrays: Array, shaft: Array[int], holder: Node3D) -> float:
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var bones: PackedInt32Array = arrays[Mesh.ARRAY_BONES]
	var weights: PackedFloat32Array = arrays[Mesh.ARRAY_WEIGHTS]
	var per := bones.size()/vertices.size()
	var best := -INF
	for index: int in shaft:
		var skinned := Vector3.ZERO
		for k in per:
			var weight := weights[index*per+k]
			if weight <= 0.0:
				continue
			var bind := bones[index*per+k]
			var bone := kit.skin.get_bind_bone(bind)
			if bone < 0:
				bone = rig.find_bone(kit.skin.get_bind_name(bind))
			skinned += weight*(rig.get_bone_global_pose(bone)*kit.skin.get_bind_pose(bind)*vertices[index])
		var point := holder.global_transform.affine_inverse()*(kit.global_transform*skinned)
		best = maxf(best,-point.z)
	return best


func _setup() -> void:
	model = Model.new()
	model.new_game("italia",true,false,true)
	model.data.village.raid.number = 0
	Life._begin_warning(model.data)
	Life._begin_raid(model.data)
	enemy_id = str(model.data.village.raid.enemies[0].id)
	for index in model.data.village.raid.enemies.size():
		var enemy: Dictionary = model.data.village.raid.enemies[index]
		enemy.x = FIELD.x-2.0 if index == 0 else -60.0-index*3.0
		enemy.z = FIELD.y if index == 0 else -105.0
		if index > 0:
			enemy.health = 0
	model.set_player_position(Vector3(FIELD.x,.91,FIELD.y))
	_check(model._validate_state(model.data).is_empty(),"Strike fixture is a valid authoritative world")
	world = World.new()
	root.add_child(world)
	world.setup(model.data)
	world.set_active(true)
	world.set_mode("person")
	world.set_raid_physics_authority(true)
	model.raid_observations = world.raid_observations
	model.combat_sight_check = world.combat_sight_clear
	model.combat_motion_check = world.combat_safe_motion
	world.get_node("Player").position = Vector3(FIELD.x,.91,FIELD.y)
	raider = world.village_life_world.raiders[enemy_id]
	figure = raider.get_node("Figure")
	await physics_frame
	_check(world.combat_sight_clear(FIELD + Vector2(-2.5, 0.0), FIELD), "Strike fixture has unobstructed sight before the first approach")
	_sync_counters()


func _enemy() -> Dictionary:
	for enemy: Dictionary in model.data.village.raid.enemies:
		if str(enemy.id) == enemy_id:
			return enemy
	return {}


func _sync_counters() -> void:
	_last_cues = int(raider.get_meta("strike_cues",0))
	_last_health = int(model.data.player.health)
	_last_blocks = int(model.data.village.raid.blocks)
	_last_dodges = int(model.data.village.raid.dodges)
	_last_timer = float(_enemy().attack_timer)


func _place_player(at: Vector2) -> void:
	world.get_node("Player").position = Vector3(at.x,.91,at.y)
	world.get_node("Player").velocity = Vector3.ZERO
	model.set_player_position(Vector3(at.x,.91,at.y))


func _reset(raider_at: Vector2, player_at: Vector2) -> void:
	raider.global_position = Vector3(raider_at.x,0.0,raider_at.y)
	raider.reset_physics_interpolation()
	var enemy := _enemy()
	enemy.x = raider_at.x
	enemy.z = raider_at.y
	enemy.attack_timer = Strike.APPROACH_SECONDS
	# Heal through the same ledger the world uses for village health changes.
	model.data.village.health_delta = int(model.data.village.health_delta)+100-int(model.data.player.health)
	model.data.player.health = 100
	model.data.village.unarmed.stamina = 100.0
	_check(model._validate_state(model.data).is_empty(),"Scenario reset keeps a valid world: %s" % model._validate_state(model.data))
	_place_player(player_at)
	world.sync_combat_state(model.data)
	_sync_counters()
	_open_swing = -1.0


func _step() -> void:
	await physics_frame
	clock += DT
	model.set_player_position(world.get_player_position())
	model.advance(DT)
	world.sync_combat_state(model.data)
	var enemy := _enemy()
	var cues := int(raider.get_meta("strike_cues",0))
	var health := int(model.data.player.health)
	var blocks := int(model.data.village.raid.blocks)
	var dodges := int(model.data.village.raid.dodges)
	var timer := float(enemy.attack_timer)
	var player: Vector3 = world.get_player_position()
	var distance := Vector2(raider.global_position.x,raider.global_position.z).distance_to(Vector2(player.x,player.z))
	var outcome := ""
	if health < _last_health:
		outcome = "hit"
		hit_distances.append(distance)
	elif blocks > _last_blocks:
		outcome = "block"
	elif dodges > _last_dodges:
		outcome = "dodge"
	elif Strike.swinging(_last_timer) and _last_timer > .000001 and not Strike.swinging(timer):
		outcome = "interrupted" if timer < Strike.INTERVAL_SECONDS-.001 else "miss"
	if not outcome.is_empty():
		if _open_swing < 0.0:
			if outcome in ["hit","block","dodge"]:
				# A resolved blow without a visible swing would break D-026.
				orphan_swings += 1
				log_events.append({"t":clock,"event":"blow_without_swing","outcome":outcome})
		else:
			if outcome in ["hit","block","dodge"]:
				windups.append(clock-_open_swing)
				var progress: Dictionary = figure.strike_progress()
				contact_errors.append(absf(float(progress.clip_time)-float(progress.contact)))
			elif outcome == "miss":
				misses += 1
			else:
				interrupted += 1
			log_events.append({"t":snappedf(clock,.001),"event":outcome,"windup_s":snappedf(clock-_open_swing,.001),"distance_m":snappedf(distance,.001)})
			_open_swing = -1.0
	if cues > _last_cues:
		if _open_swing >= 0.0:
			orphan_swings += 1
		swings += 1
		_open_swing = clock
		log_events.append({"t":snappedf(clock,.001),"event":"swing_start","timer":timer})
	_last_cues = cues
	_last_health = health
	_last_blocks = blocks
	_last_dodges = dodges
	_last_timer = timer


func _steps(seconds: float) -> void:
	for frame in int(round(seconds/DT)):
		await _step()


func _wait_swing(limit: float) -> bool:
	var start := swings
	for frame in int(limit/DT):
		await _step()
		if swings > start:
			return true
	return false


func _scenario_standing() -> void:
	# The raider walks up, stops inside its reach and strikes a standing player.
	_reset(FIELD+Vector2(-2.5,0.0),FIELD)
	var before := swings
	await _steps(8.0)
	_check(swings-before >= 3,"A standing player sees repeated swings (%d)" % (swings-before))
	_check(int(model.data.player.health) < 100,"Unblocked blows deal damage")


func _scenario_block() -> void:
	# Block 0.0, 0.1 and 0.2 s after the visible swing begins: always caught.
	_reset(FIELD+Vector2(-0.9,0.0),FIELD)
	for delay: float in [0.0,0.1,0.2]:
		_check(await _wait_swing(4.0),"A swing follows for the block at +%.1f s" % delay)
		var health := int(model.data.player.health)
		var blocks := int(model.data.village.raid.blocks)
		await _steps(delay)
		var guard: Dictionary = model.execute("village_unarmed_guard",{})
		_check(guard.ok,"Guard accepted %.1f s after the swing start" % delay)
		await _steps(Strike.windup_seconds()+.1)
		_check(int(model.data.village.raid.blocks) == blocks+1 and int(model.data.player.health) == health,"A block %.1f s after the swing start catches the blow" % delay)
		await _steps(1.0)


func _scenario_dodge() -> void:
	_reset(FIELD+Vector2(-0.9,0.0),FIELD)
	_check(await _wait_swing(4.0),"A swing follows for the dodge")
	var health := int(model.data.player.health)
	var dodges := int(model.data.village.raid.dodges)
	await _steps(.2)
	_check(model.execute("village_unarmed_dodge",{}).ok,"Dodge accepted 0.2 s after the swing start")
	await _steps(Strike.windup_seconds())
	_check(int(model.data.village.raid.dodges) == dodges+1 and int(model.data.player.health) == health,"A dodge 0.2 s after the swing start evades the blow")
	await _steps(1.0)


func _scenario_reset_without_swing() -> void:
	# Leaving reach before the wind-up resets the clock; that reset never swings.
	_reset(FIELD+Vector2(-0.9,0.0),FIELD)
	var before := swings
	for round in 6:
		await _steps(.3)
		_place_player(FIELD+Vector2(3.0,0.0))
		await _steps(.2)
		raider.global_position = Vector3(FIELD.x-.9,0.0,FIELD.y)
		raider.reset_physics_interpolation()
		_place_player(FIELD)
	_check(swings == before,"Approach resets of the clock start no swing (%d swings)" % (swings-before))


func _scenario_step_out_during_swing() -> void:
	# A begun swing completes visibly; stepping out of reach makes it miss.
	_reset(FIELD+Vector2(-0.9,0.0),FIELD)
	_check(await _wait_swing(4.0),"A swing begins before the step out")
	var health := int(model.data.player.health)
	var missed := misses
	await _steps(.1)
	_place_player(FIELD+Vector2(2.5,0.0))
	var origin := raider.global_position
	var moved := 0.0
	for frame in int(Strike.windup_seconds()/DT):
		await _step()
		if misses > missed:
			break
		moved = maxf(moved,raider.global_position.distance_to(origin))
	_check(int(model.data.player.health) == health and misses == missed+1,"Stepping out during the swing makes the visible blow miss")
	_check(moved < .01,"The raider completes its blow standing instead of chasing mid-swing (moved %.3f m)" % moved)
	await _steps(1.0)


func _scenario_interrupt() -> void:
	# D-026: the player's jab lands during the wind-up -> hit reaction, no blow.
	_reset(FIELD+Vector2(-0.9,0.0),FIELD)
	_check(await _wait_swing(4.0),"A swing begins before the counter-jab")
	var health := int(model.data.player.health)
	var enemy_health := int(_enemy().health)
	var towards := Vector2(raider.global_position.x,raider.global_position.z)-FIELD
	towards = towards.normalized()
	var jab: Dictionary = model.execute("village_unarmed_attack",{"technique":"jab_left","target_id":enemy_id,"facing_x":towards.x,"facing_z":towards.y})
	_check(jab.ok,"Counter-jab accepted at the swing start")
	var reacted := false
	for frame in int((Strike.windup_seconds()+.2)/DT):
		await _step()
		reacted = reacted or figure.clip == "hit"
	_check(int(_enemy().health) < enemy_health and reacted,"The raider shows its own hit reaction to the jab")
	_check(int(model.data.player.health) == health and interrupted >= 1,"The interrupted swing deals no damage")
	await _steps(1.0)


func _scenario_facing() -> void:
	# The player moves round a standing raider; within 0.5 s it faces him again.
	var errors := []
	for angle_deg: float in [90.0,180.0,-90.0]:
		_reset(FIELD+Vector2(-0.9,0.0),FIELD)
		await _steps(.6)
		var centre := Vector2(raider.global_position.x,raider.global_position.z)
		var heading := FIELD-centre
		_place_player(centre+heading.rotated(deg_to_rad(angle_deg)))
		await _steps(.5)
		var player: Vector3 = world.get_player_position()
		var towards := Vector2(player.x,player.z)-Vector2(raider.global_position.x,raider.global_position.z)
		var facing := Vector2(-sin(raider.rotation.y),-cos(raider.rotation.y))
		var error := rad_to_deg(absf(facing.angle_to(towards)))
		errors.append(snappedf(error,.1))
		_check(error <= 20.0,"After the player moves %.0f degrees round the raider it faces him within 0.5 s (error %.1f deg)" % [angle_deg,error])
	report["facing_error_after_0_5s_deg"] = errors
