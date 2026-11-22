extends Node3D
## Presentation and input only. World-changing decisions are emitted to the model.

signal action_requested(action: String, payload: Dictionary)

const Art = preload("res://scripts/world/village_art.gd")
const Grove = preload("res://scripts/visuals/grove.gd")
const Origins = preload("res://scripts/strategy/origins.gd")
var regional = preload("res://scripts/world/regional_village.gd").new()
var grove = Grove.new()
var scenery = preload("res://scripts/world/village/village_scenery.gd").new()
var tree_sites := []
var crops := Node3D.new()
var season_index := -1
const PLAYER_SPEED := 4.6
const PERSON_ZOOM_MIN := 1.7
const PERSON_ZOOM_MAX := 12.0
const INTERACTION_RADIUS := 3.0
const TRAINING_LOCATION := Vector3(0, 0, -7)
const COMPANION_LOCATION := Vector3(-3, 0, 4)
const PLOT_MIN := Vector2(5, -4)
const PLOT_MAX := Vector2(24, 13)

var _state: Dictionary = {}
var _materials: Dictionary = {}
var _active := false
var _built := false
var _mode := "person"
var _build_mode := false
var _preview_valid := false
var _preview_position := Vector3.ZERO
var _camera_yaw := 0.0
var _camera_pitch := 0.40
var _person_zoom := 7.5
var _city_zoom := 43.0
var _city_focus := Vector3(7, 0, 1)
var _attack_cooldown := 0.0
var _attack_animation := 0.0
var _enemy_attack_cooldown := 1.3
var _animation_time := 0.0
var _resolve_requested := false
var _touch_move := Vector2.ZERO
var _gesture_index := -1
var _camera_contacts: Dictionary[int, Vector2] = {}
var _gesture_start := Vector2.ZERO
var _gesture_moved := false
var _touch_preview_active := false
var _touch_preview_position := Vector2.ZERO
var _map_focus := Vector3(-7, 0, -7)
var _quality_profile := "balanced"
var _sun: DirectionalLight3D
var _village_environment := Environment.new()
var _player: CharacterBody3D
var _figure: Node3D
var _camera: Camera3D
var _camera_initialized := false
var _companion: Node3D
var _companion_label: Label3D
var _training_label: Label3D
var _hint: Label3D
var _preview: Node3D
var _preview_paint: StandardMaterial3D
var _plot: Node3D
var _markers: Node3D
var _buildings_root: Node3D
var _resources_root: Node3D
var _enemies_root: Node3D
var _squad_root: Node3D
var _buildings: Dictionary = {}
var _resource_views: Dictionary = {}
var _enemy_views: Dictionary = {}
var _squad_views: Array[Node3D] = []


func _ready() -> void:
	_build_scene()
	_apply_quality()
	set_process_unhandled_input(true)


func setup(state: Dictionary) -> void:
	_build_scene()
	set_build_mode(false)
	_reset_touch_input()
	_resolve_requested = false
	_attack_cooldown = 0.0
	_enemy_attack_cooldown = 1.3
	var person_data: Dictionary = state.get("player", {})
	var coordinates: Array = person_data.get("position", [0, 1, 8])
	if coordinates.size() == 3:
		_player.position = Vector3(float(coordinates[0]), float(coordinates[1]), float(coordinates[2]))
	else:
		_player.position = Vector3(0, 1, 8)
	_player.velocity = Vector3.ZERO
	_camera_yaw = 0.0
	_camera_pitch = 0.40
	_camera_initialized = false
	if regional.current_origin != state.get("origin_id","italia"):
		var id: String = state.get("origin_id","italia")
		regional.show_origin(id)
		var placements := tree_sites.duplicate(true)
		if id != "italia":
			for tree in placements:
				if tree.kind == "olive":
					tree.kind = "oak"
		grove.populate(placements)
	sync_state(state)
	set_mode("person")


func sync_state(state: Dictionary) -> void:
	_build_scene()
	_state = state
	_apply_season(int(state.get("strategy",{}).get("turn",0))%4)
	_sync_resources()
	_sync_buildings()
	_sync_companion()
	_sync_enemies()
	_sync_squad()
	var player_data: Dictionary = _state.get("player", {})
	var age := int(player_data.get("age", 12))
	_figure.scale = Vector3.ONE * (0.88 if age < 18 else 1.0)
	_figure.get_node("ArmRight/Sword").visible = age >= 18
	_figure.get_node("ArmRight/SwordGuard").visible = age >= 18
	var progress: Dictionary = _state.get("progress", {})
	var trained := bool(progress.get("training_complete", false))
	var hits := int(progress.get("training_hits", 0))
	_training_label.text = "Übungsplatz\nAusbildung bestanden" if trained else "Übungsplatz · E\nTreffer %d / 3" % hits
	var encounter: Dictionary = _state.get("encounter", {})
	if not bool(encounter.get("active", false)):
		_resolve_requested = false
	_update_context_hint()


func set_mode(mode: String) -> void:
	if mode not in ["person", "city", "map"]:
		return
	_mode = mode
	_reset_touch_input()
	if _player != null:
		_player.velocity.x = 0.0
		_player.velocity.z = 0.0
	if mode != "city":
		set_build_mode(false)
	if _plot != null:
		_plot.visible = mode == "city" and _active
	if _markers != null:
		_markers.visible = mode == "map"
	if _preview != null:
		_preview.visible = _build_mode and _active
	if _camera != null:
		_camera.projection = Camera3D.PROJECTION_PERSPECTIVE if mode == "person" else Camera3D.PROJECTION_ORTHOGONAL
		_camera_initialized = false
	_update_context_hint()


func set_active(active: bool) -> void:
	_active = active
	if not active:
		_reset_touch_input()
	if _player != null and not active:
		_player.velocity = Vector3.ZERO
	if _preview != null:
		_preview.visible = active and _build_mode and _mode == "city"
	if _hint != null:
		_hint.visible = active and _mode == "person"
	if _plot != null:
		_plot.visible = active and _mode == "city"
	if not active:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func get_player_position() -> Vector3:
	return _player.global_position if _player != null else Vector3(0, 1, 8)


