extends Node3D
## Asset workshop attached through a separate scene. It has no WorldModel or save access.
signal return_requested
const Controller = preload("res://scripts/world_expansion/environment_controller.gd")
const Library = preload("res://scripts/world_expansion/asset_library.gd")
const Layout = preload("res://scripts/world_expansion/settlement_layout.gd")
const View = preload("res://scripts/world_expansion/settlement_view.gd")
const Atlas = preload("res://scripts/world_expansion/atlas.gd")
const MANIFEST_PATH := "res://assets/world_expansion/manifest.json"
const PROFILE_IDS := ["low", "balanced", "high", "very_high"]
var manifest: Dictionary = {}
var load_error := ""
var controller: Node3D
var settlement: Node3D
var camera: Camera3D
var library: RefCounted
var atlas: Control
var selected_settlement := "village"
var selected_region := ""
var view_mode := 0
var _target := Vector3(0, 2, 0)
var _distance := 80.0
var _yaw := 35.0
var _pitch := 30.0
var _ground: MeshInstance3D
var _time_slider: HSlider
var _wind_slider: HSlider
var _settlement_choice: OptionButton
var _view_choice: OptionButton
var _status: Label
var _panel: PanelContainer
var _ui_time := 0.0
var _hud: CanvasLayer


func _ready() -> void:
	name = "WorldWorkshop"
	controller = Controller.new()
	controller.name = "Atmosphere"
	add_child(controller)
	camera = Camera3D.new()
	camera.name = "WorkshopCamera"
	camera.current = true
	camera.near = 0.12
	camera.far = 12000.0
	camera.fov = 55.0
	add_child(camera)
	settlement = View.new()
	settlement.name = "SettlementBatches"
	settlement.camera = camera
	add_child(settlement)
	_update_camera()
	_build_controls()
	if not FileAccess.file_exists(MANIFEST_PATH):
		_fail("Das Weltpaket fehlt.")
		return
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(MANIFEST_PATH))
	if not parsed is Dictionary:
		_fail("Das Weltpaket konnte nicht gelesen werden.")
		return
	manifest = parsed
	atlas.configure(manifest)
	for config: Dictionary in manifest.get("settlements", []):
		_settlement_choice.add_item(str(config.get("label", config.get("id", "Siedlung"))))
	library = Library.new()
	if not library.load_manifest_assets(manifest):
		_fail("\n".join(library.errors))
		return
	for material: ShaderMaterial in library.wind_materials:
		controller.bind_material(material)
	select_settlement(selected_settlement)


func _fail(message: String) -> void:
	load_error = message
	_status.text = message
	_status.add_theme_color_override("font_color", Color("#ffc6a5"))


func select_settlement(id: String, region_id: String = "") -> bool:
	if library == null or library.assets.is_empty():
		return false
	var config := {}
	var selection_index := -1
	var configs: Array = manifest.get("settlements", [])
	for index in configs.size():
		if str(configs[index].get("id", "")) == id:
			config = configs[index].duplicate(true)
			selection_index = index
			break
	if config.is_empty():
		_fail("Diese Siedlung ist nicht im Weltpaket enthalten.")
		return false
	if not region_id.is_empty():
		for region: Dictionary in manifest.get("regions", []):
			if str(region.get("id", "")) == region_id:
				config.seed = int(config.get("seed", 0)) + region_id.hash()
				config.label = str(region.get("label", config.get("label", "")))
				break
	var plan: Dictionary = Layout.generate(config, manifest.get("building_assets", []),
		manifest.get("vegetation_assets", []), manifest.get("road_assets", []))
	if not bool(plan.get("ok", false)):
		_fail(str(plan.get("message", "Siedlung konnte nicht angeordnet werden.")))
		return false
	var result: Dictionary = settlement.populate(plan, library)
	if not bool(result.get("ok", false)):
		_fail(str(result.get("message", "")))
		return false
	selected_settlement = id
	selected_region = region_id
	_settlement_choice.select(selection_index)
	_make_ground(plan.extent)
	load_error = ""
	set_view_mode(0)
	_refresh_status()
	return true


func set_view_mode(mode: int) -> void:
	view_mode = clampi(mode, 0, 3)
	if _view_choice != null:
		_view_choice.select(view_mode)
	atlas.visible = view_mode == 3
	settlement.visible = view_mode != 3
	if _ground != null:
		_ground.visible = view_mode != 3
	if settlement.layout.is_empty():
		return
	var extent: Vector2 = settlement.layout.extent
	if view_mode == 1:
		_target = Vector3(0, 0, 0)
		_pitch = 58.0
		_yaw = 22.0
		_distance = maxf(extent.x, extent.y) * 1.3 + 70.0
		settlement.set_overview(true, _distance + extent.length())
	elif view_mode == 2:
		settlement.set_overview(false)
		focus_on_asset("field_elm")
	else:
		settlement.set_overview(false)
		_target = Vector3(0, 3.0, 0)
		_distance = 62.0
		_pitch = 24.0
		_yaw = 34.0
	_update_camera()
	settlement.refresh_all(camera.global_position)


