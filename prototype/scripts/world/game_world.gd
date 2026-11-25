extends Node3D
## Presentation and input only. World-changing decisions are emitted to the model.

signal action_requested(action: String, payload: Dictionary)

const Art = preload("res://scripts/world/village_art.gd")
const Grove = preload("res://scripts/visuals/grove.gd")
const Origins = preload("res://scripts/strategy/origins.gd")
const VillageLifeWorld = preload("res://scripts/world/village_life_world.gd")
const VillageLife = preload("res://scripts/story/village_life.gd")
const Childhood = preload("res://scripts/story/village_childhood.gd")
const CompanionWorld = preload("res://scripts/world/companion_world.gd")
const RegionalTerrain = preload("res://scripts/world/regional_terrain.gd")
const CombatActions = preload("res://scripts/domain/combat_actions.gd")
const PlayerActionWorld = preload("res://scripts/world/player_action_world.gd")
const CameraObstruction = preload("res://scripts/world/camera_obstruction.gd")
var village_life_world: Node3D
var regional_terrain: Node3D
var _village_focus := ""
var _dodge_remaining := 0.0
var _dodge_direction := Vector3.ZERO
const VillageLayout = preload("res://scripts/world/village/village_layout.gd")
var population = preload("res://scripts/world/village/village_population.gd").new()
var regional = preload("res://scripts/world/regional_village.gd").new()
var grove = Grove.new()
var scenery = preload("res://scripts/world/village/village_scenery.gd").new()
var opening_props = preload("res://scripts/world/village/opening_props.gd").new()
var tree_sites := []
var crops := Node3D.new()
var season_index := -1
const PLAYER_SPEED := 4.6
const WALK_SPEED := 1.45
const CHILD_RUN_SPEED := 3.8
const START_YAW := 0.62
const START_PITCH := 0.18
const PERSON_ZOOM_MIN := 1.25
const PERSON_ZOOM_MAX := 12.0
const INTERACTION_RADIUS := 3.0
const TRAINING_LOCATION := Vector3(0, 0, -7)
const COMPANION_LOCATION := Vector3(-3, 0, 4)
const PLOT_MIN := Vector2(5, -4)
const PLOT_MAX := Vector2(24, 13)

var _state: Dictionary = {}
var _materials: Dictionary = {}
var _active := false
var _running := false
var _built := false
var _mode := "person"
var _build_mode := false
var _preview_valid := false
var _preview_position := Vector3.ZERO
var _camera_yaw := START_YAW
var _camera_pitch := START_PITCH
var _person_zoom := 3.05
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
const VillagePerson := preload("res://scripts/visuals/village_person.gd")
var _shown_health := -1
var _shown_work := -1.0
var _figure: VillagePerson
var _camera: Camera3D
var _camera_initialized := false
# Preserve this camera's layer selection while no collision-free view exists.
var _camera_obstructed_mask := -1
var _camera_obstruction = CameraObstruction.new()
var _menu_flight := false
var _flight_time := 0.0
var _companion: CharacterBody3D
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
var _frontier_focus := ""
var _frontier_camera_direction := Vector3.BACK
var _turn_rate := 0.0
var _touch_camera_managed := false
var _actions = PlayerActionWorld.new(self)
var _story_companions = CompanionWorld.new(self)


func _ready() -> void:
	_build_scene()
	_apply_quality()
	set_process_unhandled_input(true)


func setup(state: Dictionary) -> void:
	clear_frontier_focus()
	_shown_health = -1
	_shown_work = -1.0
	_build_scene()
	for actor in get_tree().get_nodes_in_group("village_people"):
		if is_ancestor_of(actor): actor.reset_motion()
	set_build_mode(false)
	_reset_touch_input()
	_resolve_requested = false
	_running=false
	_attack_cooldown = 0.0
	_enemy_attack_cooldown = 1.3
	var person_data: Dictionary = state.get("player", {})
	var coordinates: Array = person_data.get("position", [0, 1, 8])
	if coordinates.size() == 3:
		_player.position = Vector3(float(coordinates[0]), float(coordinates[1]), float(coordinates[2]))
	else:
		_player.position = Vector3(0, 1, 8)
	_player.velocity = Vector3.ZERO
	_running = false
	_actions.reset()
	_camera_yaw = START_YAW
	_camera_pitch = START_PITCH
	_figure.rotation.y = START_YAW
	_camera_initialized = false
	_camera_obstruction.reset()
	if regional.current_origin != state.get("origin_id","italia"):
		var id: String = state.get("origin_id","italia")
		regional.show_origin(id)
		scenery.set_origin(id)
		var placements := tree_sites.duplicate(true)
		if id != "italia":
			for tree in placements:
				if tree.kind == "olive":
					tree.kind = "oak"
		grove.populate(placements)
	sync_state(state)
	_story_companions.reset(state)
	set_mode("person")


