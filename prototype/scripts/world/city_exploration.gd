extends Node3D
## The menu tour owns its sandbox. Campaign visits borrow the running WorldModel.
signal leave_requested
signal story_requested
const Person := preload("res://scripts/visuals/village_person.gd")
const YouthOutfit := preload("res://scripts/visuals/youth_outfit.gd")
const State := preload("res://scripts/world/city_exploration_state.gd")
const CameraObstruction := preload("res://scripts/world/camera_obstruction.gd")
const CityDetailAdapter := preload("res://scripts/rendering/city_exploration_detail_adapter.gd")
const CityCharacterFinish := preload("res://scripts/rendering/city_character_detail.gd")
const CityMarketSignage := preload("res://scripts/world/city_market_signage.gd")
const CityMarketBridge := preload("res://scripts/world/city_market_bridge.gd")
const Daylight := preload("res://scripts/rendering/village_look.gd")
const BakeryDisplay := preload("res://scripts/world/city_bakery_display.gd")
const ResidentView := preload("res://scripts/world/city_resident_view.gd")
const CityLifeSession := preload("res://scripts/world/city_life_session.gd")
const CitySurfaceMicrodetail := preload("res://scripts/rendering/city_surface_microdetail.gd")
const VivaCloseupProps := preload("res://scripts/rendering/city_viva_closeup_props.gd")
const CityAmbientPeople := preload("res://scripts/world/city_ambient_people.gd")
const Crowd := preload("res://scripts/world/city_exploration_crowd.gd")
const WatchPatrol = preload("res://scripts/world/city_watch_patrol.gd")
const CityTraining := preload("res://scripts/world/city_training.gd")
const CombatActions := preload("res://scripts/domain/combat_actions.gd")
const VivaAtmosphere := preload("res://scripts/rendering/viva_roma_atmosphere.gd")
const TouchPad := preload("res://scripts/ui/touch_pad.gd")
const TouchLook := preload("res://scripts/ui/touch_look.gd")
const TouchAction := preload("res://scripts/ui/touch_action.gd")
const SafeArea := preload("res://scripts/ui/safe_area.gd")
const Calendar := preload("res://scripts/domain/world_calendar.gd")
const EraRegistry := preload("res://scripts/domain/era_registry.gd")
const RomanQuarter := preload("res://scripts/world/roman_quarter.gd")
const RidingTrial := preload("res://scripts/world/city_riding_trial.gd")
const FlavianAmphitheatre := preload("res://scripts/monuments/colosseum.gd")
const CITY_PATH := "res://assets/world/roman_city_test.glb"
const CITY_COLLISION := "res://assets/world/roman_city_collision.glb"
const TEMPLE_PATH := "res://assets/world/roman_meshy_temple_%d.glb"
const FORUM_DETAIL := "res://assets/world/roman_forum_paving_detail.glb"
const FORUM_COLLISION := "res://assets/world/roman_forum_paving_collision.glb"
const MAX_STEP := 0.25
const SOLE_OFFSET := 0.9
const VISIBILITY_MARGIN := 20.0
# Ground, main-street and plot surfaces are exported as tiles under these group
# nodes (tools/world/build_roman_test_city.py, SurfaceTiles).
const SURFACE_TILE_GROUPS := ["City_Ground", "Main_Streets", "Residential_Roads"]
const CATALOG_PATH := "res://assets/world/city_catalog.json"
const CATALOG_ORIGIN := Vector3(475,0,90)
const WALK_SPEED := 1.45
const RUN_SPEED := 3.8
const WALK_ACCELERATION := 4.5
const RUN_ACCELERATION := 6.0
const BRAKING_DECELERATION := 8.0
var profile := "balanced"
var persist := true
var enable_riding_trial := false
var campaign
var campaign_path := ""
var party_visit := preload("res://scripts/world/city_party_visit.gd").new()
var resident_view: ResidentView
var _bakery: BakeryDisplay
var _bakery_business := -1
var street_watch: WatchPatrol
var _visit_elapsed := 0.0
var _market_sun: DirectionalLight3D
var _solar_minute := -1
var _wait_button: Button
# Only explicit, non-persistent QA callers may attach the new city economy.
var enable_living_city_qa := false
var living_city: CityLifeSession
var _living_city_clock: Dictionary = {}
# Callers entering a dated scenario assign its authoritative JDN before add_child.
var world_jdn := Calendar.campaign_start_jdn()
# Only the independently dated free city uses the new monument until the full campaign assets are accepted.
var use_flavian_kit := false
var start_at_colosseum := false
# Review toggle: keep an exact legacy light/ground path for comparison.
var viva_visuals := true
var save_path := State.PATH
var paused := false
var player := CharacterBody3D.new()
var figure := Person.new()
var camera := Camera3D.new()
var city_available := false
var youth_available := false
var ambient_people: CityAmbientPeople
var quarter: RomanQuarter
var riding_trial: RidingTrial
var crowd := Crowd.new()
var training := CityTraining.new()
var _crowd_elapsed := 0.0
var catalog: Array[Dictionary] = []
var _catalog_nodes: Dictionary = {}
var _catalog_pending := ""
var _catalog_pending_index := -1
var _catalog_elapsed := 0.0
var _catalog_status := ""
var _street_caption := ""
var _touch_move := Vector2.ZERO
var _yaw := 0.0
var _pitch := -0.18
var _distance := 4.2
var _running := false
var _camera_solver := CameraObstruction.new()
var _camera_previous := Vector3.INF
var _action_left := 0.0
var _save_elapsed := 0.0
var _hud := CanvasLayer.new()
var _safe := Control.new()
var _status := Label.new()
var _pace: Button
var _pause_panel := PanelContainer.new()
var _pad: Control
var _look: Control
var _toolbar: HBoxContainer
var street_chart := preload("res://scripts/ui/roman_hud/city_route_chart.gd").new()
var _trade_bar: HBoxContainer
var _trade_button: Button
var _bag_button: Button
var market := CityMarketBridge.new()
var _actions: HBoxContainer
var _tablet_dialog := AcceptDialog.new()

