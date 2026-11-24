extends RefCounted
## Measured production world fixtures. CPU shader observations are identified;
## their rendering still requires the independent source-bound visual review.

const World = preload("res://scripts/world/game_world.gd")
const Model = preload("res://scripts/domain/world_model.gd")
const Stage = preload("res://scripts/cinematic/i00_stage.gd")
const Ranks = preload("res://scripts/visuals/far_ranks.gd")
const Soldier = preload("res://scripts/visuals/soldier_visual.gd")
const Childhood = preload("res://scripts/story/village_childhood.gd")
const Life = preload("res://scripts/story/village_life.gd")
const DT := 1.0/60.0
var _tree: SceneTree


func _family() -> Dictionary:
	return {"subjects":[],"sample_hz":60,"sample_count":0,"scenarios":[],"metrics":{},"scenario_samples":[],"errors":[]}


func _world_metrics() -> Dictionary:
	return {"max_root_step_m":0.0,"max_collision_overlap_m":0.0,"max_support_slip_m":0.0,
		"max_transition_position_jump_m":0.0,"max_transition_rotation_jump_deg":0.0}


func _merge(target: Dictionary, source: Dictionary) -> void:
	for key: String in source:
		target[key] = maxf(float(target.get(key,0.0)),float(source[key]))


func _add(family: Dictionary, subject: String, scenario: String, sample: Dictionary) -> void:
	family.scenario_samples.append({"subject":subject,"scenario":scenario,"sample_hz":60,
		"sample_count":int(sample.count),"finite":bool(sample.finite),"metrics":sample.metrics,"diagnostics":sample.get("worst",{}),"contact_samples":int(sample.get("contact_samples",0))})
	if subject not in family.subjects: family.subjects.append(subject)
	if scenario not in family.scenarios: family.scenarios.append(scenario)
	family.sample_count += int(sample.count)
	_merge(family.metrics,sample.metrics)


func _observer() -> Dictionary:
	return {"count":0,"finite":true,"metrics":_world_metrics(),"actors":{},"worst":{},"contact_samples":0,"max_root_turn_deg":0.0}


func _maximum(sample: Dictionary, key: String, value: float, context: Dictionary) -> void:
	if not is_finite(value):
		sample.finite = false
		return
	if value > float(sample.metrics.get(key,0.0)):
		sample.metrics[key] = value
		sample.worst[key] = context.duplicate()


func _collision_depth(actor: Node3D) -> float:
	if not actor is CollisionObject3D or actor.collision_layer == 0:
		return 0.0
	var maximum := 0.0
	for node: Node in actor.get_children():
		if not node is CollisionShape3D or node.disabled or node.shape == null:
			continue
		var query := PhysicsShapeQueryParameters3D.new()
		query.shape = node.shape
		query.transform = node.global_transform
		query.collision_mask = 1 | 2 | 4 | 8
		query.exclude = [actor.get_rid()]
		var pairs := actor.get_world_3d().direct_space_state.collide_shape(query,32)
		for pair in range(0,pairs.size()-1,2):
			maximum = maxf(maximum,pairs[pair].distance_to(pairs[pair+1]))
	return maximum


