extends SceneTree
## Imported props on the production actor, including hand motion and LOD reload.

const Person := preload("res://scripts/visuals/village_person.gd")
const Equipment := preload("res://scripts/visuals/meshy_equipment.gd")
const SocketMeasurement := preload("res://tests/motion_equipment_measurement.gd")
const EXPECTED := {
	"unit_germanic_axe_fighter":{"weap_germanic_hand_axe":"Hand_R", "gear_germanic_round_shield":"Hand_L"},
	"unit_roman_signifer":{"gear_roman_signum":"Hand_R"}}
const BUDGETS := {"weap_germanic_hand_axe":[1200,350], "gear_germanic_round_shield":[1800,450], "gear_roman_signum":[1400,450]}
var checks := 0
var failures: Array[String] = []
var stage: Node3D
var output := ""
var captures: Array[Dictionary] = []


func _check_physical_socket(attachment: BoneAttachment3D, label: String) -> void:
	var rig:=attachment.get_parent() as Skeleton3D
	var fixture:=SocketMeasurement.new()
	var baseline:=fixture._socket(attachment,rig)
	_check(baseline.finite and float(baseline.get("max_socket_drift_m",INF))<.002 and float(baseline.get("max_socket_orientation_error_deg",INF))<2.0,label+" actual exported grip frame matches the declared hand attachment")
	var grip:=attachment.get_node("Grip") as Node3D
	var original:=grip.transform
	grip.position+=Vector3(.012,0,0)
	var displaced:=fixture._socket(attachment,rig)
	_check(displaced.finite and float(displaced.max_socket_drift_m)>.011,label+" catches displaced child prop even while BoneAttachment stays correct")
	grip.transform=original
	grip.rotate_object_local(Vector3.UP,deg_to_rad(10.0))
	var rotated:=fixture._socket(attachment,rig)
	_check(rotated.finite and float(rotated.max_socket_orientation_error_deg)>9.0,label+" catches rotated child prop")
	grip.transform=original
	var socket_name:="SOCKET_RIGHT_HAND" if attachment.bone_name=="Hand_R" else "SOCKET_LEFT_HAND"
	var socket:=attachment.find_child(socket_name,true,false) as Node3D
	if socket!=null:
		socket.name="MissingGripDuringNegativeCheck"
		_check(not fixture._socket(attachment,rig).finite,label+" rejects missing model grip marker")
		socket.name=socket_name


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if not args.is_empty():
		output = args[0]
		DirAccess.make_dir_recursive_absolute(output)
	_run.call_deferred()


func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)
		push_error(message)


func _attachments(person: Person) -> Array[BoneAttachment3D]:
	var result: Array[BoneAttachment3D] = []
	for node: Node in person.body.find_children("*", "BoneAttachment3D", true, false):
		if node.get_meta("meshy_equipment", false):
			result.append(node as BoneAttachment3D)
	return result