func set_build_mode(enabled: bool) -> void:
	_build_scene()
	if enabled and _mode != "city":
		set_mode("city")
	var changed := _build_mode != enabled
	_build_mode = enabled
	_touch_preview_active = false
	_preview.visible = enabled and _active
	if enabled:
		_city_focus = Vector3(12, 0, 3)
		_camera_initialized = false
		_update_preview()
	if changed:
		action_requested.emit("build_mode_changed", {"active": enabled})


func is_build_active() -> bool:
	return _build_mode


func set_quality(profile: String) -> void:
	if profile not in ["low", "balanced", "high", "very_high"]:
		return
	_quality_profile = profile
	grove.set_quality(profile)
	scenery.set_quality(profile)
	_apply_quality()


func set_presentation_time(seconds: float) -> void:
	scenery.set_presentation_time(seconds)


func get_quality_profile() -> String:
	return _quality_profile


func _apply_quality() -> void:
	if _sun == null or not is_inside_tree():
		return
	var viewport := get_viewport()
	# These are real Compatibility-renderer settings; simulation is untouched.
	_sun.shadow_enabled = true
	match _quality_profile:
		"low":
			viewport.msaa_3d = Viewport.MSAA_DISABLED
			_sun.directional_shadow_max_distance = 24.0
			_sun.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL
		"balanced":
			viewport.msaa_3d = Viewport.MSAA_2X
			_sun.directional_shadow_max_distance = 48.0
			_sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
		"high":
			viewport.msaa_3d = Viewport.MSAA_4X
			_sun.directional_shadow_max_distance = 85.0
			_sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS
		"very_high":
			viewport.msaa_3d = Viewport.MSAA_4X
			_sun.directional_shadow_max_distance = 110.0
			_sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS


func set_touch_move(axis: Vector2) -> void:
	_touch_move = axis.limit_length(1.0) if _active else Vector2.ZERO


func perform_interaction() -> void:
	if _active:
		_interact()


func perform_attack() -> void:
	if _active:
		_attack()


func _reset_touch_input() -> void:
	_camera_contacts.clear()
	_touch_move = Vector2.ZERO
	_gesture_index = -1
	_gesture_moved = false
	_touch_preview_active = false


func _build_scene() -> void:
	if _built:
		return
	_built = true
	_materials = {
		"earth": Art.material(Color(0.32, 0.33, 0.22)),
		"grass": Art.material(Color(0.38, 0.40, 0.25)),
		"path": Art.material(Color(0.56, 0.47, 0.32)),
		"stone": Art.material(Color(0.66, 0.62, 0.49)),
		"dark_stone": Art.material(Color(0.40, 0.42, 0.37)),
		"plaster": Art.material(Color(0.76, 0.70, 0.55)),
		"timber": Art.material(Color(0.28, 0.18, 0.10)),
		"cut_wood": Art.material(Color(0.63, 0.45, 0.25)),
		"tiles": Art.material(Color(0.45, 0.21, 0.13)),
		"straw": Art.material(Color(0.64, 0.50, 0.28)),
		"foliage": Art.material(Color(0.22, 0.30, 0.15)),
		"red": Art.material(Color(0.48, 0.12, 0.10)),
		"water": Art.material(Color(0.20, 0.37, 0.39), 0.22),
		"field": Art.material(Color(0.29, 0.23, 0.14)),
		"wheat": Art.material(Color(0.65, 0.59, 0.29)),
	}
	_create_atmosphere()
	_create_terrain()
	_create_village()
	_create_build_plot()
	_buildings_root = Node3D.new()
	_buildings_root.name = "PlayerBuildings"
	add_child(_buildings_root)
	_resources_root = Node3D.new()
	_resources_root.name = "WoodStocks"
	add_child(_resources_root)
	_enemies_root = Node3D.new()
	_enemies_root.name = "Encounter"
	add_child(_enemies_root)
	_squad_root = Node3D.new()
	_squad_root.name = "Squad"
	add_child(_squad_root)
	_create_player()
	_create_companion_and_training()
	_create_map_markers()
	_create_preview()
	_camera = Camera3D.new()
	_camera.name = "WorldCamera"
	_camera.fov = 66.0
	_camera.near = 0.12
	_camera.far = 300.0
	add_child(_camera)
	_camera.current = true
	_hint = Art.label(_player, "", Vector3(0, 1.25, 0), Color(1, 0.92, 0.70), 33)
	_hint.visible = false
	_update_camera(0.016)


func _create_atmosphere() -> void:
	var world_environment := WorldEnvironment.new()
	var environment := _village_environment
	environment.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	sky.radiance_size = Sky.RADIANCE_SIZE_64
	sky.sky_material = scenery.sky_material
	environment.sky = sky
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.69, 0.77, 0.85)
	environment.ambient_light_energy = 0.58
	environment.ambient_light_sky_contribution = 0.0
	environment.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	environment.fog_enabled = true
	environment.fog_sky_affect = 0.06
	environment.fog_sun_scatter = 0.04
	environment.fog_density = 0.0015
	environment.fog_light_color = Color(0.63, 0.69, 0.66)
	world_environment.environment = environment
	add_child(world_environment)
	var sun := DirectionalLight3D.new()
	sun.name = "AfternoonSun"
	sun.rotation_degrees = Vector3(-42, -28, 0)
	sun.light_color = Color(1.0, 0.88, 0.69)
	sun.light_energy = 0.46
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 95.0
	add_child(sun)
	_sun = sun