func _observe_person(sample: Dictionary, actor: Node3D, figure: Node3D) -> void:
	var id := str(actor.get_instance_id())
	var previous: Dictionary = sample.actors.get(id,{})
	var at := actor.global_position
	var context := {"actor":actor.name,"clip":figure.clip,"frame":int(previous.get("frame",0))+1,"model":figure.active_model_path}
	var root_rotation := actor.global_basis.orthonormalized().get_rotation_quaternion()
	if not previous.is_empty():
		context["root_turn_deg"] = rad_to_deg(root_rotation.angle_to(previous.root_rotation))
		sample.max_root_turn_deg = maxf(float(sample.max_root_turn_deg),float(context.root_turn_deg))
		context["previous_model"] = previous.model
		context["previous_clip"] = previous.clip
		context["lod_changed"] = previous.model != figure.active_model_path
	var m: Dictionary = sample.metrics
	var pose: Array[Transform3D] = []
	var rigs: Array[Node] = figure.find_children("*","Skeleton3D",true,false)
	if rigs.size() != 1:
		sample.finite = false
		return
	var rig: Skeleton3D = rigs[0]
	rig.force_update_all_bone_transforms()
	for bone in rig.get_bone_count():
		var transform := rig.global_transform*rig.get_bone_global_pose(bone)
		pose.append(transform)
		sample.finite = bool(sample.finite) and transform.is_finite()
	_maximum(sample,"max_collision_overlap_m",_collision_depth(actor),context)
	if not previous.is_empty():
		_maximum(sample,"max_root_step_m",at.distance_to(previous.root),context)
		if previous.pose.size() == pose.size():
			for bone in pose.size():
				var old: Transform3D = previous.pose[bone]
				context["bone"] = rig.get_bone_name(bone)
				_maximum(sample,"max_transition_position_jump_m",pose[bone].origin.distance_to(old.origin),context)
				var angle := rad_to_deg(pose[bone].basis.orthonormalized().get_rotation_quaternion().angle_to(old.basis.orthonormalized().get_rotation_quaternion()))
				_maximum(sample,"max_transition_rotation_jump_deg",angle,context)
	var contacts: Dictionary = previous.get("contacts",{})
	var phase := 0.0
	if figure.animator != null and figure.animator.current_animation_length > 0:
		phase = figure.animator.current_animation_position/figure.animator.current_animation_length
	var gait: bool = figure.clip in ["march","run","retreat"]
	for side: String in ["L","R"]:
		var bone := rig.find_bone("Foot_"+side)
		if bone < 0:
			sample.finite = false
			continue
		var phase_at := fposmod(phase+(.5 if side == "L" else 0.0),1.0)
		var supported: bool = figure.world_foot_supported(side)
		# The controller executes a real lifted turning step. Only its actual
		# planted phase is a contact; the swing arc must not be called slipping.
		var foot: Vector3 = pose[bone].origin
		var contact: Dictionary = contacts.get(side,{})
		if supported:
			sample.contact_samples += 1
			if contact.is_empty() or contact.clip != figure.clip or (gait and phase_at+0.00001 < float(contact.phase)):
				contact = {"anchor":foot,"phase":phase_at,"clip":figure.clip}
			else:
				var offset: Vector3 = foot-Vector3(contact.anchor)
				context["bone"] = "Foot_"+side
				context["phase"] = phase_at
				_maximum(sample,"max_support_slip_m",Vector2(offset.x,offset.z).length(),context)
			contact.phase = phase_at
			contacts[side] = contact
		else:
			contacts.erase(side)
	sample.actors[id] = {"root":at,"root_rotation":root_rotation,"pose":pose,"contacts":contacts,
		"frame":context.frame,"model":figure.active_model_path,"clip":figure.clip}
	sample.count += 1


func _manual_people(node: Node) -> void:
	for figure: Node in node.find_children("*","Node3D",true,false):
		if figure.has_method("drive") and figure.has_method("sample_pose"):
			figure.set_process(false)


func measure(tree: SceneTree, _contract: Dictionary) -> Dictionary:
	_tree = tree
	var result := {"distant_ranks":_distant(),"cinematic_people":_cinematic()}
	var model := Model.new()
	model.new_game("italia",true,true)
	var world := World.new()
	tree.root.add_child(world)
	world.setup(model.data)
	world.set_active(true)
	world.set_physics_process(false)
	world.village_life_world.set_physics_process(false)
	_manual_people(world)
	await tree.physics_frame
	await tree.physics_frame
	result.village_navigation = _navigation(world,model.data)
	result.raid_motion = await _raid(world,model.data)
	await _companions(world,result.village_navigation)
	world.free()
	return result


