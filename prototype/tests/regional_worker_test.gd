extends SceneTree
## Actual regional worker, controller, collision and pause regression.
const Region = preload("res://scripts/world/regional_village.gd")
var failures: Array[String] = []
var checks := 0

func _initialize() -> void:
	_run.call_deferred()

func _check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures.append(message)
		push_error(message)

func _run() -> void:
	var region := Region.new()
	root.add_child(region)
	region.set_physics_process(false)
	for origin: String in ["germania", "han", "wa"]:
		region.show_origin(origin)
		region.set_active(true)
		region.worker_figure.set_process(false)
		await physics_frame
		var expected := origin+"_farmer" if origin in ["han","wa"] else "farmer"
		_check(region.worker_figure.active_model_path.ends_with("/"+expected+".glb"), origin+" preserves its actual regional source")
		var start := region.worker.position
		var seen := {}
		var max_step := 0.0
		var distance := 0.0
		for frame in 420:
			var before := region.worker.position
			region._physics_process(1.0/60.0)
			region.worker_figure._process(1.0/60.0)
			var step := before.distance_to(region.worker.position)
			max_step = maxf(max_step,step)
			distance += step
			seen[region.worker_figure.clip] = true
		_check(distance > 1.8 and start.distance_to(region.worker.position)>1.8, origin+" walks between actual work stations")
		_check(max_step <= 1.05/60.0+.0001, origin+" bounded swept movement without teleports")
		_check(seen.has("work") and seen.has("march") and seen.has("idle"), origin+" work/walk/stop poses are wired")
		region.set_active(false)
		var paused := region.worker.position
		var phase: float = region.worker_figure.phase
		for frame in 60:
			region._physics_process(1.0/60.0)
		_check(region.worker.position.is_equal_approx(paused) and is_equal_approx(region.worker_figure.phase,phase), origin+" pause freezes motion and animation clock")
		region.set_active(true)
		region.worker_figure.set_process(false)
		region.worker.position = Vector3(-4,0,7)
		region._worker_target = 1
		region._worker_rest = 0.0
		var wall := StaticBody3D.new()
		wall.collision_layer = 1
		wall.position = Vector3(-3.3,1,7)
		var shape := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = Vector3(.2,2,2)
		shape.shape = box
		wall.add_child(shape)
		root.add_child(wall)
		await physics_frame
		for frame in 180:
			region._physics_process(1.0/60.0)
			region.worker_figure._process(1.0/60.0)
		_check(region.worker.position.x < -3.67, origin+" cannot walk through a real wall")
		_check(region.worker_figure.speed < .001, origin+" blocked body also stops the visible stride")
		wall.free()
	region.show_origin("italia")
	_check(not is_instance_valid(region.worker),"Italian named population is not duplicated by a regional worker")
	region.free()
	print("REGIONAL_WORKERS_PASS" if failures.is_empty() else "REGIONAL_WORKERS_FAIL"," ",checks," checks; failures=",failures.size())
	quit(0 if failures.is_empty() else 1)
