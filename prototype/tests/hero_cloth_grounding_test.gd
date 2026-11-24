extends SceneTree
## Real imported cloth and fall geometry at 60 Hz, child/adult and all four LODs.
const Person=preload("res://scripts/visuals/village_person.gd")
const Motion=preload("res://scripts/visuals/character_motion.gd")
const SkinFixture=preload("res://tests/motion_skin_measurement.gd")
var checks:=0
var failed:=0
var records: Array[Dictionary]=[]


func _initialize() -> void:
	_run.call_deferred()


func _check(value: bool, label: String) -> void:
	checks+=1
	if not value:
		failed+=1
		push_error(label)


func _run() -> void:
	for age in [12,18]:
		var actor:=Person.new()
		root.add_child(actor)
		actor.set_process(false)
		actor.position=Vector3(0,.9,0)
		actor.configure("player","italia",age)
		for level in 4:
			actor._reload(level)
			actor._check_lod=100000.0
			var skin:=SkinFixture.new()
			skin.bind(actor.body)
			_check(skin.errors.is_empty(),"Actual hero skin binds at age%d LOD%d"%[age,level])
			var actions: Array[String]=["run","side_kick","high_kick","death"]
			for action: String in actions:
				actor.sample_pose(action,0.0)
				var duration: float=Motion.TIMING[action].z if Motion.TIMING.has(action) else actor.animator.current_animation_length
				var count:=maxi(1,ceili(duration*60.0))
				var violations:=0
				var penetration:=0.0
				var finite:=true
				var worst: Dictionary={}
				var worst_sole: Dictionary={}
				for frame in range(count+1):
					var phase:=float(frame)/float(count)
					actor.sample_pose(action,phase)
					actor._motion.skeleton.force_update_all_bone_transforms()
					var sample:=skin.sample()
					finite=finite and bool(sample.finite)
					violations+=int(sample.skin_edge_violations)
					if float(sample.max_sole_penetration_m)>penetration:
						penetration=float(sample.max_sole_penetration_m)
						worst_sole=sample.lowest_sole_vertex.duplicate(true)
						worst_sole.phase=phase
					if float(sample.worst_skin_edge.get("excess_m",0.0))>float(worst.get("excess_m",0.0)):
						worst=sample.worst_skin_edge.duplicate(true)
						worst.phase=phase
				var label:="age%d LOD%d %s"%[age,level,action]
				_check(finite,label+" has finite actual posed geometry")
				_check(violations==0,label+" has no severe skin/cloth edge tears: "+JSON.stringify(worst))
				if action=="death":
					_check(penetration<=.01,label+" sole does not penetrate the actual floor over10mm: "+str(penetration))
				records.append({"age":age,"lod":level,"clip":action,"sample_hz":60,"samples":count+1,
					"finite":finite,"skin_edge_violations":violations,"max_sole_penetration_m":penetration,
					"worst_sole":worst_sole,"worst_skin_edge":worst})
			print("HERO_CLOTH_GROUNDING age",age," LOD",level," measured")
		actor.free()
	var args:=OS.get_cmdline_user_args()
	if not args.is_empty():
		var file:=FileAccess.open(args[0],FileAccess.WRITE)
		file.store_string(JSON.stringify({"checks":checks,"failed":failed,"records":records},"  ")+"\n")
		file.close()
	print("HERO_CLOTH_GROUNDING_TEST ",checks," checks; ",failed," failed")
	quit(0 if failed==0 else 1)
