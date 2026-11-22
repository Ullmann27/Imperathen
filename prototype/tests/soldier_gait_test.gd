extends SceneTree
## Sample the imported mesh-space bones, then drive the live scene at 50 Hz.
const Actor := preload("res://scripts/visuals/soldier_visual.gd")
const Valley := preload("res://scripts/tactics/valley_scene.gd")
const Stance := {"march":0.58,"run":0.40,"retreat":0.51}
var checks := 0
var failures := 0


func _initialize() -> void:
	_run.call_deferred()


func _check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("FAIL ",message)


func _run() -> void:
	var max_slip := 0.0
	var max_vertical := 0.0
	var lowest_sole := 1.0
	for role in Actor.ROLES:
		var a := Actor.new()
		a.role = role
		root.add_child(a)
		for lod in [0,1]:
			a.set_detail(lod)
			var skel: Skeleton3D = a.find_children("*","Skeleton3D",true,false)[0]
			for gait in Stance:
				a.play_state(gait)
				var stride: float = Actor.STRIDES[gait]
				for foot in ["Foot_R","Foot_L"]:
					var bone := skel.find_bone(foot)
					var offset := 0.0 if foot == "Foot_R" else 0.5
					var peak := 0.0
					var planted := Vector3.ZERO
					var slip := 0.0
					var vertical := 0.0
					var knee := skel.find_bone("Shin_R" if foot == "Foot_R" else "Shin_L")
					var max_bend := 0.0
					for i in range(101):
						var cycle := i/100.0
						a.player.seek(fposmod(cycle + offset,1.0)*a.player.current_animation_length,true)
						a.player.advance(0)
						var foot_pose := skel.get_bone_global_pose(bone)
						var ankle := foot_pose.origin
						var skinning := foot_pose * skel.get_bone_global_rest(bone).affine_inverse()
						for local_z in [0.175,-0.065]:
							var sole := skinning * Vector3(-0.126 if foot == "Foot_R" else 0.126,0.011,local_z)
							lowest_sole = minf(lowest_sole,sole.y)
						var step := ankle + Vector3.BACK*cycle*stride
						if i == 0:
							planted = step
						if cycle <= float(Stance[gait]):
							slip = maxf(slip,absf(step.z-planted.z))
							vertical = maxf(vertical,absf(ankle.y-0.12))
						else:
							peak = maxf(peak,ankle.y - 0.12)
							max_bend = maxf(max_bend,skel.get_bone_pose_rotation(knee).angle_to(skel.get_bone_rest(knee).basis.get_rotation_quaternion()))
					_check(slip < 0.015 and vertical < 0.015,"Planted ankle world drift "+gait+" "+role+" "+foot)
					_check(peak > 0.09 and max_bend > deg_to_rad(45),"Swing clears floor with flexed knee "+gait+" "+role)
					max_slip = maxf(slip,max_slip)
					max_vertical = maxf(vertical,max_vertical)
			if role in ["heavy","spear"]:
				a.play_state("march")
				var wrist := skel.find_bone("Hand_R" if role == "spear" else "Hand_L")
				var max_tilt := 0.0
				for i in range(51):
					a.player.seek(a.player.current_animation_length*i/50.0,true)
					a.player.advance(0)
					var binding := skel.get_bone_global_pose(wrist)*skel.get_bone_global_rest(wrist).affine_inverse()
					max_tilt = maxf(max_tilt,Vector3.UP.angle_to(binding.basis*Vector3.UP))
				_check(max_tilt < deg_to_rad(16),"Shield or upright spear grip remains stable during march")
		a.free()
	_check(lowest_sole >= -0.01, "Heel and forefoot probes stay above the terrain plane")
	_test_scene()
	print("SOLDIER_GAIT_RESULT checks=%d failures=%d max_stance_slip_m=%.4f max_stance_height_error_m=%.4f lowest_sole_m=%.4f" % [checks,failures,max_slip,max_vertical,lowest_sole])
	quit(1 if failures else 0)


func _test_scene() -> void:
	var v := Valley.new()
	root.add_child(v)
	v.set_process(false)
	v.focus = Vector2(-7,8)
	v.distance = 7
	v._place_camera()
	v._sync_units()
	var initial: Dictionary = v.model.snapshot()
	var reference = v.model.get_script().new()
	reference.restore(initial)
	for model in [v.model,reference]:
		model.order(["valley_guard"], "move", Vector2(-7,-8))
	v.paused = false
	var id := "valley_guard_01"
	var moved := false
	for i in range(140):
		v._process(0.02)
		reference.tick(0.02)
		if v.motion[id].pose == "march":
			moved = true
	_check(moved,"Actual order produces marching animation")
	_check(v.model.snapshot() == reference.snapshot(),"Rendering, animation and interpolation preserve exact rule simulation")
	var node = v.actors[id]
	var phase: float = node.player.current_animation_position
	var position: Vector3 = node.position
	v.paused = true
	for i in 30:
		v._process(0.02)
	_check(position == node.position and is_equal_approx(phase,node.player.current_animation_position),"Pause freezes animated position and pose")
	_check(absf(v.motion[id].phase0-v.motion.valley_guard_02.phase0) > 0.015,"Stable member phases distinguish the rank")
	var before_lod := float(node.player.current_animation_position)
	v.distance = 100
	v._place_camera()
	v._sync_units()
	v.distance = 7
	v._place_camera()
	v._sync_units()
	v._process(0)
	node = v.actors[id]
	_check(absf(before_lod-node.player.current_animation_position) < 0.025,"Far-to-near transition retains step phase")
	var restored := Valley.new()
	restored.model.restore(v.model.snapshot())
	root.add_child(restored)
	restored.set_process(false)
	restored.focus = v.focus
	restored.distance = 7
	restored._place_camera()
	restored._sync_units()
	restored._process(0)
	var hold: Vector3 = restored.actors[id].position
	restored._process(0.1)
	_check(restored.actors[id].position == hold and restored.model.snapshot() == v.model.snapshot(),"Paused re-entry keeps saved position and rule state")
	restored.free()
	v.free()