func _navigation(world: Node3D, data: Dictionary) -> Dictionary:
	var family := _family()
	var subject := "family:village_navigation"
	var population: Node3D = world.population
	var resident: CharacterBody3D = population.actors.marcellus
	var figure: Node3D = resident.get_node("Figure")
	var intent: Dictionary = data.village.behavior.people.marcellus
	intent.activity = "explore"
	population.sync_behavior(data)
	var walk := _observer()
	for frame in 180:
		population.advance_to(population.seconds+DT)
		figure._process(DT)
		_observe_person(walk,resident,figure)
	_add(family,subject,"world_displacement",walk)
	_add(family,subject,"contact_and_weight",walk)
	_add(family,subject,"collision",walk)
	var transition := _observer()
	for frame in 120:
		if frame == 0: intent.activity = "rest"
		if frame == 60: intent.activity = "work"
		population.advance_to(population.seconds+DT)
		figure._process(DT)
		_observe_person(transition,resident,figure)
	# Player's actual walk/run/stop driver is part of the same world contract.
	# The fixture starts on a clear production-road section to exercise travel.
	world._player.position = Vector3(-5,.91,-62)
	world._player.velocity = Vector3.ZERO
	world._figure.set_process(false)
	for frame in 240:
		world.set_running(frame >= 80 and frame < 160)
		world.set_touch_move(Vector2(1,0) if frame < 160 else Vector2.ZERO)
		world._move_player(DT)
		world._animate_figure()
		world._figure._process(DT)
		_observe_person(transition,world._player,world._figure)
	world.set_touch_move(Vector2.ZERO)
	world.set_running(false)
	_add(family,subject,"walk_run_stop",transition)
	var dialogue := _observer()
	for frame in 120:
		if frame == 0: population.focus("marcellus",resident.position+Vector3(0,1,2))
		if frame == 60: population.clear_focus()
		population._process(DT)
		figure._process(DT)
		_observe_person(dialogue,resident,figure)
	_add(family,subject,"dialogue_transition",dialogue)
	return family


func _reach_companion_stage(model: RefCounted, stage: String, family: Dictionary) -> bool:
	# Normal validated commands establish the mission; only the player's travel
	# to each conversation/work point is fixture placement, never quest editing.
	for attempt in 100:
		var view: Dictionary = Childhood.view(model.data)
		if view.is_empty():
			family.errors.append("Companion fixture has no mission view before "+stage)
			return false
		if str(view.stage) == stage:
			return true
		var point: Vector2 = view.point
		model.set_player_position(Vector3(point.x,1.0,point.y))
		var npc := str(view.get("target_npc",""))
		if not npc.is_empty() and not Life.relationship(model.data,npc).get("met",false):
			var greeting: Dictionary = model.execute("village_talk",{"npc_id":npc,"choice":"meet"})
			if not greeting.ok:
				family.errors.append("Companion fixture could not meet "+npc+": "+str(greeting.message))
				return false
		view = Childhood.view(model.data)
		var action := str(view.actions[0].payload.action_id)
		if str(view.stage) == "i03_marcus":
			action = "marcus_friend"
		var result: Dictionary = model.execute("village_childhood_action",{"action_id":action})
		if not result.ok:
			family.errors.append("Companion fixture command "+action+": "+str(result.message))
			return false
		if action.begins_with("begin_"):
			model.advance(float(view.work_required)+0.05)
	family.errors.append("Companion fixture did not reach "+stage)
	return false


func _companion_sample(family: Dictionary, stage: String, id: String, scenario: String,
		sample: Dictionary, segment: String) -> void:
	_add(family,"family:village_navigation",scenario,sample)
	family.scenario_samples.back()["fixture"] = {"mission_step":stage,"actor_id":id,"segment":segment}