func _create_terrain() -> void:
	var ground := Node3D.new()
	ground.name = "Landscape"
	add_child(ground)
	ground.add_child(scenery)
	scenery.name = "VillageScenery"
	scenery.create_land()
	var bridge := Node3D.new()
	bridge.position = Vector3(-28, 0.03, 4)
	ground.add_child(bridge)
	for index in range(14):
		Art.box(bridge, Vector3(0.68, 0.10, 3.1), Vector3(-4.45 + index * 0.68, 0, 0), _materials["timber"])
	for z: float in [-1.55, 1.55]:
		Art.box(bridge, Vector3(9.6, 0.13, 0.13), Vector3(0, 0.75, z), _materials["timber"], true)
		for x: float in [-4.3, -2.2, 0, 2.2, 4.3]:
			Art.cylinder(bridge, 0.09, 1.0, Vector3(x, 0.43, z), _materials["timber"])
	var random := RandomNumberGenerator.new()
	random.seed = 104729
	ground.add_child(grove)
	for index in range(38):
		var x := random.randf_range(-61, -33) if index < 22 else random.randf_range(-20, 43)
		var z := random.randf_range(-42, 28) if index < 22 else random.randf_range(-46, -27)
		var at := Vector3(x,0,z)
		tree_sites.append({"kind":Grove.KINDS[index%3],"position":at,"scale":random.randf_range(0.8,1.15),"yaw":random.randf_range(-PI,PI)})
		Art.box_collider(ground, Vector3(0.44,2.6,0.44), at+Vector3.UP*1.3)
	for at in [Vector3(-12,0,4),Vector3(6,0,-12),Vector3(-19,0,15),Vector3(26,0,16)]:
		tree_sites.append({"kind":Grove.KINDS[tree_sites.size()%3],"position":at,"scale":0.92,"yaw":random.randf_range(-PI,PI)})
		Art.box_collider(ground, Vector3(0.42,2.6,0.42),at+Vector3.UP*1.3)
	for index in range(26):
		var location := Vector3(random.randf_range(-58, 48), -0.05, random.randf_range(-45, 31))
		if location.x > -20 and location.x < 29 and location.z > -22 and location.z < 19:
			continue
		Art.sphere(ground, random.randf_range(0.35, 0.90), location, _materials["dark_stone"], Vector3(1.3, 0.6, 1.0))
	for x: float in [-64, 58]:
		Art.box_collider(ground, Vector3(1, 15, 105), Vector3(x, 7, -8))
	for z: float in [-58, 40]:
		Art.box_collider(ground, Vector3(125, 15, 1), Vector3(-3, 7, z))


func _create_village() -> void:
	var village := Node3D.new()
	village.name = "FrontierVillage"
	add_child(village)
	village.add_child(regional)
	scenery.add_businesses(village)
	_create_palisade(village)
	village.add_child(crops)
	scenery.sow_field(crops)
	for x: float in [-3, 3]:
		Art.box(village, Vector3(0.22, 4.6, 0.22), Vector3(x, 2.3, 18), _materials["timber"], true)
		Art.box(village, Vector3(1.2, 1.8, 0.04), Vector3(x + 0.56, 3.6, 18), _materials["red"])
	Art.label(village, "VALDORA\nGRENZDORF", Vector3(0, 4.8, 18), Color(0.91, 0.84, 0.66), 52)


func _create_palisade(parent: Node3D) -> void:
	for z: float in [-21.0, 18.0]:
		var poses := []
		for index in range(34):
			var x := -19.0 + index * 1.4
			if absf(x) < 3.0:
				continue
			poses.append(Transform3D(Basis.IDENTITY,Vector3(x,0,z)))
		scenery.palisade_bays(parent,poses)
		Art.box_collider(parent, Vector3(16, 2.5, 0.5), Vector3(-11, 1.25, z))
		Art.box_collider(parent, Vector3(25, 2.5, 0.5), Vector3(15.5, 1.25, z))
	for x: float in [-19.0, 28.0]:
		var poses := []
		for index in range(28):
			var z := -20.0 + index * 1.4
			if x < 0.0 and absf(z - 4.0) < 2.2:
				continue
			poses.append(Transform3D(Basis(Vector3.UP,PI/2),Vector3(x,0,z)))
		scenery.palisade_bays(parent,poses)
		if x > 0.0:
			Art.box_collider(parent, Vector3(0.5, 2.5, 39), Vector3(x, 1.25, -1.5))
		else:
			Art.box_collider(parent, Vector3(0.5, 2.5, 22), Vector3(x, 1.25, -10))
			Art.box_collider(parent, Vector3(0.5, 2.5, 11), Vector3(x, 1.25, 12.5))


func _create_build_plot() -> void:
	_plot = Node3D.new()
	_plot.name = "AvailableBuildingGround"
	add_child(_plot)
	var line_paint := Art.transparent_material(Color(0.70, 0.77, 0.53, 0.40))
	var ground_paint := Art.transparent_material(Color(0.31, 0.53, 0.34, 0.16))
	Art.box(_plot, Vector3(19, 0.02, 17), Vector3(14.5, 0.045, 4.5), ground_paint)
	for x in range(5, 25):
		Art.box(_plot, Vector3(0.025, 0.025, 17), Vector3(x, 0.065, 4.5), line_paint)
	for z in range(-4, 14):
		Art.box(_plot, Vector3(19, 0.025, 0.025), Vector3(14.5, 0.065, z), line_paint)
	Art.label(_plot, "BAUGRUND\nHütte: 8 Holz · Mindestabstand: 5 m", Vector3(14.5, 1.5, 13.7), Color(0.86, 0.94, 0.72), 38)
	_plot.visible = false


func _create_player() -> void:
	_player = CharacterBody3D.new()
	_player.name = "Player"
	_player.position = Vector3(0, 1, 8)
	_player.collision_layer = 2
	_player.collision_mask = 1
	_player.floor_snap_length = 0.25
	var shape := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.28
	capsule.height = 1.8
	shape.shape = capsule
	_player.add_child(shape)
	add_child(_player)
	_figure = Art.person(_player, Color(0.53, 0.25, 0.15))
	var player_ring := Art.cylinder(_player, 0.46, 0.018, Vector3(0, -0.87, 0), Art.transparent_material(Color(0.91, 0.76, 0.41, 0.48)))
	player_ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


func _create_companion_and_training() -> void:
	_companion = Node3D.new()
	_companion.name = "Marcus"
	_companion.position = COMPANION_LOCATION + Vector3.UP * 0.9
	add_child(_companion)
	Art.person(_companion, Color(0.31, 0.39, 0.29))
	_companion_label = Art.label(_companion, "Marcus · E\nGefährten kennenlernen", Vector3(0, 1.15, 0), Color(0.85, 0.92, 0.74), 36)
	var training := Node3D.new()
	training.name = "TrainingGround"
	training.position = TRAINING_LOCATION
	add_child(training)
	Art.box(training, Vector3(6, 0.04, 5), Vector3(0, 0.01, 0), _materials["path"])
	Art.cylinder(training, 0.16, 2.0, Vector3(0, 1.0, 0), _materials["timber"], 0.13, true)
	Art.box(training, Vector3(1.5, 0.18, 0.18), Vector3(0, 1.4, 0), _materials["timber"])
	Art.sphere(training, 0.32, Vector3(0, 1.4, 0), _materials["straw"], Vector3(1.0, 1.6, 0.7))
	_training_label = Art.label(training, "Übungsplatz · E", Vector3(0, 2.8, 0), Color(0.97, 0.84, 0.58), 39)
	var mentor := Node3D.new()
	mentor.position = Vector3(-2.0, 0.9, -1.5)
	training.add_child(mentor)
	Art.person(mentor, Color(0.42, 0.16, 0.13), true)
	Art.label(mentor, "Ausbilder", Vector3(0, 1.05, 0), Color(0.90, 0.83, 0.66), 29)


