extends CanvasLayer
## UI owns presentation and preferences; the entry point owns world pause and commands.

signal action_requested(action: String, payload: Dictionary)

const CREAM := Color("eadfc9")
const MUTED := Color("b9b4a7")
const BRONZE := Color("b99563")
const CRIMSON := Color("722b32")
const INK := Color("111a1b")
const SETTINGS_PATH := "user://imperathen_ui.cfg"
const AudioBuses = preload("res://scripts/audio/audio_buses.gd")
const Origins = preload("res://scripts/strategy/origins.gd")
const ORIGIN_IDS := ["italia", "germania", "han", "wa", "vistula"]
const FigureGallery = preload("res://scripts/ui/figure_gallery.gd")
const SafeArea = preload("res://scripts/ui/safe_area.gd")
const GraphicsPolicy = preload("res://scripts/rendering/fold7_quality_policy.gd")
const TouchPadScript := preload("res://scripts/ui/touch_pad.gd")
const TouchActionScript := preload("res://scripts/ui/touch_action.gd")
const TouchLookScript := preload("res://scripts/ui/touch_look.gd")
const TouchModalScript := preload("res://scripts/ui/touch_modal.gd")
const CombatActions := preload("res://scripts/domain/combat_actions.gd")
const VillagePanel = preload("res://scripts/ui/village_life_panel.gd")
const Childhood = preload("res://scripts/story/village_childhood.gd")
const Navigation = preload("res://scripts/ui/village_navigation.gd")
const RomanStyle = preload("res://scripts/ui/roman_style.gd")
const ImperialIntro = preload("res://scripts/ui/imperial_intro.gd")
const Fx = preload("res://scripts/ui/imperial_fx.gd")
const MenuGradeShader = preload("res://shaders/menu_grade.gdshader")
const MENU_MUSIC_DB := -9.0
var _village_tab := "overview"
var _navigation: Control

class Atmosphere extends Control:

	var menu_style: bool = false

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		resized.connect(queue_redraw)

	func _draw() -> void:
		if menu_style:
			# One smooth horizontal gradient (no banding) plus a soft vignette.
			var stops := [0.0, 0.3, 0.62, 1.0]
			var alphas := [0.9, 0.82, 0.38, 0.16]
			for index in range(stops.size() - 1):
				var x0: float = stops[index] * size.x
				var x1: float = stops[index + 1] * size.x
				var a0 := Color(0.035, 0.022, 0.016, alphas[index])
				var a1 := Color(0.035, 0.022, 0.016, alphas[index + 1])
				draw_polygon(PackedVector2Array([Vector2(x0, 0), Vector2(x1, 0), Vector2(x1, size.y), Vector2(x0, size.y)]),
					PackedColorArray([a0, a1, a1, a0]))
			var edge := Color(0.02, 0.012, 0.01, 0.55)
			var clear := Color(0.02, 0.012, 0.01, 0.0)
			var band := size.y * 0.16
			draw_polygon(PackedVector2Array([Vector2(0, 0), Vector2(size.x, 0), Vector2(size.x, band), Vector2(0, band)]),
				PackedColorArray([edge, edge, clear, clear]))
			draw_polygon(PackedVector2Array([Vector2(0, size.y - band), Vector2(size.x, size.y - band), Vector2(size.x, size.y), Vector2(0, size.y)]),
				PackedColorArray([clear, clear, edge, edge]))
			var gold := Color(0.85, 0.68, 0.38, 0.55)
			draw_line(Vector2(24, 21), Vector2(size.x - 24, 21), gold, 1, true)
			draw_line(Vector2(24, 25), Vector2(size.x - 24, 25), Color(gold, 0.3), 1, true)
			draw_line(Vector2(24, size.y - 25), Vector2(size.x - 24, size.y - 25), Color(gold, 0.3), 1, true)
			draw_line(Vector2(24, size.y - 21), Vector2(size.x - 24, size.y - 21), gold, 1, true)
			return
		draw_rect(Rect2(Vector2.ZERO, size), Color(0.025, 0.039, 0.043, 0.86))
		draw_line(Vector2(24, 23), Vector2(size.x - 24, 23), Color(0.72, 0.57, 0.36, 0.52), 1)
		draw_line(Vector2(24, size.y - 23), Vector2(size.x - 24, size.y - 23), Color(0.72, 0.57, 0.36, 0.36), 1)