func _companions(world: Node3D, family: Dictionary) -> void:
	var model := Model.new()
	model.new_game("italia",true,true)
	var cases := {
		"deliver_kindling":{"id":"silvanus","player":Vector3(31.4,.94,-21.9),"stop":Vector2(30.4,-23.2),"limit":2100},
		"market_trade":{"id":"marcus","player":Vector3(24.4,.94,28.0),"stop":Vector2(22.8,26.8),"limit":1200}}
	var snapshots := {}
	for stage: String in cases:
		if not _reach_companion_stage(model,stage,family):
			return
		snapshots[stage] = model.data.duplicate(true)
	family["companion_routes"] = []
	for stage: String in cases:
		var spec: Dictionary = cases[stage]
		var id := str(spec.id)
		model.data = snapshots[stage].duplicate(true)
		model.set_player_position(spec.player)
		world.setup(model.data)
		world.set_active(true)
		world.set_physics_process(false)
		world.village_life_world.set_physics_process(false)
		_manual_people(world)
		var actor: CharacterBody3D = world._story_companions.actor(id)
		if actor == null or not Childhood.companion_specs(model.data).has(id):
			family.errors.append("Missing actual mission companion: "+stage+"/"+id)
			continue
		var figure: Node3D = actor.get_node("Figure")
		var actor_identity := actor.get_instance_id()
		var people_count: int = world.population.actors.size()+world.village_life_world.actors.size()
		await _tree.physics_frame
		await _tree.physics_frame
		var start := actor.global_position
		var travel := 0.0
		var walking := _observer()
		_observe_person(walking,actor,figure)
		# Pause after real travel, not after an assumed amount of wall-clock time.
		for frame in int(spec.limit):
			await _tree.physics_frame
			var before := actor.global_position
			world._update_story_companions(DT)
			figure._process(DT)
			travel += Vector2(actor.global_position.x-before.x,actor.global_position.z-before.z).length()
			_observe_person(walking,actor,figure)
			if travel >= 2.0:
				break
		var paused_at := actor.global_position
		var paused := _observer()
		_observe_person(paused,actor,figure)
		world.set_active(false)
		var pause_displacement := 0.0
		for frame in 60:
			await _tree.physics_frame
			world._update_story_companions(DT)
			figure._process(DT)
			pause_displacement = maxf(pause_displacement,actor.global_position.distance_to(paused_at))
			_observe_person(paused,actor,figure)
			_observe_person(walking,actor,figure)
		world.set_active(true)
		var resumed_distance := 0.0
		for frame in int(spec.limit):
			await _tree.physics_frame
			var before := actor.global_position
			world._update_story_companions(DT)
			figure._process(DT)
			var step := Vector2(actor.global_position.x-before.x,actor.global_position.z-before.z).length()
			resumed_distance += step
			travel += step
			_observe_person(walking,actor,figure)
			if Vector2(actor.global_position.x,actor.global_position.z).distance_to(spec.stop) < 0.35:
				break
		var stopped := _observer()
		for frame in 120:
			await _tree.physics_frame
			var before := actor.global_position
			world._update_story_companions(DT)
			figure._process(DT)
			travel += Vector2(actor.global_position.x-before.x,actor.global_position.z-before.z).length()
			_observe_person(stopped,actor,figure)
			_observe_person(walking,actor,figure)
		var gap := Vector2(actor.global_position.x,actor.global_position.z).distance_to(spec.stop)
		var final_speed := float(figure.speed)
		if travel <= 1.0 or resumed_distance <= 0.1 or gap >= 0.6 or final_speed >= 0.05:
			family.errors.append("Companion route not completed by actual walking and stopping: "+stage+"/"+id)
		if pause_displacement > 0.001:
			family.errors.append("Companion moved while the world was paused: "+stage+"/"+id)
		if world._story_companions.actor(id).get_instance_id() != actor_identity or world.population.actors.size()+world.village_life_world.actors.size() != people_count:
			family.errors.append("Companion fixture replaced or duplicated its production actor: "+stage+"/"+id)
		for scenario: String in ["world_displacement","contact_and_weight","collision","walk_run_stop"]:
			_companion_sample(family,stage,id,scenario,walking,"travel_pause_resume_stop")
		_companion_sample(family,stage,id,"dialogue_transition",paused,"world_pause")
		_companion_sample(family,stage,id,"walk_run_stop",stopped,"arrival_hold")
		family.companion_routes.append({"mission_step":stage,"actor_id":id,"model":figure.active_model_path,
			"distance_m":travel,"displacement_m":start.distance_to(actor.global_position),
			"resumed_distance_m":resumed_distance,"pause_displacement_m":pause_displacement,
			"arrival_gap_m":gap,"final_speed_m_s":final_speed,"sample_count":int(walking.count),
			"max_root_turn_deg":float(walking.max_root_turn_deg),
			"same_actor":world._story_companions.actor(id).get_instance_id()==actor_identity})
	family["companion_fixture_notes"] = "Validated mission commands reach deliver_kindling and market_trade. Player arrivals are fixture placements; the existing Silvanus/Marcus bodies then walk via production companion navigation and 60-Hz physics, including pause, resume and their authored stop. No quest editing or duplicate actors."


