extends SceneTree
## Full-world checks for person identity, real placement and saved deaths.

const Model = preload("res://scripts/domain/world_model.gd")
const World = preload("res://scripts/world/game_world.gd")
var checks := 0
var failures: Array[String] = []


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var model := Model.new()
	model.new_game("italia",true,true)
	var world := World.new()
	root.add_child(world)
	world.setup(model.data)
	world.set_active(false)
	world.set_physics_process(false)
	await physics_frame
	await physics_frame
	var village: Node3D = world.village_life_world
	_check(village.actors.size()==15,"Fourteen real economy people plus their existing administrator are rendered")
	var stable_ids: Dictionary = {}
	var capsule := CapsuleShape3D.new()
	capsule.radius = .28
	capsule.height = 1.70
	for id: String in village.actors:
		var actor: Node3D = village.actors[id]
		stable_ids[id] = actor.get_instance_id()
		_check(actor.get_meta("resident_id","")==id,"Scene identity matches authoritative dictionary key: "+id)
		_check(actor.get_node("ResidentBody").collision_layer==1,"A living resident has a solid body: "+id)
		if world.population.actors.has(id):
			_check(not world.population.actors[id].visible,"The ambient layer does not duplicate economy identity: "+id)
		var query := PhysicsShapeQueryParameters3D.new()
		query.shape = capsule
		query.collision_mask = 1
		query.margin = .003
		query.exclude = [village.actor_collision_rid(id)]
		query.transform.origin = actor.global_position+Vector3.UP*.88
		var overlaps := world.get_world_3d().direct_space_state.intersect_shape(query,4)
		for hit: Dictionary in overlaps:
			printerr("RESIDENT_OVERLAP %s at %s -> %s"%[id,actor.position,hit.collider.get_path()])
		_check(overlaps.is_empty(),"Resident stands clear of buildings and other people: "+id)
	_check(absf(village.actors.julia.position.y-.3925)<.001,"Julia stands on the family's visible floor")
	_check(absf(village.actors.silvanus.position.y-.3925)<.001,"Silvanus shares the same real household floor")
	_check(absf(village.actors.sextus.position.y-.3925)<.001,"Sextus stands on the workshop floor")
	world.get_node("Player").position = Vector3(-1.4,1,24.9)
	_check(not world.can_talk_childhood("julia"),"Julia cannot be spoken to through the family house's east wall")
	world.get_node("Player").position = Vector3(-5,1.2925,25.2)
	_check(world.can_talk_childhood("julia"),"Julia is reachable from the free space inside her house")
	var bereaved: Dictionary = model.data.duplicate(true)
	for person: Dictionary in bereaved.village.economy.people:
		if person.id in ["silvanus","sextus"]:
			person.alive = false
			person.health = 0
			person.assignment = "idle"
	world.sync_state(bereaved)
	for id in ["silvanus","sextus"]:
		_check(not village.actors[id].visible,"The saved dead person is absent: "+id)
		_check(village.actors[id].get_node("ResidentBody").collision_layer==0,"The absent person leaves no invisible collider: "+id)
		_check(not world.can_talk_childhood(id),"A dead person cannot reopen a conversation: "+id)
	_check(village.actors.julia.visible,"The saved surviving mother stays visible")
	world.set_quality("low")
	world.sync_state(bereaved)
	for id: String in stable_ids:
		_check(village.actors[id].get_instance_id()==stable_ids[id],"Quality and scene sync preserve the existing person node: "+id)
	model.new_game("han",false,false)
	world.setup(model.data)
	_check(not village.visible,"A different regional game hides the Roman economy population")
	for id: String in village.actors:
		_check(village.actors[id].get_node("ResidentBody").collision_layer==0,"A later legacy/region game leaves no Roman ghost body: "+id)
	world.free()
	await process_frame
	print("CHILDHOOD_RESIDENT_IDENTITY_RESULT checks=%d failures=%d"%[checks,failures.size()])
	for message: String in failures: printerr("FAIL: "+message)
	quit(0 if failures.is_empty() else 1)


func _check(value: bool,message: String) -> void:
	checks += 1
	if not value:
		failures.append(message)
		push_error(message)