var origin_id := "italia"
var _root: Control
var _screen: Control
var _toast_panel: PanelContainer
var _toast_label: Label
var _toast_tween: Tween
var _intro_done := false
var _view_state := ""
var _gallery_from := "menu"
var _settings_return := "menu"
var _confirm_return := "menu"
var _can_continue := false
var _state: Dictionary = {}
var _mode := "person"
var _ui_scale := 1.0
var _reduce_motion := false
var _opening_reading := false
var _volume := 0.55
var _sound_player: AudioStreamPlayer
var _music_player: AudioStreamPlayer
var _music_tween: Tween
var _music_volume := 0.7
var _music_wanted := false
var _intro_seen := false
var _always_intro := false
var _intro_node: Control
var _intro_full_pending := false
var _serif: SystemFont
var _ui_theme: Theme
var _hud_labels: Dictionary = {}
var _action_buttons: Dictionary = {}
var _mode_buttons: Dictionary = {}
var _life_panel: PanelContainer
var _chronicle_panel: PanelContainer
var _health_bar: ProgressBar
var _touch_enabled := false
var _compact_layout := false
var _touch_pad: Control
var _touch_actions: Array[Button] = []
var _touch_look: Control
var _touch_menu_layer: Control
var _technique_menu_layer: Control
var _touch_attack_button: Button
var _touch_technique_button: Button
var _pace_button: Button
var _running := false
var _selected_technique := "jab_left"
var _cancel_build_button: Button
var _build_active := false
var _quality := "balanced"
var _diagnostics := false
var _layout_queued := false
var _dialog_data: Dictionary = {}
var _frontier_dialog_data: Dictionary = {}
var _confirm_data: Dictionary = {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 20
	_load_settings()
	_apply_display_settings()
	_setup_theme()
	_root = Control.new()
	_root.name = "Interface"
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.theme = _ui_theme
	add_child(_root)
	_update_safe_area()
	_setup_sound()
	_setup_music()
	_setup_toast()
	get_viewport().size_changed.connect(_viewport_changed)


func _notification(what: int) -> void:
	if what in [NOTIFICATION_APPLICATION_PAUSED, NOTIFICATION_APPLICATION_FOCUS_OUT, NOTIFICATION_WM_WINDOW_FOCUS_OUT]:
		_reset_touch()
	elif what == NOTIFICATION_APPLICATION_RESUMED and is_instance_valid(_root):
		_viewport_changed()


func _exit_tree() -> void:
	_reset_touch()
	if _toast_tween != null and _toast_tween.is_valid():
		_toast_tween.kill()
	if is_instance_valid(_sound_player):
		_sound_player.stop()
		_sound_player.stream = null
	if _music_tween != null and _music_tween.is_valid():
		_music_tween.kill()
	if is_instance_valid(_music_player):
		_music_player.stop()
		_music_player.stream = null


func show_intro() -> void:
	# The complete title sequence plays on the first start, or every time when
	# the player chooses so in the settings; later starts show a short title card.
	# The full sequence carries its own trailer sound; the menu theme follows it.
	_intro_full_pending = (_always_intro or not _intro_seen) and not _reduce_motion
	_open_screen("intro", false)
	_screen.mouse_filter = Control.MOUSE_FILTER_STOP
	_intro_done = false
	_intro_node = ImperialIntro.new()
	_intro_node.name = "ImperialIntro"
	_intro_node.set_quality(_quality)
	_intro_node.audio_db = MENU_MUSIC_DB + 3.0 + linear_to_db(maxf(0.001, _music_volume))
	_screen.add_child(_intro_node)
	_intro_node.finished.connect(_finish_intro)
	_intro_node.play(_always_intro or not _intro_seen, _reduce_motion)
	var area := _content_size()
	var compact := _touch_enabled or area.x < 900
	# Portrait phones see the 1280-wide canvas scaled down; enlarge the button to match.
	var k := clampf(area.x / 560.0, 1.0, 2.4) if area.y > area.x * 1.15 else 1.0
	var skip := _button("Überspringen" if _touch_enabled else "Überspringen  ·  Enter", func(): _finish_intro(), false, 15 if compact else 14)
	skip.name = "IntroSkip"
	RomanStyle.style_button(skip, false, roundi((16 if compact else 15) * k * _ui_scale))
	skip.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	var skip_size := (Vector2(270, 58) if compact else Vector2(250, 48)) * k
	var inset := 30.0 * k
	skip.offset_left = -skip_size.x - inset
	skip.offset_right = -inset
	skip.offset_top = -skip_size.y - inset
	skip.offset_bottom = -inset
	_screen.add_child(skip)
	skip.grab_focus.call_deferred()
	if OS.is_debug_build() and OS.has_feature("android"):
		_log_intro_skip.call_deferred(skip)


func intro_is_full() -> bool:
	return is_instance_valid(_intro_node) and _intro_node.full


func show_menu(can_continue: bool) -> void:
	_can_continue = can_continue
	_open_screen("menu", true, true)
	var area := _content_size()
	var portrait := area.y > area.x * 1.15
	# Portrait phones get a single large column; landscape gets a framed tablet
	# with the title above two columns, so nothing needs scrolling at 1280 x 720.
	var k := clampf(area.x / 560.0, 1.0, 2.4) if portrait else 1.0
	var px := func(value: float) -> int: return roundi(value * k * _ui_scale)
	var button_height: int = px.call(52 if (_touch_enabled or portrait) else 48)
	var stage := _menu_stage(area)
	var margin := _margin(px.call(20), px.call(30), px.call(20), px.call(30))
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_screen.add_child(margin)
	var scroll := ScrollContainer.new()
	scroll.name = "MenuScroll"
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.follow_focus = true
	margin.add_child(scroll)
	var panel_width: float = (area.x - px.call(40)) if portrait else minf(900.0, area.x - 72.0)
	scroll.size_flags_horizontal = Control.SIZE_SHRINK_CENTER if portrait else Control.SIZE_SHRINK_BEGIN
	scroll.custom_minimum_size.x = panel_width
	var holder := _column(0)
	holder.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	holder.size_flags_vertical = Control.SIZE_EXPAND_FILL
	holder.alignment = BoxContainer.ALIGNMENT_CENTER
	scroll.add_child(holder)
	var panel := PanelContainer.new()
	panel.name = "MenuTablet"
	panel.mouse_filter = Control.MOUSE_FILTER_PASS
	panel.custom_minimum_size.x = panel_width
	var frame := RomanStyle.TabletBox.new()
	frame.frame_width = px.call(7)
	frame.content_margin_left = px.call(26)
	frame.content_margin_right = px.call(26)
	frame.content_margin_top = px.call(14)
	frame.content_margin_bottom = px.call(18)
	panel.add_theme_stylebox_override("panel", frame)
	holder.add_child(panel)
	var layout := _column(px.call(6))
	layout.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.add_child(layout)
	var inner_width: float = panel_width - px.call(52)
	# Emblem: legion eagle between two laurel sprays.
	var crest := _row(px.call(4))
	crest.alignment = BoxContainer.ALIGNMENT_CENTER
	crest.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layout.add_child(crest)
	var crest_height: int = px.call(78)
	var laurel_left := RomanStyle.LaurelSpray.new()
	laurel_left.custom_minimum_size = Vector2(crest_height * 1.1, crest_height)
	crest.add_child(laurel_left)
	var aquila := TextureRect.new()
	aquila.name = "MenuAquila"
	aquila.texture = load(RomanStyle.AQUILA_PATH)
	aquila.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	aquila.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	aquila.mouse_filter = Control.MOUSE_FILTER_IGNORE
	aquila.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	aquila.custom_minimum_size = Vector2(crest_height * 1.84, crest_height)
	aquila.material = _menu_metal(0.0, 3.5)
	aquila.resized.connect(func(): (aquila.material as ShaderMaterial).set_shader_parameter("extent", aquila.size))
	crest.add_child(aquila)
	var laurel_right := RomanStyle.LaurelSpray.new()
	laurel_right.mirrored = true
	laurel_right.custom_minimum_size = laurel_left.custom_minimum_size
	crest.add_child(laurel_right)
	var title := Label.new()
	title.name = "MenuTitle"
	title.text = "IMPERATHEN"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var title_size: int = px.call(70)
	var measured := RomanStyle.font(800, 4).get_string_size("IMPERATHEN", HORIZONTAL_ALIGNMENT_LEFT, -1, title_size).x
	if measured > inner_width * 0.96:
		title_size = maxi(26, floori(title_size * inner_width * 0.96 / measured))
	RomanStyle.style_title(title, title_size)
	# Polished gold lettering with a slow glint (static under reduced motion).
	title.material = _menu_metal(1.0, 0.0)
	title.resized.connect(func():
		var metal := title.material as ShaderMaterial
		metal.set_shader_parameter("extent", title.size)
		var cap := title_size * 0.36 / maxf(1.0, title.size.y)
		metal.set_shader_parameter("band", Vector2(0.5 - cap * 1.05, 0.5 + cap * 0.95))
	)
	layout.add_child(title)
	var motto := Label.new()
	motto.name = "MenuMotto"
	motto.text = "VENI · VIDI · VICI"
	motto.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	motto.mouse_filter = Control.MOUSE_FILTER_IGNORE
	RomanStyle.style_caps(motto, px.call(14), RomanStyle.PARCHMENT, px.call(5))
	layout.add_child(motto)
	var meander := RomanStyle.MeanderBand.new()
	meander.custom_minimum_size = Vector2(0, px.call(13))
	layout.add_child(meander)
	var pitch := _label("Dein Anfang ist klein. Was daraus wird, entscheidest du.", 15, MUTED)
	pitch.add_theme_font_size_override("font_size", px.call(15))
	pitch.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	pitch.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	layout.add_child(pitch)
	_spacer(layout, px.call(4))
	var columns: BoxContainer = VBoxContainer.new() if portrait else HBoxContainer.new()
	columns.add_theme_constant_override("separation", px.call(10 if portrait else 22))
	layout.add_child(columns)
	var life := _column(px.call(7))
	life.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	columns.add_child(life)
	var more := _column(px.call(7))
	more.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	columns.add_child(more)
	var font_size: int = px.call(17)
	var continue_button := _roman_button("Fortsetzen", func(): _emit("continue"), true, font_size, button_height)
	continue_button.disabled = not can_continue
	continue_button.tooltip_text = "Deinen gespeicherten Lebensweg fortsetzen." if can_continue else "Es wurde noch kein Spielstand gefunden."
	life.add_child(continue_button)
	_add_origin_picker(life, k)
	var new_button := _roman_button("Neues Leben", _request_new_game, not can_continue, font_size, button_height)
	life.add_child(new_button)
	var demo_button := _roman_button("Talgefecht erproben", func(): _emit("valley_demo"), false, font_size, button_height)
	var city_button := _roman_button("Stadt frei erkunden", func(): _emit("city_exploration"), true, font_size, button_height)
	city_button.name = "FreeCityExploration"
	city_button.tooltip_text = "Eine freie Testrunde durch die Stadt und vorhandene Modelle beginnen."
	more.add_child(city_button)
	more.add_child(demo_button)
	var atlas_button := _roman_button("Weltkugel erkunden", func(): _emit("atlas_demo"), false, font_size, button_height)
	more.add_child(atlas_button)
	var gallery_button := _roman_button("Figuren", func(): _show_gallery("menu"), false, font_size, button_height)
	more.add_child(gallery_button)
	if OS.is_debug_build() and OS.has_feature("android"):
		_log_menu_buttons.call_deferred(demo_button, atlas_button, continue_button, gallery_button, scroll)
		scroll.get_v_scroll_bar().value_changed.connect(func(_value: float):
			_log_gallery_button.call_deferred(gallery_button,scroll)
		)
	more.add_child(_roman_button("Einstellungen", func(): _show_settings("menu"), false, font_size, button_height))
	more.add_child(_roman_button("Spiel beenden", func(): _confirm("Spiel beenden?", "Ein laufender Lebensweg wird vor dem Beenden gespeichert.", "quit", {}), false, font_size, button_height))
	(continue_button if can_continue else new_button).grab_focus.call_deferred()
	var province := _panel(false)
	province.name = "ProvinceNote"
	province.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	province.offset_left = -357
	province.offset_right = -52
	province.offset_top = -150
	province.offset_bottom = -56
	_screen.add_child(province)
	var province_content := _column(5)
	province.add_child(province_content)
	var province_kicker := _label("AN DER GRENZE DES REICHES", 12, BRONZE)
	RomanStyle.style_caps(province_kicker, roundi(12 * _ui_scale), RomanStyle.GOLD, 2)
	province_content.add_child(province_kicker)
	province_content.add_child(_label("Eine Heimat. Eine Entscheidung.", 17, CREAM, true))
	province_content.add_child(_label("Grenzdorf · spielbarer Funktionsprototyp", 12, MUTED))
	province.visible = not portrait and area.x - (panel_width + 40) > 380
	panel.resized.connect(_place_menu_decor.bind(stage, panel, portrait))
	_place_menu_decor.call_deferred(stage, panel, portrait)


## Stage behind the menu tablet: colour grade and vignette over the village,
## light shafts, low fog, embers and (placed once the tablet is laid out)
## legion banners and torches. Density follows the graphics profile.
func _menu_stage(area: Vector2) -> Control:
	var level := Fx.effect_level(_quality)
	var stage := Control.new()
	stage.name = "MenuStage"
	stage.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stage.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_screen.add_child(stage)
	var grade := ColorRect.new()
	grade.name = "MenuGrade"
	grade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	grade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var grade_material := ShaderMaterial.new()
	grade_material.shader = MenuGradeShader
	grade_material.set_shader_parameter("aspect", area.x / maxf(1.0, area.y))
	grade_material.set_shader_parameter("shaft", 0.0 if level == 0 else 1.0)
	grade.material = grade_material
	stage.add_child(grade)
	if level >= 1:
		var fog := Fx.fog(level, Color(0.26, 0.12, 0.08))
		fog.name = "MenuFog"
		fog.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
		fog.offset_top = -area.y * 0.3
		var fog_material := fog.material as ShaderMaterial
		fog_material.set_shader_parameter("density", 0.45)
		fog_material.set_shader_parameter("aspect", area.x / maxf(1.0, area.y * 0.3))
		fog_material.set_shader_parameter("top_fade", 0.7)
		fog_material.set_shader_parameter("speed", 0.0 if _reduce_motion else 0.6)
		stage.add_child(fog)
	if not _reduce_motion:
		var embers := Fx.embers([10, 26, 44][level], 7.0)
		embers.name = "MenuEmbers"
		embers.position = Vector2(area.x * 0.5, area.y + 10)
		embers.emission_rect_extents = Vector2(area.x * 0.55, 8)
		stage.add_child(embers)
	var decor := Control.new()
	decor.name = "MenuDecor"
	decor.mouse_filter = Control.MOUSE_FILTER_IGNORE
	decor.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	stage.add_child(decor)
	return stage


func _menu_metal(ramp: float, offset: float) -> ShaderMaterial:
	var metal := Fx.metal_material(0.9)
	metal.set_shader_parameter("ramp", ramp)
	metal.set_shader_parameter("auto_period", 0.0 if _reduce_motion else 7.0)
	metal.set_shader_parameter("auto_offset", offset)
	return metal


## Banners and torches go where the tablet leaves room: beside it on wide
## screens, above and below it on portrait phones. Nothing overlaps a button.
func _place_menu_decor(stage: Control, panel: Control, portrait: bool) -> void:
	if not is_instance_valid(stage) or not is_instance_valid(panel):
		return
	var decor: Control = stage.get_node_or_null("MenuDecor")
	if decor == null:
		return
	for child in decor.get_children():
		decor.remove_child(child)
		child.queue_free()
	var area := stage.size
	var inverse := stage.get_global_transform().affine_inverse()
	var tablet := Rect2(inverse * panel.get_global_rect().position, panel.get_global_rect().size)
	var level := Fx.effect_level(_quality)
	var spots: Array[Dictionary] = []
	if not portrait:
		var free_left := tablet.end.x + 24.0
		var free_width := area.x - free_left - 24.0
		var count := 2 if free_width >= 460.0 else (1 if free_width >= 200.0 else 0)
		var banner_w := clampf(free_width * (0.22 if count == 2 else 0.4), 90.0, 170.0)
		var banner_h := minf(area.y * 0.5, banner_w * 2.6)
		var torch_y := 34.0 + banner_h * 0.62
		var centres: Array[float] = []
		for index in range(count):
			centres.append(free_left + free_width * (float(index) + 0.5) / count)
			spots.append({"banner": Rect2(centres[index] - banner_w * 0.5, 34.0, banner_w, banner_h)})
		if count > 0:
			# Torches flank the banners; two banners share the middle torch.
			var torches: Array[Vector2] = [Vector2(centres[0] - banner_w * 0.95, torch_y), Vector2(centres[-1] + banner_w * 0.95, torch_y)]
			if count == 2:
				torches.append(Vector2((centres[0] + centres[1]) * 0.5, torch_y))
			spots.append({"torches": torches})
	else:
		var above := tablet.position.y
		var below := area.y - tablet.end.y
		if above >= 90.0:
			var banner_w := clampf(area.x * 0.16, 90.0, 220.0)
			var banner_h := above + tablet.size.y * 0.2
			for fraction in [0.14, 0.86]:
				spots.append({"banner": Rect2(area.x * fraction - banner_w * 0.5, 8.0, banner_w, banner_h), "torches": []})
		if below >= 110.0:
			var torch_y := tablet.end.y + minf(below * 0.62, 190.0)
			spots.append({"torches": [Vector2(area.x * 0.2, torch_y), Vector2(area.x * 0.8, torch_y)]})
	var torch_w := clampf(area.x * (0.036 if portrait else 0.026), 22.0, 46.0)
	var index := 0
	for spot in spots:
		if spot.has("banner"):
			var banner := Fx.Banner.new()
			banner.name = "MenuBanner%d" % index
			banner.phase = index * 1.7
			banner.wind = 0.2 if _reduce_motion else 1.0
			var rect: Rect2 = spot.banner
			banner.position = rect.position
			banner.size = rect.size
			decor.add_child(banner)
		for point: Vector2 in spot.get("torches", []):
			if point.x - torch_w < 0 or point.x + torch_w > area.x:
				continue
			var torch := Fx.Torch.new()
			torch.name = "MenuTorch%d" % index
			torch.level = level
			torch.calm = _reduce_motion
			torch.seed = index * 1.3 + point.x * 0.01
			torch.position = point - Vector2(torch_w * 0.5, 0)
			torch.size = Vector2(torch_w, torch_w)
			decor.add_child(torch)
			index += 1
		index += 1


func _roman_button(text: String, callback: Callable, primary: bool, font_size: int, height: int) -> Button:
	var button := _button(text, callback, primary, font_size)
	RomanStyle.style_button(button, primary, font_size)
	button.remove_meta("base_font_size")
	button.custom_minimum_size.y = height
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return button


func _add_origin_picker(parent: VBoxContainer, k := 1.0) -> void:
	var caption := _label("Herkunft für ein neues Leben", 13, BRONZE)
	RomanStyle.style_caps(caption, roundi(12 * k * _ui_scale), RomanStyle.GOLD, 2)
	caption.remove_meta("base_font_size")
	parent.add_child(caption)
	var picker := OptionButton.new()
	picker.name = "OriginPicker"
	picker.custom_minimum_size.y = roundi(46 * k * _ui_scale)
	picker.add_theme_font_size_override("font_size", roundi(16 * k * _ui_scale))
	for state in ["normal", "hover", "pressed", "focus"]:
		var box := _flat(Color("2a2017") if state != "hover" else Color("3a2c1f"))
		box.border_color = RomanStyle.GOLD if state in ["hover", "focus"] else RomanStyle.GOLD_DEEP
		box.set_border_width_all(1 if state != "focus" else 2)
		box.set_corner_radius_all(2)
		box.content_margin_left = 14
		box.content_margin_right = 14
		if state == "focus":
			box.bg_color = Color(0, 0, 0, 0)
		picker.add_theme_stylebox_override(state, box)
	for id in ORIGIN_IDS:
		picker.add_item(String(Origins.PEOPLES[id].name))
	picker.selected = ORIGIN_IDS.find(origin_id)
	parent.add_child(picker)
	var description := _label(String(Origins.PEOPLES[origin_id].intro), 13, MUTED)
	description.add_theme_font_size_override("font_size", roundi(13 * k * _ui_scale))
	description.remove_meta("base_font_size")
	description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	parent.add_child(description)
	picker.item_selected.connect(func(index: int):
		origin_id = ORIGIN_IDS[index]
		description.text = String(Origins.PEOPLES[origin_id].intro)
	)


func _log_intro_skip(skip: Button) -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	if is_instance_valid(skip) and skip.is_visible_in_tree():
		var point := get_viewport().get_screen_transform() * skip.get_global_rect().get_center()
		print("IMPERATHEN_INTRO_READY " + JSON.stringify({"skip": [point.x, point.y]}))


func _log_gallery_button(button: Button, scroll: ScrollContainer) -> void:
	if not is_instance_valid(button) or not button.is_visible_in_tree() or not is_instance_valid(scroll):
		return
	var center := button.get_global_rect().get_center()
	var point := get_viewport().get_screen_transform() * center
	print("IMPERATHEN_GALLERY_MENU_BUTTON " + JSON.stringify({"center":[point.x,point.y],
		"visible":scroll.get_global_rect().has_point(center)}))


func _log_menu_buttons(demo: Button, atlas: Button, resume: Button, gallery: Button, scroll: ScrollContainer) -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	if not is_instance_valid(demo) or not demo.is_visible_in_tree():
		return
	var transform := get_viewport().get_screen_transform()
	var demo_center := transform * demo.get_global_rect().get_center()
	var resume_center := transform * resume.get_global_rect().get_center()
	var atlas_center := transform * atlas.get_global_rect().get_center()
	var gallery_center := transform * gallery.get_global_rect().get_center()
	print("IMPERATHEN_MENU_TOUCH " + JSON.stringify({
		"demo": [demo_center.x, demo_center.y],
		"atlas": [atlas_center.x, atlas_center.y],
		"gallery": [gallery_center.x, gallery_center.y],
		"gallery_visible": scroll.get_global_rect().has_point(gallery.get_global_rect().get_center()),
		"continue": [resume_center.x, resume_center.y],
		"can_continue": not resume.disabled}))


func show_game(state: Dictionary) -> void:
	_sync_pace_from_state(state)
	_state = state.duplicate(true)
	_state["running"] = _running
	_open_screen("game", false)
	_hud_labels.clear()
	_action_buttons.clear()
	_mode_buttons.clear()
	_build_top_bar()
	_build_objective_card()
	_build_navigation()
	_build_character_card()
	_build_toolbar()
	_build_touch_controls()
	update_state(state)
	set_mode(_mode)
	_emit("touch_camera_managed", {"enabled": _touch_enabled})
	_emit("select_technique", {"technique": _selected_technique})


func show_cinematic() -> void:
	_open_screen("cinematic", false)
	if _toast_tween != null and _toast_tween.is_valid():
		_toast_tween.kill()
	_toast_panel.hide()


func opening_preferences() -> Dictionary:
	return {"ui_scale": _ui_scale, "reduce_motion": _reduce_motion,
		"touch_enabled": _touch_enabled, "manual_reading": _opening_reading}


func set_opening_reading(enabled: bool) -> void:
	_opening_reading = enabled
	_save_settings()


func update_state(state: Dictionary) -> void:
	_sync_pace_from_state(state)
	_state = state.duplicate(true)
	_state["running"] = _running
	if _view_state != "game":
		return
	_update_pace_caption()
	var resources: Dictionary = state.get("resources", {})
	var player: Dictionary = state.get("player", {})
	var progress: Dictionary = state.get("progress", {})
	var companion: Dictionary = state.get("companion", {})
	var squad: Dictionary = state.get("squad", {})
	var encounter: Dictionary = state.get("encounter", {})
	_hud_labels["wood"].text = "%d  Holz" % int(resources.get("wood", 0))
	_hud_labels["grain"].text = "%d  Getreide" % int(resources.get("grain", 0))
	_hud_labels["denarii"].text = "%d  Denare" % int(resources.get("denarii", 0))
	var seconds := maxi(0, int(state.get("world_seconds", 0)))
	_hud_labels["time"].text = "TAG %d  ·  %02d:%02d" % [seconds / 86400 + 1, (seconds / 3600) % 24, (seconds / 60) % 60]
	if state.get("village", {}).get("enabled", false):
		_hud_labels["time"].text = "DORFTAG %d" % int(state.village_economy_view.get("day", 1))
	if Childhood.enabled(state):
		_hud_labels["time"].text = "TAG %d · 12 JAHRE" % int(state.get("childhood_view", Childhood.view(state)).get("day", 1))
	_hud_labels["age"].text = "%d Jahre  ·  %s" % [int(player.get("age", 12)), _career_name(String(progress.get("stage", "prologue")))]
	var health := clampf(float(player.get("health", 100)), 0, 100)
	_health_bar.value = health
	_hud_labels["health"].text = "Lebenskraft   %d / 100" % int(health)
	_hud_labels["companion"].text = "%s · Vertrauen %+d" % [_companion_name(state), int(companion.get("trust", 0))] if bool(companion.get("met", false)) else "%s wartet im Dorf." % _companion_name(state)
	_hud_labels["squad"].text = "Truppe   %d / %d am Leben\nMoral   %d / 100" % [int(squad.get("alive", 0)), int(squad.get("recruits", 0)), int(squad.get("morale", 0))]
	if _hud_labels.has("compact_life"):
		_hud_labels["compact_life"].text = "Leben %d/100  ·  Truppe %d/%d" % [int(health), int(squad.get("alive", 0)), int(squad.get("recruits", 0))]
		if Childhood.enabled(state):
			_hud_labels["compact_life"].text = "Leben %d · Ausdauer %d" % [int(health), int(CombatActions.view(state).get("stamina", 100))]
	var objective := _objective(state)
	_hud_labels["objective_title"].text = objective[0]
	_hud_labels["objective_text"].text = objective[1]
	_update_map_objective()
	var chronicle: Array = state.get("chronicle", [])
	var entries: Array[String] = []
	for index in range(maxi(0, chronicle.size() - 3), chronicle.size()):
		var entry = chronicle[index]
		var line := String(entry.get("text", "")) if entry is Dictionary else str(entry)
		if not line.is_empty():
			entries.append("• " + line)
	_hud_labels["chronicle"].text = "\n\n".join(entries) if not entries.is_empty() else "Deine Geschichte beginnt hier."
	var completed := false
	var unfinished := false
	for building in state.get("buildings", []):
		completed = completed or bool(building.get("completed", false))
		unfinished = unfinished or not bool(building.get("completed", false))
	var trained := bool(progress.get("training_complete", false))
	var ended := bool(progress.get("career_terminal", false)) or String(progress.get("stage", "")) == "fallen"
	_action_buttons["build"].disabled = int(resources.get("wood", 0)) < 8 or ended
	_action_buttons["train"].disabled = not completed or not bool(companion.get("met", false)) or unfinished or trained or ended
	if state.get("village", {}).get("enabled", false) and int(player.get("age", 12)) < 18:
		_action_buttons["train"].disabled = _action_buttons["train"].disabled or not bool(state.get("village_view", {}).get("training_ready", false))
	_action_buttons["recruit"].disabled = not trained or int(squad.get("recruits", 0)) >= 3 or int(resources.get("denarii", 0)) < 5 or int(resources.get("grain", 0)) < 2 or ended
	_action_buttons["skirmish"].disabled = not trained or int(squad.get("alive", 0)) <= 0 or bool(encounter.get("active", false)) or bool(progress.get("skirmish_won", false)) or ended
	if Childhood.enabled(state):
		for key in ["build", "train", "recruit", "skirmish"]:
			_action_buttons[key].hide()
	if bool(encounter.get("active", false)):
		var remaining := 0
		for enemy in encounter.get("enemies", []):
			if float(enemy.get("health", 0)) > 0:
				remaining += 1
		_hud_labels["status"].text = ("ANGRIFF  ·  %d Gegner" if _compact_layout else "VERTEIDIGUNG  ·  %d Gegner") % remaining
	else:
		_hud_labels["status"].text = ("ABSCHLUSS" if ended else "GRENZDORF") if _compact_layout else "GRENZDORF  ·  " + ("ABSCHNITT BEENDET" if ended else "DEIN LEBENSWEG")
	if state.get("village", {}).get("enabled", false):
		var raid: Dictionary = state.village.raid
		if raid.status == "warning":
			_hud_labels["status"].text = "SPUREN VOR DEM DORF · %d s" % ceili(float(raid.remaining))
		elif raid.active:
			_hud_labels["status"].text = "ÜBERFALL · AUSDAUER %d" % int(raid.stamina)
	_update_combat_controls()


func show_pause() -> void:
	_open_screen("pause", true)
	var column := _modal("EIN AUGENBLICK RUHE", "Spiel pausiert", "Die Welt wartet. Dein nächster Schritt gehört dir.", 490)
	var resume_button := _button("Weiterspielen", func(): _emit("resume"), true)
	column.add_child(resume_button)
	column.add_child(_button("Weltkugel", func(): _emit("atlas")))
	var legion := _button("Grenzlegion im Tal", func(): _emit("valley"))
	legion.disabled = not bool(_state.get("progress", {}).get("skirmish_won", false)) or not _state.get("story", {}).get("choices", []).is_empty()
	legion.tooltip_text = "Verteidige zuerst das Dorf und entscheide über seine Zukunft." if legion.disabled else "Befehle die regionale Legion. Deine Dorftruppe bleibt zu Hause."
	column.add_child(legion)
	if legion.disabled:
		var requirement := _label("Nach erfolgreicher Dorfverteidigung und Folgeentscheidung verfügbar.", 13, MUTED)
		requirement.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		column.add_child(requirement)
	column.add_child(_button("Chronik", func(): _show_journal(false)))
	if _state.get("village", {}).get("enabled", false):
		column.add_child(_button("Dorfleben und Wiederaufbau", _emit.bind("village_panel", {})))
	column.add_child(_button("Spiel speichern", func(): _emit("save")))
	column.add_child(_button("Einstellungen", func(): _show_settings("pause")))
	column.add_child(_button("Zum Hauptmenü", func(): _emit("menu")))
	column.add_child(_button("Spiel beenden", func(): _confirm("Spiel beenden?", "Dein aktueller Spielstand wird vor dem Beenden gespeichert.", "quit", {})))
	resume_button.grab_focus.call_deferred()


func show_dialog(title: String, text: String, choices: Array) -> void:
	_dialog_data = {"title": title, "text": text, "choices": choices.duplicate(true)}
	_open_screen("dialog", true)
	var speaker := ""
	var youth: bool = int(_state.get("player",{}).get("age",18)) < 18
	if youth and not _state.get("companion",{}).get("met",false):
		for choice in choices:
			if choice is Dictionary and choice.get("action") == "companion_help":
				speaker = String(FigureGallery.FRIENDS.get(_state.get("origin_id","italia"),""))
				break
	var heading := "Begegnung mit %s" % FigureGallery.caption(speaker).name if speaker != "" else title
	var column := _modal("DEINE ENTSCHEIDUNG", heading, text, 670, speaker)
	column.add_child(_label("Die Welt ist während dieses Gesprächs pausiert.", 12, MUTED))
	_spacer(column, 3)
	var first_button: Button
	for index in range(choices.size()):
		var entry = choices[index]
		var caption: String
		var action := "story_choice"
		var payload: Dictionary = {}
		if entry is Dictionary:
			caption = String(entry.get("label", entry.get("text", "Wählen")))
			action = String(entry.get("action", "story_choice"))
			payload = entry.get("payload", {}).duplicate(true)
			if entry.has("choice") or entry.has("id"):
				payload["choice"] = entry.get("choice", entry.get("id", ""))
		else:
			caption = str(entry)
			payload["choice"] = str(entry)
		var choice_button := _button(caption, _emit.bind(action, payload), index == 0, 17)
		choice_button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		choice_button.tooltip_text = caption
		if entry is Dictionary:
			choice_button.disabled = not bool(entry.get("enabled", true))
			if choice_button.disabled and not str(entry.get("reason", "")).is_empty():
				choice_button.tooltip_text = str(entry.reason)
		column.add_child(choice_button)
		if choice_button.disabled and entry is Dictionary and not str(entry.get("reason", "")).is_empty():
			var reason := _label(str(entry.reason), 13, MUTED)
			reason.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			column.add_child(reason)
		if first_button == null and not choice_button.disabled:
			first_button = choice_button
	if choices.is_empty():
		first_button = _button("Zurück ins Spiel", func(): _emit("resume"), true)
		column.add_child(first_button)
	if first_button != null:
		first_button.grab_focus.call_deferred()


func show_frontier_dialog(dialog: Dictionary) -> void:
	clear_notification()
	_frontier_dialog_data = dialog.duplicate(true)
	_open_screen("frontier_dialog", false)
	_screen.mouse_filter = Control.MOUSE_FILTER_STOP
	var shade := ColorRect.new()
	shade.color = Color(0.025, 0.035, 0.04, 0.20)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_screen.add_child(shade)
	var extent := _content_size()
	var wide := extent.x >= 820 and extent.x >= extent.y * 1.25
	var width := minf(560.0, extent.x * 0.53) if wide else minf(560.0, extent.x - 40.0)
	var margin := _margin(20, 22, 20, 22)
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_screen.add_child(margin)
	var row := _row(0)
	margin.add_child(row)
	var space := Control.new()
	space.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(space)
	var panel := _panel(true)
	panel.name = "FrontierConversation"
	panel.custom_minimum_size.x = width
	panel.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(panel)
	if not wide:
		var right_space := Control.new()
		right_space.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(right_space)
	var scroll := ScrollContainer.new()
	scroll.name = "FrontierConversationScroll"
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.follow_focus = true
	scroll.custom_minimum_size = Vector2(width - 36.0, 0)
	panel.add_child(scroll)
	var column := _column(12)
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.custom_minimum_size.x = width - 48.0
	scroll.add_child(column)
	column.add_child(_label(str(dialog.get("kicker", "DIE STRASSE ZUR LEGION")), 12, BRONZE))
	var heading := _label(str(dialog.get("title", "Ein Gespräch im Dorf")), 28, CREAM, true)
	heading.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(heading)
	var body := _label(str(dialog.get("text", "")), 17, CREAM)
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(body)
	if not str(dialog.get("feedback", "")).is_empty():
		var feedback := _label(str(dialog.feedback), 15, BRONZE)
		feedback.name = "ConversationFeedback"
		feedback.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		column.add_child(feedback)
	_spacer(column, 4)
	var first_button: Button
	for value in dialog.get("choices", []):
		if not value is Dictionary:
			continue
		var entry: Dictionary = value
		var choice_id := str(entry.get("id", ""))
		var payload := {"npc_id": str(dialog.get("npc_id", "")), "choice": choice_id}
		var action := "frontier_choice"
		if entry.has("command"):
			action = "village_command"
			payload = {"command":entry.command, "args":entry.get("payload", {})}
		var available := bool(entry.get("enabled", true))
		var button := _button(str(entry.get("label", "Antworten")), _emit.bind(action, payload), first_button == null and available, 16)
		button.name = "FrontierChoice_" + choice_id
		if entry.has("command"):
			button.set_meta("village_command", str(entry.command))
			button.set_meta("village_args", entry.get("payload", {}).duplicate(true))
		button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		button.custom_minimum_size.y = 52
		button.disabled = not available
		button.tooltip_text = str(entry.get("reason", ""))
		column.add_child(button)
		if available and first_button == null:
			first_button = button
		if not available and not button.tooltip_text.is_empty():
			var reason := _label(button.tooltip_text, 13, MUTED)
			reason.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			column.add_child(reason)
	var close_button := _button("Gespräch beenden", _emit.bind(str(dialog.get("close_action", "frontier_close")), {}), false, 15)
	close_button.name = "FrontierConversationClose"
	column.add_child(close_button)
	var fit := func():
		if is_instance_valid(scroll):
			scroll.custom_minimum_size.y = minf(column.get_combined_minimum_size().y, maxf(100.0, _content_size().y - 100.0))
	column.minimum_size_changed.connect(fit)
	fit.call_deferred()
	(first_button if first_button != null else close_button).grab_focus.call_deferred()


func show_village_dialog(dialog: Dictionary) -> void:
	var content := dialog.duplicate(true)
	content.kicker = "MENSCHEN DEINES DORFES"
	content.close_action = "village_close"
	show_frontier_dialog(content)


func show_village_panel(state: Dictionary, tab := "overview") -> void:
	clear_notification()
	_state = state.duplicate(true)
	VillagePanel.show(self, state, tab)


func update_navigation(value: Dictionary) -> void:
	if _view_state == "game" and is_instance_valid(_navigation):
		_navigation.update_view(value)


func select_combat_technique(id: String) -> void:
	if CombatActions.available(_state, id):
		_selected_technique = id
		_update_combat_controls()


func show_combat_palette(state: Dictionary) -> void:
	if _view_state != "game":
		return
	_state = state.duplicate(true)
	_show_technique_menu()


func clear_notification() -> void:
	if _toast_tween != null and _toast_tween.is_valid():
		_toast_tween.kill()
	if is_instance_valid(_toast_panel):
		_toast_panel.hide()


func notify(message: String) -> void:
	if _toast_panel == null:
		return
	if _toast_tween != null and _toast_tween.is_valid():
		_toast_tween.kill()
	_toast_label.text = message
	_toast_panel.show()
	_toast_panel.modulate.a = 1.0
	_toast_tween = create_tween()
	_toast_tween.tween_interval(clampf(2.5 + message.length() * 0.025, 3.0, 7.0))
	if not _reduce_motion:
		_toast_tween.tween_property(_toast_panel, "modulate:a", 0.0, 0.3)
	_toast_tween.tween_callback(_toast_panel.hide)


func set_mode(mode: String) -> void:
	if mode not in ["person", "city", "map"]:
		return
	if _mode != mode:
		_reset_touch()
	_mode = mode
	if _view_state != "game":
		return
	for key in _mode_buttons:
		var button: Button = _mode_buttons[key]
		button.add_theme_stylebox_override("normal", _button_style(key == mode, false))
	var hints := {
		"person": "WASD bewegen  ·  Rechte Maus drehen  ·  E interagieren  ·  Linksklick / Leertaste kämpfen",
		"city": "B Bauplan öffnen  ·  Linksklick platzieren  ·  Tab zur Figur  ·  Die Figur bleibt an ihrem Ort.",
		"map": "M zurück zur Figur  ·  Strategischer Überblick  ·  Die Fernansicht versetzt deine Figur nicht."
	}
	if _touch_enabled:
		hints = {
			"person": "Links bewegen · Rechts im freien Bild umsehen · Gehen/Laufen umschalten · Technik wählen und schlagen.",
			"city": "Hütte wählen · Freien Bauplatz antippen · Zum Beenden Bau abbrechen wählen.",
			"map": "Im freien Bild ziehen · Figur wählen, um zurückzukehren · Deine Figur bleibt an ihrem Ort."
		}
	_life_panel.visible = not _compact_layout and mode != "person"
	_chronicle_panel.visible = _life_panel.visible
	_hud_labels.compact_life.visible = not _life_panel.visible and not (_touch_enabled and _content_size().y < 520)
	_action_buttons["atlas"].visible = mode == "map"
	_hud_labels["controls"].text = hints[mode]
	var objective := _objective(_state)
	_hud_labels["objective_title"].text = objective[0]
	_hud_labels["objective_text"].text = objective[1]
	_update_map_objective()
	_update_touch_visibility()


func _update_map_objective() -> void:
	if _mode == "map" and not _state.get("valley", {}).is_empty():
		_hud_labels["objective_title"].text = "Regionaler Lagebericht"
		_hud_labels["objective_text"].text = _region_report()


func set_build_active(active: bool) -> void:
	_build_active = active
	_update_touch_visibility()


func set_quality(profile: String) -> void:
	if profile not in ["low", "balanced", "high", "very_high"]:
		return
	_quality = profile
	_apply_display_settings()
	_save_settings()
	_emit("quality_changed", {"profile": _quality})


func get_quality() -> String:
	return _quality


func _unhandled_input(event: InputEvent) -> void:
	if event is not InputEventKey or not event.pressed or event.echo:
		return
	if _view_state == "intro" and event.keycode in [KEY_ENTER, KEY_SPACE, KEY_ESCAPE]:
		get_viewport().set_input_as_handled()
		_finish_intro()
	elif event.keycode == KEY_ESCAPE:
		if handle_back():
			get_viewport().set_input_as_handled()


func handle_back() -> bool:
	# Root forwards Android's go-back notification with SceneTree.quit_on_go_back disabled.
	match _view_state:
		"intro": _finish_intro()
		"game":
			if _touch_overlay_open():
				_close_touch_overlays()
			else:
				_emit("cancel_build" if _build_active else "pause")
		"pause", "journal", "village": _emit("resume")
		"gallery": _close_gallery()
		"settings": _return_to(_settings_return)
		"confirm": _return_to(_confirm_return)
		"menu": _confirm("Spiel beenden?", "Ein laufender Lebensweg wird vor dem Beenden gespeichert.", "quit", {})
		"dialog": notify("Wähle eine Antwort, um dieses Gespräch abzuschließen.")
		"frontier_dialog": _emit(str(_frontier_dialog_data.get("close_action", "frontier_close")))
		_: return false
	return true


func _open_screen(screen_name: String, darken: bool, menu_style := false) -> void:
	_reset_touch()
	_touch_pad = null
	_touch_look = null
	_touch_menu_layer = null
	_technique_menu_layer = null
	_touch_attack_button = null
	_touch_technique_button = null
	_pace_button = null
	_touch_actions.clear()
	_cancel_build_button = null
	if _screen != null:
		_screen.hide()
		_screen.queue_free()
	_view_state = screen_name
	_update_music(screen_name)
	var viewport_size := _content_size()
	_compact_layout = _touch_enabled or viewport_size.x < 1120 or viewport_size.y < 640
	_screen = Control.new()
	_screen.name = screen_name.capitalize()
	_screen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_screen.mouse_filter = Control.MOUSE_FILTER_STOP if darken else Control.MOUSE_FILTER_IGNORE
	_root.add_child(_screen)
	_root.move_child(_toast_panel, -1)
	if darken:
		var atmosphere := Atmosphere.new()
		atmosphere.menu_style = menu_style
		atmosphere.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		_screen.add_child(atmosphere)


func _finish_intro() -> void:
	if _intro_done or _view_state != "intro":
		return
	_intro_done = true
	if not _intro_seen:
		_intro_seen = true
		_save_settings()
	_emit("intro_finished")


func _emit(action: String, payload: Dictionary = {}) -> void:
	if action == "build":
		set_build_active(true)
	elif action == "cancel_build":
		set_build_active(false)
	action_requested.emit(action, payload)


func _request_new_game() -> void:
	# The entry point knows the real save state and supplies its confirmation dialog.
	_emit("new_game")


func _confirm(title: String, body: String, action: String, payload: Dictionary) -> void:
	_confirm_return = _view_state
	_confirm_data = {"title": title, "body": body, "action": action, "payload": payload.duplicate(true)}
	_render_confirmation()


func _render_confirmation() -> void:
	_open_screen("confirm", true)
	var column := _modal("BITTE BESTÄTIGEN", String(_confirm_data.title), String(_confirm_data.body), 540)
	column.add_child(_button("Bestätigen", _emit.bind(String(_confirm_data.action), _confirm_data.payload), true))
	var back := _button("Zurück", func(): _return_to(_confirm_return))
	column.add_child(back)
	back.grab_focus.call_deferred()


func _return_to(screen_name: String) -> void:
	if screen_name == "pause":
		show_pause()
	else:
		show_menu(_can_continue)


func _build_top_bar() -> void:
	var panel := _panel(false)
	panel.name = "ResourceBar"
	panel.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	panel.offset_left = 24
	panel.offset_right = -24
	panel.offset_top = 24
	panel.offset_bottom = 91
	if _touch_enabled:
		_compact_panel(panel, 10, 8)
		panel.offset_left = 12
		panel.offset_right = -12
		panel.offset_top = 8 if _content_size().y < 470 else 12
		panel.offset_bottom = panel.offset_top + 64
	_screen.add_child(panel)
	var row := _row(5 if _touch_enabled else 10 if _compact_layout else 22)
	panel.add_child(row)
	var brand := _column(2)
	brand.custom_minimum_size.x = 130 if _compact_layout else 190
	row.add_child(brand)
	brand.add_child(_label("IMPERATHEN", 17 if _compact_layout else 23, CREAM, true))
	_hud_labels["status"] = _label("GRENZDORF", 10, BRONZE)
	brand.add_child(_hud_labels["status"])
	brand.visible = not (_compact_layout and _content_size().x < 1000)
	for resource in ["wood", "grain", "denarii"]:
		var metric := _label("", 13 if _compact_layout else 18, CREAM)
		metric.custom_minimum_size.x = 60 if _touch_enabled else 72 if _compact_layout else 115
		metric.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		row.add_child(metric)
		_hud_labels[resource] = metric
	var fill := Control.new()
	fill.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(fill)
	_hud_labels["time"] = _label("", 12, MUTED)
	_hud_labels["time"].vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(_hud_labels["time"])
	_hud_labels["time"].visible = not _touch_enabled or _content_size().x >= 760
	row.add_child(_button("Chronik", _show_journal, false, 12))
	if _compact_layout:
		row.add_child(_button("Pause", func(): _emit("pause"), false, 12))
	else:
		row.add_child(_button("Speichern", func(): _emit("save"), false, 13))
		row.add_child(_button("Pause  ·  Esc", func(): _emit("pause"), false, 13))
	if _touch_enabled:
		for child: Node in row.get_children():
			if child is Button:
				child.custom_minimum_size.y = 48


func _build_navigation() -> void:
	if not Childhood.enabled(_state):
		return
	_navigation = Navigation.new()
	_navigation.name = "VillageCompass"
	_navigation.size = Vector2(158, 148)
	_navigation.position = Vector2(24, 110)
	if _touch_enabled:
		var extent := _content_size()
		if extent.y < 470:
			_navigation.size = Vector2(128, 110)
			_navigation.position = Vector2((extent.x - _navigation.size.x) * 0.5, 124)
		else:
			_navigation.size.y = minf(148, extent.y - 88 - 196 - 92 - 12)
			_navigation.position = Vector2(extent.x - _navigation.size.x - 16, 92)
	_screen.add_child(_navigation)


func _build_objective_card() -> void:
	var panel := _panel(true)
	panel.name = "ObjectiveCard"
	panel.position = Vector2(196, 110) if Childhood.enabled(_state) and not _touch_enabled else Vector2(24, 110)
	panel.size = Vector2(272, 150) if _compact_layout else Vector2(300, 180)
	var minimal_touch := _touch_enabled and _content_size().y < 470
	if _touch_enabled:
		panel.position = Vector2(16, 80 if minimal_touch else 92)
		_compact_panel(panel, 10, 4 if minimal_touch else 10)
	if _touch_enabled and not minimal_touch:
		var pad_size := clampf(_content_size().y * 0.36, 156.0, 216.0)
		panel.size.y = minf(150, _content_size().y - 88 - pad_size - panel.position.y - 12)
	if minimal_touch:
		panel.size = Vector2(_content_size().x - 32, 32)
	_screen.add_child(panel)
	var short_layout := _compact_layout and _content_size().y < 600
	var column := _column(0 if minimal_touch else 6 if short_layout else 10)
	panel.add_child(column)
	if not (_compact_layout and _content_size().y < 520):
		column.add_child(_label("DEIN NÄCHSTER SCHRITT", 11, BRONZE))
	_hud_labels["objective_title"] = _label("", 17 if short_layout else 19 if _compact_layout else 23, CREAM, true)
	_hud_labels["objective_title"].autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(_hud_labels["objective_title"])
	if _touch_enabled and _content_size().y < 600:
		_hud_labels["objective_title"].max_lines_visible = 1
		_hud_labels["objective_title"].text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_hud_labels["objective_text"] = _label("", 12 if short_layout else 13 if _compact_layout else 15, MUTED)
	_hud_labels["objective_text"].autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	if _compact_layout:
		_hud_labels["objective_text"].max_lines_visible = 2 if _content_size().y < 520 else 3 if short_layout else 4
		_hud_labels["objective_text"].text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	column.add_child(_hud_labels["objective_text"])
	_hud_labels["compact_life"] = _label("", 12, BRONZE)
	_hud_labels["compact_life"].autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(_hud_labels["compact_life"])
	if minimal_touch:
		_hud_labels["objective_title"].add_theme_font_size_override("font_size", roundi(14 * _ui_scale))
		_hud_labels["objective_title"].max_lines_visible = 1
		_hud_labels["objective_title"].text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		_hud_labels["objective_text"].hide()
		_hud_labels["compact_life"].hide()
		panel.gui_input.connect(func(event: InputEvent):
			if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
				_show_journal()
		)


func _build_character_card() -> void:
	var panel := _panel(false)
	_life_panel = panel
	panel.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	panel.offset_left = -282
	panel.offset_right = -24
	panel.offset_top = 110
	panel.offset_bottom = 330
	_screen.add_child(panel)
	var column := _column(9)
	panel.add_child(column)
	column.add_child(_label("DEIN LEBEN", 11, BRONZE))
	_hud_labels["age"] = _label("", 17, CREAM, true)
	_hud_labels["age"].autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(_hud_labels["age"])
	_hud_labels["health"] = _label("", 12, MUTED)
	column.add_child(_hud_labels["health"])
	_health_bar = ProgressBar.new()
	_health_bar.custom_minimum_size.y = 5
	_health_bar.show_percentage = false
	_health_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_health_bar.add_theme_stylebox_override("background", _flat(Color("26302b")))
	_health_bar.add_theme_stylebox_override("fill", _flat(Color("a77b53")))
	column.add_child(_health_bar)
	_hud_labels["companion"] = _label("", 13, MUTED)
	_hud_labels["companion"].autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(_hud_labels["companion"])
	_hud_labels["squad"] = _label("", 13, CREAM)
	_hud_labels["squad"].autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_hud_labels["squad"].tooltip_text = "Lebende Soldaten im Verhältnis zu allen bisher rekrutierten Soldaten."
	column.add_child(_hud_labels["squad"])
	var chronicle_panel := _panel(false)
	_chronicle_panel = chronicle_panel
	chronicle_panel.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	chronicle_panel.offset_left = -282
	chronicle_panel.offset_right = -24
	chronicle_panel.offset_top = 347
	chronicle_panel.offset_bottom = 500
	_screen.add_child(chronicle_panel)
	var chronicle_column := _column(10)
	chronicle_panel.add_child(chronicle_column)
	chronicle_column.add_child(_label("CHRONIK", 11, BRONZE))
	_hud_labels["chronicle"] = _label("", 12, MUTED)
	_hud_labels["chronicle"].autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_hud_labels["chronicle"].max_lines_visible = 5
	_hud_labels["chronicle"].text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	chronicle_column.add_child(_hud_labels["chronicle"])
	panel.resized.connect(func():
		if is_instance_valid(chronicle_panel):
			var next_top := maxf(347, panel.position.y + panel.size.y + 14)
			chronicle_panel.offset_top = next_top
			chronicle_panel.offset_bottom = next_top + 153
	)
	if _compact_layout:
		panel.hide()
		chronicle_panel.hide()


func _build_toolbar() -> void:
	if _touch_enabled:
		_build_touch_toolbar()
		return
	var panel := _panel(false)
	panel.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	panel.offset_left = 24
	panel.offset_right = -24
	if _touch_enabled:
		panel.offset_left = 184
		panel.offset_right = -184
	panel.offset_top = -143
	panel.offset_bottom = -24
	_screen.add_child(panel)
	var column := _column(8)
	panel.add_child(column)
	var row := HFlowContainer.new()
	row.add_theme_constant_override("h_separation", 10)
	row.add_theme_constant_override("v_separation", 8)
	column.add_child(row)
	var modes := [["person", "Figur"], ["city", "Stadt"], ["map", "Karte"]] if _compact_layout else [["person", "Persönlich"], ["city", "Städtebau · Tab"], ["map", "Landkarte · M"]]
	for item in modes:
		var button := _button(item[1], _emit.bind("mode_" + item[0], {}), false, 12 if _compact_layout else 13)
		_mode_buttons[item[0]] = button
		row.add_child(button)
	var atlas := _button("Weltkugel", func(): _emit("atlas"), false, 13)
	atlas.visible = _mode == "map"
	row.add_child(atlas)
	_action_buttons["atlas"] = atlas
	if _state.get("village", {}).get("enabled", false):
		row.add_child(_button("Dorfleben", _emit.bind("village_panel", {}), true, 13))
	var actions := [
		["build", "Hütte · 8 Holz", "Bauplan öffnen. Mit Linksklick einen erlaubten Platz bestätigen."],
		["train", "Ausbildung", "Benötigt eine fertige Hütte, eine Gefährtenentscheidung und keine offene Baustelle. Am Trainingsplatz fortsetzen."],
		["recruit", "Rekrutieren", "Ein Rekrut: 5 Denare und 2 Getreide. Ausbildung erforderlich; höchstens drei Rekruten."],
		["skirmish", "Dorf verteidigen", "Benötigt abgeschlossene Ausbildung und eine lebende eigene Truppe."]
	]
	for item in actions:
		var compact_names := {"build": "Hütte", "train": "Üben", "recruit": "Truppe +", "skirmish": "Verteidigen"}
		var button := _button(compact_names[item[0]] if _compact_layout else item[1], _emit.bind(item[0], {}), false, 12 if _compact_layout else 13)
		button.tooltip_text = item[2]
		if _touch_enabled and item[0] == "build":
			button.tooltip_text = "Bauplan öffnen und einen freien Platz antippen. Eine Hütte benötigt acht Holz."
		_action_buttons[item[0]] = button
		row.add_child(button)
	_hud_labels["controls"] = _label("", 12, MUTED)
	_hud_labels["controls"].autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(_hud_labels["controls"])
	_hud_labels["controls"].visible = not _compact_layout
	panel.minimum_size_changed.connect(func():
		if is_instance_valid(panel):
			panel.offset_top = -24 - maxf(78 if _compact_layout else 102, panel.get_combined_minimum_size().y)
	)


func _build_touch_toolbar() -> void:
	var panel := _panel(false)
	panel.name = "TouchToolbar"
	_compact_panel(panel, 10, 8)
	panel.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	panel.offset_left = 12
	panel.offset_right = -12
	panel.offset_top = -76
	panel.offset_bottom = -12
	_screen.add_child(panel)
	var row := _row(6)
	panel.add_child(row)
	for item in [["person", "Figur"], ["city", "Stadt"], ["map", "Karte"]]:
		var button := _touch_button(item[1], _emit.bind("mode_" + item[0], {}), false)
		button.custom_minimum_size.y = 48
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_mode_buttons[item[0]] = button
		row.add_child(button)
	if _state.get("village", {}).get("enabled", false):
		var village := _touch_button("Dorf", _emit.bind("village_panel", {}), false)
		village.custom_minimum_size.y = 48
		village.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(village)
	var commands := _touch_button("Vorhaben", _toggle_command_menu, false)
	commands.name = "OpenCommands"
	commands.custom_minimum_size.y = 48
	commands.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(commands)
	_hud_labels["controls"] = _label("", 12, MUTED)
	_hud_labels["controls"].hide()
	_screen.add_child(_hud_labels["controls"])
	_touch_menu_layer = _new_touch_overlay("CommandMenu", "Dein nächster Schritt")
	var column: VBoxContainer = _touch_menu_layer.get_meta("content")
	var actions := [["build", "Hütte bauen · 8 Holz"], ["train", "Ausbildung"], ["recruit", "Truppe verstärken"], ["skirmish", "Dorf verteidigen"], ["atlas", "Weltkugel"]]
	for item in actions:
		var button := _button(item[1], func():
			_close_touch_overlays()
			_emit(item[0])
		, false, 14)
		button.name = "Command_" + item[0]
		button.custom_minimum_size.y = 50
		column.add_child(button)
		_action_buttons[item[0]] = button
	_touch_menu_layer.hide()


func _build_touch_controls() -> void:
	if _touch_enabled:
		var extent := _content_size()
		var short_screen := extent.y < 470
		var pad_size := clampf(extent.y * 0.36, 156.0, 216.0)
		pad_size = minf(pad_size, maxf(150.0, extent.x * 0.43))
		_touch_pad = TouchPadScript.new()
		_touch_pad.name = "MovementPad"
		_touch_pad.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
		_touch_pad.offset_left = 12
		_touch_pad.offset_right = 12 + pad_size
		_touch_pad.offset_top = -88 - pad_size
		_touch_pad.offset_bottom = -88
		_screen.add_child(_touch_pad)
		_touch_pad.axis_changed.connect(func(axis: Vector2): _emit("move_axis", {"x": axis.x, "y": axis.y}))
		_touch_look = TouchLookScript.new()
		_touch_look.name = "CameraLook"
		_touch_look.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		_touch_look.anchor_left = 0.35
		_screen.add_child(_touch_look)
		_touch_look.look_changed.connect(func(delta: Vector2): _emit("camera_look", {"x": delta.x, "y": delta.y}))
		_touch_look.zoom_changed.connect(func(factor: float): _emit("camera_zoom", {"factor": factor}))
		var right := GridContainer.new()
		right.name = "TouchActions"
		right.columns = 2
		right.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
		right.offset_left = -12 - clampf(extent.x * 0.31, 224.0, 304.0)
		right.offset_right = -12
		right.offset_top = -88 - (156 if short_screen else 196)
		right.offset_bottom = -88
		right.add_theme_constant_override("h_separation", 8)
		right.add_theme_constant_override("v_separation", 6 if short_screen else 8)
		right.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_screen.add_child(right)
		var entries := [["interact", "Interagieren"], ["attack", "Schlagen"], ["guard", "Deckung"], ["dodge", "Ausweichen"], ["techniques", "Techniken"], ["pace", "Gehen"]]
		for item in entries:
			var action_id := str(item[0])
			var button := _touch_button(item[1], _touch_action.bind(action_id), action_id == "attack")
			button.name = action_id.capitalize()
			button.set_action_icon(action_id)
			button.custom_minimum_size = Vector2(0, 48 if short_screen else 60)
			button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			button.size_flags_vertical = Control.SIZE_EXPAND_FILL
			_touch_actions.append(button)
			right.add_child(button)
			if action_id == "attack":
				_touch_attack_button = button
			elif action_id == "techniques":
				_touch_technique_button = button
			elif action_id == "pace":
				_pace_button = button
			button.set_meta("touch_action", action_id)
		_update_pace_caption()
		# Modal native handlers run above every gameplay input control.
		if is_instance_valid(_touch_menu_layer):
			_screen.move_child(_touch_menu_layer, -1)
	_cancel_build_button = _touch_button("Bau abbrechen", func(): _emit("cancel_build"), false) if _touch_enabled else _button("Bau abbrechen", func(): _emit("cancel_build"), false, 14)
	_cancel_build_button.name = "CancelBuild"
	_cancel_build_button.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	_cancel_build_button.offset_left = -194 if _touch_enabled else -220
	_cancel_build_button.offset_right = -16 if _touch_enabled else -24
	_cancel_build_button.offset_top = -150 if _touch_enabled else -210
	_cancel_build_button.offset_bottom = -92 if _touch_enabled else -154
	_screen.add_child(_cancel_build_button)
	_update_touch_visibility()


func _touch_button(caption: String, callback: Callable, primary: bool) -> Button:
	var button: Button = TouchActionScript.new()
	button.text = caption
	button.set_meta("base_font_size", 13)
	button.add_theme_font_size_override("font_size", roundi(13 * _ui_scale))
	var normal := _button_style(primary, false)
	var hover := _button_style(primary, true)
	for style in [normal, hover]:
		style.content_margin_left = 10
		style.content_margin_right = 10
		style.content_margin_top = 6
		style.content_margin_bottom = 6
	button.add_theme_stylebox_override("normal", normal)
	button.add_theme_stylebox_override("hover", hover)
	button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	button.pressed.connect(func():
		_play_click()
		callback.call()
	)
	return button


func _touch_action(action: String) -> void:
	match action:
		"attack": _emit("attack", {"technique": _selected_technique} if CombatActions.enabled(_state) else {})
		"guard": _emit("village_unarmed_guard" if CombatActions.enabled(_state) else "village_block")
		"dodge": _emit("village_unarmed_dodge" if CombatActions.enabled(_state) else "village_dodge")
		"techniques": _show_technique_menu()
		"pace":
			_running = not _running
			_state["running"] = _running
			_update_pace_caption()
			_emit("movement_pace", {"running": _running})
		_: _emit(action)


func _sync_pace_from_state(state: Dictionary) -> void:
	if state.has("running"):
		_running = bool(state.running)
	elif state.get("world_id", "") != _state.get("world_id", ""):
		_running = false


func _update_pace_caption() -> void:
	if is_instance_valid(_pace_button):
		_pace_button.text = "Laufen" if _running else "Gehen"
		_pace_button.set_action_icon("run" if _running else "pace")
		_pace_button.tooltip_text = "Antippen: zum Gehen wechseln." if _running else "Antippen: zum Laufen wechseln."
		_pace_button.add_theme_stylebox_override("normal", _button_style(_running, false))


func _update_combat_controls() -> void:
	if not is_instance_valid(_touch_attack_button):
		return
	var enabled := CombatActions.enabled(_state)
	if enabled and not CombatActions.available(_state, _selected_technique):
		_selected_technique = "jab_left"
		_emit("select_technique", {"technique": _selected_technique})
	_touch_attack_button.text = (("Gladius\n" if CombatActions.is_armed(_selected_technique) else "Schlag\n") + str(CombatActions.TECHNIQUES[_selected_technique].short)) if enabled else "Angreifen"
	_touch_technique_button.disabled = not enabled
	_touch_technique_button.tooltip_text = "Wähle eine erlernte Bewegung." if enabled else "Techniken stehen in deinem neuen Dorfleben zur Verfügung."
	if enabled:
		var stamina: float = float(_state.village.unarmed.stamina)
		_touch_attack_button.tooltip_text = "%s · %d Ausdauer" % [CombatActions.TECHNIQUES[_selected_technique].label, int(CombatActions.TECHNIQUES[_selected_technique].cost)]
		_touch_attack_button.disabled = stamina < float(CombatActions.TECHNIQUES[_selected_technique].cost) or float(_state.get("player", {}).get("health", 0)) <= 0
	else:
		_touch_attack_button.disabled = false


func _new_touch_overlay(node_name: String, title: String) -> Control:
	var overlay: Control = TouchModalScript.new()
	overlay.name = node_name
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_screen.add_child(overlay)
	var shade := ColorRect.new()
	shade.color = Color(0.015, 0.025, 0.025, 0.72)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(shade)
	var panel := _panel(true)
	_compact_panel(panel, 14, 12)
	panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	var extent := _content_size()
	var width := minf(630.0, extent.x - 40.0)
	var height := minf(510.0, extent.y - 42.0)
	panel.offset_left = -width * 0.5
	panel.offset_right = width * 0.5
	panel.offset_top = -height * 0.5
	panel.offset_bottom = height * 0.5
	overlay.add_child(panel)
	var layout := _column(10)
	panel.add_child(layout)
	var header := _row(12)
	layout.add_child(header)
	var heading := _label(title, 20, CREAM, true)
	heading.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	heading.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	header.add_child(heading)
	var close := _button("Zurück", _close_touch_overlays, false, 13)
	close.name = "CloseOverlay"
	close.custom_minimum_size.y = 48
	header.add_child(close)
	var scroll := ScrollContainer.new()
	scroll.name = "ChoicesScroll"
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.follow_focus = true
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	layout.add_child(scroll)
	var content := _column(8)
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(content)
	overlay.set_meta("content", content)
	return overlay


func _show_technique_menu() -> void:
	if not CombatActions.enabled(_state):
		return
	_reset_touch()
	if is_instance_valid(_touch_menu_layer):
		_touch_menu_layer.hide()
	if is_instance_valid(_technique_menu_layer):
		_technique_menu_layer.queue_free()
	_technique_menu_layer = _new_touch_overlay("TechniqueMenu", "Deine Techniken")
	var column: VBoxContainer = _technique_menu_layer.get_meta("content")
	var combat: Dictionary = CombatActions.view(_state)
	var help := _label("Ausdauer %d/100 · %d kontrollierte Übungstreffer\nEine Technik wählen, dann im Spiel mit der Schlagtaste ausführen." % [int(combat.stamina), int(combat.practice_hits)], 13, MUTED)
	help.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(help)
	if combat.get("service_gear",false):
		var equipment := _label("Dienstausrüstung: Gladius und Scutum · ausgebildeter Soldat. Wähle Faust- oder Waffentechnik.", 13, MUTED)
		equipment.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		column.add_child(equipment)
	for technique: Dictionary in combat.techniques:
		var id := str(technique.id)
		var available := bool(technique.available)
		var caption := "%s · %d Ausdauer" % [technique.label, int(technique.cost)]
		if not available:
			caption += "\nErlernbar ab %d Übungstreffern" % int(technique.practice)
		var button := _button(caption, _choose_technique.bind(id), id == _selected_technique, 14)
		button.name = "Technique_" + id
		button.custom_minimum_size.y = 56 if available else 68
		button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		button.disabled = not available
		column.add_child(button)
	_update_touch_visibility()


func _choose_technique(id: String) -> void:
	if not CombatActions.available(_state, id):
		return
	_selected_technique = id
	_close_touch_overlays()
	_update_combat_controls()
	_emit("select_technique", {"technique": id})


func _toggle_command_menu() -> void:
	if not is_instance_valid(_touch_menu_layer):
		return
	var opening := not _touch_menu_layer.visible
	_close_touch_overlays()
	_touch_menu_layer.visible = opening
	_update_touch_visibility()


func _close_touch_overlays() -> void:
	_reset_touch()
	if is_instance_valid(_touch_menu_layer):
		_touch_menu_layer.hide()
	if is_instance_valid(_technique_menu_layer):
		_technique_menu_layer.hide()
	_update_touch_visibility()


func _touch_overlay_open() -> bool:
	return (is_instance_valid(_touch_menu_layer) and _touch_menu_layer.visible) or (is_instance_valid(_technique_menu_layer) and _technique_menu_layer.visible)


func _compact_panel(panel: PanelContainer, horizontal: int, vertical: int) -> void:
	var style := panel.get_theme_stylebox("panel").duplicate() as StyleBoxFlat
	style.content_margin_left = horizontal
	style.content_margin_right = horizontal
	style.content_margin_top = vertical
	style.content_margin_bottom = vertical
	panel.add_theme_stylebox_override("panel", style)


func _reset_touch() -> void:
	if is_instance_valid(_touch_pad):
		_touch_pad.reset()
	if is_instance_valid(_touch_look):
		_touch_look.reset()
	for button in _touch_actions:
		if is_instance_valid(button):
			button.reset()
	if is_instance_valid(_screen):
		for button: Node in _screen.find_children("*", "Button", true, false):
			if button.has_method("reset"):
				button.reset()
	if is_instance_valid(_cancel_build_button) and _cancel_build_button.has_method("reset"):
		_cancel_build_button.reset()


func _update_touch_visibility() -> void:
	if _view_state != "game":
		return
	var overlay := _touch_overlay_open()
	var toolbar := _screen.get_node_or_null("TouchToolbar")
	if toolbar != null:
		toolbar.visible = not overlay
	var personal := _mode == "person" and not _build_active and not overlay
	if is_instance_valid(_touch_pad):
		_touch_pad.visible = personal
	if is_instance_valid(_touch_look):
		_touch_look.visible = personal
	for button in _touch_actions:
		if is_instance_valid(button):
			var action := str(button.get_meta("touch_action", ""))
			button.visible = personal and (action not in ["guard", "dodge"] or _state.get("village", {}).get("enabled", false))
	if is_instance_valid(_cancel_build_button):
		_cancel_build_button.visible = _build_active and not overlay


func _region_report() -> String:
	var region: Dictionary = _state.get("valley", {})
	if region.is_empty():
		return ""
	var outcome := String(region.get("outcome", ""))
	var status := String({"victory": "Sieg", "defeat": "Niederlage", "draw": "Unentschieden"}.get(outcome, "Einsatz läuft"))
	return "Grenzlegion im Tal · %s\nVerluste: %d eigene · %d gegnerische" % [
		status, int(region.get("allied_losses", 0)), int(region.get("enemy_losses", 0))]


func _show_gallery(source: String, selected: String = "") -> void:
	_gallery_from = source
	_open_screen("gallery",true)
	var gallery := FigureGallery.new()
	gallery.name = "FigureGallery"
	gallery.from_journal = source == "journal"
	gallery.origin = String(_state.get("origin_id",origin_id)) if gallery.from_journal else origin_id
	gallery.age = int(_state.get("player",{}).get("age",12))
	if gallery.from_journal:
		gallery.filter = "journal"
		gallery.current_id = selected if selected != "" else "hero_" + gallery.origin
	gallery.closed.connect(_close_gallery)
	if OS.is_debug_build() and OS.has_feature("android"):
		print("IMPERATHEN_GALLERY_OPEN " + source)
	_screen.add_child(gallery)


func _close_gallery() -> void:
	if OS.is_debug_build() and OS.has_feature("android"):
		print("IMPERATHEN_GALLERY_CLOSED " + _gallery_from)
	if _gallery_from == "journal":
		_show_journal(false)
	else:
		show_menu(_can_continue)


func _add_journal_portraits(column: VBoxContainer) -> void:
	var home := String(_state.get("origin_id","italia"))
	var ids := FigureGallery.arrival_ids(home,int(_state.get("player",{}).get("age",12)))
	for pair in range(0,ids.size(),2):
		column.add_child(_label("Bei der Ankunft" if pair == 0 else "Im Erwachsenenalter",16,BRONZE,true))
		var row := _row(10)
		column.add_child(row)
		for i in range(pair,pair+2):
			var id: String = ids[i]
			var cell := _column(4)
			cell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			row.add_child(cell)
			var picture := TextureRect.new()
			picture.name = "Journal_" + id
			picture.mouse_filter = Control.MOUSE_FILTER_IGNORE
			picture.texture = FigureGallery.texture(id)
			picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			picture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			picture.custom_minimum_size.y = 115
			picture.visible = picture.texture != null
			cell.add_child(picture)
			var title: String = FigureGallery.caption(id).name
			var button := _button(title,func(): _show_gallery("journal",id),false,14)
			button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			cell.add_child(button)
	column.add_child(_button("Figuren",func(): _show_gallery("journal")))


func _show_journal(pause_world := true) -> void:
	# Root pauses the authoritative world before the reading screen replaces its pause UI.
	if pause_world:
		_emit("pause")
	_open_screen("journal", true)
	var objective := _objective(_state)
	var player: Dictionary = _state.get("player", {})
	var squad: Dictionary = _state.get("squad", {})
	var companion: Dictionary = _state.get("companion", {})
	var summary := "%d Jahre · Leben %d / 100\nTruppe: %d / %d am Leben · Moral %d\n%s: %s\n\n%s\n%s" % [
		int(player.get("age", 12)), int(player.get("health", 100)), int(squad.get("alive", 0)), int(squad.get("recruits", 0)), int(squad.get("morale", 0)),
		_companion_name(_state), "Vertrauen %+d" % int(companion.get("trust", 0)) if bool(companion.get("met", false)) else "noch nicht kennengelernt", objective[0], objective[1]
	]
	var report := _region_report()
	if not report.is_empty():
		summary += "\n\n" + report
	var column := _modal("DEIN LEBENSWEG", "Chronik", summary, 650)
	_add_journal_portraits(column)
	for entry in _state.get("chronicle", []):
		var line := _label(String(entry.get("text", "")) if entry is Dictionary else str(entry), 14, MUTED)
		line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		column.add_child(line)
	var controls := "Links bewegen. Rechts im freien Bild umsehen. Gehen und Laufen mit der Temposchaltfläche wechseln. Unter Techniken eine Bewegung wählen, dann mit Schlag ausführen. Vorhaben öffnet Bau und Ausbildung." if _touch_enabled else "WASD bewegen · E interagieren · Linksklick / Leertaste kämpfen · B bauen · Tab Stadt · M Karte"
	var help := _label(controls, 13, BRONZE)
	help.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(help)
	var back := _button("Weiterspielen", func(): _emit("resume"), true)
	column.add_child(back)
	back.grab_focus.call_deferred()


func _viewport_changed() -> void:
	if _layout_queued:
		return
	_layout_queued = true
	_rebuild_layout.call_deferred()


func _rebuild_layout() -> void:
	_layout_queued = false
	_update_safe_area()
	match _view_state:
		"intro":
			# The sequence lays itself out again; restarting it would replay it.
			if not is_instance_valid(_intro_node):
				show_intro()
		"game": show_game(_state)
		"menu": show_menu(_can_continue)
		"settings": _show_settings(_settings_return)
		"pause": show_pause()
		"journal": _show_journal(false)
		"village": show_village_panel(_state, _village_tab)
		"confirm": _render_confirmation()
		"dialog": show_dialog(String(_dialog_data.title), String(_dialog_data.text), _dialog_data.choices)
		"frontier_dialog": show_frontier_dialog(_frontier_dialog_data)


func _content_size() -> Vector2:
	return _root.size if is_instance_valid(_root) else get_viewport().get_visible_rect().size


func _update_safe_area() -> void:
	_apply_safe_rect(SafeArea.for_viewport(get_viewport()))


func _safe_rect_from_display(screen_safe: Rect2, screen_transform: Transform2D, viewport_size: Vector2) -> Rect2:
	return SafeArea.from_display(screen_safe, screen_transform, viewport_size)


func _apply_safe_rect(safe: Rect2) -> void:
	if not is_instance_valid(_root):
		return
	var viewport_size := get_viewport().get_visible_rect().size
	_root.offset_left = safe.position.x
	_root.offset_top = safe.position.y
	_root.offset_right = safe.end.x - viewport_size.x
	_root.offset_bottom = safe.end.y - viewport_size.y


func _title_font_size(text: String, desired: int, available_width: float) -> int:
	var measured := _serif.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, roundi(desired * _ui_scale)).x
	if measured <= available_width or measured <= 0:
		return desired
	return maxi(24, floori(desired * maxf(available_width, 100) / measured))