func _ready() -> void:
	name = "CityExploration"
	_build_ground()
	_load_city()
	if city_available:
		quarter = RomanQuarter.new()
		quarter.name = "RomanQuarter"
		quarter.position = RomanQuarter.ORIGIN
		add_child(quarter)
		quarter.install(profile, _add_static_colliders)
	_build_player()
	_build_camera()
	add_child(training)
	if campaign == null:
		_build_ambient_people()
	crowd.profile = profile
	if is_instance_valid(ambient_people):
		for record: Dictionary in ambient_people.citizens:
			crowd.exclude_market_shop(str(record.get("shop", "")))
	add_child(crowd)
	if campaign == null:
		_read_catalog()
	_build_ui()
	_restore(State.read(save_path) if persist and campaign == null else State.defaults())
	if start_at_colosseum:
		go_to_colosseum()
	add_child(market)
	market.message.connect(_market_message)
	market.closed.connect(_close_market)
	var stable := quarter.stable_trader if quarter != null else null
	var city := get_node_or_null("RomanCity") as Node3D
	if campaign != null:
		var has_site := func(site: String) -> bool: return is_instance_valid(find_child(site, true, false))
		market.setup(city, player, true, stable, campaign, campaign_path, has_site)
		if market.available:
			# The street approaches the counters from +Z. Leave a walking
			# distance before the bakery so arrival cannot trigger a purchase.
			teleport(market.sites.bakery + Vector3(0, 0, 6))
		living_city = market.campaign_session()
		if living_city != null:
			resident_view = ResidentView.new()
			add_child(resident_view)
			resident_view.setup(living_city.life, player, camera, profile)
			street_watch = WatchPatrol.new()
			street_watch.name = "StreetWatch"
			add_child(street_watch)
			if not street_watch.setup(self,living_city.life.streets,_safe):
				street_watch.queue_free()
				street_watch = null
			_bakery_business = living_city.life.business_for_shop("bakery")
			if _bakery_business >= 0:
				var display := BakeryDisplay.new()
				if display.install(city):
					_bakery = display
					_update_bakery()
				else:
					display.free()
	else:
		market.setup(city, player, persist, stable)
	if enable_living_city_qa and not persist and market.available:
		var session := CityLifeSession.new()
		var clock := Calendar.new_clock(world_jdn, 12 * 3600)
		var node_exists := func(node_name: String) -> bool: return is_instance_valid(find_child(node_name, true, false))
		if session.start(clock, 20261126, node_exists) and market.attach_living_city(session):
			living_city = session
			_living_city_clock = clock
		else:
			push_warning("City life QA could not be attached: " + session.error)
	if enable_riding_trial:
		_start_riding_trial()
	_bag_button.disabled = not market.available
	_refresh_market_buttons()
	get_viewport().size_changed.connect(_layout_ui)
	_layout_ui()
	_update_status()
	var renderer := get_node_or_null("/root/RuntimeDisplay")
	if is_instance_valid(renderer):
		renderer.set_sustained_scene(true)
	print("IMPERATHEN_CITY_READY "+JSON.stringify({"city":city_available,"meshy_youth":youth_available,"selected_player_model":figure.active_model_path,"original_youth_active":youth_available and figure.active_model_path.begins_with("res://assets/characters/hero_meshy_italia_"),"catalog_families":catalog.size(),"campaign_started":campaign != null,"combat_mode":"authoritative_unarmed_training","mocap_active":figure._uses_youth_mocap()}))

func _build_ground() -> void:
	var ground := MeshInstance3D.new()
	ground.name = "ExplorationGround"
	var mesh := PlaneMesh.new()
	mesh.size = Vector2(1400,1400)
	ground.mesh = mesh
	var material := StandardMaterial3D.new()
	material.albedo_color = Color("777d55")
	material.roughness = 0.96
	ground.material_override = VivaAtmosphere.ground_material(profile) if viva_visuals else material
	ground.position.y = -0.025
	add_child(ground)
	_box_collision(self,Vector3(1400,0.2,1400),Vector3(0,-0.125,0))
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-38,-24,0)
	sun.light_color = Color(1.0,0.88,0.72)
	sun.light_energy = 1.05
	sun.shadow_enabled = profile!="low"
	sun.directional_shadow_max_distance = 90.0
	if viva_visuals:
		VivaAtmosphere.configure_sun(sun, profile)
	add_child(sun)
	_market_sun = sun

func _scene(path: String) -> Node3D:
	if not ResourceLoader.exists(path,"PackedScene"):
		return null
	var packed := load(path) as PackedScene
	return packed.instantiate() as Node3D if packed!=null else null

func _load_city() -> void:
	var city := _scene(CITY_PATH)
	var excluded := {}
	if city!=null:
		city.name = "RomanCity"
		prune_future_city_nodes(city, world_jdn, excluded)
		if use_flavian_kit and FlavianAmphitheatre.available_at(world_jdn):
			_remove_legacy_amphitheatre(city)
		add_child(city)
		city_available = true
		var reach := 270.0 if profile in ["low","balanced"] else 450.0
		for mesh: MeshInstance3D in city.find_children("*","MeshInstance3D",true,false):
			mesh.visibility_range_end = reach + surface_tile_extra_reach(mesh)
			mesh.visibility_range_end_margin = VISIBILITY_MARGIN
	var collision := _scene(CITY_COLLISION)
	if collision!=null:
		# Apply chronology before converting collision meshes into live bodies.
		prune_future_city_nodes(collision, world_jdn, excluded)
		if use_flavian_kit and FlavianAmphitheatre.available_at(world_jdn):
			_remove_legacy_amphitheatre(collision)
		add_child(collision)
		_add_static_colliders(collision,"CityCollision_")
		collision.queue_free()
	if city_available and use_flavian_kit and FlavianAmphitheatre.available_at(world_jdn):
		var monument := FlavianAmphitheatre.new()
		monument.name = "FlavianAmphitheatre"
		# The city builder places the legacy kit at Blender (181, 42, 0); glTF converts Y to -Z.
		monument.position = Vector3(181, 0, -42)
		monument.profile = profile
		monument.world_jdn = world_jdn
		add_child(monument)
	var temple_level := 2 if profile=="low" else (1 if profile=="balanced" else 0)
	var temple := _scene(TEMPLE_PATH % temple_level)
	if temple!=null:
		temple.name = "MeshyTemple"
		temple.position = Vector3(0,0.09,-55)
		add_child(temple)
		var temple_collision := _scene(TEMPLE_PATH % 2)
		if temple_collision!=null:
			temple_collision.position = temple.position
			add_child(temple_collision)
			_add_static_colliders(temple_collision,"TempleCollision_")
			temple_collision.queue_free()
	# The actual 50 MB RomanCity GLB already contains Forum_Piazza and
	# Forum_Worn_Stonework. Never place an obsolete external duplicate over
	# those stones (z-fighting, redundant triangles and duplicated collision).
	var embedded_forum := is_instance_valid(city) and (
		is_instance_valid(city.find_child("Forum_Piazza",true,false))
		and is_instance_valid(city.find_child("Forum_Worn_Stonework",true,false)))
	if embedded_forum:
		print("IMPERATHEN_FORUM_SOURCE " + JSON.stringify({
			"source":"original_roman_city_glb","duplicate_external_loaded":false}))
	else:
		var forum_detail := _scene(FORUM_DETAIL)
		if forum_detail!=null:
			forum_detail.name = "ForumPavingDetail"
			add_child(forum_detail)
		var forum_collision := _scene(FORUM_COLLISION)
		if forum_collision!=null:
			add_child(forum_collision)
			_add_static_colliders(forum_collision,"ForumPavingCollision_")
			forum_collision.queue_free()
	print("IMPERATHEN_CITY_DETAIL " + JSON.stringify(CityDetailAdapter.install(city, profile)))
	# Read-only signboards are attached only to the six matching existing stalls.
	# The market bridge independently verifies the same authored stands before enabling transactions.
	print("IMPERATHEN_CITY_MARKET " + JSON.stringify(CityMarketSignage.install(city, profile)))
	# Optional GPU-instanced masonry and worn street microgeometry. This never
	# replaces the authored RomanCity walls, collision, NPCs, camera or save.
	print("IMPERATHEN_FACADE_DETAIL " + JSON.stringify(CitySurfaceMicrodetail.install(city, profile)))
	# Use real already-exported close-up GLBs. No extra collision bodies or economy.
	print("IMPERATHEN_VIVA_PROPS " + JSON.stringify(VivaCloseupProps.install(city, profile)))

