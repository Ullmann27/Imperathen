extends Node3D
## Optional walkable market district. Existing campaign startup is unchanged.
## All stock, money, equipment and rewards remain in the shared WorldModel.
const Model = preload("res://scripts/domain/world_model.gd")
const Trade = preload("res://scripts/city_trade.gd")
const Architecture = preload("res://scripts/rendering/city_architecture_detail.gd")
const CharacterDetail = preload("res://scripts/rendering/city_character_detail.gd")
const Person = preload("res://scripts/visuals/village_person.gd")
const MarketPanel = preload("res://scripts/city_support_panel.gd")
const SAVE_PATH := "user://imperathen_city_support.json"
const PROFILE_IDS := ["low", "balanced", "high", "very_high"]
const WALK_SPEED := 1.45
const RUN_SPEED := 3.8
var model
var ui
var player: CharacterBody3D
var figure: Node3D
var camera: Camera3D
var quality_profile := "balanced"
var auto_load := true
var save_path := SAVE_PATH
var active := true
var _touch_axis := Vector2.ZERO
var _camera_yaw := 0.0
var _camera_pitch := 0.32
var _look_pointer := -1
var _nearest := ""
var _shop_anchors: Dictionary = {}
var _architecture_root: Node3D
var _actors: Array[Node3D] = []
var _merchants: Dictionary = {}
var _actor_visual_ids: Dictionary = {}
var _lod_elapsed := 0.0
var _save_elapsed := 0.0
var _sun: DirectionalLight3D
var _load_failed := false
var _suspended := false


func _ready() -> void:
	if model == null:
		model = Model.new()
		model.new_game("italia", true, true)
		if auto_load and FileAccess.file_exists(save_path):
			var loaded: Dictionary = model.load_game(save_path)
			_load_failed = not bool(loaded.get("ok", false))
	var enabled: Dictionary = model.execute("city_trade_enable", {})
	if not enabled.get("ok", false):
		push_error(str(enabled.get("message", "Handel konnte nicht gestartet werden.")))
		active = false
	_build_environment()
	_build_district()
	_build_player()
	_update_camera(1.0, true)
	_build_people()
	_build_ui()
	if _load_failed:
		ui.notify("Der gespeicherte Marktbesuch konnte nicht geladen werden. Die Datei bleibt erhalten.")
	model.changed.connect(_sync_ui)
	_sync_ui()
	_apply_quality(quality_profile)
	_update_camera(1.0, true)
	get_window().go_back_requested.connect(_back)
	print("CITY_SUPPORT_READY")


func _build_environment() -> void:
	var world_environment := WorldEnvironment.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color("b2c4c5")
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("d4e1ed")
	environment.ambient_light_energy = 0.30
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	world_environment.environment = environment
	add_child(world_environment)
	_sun = DirectionalLight3D.new()
	_sun.rotation_degrees = Vector3(-43, -32, 0)
	_sun.light_color = Color("ffe3bc")
	_sun.light_energy = 0.95
	_sun.shadow_enabled = true
	_sun.directional_shadow_max_distance = 55
	add_child(_sun)
	var ground := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(54, 46)
	ground.mesh = plane
	var material := StandardMaterial3D.new()
	material.albedo_color = Color("a6987d")
	material.roughness = 0.92
	ground.material_override = material
	ground.position.y = -0.025
	add_child(ground)
	_box_collision(self, Vector3(0, -0.11, 0), Vector3(54, 0.22, 46))
	# Low walls enclose the review district and use ordinary world collision.
	for specification: Array in [[Vector3(-24, 1.0, 0), Vector3(0.35, 2.0, 38)], [Vector3(24, 1.0, 0), Vector3(0.35, 2.0, 38)], [Vector3(0, 1.0, -18), Vector3(48, 2.0, 0.35)], [Vector3(0, 1.0, 18), Vector3(48, 2.0, 0.35)]]:
		var wall := MeshInstance3D.new()
		var mesh := BoxMesh.new()
		mesh.size = specification[1]
		wall.mesh = mesh
		wall.material_override = material
		wall.position = specification[0]
		add_child(wall)
		_box_collision(self, specification[0], specification[1])