func _companion_name(state: Dictionary) -> String:
	var origin: Dictionary = Origins.PEOPLES.get(state.get("origin_id", "italia"), Origins.PEOPLES.italia)
	return String(origin.companion)


func _objective(state: Dictionary) -> Array[String]:
	var progress: Dictionary = state.get("progress", {})
	var stage := String(progress.get("stage", "prologue"))
	if stage == "fallen":
		return ["Dein Weg ist zu Ende", "Du bist im Kampf gefallen. Im Menü kannst du einen gespeicherten Stand laden oder ein neues Leben beginnen."]
	if Childhood.enabled(state):
		var childhood: Dictionary = state.get("childhood_view", Childhood.view(state))
		return [str(childhood.get("title", "Ein Morgen zu Hause")), str(childhood.get("objective", "Sprich mit deiner Mutter vor dem Haus."))]
	var village: Dictionary = state.get("village_view", {})
	if state.get("village", {}).get("enabled", false):
		var has_roof := false
		for hut: Dictionary in state.get("buildings", []):
			has_roof = has_roof or bool(hut.get("completed", false))
		if state.village.raid.status == "warning" or state.village.raid.active or (has_roof and int(state.player.age) < 18):
			return [str(village.get("title", "Dein Platz im Dorf")), str(village.get("objective", "Sprich mit Decimus und lerne die Nachbarn kennen."))]
	if bool(state.get("encounter", {}).get("active", false)):
		return ["Für das Dorf", "Bleibe bei deiner Truppe. Nutze Abstand und gezielte Treffer. Ein gefallener Gefährte kehrt nicht durch einen Kamerawechsel zurück."]
	var journey: Dictionary = state.get("frontier_objective", {})
	if bool(journey.get("active", false)):
		return [str(journey.get("title", "Die Straße zur Legion")), str(journey.get("text", ""))]
	if stage == "ended":
		return ["Eine Spur bleibt", "Dieser erste Abschnitt ist abgeschlossen. Deine Entscheidung steht in der Chronik. Speichere deinen Lebensweg."]
	if bool(progress.get("skirmish_won", false)):
		return ["Was bleibt nach dem Sieg?", "Die Verteidigung ist entschieden. Deine nächste Wahl bestimmt den Abschluss dieses Abschnitts."]
	var buildings: Array = state.get("buildings", [])
	if buildings.is_empty():
		if int(state.get("resources", {}).get("wood", 0)) < 8:
			return ["Ein Dach für die Nacht", "Gehe zu den Holzstellen. Mit %s sammelst du Holz. Deine erste Hütte braucht acht Holz." % ("„Interagieren“" if _touch_enabled else "E")]
		return ["Dein erster Bauplatz", "Wähle „Hütte“ und danach eine freie Fläche im markierten Baugebiet."]
	for building in buildings:
		if not bool(building.get("completed", false)):
			return ["Ein Zuhause entsteht", "Bleibe bei der Baustelle und arbeite an deiner Hütte. Baufortschritt und verbrauchtes Material bleiben erhalten."]
	if not bool(state.get("companion", {}).get("met", false)):
		return ["Du bist nicht allein", "%s wartet im Dorf. Geh näher und wähle %s. Deine Antwort hat Folgen." % [_companion_name(state), "„Interagieren“" if _touch_enabled else "E"]]
	if not bool(progress.get("training_complete", false)):
		if int(state.get("player", {}).get("age", 12)) < 18:
			return ["Wenn du bereit bist", "Am Übungsplatz kannst du den nächsten Lebensabschnitt beginnen. Dann vergehen ausdrücklich sechs Jahre. Deine Hütte und eure Entscheidung bleiben erhalten."]
		return ["Der nächste Lebensabschnitt", "Gehe zum Trainingsplatz. Beginne die Ausbildung und triff den Übungspfahl dreimal. Treffer: %d / 3." % int(progress.get("training_hits", 0))]
	if int(state.get("squad", {}).get("alive", 0)) == 0:
		return ["Gemeinsam stärker", "Du hast die Grundlagen gelernt. Rekrutiere eine kleine Truppe. Jeder Rekrut braucht Sold und Nahrung."]
	return ["Verantwortung übernehmen", "Deine Truppe ist bereit. Bereite die Verteidigung vor und kämpfe persönlich an ihrer Seite."]