## Remove both mesh and collision forms before installing the replacement.
static func _remove_legacy_amphitheatre(root: Node) -> void:
	for node: Node in root.get_children():
		var identity := str(node.name)
		if identity == "Colosseum" or identity.begins_with("Colosseum_"):
			node.free()
		else:
			_remove_legacy_amphitheatre(node)

## The builder exports dates on both visual and collision nodes. Keep the
## names removed from the visual GLB for older collision imports without extras.
static func prune_future_city_nodes(root: Node, jdn: int, excluded: Dictionary) -> void:
	for node: Node in root.get_children():
		var identity := str(node.name).trim_suffix("-colonly").trim_suffix("_collision")
		var extras: Dictionary = node.get_meta("extras", {})
		var year: Variant = extras.get("era_min_ce")
		if year == null and node.has_meta("era_min_ce"):
			year = node.get_meta("era_min_ce")
		var future := year != null and not EraRegistry.era_min_visible(int(year), jdn)
		# Older RomanCity exports did not always carry the registry metadata.
		if identity == "Colosseum" or identity.begins_with("Colosseum_"):
			future = future or not EraRegistry.available("building.amphitheatrum_flavium", jdn)
		if future or excluded.has(identity):
			excluded[identity] = true
			node.free()
		else:
			prune_future_city_nodes(node, jdn, excluded)

## Godot culls by the camera distance to a mesh's AABB centre. A flat ground
## tile is 136-188 m wide, so its centre can be out of range while a house standing
## on its edge is still drawn. Surface tiles therefore get their half diagonal
## plus both hysteresis margins on top of the profile range: whenever a house can
## be visible, the ground, street and plot surface under it is drawn as well.
static func surface_tile_extra_reach(mesh: MeshInstance3D) -> float:
	var group := mesh.get_parent()
	if group == null or str(group.name) not in SURFACE_TILE_GROUPS:
		return 0.0
	var size := mesh.get_aabb().size
	return 0.5*Vector2(size.x,size.z).length()+2.0*VISIBILITY_MARGIN

func _add_static_colliders(source: Node3D,prefix: String) -> void:
	# Godot's -colonly importer may already have generated the physics body.
	var imported_bodies: Array[Node] = source.find_children("*","StaticBody3D",true,false)
	if source is StaticBody3D:
		imported_bodies.push_front(source)
	if not imported_bodies.is_empty():
		for original: StaticBody3D in imported_bodies:
			var copy := original.duplicate() as StaticBody3D
			copy.name = prefix+str(original.name)
			copy.collision_layer = 1
			copy.collision_mask = 0
			add_child(copy)
			copy.global_transform = original.global_transform
		return
	for mesh: MeshInstance3D in source.find_children("*","MeshInstance3D",true,false):
		if mesh.mesh==null:
			continue
		var body := StaticBody3D.new()
		body.name = prefix+str(mesh.name)
		body.collision_layer = 1
		body.collision_mask = 0
		var shape := CollisionShape3D.new()
		shape.shape = mesh.mesh.create_trimesh_shape()
		body.add_child(shape)
		add_child(body)
		body.global_transform = mesh.global_transform

func _build_ambient_people() -> void:
	# Uses the existing city meshes, actual camera and the existing
	# village_person.gd appearance and animation library. Never duplicates
	# the independent player's save state, campaign or trade authority.
	var city := get_node_or_null("RomanCity") as Node3D
	if not is_instance_valid(city):
		return
	ambient_people = CityAmbientPeople.new()
	ambient_people.name = "CityAmbientLife"
	add_child(ambient_people)
	var status: Dictionary = ambient_people.setup(city,camera,profile)
	print("IMPERATHEN_CITY_PEOPLE " + JSON.stringify(status))


func _build_player() -> void:
	player.name = "ExplorationPlayer"
	player.collision_layer = 2
	player.collision_mask = 3 if campaign != null else 1
	player.safe_margin = 0.002
	player.floor_snap_length = 0.24
	player.floor_max_angle = deg_to_rad(46.0)
	var collider := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.height = 1.5
	capsule.radius = 0.24
	collider.shape = capsule
	collider.position.y = -0.15
	player.add_child(collider)
	add_child(player)
	figure.name = "Youth"
	figure.profile = profile
	figure.detail = 2 if profile=="low" else (1 if profile=="balanced" else 0)
	player.add_child(figure)
	var age := int(campaign.data.player.age) if campaign != null else 12
	var origin := str(campaign.data.origin_id) if campaign != null else "italia"
	var outfit := YouthOutfit.for_state(campaign.data) if campaign != null else YouthOutfit.ARMOURED
	if age == 12 and origin == "italia":
		youth_available = figure.configure_meshy_youth(true, outfit)
	figure.configure("player", origin, age)
	if age != 12:
		youth_available = figure.configure_meshy_youth(true, outfit)
	figure._check_lod = 10000.0
	if is_instance_valid(figure.body):
		CityCharacterFinish.apply_to(figure.body, profile, figure.detail)

func _build_camera() -> void:
	add_child(camera)
	camera.name = "ExplorationCamera"
	camera.current = true
	camera.fov = 62.0
	camera.near = 0.08
	camera.far = 1200.0
	# Create only the environment actually assigned to this camera. An unused
	# procedural sky must not allocate renderer resources during VIVA startup.
	if viva_visuals:
		camera.environment = VivaAtmosphere.environment(profile)
		return
	var environment := Environment.new()
	var sky := Sky.new()
	var atmosphere := ProceduralSkyMaterial.new()
	atmosphere.sky_top_color = Color("638caf")
	atmosphere.sky_horizon_color = Color("c4d3d3")
	atmosphere.ground_bottom_color = Color("80775d")
	atmosphere.ground_horizon_color = Color("c4d3d3")
	sky.sky_material = atmosphere
	sky.radiance_size = Sky.RADIANCE_SIZE_64
	environment.background_mode = Environment.BG_SKY
	environment.sky = sky
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("b4c0ce")
	environment.ambient_light_energy = 0.62
	environment.ambient_light_sky_contribution = 0.0
	environment.fog_enabled = true
	environment.fog_density = 0.0013
	environment.fog_light_color = Color("c3c9bf")
	camera.environment = environment