func _run() -> void:
	stage = Node3D.new()
	root.add_child(stage)
	_setup_studio()
	_check(not Equipment.has_complete_set("unsupported_source"), "Unreviewed sources cannot satisfy the equipment contract")
	for identity: String in EXPECTED:
		_check(Equipment.has_complete_set(identity), identity + " has both required mobile equipment tiers")
		var person := Person.new()
		stage.add_child(person)
		person.position.y = .9
		person.set_process(false)
		person.configure_resident("germania" if "germanic" in identity else "italia", 32, "spearman" if "germanic" in identity else "legionary")
		_check(person.configure_meshy(identity), identity + " selects the production Meshy actor")
		var prior: Array[int] = []
		for level in 4:
			person._reload(level)
			for old: int in prior:
				_check(not is_instance_id_valid(old), "Replacing a model frees its previous equipment")
			var attachments := _attachments(person)
			_check(attachments.size() == EXPECTED[identity].size(), identity + " complete loadout at LOD " + str(level))
			var tier := 0 if level <= 1 else 1
			for attachment: BoneAttachment3D in attachments:
				var asset := str(attachment.get_meta("asset_id"))
				_check(EXPECTED[identity].get(asset, "") == attachment.bone_name and not attachment.override_pose, asset + " uses its actual hand without overriding the rig")
				_check(attachment.get_meta("model_path") == Equipment.PATH % [asset, tier], asset + " selects the matching mobile tier")
				var meshes := attachment.find_children("*", "MeshInstance3D", true, false)
				_check(meshes.size() == 1 and attachment.find_children("*", "CollisionObject3D", true, false).is_empty(), asset + " is one rigid visual mesh without gameplay collision")
				if meshes.size() == 1:
					var mesh := meshes[0] as MeshInstance3D
					var triangles := 0
					for surface in mesh.mesh.get_surface_count():
						triangles += mesh.mesh.surface_get_array_index_len(surface) / 3
						var material := mesh.get_active_material(surface) as StandardMaterial3D
						_check(material != null and material.albedo_texture != null and material.albedo_texture.get_width() <= (512 if tier == 0 else 256), asset + " keeps bounded real source textures")
					_check(mesh.skin == null and triangles > 0 and triangles <= BUDGETS[asset][tier], asset + " respects rigid triangle budget")
			person.sample_pose("march", .13)
			await process_frame
			var before := {}
			for attachment: BoneAttachment3D in attachments:
				before[attachment.get_meta("asset_id")] = attachment.global_transform
			person.sample_pose("march", .65)
			await process_frame
			for attachment: BoneAttachment3D in attachments:
				var rig := attachment.get_parent() as Skeleton3D
				var expected := rig.global_transform * rig.get_bone_global_pose(rig.find_bone(attachment.bone_name))
				_check(attachment.global_transform.is_equal_approx(expected), "Equipment follows actual posed hand transform")
				_check(attachment.global_position.distance_to((before[attachment.get_meta("asset_id")] as Transform3D).origin) > .025, "Held equipment moves with a walking hand")
				_check_physical_socket(attachment,identity+" "+str(attachment.get_meta("asset_id"))+" LOD"+str(level))
			prior.clear()
			for attachment: BoneAttachment3D in attachments:
				prior.append(attachment.get_instance_id())
		person._reload(0)
		var once: Array[int] = []
		for attachment: BoneAttachment3D in _attachments(person):
			once.append(attachment.get_instance_id())
		var second := Equipment.attach(person.body, identity, 0)
		_check(second.size() == EXPECTED[identity].size() and _attachments(person).size() == second.size(), "Repeated attachment cannot duplicate a loadout")
		for old: int in once:
			_check(not is_instance_id_valid(old), "Repeated attachment disposes previous hand nodes")
		_check(Equipment.attach(person.body, "unsupported_source", 0).is_empty() and _attachments(person).size() == second.size(), "Unsupported identity cannot replace valid existing equipment")
		if not output.is_empty() and DisplayServer.get_name() != "headless":
			for pose: String in ["idle", "march", "attack", "block"]:
				person.sample_pose(pose, .13 if pose == "march" else .55)
				await _capture(person, identity + "-" + pose)
			person._reload(3)
			person.sample_pose("march", .65)
			await _capture(person, identity + "-distant")
		_check(not person.configure_meshy(""), "Explicit clearing restores the existing frontier character")
		_check(_attachments(person).is_empty() and person.body.find_child("FrontierRomanKit", true, false) != null, "Fallback retains its original weapon kit without duplicate Meshy props")
		person.free()
		await process_frame
	var child := Person.new()
	stage.add_child(child)
	child.configure("player", "italia", 12)
	_check(not child.configure_meshy("unit_germanic_axe_fighter") and _attachments(child).is_empty(), "Cosmetic NPC props cannot arm the child player")
	child.free()
	var adult:=Person.new()
	stage.add_child(adult)
	adult.set_process(false)
	adult.configure("player","italia",18)
	adult.set_service_gear(true)
	_check(adult.sample_service_combat("thrust",.56),"Physical socket fixture uses a real adult service combat pose")
	await process_frame
	for attachment: BoneAttachment3D in adult._service_nodes:
		_check_physical_socket(attachment,str(attachment.name))
	adult.free()
	var report := {"engine":Engine.get_version_info().string, "checks":checks, "failures":failures,
		"scope":"Actual imported production VillagePerson and hand attachments; no inventory or damage changes",
		"android_device_test":false, "captures":captures}
	if not output.is_empty():
		var file := FileAccess.open(output.path_join("review.json"), FileAccess.WRITE)
		file.store_string(JSON.stringify(report, "  ") + "\n")
		file.close()
	stage.free()
	print("MESHY_EQUIPMENT_PASS" if failures.is_empty() else "MESHY_EQUIPMENT_FAIL", " ", checks, " checks, ", failures.size(), " failed")
	quit(0 if failures.is_empty() else 1)


func _setup_studio() -> void:
	var environment := WorldEnvironment.new()
	environment.environment = Environment.new()
	environment.environment.background_mode = Environment.BG_COLOR
	environment.environment.background_color = Color(.07,.08,.10)
	environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_color = Color(.78,.84,.95)
	environment.environment.ambient_light_energy = .5
	stage.add_child(environment)
	var key := DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-32,154,0)
	key.light_color = Color(1,.9,.78)
	key.light_energy = .95
	stage.add_child(key)
	var floor := MeshInstance3D.new()
	floor.mesh = PlaneMesh.new()
	(floor.mesh as PlaneMesh).size = Vector2(8,8)
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(.12,.14,.15)
	floor.material_override = material
	stage.add_child(floor)
	var camera := Camera3D.new()
	stage.add_child(camera)
	camera.position = Vector3(2.15,1.65,-4.3)
	camera.look_at(Vector3(0,1.12,0))
	camera.fov = 34
	camera.current = true


func _capture(person: Person, label: String) -> void:
	for frame in 3:
		await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	_check(image != null and not image.is_empty(), "Actual equipment viewport " + label)
	if image != null and not image.is_empty():
		_check(image.save_png(output.path_join(label + ".png")) == OK, "Save equipment viewport " + label)
	var props: Array[String] = []
	for attachment: BoneAttachment3D in _attachments(person):
		props.append(str(attachment.get_meta("model_path")))
	captures.append({"file":label + ".png", "body":person.active_model_path, "equipment":props, "clip":person.clip, "phase":person.phase})
