extends SceneTree
## Isolated Godot engine test of actual unarmed practice and defence.
## No quest/world-save mutation or real phone performance is claimed.
const Training = preload("res://scripts/world/city_training.gd")
var failures: Array[String] = []
var checks := 0

func _initialize() -> void:
	if OS.get_environment("IMPERATHEN_ISOLATED_TEST") != "1":
		printerr("CITY_TRAINING_TEST_REQUIRES_ISOLATION")
		quit(2)
		return
	_run.call_deferred()

func _check(ok: bool, description: String) -> void:
	checks += 1
	if not ok:
		failures.append(description)
		printerr("CITY_TRAINING_FAIL: "+description)

func _run() -> void:
	var world := Node3D.new()
	root.add_child(world)
	var training := Training.new()
	world.add_child(training)
	await physics_frame
	_check(training.available, "The original village training dummy and combat state are available")
	_check(is_instance_valid(training.dummy),"The physical 3D training prop comes from an authored GLB")
	_check(training.state().get("practice_hits",-1) == 0,"Unarmed sandbox starts with no awarded practice hits")
	var attack := training.execute_attack(Vector3(0.0,0.92,-5.8),0.0)
	_check(bool(attack.get("ok",false)),"Age 12 unarmed jab can enter the combat timing authority")
	var observed_hit := false
	for step in 55:
		await physics_frame
		var event: Dictionary = training.tick(1.0/60.0)
		if bool(event.get("practice",false)):
			observed_hit = true
	_check(observed_hit,"Only a timed, facing-checked contact can award the one practice hit")
	_check(training.state().get("practice_hits",-1) == 1,"A completed strike awards exactly one hit")
	_check(training.state().get("stamina",100.0) < 100.0,"The strike consumes real sandbox stamina")
	_check(not bool(training.state().get("service_gear",true)),"A child does not receive adult Gladius or Scutum entitlement")
	var blocked := training.execute_block()
	_check(bool(blocked.get("ok",false)),"Unarmed guard uses the existing authoritative defence window")
	_check(training.state().get("guard_remaining",0.0)>0.0,"Defence has a measurable expiration time")
	for step in 70:
		await physics_frame
		training.tick(1.0/60.0)
	_check(training.state().get("guard_remaining",-1.0)<0.0001,"Guard automatically expires")
	_check(training.state().get("stamina",100.0)<=100.0,"Stamina remains bounded")
	world.free()
	await process_frame
	print("CITY_TRAINING_RESULT "+JSON.stringify({"checks":checks,"failures":failures,"success":failures.is_empty(),"real_player_save":false,"android_device":false}))
	print("CITY_TRAINING_PASS" if failures.is_empty() else "CITY_TRAINING_FAIL")
	quit(0 if failures.is_empty() else 1)
