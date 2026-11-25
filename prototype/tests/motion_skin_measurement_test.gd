extends SceneTree
const Person=preload("res://scripts/visuals/village_person.gd")
const SkinFixture=preload("res://tests/motion_skin_measurement.gd")
var checks:=0
var failed:=0


func _initialize() -> void:
	_run.call_deferred()


func _check(value: bool, label: String) -> void:
	checks+=1
	if not value:
		failed+=1
		push_error(label)


func _run() -> void:
	for identity: String in ["hero","meshy","archer","worker"]:
		var actor:=Person.new()
		root.add_child(actor)
		actor.set_process(false)
		actor.position=Vector3(0,.9,0)
		match identity:
			"hero": actor.configure("player","italia",18)
			"meshy":
				actor.configure_resident("germania",32,"spearman")
				actor.configure_meshy("unit_germanic_axe_fighter")
			"archer": actor.configure_resident("italia",32,"archer")
			"worker": actor.configure("regional_worker","han",32)
		actor._reload(3)
		actor._check_lod=100000.0
		await process_frame
		var skin:=SkinFixture.new()
		skin.bind(actor.body)
		_check(skin.errors.is_empty(),identity+" actual skin fixture binds")
		var maximum:=0.0
		var packed_count:=0
		for action: String in ["idle","march","run","jab_left","high_kick"]:
			for phase: float in [.03,.24,.56,.91]:
				actor.sample_pose(action,phase)
				actor._motion.skeleton.force_update_all_bone_transforms()
				var accelerated:=skin.sample()
				var vertices: Array[PackedVector3Array]=[]
				for surface: Dictionary in skin.surfaces: vertices.append(surface.last_posed.duplicate())
				var exact:=skin.sample(true)
				packed_count+=int(accelerated.packed_surfaces)
				for surface in skin.surfaces.size():
					var cpu: PackedVector3Array=skin.surfaces[surface].last_posed
					for vertex in cpu.size(): maximum=maxf(maximum,cpu[vertex].distance_to(vertices[surface][vertex]))
				_check(accelerated.finite and exact.finite,identity+" finite actual vertices "+action+" "+str(phase))
				_check(accelerated.skin_edge_violations==exact.skin_edge_violations,identity+" identical skin-edge result "+action)
				_check(absf(float(accelerated.max_sole_penetration_m)-float(exact.max_sole_penetration_m))<.00002,identity+" identical real sole result "+action)
		_check(maximum<.00002,identity+" accelerated and full CPU geometry agree")
		print("MOTION_SKIN_BACKEND ",identity," packed_surfaces=",packed_count," max_vertex_difference_m=",maximum," sentinel_max_m=",skin.packed_validation_error_m)
		actor.free()
	await _test_meshy_world_contacts()
	print("MOTION_SKIN_TEST ",checks," checks; ",failed," failed")
	quit(0 if failed==0 else 1)


func _test_meshy_world_contacts() -> void:
	# A valid ankle trajectory does not prove that its actual skin is planted.
	# LOD smoothing previously mixed a rigid sole into the shin: the ankle
	# remained fixed while the Germanic LOD3 sole slid more than 17 mm.
	for identity: String in ["unit_germanic_axe_fighter","unit_roman_signifer"]:
		for level in [0,3]:
			var actor:=Person.new()
			root.add_child(actor)
			actor.set_process(false)
			actor.configure_resident("germania" if "germanic" in identity else "italia",32,
				"spearman" if "germanic" in identity else "legionary")
			actor.configure_meshy(identity)
			actor._reload(level)
			actor._check_lod=100000.0
			await process_frame
			var skin:=SkinFixture.new()
			skin.bind(actor.body)
			var label:="%s LOD%d" % [identity,level]
			_check(skin.errors.is_empty(),label+" actual contact skin binds")
			for action: String in ["march","run"]:
				actor.position=Vector3(0,.9,0)
				actor.reset_motion()
				var speed:=1.45 if action=="march" else 3.6
				actor.drive(speed)
				actor._play(action,0.0,0.0)
				var seconds:=actor.locomotion_stride(action)/speed
				var frames:=int(ceil(seconds*60.0))
				var elapsed:=0.0
				var anchors:={}
				var contacts:={"L":0,"R":0}
				var max_slip:=0.0
				var max_penetration:=0.0
				var skin_edges:=0
				var finite:=true
				for frame in frames+1:
					var target:=float(frame)/frames*seconds
					var delta:=target-elapsed
					actor.position.z-=speed*delta
					actor._process(delta)
					actor._motion.skeleton.force_update_all_bone_transforms()
					var observed:=skin.sample()
					finite=finite and bool(observed.finite)
					max_penetration=maxf(max_penetration,float(observed.max_sole_penetration_m))
					skin_edges+=int(observed.skin_edge_violations)
					var next_anchors:={}
					for key: int in observed.contact_points:
						var side:="R" if key%2==1 else "L"
						if not actor.world_foot_supported(side): continue
						contacts[side]+=1
						var point: Vector3=observed.contact_points[key]
						var anchor: Vector3=anchors.get(key,point)
						max_slip=maxf(max_slip,Vector2(point.x-anchor.x,point.z-anchor.z).length())
						next_anchors[key]=anchor
					anchors=next_anchors
					elapsed=target
				_check(finite,label+" finite live "+action+" skin")
				for side: String in ["L","R"]:
					_check(contacts[side]>0,label+" live "+action+" has actual "+side+" sole contacts")
				# Existing motion-gate limits, unchanged by this regression.
				_check(max_slip<=.015,label+" live "+action+" planted sole slip: "+str(max_slip))
				_check(max_penetration<=.01,label+" live "+action+" sole penetration: "+str(max_penetration))
				_check(skin_edges==0,label+" live "+action+" skin remains connected")
				print("MOTION_SKIN_CONTACT ",label," ",action," samples=",contacts," slip_m=",max_slip," penetration_m=",max_penetration)
			actor.free()