func sync_state(state: Dictionary) -> void:
	_build_scene()
	_state = state
	# Keep nearby interaction text compact; large 3D labels can cover the map.
	_hint.font_size = 28
	_hint.pixel_size = 0.0019
	_hint.outline_size = 3
	var inner := get_node_or_null("FrontierVillage/InnerLegacyPalisade")
	if inner != null:
		inner.visible=not bool(state.get("village",{}).get("enabled",false))
		for body in inner.find_children("*","StaticBody3D",true,false):
			body.collision_layer=1 if inner.visible else 0
	opening_props.sync_state(state)
	village_life_world.sync_state(state, _quality_profile)
	var mentor := get_node_or_null("TrainingGround/Mentor")
	if mentor != null:
		mentor.visible = not bool(state.get("village", {}).get("enabled", false))
	var legacy_boundary := get_node_or_null("Landscape/LegacyBoundary")
	if legacy_boundary != null:
		for body: StaticBody3D in legacy_boundary.get_children():
			body.collision_layer = 0 if state.get("village", {}).get("enabled", false) else 1
	var legacy_recruits := 0 if state.get("village", {}).get("enabled", false) else int(state.get("squad", {}).get("recruits", 0))
	population.sync_behavior(state)
	population.show_origin(str(state.get("origin_id","italia")),float(state.get("world_seconds",0)),legacy_recruits)
	if regional.frontier_details:
		regional.frontier_details.set_wagon_progress(float(state.get("frontier",{}).get("work_seconds",0))/12.0)
	_apply_season(int(state.get("strategy",{}).get("turn",0))%4)
	_sync_resources()
	_sync_buildings()
	_sync_companion()
	_sync_enemies()
	_sync_squad()
	var player_data: Dictionary = _state.get("player", {})
	var age := int(player_data.get("age", 12))
	_figure.configure("player",_state.get("origin_id","italia"),age)
	_figure.set_loaned_gear(Childhood.enabled(state) and state.village.childhood.gear=="loaned")
	_figure.set_service_gear(CombatActions.service_gear(state))
	_update_people_profile()
	var health_now := int(player_data.get("health",100))
	var construction := 0.0
	for hut: Dictionary in _state.get("buildings",[]):
		construction += 1.0 + float(hut.get("progress",0.0))
	if health_now == 0 or (_shown_health >= 0 and health_now < _shown_health):
		_figure.cue("death" if health_now == 0 else "hit")
	elif _shown_work >= 0 and construction > _shown_work and _can_show_player_work():
		_figure.keep_working()
	_shown_health = health_now
	_shown_work = construction
	_companion.get_node("Figure").configure("companion",_state.get("origin_id","italia"),age)
	var progress: Dictionary = _state.get("progress", {})
	var trained := bool(progress.get("training_complete", false))
	var hits := int(progress.get("training_hits", 0))
	_training_label.text = "Übungsplatz\nAusbildung bestanden" if trained else "Übungsplatz · E\nTreffer %d / 3" % hits
	if CombatActions.enabled(state):
		_training_label.text="Übungspfahl · Fausttechniken\n%d kontrollierte Treffer"%int(state.village.unarmed.practice_hits)
	var encounter: Dictionary = _state.get("encounter", {})
	if not bool(encounter.get("active", false)):
		_resolve_requested = false
	_update_context_hint()
	_actions.sync(state)
	_actions.sync_personal_space()


func set_mode(mode: String) -> void:
	if mode not in ["person", "city", "map"]:
		return
	_mode = mode
	if mode != "person":
		action_requested.emit("combat_interrupt", {})
		_actions.reset()
		_dodge_remaining = 0.0
		clear_frontier_focus()
	_reset_touch_input()
	if _player != null:
		_player.velocity.x = 0.0
		_player.velocity.z = 0.0
	if mode != "city":
		set_build_mode(false)
		set_menu_flight(false)
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


## Slow camera drift over the frontier behind the main menu (off for reduced motion).
func set_menu_flight(enabled: bool) -> void:
	_menu_flight = enabled and _mode == "city"
	if not _menu_flight:
		_flight_time = 0.0


func is_menu_flight() -> bool:
	return _menu_flight


func set_active(active: bool) -> void:
	regional.set_active(active)
	_active = active
	if active:
		set_menu_flight(false)
	population.set_active(active)
	if village_life_world != null:
		village_life_world.set_active(active)
	if active:
		clear_frontier_focus()
	if not active:
		_story_companions.pause()
		action_requested.emit("combat_interrupt", {})
		_actions.reset()
		_dodge_remaining = 0.0
		_reset_touch_input()
	if _player != null and not active:
		_player.velocity = Vector3.ZERO
		_figure.drive(0.0)
		for recruit in _squad_views:
			recruit.get_node("Figure").drive(0.0)
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


func prepare_cinematic_camera() -> void:
	# Settle the ordinary camera first so the closing shot has an exact target.
	set_menu_flight(false)
	_camera_initialized = false
	_update_camera(0.0)
	_camera.make_current()


func get_cinematic_anchor(key: String) -> Vector3:
	match key:
		"road": return to_global(Vector3(0, 0, 18))
		"market": return scenery.to_global(scenery.MARKET)
		"companion": return _companion.global_position
		"plot":
			var buildings: Array = _state.get("buildings", [])
			if not buildings.is_empty():
				return to_global(Vector3(float(buildings[0].x), 0, float(buildings[0].z)))
			return to_global(Vector3(14.5, 0, 4.5))
		"training": return to_global(TRAINING_LOCATION)
		_: return get_player_position()


func set_frontier_time(seconds: float) -> void:
	population.advance_to(seconds)


func get_frontier_npc_position(id: String) -> Vector3:
	return population.actor_position(id)


func get_frontier_npc_info(id: String) -> Dictionary:
	return population.info(id)


func focus_frontier_npc(id: String) -> bool:
	if _mode != "person" or not _player or not _camera or population.info(id).is_empty():
		return false
	var at: Vector3 = population.actor_position(id)
	if _horizontal_distance(_player.global_position,at) > INTERACTION_RADIUS+.3:
		return false
	var direction := _player.global_position-at
	direction.y = 0
	_frontier_camera_direction = direction.normalized() if direction.length() > .2 else Vector3.BACK
	_frontier_focus = id
	population.focus(id,at+_frontier_camera_direction*3)
	_camera.fov = 44.0
	return true


