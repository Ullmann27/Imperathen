extends SceneTree
## Sample the imported mesh-space bones, then drive the live scene at 50 Hz.
const Actor := preload("res://scripts/visuals/soldier_visual.gd")
const Ranks := preload("res://scripts/visuals/far_ranks.gd")
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
	_test_far_motion()
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


func _test_far_motion() -> void:
	var max_slip := 0.0
	for gait: String in Ranks.STANCE:
		var stride: float = Actor.STRIDES[gait]
		var stance: float = Ranks.STANCE[gait]
		for side: float in [-1.0,1.0]:
			var phase_offset := 0.0 if side < 0 else .5
			var vertex := Vector3(side*.126,.011,.06)
			var first := Vector3.ZERO
			for i in 61:
				var phase := stance*float(i)/60.0
				var data := Ranks.gait_data(gait,phase-phase_offset,phase-phase_offset)
				var foot := Ranks.deformed_vertex(vertex,data,1.0)+Vector3.BACK*phase*stride
				if i == 0:
					first = foot
				max_slip = maxf(max_slip,foot.distance_to(first))
			_check(max_slip < .00001,"Far stance cancels actual root distance for "+gait)
		_check(Ranks.foot_offset(.999999,gait).distance_to(Ranks.foot_offset(0,gait)) < .00001,"Far stride wraps without a positional seam: "+gait)
		var left_velocity := (Ranks.foot_offset(stance,gait)-Ranks.foot_offset(stance-.0001,gait))/.0001
		var right_velocity := (Ranks.foot_offset(stance+.0001,gait)-Ranks.foot_offset(stance,gait))/.0001
		_check(left_velocity.distance_to(right_velocity) < .02,"Far support-to-swing velocity is continuous: "+gait)
	var start := Transform3D(Basis(Vector3.UP,deg_to_rad(170)),Vector3(-1,.2,3))
	var finish := Transform3D(Basis(Vector3.UP,deg_to_rad(-165)),Vector3(-.7,.3,3.1))
	var previous := Ranks.root_data(start,finish)
	_check(Ranks.interpolated_root(finish,previous,0).is_equal_approx(start),"Far transform starts at the actual previous root even through a wrapped turn")
	_check(Ranks.interpolated_root(finish,previous,1).is_equal_approx(finish),"Far transform reaches the exact next simulation root")
	var middle := Ranks.interpolated_root(finish,previous,.5)
	_check(middle.origin.distance_to(start.origin.lerp(finish.origin,.5)) < .000001,"Far diagonal/height interpolation follows the same root path as nearby skeletons")
	_check(middle.basis.get_rotation_quaternion().angle_to(start.basis.get_rotation_quaternion()) < deg_to_rad(13),"Far yaw interpolates by the short arc instead of snapping to the next heading")
	var ranks := Ranks.new()
	root.add_child(ranks)
	ranks.sync({"heavy":[finish]},{"heavy":[Ranks.gait_data("march",.1,.2)]},{"heavy":[start]})
	var batch: MultiMeshInstance3D = ranks._batches.heavy
	_check(batch.multimesh.use_colors and batch.multimesh.use_custom_data,"Production MultiMesh enables the previous-root and gait instance channels")
	if DisplayServer.get_name() != "headless":
		# The dummy renderer does not retain per-instance color data. Verify GPU
		# storage only with a real rendering backend; never claim it headless.
		var stored := batch.multimesh.get_instance_color(0)
		_check(Vector4(stored.r,stored.g,stored.b,stored.a).distance_to(Vector4(previous.r,previous.g,previous.b,previous.a)) < .001,"Rendering backend retains the uploaded previous-root transform")
	var upper := Vector3(0,1.55,0)
	var idle := Ranks.deformed_vertex(upper,Ranks.gait_data("idle",0,0),1)
	var hit := Ranks.deformed_vertex(upper,Ranks.gait_data("hit",.5,.5),1)
	_check(idle.distance_to(hit) > .1,"Distant hit reaction visibly differs from a frozen idle silhouette")
	ranks.free()
	print("FAR_MOTION_RESULT max_support_slip_m=",max_slip)