func _read_catalog() -> void:
	if not FileAccess.file_exists(CATALOG_PATH):
		return
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(CATALOG_PATH))
	if not data is Dictionary or data.get("format","")!="imperathen-city-catalog":
		return
	for value: Variant in data.get("families",[]):
		if value is Dictionary and value.get("tiers") is Array and not value.tiers.is_empty():
			catalog.append(value)
	var label := Label3D.new()
	label.text = "MODELLSAMMLUNG\n%d vorhandene Modellfamilien" % catalog.size()
	label.font_size = 50
	label.pixel_size = 0.015
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.position = CATALOG_ORIGIN+Vector3(0,4,8)
	label.visibility_range_end = 110
	add_child(label)

func _catalog_position(index: int) -> Vector3:
	return CATALOG_ORIGIN+Vector3(float(index%4)*26,0,-float(index/4)*22)

func _catalog_path(entry: Dictionary) -> String:
	var target := 2 if profile=="low" else 1
	var closest := 100
	var path := ""
	for tier: Dictionary in entry.tiers:
		var difference := absi(int(tier.level)-target)
		if difference<closest and ResourceLoader.exists(str(tier.path),"PackedScene"):
			closest = difference
			path = str(tier.path)
	return path

func _stream_catalog() -> void:
	if not _catalog_pending.is_empty():
		var status := ResourceLoader.load_threaded_get_status(_catalog_pending)
		if status==ResourceLoader.THREAD_LOAD_LOADED:
			var packed := ResourceLoader.load_threaded_get(_catalog_pending) as PackedScene
			if packed!=null:
				_add_catalog_model(_catalog_pending_index,packed)
			_catalog_pending = ""
		elif status in [ResourceLoader.THREAD_LOAD_FAILED,ResourceLoader.THREAD_LOAD_INVALID_RESOURCE]:
			ResourceLoader.load_threaded_get(_catalog_pending)
			_catalog_status = "Ein Sammlungsmodell konnte nicht geladen werden."
			_catalog_pending = ""
			_update_status()
		return
	for index: int in _catalog_nodes.keys():
		if player.position.distance_to(_catalog_position(index))>95:
			var node: Node3D = _catalog_nodes[index]
			node.queue_free()
			_catalog_nodes.erase(index)
	var nearest := -1
	var nearest_distance := 70.0
	for index in catalog.size():
		if _catalog_nodes.has(index):
			continue
		var distance := player.position.distance_to(_catalog_position(index))
		if distance<nearest_distance:
			nearest = index
			nearest_distance = distance
	if nearest<0:
		return
	var path := _catalog_path(catalog[nearest])
	if not path.is_empty() and ResourceLoader.load_threaded_request(path,"PackedScene",false)==OK:
		_catalog_pending = path
		_catalog_pending_index = nearest

func _add_catalog_model(index: int,packed: PackedScene) -> void:
	var model := packed.instantiate() as Node3D
	if model==null:
		return
	var station := Node3D.new()
	station.name = "Catalog_%02d" % index
	station.position = _catalog_position(index)
	add_child(station)
	station.add_child(model)
	var bounds := _bounds(model)
	model.position.y = -bounds.position.y
	if catalog[index].category=="equipment":
		model.position.y += 0.805
		_box_visual(station,Vector3(2,0.8,2),Vector3(0,0.4,0),Color("ad9d7d"))
		_box_collision(station,Vector3(2,0.8,2),Vector3(0,0.4,0))
	elif str(catalog[index].get("scale_status",""))=="unverified_source_units":
		var plinth_size := Vector3(maxf(2,bounds.size.x+0.6),0.7,maxf(2,bounds.size.z+0.6))
		model.position.y += 0.7
		_box_visual(station,plinth_size,Vector3(0,0.35,0),Color("827365"))
		_box_collision(station,plinth_size,Vector3(0,0.35,0))
	var label := Label3D.new()
	label.text = str(catalog[index].name)
	if str(catalog[index].get("scale_status",""))=="unverified_source_units":
		label.text += "\nMaßstab ungeprüft"
	label.font_size = 34
	label.pixel_size = 0.008
	label.position = Vector3(0,maxf(2,bounds.size.y+model.position.y+0.4),0)
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.visibility_range_end = 38
	station.add_child(label)
	_catalog_nodes[index] = station

