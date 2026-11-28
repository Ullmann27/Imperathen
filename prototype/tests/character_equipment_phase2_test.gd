extends SceneTree
## Actual imported rig and real catalog/prop assets. Explicit adult fixture;
## does not grant equipment to the campaign or certify a historical model.
const Scene: PackedScene = preload("res://scenes/character_core/equipment_character.tscn")
const Model = preload("res://scripts/domain/world_model.gd")
const Gear = preload("res://scripts/domain/gear_market.gd")
const Calendar = preload("res://scripts/domain/world_calendar.gd")
const Visuals = preload("res://scripts/visuals/gear_visuals.gd")
const SITES: Dictionary = {"outfitter": Vector3(16, 1, 4), "smith": Vector3(10, 1, 4), "home": Vector3(-12.05, 1, 10.55), "market": Vector3(-10, 1, 4), "stable": Vector3(16, 1, -8)}
var checks: int = 0
var failures: Array[String] = []

func _initialize() -> void:
	if OS.get_environment("IMPERATHEN_ISOLATED_TEST") != "1":
		quit(2)
		return
	_run.call_deferred()

func _check(condition: bool, label: String) -> bool:
	checks += 1
	if not condition:
		failures.append(label)
		printerr("CHARACTER_PHASE2_FAIL ", label)
	return condition

func _frames(count: int) -> void:
	for frame: int in range(count):
		await physics_frame
		await process_frame

func _gear_count(rig: Skeleton3D) -> int:
	var count: int = 0
	for child: Node in rig.get_children():
		if child.get_meta("phase2_equipment", false):
			count += 1
	return count

func _check_socket(actor: CharacterCore, component: EquipmentComponent, slot: String, place: String) -> void:
	var attachment: BoneAttachment3D = component.get_attachment(slot)
	if not _check(attachment != null, slot + " attachment exists"):
		return
	var spec: Dictionary = Visuals.ATTACH[place]
	var rig: Skeleton3D = actor.get_character_skeleton()
	var marker: Node3D = attachment.find_child(str(spec.socket), true, false) as Node3D
	if not _check(marker != null, slot + " real authored marker exists"):
		return
	_check(component.get_place(slot) == place and attachment.bone_name == str(spec.bone), slot + " declared destination")
	var bone: int = rig.find_bone(str(spec.bone))
	var offset: Vector3 = spec.offset
	var inverse: Basis = rig.get_bone_global_rest(bone).basis.orthonormalized().inverse()
	var expected: Vector3 = attachment.global_transform * (inverse * offset / rig.global_basis.get_scale().x)
	var error: float = marker.global_position.distance_to(expected)
	_check(is_finite(error) and error <= 0.002, "%s/%s authored socket residual %.6f m" % [slot, place, error])
	print("CHARACTER_PHASE2_SOCKET ", slot, " ", place, " residual_m=", error)