func _create_map_markers() -> void:
	_markers = Node3D.new()
	_markers.name = "RegionalMapLabels"
	add_child(_markers)
	Art.label(_markers, "VALDORA\nDein tatsächlicher Ort", Vector3(2, 7, 2), Color(1, 0.89, 0.60), 66)
	Art.label(_markers, "WALD UND FURT", Vector3(-38, 6, -6), Color(0.79, 0.89, 0.70), 56)
	Art.label(_markers, "NÖRDLICHER GRENZWEG", Vector3(0, 6, -39), Color(0.89, 0.82, 0.68), 54)
	Art.label(_markers, "FELDER", Vector3(17, 5, -18), Color(0.91, 0.84, 0.55), 48)
	for child: Node in _markers.get_children():
		if child is Label3D:
			child.pixel_size = 0.035
	_markers.visible = false


func _create_preview() -> void:
	_preview = Node3D.new()
	_preview.name = "BuildingPreview"
	add_child(_preview)
	_preview_paint = Art.transparent_material(Color(0.40, 0.84, 0.56, 0.38))
	Art.box(_preview, Vector3(4.1, 0.12, 3.9), Vector3(0, 0.08, 0), _preview_paint)
	Art.box(_preview, Vector3(3.8, 2.1, 3.6), Vector3(0, 1.18, 0), _preview_paint)
	Art.roof(_preview, 4.45, 4.25, 2.37, 1.15, _preview_paint)
	_preview.visible = false


func _sync_resources() -> void:
	var nodes: Array = _state.get("resource_nodes", [])
	var seen: Dictionary = {}
	for value: Variant in nodes:
		if not value is Dictionary:
			continue
		var item: Dictionary = value
		var identity := str(item.get("id", ""))
		seen[identity] = true
		if not _resource_views.has(identity):
			var stock := Node3D.new()
			stock.name = identity
			_resources_root.add_child(stock)
			for index in range(4):
				var log_view := preload("res://assets/village/timber_billet.glb").instantiate() as Node3D
				log_view.position = Vector3(-0.35 + index % 2 * 0.55, 0.22 + index / 2 * 0.32, 0)
				stock.add_child(log_view)
				log_view.name = "Log%d" % index
			var stock_label := Art.label(stock, "", Vector3(0, 1.55, 0), Color(0.94, 0.84, 0.59), 36)
			stock_label.name = "StockLabel"
			_resource_views[identity] = stock
		var visual: Node3D = _resource_views[identity]
		visual.position = Vector3(float(item.get("x", 0)), 0, float(item.get("z", 0)))
		var remaining := int(item.get("amount", 0))
		var label_view: Label3D = visual.get_node("StockLabel")
		label_view.text = "Holzvorrat · E\n%d Holz" % remaining if remaining > 0 else "Holzvorrat erschöpft"
		for index in range(4):
			var log_node: Node3D = visual.get_node("Log%d" % index)
			log_node.visible = remaining > index * 4
	for identity: Variant in _resource_views.keys():
		if not seen.has(identity):
			_resource_views[identity].queue_free()
			_resource_views.erase(identity)


func _sync_buildings() -> void:
	var items: Array = _state.get("buildings", [])
	var seen: Dictionary = {}
	for value: Variant in items:
		if not value is Dictionary:
			continue
		var item: Dictionary = value
		var identity := str(item.get("id", ""))
		seen[identity] = true
		if not _buildings.has(identity):
			_buildings[identity] = _create_building_view(identity)
		var building: Node3D = _buildings[identity]
		building.position = Vector3(float(item.get("x", 0)), 0, float(item.get("z", 0)))
		var progress := clampf(float(item.get("progress", 0.0)), 0.0, 1.0)
		var complete := bool(item.get("completed", false))
		var shell: Node3D = building.get_node("Shell")
		shell.scale.y = maxf(0.06, progress)
		var scaffold: Node3D = building.get_node("Scaffold")
		scaffold.visible = not complete
		var title: Label3D = building.get_node("Title")
		title.text = "Deine Hütte\nFertiggestellt" if complete else "Baustelle · %d %%\nIn der Nähe bleiben" % roundi(progress * 100)
		if complete and not building.has_node("FinishedCollision"):
			_add_finished_hut_collision(building)
		elif not complete and building.has_node("FinishedCollision"):
			var old_collision := building.get_node("FinishedCollision")
			building.remove_child(old_collision)
			old_collision.queue_free()
	for identity: Variant in _buildings.keys():
		if not seen.has(identity):
			_buildings[identity].queue_free()
			_buildings.erase(identity)


func _create_building_view(identity: String) -> Node3D:
	var building := Node3D.new()
	building.name = identity
	_buildings_root.add_child(building)
	var shell := Node3D.new()
	shell.name = "Shell"
	building.add_child(shell)
	var imported := false
	if ResourceLoader.exists("res://assets/frontier_hut.glb"):
		var scene: PackedScene = load("res://assets/frontier_hut.glb") as PackedScene
		if scene != null:
			var asset: Node3D = scene.instantiate() as Node3D
			if asset != null:
				shell.add_child(asset)
				imported = true
	if not imported:
		Art.hut(shell, _materials["plaster"], _materials["timber"], _materials["straw"], false)
	building.set_meta("visual_source", "res://assets/frontier_hut.glb" if imported else "native_primitives")
	var scaffold := Node3D.new()
	scaffold.name = "Scaffold"
	building.add_child(scaffold)
	for x: float in [-2.2, 2.2]:
		for z: float in [-2.0, 2.0]:
			Art.box(scaffold, Vector3(0.10, 2.5, 0.10), Vector3(x, 1.25, z), _materials["timber"])
	Art.box(scaffold, Vector3(4.5, 0.10, 0.10), Vector3(0, 1.8, 2.0), _materials["timber"])
	var title := Art.label(building, "Baustelle", Vector3(0, 4.2, 0), Color(0.98, 0.90, 0.65), 36)
	title.name = "Title"
	return building