func _build_ui() -> void:
	_hud.layer = 20
	add_child(_hud)
	_safe.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hud.add_child(_safe)
	_look = TouchLook.new()
	_look.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_look.look_changed.connect(_look_by)
	_look.zoom_changed.connect(func(factor: float): _distance=clampf(_distance*factor,1.6,8.0))
	_safe.add_child(_look)
	var heading := Label.new()
	heading.name = "Heading"
	heading.text = "IMPERATHEN · STADTMARKT" if campaign != null else ("IMPERATHEN · ROM 100 N. CHR." if use_flavian_kit else "IMPERATHEN · FREIE STADTERKUNDUNG")
	heading.add_theme_font_size_override("font_size",21)
	heading.add_theme_color_override("font_color",Color("f1dfb4"))
	heading.add_theme_color_override("font_shadow_color",Color.BLACK)
	heading.add_theme_constant_override("shadow_offset_x",1)
	heading.add_theme_constant_override("shadow_offset_y",2)
	heading.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_safe.add_child(heading)
	_status.add_theme_font_size_override("font_size",15)
	_status.add_theme_color_override("font_shadow_color",Color.BLACK)
	_status.add_theme_constant_override("shadow_offset_x",1)
	_status.add_theme_constant_override("shadow_offset_y",2)
	_status.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_safe.add_child(_status)
	_toolbar = HBoxContainer.new()
	_toolbar.add_theme_constant_override("separation",8)
	if campaign == null:
		_toolbar.add_child(_button("Stadt",func(): teleport(State.SPAWN)))
		_toolbar.add_child(_button("Modelle",func(): teleport(CATALOG_ORIGIN+Vector3(0,0.92,12))))
		_toolbar.add_child(_button("Übung",func(): teleport(Vector3(0,0.92,-5.8))))
	else:
		_toolbar.add_child(_button("Zurück ins Dorf", _request_leave))
		_wait_button = _button("1 Std. warten", _wait_at_market)
		_toolbar.add_child(_wait_button)
	_toolbar.add_child(_button("Pause",func(): set_paused(not paused)))
	_safe.add_child(_toolbar)
	_trade_bar = HBoxContainer.new()
	_trade_bar.add_theme_constant_override("separation",8)
	_trade_button = _button("Handel",_interact)
	_bag_button = _button("Beutel",func(): _open_market(true))
	_trade_button.disabled = true
	_bag_button.disabled = true
	_trade_bar.add_child(_trade_button)
	_trade_bar.add_child(_bag_button)
	add_child(street_chart)
	_trade_bar.add_child(_button("Stadtplan",func():
		if market.available:
			street_chart.open_chart(player,market.sites,living_city.life.streets if living_city != null else null)))
	_safe.add_child(_trade_bar)
	_pad = TouchPad.new()
	_pad.axis_changed.connect(func(axis: Vector2): _touch_move=axis)
	_safe.add_child(_pad)
	_actions = HBoxContainer.new()
	_actions.add_theme_constant_override("separation",8)
	_pace = _button("Gehen",_toggle_pace)
	_actions.add_child(_pace)
	_actions.add_child(_button("Übungshieb",func(): perform_action("attack")))
	_actions.add_child(_button("Deckung",func(): perform_action("block")))
	_safe.add_child(_actions)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.06,0.08,0.08,0.96)
	style.set_content_margin_all(22)
	style.border_color = Color("b89862")
	style.set_border_width_all(1)
	_pause_panel.add_theme_stylebox_override("panel",style)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation",12)
	var description := Label.new()
	description.text = "Freie Testrunde\n\nWASD / linker Stick: bewegen\nShift / Gehen: Tempo wechseln\nRechte Maustaste / Wischen: umsehen\nLeertaste: Hieb · Q: Abwehr\n\nDiese Stadt startet keine Mission."
	description.add_theme_font_size_override("font_size",17)
	if campaign != null:
		description.text = "Stadtmarkt\n\nDein Beutel gehört zur laufenden Kampagne. Gehe zu einem Händler, um seinen Stand zu öffnen."
	column.add_child(description)
	column.add_child(_button("Weiter erkunden",func(): set_paused(false)))
	if campaign == null:
		if is_instance_valid(get_node_or_null("FlavianAmphitheatre")):
			var monument_button := _button("Zum Kolosseum", func():
				if go_to_colosseum():
					set_paused(false))
			monument_button.name = "GoToColosseum"
			column.add_child(monument_button)
		column.add_child(_button("Neues Leben · Geschichte beginnen",_request_story))
	column.add_child(_button("Zurück ins Dorf" if campaign != null else "Zum Hauptmenü",_request_leave))
	_pause_panel.add_child(column)
	_safe.add_child(_pause_panel)
	_pause_panel.hide()
	_tablet_dialog.title = "Wachstafel am Tresen"
	_tablet_dialog.dialog_autowrap = true
	_tablet_dialog.dialog_text = "Heute bei Sonnenaufgang geliefert\n\nDrei Krüge Öl. Zwei Säcke Mehl.\nDer kleinere Krug hat einen Sprung. Stell ihn beiseite, bis Livia ihn gesehen hat."
	_tablet_dialog.ok_button_text = "Schließen"
	add_child(_tablet_dialog)

func _button(caption: String,callback: Callable) -> Button:
	var button := TouchAction.new()
	button.text = caption
	button.custom_minimum_size = Vector2(104,56)
	button.add_theme_font_size_override("font_size",18)
	button.focus_mode = Control.FOCUS_NONE
	button.pressed.connect(callback)
	return button

func _layout_ui() -> void:
	var safe := SafeArea.for_viewport(get_viewport())
	_safe.position = safe.position+Vector2(12,12)
	_safe.size = safe.size-Vector2(24,24)
	var portrait := _safe.size.x<760
	_safe.get_node("Heading").position = Vector2(2,0)
	_safe.get_node("Heading").add_theme_font_size_override("font_size",16 if portrait else 21)
	_status.position = Vector2(2,31)
	_status.size = Vector2(_safe.size.x-8,54)
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_toolbar.position = Vector2(0,90 if portrait else 71)
	_trade_bar.position = Vector2(0,152 if portrait else 133)
	_pad.size = Vector2(178,178)
	_pad.position = Vector2(0,_safe.size.y-182)
	_actions.position = Vector2(maxf(0,_safe.size.x-328),_safe.size.y-(250 if portrait else 82))
	_pause_panel.size = Vector2(minf(460,_safe.size.x),minf(430,_safe.size.y-16))
	_pause_panel.position = (_safe.size-_pause_panel.size)*0.5