func focus_on_asset(asset_id: String) -> bool:
	if settlement.layout.is_empty():
		return false
	var chosen := {}
	var closest := INF
	for key in ["buildings", "vegetation"]:
		for entry: Dictionary in settlement.layout.get(key, []):
			if str(entry.asset) != asset_id:
				continue
			var distance: float = entry.position.length_squared()
			if distance < closest:
				closest = distance
				chosen = entry
	if chosen.is_empty():
		return false
	var height := float(library.assets[asset_id].definition.get("height", 8.0))
	_target = chosen.position + Vector3(0, height * 0.40, 0)
	_distance = maxf(8.0, height * 1.9)
	_pitch = 12.0
	_yaw = 25.0
	_update_camera()
	settlement.refresh_all(camera.global_position)
	return true


func set_quality(profile: String) -> void:
	settlement.set_quality(profile)
	controller.set_quality(profile)


func _make_ground(extent: Vector2) -> void:
	if _ground != null:
		remove_child(_ground)
		_ground.free()
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var steps := 48
	var dimensions := extent + Vector2(260, 260)
	for row in steps:
		for column in steps:
			var uv := Vector2(float(column) / steps, float(row) / steps)
			var step := Vector2.ONE / float(steps)
			for point: Vector2 in [uv, uv + Vector2(step.x, 0), uv + Vector2(0, step.y),
					uv + Vector2(step.x, 0), uv + step, uv + Vector2(0, step.y)]:
				var position := (point - Vector2.ONE * 0.5) * dimensions
				var outside := maxf(absf(position.x) - extent.x * 0.5 - 20.0, absf(position.y) - extent.y * 0.5 - 20.0)
				var rise := smoothstep(0, 110, outside)
				var height := -0.045 + rise * (11.0 + 7.0 * sin(position.x * 0.015) * cos(position.y * 0.012))
				var tone := 0.5 + 0.5 * sin(position.x * 0.09) * sin(position.y * 0.12)
				surface.set_color(Color("#6d7551").lerp(Color("#85825c"), tone).srgb_to_linear())
				surface.add_vertex(Vector3(position.x, height, position.y))
	surface.generate_normals()
	surface.index()
	var material := StandardMaterial3D.new()
	material.vertex_color_use_as_albedo = true
	material.roughness = 0.96
	_ground = MeshInstance3D.new()
	_ground.name = "WorkshopLandscape"
	_ground.mesh = surface.commit()
	_ground.material_override = material
	add_child(_ground)


func _update_camera() -> void:
	if camera == null:
		return
	var elevation := deg_to_rad(_pitch)
	var azimuth := deg_to_rad(_yaw)
	camera.position = _target + Vector3(sin(azimuth) * cos(elevation), sin(elevation), cos(azimuth) * cos(elevation)) * _distance
	camera.look_at(_target, Vector3.UP)


func _process(delta: float) -> void:
	_ui_time += delta
	if _ui_time < 0.5:
		return
	_ui_time = 0.0
	if _time_slider != null:
		_time_slider.set_value_no_signal(controller.time_of_day)
	_refresh_status()


func _refresh_status() -> void:
	if _status == null or not load_error.is_empty() or settlement.layout.is_empty():
		return
	var report: Dictionary = settlement.report()
	_status.text = "%s\n%d Gebäude · %d Grundmodelle\n%d Gebäude im Distanzbereich\n%02d:%02d Uhr · Wind %.1f" % [
		str(settlement.layout.get("label", "Siedlung")), report.placed_buildings, report.unique_building_modules,
		report.distance_enabled_buildings, int(controller.time_of_day), int(fmod(controller.time_of_day, 1.0) * 60.0), controller.wind_strength]


func _unhandled_input(event: InputEvent) -> void:
	if view_mode == 3:
		return
	if event is InputEventMouseMotion and event.device != InputEvent.DEVICE_ID_EMULATION and Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		_yaw -= event.relative.x * 0.25
		_pitch = clampf(_pitch + event.relative.y * 0.18, 4.0, 84.0)
		_update_camera()
	elif event is InputEventScreenDrag:
		_yaw -= event.relative.x * 0.25
		_pitch = clampf(_pitch + event.relative.y * 0.18, 4.0, 84.0)
		_update_camera()
	elif event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_zoom(0.85)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_zoom(1.15)


func _zoom(factor: float) -> void:
	_distance = clampf(_distance * factor, 5.0, 7000.0)
	_update_camera()