func _career_name(stage: String) -> String:
	match stage:
		"training": return "In Ausbildung"
		"trained": return "Ausgebildet"
		"skirmish", "aftermath": return "Truppenführer"
		"ended": return "Auf eigenem Weg"
		"fallen": return "Gefallen"
		_: return "Dorfkind"


func _show_settings(return_screen: String) -> void:
	_settings_return = return_screen
	_open_screen("settings", true)
	var column := _modal("DEIN SPIELGEFÜHL", "Einstellungen", "Änderungen werden auf diesem Gerät gespeichert.", 650)
	var scale_caption := _label("Schrift und Oberfläche  ·  %d %%" % int(_ui_scale * 100), 16, CREAM)
	column.add_child(scale_caption)
	var scale_slider := HSlider.new()
	scale_slider.min_value = 0.85
	scale_slider.max_value = 1.25
	scale_slider.step = 0.05
	scale_slider.value = _ui_scale
	scale_slider.custom_minimum_size.y = 32
	scale_slider.tooltip_text = "Schrift und Bedienelemente vergrößern oder verkleinern."
	column.add_child(scale_slider)
	scale_slider.value_changed.connect(func(value: float):
		_ui_scale = value
		scale_caption.text = "Schrift und Oberfläche  ·  %d %%" % roundi(value * 100)
		_apply_scale(_root)
		_save_settings()
	)
	var motion := CheckButton.new()
	motion.text = "Bewegungseffekte reduzieren"
	motion.button_pressed = _reduce_motion
	motion.custom_minimum_size.y = 48
	motion.tooltip_text = "Verzichtet auf Einblendanimationen und reduziert die Bewegung des Vorspanns."
	column.add_child(motion)
	motion.toggled.connect(func(value: bool):
		_reduce_motion = value
		_save_settings()
	)
	var touch_toggle := CheckButton.new()
	touch_toggle.name = "TouchControlsSetting"
	touch_toggle.text = "Touch-Steuerung"
	touch_toggle.button_pressed = _touch_enabled
	touch_toggle.custom_minimum_size.y = 48
	touch_toggle.tooltip_text = "Analogpad und Aktionstasten. Auf Mobilgeräten automatisch aktiv; auch am Desktop nutzbar."
	column.add_child(touch_toggle)
	touch_toggle.toggled.connect(func(value: bool):
		_touch_enabled = value
		_reset_touch()
		_save_settings()
	)
	column.add_child(_label("Grafikqualität", 16, CREAM))
	var quality_select := OptionButton.new()
	quality_select.name = "QualitySetting"
	quality_select.add_item("Leicht · Limit 30 FPS")
	quality_select.add_item("Ausgewogen · Limit 60 FPS")
	quality_select.add_item("Hoch · bis 4K · Limit 60 FPS" if OS.has_feature("pc") else "Hoch · Limit 60 FPS")
	quality_select.add_item("Sehr hoch · Limit 30 FPS")
	quality_select.custom_minimum_size.y = 46
	var profiles := ["low", "balanced", "high", "very_high"]
	quality_select.selected = profiles.find(_quality)
	column.add_child(quality_select)
	quality_select.item_selected.connect(func(index: int):
		set_quality(profiles[index])
	)
	var sustained_note := _label("Fold7-Grafikziel: Hoch · 60 FPS, Sehr hoch · 30 FPS.\nBei dauerhaft langen Bildzeiten wird nur die 3D-Auflösung reduziert; Menü und Touch bleiben scharf. Kein gemessener Temperaturwert.", 14, MUTED)
	sustained_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(sustained_note)
	var diagnostics := CheckButton.new()
	diagnostics.name = "DiagnosticsSetting"
	diagnostics.text = "Leistungsdiagnose anzeigen"
	diagnostics.button_pressed = _diagnostics
	diagnostics.custom_minimum_size.y = 48
	column.add_child(diagnostics)
	diagnostics.toggled.connect(func(value: bool):
		_diagnostics = value
		_apply_display_settings()
		_save_settings()
	)
	var volume_caption := _label("Gesamtlautstärke  ·  %d %%" % int(_volume * 100), 16, CREAM)
	column.add_child(volume_caption)
	var volume_slider := HSlider.new()
	volume_slider.min_value = 0
	volume_slider.max_value = 1
	volume_slider.step = 0.05
	volume_slider.value = _volume
	volume_slider.custom_minimum_size.y = 32
	column.add_child(volume_slider)
	volume_slider.value_changed.connect(func(value: float):
		_volume = value
		volume_caption.text = "Gesamtlautstärke  ·  %d %%" % roundi(value * 100)
		_apply_volume()
		_save_settings()
	)
	volume_slider.drag_ended.connect(func(_changed: bool): _play_click())
	var music_caption := _label("Musik im Hauptmenü  ·  %d %%" % roundi(_music_volume * 100), 16, CREAM)
	column.add_child(music_caption)
	var music_slider := HSlider.new()
	music_slider.name = "MusicVolumeSetting"
	music_slider.min_value = 0
	music_slider.max_value = 1
	music_slider.step = 0.05
	music_slider.value = _music_volume
	music_slider.custom_minimum_size.y = 32
	music_slider.tooltip_text = "Lautstärke des Menüthemas; ganz links schaltet die Musik stumm."
	column.add_child(music_slider)
	music_slider.value_changed.connect(func(value: float):
		_music_volume = value
		music_caption.text = "Musik im Hauptmenü  ·  %d %%" % roundi(value * 100)
		_apply_music_volume()
		_save_settings()
	)
	var intro_toggle := CheckButton.new()
	intro_toggle.name = "AlwaysIntroSetting"
	intro_toggle.text = "Vorspann bei jedem Start vollständig zeigen"
	intro_toggle.button_pressed = _always_intro
	intro_toggle.custom_minimum_size.y = 48
	intro_toggle.tooltip_text = "Sonst erscheint der vollständige Vorspann nur beim ersten Start und danach eine kurze Titelkarte."
	column.add_child(intro_toggle)
	intro_toggle.toggled.connect(func(value: bool):
		_always_intro = value
		_save_settings()
	)
	if return_screen == "menu":
		var replay := _button("Vorspann jetzt ansehen", _replay_intro)
		replay.name = "ReplayIntro"
		column.add_child(replay)
	var note := _label("Das Menüthema ist eine eigene, synthetisch erzeugte Komposition. Vertonte Gespräche sind noch nicht enthalten.\n\nDie Grundfunktionen sind ohne Mikrofon bedienbar.", 13, MUTED)
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(note)
	_spacer(column, 6)
	column.add_child(_button("Zurück", func(): _return_to(_settings_return), true))
	scale_slider.grab_focus.call_deferred()