func _physics_process(delta: float) -> void:
	if paused or market.is_open() or _tablet_dialog.visible:
		return
	_crowd_elapsed += delta
	if campaign == null and _crowd_elapsed >= 0.2:
		_crowd_elapsed = 0.0
		crowd.tick(player.position)
	_action_left = maxf(0,_action_left-delta)
	var combat_event: Dictionary = training.tick(delta)
	var combat_state: Dictionary = training.state()
	if bool(combat_event.get("practice",false)):
		_catalog_status = "Kontrollierter Treffer am Übungspfahl: %d" % int(combat_state.get("practice_hits",0))
		_update_status()
	if not str(combat_state.get("technique","")).is_empty():
		figure.sample_combat(str(combat_state.technique),float(combat_state.progress))
	elif figure.clip == "jab_right":
		figure.cancel_action()
	var axis := _touch_move
	axis.x += float(Input.is_physical_key_pressed(KEY_D) or Input.is_physical_key_pressed(KEY_RIGHT))-float(Input.is_physical_key_pressed(KEY_A) or Input.is_physical_key_pressed(KEY_LEFT))
	axis.y += float(Input.is_physical_key_pressed(KEY_S) or Input.is_physical_key_pressed(KEY_DOWN))-float(Input.is_physical_key_pressed(KEY_W) or Input.is_physical_key_pressed(KEY_UP))
	axis = axis.limit_length(1)
	var direction := Vector3(axis.x,0,axis.y).rotated(Vector3.UP,_yaw)
	var running := _running or Input.is_physical_key_pressed(KEY_SHIFT)
	if riding_trial != null and riding_trial.advance(delta, axis, _yaw, running):
		if is_instance_valid(street_watch):
			street_watch.tick(delta)
		_place_camera(delta)
		return
	var speed := RUN_SPEED if running else WALK_SPEED
	var previous_yaw := figure.rotation.y
	if direction.length_squared()>0.01 and _action_left<=0:
		figure.rotation.y = rotate_toward(figure.rotation.y,atan2(-direction.x,-direction.z),delta*4.5)
		var alignment := maxf(0,Vector3.FORWARD.rotated(Vector3.UP,figure.rotation.y).dot(direction))
		speed *= lerpf(0.3,1,alignment)
	var desired := direction*speed if _action_left<=0 else Vector3.ZERO
	# Constant-magnitude horizontal acceleration avoids faster diagonal starts.
	# Combat input decelerates through the same physics path instead of hard
	# resetting both axes, which used to cause an abrupt foot-plant snap.
	var planar := Vector3(player.velocity.x,0.0,player.velocity.z)
	var accelerating := desired.length_squared() > 0.0001 and planar.dot(desired) >= 0.0
	var acceleration := (RUN_ACCELERATION if running else WALK_ACCELERATION) if accelerating else BRAKING_DECELERATION
	planar = planar.move_toward(desired,maxf(delta,0.0)*acceleration)
	player.velocity.x = planar.x
	player.velocity.z = planar.z
	player.velocity.y = -0.3 if player.is_on_floor() else player.velocity.y-19.6*delta
	var previous_position := player.position
	var horizontal_motion := Vector3(player.velocity.x,0,player.velocity.z)*delta
	if not _step_up(horizontal_motion):
		player.move_and_slide()
	player.position.x = clampf(player.position.x,-State.LIMIT+1,State.LIMIT-1)
	player.position.z = clampf(player.position.z,-State.LIMIT+1,State.LIMIT-1)
	if player.position.y < -8:
		teleport(State.SPAWN)
	if campaign != null and market.available:
		party_visit.advance(self, player, campaign.data, delta)
	if is_instance_valid(street_watch):
		street_watch.tick(delta)
	var actual := (player.position-previous_position)/maxf(delta,0.000001)
	figure.drive(Vector2(actual.x,actual.z).length(),angle_difference(previous_yaw,figure.rotation.y)/maxf(delta,0.000001))
	# The collider bottom is the nominal walking plane. Check the actual
	# authored ground below the player, but never pull a falling actor down.
	figure.youth_ground_floor_y=INF
	if player.is_on_floor() or absf(player.velocity.y)<.001:
		var nominal := player.global_position.y-SOLE_OFFSET
		var query := PhysicsRayQueryParameters3D.create(player.global_position,player.global_position+Vector3.DOWN*1.2,1,[player.get_rid()])
		var floor_hit := get_world_3d().direct_space_state.intersect_ray(query)
		if not floor_hit.is_empty() and (floor_hit.normal as Vector3).y>=cos(player.floor_max_angle) and absf(float(floor_hit.position.y)-nominal)<.15:
			figure.youth_ground_floor_y=float(floor_hit.position.y)
		else:
			figure.youth_ground_floor_y=nominal
	_place_camera(delta)

func _step_up(motion: Vector3) -> bool:
	if not player.is_on_floor() or motion.length_squared()<0.0000001:
		return false
	var start := player.global_transform
	if not player.test_move(start,motion):
		return false
	if player.test_move(start,Vector3.UP*MAX_STEP):
		return false
	var elevated := start
	elevated.origin += Vector3.UP*MAX_STEP
	if player.test_move(elevated,motion):
		return false
	elevated.origin += motion
	var landing := KinematicCollision3D.new()
	if not player.test_move(elevated,Vector3.DOWN*(MAX_STEP+0.03),landing,player.safe_margin):
		return false
	var destination := elevated.origin+landing.get_travel()
	var rise := destination.y-start.origin.y
	if rise<0.003 or rise>MAX_STEP or landing.get_normal().y<=0.01:
		return false
	var probe := landing.get_position()+motion.normalized()*0.04+Vector3.UP*0.06
	var query := PhysicsRayQueryParameters3D.create(probe,probe+Vector3.DOWN*0.12,1,[player.get_rid()])
	var floor := get_world_3d().direct_space_state.intersect_ray(query)
	if floor.is_empty() or (floor.normal as Vector3).dot(Vector3.UP)<cos(player.floor_max_angle):
		return false
	var tread_rise := float(floor.position.y)-(start.origin.y-SOLE_OFFSET)
	if tread_rise>MAX_STEP+player.safe_margin:
		return false
	player.global_position = destination
	player.velocity.y = 0
	return true

## The QA owner supplies calendar instants, never a second autonomous clock.
## The ordinary free-walk mode and campaign saves remain unaffected.
func set_living_city_clock(clock: Dictionary) -> bool:
	if living_city == null or not Calendar.validate_clock(clock):
		return false
	var result := living_city.sync_to(clock)
	if not bool(result.get("ok", false)):
		return false
	_living_city_clock = clock.duplicate(true)
	return true

func _process(delta: float) -> void:
	if campaign != null and living_city != null and not paused:
		if not market.is_open() and not _tablet_dialog.visible:
			_visit_elapsed += delta
			var seconds := floori(_visit_elapsed)
			if seconds > 0:
				_visit_elapsed -= seconds
				var moved: Dictionary = campaign.advance_city_visit(seconds)
				if not moved.ok:
					_market_message(str(moved.message))
					set_paused(true)
		var sync: Dictionary = market.sync_campaign()
		_wait_button.disabled = not bool(sync.get("done", false))
		_update_market_daylight()
		_update_bakery()
	elif living_city != null and not paused and not market.is_open() and not bool(living_city.last_sync.get("done", false)):
		living_city.sync_to(_living_city_clock)
	_catalog_elapsed += delta
	if _catalog_elapsed>=0.15:
		_catalog_elapsed = 0
		if campaign == null:
			_stream_catalog()
		_refresh_market_buttons()
		_update_street_caption()
	if paused or market.is_open():
		return
	_save_elapsed += delta
	if _save_elapsed>=30:
		_save_elapsed = 0
		save_state()

func _update_bakery() -> void:
	if is_instance_valid(_bakery):
		_bakery.set_stock(int(living_city.life.state.businesses[_bakery_business].stock.bread))


func _wait_at_market() -> void:
	if campaign == null or living_city == null or paused or market.is_open() or _tablet_dialog.visible:
		return
	if not bool(living_city.last_sync.get("done", false)):
		return
	var result: Dictionary = campaign.advance_city_visit(3600)
	if result.ok:
		_wait_button.disabled = true
		market.sync_campaign()
		_update_market_daylight()
	else:
		_market_message(str(result.message))


func _update_market_daylight() -> void:
	var clock: Dictionary = campaign.data.calendar.clock
	var minute := int(clock.jdn) * 1440 + floori(float(clock.second) / 60.0)
	if minute == _solar_minute:
		return
	_solar_minute = minute
	Daylight.apply_solar_time(float(clock.second) / 3600.0, Calendar.season_index(clock.jdn),
		_market_sun, camera.environment, null)
	_safe.get_node("Heading").text = "STADTMARKT · %s · %02d:%02d" % [
		Calendar.format_date(clock.jdn), floori(float(clock.second) / 3600.0), minute % 60]