func _box_collision(parent: Node3D, at: Vector3, dimensions: Vector3) -> void:
	var body := StaticBody3D.new()
	body.position = at
	body.collision_layer = 1
	body.collision_mask = 2
	var collider := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = dimensions
	collider.shape = shape
	body.add_child(collider)
	parent.add_child(body)


func _build_district() -> void:
	if is_instance_valid(_architecture_root):
		remove_child(_architecture_root)
		_architecture_root.free()
	_architecture_root = Node3D.new()
	_architecture_root.name = "MarketArchitecture"
	add_child(_architecture_root)
	var lod := 2 if quality_profile == "low" else (1 if quality_profile == "balanced" else 0)
	var paving: Array[Transform3D] = []
	for x in range(-4, 5):
		for z in range(-3, 4):
			var turn := float(posmod(x * 3 + z, 4)) * PI * 0.5
			paving.append(Transform3D(Basis(Vector3.UP, turn), Vector3(x * 4.0, 0, z * 4.0)))
	var street: Node3D = Architecture.create_multimesh("basoli_4m", paving, lod)
	_architecture_root.add_child(street)
	_shop_anchors.clear()
	for shop: Dictionary in Trade.shop_catalog():
		var point: Array = shop.position
		var anchor := Vector3(float(point[0]), 0.0, float(point[1]))
		_shop_anchors[shop.id] = anchor
		_add_module("taberna_4m", anchor + Vector3(0, 0, -2.45), lod, true)
		if shop.id == "thermopolium":
			_add_module("dolia_counter", anchor + Vector3(2.2, 0, 0.0), lod, true)
		else:
			_add_module("market_canopy", anchor + Vector3(0, 0, -0.35), lod, true)
			if shop.id in ["bakery", "foodstall"]:
				_add_stall_table(anchor + Vector3(0.95, 0, -0.25), lod)
		if shop.id in ["pottery", "thermopolium"]:
			_add_module("amphora_pair", anchor + Vector3(1.55, 0, 0.1), lod, true)
		var label := Label3D.new()
		label.text = shop.name
		label.font_size = 34
		label.pixel_size = 0.006
		label.outline_size = 5
		label.modulate = Color("faefd3")
		label.position = anchor + Vector3(0, 2.8, 0)
		label.no_depth_test = false
		_architecture_root.add_child(label)
	var edges: Array[Transform3D] = []
	for z in range(-3, 4):
		edges.append(Transform3D(Basis(Vector3.UP, PI * 0.5), Vector3(-18.25, 0, z * 4.0)))
		edges.append(Transform3D(Basis(Vector3.UP, -PI * 0.5), Vector3(18.25, 0, z * 4.0)))
	_architecture_root.add_child(Architecture.create_multimesh("curb_4m", edges, lod))
	for side in [-1.0, 1.0]:
		_box_collision(_architecture_root, Vector3(side * 18.25, 0.08, 0), Vector3(0.55, 0.16, 28))
		_box_collision(_architecture_root, Vector3(side * 18.82, 0.10, 0), Vector3(0.55, 0.20, 28))


func _add_stall_table(at: Vector3, lod: int) -> void:
	# Keep a physical, visible support under the board and the central doorway free.
	var table := Node3D.new()
	table.name = "BreadTable"
	table.position = at
	_architecture_root.add_child(table)
	var display: Node3D = Architecture.create_module("bread_display", lod, false)
	display.position.y = 0.85
	table.add_child(display)
	var wood: Material
	var visual := display.get_node("Visual") as MeshInstance3D
	for surface in visual.mesh.get_surface_count():
		var candidate: Material = visual.mesh.surface_get_material(surface)
		if candidate != null and candidate.resource_name == "CITY_wood":
			wood = candidate
			break
	if wood == null:
		var fallback := StandardMaterial3D.new()
		fallback.albedo_color = Color("65462b")
		fallback.roughness = 0.85
		wood = fallback
	_add_table_part(table, Vector3(0, 0.815, 0), Vector3(1.12, 0.07, 0.72), wood)
	for x in [-0.44, 0.44]:
		for z in [-0.25, 0.25]:
			_add_table_part(table, Vector3(x, 0.39, z), Vector3(0.08, 0.78, 0.08), wood)
		_add_table_part(table, Vector3(x, 0.24, 0), Vector3(0.07, 0.08, 0.57), wood)
	_add_table_part(table, Vector3(0, 0.25, 0), Vector3(0.88, 0.07, 0.07), wood)
	_box_collision(table, Vector3(0, 0.425, 0), Vector3(1.12, 0.85, 0.72))