func _add_finished_hut_collision(building: Node3D) -> void:
	var collision := Node3D.new()
	collision.name = "FinishedCollision"
	building.add_child(collision)
	Art.box_collider(collision, Vector3(0.22, 2.25, 3.7), Vector3(-1.9, 1.18, 0))
	Art.box_collider(collision, Vector3(0.22, 2.25, 3.7), Vector3(1.9, 1.18, 0))
	Art.box_collider(collision, Vector3(3.7, 2.25, 0.22), Vector3(0, 1.18, -1.8))
	Art.box_collider(collision, Vector3(1.35, 2.25, 0.22), Vector3(-1.25, 1.18, 1.8))
	Art.box_collider(collision, Vector3(1.35, 2.25, 0.22), Vector3(1.25, 1.18, 1.8))


func _sync_companion() -> void:
	var companion: Dictionary = _state.get("companion", {})
	if not bool(companion.get("met", false)):
		_companion_label.text = "%s · E\nGefährten kennenlernen" % Origins.PEOPLES[_state.get("origin_id","italia")].companion
	else:
		_companion_label.text = "%s\nVertrauen: %d" % [Origins.PEOPLES[_state.get("origin_id","italia")].companion,int(companion.get("trust",0))]


func _sync_enemies() -> void:
	var encounter: Dictionary = _state.get("encounter", {})
	var enemies: Array = encounter.get("enemies", [])
	var seen: Dictionary = {}
	for value: Variant in enemies:
		if not value is Dictionary:
			continue
		var enemy: Dictionary = value
		var identity := str(enemy.get("id", ""))
		seen[identity] = true
		if not _enemy_views.has(identity):
			var actor := Node3D.new()
			actor.name = identity
			_enemies_root.add_child(actor)
			Art.person(actor, Color(0.29, 0.25, 0.22))
			var name_label := Art.label(actor, "", Vector3(0, 1.15, 0), Color(1, 0.57, 0.39), 33)
			name_label.name = "HealthLabel"
			var body := StaticBody3D.new()
			body.name = "Body"
			body.collision_layer = 1
			body.collision_mask = 0
			var collision := CollisionShape3D.new()
			var capsule := CapsuleShape3D.new()
			capsule.radius = 0.30
			capsule.height = 1.7
			collision.shape = capsule
			body.add_child(collision)
			actor.add_child(body)
			_enemy_views[identity] = actor
		var visual: Node3D = _enemy_views[identity]
		var health := int(enemy.get("health", 0))
		visual.position = Vector3(float(enemy.get("x", 0)), 0.9, float(enemy.get("z", 0)))
		var figure: Node3D = visual.get_node("Figure")
		figure.rotation.z = 0.0 if health > 0 else PI * 0.5
		figure.position.y = 0.0 if health > 0 else -0.65
		var name_label: Label3D = visual.get_node("HealthLabel")
		name_label.text = "Räuber · %d / 60" % health
		name_label.visible = health > 0
		var body: StaticBody3D = visual.get_node("Body")
		body.collision_layer = 1 if health > 0 else 0
	for identity: Variant in _enemy_views.keys():
		if not seen.has(identity):
			_enemy_views[identity].queue_free()
			_enemy_views.erase(identity)


func _sync_squad() -> void:
	var squad: Dictionary = _state.get("squad", {})
	var alive := clampi(int(squad.get("alive", 0)), 0, 3)
	while _squad_views.size() < alive:
		var soldier := CharacterBody3D.new()
		soldier.name = "Recruit%d" % (_squad_views.size() + 1)
		soldier.collision_layer = 4
		soldier.collision_mask = 1
		soldier.floor_snap_length = 0.25
		var collider := CollisionShape3D.new()
		var capsule := CapsuleShape3D.new()
		capsule.radius = 0.25
		capsule.height = 1.8
		collider.shape = capsule
		soldier.add_child(collider)
		_squad_root.add_child(soldier)
		Art.person(soldier, Color(0.46, 0.14, 0.11), true)
		Art.label(soldier, "Rekrut %d" % (_squad_views.size() + 1), Vector3(0, 1.05, 0), Color(0.78, 0.88, 0.74), 28)
		soldier.position = _player.position + Vector3(2 + _squad_views.size(), 0, 2)
		_squad_views.append(soldier)
	while _squad_views.size() > alive:
		var removed: Node3D = _squad_views.pop_back()
		removed.queue_free()


func _physics_process(delta: float) -> void:
	if not _built or _camera == null:
		return
	_update_camera(delta)
	if not _active:
		return
	_animation_time += delta
	_attack_cooldown = maxf(0.0, _attack_cooldown - delta)
	_attack_animation = maxf(0.0, _attack_animation - delta)
	_enemy_attack_cooldown = maxf(0.0, _enemy_attack_cooldown - delta)
	var player_data: Dictionary = _state.get("player", {})
	if int(player_data.get("health", 100)) <= 0:
		_player.velocity = Vector3.ZERO
		return
	if _mode == "person":
		_move_player(delta)
	elif _mode == "city" and not _build_mode:
		_pan_city_camera(delta)
	_animate_figure()
	_update_followers(delta)
	_update_encounter()
	_update_preview()
	_update_context_hint()