func _place_camera(delta: float) -> void:
	var anchor := player.position+Vector3(0,0.4,0)
	var wanted := anchor+Vector3(0,0,_distance).rotated(Vector3.RIGHT,_pitch).rotated(Vector3.UP,_yaw)
	var exclusions: Array[RID] = [player.get_rid()]
	if riding_trial != null:
		exclusions = riding_trial.controller.camera_exclusions()
	var placed := _camera_solver.place(get_world_3d().direct_space_state,anchor,wanted,_camera_previous,1-exp(-12*delta),exclusions)
	if placed.is_finite():
		camera.position = placed
		_camera_previous = placed
		if camera.position.distance_squared_to(anchor)>0.001:
			camera.look_at(anchor,Vector3.UP)

func _unhandled_input(event: InputEvent) -> void:
	if market.is_open():
		if event.is_action_pressed("ui_cancel"):
			market.close()
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("ui_cancel"):
		set_paused(not paused)
		get_viewport().set_input_as_handled()
		return
	if paused:
		return
	if event is InputEventMouseMotion and Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT):
		_look_by(event.relative)
		get_viewport().set_input_as_handled()
	elif event is InputEventKey and event.pressed and not event.echo:
		if event.physical_keycode==KEY_E:
			_interact()
			get_viewport().set_input_as_handled()
		elif event.physical_keycode==KEY_I:
			_open_market(true)
			get_viewport().set_input_as_handled()
		elif event.physical_keycode==KEY_SPACE:
			perform_action("attack")
			get_viewport().set_input_as_handled()
		elif event.physical_keycode==KEY_Q:
			perform_action("block")
			get_viewport().set_input_as_handled()

func _look_by(delta: Vector2) -> void:
	if not paused:
		_yaw = wrapf(_yaw-delta.x*0.004,-PI,PI)
		_pitch = clampf(_pitch-delta.y*0.003,-0.75,0.65)

func _market_message(value: String) -> void:
	_catalog_status = value
	_update_status()

func _update_street_caption() -> void:
	if not is_instance_valid(quarter):
		return
	var caption := quarter.street_at(player.global_position)
	if caption != _street_caption:
		_street_caption = caption
		_update_status()

func _refresh_market_buttons() -> void:
	if not is_instance_valid(_trade_button):
		return
	var riding_action := riding_trial.controller.interaction_label() if riding_trial != null else ""
	_bag_button.disabled = not market.available or _horse_mounted()
	if not riding_action.is_empty():
		_trade_button.disabled = false
		_trade_button.text = riding_action
		_trade_button.tooltip_text = "Reitprüfung"
		return
	if _tablet_is_near():
		_trade_button.disabled = false
		_trade_button.text = "Tafel lesen"
		_trade_button.tooltip_text = "Wachstafel am Tresen"
		return
	var target := market.nearest()
	_trade_button.disabled = not market.available or not bool(target.reachable)
	_trade_button.text = "Handel" if not target.reachable else ("Pferdehandel" if target.id == "equarius" else "Kaufen")
	_trade_button.tooltip_text = str(target.label) if target.reachable else "Gehe zu einem Marktstand"

func _tablet_is_near() -> bool:
	return is_instance_valid(quarter) and quarter.tablet_reachable(player)

func _interact() -> void:
	if paused or market.is_open() or _tablet_dialog.visible:
		return
	if riding_trial != null and _action_left <= 0.0 and riding_trial.controller.request_interact():
		return
	if _tablet_is_near():
		if is_instance_valid(street_watch):
			street_watch.suspend()
		_touch_move = Vector2.ZERO
		_pad.reset()
		_look.reset()
		player.velocity = Vector3.ZERO
		figure.drive(0)
		var width := mini(420, int(get_viewport().get_visible_rect().size.x) - 36)
		_tablet_dialog.popup_centered(Vector2i(width, 210))
	else:
		_open_market(false)

func _open_market(inventory: bool) -> void:
	party_visit.pause()
	if paused or _action_left > 0 or market.is_open() or _horse_mounted():
		return
	var opened: bool = market.open_inventory() if inventory else market.open_shop()
	if not opened:
		return
	_touch_move = Vector2.ZERO
	_pad.reset()
	_look.reset()
	player.velocity = Vector3.ZERO
	figure.drive(0)
	crowd.set_paused(true)
	if resident_view:
		resident_view.process_mode = Node.PROCESS_MODE_DISABLED
	if is_instance_valid(ambient_people):
		ambient_people.set_active(false)
	var display := get_node_or_null("/root/RuntimeDisplay")
	if is_instance_valid(display):
		display.set_sustained_paused(true)
	_hud.hide()

func _close_market() -> void:
	_hud.show()
	var display := get_node_or_null("/root/RuntimeDisplay")
	if is_instance_valid(display):
		display.set_sustained_paused(paused)
	crowd.set_paused(paused)
	if resident_view:
		resident_view.process_mode = Node.PROCESS_MODE_DISABLED if paused else Node.PROCESS_MODE_INHERIT
	if is_instance_valid(ambient_people):
		ambient_people.set_active(not paused)

func _toggle_pace() -> void:
	_running = not _running
	_update_pace_caption()

func _update_pace_caption() -> void:
	_pace.text = ("Schneller" if _running else "Schritt") if _horse_mounted() else ("Rennen" if _running else "Gehen")

func _horse_mounted() -> bool:
	return riding_trial != null and riding_trial.controller.is_mounted()

func _start_riding_trial() -> void:
	if quarter == null or not quarter.has_node("StableYard"):
		_market_message("Die Reitprüfung benötigt den Stallhof.")
		return
	var trial := RidingTrial.new()
	add_child(trial)
	var stable := quarter.get_node("StableYard") as Node3D
	var horse_at := stable.to_global(Vector3(0.0, 0.002, -2.20))
	if not trial.install(player, figure, horse_at, stable.global_rotation.y + PI):
		trial.queue_free()
		_market_message("Die Reitprüfung benötigt das animierte Pferdemodell.")
		return
	riding_trial = trial
	riding_trial.feedback.connect(_market_message)
	riding_trial.controller.state_changed.connect(func(_mounted: bool) -> void: _update_pace_caption())
	teleport(stable.to_global(Vector3(-1.11, SOLE_OFFSET + 0.023, -2.20)))
	_market_message("Reitprüfung · Aufsteigen mit E oder der Aktionstaste")