func _build_controls() -> void:
	_hud = CanvasLayer.new()
	_hud.name = "WorkshopControls"
	add_child(_hud)
	var frame := Control.new()
	frame.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hud.add_child(frame)
	_panel = PanelContainer.new()
	_panel.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	_panel.position = Vector2(16, 16)
	_panel.custom_minimum_size = Vector2(290, 0)
	var background := StyleBoxFlat.new()
	background.bg_color = Color(0.075, 0.095, 0.085, 0.94)
	background.set_corner_radius_all(10)
	background.set_content_margin_all(14)
	_panel.add_theme_stylebox_override("panel", background)
	frame.add_child(_panel)
	var controls := VBoxContainer.new()
	controls.add_theme_constant_override("separation", 8)
	_panel.add_child(controls)
	var title := Label.new()
	title.text = "IMPERATHEN · Modulvorschau"
	title.add_theme_font_size_override("font_size", 18)
	controls.add_child(title)
	_settlement_choice = OptionButton.new()
	_settlement_choice.custom_minimum_size.y = 40
	controls.add_child(_settlement_choice)
	_settlement_choice.item_selected.connect(func(index: int) -> void:
		var configs: Array = manifest.get("settlements", [])
		if index < configs.size():
			select_settlement(str(configs[index].id)))
	_view_choice = OptionButton.new()
	for label in ["Straßenansicht", "Siedlungsübersicht", "Vegetation", "Handelsrouten"]:
		_view_choice.add_item(label)
	_view_choice.custom_minimum_size.y = 40
	controls.add_child(_view_choice)
	_view_choice.item_selected.connect(set_view_mode)
	var quality := OptionButton.new()
	for label in ["Leicht", "Ausgewogen", "Hoch", "Sehr hoch"]:
		quality.add_item(label)
	quality.select(1)
	quality.custom_minimum_size.y = 38
	controls.add_child(quality)
	quality.item_selected.connect(func(index: int) -> void: set_quality(PROFILE_IDS[index]))
	_label(controls, "Tageszeit")
	_time_slider = _slider(controls, 0, 23.99, 0.05, 14.0)
	_time_slider.value_changed.connect(func(value: float) -> void: controller.set_time_of_day(value))
	var cycle := CheckButton.new()
	cycle.text = "Tageslauf"
	cycle.custom_minimum_size.y = 38
	controls.add_child(cycle)
	cycle.toggled.connect(func(enabled: bool) -> void: controller.auto_cycle = enabled)
	_label(controls, "Wind")
	_wind_slider = _slider(controls, 0, 2.0, 0.05, 0.6)
	_wind_slider.value_changed.connect(func(value: float) -> void: controller.set_wind(value))
	var buttons := HBoxContainer.new()
	controls.add_child(buttons)
	for item in [["−", 1.18], ["+", 0.82]]:
		var zoom := Button.new()
		zoom.text = item[0]
		zoom.custom_minimum_size = Vector2(50, 38)
		buttons.add_child(zoom)
		zoom.pressed.connect(_zoom.bind(float(item[1])))
	var back := Button.new()
	back.text = "Zurück"
	back.custom_minimum_size = Vector2(100, 38)
	buttons.add_child(back)
	back.pressed.connect(_return)
	_status = Label.new()
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status.custom_minimum_size = Vector2(265, 82)
	_status.add_theme_font_size_override("font_size", 14)
	_status.text = "Weltpaket wird geladen …"
	controls.add_child(_status)
	atlas = Atlas.new()
	atlas.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	atlas.offset_left = 330
	atlas.offset_top = 18
	atlas.offset_right = -18
	atlas.offset_bottom = -18
	frame.add_child(atlas)
	atlas.hide()
	atlas.settlement_selected.connect(func(id: String, region_id: String) -> void: select_settlement(id, region_id))


func _label(parent: Control, text: String) -> void:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 14)
	parent.add_child(label)


func _slider(parent: Control, minimum: float, maximum: float, step: float, initial: float) -> HSlider:
	var slider := HSlider.new()
	slider.min_value = minimum
	slider.max_value = maximum
	slider.step = step
	slider.value = initial
	slider.custom_minimum_size = Vector2(245, 30)
	parent.add_child(slider)
	return slider


func _return() -> void:
	controller.motion_paused = true
	if return_requested.get_connections().is_empty() and ResourceLoader.exists("res://main.tscn"):
		get_tree().change_scene_to_file("res://main.tscn")
	else:
		return_requested.emit()


func set_controls_visible(enabled: bool) -> void:
	_hud.visible = enabled


func diagnostics() -> Dictionary:
	return {"load_error": load_error, "selected_settlement": selected_settlement,
		"selected_region": selected_region, "view_mode": view_mode,
		"environment": controller.snapshot(), "settlement": settlement.report(),
		"atlas": atlas.route_report(), "camera_position": [camera.position.x, camera.position.y, camera.position.z]}