func _move_player(delta: float) -> void:
	var direction := Vector3(_touch_move.x, 0, _touch_move.y)
	var focus: Control = get_viewport().gui_get_focus_owner()
	var editing_text := focus is LineEdit or focus is TextEdit
	if not editing_text:
		direction.x += float(Input.is_physical_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT)) - float(Input.is_physical_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT))
		direction.z += float(Input.is_physical_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN)) - float(Input.is_physical_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP))
	direction = direction.limit_length(1.0).rotated(Vector3.UP, _camera_yaw)
	_player.velocity.x = move_toward(_player.velocity.x, direction.x * PLAYER_SPEED, delta * 22.0)
	_player.velocity.z = move_toward(_player.velocity.z, direction.z * PLAYER_SPEED, delta * 22.0)
	if not _player.is_on_floor():
		_player.velocity.y -= delta * 19.6
	else:
		_player.velocity.y = -0.3
	_player.move_and_slide()
	if direction.length_squared() > 0.01:
		_figure.rotation.y = lerp_angle(_figure.rotation.y, atan2(-direction.x, -direction.z), minf(1.0, delta * 12.0))


func _pan_city_camera(delta: float) -> void:
	var direction := Vector3(_touch_move.x, 0, _touch_move.y)
	direction.x += float(Input.is_physical_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT)) - float(Input.is_physical_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT))
	direction.z += float(Input.is_physical_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN)) - float(Input.is_physical_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP))
	_city_focus += direction.limit_length(1.0) * delta * 14.0
	_city_focus.x = clampf(_city_focus.x, -25, 30)
	_city_focus.z = clampf(_city_focus.z, -25, 20)


func _update_camera(delta: float) -> void:
	var target: Vector3
	var desired: Vector3
	if _mode == "person":
		target = _player.global_position + Vector3(0, 0.40, 0)
		var offset := Vector3(0, sin(_camera_pitch) * _person_zoom + 1.1, cos(_camera_pitch) * _person_zoom)
		desired = target + offset.rotated(Vector3.UP, _camera_yaw)
		if is_inside_tree():
			var query := PhysicsRayQueryParameters3D.create(target, desired, 1)
			query.exclude = [_player.get_rid()]
			var hit: Dictionary = get_world_3d().direct_space_state.intersect_ray(query)
			if not hit.is_empty():
				var hit_position: Vector3 = hit["position"]
				desired = hit_position + (target - hit_position).normalized() * 0.4
	elif _mode == "city":
		target = _city_focus
		desired = target + Vector3(10, 38, 28)
		_camera.size = _city_zoom
	else:
		target = _map_focus
		desired = target + Vector3(0, 104, 18)
		_camera.size = 100.0
	if not _camera_initialized:
		_camera.global_position = desired
		_camera_initialized = true
	else:
		_camera.global_position = _camera.global_position.lerp(desired, 1.0 - exp(-delta * 12.0))
	if _camera.global_position.distance_squared_to(target) > 0.01:
		_camera.look_at(target, Vector3.UP)


func _animate_figure() -> void:
	var speed := Vector2(_player.velocity.x, _player.velocity.z).length()
	var stride := sin(_animation_time * 10.5) * minf(0.48, speed * 0.10)
	var left_leg: Node3D = _figure.get_node("LegLeft")
	var right_leg: Node3D = _figure.get_node("LegRight")
	var left_arm: Node3D = _figure.get_node("ArmLeft")
	var right_arm: Node3D = _figure.get_node("ArmRight")
	left_leg.rotation.x = stride
	right_leg.rotation.x = -stride
	left_arm.rotation.x = -stride * 0.6
	right_arm.rotation.x = stride * 0.6 if _attack_animation <= 0.0 else -1.7 + (0.28 - _attack_animation) * 6.0


func _update_followers(delta: float) -> void:
	var offsets: Array[Vector3] = [Vector3(-1.7, 0, 2.0), Vector3(0, 0, 3.0), Vector3(1.7, 0, 2.0)]
	for index in range(_squad_views.size()):
		var soldier := _squad_views[index] as CharacterBody3D
		var desired := _player.position + offsets[index].rotated(Vector3.UP, _figure.rotation.y)
		desired.y = 0.90
		var displacement := desired - soldier.position
		var horizontal := Vector3(displacement.x, 0, displacement.z)
		var movement := horizontal.normalized() * minf(4.8, horizontal.length() * 2.0)
		soldier.velocity.x = movement.x
		soldier.velocity.z = movement.z
		soldier.velocity.y = -0.3 if soldier.is_on_floor() else soldier.velocity.y - delta * 19.6
		soldier.move_and_slide()
		if horizontal.length_squared() > 0.04:
			var figure: Node3D = soldier.get_node("Figure")
			figure.rotation.y = atan2(-displacement.x, -displacement.z)
			var leg: Node3D = figure.get_node("LegLeft")
			leg.rotation.x = sin(_animation_time * 10 + index) * 0.40
			var other_leg: Node3D = figure.get_node("LegRight")
			other_leg.rotation.x = -leg.rotation.x
		else:
			soldier.get_node("Figure/LegLeft").rotation.x = 0.0
			soldier.get_node("Figure/LegRight").rotation.x = 0.0


func _update_encounter() -> void:
	var encounter: Dictionary = _state.get("encounter", {})
	if not bool(encounter.get("active", false)):
		return
	var enemies: Array = encounter.get("enemies", [])
	var living := 0
	var nearest_distance := INF
	for value: Variant in enemies:
		if not value is Dictionary:
			continue
		var enemy: Dictionary = value
		if int(enemy.get("health", 0)) <= 0:
			continue
		living += 1
		var location := Vector3(float(enemy.get("x", 0)), 0, float(enemy.get("z", 0)))
		var distance := _horizontal_distance(_player.position, location)
		nearest_distance = minf(nearest_distance, distance)
		var identity := str(enemy.get("id", ""))
		if _enemy_views.has(identity):
			var actor: Node3D = _enemy_views[identity]
			var figure: Node3D = actor.get_node("Figure")
			var direction := _player.position - actor.position
			figure.rotation.y = atan2(-direction.x, -direction.z)
			var arm: Node3D = figure.get_node("ArmRight")
			arm.rotation.x = sin(_animation_time * 5.0) * 0.8 - 0.7 if distance <= 2.3 else 0.0
	if living == 0 and not enemies.is_empty() and not _resolve_requested:
		_resolve_requested = true
		action_requested.emit("resolve_skirmish", {})
	elif nearest_distance <= 2.3 and _enemy_attack_cooldown <= 0.0:
		_enemy_attack_cooldown = 1.35
		action_requested.emit("receive_damage", {"amount": 8})