func _modal(kicker: String, title: String, body: String, width: float, portrait_id: String = "") -> VBoxContainer:
	width = minf(width, _content_size().x - 100)
	var margin := _margin(30, 46, 30, 46)
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_screen.add_child(margin)
	var center := CenterContainer.new()
	margin.add_child(center)
	var panel := _panel(true)
	panel.custom_minimum_size.x = width
	center.add_child(panel)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.follow_focus = true
	scroll.custom_minimum_size = Vector2(width - 36, 0)
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.add_child(scroll)
	var column := _column(13)
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.custom_minimum_size.x = width - 48
	scroll.add_child(column)
	column.add_child(_label(kicker, 12, BRONZE))
	var heading := _label(title, 34, CREAM, true)
	heading.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(heading)
	var description := _label(body, 17, MUTED)
	description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var portrait := FigureGallery.texture(portrait_id) if portrait_id != "" else null
	if portrait:
		var speaker_row := _row(12)
		column.add_child(speaker_row)
		var image := TextureRect.new()
		image.name = "Speaker_" + portrait_id
		image.texture = portrait
		image.mouse_filter = Control.MOUSE_FILTER_IGNORE
		image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		image.custom_minimum_size = Vector2(78,106) if _compact_layout else Vector2(100,132)
		speaker_row.add_child(image)
		description.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		speaker_row.add_child(description)
	else:
		column.add_child(description)
	_spacer(column, 6)
	# Fit long story text and large type while keeping the choices reachable by scroll.
	column.minimum_size_changed.connect(func():
		if is_instance_valid(scroll):
			scroll.custom_minimum_size.y = minf(column.get_combined_minimum_size().y, maxf(120, _content_size().y - 144))
	)
	return column