func clear_frontier_focus() -> void:
	if is_instance_valid(_companion):
		_companion.get_node("Figure").set_conversation_focus(false)
	_frontier_focus = ""
	_village_focus = ""
	if village_life_world != null:
		village_life_world.clear_focus()
	population.clear_focus()
	if _camera:
		_camera.fov = 54.0


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
	_update_people_profile()
	grove.set_quality(profile)
	scenery.set_quality(profile)
	regional.set_quality(profile)
	population.set_quality(profile)
	_apply_quality()


func _update_people_profile() -> void:
	for actor in get_tree().get_nodes_in_group("village_people"):
		if is_ancestor_of(actor) and actor.profile != _quality_profile:
			actor.profile = _quality_profile
			actor.refresh_lod(_camera)


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


func is_running() -> bool:
	return _running


func combat_line_clear(from: Vector2, to: Vector2) -> bool:
	return combat_sight_clear(from, to)


func perform_unarmed(technique: String) -> void:
	perform_attack(technique)


func cue_unarmed(technique: String) -> void:
	_figure.cue_unarmed(technique)


func navigation_view() -> Dictionary:
	var result:={"player":Vector2(snappedf(_player.position.x,.1),snappedf(_player.position.z,.1)),"heading":snappedf(_figure.rotation.y,.02),"has_target":false}
	if not Childhood.enabled(_state):
		return result
	var chapter:=Childhood.view(_state)
	var target: Variant=chapter.get("point",null)
	var npc:=str(chapter.get("target_npc",""))
	if not npc.is_empty() and VillageLife.has_npc(_state,npc):
		target=VillageLife.actor_position(_state,npc)
	if typeof(target)==TYPE_VECTOR2:
		result["target"]=target
		result.has_target=true
	return result


func perform_interaction() -> void:
	if _active:
		_interact()


func perform_attack(technique := "") -> void:
	if _active:
		if not technique.is_empty():
			if CombatActions.enabled(_actions.state) and not CombatActions.available(_actions.state,technique):
				return
			set_selected_technique(technique)
		_attack()


func set_running(value: bool) -> void:
	_running = value


func set_selected_technique(technique: String) -> void:
	if CombatActions.available(_actions.state,technique):
		_actions.selected = technique


func set_touch_camera_managed(value: bool) -> void:
	_touch_camera_managed = value
	_reset_touch_input()


func apply_camera_look(relative: Vector2) -> void:
	if _active and _mode == "person" and relative.is_finite():
		_camera_yaw = wrapf(_camera_yaw - relative.x * 0.006, -PI, PI)
		_camera_pitch = clampf(_camera_pitch + relative.y * 0.004, 0.12, 1.10)


func apply_camera_zoom(factor: float) -> void:
	if _active and _mode == "person" and is_finite(factor) and factor > 0.0:
		_person_zoom = clampf(_person_zoom * clampf(factor, 0.5, 2.0), PERSON_ZOOM_MIN, PERSON_ZOOM_MAX)


func sync_combat_state(state: Dictionary) -> void:
	_actions.sync(state)
	if village_life_world != null:
		village_life_world.sync_raid_state(state)


func set_raid_physics_authority(enabled: bool) -> void:
	if village_life_world != null:
		village_life_world.physical_raiders = enabled
		village_life_world.raider_sight_check = combat_sight_clear


func raid_observations() -> Dictionary:
	return village_life_world.raid_observations() if village_life_world != null else {}


func combat_sight_clear(from: Vector2, to: Vector2) -> bool:
	return _actions.sight_clear(from, to)


func npc_sight_clear(from: Vector3, to: Vector3) -> bool:
	# NPC observations use floor origins. A ray between their own eye-level
	# offsets tests static world geometry, independent of the player's altitude.
	if not is_inside_tree() or not from.is_finite() or not to.is_finite():
		return false
	var eye_offset := Vector3(0.0, 1.45, 0.0)
	var query := PhysicsRayQueryParameters3D.create(from + eye_offset, to + eye_offset, 1)
	# Some existing raider bodies share the scenery layer. Exempt only the
	# identified endpoint actors, using the established participant lookup.
	var excluded: Array[RID] = _actions._bodies_at(Vector2(from.x, from.z))
	for rid: RID in _actions._bodies_at(Vector2(to.x, to.z)):
		if not excluded.has(rid):
			excluded.append(rid)
	query.exclude = excluded
	query.hit_from_inside = true
	return get_world_3d().direct_space_state.intersect_ray(query).is_empty()


func combat_safe_motion(from: Vector2, to: Vector2) -> Vector2:
	return _actions.safe_actor_motion(from, to)


func guard_visual_style() -> String:
	# Direction selects presentation only; it never expands the existing
	# authoritative guard window or creates a new defensive permission.
	var axis := _movement_axis()
	if absf(axis.x) > absf(axis.y) and absf(axis.x) > .45:
		return "guard_right" if axis.x > 0.0 else "guard_left"
	if absf(axis.y) > .45:
		return "guard_low" if axis.y > 0.0 else "guard_high"
	return "guard_front"


func cue_village_defense(action: String) -> void:
	if _active and _figure != null:
		_figure.cue("block" if action == "village_block" else "march",guard_visual_style() if action == "village_block" else "")
		if action == "village_dodge":
			_dodge_remaining = 0.26
			_dodge_direction = Vector3.BACK.rotated(Vector3.UP, _figure.rotation.y)


