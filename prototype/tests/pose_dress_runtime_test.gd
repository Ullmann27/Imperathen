extends SceneTree
## Optional candidate-only runtime gate. Measure the actual imported garment
## and real live actor poses, not a placeholder mesh or a fabricated report.
const Person := preload("res://scripts/visuals/village_person.gd")
const Skin := preload("res://tests/motion_skin_measurement.gd")
var failed := 0
var checks := 0


func _initialize() -> void:
	_run.call_deferred()


func check(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failed += 1
		push_error(label)


func _run() -> void:
	var actor := Person.new()
	root.add_child(actor)
	actor.position.y = 0.9
	actor.set_process(false)
	actor.configure_resident("italia",36,"civilian_woman",0,null,"vil:julia")
	var required := OS.get_environment("IMPERATHEN_REQUIRE_JULIA_DRESS") == "1"
	var results: Array[Dictionary] = []
	for lod in 4:
		actor._reload(lod)
		if required:
			check(actor.active_model_path == Person.PARENT_PATH%["julia",lod],"Exact parent family, LOD "+str(lod))
			check(actor._pose_dress.bound(),"Complete fitted garment shape and skin, LOD "+str(lod))
		if not actor._pose_dress.bound():
			continue
		var skin := Skin.new()
		skin.bind(actor.body)
		check(skin.errors.is_empty(),"Actual skin measurement binds")
		var saw_motion := false
		for action: String in ["idle","march","run","gather","talk","work","death"]:
			var duration := actor.animator.get_animation(action).length
			var count := maxi(2,ceili(duration*60.0))
			var maximum_floor := 0.0
			var skirt_violations := 0
			for i in range(count+1):
				actor.sample_pose(action,float(i)/float(count))
				var measured: Dictionary = skin.sample()
				check(bool(measured.finite),"Finite posed body "+action)
				maximum_floor = maxf(maximum_floor,actor._pose_dress.last_floor_residual_m)
				var garment := actor._pose_dress.mesh
				for slot in actor._pose_dress.slots:
					var amount := garment.get_blend_shape_value(slot)
					check(is_finite(amount) and amount>=0.0 and amount<=1.0,"Bounded actual corrective weight")
					if slot != actor._pose_dress.slots[0] and amount>0.01 and action=="march":
						saw_motion=true
				# Reuse the project's measured posed vertices and existing
				# edge threshold; count only the garment, not unrelated parts.
				for surface: Dictionary in skin.surfaces:
					if surface.mesh != garment:
						continue
					var posed: PackedVector3Array = surface.last_posed
					var edges: PackedInt32Array = surface.edges
					var limits: PackedFloat32Array = surface.limits
					for e in limits.size():
						if posed[edges[e*2]].distance_to(posed[edges[e*2+1]])>limits[e]:
							skirt_violations+=1
			check(maximum_floor<=0.002,"Actual runtime dress floor residual "+action+" LOD "+str(lod))
			check(skirt_violations==0,"Actual runtime cloth edge violations "+action+" LOD "+str(lod))
			results.append({"lod":lod,"action":action,"frames":count+1,"floor_residual_m":maximum_floor,"edge_violations":skirt_violations})
		check(saw_motion,"Real gait drives fitted shape values")
	actor.free()
	var args := OS.get_cmdline_user_args()
	if not args.is_empty():
		var file := FileAccess.open(args[0],FileAccess.WRITE)
		if file:
			file.store_string(JSON.stringify({"required":required,"checks":checks,"failures":failed,"results":results},"  ")+"\n")
			file.close()
		else:
			failed+=1
	print("POSE_DRESS_RUNTIME_PASS" if failed==0 else "POSE_DRESS_RUNTIME_FAIL"," checks=",checks," failures=",failed)
	quit(0 if failed==0 else 1)
