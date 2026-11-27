extends SceneTree
const Village := preload("res://scripts/world/village_life_world.gd")
const Person := preload("res://scripts/visuals/village_person.gd")
const City := preload("res://scripts/world/city_resident_view.gd")
var failures := 0
func _initialize() -> void:
	_run.call_deferred()
func check(value: bool, why: String) -> void:
	if not value:
		failures += 1
		push_error(why)
func _run() -> void:
	var village := Village.new()
	root.add_child(village)
	village.set_physics_process(false)
	var first := StaticBody3D.new()
	first.collision_layer = 5
	village.add_child(first)
	village._set_collisions(false)
	check(first.collision_layer == 0,"Existing body disabled")
	check(not village._collision_bodies_dirty,"Initial scan cached")
	var second := StaticBody3D.new()
	second.collision_layer = 3
	village.add_child(second)
	check(village._collision_bodies_dirty,"New collider invalidates enumeration")
	village._set_collisions(false)
	check(second.collision_layer == 0,"New collider cannot stay enabled")
	village.remove_child(first)
	check(village._collision_bodies_dirty,"Removed collider invalidates enumeration")
	first.free()
	village._set_collisions(true)
	check(second.collision_layer == 3,"Original collision layer restored")
	var unrelated := StaticBody3D.new()
	root.add_child(unrelated)
	check(not village._collision_bodies_dirty,"Unrelated tree does not invalidate cache")
	unrelated.free()
	check(not Person.far_foot_contacts("low") and Person.far_foot_contacts("balanced") and Person.far_foot_contacts("high") and Person.far_foot_contacts("very_high"),"Far contact optimisation is low-profile only")
	check(City.LIMITS.low == 3 and City.LIMITS.high == 16 and City.LIMITS.very_high == 24,"Bounded city actor budgets")
	village.free()
	print("RECOVERED_POPULATION_PERF_PASS" if failures==0 else "RECOVERED_POPULATION_PERF_FAIL")
	quit(0 if failures==0 else 1)