func _add_table_part(parent: Node3D, at: Vector3, size: Vector3, material: Material) -> void:
	var block := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	block.mesh = mesh
	block.material_override = material
	block.position = at
	parent.add_child(block)


func _add_module(id: String, at: Vector3, lod: int, collisions: bool) -> void:
	var module: Node3D = Architecture.create_module(id, lod, collisions)
	module.position = at
	_architecture_root.add_child(module)


func _build_player() -> void:
	player = CharacterBody3D.new()
	player.name = "Player"
	player.collision_layer = 2
	player.collision_mask = 1 | 8
	player.floor_snap_length = 0.35
	var saved: Array = model.data.player.position
	player.position = Vector3(clampf(float(saved[0]), -20, 20), 0.03, clampf(float(saved[2]), -14, 14))
	var collision := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.23
	capsule.height = 1.50
	collision.position.y = 0.75
	collision.shape = capsule
	player.add_child(collision)
	add_child(player)
	figure = Person.new()
	figure.profile = quality_profile
	player.add_child(figure)
	figure.configure("player", "italia", int(model.data.player.age))
	_fit_person(figure, 1.50 if int(model.data.player.age) < 18 else 1.78)
	camera = Camera3D.new()
	camera.fov = 55
	camera.near = 0.08
	camera.far = 100
	camera.current = true
	add_child(camera)
	_actors.append(figure)


func _fit_person(person: Node3D, target_height: float) -> void:
	# Measure the actual displayed authored mesh; scale the whole visual together.
	var combined := AABB()
	var found := false
	for mesh: MeshInstance3D in person.find_children("*", "MeshInstance3D", true, false):
		if not mesh.mesh:
			continue
		var local_box: AABB = (person.global_transform.affine_inverse() * mesh.global_transform) * mesh.get_aabb()
		combined = combined.merge(local_box) if found else local_box
		found = true
	if found and combined.size.y > 0.1:
		var factor := target_height / combined.size.y
		person.scale = Vector3.ONE * factor
		person.position.y = -combined.position.y * factor


func _build_people() -> void:
	var appearances := ["civilian_man", "civilian_woman", "elder", "civilian_woman", "civilian_man", "civilian_man"]
	var index := 0
	for shop: Dictionary in Trade.shop_catalog():
		var anchor: Vector3 = _shop_anchors[shop.id]
		var body := StaticBody3D.new()
		body.collision_layer = 8
		body.collision_mask = 2
		body.position = anchor + Vector3(0, 0, -1.55)
		add_child(body)
		var collision := CollisionShape3D.new()
		var capsule := CapsuleShape3D.new()
		capsule.radius = 0.27
		capsule.height = 1.7
		collision.position.y = 0.85
		collision.shape = capsule
		body.add_child(collision)
		var person = Person.new()
		person.profile = quality_profile
		body.add_child(person)
		person.configure_resident("italia", 24 + index * 5, appearances[index], index * 2, camera)
		_fit_person(person, 1.64 + 0.025 * float(index % 4))
		person.rotation.y = PI
		_actors.append(person)
		_merchants[shop.id] = person
		index += 1


func _build_ui() -> void:
	ui = MarketPanel.new()
	add_child(ui)
	ui.pad.axis_changed.connect(func(axis: Vector2): _touch_axis = axis)
	ui.command_requested.connect(_execute)
	ui.interact_requested.connect(interact)
	ui.inventory_requested.connect(func(): ui.open_inventory())
	ui.save_requested.connect(save_visit)
	ui.load_requested.connect(load_visit)
	ui.quality_requested.connect(_apply_quality)
	ui.closed.connect(_close_shop_attention)


func _sync_ui() -> void:
	if is_instance_valid(ui):
		ui.update_state(model.data)