func focus_village_npc(id: String) -> void:
	_village_focus = id
	village_life_world.focus(id, get_player_position())
	var direction: Vector3 = get_player_position() - village_life_world.actor_position(id)
	direction.y = 0
	_frontier_camera_direction = direction.normalized() if direction.length() > .1 else Vector3.BACK
	_camera_initialized = false


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
	add_child(opening_props)
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
	_camera.fov = 54.0
	_camera.near = 0.12
	_camera.far = 300.0
	add_child(_camera)
	_camera.current = true
	_hint = Art.label(_player, "", Vector3(0, 1.25, 0), Color(1, 0.92, 0.70), 33)
	_hint.font_size = 28
	_hint.pixel_size = 0.0019
	_hint.outline_size = 3
	_hint.visible = false
	village_life_world = VillageLifeWorld.new()
	village_life_world.name = "VillageLife"
	add_child(village_life_world)
	regional_terrain = RegionalTerrain.new()
	regional_terrain.name = "RegionalTerrain"
	add_child(regional_terrain)
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
		if VillageLayout.reserved(Vector2(x,z),1.3) or VillageLayout.road(Vector2(x,z)):
			continue
		tree_sites.append({"kind":Grove.KINDS[index%3],"position":at,"scale":random.randf_range(0.8,1.15),"yaw":random.randf_range(-PI,PI)})
		Art.box_collider(ground, Vector3(0.44,2.6,0.44), at+Vector3.UP*1.3)
	for at in [Vector3(-18,0,8),Vector3(6,0,-12),Vector3(-19,0,15),Vector3(26,0,16)]:
		tree_sites.append({"kind":Grove.KINDS[tree_sites.size()%3],"position":at,"scale":0.92,"yaw":random.randf_range(-PI,PI)})
		Art.box_collider(ground, Vector3(0.42,2.6,0.42),at+Vector3.UP*1.3)
	for index in range(26):
		var location := Vector3(random.randf_range(-58, 48), -0.05, random.randf_range(-45, 31))
		if location.x > -20 and location.x < 29 and location.z > -22 and location.z < 19:
			continue
		if VillageLayout.reserved(Vector2(location.x,location.z),1.0) or VillageLayout.road(Vector2(location.x,location.z)):
			continue
		Art.sphere(ground, random.randf_range(0.35, 0.90), location, _materials["dark_stone"], Vector3(1.3, 0.6, 1.0))
	# Older saved careers retain their old boundary; new village lives stream beyond it.
	var boundary := Node3D.new()
	boundary.name = "LegacyBoundary"
	ground.add_child(boundary)
	for x: float in [-64, 58]:
		Art.box_collider(boundary, Vector3(1, 15, 105), Vector3(x, 7, -8))
	for z: float in [-58, 40]:
		Art.box_collider(boundary, Vector3(125, 15, 1), Vector3(-3, 7, z))


func _create_village() -> void:
	var village := Node3D.new()
	village.name = "FrontierVillage"
	add_child(village)
	village.add_child(regional)
	population.name = "VillagePopulation"
	village.add_child(population)
	scenery.add_businesses(village)
	_create_palisade(village)
	_create_outer_palisade(village)
	village.add_child(crops)
	scenery.sow_field(crops)
	for x: float in [-3, 3]:
		Art.box(village, Vector3(0.22, 4.6, 0.22), Vector3(x, 2.3, 18), _materials["timber"], true)
		Art.box(village, Vector3(1.2, 1.8, 0.04), Vector3(x + 0.56, 3.6, 18), _materials["red"])
	Art.label(village, "VALDORA\nGRENZDORF", Vector3(0, 4.8, 18), Color(0.91, 0.84, 0.66), 52)


func _create_palisade(parent: Node3D) -> void:
	# The southern enclosure still protects the existing personal building plot.
	# Its old northern wall is opened toward the new civic and residential quarter.
	var inner:=Node3D.new()
	inner.name="InnerLegacyPalisade"
	parent.add_child(inner)
	parent=inner
	for z: float in [18.0]:
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


func _create_outer_palisade(parent: Node3D) -> void:
	var outer := Node3D.new()
	outer.name = "OuterVillageBoundary"
	parent.add_child(outer)
	for z in [-49.0,30.0]:
		for span: Vector2 in [Vector2(-21,-3),Vector2(3,48)]:
			var poses := []
			var count := ceili((span.y-span.x)/1.4)
			for i in count:
				poses.append(Transform3D(Basis.IDENTITY,Vector3(span.x+i*1.4,0,z)))
			scenery.palisade_bays(outer,poses)
			Art.box_collider(outer,Vector3(span.y-span.x,2.5,.5),Vector3((span.x+span.y)*.5,1.25,z))
	for x in [-21.0,48.0]:
		var gaps := [Vector2(-49,1),Vector2(7,30)] if x < 0 else [Vector2(-49,-16),Vector2(-10,30)]
		for span: Vector2 in gaps:
			var poses := []
			var count := ceili((span.y-span.x)/1.4)
			for i in count:
				poses.append(Transform3D(Basis(Vector3.UP,PI/2),Vector3(x,0,span.x+i*1.4)))
			scenery.palisade_bays(outer,poses)
			Art.box_collider(outer,Vector3(.5,2.5,span.y-span.x),Vector3(x,1.25,(span.x+span.y)*.5))


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
	_player.collision_mask = 1 | 4 | 8
	_player.floor_snap_length = 0.25
	var shape := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.28
	capsule.height = 1.8
	shape.shape = capsule
	_player.add_child(shape)
	add_child(_player)
	_figure = Art.person(_player,"player","italia",12)
	var player_ring := Art.cylinder(_player, 0.46, 0.018, Vector3(0, -0.87, 0), Art.transparent_material(Color(0.91, 0.76, 0.41, 0.48)))
	player_ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