func _unhandled_input(event: InputEvent) -> void:
	if not _active:
		return
	if event is InputEventScreenTouch:
		_handle_touch(event as InputEventScreenTouch)
		return
	if event is InputEventScreenDrag:
		_handle_touch_drag(event as InputEventScreenDrag)
		return
	# Touch already has a dedicated path. Ignore its emulated duplicate mouse event.
	if event is InputEventMouse and event.device == -1:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		var key_event := event as InputEventKey
		var key := key_event.physical_keycode if key_event.physical_keycode != 0 else key_event.keycode
		match key:
			KEY_E:
				_interact()
			KEY_SPACE:
				_attack()
			KEY_B:
				var enable := not _build_mode
				if enable:
					action_requested.emit("mode_city", {})
				set_build_mode(enable)
			KEY_TAB:
				action_requested.emit("mode_person" if _mode != "person" else "mode_city", {})
			KEY_M:
				action_requested.emit("mode_person" if _mode == "map" else "mode_map", {})
			KEY_ESCAPE:
				if _build_mode:
					set_build_mode(false)
				else:
					return
			_:
				return
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton:
		var mouse := event as InputEventMouseButton
		if not mouse.pressed or _ui_blocks_pointer():
			return
		if mouse.button_index == MOUSE_BUTTON_LEFT:
			if _build_mode and _mode == "city":
				_place_building()
			elif _mode == "person":
				_attack()
			get_viewport().set_input_as_handled()
		elif mouse.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
			var direction := -1.0 if mouse.button_index == MOUSE_BUTTON_WHEEL_UP else 1.0
			if _mode == "person":
				_person_zoom = clampf(_person_zoom + direction * 0.7, PERSON_ZOOM_MIN, PERSON_ZOOM_MAX)
			elif _mode == "city":
				_city_zoom = clampf(_city_zoom + direction * 3.0, 24.0, 70.0)
			get_viewport().set_input_as_handled()
	elif event is InputEventMouseMotion and _mode == "person" and not _ui_blocks_pointer():
		var motion := event as InputEventMouseMotion
		if motion.button_mask & MOUSE_BUTTON_MASK_RIGHT:
			_camera_yaw -= motion.relative.x * 0.006
			_camera_pitch = clampf(_camera_pitch + motion.relative.y * 0.004, 0.12, 1.10)
			get_viewport().set_input_as_handled()
	elif event is InputEventMouseMotion and _mode == "city":
		_touch_preview_active = false


func _handle_touch(event: InputEventScreenTouch) -> void:
	# Only free world touches reach this handler. The HUD retains its analog-stick finger.
	if _mode == "person":
		if event.pressed:
			if _camera_contacts.size() >= 2:
				return
			_camera_contacts[event.index] = event.position
			if _camera_contacts.size() == 2:
				get_viewport().set_input_as_handled()
				return
		elif _camera_contacts.has(event.index):
			_camera_contacts.erase(event.index)
			_gesture_index = -1 if _camera_contacts.is_empty() else _camera_contacts.keys()[0]
			if _gesture_index >= 0:
				_gesture_start = _camera_contacts[_gesture_index]
			get_viewport().set_input_as_handled()
			return
	if event.pressed:
		if _gesture_index >= 0:
			return
		_gesture_index = event.index
		_gesture_start = event.position
		_gesture_moved = false
		if _build_mode and _mode == "city":
			_touch_preview_active = true
			_touch_preview_position = event.position
			_update_preview()
	elif event.index == _gesture_index:
		if not event.canceled and not _gesture_moved and _build_mode and _mode == "city":
			_touch_preview_active = true
			_touch_preview_position = event.position
			_place_building()
		_gesture_index = -1
	else:
		return
	get_viewport().set_input_as_handled()


func _handle_touch_drag(event: InputEventScreenDrag) -> void:
	if _mode == "person" and _camera_contacts.has(event.index):
		if _camera_contacts.size() == 2:
			var other: int = _camera_contacts.keys()[0]
			if other == event.index:
				other = _camera_contacts.keys()[1]
			var anchor := _camera_contacts[other]
			var before := anchor.distance_to(_camera_contacts[event.index])
			var after := anchor.distance_to(event.position)
			if minf(before, after) >= 12.0:
				_person_zoom = clampf(_person_zoom * before / after, PERSON_ZOOM_MIN, PERSON_ZOOM_MAX)
			_camera_contacts[event.index] = event.position
			get_viewport().set_input_as_handled()
			return
		_camera_contacts[event.index] = event.position
	if event.index != _gesture_index:
		return
	_gesture_moved = _gesture_moved or event.position.distance_to(_gesture_start) > 14.0
	if _mode == "person":
		_camera_yaw -= event.relative.x * 0.006
		_camera_pitch = clampf(_camera_pitch + event.relative.y * 0.004, 0.12, 1.10)
	elif _mode == "city" and _build_mode:
		_touch_preview_active = true
		_touch_preview_position = event.position
		_update_preview()
	else:
		var plane := Plane(Vector3.UP, 0.0)
		var current: Variant = plane.intersects_ray(_camera.project_ray_origin(event.position), _camera.project_ray_normal(event.position))
		var previous_pixel := event.position - event.relative
		var previous: Variant = plane.intersects_ray(_camera.project_ray_origin(previous_pixel), _camera.project_ray_normal(previous_pixel))
		if current is Vector3 and previous is Vector3:
			var offset: Vector3 = current - previous
			if _mode == "city":
				_city_focus -= offset
				_city_focus.x = clampf(_city_focus.x, -25, 30)
				_city_focus.z = clampf(_city_focus.z, -25, 20)
			else:
				_map_focus -= offset
				_map_focus.x = clampf(_map_focus.x, -30, 20)
				_map_focus.z = clampf(_map_focus.z, -30, 15)
	get_viewport().set_input_as_handled()