func _execute(command: String, arguments: Dictionary) -> void:
	model.set_player_position(player.position)
	var result: Dictionary = model.execute(command, arguments)
	_sync_ui()
	ui.notify(str(result.get("message", "")))
	if result.get("ok", false) and not _load_failed:
		var saved: Dictionary = model.save_game(save_path)
		if not saved.get("ok", false):
			ui.notify(str(saved.get("message", "Speichern fehlgeschlagen.")))


func interact() -> void:
	if _nearest.is_empty():
		return
	var anchor: Vector3 = _shop_anchors[_nearest]
	if Vector2(player.position.x, player.position.z).distance_to(Vector2(anchor.x, anchor.z)) <= 3.0:
		model.set_player_position(player.position)
		ui.open_shop(_nearest)
		var merchant = _merchants.get(_nearest)
		if is_instance_valid(merchant):
			merchant.set_conversation_focus(true)


func _close_shop_attention() -> void:
	_touch_axis = Vector2.ZERO
	for merchant in _merchants.values():
		merchant.set_conversation_focus(false)


func save_visit() -> void:
	if _load_failed:
		ui.notify("Die vorhandene Datei wird nach dem Ladefehler nicht überschrieben.")
		return
	model.set_player_position(player.position)
	var result: Dictionary = model.save_game(save_path)
	ui.notify(str(result.get("message", "")))


func load_visit() -> void:
	var result: Dictionary = model.load_game(save_path)
	if not result.get("ok", false):
		ui.notify(str(result.get("message", "")))
		return
	_load_failed = false
	var enabled: Dictionary = model.execute("city_trade_enable", {})
	if not enabled.get("ok", false):
		ui.notify(str(enabled.get("message", "")))
		return
	var coordinates: Array = model.data.player.position
	player.position = Vector3(clampf(float(coordinates[0]), -20, 20), 0.03, clampf(float(coordinates[2]), -14, 14))
	player.velocity = Vector3.ZERO
	_touch_axis = Vector2.ZERO
	ui.close()
	_sync_ui()
	_update_camera(1.0, true)
	ui.notify("Marktbesuch geladen.")


func _apply_quality(profile: String) -> void:
	if profile not in PROFILE_IDS:
		return
	var rebuild := profile != quality_profile or not is_instance_valid(_architecture_root)
	quality_profile = profile
	_sun.shadow_enabled = profile != "low"
	get_viewport().msaa_3d = Viewport.MSAA_DISABLED if profile == "low" else Viewport.MSAA_2X
	get_viewport().scaling_3d_scale = 0.85 if profile == "low" else 1.0
	if rebuild:
		_build_district()
	_actor_visual_ids.clear()
	for actor in _actors:
		actor.profile = profile
		actor.refresh_lod(camera)
	_update_character_details()
	if is_instance_valid(ui):
		ui.quality.select(PROFILE_IDS.find(profile))


func _update_character_details() -> void:
	for actor in _actors:
		if not is_instance_valid(actor.body):
			continue
		var key := "%d:%s:%d" % [actor.body.get_instance_id(), quality_profile, int(actor.detail)]
		var actor_id := actor.get_instance_id()
		if _actor_visual_ids.get(actor_id, "") != key:
			CharacterDetail.apply_to(actor.body, quality_profile, int(actor.detail))
			_actor_visual_ids[actor_id] = key