func _create_companion_and_training() -> void:
	_companion = CharacterBody3D.new()
	_companion.name = "Marcus"
	_companion.position = COMPANION_LOCATION
	_companion.collision_mask = 1 | 2 | 4 | VillageLayout.CITIZEN_LAYER
	_companion.floor_snap_length = 0.35
	var capsule := CapsuleShape3D.new()
	capsule.radius = VillageLayout.CITIZEN_RADIUS
	capsule.height = 1.72
	var shape := CollisionShape3D.new()
	shape.name = "PersonalSpace"
	shape.shape = capsule
	shape.position.y = 0.9
	_companion.add_child(shape)
	add_child(_companion)
	Art.person(_companion,"companion","italia",12).position.y = 0.9
	_companion_label = Art.label(_companion, "Marcus · E\nGefährten kennenlernen", Vector3(0, 2.05, 0), Color(0.85, 0.92, 0.74), 36)
	_companion_label.font_size = 24
	_companion_label.pixel_size = 0.0024
	_companion_label.visibility_range_end = 5.0
	var training := Node3D.new()
	training.name = "TrainingGround"
	training.position = TRAINING_LOCATION
	add_child(training)
	var post := Art.cylinder(training, 0.16, 2.0, Vector3(0, 1.0, 0), _materials["timber"], 0.13, true)
	var dummy_path := "res://assets/village/training_dummy.glb"
	if ResourceLoader.exists(dummy_path):
		post.visible = false
		var dummy: Node3D = load(dummy_path).instantiate()
		dummy.name = "TrainingDummy"
		training.add_child(dummy)
	else:
		Art.box(training, Vector3(1.5, 0.18, 0.18), Vector3(0, 1.4, 0), _materials["timber"])
		Art.sphere(training, 0.32, Vector3(0, 1.4, 0), _materials["straw"], Vector3(1.0, 1.6, 0.7))
	_training_label = Art.label(training, "Übungsplatz · E", Vector3(0, 2.8, 0), Color(0.97, 0.84, 0.58), 39)
	_training_label.font_size = 26
	_training_label.pixel_size = 0.0024
	_training_label.visibility_range_end = 8.0
	var mentor := Node3D.new()
	mentor.name = "Mentor"
	mentor.position = Vector3(-2.0, 0.9, -1.5)
	training.add_child(mentor)
	Art.person(mentor,"mentor")
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
			child.visibility_range_end = 0
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
	title.visibility_range_end = 0
	return building


func _add_finished_hut_collision(building: Node3D) -> void:
	var collision := Node3D.new()
	collision.name = "FinishedCollision"
	building.add_child(collision)
	Art.box_collider(collision,Vector3(3.7,.14,3.5),Vector3(0,.07,0))
	var ramp:=StaticBody3D.new()
	ramp.name="EntranceRamp"
	collision.add_child(ramp)
	var ramp_shape:=CollisionShape3D.new()
	var hull:=ConvexPolygonShape3D.new()
	hull.points=PackedVector3Array([Vector3(-.55,0,1.55),Vector3(.55,0,1.55),Vector3(-.55,.14,1.55),Vector3(.55,.14,1.55),Vector3(-.55,0,2.35),Vector3(.55,0,2.35)])
	ramp_shape.shape=hull
	ramp.add_child(ramp_shape)
	Art.box_collider(collision, Vector3(0.22, 2.25, 3.7), Vector3(-1.9, 1.18, 0))
	Art.box_collider(collision, Vector3(0.22, 2.25, 3.7), Vector3(1.9, 1.18, 0))
	Art.box_collider(collision, Vector3(3.7, 2.25, 0.22), Vector3(0, 1.18, -1.8))
	Art.box_collider(collision, Vector3(1.35, 2.25, 0.22), Vector3(-1.25, 1.18, 1.8))
	Art.box_collider(collision, Vector3(1.35, 2.25, 0.22), Vector3(1.25, 1.18, 1.8))


func npc_observations() -> Dictionary:
	var observations: Dictionary = population.behavior_observations()
	if is_instance_valid(village_life_world):
		observations.merge(village_life_world.behavior_observations(), true)
	if is_instance_valid(_companion) and _companion.visible and str(_state.get("origin_id", "italia")) == "italia":
		var at: Vector3 = _companion.global_position + Vector3.UP * 0.9
		observations["marcus"] = {"position": [at.x, at.y, at.z], "route_distance": 0.0}
	return observations