func _setup_theme() -> void:
	_serif = SystemFont.new()
	_serif.font_names = PackedStringArray(["DejaVu Serif", "Noto Serif", "Liberation Serif"])
	_ui_theme = Theme.new()
	_ui_theme.default_font_size = roundi(16 * _ui_scale)
	_ui_theme.set_color("font_color", "Label", CREAM)
	_ui_theme.set_color("font_color", "Button", CREAM)
	_ui_theme.set_color("font_hover_color", "Button", Color("fff2d8"))
	_ui_theme.set_color("font_pressed_color", "Button", CREAM)
	_ui_theme.set_color("font_disabled_color", "Button", Color("777b73"))
	_ui_theme.set_stylebox("normal", "Button", _button_style(false, false))
	_ui_theme.set_stylebox("hover", "Button", _button_style(false, true))
	_ui_theme.set_stylebox("pressed", "Button", _button_style(true, true))
	var disabled := _button_style(false, false)
	disabled.bg_color = Color("16201f")
	disabled.border_color = Color("333b34")
	_ui_theme.set_stylebox("disabled", "Button", disabled)
	var focus := _flat(Color(0, 0, 0, 0))
	focus.border_color = CREAM
	focus.set_border_width_all(2)
	focus.set_corner_radius_all(3)
	_ui_theme.set_stylebox("focus", "Button", focus)
	var tooltip := _flat(Color("111a1b"))
	tooltip.set_content_margin_all(12)
	tooltip.set_border_width_all(1)
	tooltip.border_color = BRONZE
	_ui_theme.set_stylebox("panel", "TooltipPanel", tooltip)
	_ui_theme.set_color("font_color", "TooltipLabel", CREAM)