func _raid(world: Node3D, data: Dictionary) -> Dictionary:
	var family := _family()
	var subject := "family:raid_motion"
	var fixture := data.duplicate(true)
	fixture.village.raid.active = true
	fixture.village.raid.status = "active"
	fixture.village.raid.enemies = [
		{"id":"measurement_raider","x":-12.0,"z":-62.0,"health":45,"max_health":45,"attack_timer":.9,"loot_timer":0.0}]
	var projection: Node3D = world.village_life_world
	projection.sync_state(fixture,"balanced")
	projection.set_active(true)
	world.set_raid_physics_authority(true)
	fixture.player.position = [-8.0,.91,-62.0]
	world._player.position = Vector3(-8,.91,-62)
	var actor: CharacterBody3D = projection.raiders.measurement_raider
	var figure: Node3D = actor.get_node("Figure")
	figure.set_process(false)
	await _tree.physics_frame
	var walking := _observer()
	for frame in 180:
		if frame%6 == 0:
			fixture.world_seconds += .1
			fixture.village.raid.enemies[0].x += .12
			projection.sync_state(fixture,"balanced")
		projection._advance_raiders(DT)
		figure._process(DT)
		_observe_person(walking,actor,figure)
	_add(family,subject,"world_displacement",walking)
	_add(family,subject,"contact_and_weight",walking)
	var stopping := _observer()
	for frame in 120:
		projection._advance_raiders(DT)
		figure._process(DT)
		_observe_person(stopping,actor,figure)
	_add(family,subject,"walk_run_stop",stopping)
	var reaction := _observer()
	for frame in 180:
		if frame == 0: fixture.village.raid.enemies[0].attack_timer = 1.8
		if frame == 60: fixture.village.raid.enemies[0].health = 30
		if frame == 120: figure.cue("block")
		projection.sync_state(fixture,"balanced")
		projection._advance_raiders(DT)
		figure._process(DT)
		_observe_person(reaction,actor,figure)
	_add(family,subject,"attack_guard_reaction",reaction)
	var wall := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(.12,2.2,2)
	shape.shape = box
	wall.add_child(shape)
	wall.position = actor.position+Vector3(.75,1.1,0)
	world.add_child(wall)
	await _tree.physics_frame
	fixture.player.position = [actor.position.x+4.5,.91,actor.position.z]
	world._player.position = Vector3(actor.position.x+4.5,.91,actor.position.z)
	var collision := _observer()
	for frame in 120:
		if frame%6 == 0:
			fixture.world_seconds += .1
			fixture.village.raid.enemies[0].x += .12
			projection.sync_state(fixture,"balanced")
		projection._advance_raiders(DT)
		figure._process(DT)
		_observe_person(collision,actor,figure)
	_add(family,subject,"collision",collision)
	family["fixture_notes"] = "Actual raid walking/stopping, attack/hit and explicit block pose; raid policy caps travel at1.2m/s. No running raid policy is claimed."
	wall.free()
	return family