func _sync_companion() -> void:
	_companion.collision_layer = VillageLayout.CITIZEN_LAYER if Childhood.enabled(_state) else (4 if CombatActions.enabled(_state) else 0)
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
			Art.person(actor,"enemy")
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
		if health <= 0: figure.cue("death")
		elif health < int(visual.get_meta("previous_health",health)): figure.cue("hit")
		visual.set_meta("previous_health",health)
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
	var residents: Array = _state.get("village", {}).get("economy", {}).get("people", [])
	var named_militia: Array[Dictionary] = []
	if _state.get("village", {}).get("enabled", false):
		for id: String in _state.village.get("militia", []):
			for person: Dictionary in residents:
				if person.id == id and person.alive:
					named_militia.append(person)
		alive = named_militia.size()
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
		Art.person(soldier,"recruit")
		var label := Art.label(soldier,"",Vector3(0,1.05,0),Color(0.78,0.88,0.74),28)
		label.name = "RecruitName"
		soldier.position = _player.position + Vector3(2 + _squad_views.size(), 0, 2)
		_squad_views.append(soldier)
	while _squad_views.size() > alive:
		var removed: Node3D = _squad_views.pop_back()
		removed.queue_free()
	for index in range(_squad_views.size()):
		var recruit_name := "Rekrut %d" % (index + 1)
		var resident_id := ""
		if not named_militia.is_empty():
			recruit_name = str(named_militia[index].name)
			resident_id = str(named_militia[index].id)
		elif _state.get("origin_id", "italia") == "italia":
			recruit_name = VillageLayout.resident(VillageLayout.VOLUNTEERS[index]).name
		_squad_views[index].set_meta("resident_id", resident_id)
		_squad_views[index].get_node("RecruitName").text = recruit_name


func _physics_process(delta: float) -> void:
	if not _built or _camera == null:
		return
	_update_camera(delta)
	if _state.get("village", {}).get("enabled", false):
		regional_terrain.follow(get_player_position(), _quality_profile)
	population.update_nearby(get_player_position(),_active and _mode == "person")
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
	if _can_show_player_work() and _at_active_work_station():
		_figure.keep_working()
	var frontier: Dictionary = _state.get("frontier",{})
	var wagon_work: bool = _can_show_player_work() and int(frontier.get("step",0)) == 2 and frontier.get("preparation","") == "work" and float(frontier.get("work_seconds",0)) < 12.0 and _horizontal_distance(_player.position,Vector3(3,0,24)) <= 3.0
	if wagon_work:
		_figure.keep_working()
	population.set_wagon_work(wagon_work)
	_update_followers(delta)
	_update_story_companions(delta)
	_update_encounter()
	_update_preview()
	_update_context_hint()


func _movement_axis() -> Vector2:
	var axis := _touch_move
	var focus: Control = get_viewport().gui_get_focus_owner()
	if not (focus is LineEdit or focus is TextEdit):
		axis.x += float(Input.is_physical_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT)) - float(Input.is_physical_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT))
		axis.y += float(Input.is_physical_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN)) - float(Input.is_physical_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP))
	return axis.limit_length(1.0)


func _can_show_player_work() -> bool:
	return _active and _mode == "person" and _figure.speed < 0.10 and _movement_axis().length_squared() <= 0.0001 and not CombatActions.busy(_actions.state)


func _at_active_work_station() -> bool:
	if not Childhood.enabled(_state):
		return false
	var child: Dictionary = _state.village.childhood
	var index := int(child.completed.size())
	if str(child.active_work).is_empty() or index >= Childhood.STEPS.size():
		return false
	var step: Dictionary = Childhood.STEPS[index]
	if step.get("id", "") != child.active_work or not step.has("seconds") or not step.has("point"):
		return false
	if float(child.work_seconds) >= float(step.seconds) or bool(_state.village.raid.active) or bool(_state.encounter.active):
		return false
	if str(step.id).begins_with("forge_") and not VillageLife.is_available(_state, "sextus"):
		return false
	var station: Vector2 = Childhood.POINTS[step.point]
	return Vector2(_player.position.x, _player.position.z).distance_to(station) <= Childhood.POINT_RANGE


func _move_player(delta: float) -> void:
	var axis := _movement_axis()
	var direction := Vector3(axis.x, 0, axis.y).rotated(Vector3.UP, _camera_yaw)
	var focus: Control = get_viewport().gui_get_focus_owner()
	var editing_text := focus is LineEdit or focus is TextEdit
	var running := _running or (not editing_text and Input.is_physical_key_pressed(KEY_SHIFT))
	var top_speed := (CHILD_RUN_SPEED if int(_state.get("player", {}).get("age", 12)) < 18 else PLAYER_SPEED) if running else WALK_SPEED
	var in_action := CombatActions.busy(_actions.state)
	var previous_yaw := _figure.rotation.y
	if direction.length_squared() > 0.01 and not in_action:
		var desired_yaw := atan2(-direction.x, -direction.z)
		_figure.rotation.y = rotate_toward(_figure.rotation.y, desired_yaw, delta * (5.5 if running else 4.2))
		var alignment := maxf(0.0, Vector3.FORWARD.rotated(Vector3.UP, _figure.rotation.y).dot(direction.normalized()))
		top_speed *= lerpf(0.3, 1.0, alignment)
	_turn_rate = angle_difference(previous_yaw, _figure.rotation.y) / maxf(delta, 0.000001)
	var desired := direction * top_speed if not in_action else Vector3.ZERO
	var acceleration := 9.0 if desired.length_squared() < 0.01 else (8.0 if running else 5.0)
	_player.velocity.x = move_toward(_player.velocity.x, desired.x, delta * acceleration)
	_player.velocity.z = move_toward(_player.velocity.z, desired.z, delta * acceleration)
	if _dodge_remaining > 0:
		_dodge_remaining = maxf(0.0, _dodge_remaining - delta)
		_player.velocity.x = _dodge_direction.x * 3.4
		_player.velocity.z = _dodge_direction.z * 3.4
	if not _player.is_on_floor():
		_player.velocity.y -= delta * 19.6
	else:
		_player.velocity.y = -0.3
	_player.move_and_slide()
	_player.position.x = clampf(_player.position.x, -15999.0, 15999.0)
	_player.position.z = clampf(_player.position.z, -15999.0, 15999.0)


