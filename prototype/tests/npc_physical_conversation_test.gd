extends SceneTree
## A real Godot physics test: two visible resident bodies must not talk, turn
## their faces or earn a visual speaking pose through a wall.
const Model = preload("res://scripts/domain/world_model.gd")
const World = preload("res://scripts/world/game_world.gd")
var checks := 0
var failures: Array[String] = []


func _initialize() -> void:
	if OS.get_environment("IMPERATHEN_ISOLATED_TEST") != "1":
		printerr("Isolated test account required.")
		quit(2)
		return
	_run.call_deferred()


func _check(ok: bool, description: String) -> void:
	checks += 1
	if not ok:
		failures.append(description)
		printerr("FAIL: " + description)


func _wall(parent: Node3D, at: Vector3, height: float) -> StaticBody3D:
	var wall := StaticBody3D.new()
	wall.name = "ConversationBlocker"
	wall.collision_layer = 1
	wall.collision_mask = 0
	wall.position = at + Vector3(0,height*0.5,0)
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(0.20,height,2.0)
	shape.shape = box
	wall.add_child(shape)
	parent.add_child(wall)
	return wall


func _run() -> void:
	var model := Model.new()
	model.new_game("italia",true,true)
	var world := World.new()
	root.add_child(world)
	world.setup(model.data)
	world.set_active(true)
	world.set_physics_process(false)
	await physics_frame
	await physics_frame
	var residents: Dictionary = world.village_life_world.actors
	_check(residents.has("julia") and residents.has("antonia"), "The real village creates both story market residents")
	if not residents.has("julia") or not residents.has("antonia"):
		quit(1)
		return
	var speaker := residents["julia"] as Node3D
	var listener := residents["antonia"] as Node3D
	var original_actor := speaker.position
	var original_peer := listener.position
	# Independent visual/physics fixture: neither quest location nor save file
	# is changed. The test uses the two actual character bodies and scene rays.
	speaker.position = Vector3(110.0,0.0,110.0)
	listener.position = Vector3(111.20,0.0,110.0)
	model.data.village.behavior.people.julia.activity = "socialize"
	model.data.village.behavior.people.julia.partner = "antonia"
	model.data.village.behavior.people.antonia.activity = "socialize"
	model.data.village.behavior.people.antonia.partner = "julia"
	var intent: Dictionary = {"activity":"socialize","partner":"antonia"}
	var initial_money := int(model.data.resources.denarii)
	var original_social := JSON.stringify(model.data.village.behavior.social)
	await physics_frame
	_check(world.npc_sight_clear(speaker.global_position,listener.global_position),
		"Two residents on a clear walkway see one another")
	var open_contact: Dictionary = world.village_life_world._physical_social_contact("julia",speaker,intent,Vector3.ZERO)
	_check(not open_contact.is_empty(),"At 1.2 metres, mutually chosen neighbors may speak without obstacles")
	var wall := _wall(world,Vector3(110.60,0,110.0),2.3)
	await physics_frame
	await physics_frame
	_check(not world.npc_sight_clear(speaker.global_position,listener.global_position),
		"A real building wall blocks both sight heights")
	_check(world.village_life_world._physical_social_contact("julia",speaker,intent,Vector3.ZERO).is_empty(),
		"Social presentation rejects an apparently close neighbor on the far side")
	world.village_life_world._set_social_pose(speaker,false)
	var yaw_before: float = speaker.rotation.y
	world.village_life_world._update_attention(0.1)
	_check(not bool(speaker.get_meta("physical_social_pose",false)),
		"Blocked pair never starts a visible talking pose")
	_check(is_equal_approx(speaker.rotation.y,yaw_before),
		"Blocked pair does not turn its face toward a person through the wall")
	wall.free()
	var lower_wall := _wall(world,Vector3(110.60,0,110.0),1.1)
	await physics_frame
	await physics_frame
	_check(not world.npc_sight_clear(speaker.global_position,listener.global_position),
		"A low wall blocks waist-height contact even if the eye ray passes over it")
	lower_wall.free()
	await physics_frame
	await physics_frame
	_check(world.npc_sight_clear(speaker.global_position,listener.global_position),
		"Visibility responds immediately to removing a wall")
	world.village_life_world._update_attention(0.1)
	_check(bool(speaker.get_meta("physical_social_pose",false)),
		"Conversation animation becomes available once the real physical corridor clears")
	# One-sided conversations cannot create false mouth motion.
	model.data.village.behavior.people.antonia.partner = ""
	world.village_life_world._update_attention(0.1)
	_check(not bool(speaker.get_meta("physical_social_pose",false)),
		"One-sided social intentions cannot start the conversation pose")
	model.data.village.behavior.people.antonia.partner = "julia"
	listener.position = Vector3(114.0,0.0,110.0)
	await physics_frame
	world.village_life_world._update_attention(0.1)
	_check(not bool(speaker.get_meta("physical_social_pose",false)),
		"Visible but distant residents do not talk across several metres")
	listener.position = Vector3(111.2,0.0,110.0)
	listener.visible = false
	world.village_life_world._update_attention(0.1)
	_check(not bool(speaker.get_meta("physical_social_pose",false)),
		"An invisible, unloaded or absent neighbor cannot be addressed")
	listener.visible = true
	speaker.position = original_actor
	listener.position = original_peer
	_check(int(model.data.resources.denarii)==initial_money and
		JSON.stringify(model.data.village.behavior.social)==original_social,
		"Visual gate grants neither money nor unobserved social memory")
	world.free()
	print("NPC_PHYSICAL_CONVERSATION_RESULT checks=%d failures=%d" % [checks, failures.size()])
	print("NPC_PHYSICAL_CONVERSATION_PASS" if failures.is_empty() else "NPC_PHYSICAL_CONVERSATION_FAIL")
	quit(0 if failures.is_empty() else 1)
