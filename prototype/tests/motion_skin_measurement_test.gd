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
	print("MOTION_SKIN_TEST ",checks," checks; ",failed," failed")
	quit(0 if failed==0 else 1)