func _pan_city_camera(delta: float) -> void:
	var direction := Vector3(_touch_move.x, 0, _touch_move.y)
	direction.x += float(Input.is_physical_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT)) - float(Input.is_physical_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT))
	direction.z += float(Input.is_physical_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN)) - float(Input.is_physical_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP))
	_city_focus += direction.limit_length(1.0) * delta * 14.0
	_city_focus.x = clampf(_city_focus.x, -25, 48)
	_city_focus.z = clampf(_city_focus.z, -48, 30)


func _update_camera(delta: float) -> void:
	var target: Vector3
	var desired: Vector3
	var collision_anchor := Vector3.INF
	if not _village_focus.is_empty() and village_life_world != null and village_life_world.actors.has(_village_focus):
		var actor: Vector3 = village_life_world.actor_position(_village_focus)
		var right := Vector3.UP.cross(_frontier_camera_direction)
		collision_anchor = actor + Vector3.UP * 1.48
		target = collision_anchor + right * .65
		desired = actor + Vector3.UP * 1.65 + _frontier_camera_direction * 3.0
	elif not _frontier_focus.is_empty() and not population.info(_frontier_focus).is_empty():
		var actor: Vector3 = population.actor_position(_frontier_focus)
		var head := actor+Vector3.UP*1.48
		var right := Vector3.UP.cross(_frontier_camera_direction)
		target = head+right*.64
		desired = actor+Vector3.UP*1.60+_frontier_camera_direction*3.0
		collision_anchor = head
	elif _mode == "person":
		target = _player.global_position + Vector3(0, 0.40, 0)
		collision_anchor = target
		var offset := Vector3(0.36, sin(_camera_pitch) * _person_zoom + 0.22, cos(_camera_pitch) * _person_zoom)
		desired = target + offset.rotated(Vector3.UP, _camera_yaw)
		# Look beyond the shoulder so the horizon and the path remain visible.
		target += Vector3(0.36, 0.05, -3.6).rotated(Vector3.UP, _camera_yaw)
	elif _mode == "city":
		target = _city_focus
		var orbit := Vector3(10, 38, 28)
		if _menu_flight and not _active:
			_flight_time += delta
			target += Vector3(sin(_flight_time * 0.045) * 7.0, 0, sin(_flight_time * 0.031) * 5.0)
			orbit = orbit.rotated(Vector3.UP, sin(_flight_time * 0.02) * 0.3)
		desired = target + orbit
		_camera.size = _city_zoom
	else:
		target = _map_focus
		desired = target + Vector3(0, 104, 18)
		_camera.size = 100.0
	if collision_anchor.is_finite() and is_inside_tree():
		var previous := _camera.global_position if _camera_initialized else Vector3.INF
		var placement: Vector3 = _camera_obstruction.place(get_world_3d().direct_space_state,
			collision_anchor,desired,previous,1.0-exp(-maxf(delta,0.0)*12.0),[_player.get_rid()])
		if not placement.is_finite():
			# A sealed volume has no verified local view. Never assign INF or
			# show clipped geometry; keep UI and camera ownership unchanged.
			if _camera_obstructed_mask < 0:
				_camera_obstructed_mask = _camera.cull_mask
			_camera.cull_mask = 0
			_camera_initialized = false
			return
		_camera.global_position = placement
		_camera_initialized = true
	elif not _camera_initialized:
		_camera.global_position = desired
		_camera_initialized = true
	else:
		_camera.global_position = _camera.global_position.lerp(desired, 1.0 - exp(-delta * 12.0))
	if _camera_obstructed_mask >= 0:
		_camera.cull_mask = _camera_obstructed_mask
		_camera_obstructed_mask = -1
	if _camera.global_position.distance_squared_to(target) > 0.01:
		_camera.look_at(target, Vector3.UP)


func _animate_figure() -> void:
	var actual := _player.get_real_velocity()
	var speed := Vector2(actual.x, actual.z).length()
	_figure.drive(speed if _mode == "person" else 0.0, _turn_rate)


func _update_story_companions(delta: float) -> void:
	_story_companions.advance(delta)


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
		soldier.get_node("Figure").drive(Vector2(soldier.get_real_velocity().x,soldier.get_real_velocity().z).length())


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
		if CombatActions.enabled(_actions.state) and not combat_sight_clear(Vector2(location.x, location.z), Vector2(_player.position.x, _player.position.z)):
			distance = INF
		nearest_distance = minf(nearest_distance, distance)
		var identity := str(enemy.get("id", ""))
		if _enemy_views.has(identity):
			var actor: Node3D = _enemy_views[identity]
			var figure: Node3D = actor.get_node("Figure")
			var direction := _player.position - actor.position
			figure.rotation.y = atan2(-direction.x, -direction.z)
			if distance <= 2.3 and _enemy_attack_cooldown <= 0.0:
				figure.cue("attack")
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
		if _mode == "person" and _touch_camera_managed:
			return
		_handle_touch(event as InputEventScreenTouch)
		return
	if event is InputEventScreenDrag:
		if _mode == "person" and _touch_camera_managed:
			return
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
			KEY_Q:
				action_requested.emit("village_unarmed_guard" if CombatActions.enabled(_actions.state) else "village_block", {})
			KEY_R:
				action_requested.emit("village_unarmed_dodge" if CombatActions.enabled(_actions.state) else "village_dodge", {})
			KEY_J:
				action_requested.emit("village_panel", {})
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
				_city_focus.x = clampf(_city_focus.x, -25, 48)
				_city_focus.z = clampf(_city_focus.z, -48, 30)
			else:
				_map_focus -= offset
				_map_focus.x = clampf(_map_focus.x, -30, 20)
				_map_focus.z = clampf(_map_focus.z, -30, 15)
	get_viewport().set_input_as_handled()