func _cinematic() -> Dictionary:
	var family := _family()
	var subject := "family:cinematic_people"
	var stage := Stage.new()
	_tree.root.add_child(stage)
	stage.ensure_built()
	stage.set_process(false)
	_manual_people(stage)
	var speakers: Array[Node3D] = [stage.speaker("caesar"),stage.speaker("labienus")]
	var sample := _observer()
	for frame in 180:
		stage._process(DT)
		for figure: Node3D in speakers:
			figure._process(DT)
			_observe_person(sample,figure.get_parent(),figure)
	_add(family,subject,"cinematic_body_motion",sample)
	_add(family,subject,"contact_and_weight",sample)
	var dialogue := _observer()
	for frame in 180:
		for index in speakers.size():
			var figure: Node3D = speakers[index]
			if frame < 120 and index == 0:
				figure.sample_pose("talk",fposmod(float(frame)*DT/1.7,1.0))
			else:
				if frame == 120: figure.reset_motion()
				figure._process(DT)
			_observe_person(dialogue,figure.get_parent(),figure)
	_add(family,subject,"dialogue_transition",dialogue)
	# The actual54-instance stage formation has fixed, non-overlapping roots.
	# Its mesh/vertex motion is measured separately under distant_ranks.
	var formation := _observer()
	var roots: Array[Vector3] = []
	var tracks: Dictionary = stage._legions.instance_tracks.spear
	for transform: Transform3D in tracks.ends:
		roots.append(transform.origin)
	var mesh: Mesh = Soldier.far_mesh("spear")
	var vertices: PackedVector3Array = mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	var old_points := {}
	for frame in 60:
		stage._process(DT)
		for a in roots.size():
			for vertex_index in vertices.size():
				if vertices[vertex_index].y > .1: continue
				var point: Vector3 = tracks.ends[a]*Ranks.deformed_vertex(vertices[vertex_index],tracks.gaits[a],stage._legions._last_fraction)
				formation.finite = bool(formation.finite) and point.is_finite()
				var key := Vector2i(a,vertex_index)
				if old_points.has(key):
					formation.metrics.max_support_slip_m = maxf(formation.metrics.max_support_slip_m,point.distance_to(old_points[key]))
				else:
					old_points[key] = point
			for b in range(a+1,roots.size()):
				formation.metrics.max_collision_overlap_m = maxf(formation.metrics.max_collision_overlap_m,maxf(0.0,.56-roots[a].distance_to(roots[b])))
		formation.count += roots.size()
	_add(family,subject,"formation",formation)
	stage.free()
	return family