func _interact() -> void:
	if _mode != "person":
		return
	var companion: Dictionary = _state.get("companion", {})
	if _horizontal_distance(_player.position, COMPANION_LOCATION) <= INTERACTION_RADIUS and not bool(companion.get("met", false)):
		action_requested.emit("companion_interact", {})
		return
	var closest_id := ""
	var closest_distance := INTERACTION_RADIUS + 0.001
	var nodes: Array = _state.get("resource_nodes", [])
	for value: Variant in nodes:
		if not value is Dictionary:
			continue
		var resource: Dictionary = value
		if int(resource.get("amount", 0)) <= 0:
			continue
		var location := Vector3(float(resource.get("x", 0)), 0, float(resource.get("z", 0)))
		var distance := _horizontal_distance(_player.position, location)
		if distance < closest_distance:
			closest_distance = distance
			closest_id = str(resource.get("id", ""))
	if not closest_id.is_empty():
		action_requested.emit("gather", {"node_id": closest_id})
	elif _horizontal_distance(_player.position, TRAINING_LOCATION) <= INTERACTION_RADIUS:
		action_requested.emit("train", {})
	elif _horizontal_distance(_player.position, COMPANION_LOCATION) <= INTERACTION_RADIUS:
		action_requested.emit("companion_interact", {})


func _attack() -> void:
	if _mode != "person" or _attack_cooldown > 0.0:
		return
	_attack_cooldown = 0.65
	_attack_animation = 0.28
	var encounter: Dictionary = _state.get("encounter", {})
	var enemies: Array = encounter.get("enemies", [])
	var closest_id := ""
	var closest_distance := INTERACTION_RADIUS + 0.001
	if bool(encounter.get("active", false)):
		for value: Variant in enemies:
			if not value is Dictionary:
				continue
			var enemy: Dictionary = value
			if int(enemy.get("health", 0)) <= 0:
				continue
			var target := Vector3(float(enemy.get("x", 0)), 0, float(enemy.get("z", 0)))
			var distance := _horizontal_distance(_player.position, target)
			if distance < closest_distance:
				closest_id = str(enemy.get("id", ""))
				closest_distance = distance
				var direction := target - _player.position
				_figure.rotation.y = atan2(-direction.x, -direction.z)
	if not closest_id.is_empty():
		action_requested.emit("strike_enemy", {"enemy_id": closest_id})
	elif _horizontal_distance(_player.position, TRAINING_LOCATION) <= INTERACTION_RADIUS:
		action_requested.emit("training_hit", {})


func _update_preview() -> void:
	if _preview == null:
		return
	_preview.visible = _active and _build_mode and _mode == "city" and (_touch_preview_active or not _ui_blocks_pointer())
	if not _preview.visible or _camera == null:
		return
	var cursor := _touch_preview_position if _touch_preview_active else get_viewport().get_mouse_position()
	var ray_origin := _camera.project_ray_origin(cursor)
	var ray_direction := _camera.project_ray_normal(cursor)
	var intersection: Variant = Plane(Vector3.UP, 0.04).intersects_ray(ray_origin, ray_direction)
	if intersection == null:
		_preview.visible = false
		_preview_valid = false
		return
	var point: Vector3 = intersection
	_preview_position = Vector3(snappedf(point.x, 0.5), 0.04, snappedf(point.z, 0.5))
	_preview.position = _preview_position
	_preview_valid = _preview_position.x >= PLOT_MIN.x and _preview_position.x <= PLOT_MAX.x and _preview_position.z >= PLOT_MIN.y and _preview_position.z <= PLOT_MAX.y
	var resources: Dictionary = _state.get("resources", {})
	_preview_valid = _preview_valid and int(resources.get("wood", 0)) >= 8
	var buildings: Array = _state.get("buildings", [])
	for value: Variant in buildings:
		if value is Dictionary:
			var existing: Dictionary = value
			var location := Vector3(float(existing.get("x", 0)), 0, float(existing.get("z", 0)))
			if _horizontal_distance(location, _preview_position) < 5.0:
				_preview_valid = false
	_preview_paint.albedo_color = Color(0.40, 0.84, 0.56, 0.38) if _preview_valid else Color(0.89, 0.22, 0.13, 0.44)


func _place_building() -> void:
	_update_preview()
	if not _preview.visible or not _preview_valid:
		return
	action_requested.emit("build", {"x": _preview_position.x, "z": _preview_position.z})


func _update_context_hint() -> void:
	if _hint == null or _player == null:
		return
	_hint.visible = _active and _mode == "person"
	_hint.text = ""
	if not _hint.visible:
		return
	var companion: Dictionary = _state.get("companion", {})
	if _horizontal_distance(_player.position, COMPANION_LOCATION) <= INTERACTION_RADIUS and not bool(companion.get("met", false)):
		_hint.text = "E · Mit %s sprechen" % Origins.PEOPLES[_state.get("origin_id","italia")].companion
		return
	var nodes: Array = _state.get("resource_nodes", [])
	for value: Variant in nodes:
		if value is Dictionary:
			var node: Dictionary = value
			var location := Vector3(float(node.get("x", 0)), 0, float(node.get("z", 0)))
			if int(node.get("amount", 0)) > 0 and _horizontal_distance(_player.position, location) <= INTERACTION_RADIUS:
				_hint.text = "E · 4 Holz sammeln"
				return
	if _horizontal_distance(_player.position, TRAINING_LOCATION) <= INTERACTION_RADIUS:
		var progress: Dictionary = _state.get("progress", {})
		_hint.text = "Ausbildung abgeschlossen" if bool(progress.get("training_complete", false)) else "E · Ausbildung beginnen\nLMB / Leertaste · Übungsschlag"
		return
	var encounter: Dictionary = _state.get("encounter", {})
	if bool(encounter.get("active", false)):
		_hint.text = "LMB / Leertaste · Nahkampf\nAbstand unter 3 m"


func _ui_blocks_pointer() -> bool:
	if not is_inside_tree():
		return false
	var control: Control = get_viewport().gui_get_hovered_control()
	while control != null:
		if control.mouse_filter == Control.MOUSE_FILTER_STOP:
			return true
		control = control.get_parent() as Control
	return false


func _horizontal_distance(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x, a.z).distance_to(Vector2(b.x, b.z))

func _apply_season(index: int) -> void:
	if index == season_index:
		return
	season_index = index
	var soil := [Color("#61704c"),Color("#72734b"),Color("#807250"),Color("#889590")]
	var grain := [Color("#77a95d"),Color("#b4a04e"),Color("#b59a55"),Color("#807968")]
	_materials.earth.albedo_color = soil[index]
	_materials.wheat.albedo_color = grain[index]
	scenery.apply_season(index,_sun,_village_environment)
	crops.visible = index != 3