func _button_style(primary: bool, hover: bool) -> StyleBoxFlat:
	var style := _flat(Color("8b3a40") if primary and hover else CRIMSON if primary else Color("333c35") if hover else Color("202925"))
	style.border_color = Color("d2ad78") if hover else Color("8e714f") if primary else Color("4f574a")
	style.set_border_width_all(1)
	style.set_corner_radius_all(3)
	style.content_margin_left = 18
	style.content_margin_right = 18
	style.content_margin_top = 9
	style.content_margin_bottom = 9
	return style


func _flat(color: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	return style


func _panel(accent: bool) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	var style := _flat(Color(0.045, 0.072, 0.072, 0.94))
	style.border_color = Color("6a5a40")
	style.set_border_width_all(1)
	if accent:
		style.border_width_top = 3
	style.set_corner_radius_all(4)
	style.content_margin_left = 18
	style.content_margin_right = 18
	style.content_margin_top = 14
	style.content_margin_bottom = 14
	panel.add_theme_stylebox_override("panel", style)
	return panel


func _button(text: String, callback: Callable, primary := false, font_size := 17) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size.y = maxf(40, 44 * _ui_scale)
	button.set_meta("base_font_size", font_size)
	button.add_theme_font_size_override("font_size", roundi(font_size * _ui_scale))
	button.add_theme_stylebox_override("normal", _button_style(primary, false))
	button.add_theme_stylebox_override("hover", _button_style(primary, true))
	button.mouse_filter = Control.MOUSE_FILTER_STOP
	button.pressed.connect(func():
		_play_click()
		callback.call()
	)
	return button


func _label(text: String, font_size := 16, color := CREAM, serif := false) -> Label:
	var label := Label.new()
	label.text = text
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.set_meta("base_font_size", font_size)
	label.add_theme_font_size_override("font_size", roundi(font_size * _ui_scale))
	label.add_theme_color_override("font_color", color)
	if serif:
		label.add_theme_font_override("font", _serif)
	return label


func _column(separation: int) -> VBoxContainer:
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", separation)
	column.mouse_filter = Control.MOUSE_FILTER_PASS
	return column


func _row(separation: int) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", separation)
	row.mouse_filter = Control.MOUSE_FILTER_PASS
	return row


func _margin(left: int, top: int, right: int, bottom: int) -> MarginContainer:
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", left)
	margin.add_theme_constant_override("margin_top", top)
	margin.add_theme_constant_override("margin_right", right)
	margin.add_theme_constant_override("margin_bottom", bottom)
	return margin


func _spacer(parent: Control, height: float) -> void:
	var space := Control.new()
	space.custom_minimum_size.y = height
	space.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(space)


func _setup_toast() -> void:
	_toast_panel = _panel(true)
	_toast_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_toast_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	_toast_panel.offset_left = -310
	_toast_panel.offset_right = 310
	_toast_panel.offset_top = -226
	_toast_panel.offset_bottom = -160
	_root.add_child(_toast_panel)
	_toast_label = _label("", 16, CREAM)
	_toast_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_toast_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_toast_panel.add_child(_toast_label)
	_toast_panel.hide()


func _apply_scale(node: Node) -> void:
	_ui_theme.default_font_size = roundi(16 * _ui_scale)
	if node is Control and node.has_meta("base_font_size"):
		node.add_theme_font_size_override("font_size", roundi(float(node.get_meta("base_font_size")) * _ui_scale))
		if node is Button:
			node.custom_minimum_size.y = maxf(40, 44 * _ui_scale)
	for child in node.get_children():
		_apply_scale(child)


func _load_settings() -> void:
	_touch_enabled = OS.has_feature("mobile") or DisplayServer.is_touchscreen_available()
	# Only first launch on the identified high-end GPU family gets the HIGH
	# recommendation. Existing saved preferences are never overwritten.
	_quality = GraphicsPolicy.recommended_profile(OS.has_feature("android"), RenderingServer.get_video_adapter_name())
	var config := ConfigFile.new()
	if config.load(SETTINGS_PATH) == OK:
		_ui_scale = clampf(float(config.get_value("interface", "scale", 1.0)), 0.85, 1.25)
		_reduce_motion = bool(config.get_value("interface", "reduce_motion", false))
		_opening_reading = bool(config.get_value("interface", "opening_reading", false))
		_volume = clampf(float(config.get_value("audio", "volume", 0.55)), 0.0, 1.0)
		_music_volume = clampf(float(config.get_value("audio", "music", 0.7)), 0.0, 1.0)
		_intro_seen = bool(config.get_value("interface", "intro_seen", false))
		_always_intro = bool(config.get_value("interface", "always_intro", false))
		_touch_enabled = bool(config.get_value("input", "touch_controls", _touch_enabled))
		_diagnostics = bool(config.get_value("graphics", "diagnostics", false))
		_quality = String(config.get_value("graphics", "quality", _quality))
		if _quality not in ["low", "balanced", "high", "very_high"]:
			_quality = "balanced"
	_apply_volume()


func _apply_display_settings() -> void:
	var display := get_node_or_null("/root/RuntimeDisplay")
	if is_instance_valid(display):
		display.apply_quality(_quality)
		display.set_diagnostics(_diagnostics)


func _save_settings() -> void:
	var config := ConfigFile.new()
	config.set_value("interface", "scale", _ui_scale)
	config.set_value("interface", "reduce_motion", _reduce_motion)
	config.set_value("interface", "opening_reading", _opening_reading)
	config.set_value("audio", "volume", _volume)
	config.set_value("audio", "music", _music_volume)
	config.set_value("interface", "intro_seen", _intro_seen)
	config.set_value("interface", "always_intro", _always_intro)
	config.set_value("input", "touch_controls", _touch_enabled)
	config.set_value("graphics", "quality", _quality)
	config.set_value("graphics", "diagnostics", _diagnostics)
	if config.save(SETTINGS_PATH) != OK:
		notify("Die Einstellungen konnten nicht auf diesem Gerät gespeichert werden.")


func _apply_volume() -> void:
	var bus := AudioServer.get_bus_index("Master")
	if bus >= 0:
		AudioServer.set_bus_mute(bus, _volume <= 0.001)
		AudioServer.set_bus_volume_db(bus, linear_to_db(maxf(0.001, _volume)))


func _setup_sound() -> void:
	_sound_player = AudioStreamPlayer.new()
	_sound_player.name = "InterfaceSound"
	_sound_player.volume_db = -12
	add_child(_sound_player)
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = 22050
	stream.stereo = false
	var count := 1323
	var samples := PackedByteArray()
	samples.resize(count * 2)
	for index in range(count):
		var time := float(index) / 22050.0
		var envelope := sin(PI * float(index) / float(count)) * exp(-time * 55.0)
		var wave := sin(TAU * 720.0 * time) + 0.25 * sin(TAU * 1080.0 * time)
		samples.encode_s16(index * 2, int(wave * envelope * 14000.0))
	stream.data = samples
	_sound_player.stream = stream


func _setup_music() -> void:
	_music_player = AudioStreamPlayer.new()
	_music_player.name = "MenuMusic"
	AudioBuses.ensure_layout()
	_music_player.bus = AudioBuses.MUSIC
	var stream: AudioStreamOggVorbis = load(RomanStyle.MUSIC_PATH)
	stream.loop = true
	_music_player.stream = stream
	add_child(_music_player)
	_apply_music_volume()


func _apply_music_volume() -> void:
	if is_instance_valid(_music_player) and _music_wanted:
		_music_player.volume_db = _music_db()


func _music_db() -> float:
	return MENU_MUSIC_DB + linear_to_db(maxf(0.001, _music_volume))


func _update_music(screen_name: String) -> void:
	var wanted := _music_wanted
	match screen_name:
		"intro": wanted = not _intro_full_pending
		"menu": wanted = true
		"settings": wanted = _settings_return == "menu"
		"gallery": wanted = _gallery_from == "menu"
		"confirm": wanted = _confirm_return == "menu"
		"dialog": pass
		_: wanted = false
	if wanted == _music_wanted:
		return
	_music_wanted = wanted
	if not is_instance_valid(_music_player):
		return
	if _music_tween != null and _music_tween.is_valid():
		_music_tween.kill()
	if not RomanStyle.audio_available():
		return
	if wanted:
		_music_player.volume_db = -60.0
		if not _music_player.playing:
			_music_player.play()
		_music_tween = create_tween()
		_music_tween.tween_property(_music_player, "volume_db", _music_db(), 1.5)
	else:
		_music_tween = create_tween()
		_music_tween.tween_property(_music_player, "volume_db", -60.0, 1.2)
		_music_tween.tween_callback(_music_player.stop)


func _replay_intro() -> void:
	var always := _always_intro
	_always_intro = true
	show_intro()
	_always_intro = always


func _play_click() -> void:
	if DisplayServer.get_name() == "headless":
		return
	if _sound_player != null and _volume > 0.001:
		_sound_player.play()