func _distant() -> Dictionary:
	var family := _family()
	family["fixture_notes"] = "CPU evaluation of production rank_stride equations on actual imported far vertices. GPU rendering requires independent visual review."
	for role: String in Soldier.ROLES:
		var subject := "assets/soldiers/%s_far.glb" % role
		var mesh := Soldier.far_mesh(role)
		var vertices: PackedVector3Array = mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
		var stance_sample := {"count":0,"finite":true,"metrics":{"max_visible_contact_slip_m":0.0,"max_root_step_m":0.0,"max_transition_rotation_jump_deg":0.0}}
		for gait: String in Ranks.STANCE:
			var stride: float = Soldier.STRIDES[gait]
			for side: float in [-1.0,1.0]:
				var anchors := {}
				for frame in 61:
					var phase := float(Ranks.STANCE[gait])*float(frame)/60.0
					var offset := 0.0 if side < 0 else .5
					var data := Ranks.gait_data(gait,phase-offset,phase-offset)
					for index in vertices.size():
						var vertex := vertices[index]
						if vertex.y > .10 or absf(vertex.x) > .205 or vertex.x*side <= 0: continue
						var point := Ranks.deformed_vertex(vertex,data,1.0)+Vector3.BACK*phase*stride
						stance_sample.finite = bool(stance_sample.finite) and point.is_finite()
						if frame == 0: anchors[index] = point
						stance_sample.metrics.max_visible_contact_slip_m = maxf(stance_sample.metrics.max_visible_contact_slip_m,point.distance_to(anchors[index]))
					stance_sample.metrics.max_root_step_m = maxf(stance_sample.metrics.max_root_step_m,float(Ranks.STANCE[gait])*stride/60.0)
					stance_sample.count += 1
		_add(family,subject,"stride_contact_at_visible_distance",stance_sample)
		var turn := {"count":0,"finite":true,"metrics":{"max_root_step_m":0.0,"max_transition_rotation_jump_deg":0.0}}
		var start := Transform3D(Basis(Vector3.UP,deg_to_rad(170)),Vector3(0,.1,0))
		var finish := Transform3D(Basis(Vector3.UP,deg_to_rad(-165)),Vector3(.24,.12,.05))
		var prior := start
		for frame in 61:
			var transform := Ranks.interpolated_root(finish,Ranks.root_data(start,finish),float(frame)/60.0)
			turn.finite = bool(turn.finite) and transform.is_finite()
			turn.metrics.max_root_step_m = maxf(turn.metrics.max_root_step_m,transform.origin.distance_to(prior.origin))
			turn.metrics.max_transition_rotation_jump_deg = maxf(turn.metrics.max_transition_rotation_jump_deg,rad_to_deg(transform.basis.get_rotation_quaternion().angle_to(prior.basis.get_rotation_quaternion())))
			prior = transform
			turn.count += 1
		_add(family,subject,"formation",turn)
		var reaction := {"count":0,"finite":true,"metrics":{"max_root_step_m":0.0,"max_transition_rotation_jump_deg":0.0}}
		for pose: String in ["attack","hit","block","shoot","wall","testudo"]:
			for frame in 61:
				var phase := float(frame)/60.0
				for vertex: Vector3 in vertices:
					reaction.finite = bool(reaction.finite) and Ranks.deformed_vertex(vertex,Ranks.gait_data(pose,phase,phase),1.0).is_finite()
				reaction.count += 1
		_add(family,subject,"combat_reaction",reaction)
		# Compare the visible sole surfaces through the actual near-to-far swap.
		var near := Soldier.new()
		near.role = role
		near.detail = 1
		_tree.root.add_child(near)
		var rig: Skeleton3D = near.find_children("*","Skeleton3D",true,false)[0]
		var lod := {"count":0,"finite":true,"metrics":{"max_lod_pose_jump_m":0.0},"worst":{}}
		for gait: String in Ranks.STANCE:
			for frame in 61:
				var phase := float(frame)/60.0
				near.present(gait,phase,DT)
				rig.force_update_all_bone_transforms()
				for side: String in ["R","L"]:
					var bone := rig.find_bone("Foot_"+side)
					var binding := rig.get_bone_global_pose(bone)*rig.get_bone_global_rest(bone).affine_inverse()
					for depth in [-.065,.175]:
						var sole := binding*Vector3(-.126 if side == "R" else .126,.011,depth)
						var closest := INF
						for vertex: Vector3 in vertices:
							if vertex.y > .10 or absf(vertex.x) > .205 or vertex.x*(-1 if side == "R" else 1) <= 0: continue
							closest = minf(closest,sole.distance_to(Ranks.deformed_vertex(vertex,Ranks.gait_data(gait,phase,phase),1.0)))
						lod.finite = bool(lod.finite) and is_finite(closest)
						_maximum(lod,"max_lod_pose_jump_m",closest,{"role":role,"gait":gait,"frame":frame,"phase":phase,"foot":side,"sole_depth":depth})
				lod.count += 1
		_add(family,subject,"near_far_transition",lod)
		near.free()
	return family
