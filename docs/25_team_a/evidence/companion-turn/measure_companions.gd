extends SceneTree
const WorldMeasurement = preload("route_phase_observer.gd")
const World = preload("res://scripts/world/game_world.gd")
const Model = preload("res://scripts/domain/world_model.gd")
func _initialize() -> void:
	_run.call_deferred()
func _run() -> void:
	var m = WorldMeasurement.new()
	m._tree = self
	var model = Model.new()
	model.new_game("italia",true,true)
	var world := World.new()
	root.add_child(world)
	world.setup(model.data)
	world.set_active(true)
	world.set_physics_process(false)
	world.village_life_world.set_physics_process(false)
	m._manual_people(world)
	await physics_frame
	await physics_frame
	var family = m._family()
	await m._companions(world,family)
	var output := "user://companion-routes.json"
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--output="):
			output = argument.trim_prefix("--output=")
	var f = FileAccess.open(output,FileAccess.WRITE)
	if f == null:
		push_error("Cannot write route evidence: " + output)
		world.free()
		quit(1)
		return
	f.store_string(JSON.stringify(family,"  "))
	print("COMPANIONS_MEASURED ",JSON.stringify({"metrics":family.metrics,"errors":family.errors,"routes":family.companion_routes}))
	world.free()
	quit(0 if family.errors.is_empty() else 1)