func _interact() -> void:
	if _mode != "person":
		return
	if Childhood.enabled(_state):
		var at:=Vector2(_player.position.x,_player.position.z)
		for item: Dictionary in Childhood.interactables(_state):
			if at.distance_to(item.point)<=float(item.radius):
				_figure.cue("gather")
				action_requested.emit(item.command,item.payload)
				return
	if _state.get("village", {}).get("enabled", false):
		var raid: Dictionary = _state.village.raid
		var point := Vector2(_player.position.x, _player.position.z)
		if raid.status == "warning" and point.distance_to(VillageLife.SCOUT_POINT) <= VillageLife.RANGE and not raid.scouted:
			action_requested.emit("village_scout", {})
			return
		if raid.status == "warning" and point.distance_to(VillageLife.ALARM_POINT) <= VillageLife.RANGE and not raid.alarm:
			action_requested.emit("village_alarm", {})
			return
		if raid.active and raid.rescue_available and not raid.rescued and point.distance_to(VillageLife.RESCUE_POINT) <= VillageLife.RANGE:
			action_requested.emit("village_rescue", {})
			return
		var villager: String = village_life_world.nearest(_player.position)
		if not villager.is_empty():
			action_requested.emit("village_npc", {"npc_id":villager})
			return
	var companion: Dictionary = _state.get("companion", {})
	if _horizontal_distance(_player.position, _companion.position) <= INTERACTION_RADIUS and (not bool(companion.get("met", false)) or not Childhood.companion_dialogue(_state, "marcus").is_empty()):
		_companion.get_node("Figure").cue("talk")
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
		_figure.cue("gather")
		action_requested.emit("gather", {"node_id": closest_id})
	elif _horizontal_distance(_player.position, TRAINING_LOCATION) <= INTERACTION_RADIUS:
		action_requested.emit("combat_palette" if Childhood.enabled(_state) else "train", {})
	elif _horizontal_distance(_player.position, _companion.position) <= INTERACTION_RADIUS:
		_companion.get_node("Figure").cue("talk")
		action_requested.emit("companion_interact", {})
	elif not bool(_state.get("encounter",{}).get("active",false)):
		var npc := _nearest_visible_npc()
		if not npc.is_empty():
			action_requested.emit("frontier_talk",{"npc_id":npc})


func _nearest_visible_npc() -> String:
	var npc: String = population.nearest_npc(_player.global_position,INTERACTION_RADIUS)
	if npc.is_empty():
		return ""
	var target: Vector3 = population.actor_position(npc)+Vector3.UP*1.4
	var query := PhysicsRayQueryParameters3D.create(_player.global_position+Vector3.UP*.4,target,1)
	return npc if get_world_3d().direct_space_state.intersect_ray(query).is_empty() else ""


func _attack() -> void:
	if _mode != "person" or _attack_cooldown > 0.0:
		return
	if CombatActions.enabled(_actions.state):
		_actions.attack()
		return
	_attack_cooldown = 0.65
	_attack_animation = 0.28
	if _state.get("village", {}).get("enabled", false) and _state.village.raid.active:
		_figure.cue("attack")
		var target_id := ""
		var distance := 2.8
		for enemy: Dictionary in _state.village.raid.enemies:
			var target := Vector3(enemy.x, 0, enemy.z)
			var next_distance := _horizontal_distance(_player.position, target)
			if int(enemy.health) > 0 and next_distance <= distance:
				distance = next_distance
				target_id = enemy.id
		if not target_id.is_empty():
			action_requested.emit("village_strike", {"enemy_id":target_id})
		return
	_figure.cue("attack" if _state.get("encounter",{}).get("active",false) else "train")
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
		get_node("TrainingGround/Mentor/Figure").cue("block")
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
	if Childhood.enabled(_state):
		var at:=Vector2(_player.position.x,_player.position.z)
		for item: Dictionary in Childhood.interactables(_state):
			if at.distance_to(item.point)<=float(item.radius):
				_hint.text=str(item.label)
				return
		if at.distance_to(CombatActions.PRACTICE_POINT)<2.4:
			_hint.text="Am Pfahl üben\nTechniken wählen"
			return
	if village_life_world != null:
		var village_hint: String = village_life_world.hint(_player.position)
		if not village_hint.is_empty():
			_hint.text = village_hint.trim_prefix("Interagieren · ")
			return
	var companion: Dictionary = _state.get("companion", {})
	if _horizontal_distance(_player.position, _companion.position) <= INTERACTION_RADIUS and (not bool(companion.get("met", false)) or not Childhood.companion_dialogue(_state, "marcus").is_empty()):
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
		if CombatActions.enabled(_actions.state):
			_hint.text = "Technik wählen · Am Pfahl üben"
		else:
			_hint.text = "Ausbildung abgeschlossen" if bool(progress.get("training_complete", false)) else "E · Ausbildung beginnen\nLMB / Leertaste · Übungsschlag"
		return
	var encounter: Dictionary = _state.get("encounter", {})
	if bool(encounter.get("active", false)):
		_hint.text = "LMB / Leertaste · Nahkampf\nAbstand unter 3 m"
		return
	var npc := _nearest_visible_npc()
	if not npc.is_empty():
		var info: Dictionary = population.info(npc)
		_hint.text = "Interagieren · %s\n%s" % [info.name,info.occupation]


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