func perform_action(action: String) -> void:
	if paused or market.is_open() or _horse_mounted() or _action_left>0 or action not in ["attack","block"]:
		return
	var response: Dictionary = training.execute_attack(player.position,figure.rotation.y) if action == "attack" else training.execute_block()
	if not bool(response.get("ok",false)):
		_catalog_status = str(response.get("message","Kampfübung nicht verfügbar."))
		_update_status()
		return
	# Authoritative action, stamina and hit windows are evaluated inside
	# CityTraining, not from a cosmetic button or frame-rate-based timer.
	# Preserve measured velocity: the physics solver brakes over time.
	if action == "attack":
		figure.sample_combat("jab_right",0.0)
		_action_left = float(CombatActions.TECHNIQUES["jab_right"].duration)
	else:
		figure.cue("block")
		_action_left = float(training.state().get("guard_remaining",0.85))
	_catalog_status = str(response.get("message",""))
	_update_status()

func set_paused(value: bool) -> void:
	if value and is_instance_valid(street_watch):
		street_watch.suspend()
	if value:
		party_visit.pause()
	if market.is_open():
		market.close()
		if not value:
			return
	paused = value
	var quality_monitor := get_node_or_null("/root/RuntimeDisplay")
	if is_instance_valid(quality_monitor):
		quality_monitor.set_sustained_paused(paused)
	_touch_move = Vector2.ZERO
	_pad.reset()
	_look.reset()
	player.velocity = Vector3.ZERO
	figure.drive(0)
	if riding_trial != null:
		riding_trial.controller.clear_pending()
		riding_trial.animation.active = not paused
	figure.set_process(not paused and not _horse_mounted())
	crowd.set_paused(paused)
	if resident_view:
		resident_view.process_mode = Node.PROCESS_MODE_DISABLED if paused else Node.PROCESS_MODE_INHERIT
	if is_instance_valid(ambient_people):
		ambient_people.set_active(not paused)
	_pause_panel.visible = paused
	_pad.visible = not paused
	_look.visible = not paused
	_actions.visible = not paused
	_toolbar.visible = not paused
	_trade_bar.visible = not paused
	if paused:
		save_state()

## The processional entrance is an authored open route (bay 40); the same
## bay geometry is exercised by colosseum_walkthrough_test.gd.
func go_to_colosseum() -> bool:
	if campaign != null or _horse_mounted():
		return false
	var monument := get_node_or_null("FlavianAmphitheatre") as Node3D
	if not is_instance_valid(monument) or monument.get("layout").is_empty():
		return false
	var layout: Dictionary = monument.get("layout")
	var entrance := monument.to_global(FlavianAmphitheatre.bay_point(layout, 40, 0.5, -6.0, SOLE_OFFSET + 0.02))
	var inward := monument.to_global(FlavianAmphitheatre.bay_point(layout, 40, 0.5, 1.3)) - entrance
	teleport(entrance)
	_yaw = atan2(-inward.x, -inward.z)
	figure.rotation.y = _yaw
	_pitch = -0.18
	_place_camera(0.0)
	return true

func teleport(point: Vector3) -> void:
	if not point.is_finite():
		return
	if _horse_mounted():
		_market_message("Steig vor dem Ortswechsel ab.")
		return
	player.position = point
	player.velocity = Vector3.ZERO
	figure.youth_ground_floor_y=INF
	figure.reset_motion()
	_action_left = 0
	_camera_previous = Vector3.INF
	_camera_solver.reset()

func snapshot() -> Dictionary:
	return {"position":player.position,"heading":figure.rotation.y,"yaw":_yaw,"pitch":_pitch,"distance":_distance,"running":_running}

func _restore(state: Dictionary) -> void:
	teleport(state.position)
	figure.rotation.y = state.heading
	_yaw = state.yaw
	_pitch = state.pitch
	_distance = state.distance
	_running = state.running
	_pace.text = "Rennen" if _running else "Gehen"

func save_state() -> Error:
	if campaign != null:
		if living_city == null:
			return OK # Entry failed before a campaign market was attached.
		var result: Dictionary = market.checkpoint_campaign()
		if not result.ok:
			_market_message(str(result.message))
			return ERR_CANT_CREATE
		return OK
	if not persist:
		return OK
	var error := State.write(snapshot(),save_path)
	if error!=OK:
		_catalog_status = "Die Position konnte nicht gespeichert werden."
		_update_status()
	return error

func _request_leave() -> void:
	if save_state()==OK:
		leave_requested.emit()

func _request_story() -> void:
	# Return through the menu's existing new-game confirmation. Never
	# overwrite a campaign save just because a sandbox button was pressed.
	if save_state()==OK:
		story_requested.emit()

func _update_status() -> void:
	var description := "Stadt · Modellpark · Gehen · Rennen · unbewaffnetes Übungstraining"
	if campaign != null:
		description = "Marktviertel · Gehe an einen Stand, um zu handeln."
	if not _street_caption.is_empty():
		description = _street_caption
	if street_watch != null and campaign != null:
		var standing := WatchPatrol.Watch.reputation(campaign.data)
		if standing != 0:
			description += " · Ansehen bei der Marktwache %d" % standing
	if not training.available:
		description += " · Trainingspfahl nicht verfügbar"
	if not city_available:
		description = "Stadtmodell ist noch nicht importiert."
	elif use_flavian_kit and not is_instance_valid(get_node_or_null("FlavianAmphitheatre")):
		description = "Kolosseum fehlt in dieser Stadtfassung."
	elif not youth_available and (campaign == null or (int(campaign.data.player.age) in range(12,18) and campaign.data.origin_id == "italia")):
		description += " · ORIGINAL-MESHY-JUNGE FEHLT: Ersatzmodell aktiv"
	if not _catalog_status.is_empty():
		description += "\n"+_catalog_status
	_status.text = description

func _exit_tree() -> void:
	var renderer := get_node_or_null("/root/RuntimeDisplay")
	if is_instance_valid(renderer):
		renderer.set_sustained_scene(false)
	if not _catalog_pending.is_empty():
		var path := _catalog_pending
		_catalog_pending = ""
		ResourceLoader.load_threaded_get(path)

static func _box_collision(parent: Node3D,size: Vector3,at: Vector3) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.collision_layer = 1
	body.collision_mask = 0
	body.position = at
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	body.add_child(shape)
	parent.add_child(body)
	return body

static func _box_visual(parent: Node3D,size: Vector3,at: Vector3,color: Color) -> void:
	var mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	mesh.mesh = box
	mesh.position = at
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.85
	mesh.material_override = material
	parent.add_child(mesh)

static func _bounds(model: Node3D) -> AABB:
	var result := AABB()
	var found := false
	for mesh: MeshInstance3D in model.find_children("*","MeshInstance3D",true,false):
		if mesh.mesh==null:
			continue
		var transform := model.global_transform.affine_inverse()*mesh.global_transform
		var box: AABB = transform*mesh.get_aabb()
		result = result.merge(box) if found else box
		found = true
	return result