func _physics_process(delta: float) -> void:
	if not is_instance_valid(player) or not active or _suspended:
		return
	var axis := _touch_axis
	if not ui.is_open():
		axis += Vector2(float(Input.is_physical_key_pressed(KEY_D)) - float(Input.is_physical_key_pressed(KEY_A)), float(Input.is_physical_key_pressed(KEY_S)) - float(Input.is_physical_key_pressed(KEY_W)))
	else:
		axis = Vector2.ZERO
	var direction := Vector3(axis.x, 0, axis.y).rotated(Vector3.UP, _camera_yaw).limit_length(1.0)
	var target_speed := RUN_SPEED if Input.is_physical_key_pressed(KEY_SHIFT) and not ui.is_open() else WALK_SPEED
	var desired := direction * target_speed
	player.velocity.x = move_toward(player.velocity.x, desired.x, 5.0 * delta)
	player.velocity.z = move_toward(player.velocity.z, desired.z, 5.0 * delta)
	player.velocity.y = -0.3 if player.is_on_floor() else player.velocity.y - 19.6 * delta
	player.move_and_slide()
	var speed := Vector2(player.velocity.x, player.velocity.z).length()
	if speed > 0.06:
		figure.rotation.y = rotate_toward(figure.rotation.y, atan2(-direction.x, -direction.z), delta * 4.2)
	figure.drive(speed)
	model.set_player_position(player.position)
	_update_camera(delta)
	var distance := INF
	_nearest = ""
	var nearest_name := ""
	for shop: Dictionary in Trade.shop_catalog():
		var point: Vector3 = _shop_anchors[shop.id]
		var current := Vector2(player.position.x, player.position.z).distance_to(Vector2(point.x, point.z))
		if current < distance:
			distance = current
			_nearest = shop.id
			nearest_name = shop.name
	ui.set_nearest(nearest_name, distance)
	_lod_elapsed += delta
	if _lod_elapsed >= 0.35:
		_lod_elapsed = 0
		_update_character_details()
	_save_elapsed += delta
	if _save_elapsed >= 30.0 and not _load_failed:
		_save_elapsed = 0
		var result: Dictionary = model.save_game(save_path)
		if not result.get("ok", false):
			ui.notify(str(result.get("message", "")))


func _update_camera(delta: float, immediate := false) -> void:
	if not is_instance_valid(camera):
		return
	var target := player.position + Vector3(0, 1.12, 0)
	var offset := Vector3(sin(_camera_yaw) * 5.2, 2.0 + _camera_pitch * 2.4, cos(_camera_yaw) * 5.2)
	var destination := target + offset
	var query := PhysicsRayQueryParameters3D.create(target, destination, 1, [player.get_rid()])
	var hit: Dictionary = get_world_3d().direct_space_state.intersect_ray(query)
	if not hit.is_empty():
		destination = hit.position + hit.normal * 0.20
	camera.position = destination if immediate else camera.position.lerp(destination, 1.0 - exp(-12.0 * delta))
	camera.look_at(target)


func _unhandled_input(event: InputEvent) -> void:
	if not is_instance_valid(ui):
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.physical_keycode == KEY_E and not ui.is_open():
			interact()
		elif event.physical_keycode == KEY_I:
			ui.open_inventory()
		elif event.physical_keycode == KEY_ESCAPE:
			_back()
	if ui.is_open():
		_look_pointer = -1
		return
	if event is InputEventMouseMotion and Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT) and event.device != InputEvent.DEVICE_ID_EMULATION:
		_camera_yaw -= event.relative.x * 0.005
		_camera_pitch = clampf(_camera_pitch + event.relative.y * 0.003, -0.3, 0.9)
	elif event is InputEventScreenTouch:
		if event.pressed and not event.canceled and event.position.x > get_viewport().get_visible_rect().size.x * 0.5 and _look_pointer == -1:
			_look_pointer = event.index
		elif event.index == _look_pointer and (not event.pressed or event.canceled):
			_look_pointer = -1
	elif event is InputEventScreenDrag and event.index == _look_pointer:
		_camera_yaw -= event.relative.x * 0.005
		_camera_pitch = clampf(_camera_pitch + event.relative.y * 0.003, -0.3, 0.9)


func _back() -> void:
	if is_instance_valid(ui) and ui.is_open():
		ui.close()
	else:
		save_visit()
	_touch_axis = Vector2.ZERO
	_look_pointer = -1


func _notification(what: int) -> void:
	if what in [NOTIFICATION_APPLICATION_FOCUS_IN, NOTIFICATION_APPLICATION_RESUMED]:
		_suspended = false
	if what in [NOTIFICATION_APPLICATION_FOCUS_OUT, NOTIFICATION_APPLICATION_PAUSED]:
		_suspended = true
		_touch_axis = Vector2.ZERO
		_look_pointer = -1
		if is_instance_valid(player):
			player.velocity = Vector3.ZERO
			if is_instance_valid(ui):
				ui.pad.reset()
			if not _load_failed and model != null:
				model.set_player_position(player.position)
				model.save_game(save_path)