func _run() -> void:
	var stage: Node3D = Node3D.new()
	root.add_child(stage)
	var ground: StaticBody3D = StaticBody3D.new()
	ground.collision_layer = 1
	ground.collision_mask = 0
	ground.position.y = -0.1
	var shape: CollisionShape3D = CollisionShape3D.new()
	var box: BoxShape3D = BoxShape3D.new()
	box.size = Vector3(80, 0.2, 80)
	shape.shape = box
	ground.add_child(shape)
	stage.add_child(ground)
	var actor: CharacterCore = Scene.instantiate() as CharacterCore
	actor.position.y = 0.05
	stage.add_child(actor)
	var component: EquipmentComponent = actor.get_node_or_null("EquipmentComponent") as EquipmentComponent
	if not _check(actor.is_character_ready() and component != null and component.is_equipment_ready(), "Integrated component binds original phase-one rig"):
		_finish()
		return
	await _frames(90)
	var rig: Skeleton3D = actor.get_character_skeleton()
	var model: Model = Model.new()
	model.new_game("italia", true, true)
	model.gear_sites = SITES.duplicate()
	_check(bool(model.execute("gear_enable").get("ok", false)), "Enable real child-world gear")
	_check(component.sync_from_world(model.data) and _gear_count(rig) == 0, "Child receives no gear")
	_check(not component.request_socket_switch("main_hand", "hip_right", &"block"), "No invented weapon on child")
	var data: Dictionary = model.data.duplicate(true)
	data.player.age = 20
	data.player.role = "soldier"
	data.progress.training_complete = true
	data.progress.stage = "trained"
	data.resources.denarii = 400
	data.village.economy.stocks.merchant_denarii = 100
	data.player.position = [16.0, 1.0, 4.0]
	_check(Gear.world_jdn(data) == Calendar.to_jdn(-58, 5, 1), "Original campaign epoch")
	_check(not bool(Gear.apply(data, "gear_buy", {"shop_id": "outfitter", "item_id": "spatha", "quality": 2}, SITES).ok), "Later spatha remains locked")
	for id: String in ["gladius", "scutum"]:
		_check(bool(Gear.apply(data, "gear_buy", {"shop_id": "outfitter", "item_id": id, "quality": 2}, SITES).ok), "Purchase real catalog " + id)
	for uid: int in [1, 2]:
		_check(bool(Gear.apply(data, "gear_equip", {"uid": uid}, SITES).ok), "Equip real owned receipt")
	if not _check(Gear.validate(data).is_empty(), "Adult domain fixture validates"):
		_finish()
		return
	var before: String = JSON.stringify(data)
	if not _check(component.sync_from_world(data), "Load actual owned gear"):
		_finish()
		return
	await _frames(10)
	_check(_gear_count(rig) == 2, "Exactly two owned attachments")
	_check_socket(actor, component, "main_hand", "hand_right")
	_check_socket(actor, component, "shield", "hand_left")
	var original: BoneAttachment3D = component.get_attachment("main_hand")
	var original_id: int = original.get_instance_id()
	_check(component.sync_from_world(data) and component.get_attachment("main_hand").get_instance_id() == original_id, "Idempotent snapshot avoids rebuild")
	_check(not component.request_socket_switch("main_hand", "hip_right", &"missing_draw_clip"), "Missing animation rejected")
	_check(not component.request_socket_switch("main_hand", "hand_left", &"block"), "Wrong place rejected")
	actor.request_motion(Vector3.FORWARD, 1.0, CharacterCore.Gait.WALK)
	await _frames(70)
	var start: Vector3 = actor.global_position
	_check(component.request_socket_switch("main_hand", "hip_right", &"block", 3.0), "Known block clip as explicit layer test, not a draw animation")
	_check(not component.request_socket_switch("shield", "back", &"block"), "Concurrent transition rejected")
	await _frames(25)
	_check(component.get_place("main_hand") == "hand_right", "Before explicit marker remains in hand")
	_check(float(actor.get_animation_tree().get("parameters/UpperBody/blend_amount")) > 0.8, "Actual filtered upper-body layer blends")
	_check(actor.global_position.distance_to(start) > 0.3 and actor.get_planar_speed() > 0.8, "Walking continues during upper-body transition")
	_check(component.commit_socket_switch(), "Explicit marker switches to hip")
	_check(not component.commit_socket_switch(), "Marker cannot commit twice")
	await _frames(10)
	_check(component.get_attachment("main_hand").get_instance_id() == original_id, "Socket change keeps same prop attachment")
	_check_socket(actor, component, "main_hand", "hip_right")
	component.finish_socket_switch()
	await _frames(25)
	_check(float(actor.get_animation_tree().get("parameters/UpperBody/blend_amount")) < 0.03 and not component.is_physics_processing(), "Layer and idle transition processing stop")
	_check(component.request_socket_switch("shield", "back", &"block"), "Shield can switch to back")
	_check(component.commit_socket_switch(), "Back marker commits")
	component.finish_socket_switch()
	await _frames(10)
	_check_socket(actor, component, "shield", "back")
	_check(not component.request_socket_switch("main_hand", "back", &"block"), "Occupied back socket rejected")
	_check(component.request_socket_switch("main_hand", "hand_right", &"block", 0.15), "Pending transition with timeout")
	await _frames(25)
	_check(not component.is_switch_pending() and not component.is_physics_processing() and component.get_place("main_hand") == "hip_right", "Timeout clears animation without switching")
	_check(component.sync_from_world(data, 3), "Actual far equipment LOD")
	await _frames(10)
	_check(_gear_count(rig) == 2 and component.get_attachment("main_hand").get_meta("model_path") == Gear.model_path("gladius", 2), "LOD swaps without duplicate gear")
	_check_socket(actor, component, "main_hand", "hip_right")
	_check_socket(actor, component, "shield", "back")
	_check(JSON.stringify(data) == before, "Presentation never writes inventory, money, or progression")
	var invalid: Dictionary = data.duplicate(true)
	invalid.player.age = 12
	_check(not component.sync_from_world(invalid) and _gear_count(rig) == 0, "Invalid child snapshot clears stale adult gear")
	_check(component.sync_from_world(data) and _gear_count(rig) == 2, "Valid snapshot recovers")
	_check(bool(Gear.apply(data, "gear_equip", {"uid": 1}, SITES).ok), "Authoritative unequip")
	_check(component.sync_from_world(data) and _gear_count(rig) == 1 and component.get_attachment("main_hand") == null, "Removed owned slot cannot remain visible")
	component.clear_equipment()
	_check(_gear_count(rig) == 0 and not component.is_physics_processing(), "Explicit cleanup")
	stage.free()
	_finish()

func _finish() -> void:
	print("CHARACTER_PHASE2_RESULT checks=%d failures=%d" % [checks, failures.size()])
	print("CHARACTER_PHASE2_PASS" if failures.is_empty() else "CHARACTER_PHASE2_FAIL")
	quit(0 if failures.is_empty() else 1)
