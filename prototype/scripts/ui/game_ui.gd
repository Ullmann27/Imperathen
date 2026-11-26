extends CanvasLayer
## UI owns presentation and preferences; the entry point owns world pause and commands.

signal action_requested(action: String, payload: Dictionary)

const CREAM := Color("eadfc9")
const MUTED := Color("b9b4a7")
const BRONZE := Color("b99563")
const CRIMSON := Color("722b32")
const INK := Color("111a1b")
const SETTINGS_PATH := "user://imperathen_ui.cfg"
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
## Interior of the family home (baker_home at (-13, 11), walls inset).
const FAMILY_HOME := Rect2(-15.6, 8.9, 5.2, 4.2)
const VillagePanel = preload("res://scripts/ui/village_life_panel.gd")
const Childhood = preload("res://scripts/story/village_childhood.gd")
const Navigation = preload("res://scripts/ui/village_navigation.gd")
const RomanStyle = preload("res://scripts/ui/roman_style.gd")
const ImperialIntro = preload("res://scripts/ui/imperial_intro.gd")
const Fx = preload("res://scripts/ui/imperial_fx.gd")
const MenuGradeShader = preload("res://shaders/menu_grade.gdshader")
const HudStyle = preload("res://scripts/ui/roman_hud/hud_style.gd")
const HudIcons = preload("res://scripts/ui/roman_hud/hud_icons.gd")
const MedallionScript = preload("res://scripts/ui/roman_hud/medallion_button.gd")
const CompassRibbon = preload("res://scripts/ui/roman_hud/compass_ribbon.gd")
const HudDirector = preload("res://scripts/ui/roman_hud/hud_director.gd")
const VitalsScript = preload("res://scripts/ui/roman_hud/vitals.gd")
const MenuKit = preload("res://scripts/ui/roman_hud/menu_kit.gd")
const DialogueStage = preload("res://scripts/ui/roman_hud/dialogue_stage.gd")
const Codex = preload("res://scripts/ui/roman_hud/codex.gd")
## Screens built with the Roman HUD kit carry the text scale in their own
## scale; the remaining screens scale their fonts individually.
const HUD_SCREENS := ["game", "dialog", "frontier_dialog", "pause", "journal"]
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
## Roman HUD: layout units per logical unit of the open screen, presence
## director, on-demand map, vitals, context prompt and the codex tab.
var _screen_scale := 1.0
var _director: Node
var _local_map: Control
var _vitals: Control
var _prompt_panel: PanelContainer
var _prompt_label: Label
var _prompt_key: Label
var _mission_card: PanelContainer
var _alert: Label
var _context := ""
var _journal_tab := "chronicle"
var _hud: Dictionary = {}
var _chrome_buttons: Array[Button] = []
var _chrome_compact := false


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
	_director = HudDirector.new()
	_director.name = "HudDirector"
	add_child(_director)
	_root.resized.connect(_fit_screen)
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
	var area := _area()
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
	var area := _area()
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
	var entering := _view_state != "game"
	_open_screen("game", false)
	_hud_labels.clear()
	_action_buttons.clear()
	_mode_buttons.clear()
	_director.reduce_motion = _reduce_motion
	_hud = _hud_layout()
	_build_top_bar()
	_build_objective_card()
	_build_navigation()
	_build_character_card()
	_build_vitals()
	_build_toolbar()
	_build_touch_controls()
	_build_prompt()
	_place_hud()
	update_state(state)
	set_mode(_mode)
	if entering:
		_director.greet()
		_animate_hud_in()
	_emit("touch_camera_managed", {"enabled": _touch_enabled})
	_emit("select_technique", {"technique": _selected_technique})


## HUD geometry in dp. Calm exploration keeps the centre of the frame free:
## guidance sits on the upper edge, controls in the thumb zones, everything
## else appears only when it is needed (HB 3.0: Inventar, Karte und Journal
## erst bei Bedarf; HUD nicht über wichtige Interaktionspunkte).
func _hud_layout() -> Dictionary:
	var area := _area()
	var gutter := 12.0 if _touch_enabled else 20.0
	var top := 8.0 if _touch_enabled else 16.0
	var layout := {"area": area, "gutter": gutter, "top": top, "portrait": area.y > area.x * 1.15}
	if _touch_enabled:
		var pad := clampf(area.y * 0.34, 156.0, 208.0)
		pad = minf(pad, maxf(156.0, area.x * 0.42))
		# Raised from the system gesture edge by at least 88 logical units.
		var lift := maxf(72.0, 88.0 / _screen_scale)
		layout.pad = Rect2(gutter, area.y - lift - pad, pad, pad)
		layout.lift = lift
		layout.dock_height = 56.0
	return layout


func _animate_hud_in() -> void:
	if _reduce_motion or not is_instance_valid(_screen):
		return
	var delay := 0.0
	for id in ["ObjectiveCard", "VillageCompass", "ResourceBar", "TouchToolbar", "ActionDock", "MovementPad", "TouchActions"]:
		var node := _screen.get_node_or_null(id) as Control
		if node == null:
			continue
		var slide := Vector2(0, -10) if id in ["ObjectiveCard", "VillageCompass", "ResourceBar"] else Vector2(0, 12)
		var tween := node.create_tween().set_parallel(true).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		var home := node.position
		node.position = home + slide
		var target_alpha := node.modulate.a
		node.modulate.a = 0.0
		tween.tween_property(node, "position", home, HudStyle.MOTION_SLOW).set_delay(delay)
		tween.tween_property(node, "modulate:a", target_alpha, HudStyle.MOTION_BASE).set_delay(delay)
		delay += 0.04


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
	if Childhood.enabled(state):
		# A twelve-year-old has a family, not a troop (HB 3.0 S. 13/44).
		_hud_labels["squad"].text = _family_line(state)
	var stamina := float(CombatActions.view(state).get("stamina", 100.0)) if CombatActions.enabled(state) else 100.0
	if _hud_labels.has("compact_life"):
		_hud_labels["compact_life"].text = "Leben %d/100  ·  Truppe %d/%d" % [int(health), int(squad.get("alive", 0)), int(squad.get("recruits", 0))]
		if Childhood.enabled(state):
			_hud_labels["compact_life"].text = "Leben %d · Ausdauer %d" % [int(health), int(stamina)]
			if _child_first_mission(state):
				var carried: Array = state.get("childhood_view", {}).get("carried", [])
				_hud_labels["compact_life"].text = "Du trägst: " + ", ".join(carried) if not carried.is_empty() else ""
			_hud_labels["compact_life"].visible = not _hud_labels["compact_life"].text.is_empty() and not (_touch_enabled and _area().y < 470)
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
		# No military menu for the child (HB 3.0 S. 13: "Keine Waffe und kein Militärmenü").
		for key in ["build", "train", "recruit", "skirmish"]:
			_action_buttons[key].hide()
	var calm_child := _child_first_mission(state)
	for metric: String in ["wood", "grain", "denarii"]:
		# The village stock is not the child's property; it stays in the village
		# panel and the chronicle instead of occupying the first-mission HUD.
		_hud_labels[metric].visible = not calm_child
	if is_instance_valid(_life_panel):
		_life_panel.visible = not _compact_layout and _mode != "person" and not calm_child
	if is_instance_valid(_chronicle_panel):
		_chronicle_panel.visible = not _compact_layout and _mode != "person" and not calm_child
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
	var danger := _danger(state)
	if is_instance_valid(_alert):
		# Danger and its count-down sit under the compass; calm leaves it empty.
		_alert.visible = danger or ended
	if is_instance_valid(_vitals):
		_vitals.health = health
		_vitals.stamina = stamina
		_vitals.show_stamina = CombatActions.enabled(state)
	var announce := 0.0
	if is_instance_valid(_navigation):
		announce = float(_navigation.announce)
	_director.observe({"objective": objective[0] + "|" + objective[1], "resources": {"wood": int(resources.get("wood", 0)), "grain": int(resources.get("grain", 0)), "denarii": int(resources.get("denarii", 0))},
		"health": int(health), "stamina": stamina, "danger": danger, "mode": _mode, "build": _build_active,
		"overlay": _touch_overlay_open(), "prompt": _context, "announce": announce, "no_stock": calm_child})
	_update_combat_controls()
	_update_touch_visibility()


func _danger(state: Dictionary) -> bool:
	if bool(state.get("encounter", {}).get("active", false)):
		return true
	var raid: Dictionary = state.get("village", {}).get("raid", {})
	return bool(raid.get("active", false)) or str(raid.get("status", "")) == "warning"


## I-01 for the child: no combat buttons, no troop/morale, no village stock on
## screen unless danger is actually present (HB 3.0 S. 13 and S. 44).
func _child_first_mission(state: Dictionary) -> bool:
	if not Childhood.enabled(state):
		return false
	if bool(state.get("village", {}).get("raid", {}).get("active", false)) or bool(state.get("encounter", {}).get("active", false)):
		return false
	return bool(state.get("childhood_view", {}).get("in_first_mission", false))


func _family_line(state: Dictionary) -> String:
	var relations: Dictionary = state.get("childhood_view", {}).get("relationships", {})
	var parts: Array[String] = []
	for id: String in ["julia", "silvanus"]:
		if relations.has(id):
			parts.append("%s · Vertrauen %d" % [{"julia":"Julia", "silvanus":"Silvanus"}[id], int(relations[id].get("trust", 0))])
	return "Familie\n" + "\n".join(parts) if not parts.is_empty() else "Familie"


func show_pause() -> void:
	_open_screen("pause", true)
	var area := _area()
	var child := Childhood.enabled(_state)
	var wide := area.x >= 880.0 and area.x > area.y
	var width := minf(430.0, area.x - 32.0)
	var margin := clampf(minf(area.x, area.y) * 0.05, 16.0, 56.0)
	var tablet := PanelContainer.new()
	tablet.name = "PauseTablet"
	tablet.mouse_filter = Control.MOUSE_FILTER_STOP
	tablet.add_theme_stylebox_override("panel", HudStyle.plaque(true, Vector4(26, 20, 26, 18), 0.9))
	_screen.add_child(tablet)
	var scroll := ScrollContainer.new()
	scroll.name = "PauseScroll"
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.follow_focus = true
	tablet.add_child(scroll)
	var column := VBoxContainer.new()
	column.mouse_filter = Control.MOUSE_FILTER_PASS
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.add_theme_constant_override("separation", 8)
	scroll.add_child(column)
	column.add_child(HudStyle.kicker("PAUSA", HudStyle.TYPE_CAPTION))
	var heading := HudStyle.label("Ein Augenblick Ruhe", 28, HudStyle.AURUM_LIGHT, true, 2)
	heading.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(heading)
	var lead := HudStyle.label("Die Welt wartet. Dein nächster Schritt gehört dir.", HudStyle.TYPE_BODY, HudStyle.CHARTA_MUTED)
	lead.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(lead)
	column.add_child(MenuKit.Rule.new())
	var resume_button := _tablet_button("Weiterspielen", func(): _emit("resume"), true)
	column.add_child(resume_button)
	column.add_child(_tablet_button("Chronik", func(): _show_journal(false)))
	if _state.get("village", {}).get("enabled", false):
		column.add_child(_tablet_button("Dorfleben und Wiederaufbau", _emit.bind("village_panel", {})))
	column.add_child(_tablet_button("Weltkugel", func(): _emit("atlas")))
	if not child:
		# The regional legion is an adult career step; the child never sees it.
		var legion := _tablet_button("Grenzlegion im Tal", func(): _emit("valley"))
		legion.disabled = not bool(_state.get("progress", {}).get("skirmish_won", false)) or not _state.get("story", {}).get("choices", []).is_empty()
		legion.tooltip_text = "Verteidige zuerst das Dorf und entscheide über seine Zukunft." if legion.disabled else "Befehle die regionale Legion. Deine Dorftruppe bleibt zu Hause."
		column.add_child(legion)
		if legion.disabled:
			var requirement := HudStyle.label("Nach erfolgreicher Dorfverteidigung und Folgeentscheidung verfügbar.", HudStyle.TYPE_CAPTION, HudStyle.CHARTA_MUTED)
			requirement.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			column.add_child(requirement)
	column.add_child(_tablet_button("Spiel speichern", func(): _emit("save")))
	column.add_child(_tablet_button("Einstellungen", func(): _show_settings("pause")))
	column.add_child(_tablet_button("Zum Hauptmenü", func(): _emit("menu")))
	column.add_child(_tablet_button("Spiel beenden", func(): _confirm("Spiel beenden?", "Dein aktueller Spielstand wird vor dem Beenden gespeichert.", "quit", {})))
	var height := minf(area.y - margin * 2.0, 760.0)
	var x := margin if wide else (area.x - width) * 0.5
	tablet.position = Vector2(x, (area.y - height) * 0.5)
	tablet.size = Vector2(width, height)
	column.minimum_size_changed.connect(_fit_tablet.bind(tablet, column, Rect2(x, margin, width, area.y - margin * 2.0)))
	_fit_tablet.call_deferred(tablet, column, Rect2(x, margin, width, area.y - margin * 2.0))
	if wide:
		_pause_situation(Rect2(x + width + margin, margin, minf(460.0, area.x - x - width - margin * 2.0), area.y - margin * 2.0))
	HudStyle.reveal(tablet, _reduce_motion, 0.0, Vector2.ZERO)
	var delay := 0.06
	for child_node: Node in column.get_children():
		if child_node is Button:
			HudStyle.reveal(child_node as Control, _reduce_motion, delay, Vector2.ZERO)
			delay += 0.03
	resume_button.grab_focus.call_deferred()


## Situation beside the pause tablet: where you are in the story, the day and
## the people closest to you - read-only, so a pause can also be a reminder.
func _pause_situation(rect: Rect2) -> void:
	if rect.size.x < 260.0:
		return
	var card := PanelContainer.new()
	card.name = "PauseSituation"
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_theme_stylebox_override("panel", HudStyle.velum(0, Vector4(22, 16, 40, 18), 0.5, true))
	card.position = Vector2(rect.position.x, rect.position.y + rect.size.y * 0.18)
	card.size = Vector2(rect.size.x, 0)
	_screen.add_child(card)
	var column := VBoxContainer.new()
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_theme_constant_override("separation", 6)
	card.add_child(column)
	var objective := _objective(_state)
	column.add_child(HudStyle.kicker("DEIN NÄCHSTER SCHRITT"))
	var title := HudStyle.label(objective[0], HudStyle.TYPE_TITLE, HudStyle.CHARTA, true, 1)
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(title)
	var text := HudStyle.label(objective[1], HudStyle.TYPE_BODY, HudStyle.CHARTA_MUTED)
	text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(text)
	column.add_child(MenuKit.Rule.new())
	var player: Dictionary = _state.get("player", {})
	var lines: Array[String] = ["%d Jahre · Leben %d / 100" % [int(player.get("age", 12)), int(player.get("health", 100))]]
	if Childhood.enabled(_state):
		lines.append(_family_line(_state).replace("\n", " · "))
	var companion: Dictionary = _state.get("companion", {})
	if bool(companion.get("met", false)):
		lines.append("%s · Vertrauen %+d" % [_companion_name(_state), int(companion.get("trust", 0))])
	for line in lines:
		var item := HudStyle.label(line, HudStyle.TYPE_CAPTION + 1, HudStyle.CHARTA_MUTED)
		item.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		column.add_child(item)
	HudStyle.reveal(card, _reduce_motion, 0.12, Vector2(12, 0))


## Roman tabula button for menus in the HUD kit (fonts in dp, the screen scales).
func _tablet_button(text: String, callback: Callable, primary := false) -> Button:
	var button := Button.new()
	button.text = text
	RomanStyle.style_button(button, primary, 17)
	button.custom_minimum_size = Vector2(0, 52)
	button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	# Inside the pause scroll: a swipe scrolls and cancels the press.
	button.mouse_filter = Control.MOUSE_FILTER_PASS
	button.pressed.connect(func():
		_play_click()
		callback.call()
	)
	return button


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
	var entries: Array = []
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
		var enabled := bool(entry.get("enabled", true)) if entry is Dictionary else true
		var reason := str(entry.get("reason", "")) if entry is Dictionary else ""
		entries.append({"caption": caption, "enabled": enabled, "reason": reason,
			"callback": func():
				_play_click()
				_emit(action, payload)})
	var close := {}
	if choices.is_empty():
		close = {"caption": "Zurück ins Spiel", "name": "DialogResume", "callback": func():
			_play_click()
			_emit("resume")}
	var named := speaker != ""
	var built := DialogueStage.build(_screen, {"name": "DialogStage", "scroll_name": "DialogScroll",
		"kicker": "DEINE ENTSCHEIDUNG", "speaker": FigureGallery.caption(speaker).name if named else title,
		"role": ("Begegnung · " + title) if named else "", "text": text,
		"note": "Die Welt ist während dieses Gesprächs pausiert.",
		"portrait": FigureGallery.texture(speaker) if named else null, "portrait_name": "Speaker_" + speaker,
		"choices": entries, "close": close, "area": _area(), "reduce_motion": _reduce_motion})
	var first: Button = built.first
	if first != null:
		first.grab_focus.call_deferred()


func show_frontier_dialog(dialog: Dictionary) -> void:
	clear_notification()
	_frontier_dialog_data = dialog.duplicate(true)
	_open_screen("frontier_dialog", false)
	_screen.mouse_filter = Control.MOUSE_FILTER_STOP
	var title := str(dialog.get("title", "Ein Gespräch im Dorf"))
	# "Name · Rolle" becomes a nameplate: the person large, the role beneath.
	var speaker := title
	var role := ""
	var split := title.find(" · ")
	if split > 0:
		speaker = title.substr(0, split)
		role = title.substr(split + 3)
	var entries: Array = []
	for value in dialog.get("choices", []):
		if not value is Dictionary:
			continue
		var entry: Dictionary = value
		var choice_id := str(entry.get("id", ""))
		var payload := {"npc_id": str(dialog.get("npc_id", "")), "choice": choice_id}
		var action := "frontier_choice"
		var meta := {}
		if entry.has("command"):
			action = "village_command"
			payload = {"command":entry.command, "args":entry.get("payload", {})}
			meta = {"village_command": str(entry.command), "village_args": entry.get("payload", {}).duplicate(true)}
		entries.append({"caption": str(entry.get("label", "Antworten")), "name": "FrontierChoice_" + choice_id,
			"enabled": bool(entry.get("enabled", true)), "reason": str(entry.get("reason", "")), "meta": meta,
			"callback": func():
				_play_click()
				_emit(action, payload)})
	var close_action := str(dialog.get("close_action", "frontier_close"))
	var built := DialogueStage.build(_screen, {"name": "FrontierConversation", "scroll_name": "FrontierConversationScroll",
		"kicker": str(dialog.get("kicker", "DIE STRASSE ZUR LEGION")), "speaker": speaker, "role": role,
		"text": str(dialog.get("text", "")), "feedback": str(dialog.get("feedback", "")),
		"choices": entries, "area": _area(), "reduce_motion": _reduce_motion,
		"close": {"caption": "Gespräch beenden", "name": "FrontierConversationClose", "callback": func():
			_play_click()
			_emit(close_action, {})}})
	var first: Button = built.first
	if first != null:
		first.grab_focus.call_deferred()


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
	if _view_state != "game":
		return
	_set_context(str(value.get("context", "")))
	_update_chrome()
	if not is_instance_valid(_navigation):
		return
	_navigation.update_view(value)
	if is_instance_valid(_local_map):
		_local_map.update_view(value)
	# HB 3.0 S. 44: the map appears when it helps. While the child's first
	# mission keeps both the boy and his goal inside the family home, the
	# compass steps aside; it returns as soon as either is outside.
	var in_home := func(point: Variant) -> bool:
		return typeof(point) == TYPE_VECTOR2 and FAMILY_HOME.has_point(point)
	_navigation.visible = not (_child_first_mission(_state) and in_home.call(value.get("player")) and in_home.call(value.get("target")))
	if not _navigation.visible and is_instance_valid(_local_map):
		_local_map.hide()


## Context-dependent interaction: the world reports what "interact" would do
## right now; the touch medallion names it and lights up, the desktop shows a
## key prompt. Without a context the action rests, dimmed.
func _set_context(text: String) -> void:
	var cleaned := text.strip_edges()
	if cleaned == _context:
		return
	_context = cleaned
	var caption := _interaction_caption(cleaned)
	for button: Button in _touch_actions:
		if is_instance_valid(button) and str(button.get_meta("touch_action", "")) == "interact":
			button.text = caption if not caption.is_empty() else "Interagieren"
			if "lit" in button:
				button.lit = 1.0 if not caption.is_empty() else 0.0
	if is_instance_valid(_prompt_label):
		var keyed := not cleaned.begins_with("LMB")
		var shown := cleaned.trim_prefix("E · ").trim_prefix("Interagieren · ").trim_prefix("LMB / Leertaste · ").replace("\n", " · ")
		_prompt_label.text = shown
		_prompt_key.text = "E" if keyed else "LMB"
	if is_instance_valid(_director):
		_director.context["prompt"] = cleaned


func _interaction_caption(text: String) -> String:
	if text.is_empty() or text.begins_with("LMB") or text.begins_with("Ausbildung abgeschlossen"):
		return ""
	var first := text.get_slice("\n", 0).trim_prefix("E · ").trim_prefix("Interagieren · ")
	return first.strip_edges()


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
	# A short Roman notice under the top edge of the HUD; it never covers the
	# thumb controls or the middle of the frame.
	var scale_factor := _screen_scale if _view_state in HUD_SCREENS else HudStyle.units_per_dp(get_viewport())
	var area := _root.size / maxf(0.01, scale_factor)
	var width := minf(560.0, area.x - 32.0)
	_toast_panel.scale = Vector2.ONE * scale_factor
	_toast_panel.size = Vector2(width, 0)
	_toast_label.custom_minimum_size.x = width - 44.0
	var top := float(_hud.get("toast_top", 72.0)) if _view_state == "game" else area.y * 0.12
	_toast_panel.position = Vector2((area.x - width) * 0.5 * scale_factor, top * scale_factor)
	_toast_panel.show()
	_toast_panel.modulate.a = 1.0
	_toast_tween = create_tween()
	if not _reduce_motion:
		_toast_panel.modulate.a = 0.0
		_toast_tween.tween_property(_toast_panel, "modulate:a", 1.0, HudStyle.MOTION_BASE)
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
		button.set_meta("plaque_active", key == mode)
		HudStyle.style_plaque_button(button, false, HudStyle.TYPE_CAPTION + 1, key == mode)
		if bool(button.get_meta("compact", false)):
			_icon_only(button)
	if is_instance_valid(_director) and _director.context.get("mode", mode) != mode:
		_director.wake("dock", 6.0)
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
	var calm_child := _child_first_mission(_state)
	_life_panel.visible = not _compact_layout and mode != "person" and not calm_child
	_chronicle_panel.visible = _life_panel.visible
	_hud_labels.compact_life.visible = not _life_panel.visible and not _hud_labels.compact_life.text.is_empty() and not (_touch_enabled and _area().y < 470)
	_action_buttons["atlas"].visible = mode == "map"
	_hud_labels["controls"].text = hints[mode]
	var objective := _objective(_state)
	_hud_labels["objective_title"].text = objective[0]
	_hud_labels["objective_text"].text = objective[1]
	_update_map_objective()
	if is_instance_valid(_director):
		_director.context["mode"] = mode
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
	_local_map = null
	_vitals = null
	_prompt_panel = null
	_prompt_label = null
	_prompt_key = null
	_mission_card = null
	_alert = null
	_context = ""
	_chrome_buttons.clear()
	_chrome_compact = false
	if is_instance_valid(_director):
		_director.clear()
	if _screen != null:
		_screen.hide()
		_screen.queue_free()
	_view_state = screen_name
	_update_music(screen_name)
	# Density-independent layout: one dp is the same physical size on every
	# display. Screens built with the Roman HUD kit also carry the text scale;
	# the title screens keep their own portrait compensation.
	var dp := HudStyle.units_per_dp(get_viewport())
	_screen_scale = 1.0 if screen_name in ["intro", "menu", "gallery"] else dp * (_ui_scale if screen_name in HUD_SCREENS else 1.0)
	var viewport_size := _area()
	_compact_layout = _touch_enabled or viewport_size.x < 1120 or viewport_size.y < 640
	_screen = Control.new()
	_screen.name = screen_name.capitalize()
	_root.add_child(_screen)
	_fit_screen()
	_screen.mouse_filter = Control.MOUSE_FILTER_STOP if darken else Control.MOUSE_FILTER_IGNORE
	_root.move_child(_toast_panel, -1)
	if darken:
		if menu_style or screen_name in ["intro", "menu", "gallery"]:
			var atmosphere := Atmosphere.new()
			atmosphere.menu_style = menu_style
			atmosphere.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
			_screen.add_child(atmosphere)
		else:
			# The live world stays recognisable behind a menu, graded and calmed.
			var backdrop := MenuKit.Backdrop.new()
			backdrop.name = "Backdrop"
			backdrop.darkness = 0.28 if screen_name == "dialog" else 0.64 if screen_name in ["village", "settings", "confirm"] else 0.52
			backdrop.desaturate = 0.35 if screen_name == "dialog" else 0.72
			backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
			_screen.add_child(backdrop)
			backdrop.animate(_reduce_motion)


func _fit_screen() -> void:
	if not is_instance_valid(_screen) or not is_instance_valid(_root):
		return
	if is_equal_approx(_screen_scale, 1.0):
		_screen.scale = Vector2.ONE
		_screen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		return
	_screen.set_anchors_preset(Control.PRESET_TOP_LEFT)
	_screen.position = Vector2.ZERO
	_screen.scale = Vector2.ONE * _screen_scale
	_screen.size = _root.size / _screen_scale


## Size of the open screen in its own layout units (dp for scaled screens).
func _area() -> Vector2:
	var full := _root.size if is_instance_valid(_root) else get_viewport().get_visible_rect().size
	return full / maxf(0.01, _screen_scale)


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


## Command corner (top right): the village stock as engraved chips that only
## appear when it changes or matters, the day, the chronicle and pause.
## Plaques carry their names where there is room and become glyphs on narrow
## displays; the readable name always stays the button's text.
func _build_top_bar() -> void:
	var area: Vector2 = _hud.area
	var panel := PanelContainer.new()
	panel.name = "ResourceBar"
	panel.mouse_filter = Control.MOUSE_FILTER_PASS
	panel.add_theme_stylebox_override("panel", HudStyle.velum(1, Vector4(30, 0, 0, 0), 0.42, false))
	_screen.add_child(panel)
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_PASS
	row.add_theme_constant_override("separation", 6)
	row.alignment = BoxContainer.ALIGNMENT_END
	panel.add_child(row)
	# The stock sits on its own line under the corner and rests while unchanged.
	var stock := PanelContainer.new()
	stock.name = "ResourceChips"
	stock.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stock.add_theme_stylebox_override("panel", HudStyle.velum(1, Vector4(30, 2, 4, 2), 0.42, false))
	_screen.add_child(stock)
	var chips := HBoxContainer.new()
	chips.mouse_filter = Control.MOUSE_FILTER_IGNORE
	chips.add_theme_constant_override("separation", 12)
	stock.add_child(chips)
	for entry: Array in [["wood", "wood"], ["grain", "grain"], ["denarii", "coin"]]:
		var chip := HBoxContainer.new()
		chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
		chip.add_theme_constant_override("separation", 3)
		chips.add_child(chip)
		var glyph := TextureRect.new()
		glyph.texture = HudIcons.texture(entry[1], roundi(18 * _screen_scale), 1.5)
		glyph.custom_minimum_size = Vector2(18, 18)
		glyph.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		glyph.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		glyph.self_modulate = HudStyle.AURUM
		glyph.mouse_filter = Control.MOUSE_FILTER_IGNORE
		glyph.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		chip.add_child(glyph)
		var metric := HudStyle.label("", HudStyle.TYPE_CAPTION + 1, HudStyle.CHARTA)
		metric.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		metric.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		chip.add_child(metric)
		_hud_labels[entry[0]] = metric
		# Hiding a metric hides its glyph with it.
		metric.visibility_changed.connect(_follow_visibility.bind(metric, glyph))
	_director.register("resources", stock, true)
	stock.minimum_size_changed.connect(_anchor_top_right.bind(stock, Vector2(area.x - float(_hud.gutter), float(_hud.top) + 54.0), 0.0))
	_anchor_top_right(stock, Vector2(area.x - float(_hud.gutter), float(_hud.top) + 54.0), 0.0)
	# Widest day caption, so the corner is measured before the state fills it.
	var time := HudStyle.kicker("TAG 00  ·  00:00", HudStyle.TYPE_MICRO + 1, HudStyle.CHARTA_MUTED)
	time.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	time.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(time)
	_hud_labels["time"] = time
	_director.register("time", time)
	var buttons: Array[Button] = []
	buttons.append(_hud_button("Chronik", _show_journal, "chronicle"))
	if not _compact_layout:
		buttons.append(_hud_button("Speichern", func(): _emit("save"), "save"))
	buttons.append(_hud_button("Pause" if _compact_layout else "Pause  ·  Esc", func(): _emit("pause"), "pause"))
	for button in buttons:
		button.name = "Corner_" + button.text.get_slice(" ", 0)
		row.add_child(button)
		_director.register("corner", button)
		_chrome_buttons.append(button)
	# Fit: names when there is room beside compass and objective, glyphs otherwise.
	var compass_width := clampf(area.x * 0.26, 220.0, 340.0)
	var room := func() -> float:
		return area.x - 2.0 * float(_hud.gutter) - row.get_combined_minimum_size().x - 30.0 - compass_width - 2.0 * HudStyle.GAP
	time.visible = area.x >= 1100.0
	if room.call() < 230.0:
		for button in buttons:
			_icon_only(button)
			button.set_meta("always_compact", true)
	if room.call() < 230.0:
		time.visible = false
	var width := row.get_combined_minimum_size().x + 30.0
	panel.position = Vector2(area.x - _hud.gutter - width, _hud.top)
	panel.size = Vector2(width, 48.0)
	_hud.corner = Rect2(panel.position, panel.size)
	# Stay anchored to the right edge when the day label changes its width.
	panel.minimum_size_changed.connect(_anchor_top_right.bind(panel, Vector2(area.x - float(_hud.gutter), float(_hud.top)), 48.0))
	_hud.compass_width = compass_width
	_hud.single_row = room.call() >= 230.0


## Command plaque for the HUD; touch layouts use the multitouch-safe button.
func _hud_button(text: String, callback: Callable, glyph := "", primary := false) -> Button:
	var button: Button = TouchActionScript.new() if _touch_enabled else Button.new()
	button.text = text
	button.set_meta("plaque_primary", primary)
	HudStyle.style_plaque_button(button, primary, HudStyle.TYPE_CAPTION + 1)
	if not glyph.is_empty():
		button.icon = HudIcons.texture(glyph, roundi(20 * _screen_scale), 1.6)
		button.expand_icon = false
		button.add_theme_constant_override("icon_max_width", 20)
	button.custom_minimum_size = Vector2(0, HudStyle.TOUCH_MIN if _touch_enabled else 40.0)
	button.mouse_filter = Control.MOUSE_FILTER_STOP
	button.tooltip_text = text
	button.pressed.connect(func():
		_play_click()
		callback.call()
	)
	return button


## Glyph-only plaque on narrow displays and while exploration is calm; the
## name stays as text and tooltip. `_plaque_labels` brings the name back.
func _icon_only(button: Button) -> void:
	button.set_meta("compact", true)
	button.clip_text = true
	button.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	for color in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_disabled_color", "font_outline_color"]:
		button.add_theme_color_override(color, Color(0, 0, 0, 0))
	button.custom_minimum_size.x = 52.0
	for state in ["normal", "hover", "pressed", "disabled"]:
		var box := button.get_theme_stylebox(state)
		if box != null:
			box = box.duplicate()
			box.content_margin_left = 8
			box.content_margin_right = 8
			button.add_theme_stylebox_override(state, box)


func _plaque_labels(button: Button) -> void:
	button.set_meta("compact", false)
	button.clip_text = false
	button.icon_alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.custom_minimum_size.x = 0.0
	HudStyle.style_plaque_button(button, bool(button.get_meta("plaque_primary", false)), HudStyle.TYPE_CAPTION + 1, bool(button.get_meta("plaque_active", false)))


## Calm exploration shows command plaques as glyphs only; entering the game,
## a mode change or leaving calm brings their names back.
func _update_chrome() -> void:
	if not _touch_enabled or not is_instance_valid(_director) or _view_state != "game":
		return
	var compact: bool = _director.calm() and not _director.is_awake("controls_hint") and not _director.is_awake("dock")
	if compact == _chrome_compact:
		return
	_chrome_compact = compact
	for button: Button in _chrome_buttons:
		if not is_instance_valid(button) or bool(button.get_meta("always_compact", false)):
			continue
		if compact:
			_icon_only(button)
		else:
			_plaque_labels(button)


func _build_navigation() -> void:
	var area: Vector2 = _hud.area
	var corner: Rect2 = _hud.corner
	var width: float = _hud.compass_width
	var gutter: float = _hud.gutter
	var top: float = _hud.top
	var rect: Rect2
	if _hud.single_row:
		var x := clampf(area.x * 0.5 - width * 0.5, gutter + 230.0 + HudStyle.GAP, corner.position.x - HudStyle.GAP - width)
		rect = Rect2(x, top + 1.0, width, 46.0)
	else:
		width = minf(width, corner.position.x - HudStyle.GAP - gutter)
		rect = Rect2(gutter + (corner.position.x - HudStyle.GAP - gutter - width) * 0.5, top + 1.0, width, 46.0)
	_hud.compass = rect
	# Danger and count-downs read under the compass, in cinnabar.
	_alert = HudStyle.kicker("", HudStyle.TYPE_CAPTION, HudStyle.MINIUM.lightened(0.25))
	_alert.name = "AlertLine"
	_alert.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_alert.position = Vector2(rect.position.x - 60.0, rect.end.y + (14.0 if Childhood.enabled(_state) else -26.0))
	_alert.size = Vector2(rect.size.x + 120.0, 18.0)
	_alert.visible = false
	_screen.add_child(_alert)
	_hud_labels["status"] = _alert
	if not Childhood.enabled(_state):
		return
	_navigation = CompassRibbon.new()
	_navigation.name = "VillageCompass"
	_navigation.position = rect.position
	_navigation.size = rect.size
	_screen.add_child(_navigation)
	_director.register("compass", _navigation)
	var map_size := clampf(minf(area.x, area.y) * 0.36, 170.0, 250.0)
	_local_map = CompassRibbon.LocalMap.new()
	_local_map.name = "LocalMap"
	_local_map.size = Vector2(map_size, map_size)
	_local_map.position = Vector2(clampf(rect.get_center().x - map_size * 0.5, gutter, area.x - gutter - map_size), rect.end.y + 8.0)
	_local_map.visible = false
	_screen.add_child(_local_map)
	_navigation.map_requested.connect(_toggle_local_map)


## The local map opens from the compass and closes again by itself.
func _toggle_local_map() -> void:
	if not is_instance_valid(_local_map):
		return
	_local_map.visible = not _local_map.visible
	if _local_map.visible:
		_local_map.update_view(_navigation.view)
		_play_click()
		HudStyle.reveal(_local_map, _reduce_motion, 0.0, Vector2(0, -8))
		get_tree().create_timer(8.0).timeout.connect(_hide_later.bind(_local_map))


## Subtle mission line (top left): occasion and place in Roman capitals over a
## soft ink veil with a gilded rule. After a few seconds the detail rests and
## only the title stays; a new objective, danger or a tap brings it back.
func _build_objective_card() -> void:
	var area: Vector2 = _hud.area
	var gutter: float = _hud.gutter
	var corner: Rect2 = _hud.corner
	var width := clampf(area.x * 0.34, 230.0, 420.0)
	var top: float = _hud.top
	if _hud.single_row:
		width = minf(width, maxf(230.0, area.x * 0.5 - float(_hud.compass_width) * 0.5 - HudStyle.GAP - gutter))
		width = minf(width, corner.position.x - HudStyle.GAP - float(_hud.compass_width) - HudStyle.GAP - gutter)
	else:
		top = _hud.top + 56.0
		width = minf(area.x - gutter * 2.0, 520.0)
	var limit := area.y * 0.42
	if _touch_enabled:
		limit = (_hud.pad as Rect2).position.y - HudStyle.GAP - top
	var panel := PanelContainer.new()
	panel.name = "ObjectiveCard"
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	panel.add_theme_stylebox_override("panel", HudStyle.velum(0, Vector4(16, 7, 36, 9), 0.58, true))
	panel.position = Vector2(gutter, top)
	_screen.add_child(panel)
	_mission_card = panel
	var column := VBoxContainer.new()
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_theme_constant_override("separation", 2)
	panel.add_child(column)
	var lines := clampi(int((limit - 56.0) / 18.0), 0, 4)
	var kicker := HudStyle.kicker("AUFTRAG", HudStyle.TYPE_MICRO)
	kicker.name = "MissionKicker"
	column.add_child(kicker)
	_hud_labels["objective_title"] = HudStyle.label("", 18 if area.y >= 600 else 16, HudStyle.CHARTA, true, 1)
	_hud_labels["objective_title"].autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_hud_labels["objective_title"].max_lines_visible = 2 if lines >= 2 else 1
	_hud_labels["objective_title"].text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	column.add_child(_hud_labels["objective_title"])
	var detail := VBoxContainer.new()
	detail.name = "MissionDetail"
	detail.mouse_filter = Control.MOUSE_FILTER_IGNORE
	detail.add_theme_constant_override("separation", 3)
	column.add_child(detail)
	_hud_labels["objective_text"] = HudStyle.label("", HudStyle.TYPE_BODY - 1, HudStyle.CHARTA_MUTED)
	_hud_labels["objective_text"].autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_hud_labels["objective_text"].max_lines_visible = maxi(1, lines - 1)
	_hud_labels["objective_text"].text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	detail.add_child(_hud_labels["objective_text"])
	_hud_labels["compact_life"] = HudStyle.label("", HudStyle.TYPE_CAPTION + 1, HudStyle.AURUM)
	_hud_labels["compact_life"].autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_hud_labels["compact_life"].max_lines_visible = 2
	_hud_labels["compact_life"].text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	detail.add_child(_hud_labels["compact_life"])
	if lines <= 0:
		kicker.hide()
		_hud_labels["objective_text"].hide()
		_hud_labels["compact_life"].hide()
	_director.register("mission", panel)
	_director.register("mission_detail", detail, true)
	_director.register("mission_detail", kicker, true)
	panel.minimum_size_changed.connect(_fit_width.bind(panel, width))
	panel.size = Vector2(width, 0)
	_hud.mission = Rect2(panel.position, Vector2(width, 0))
	_hud.toast_top = top + 64.0 if _hud.single_row else top + 96.0
	panel.gui_input.connect(func(event: InputEvent):
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			_director.wake("mission")
			_director.wake("mission_detail")
	)
	panel.mouse_entered.connect(func():
		_director.wake("mission")
		_director.wake("mission_detail")
	)


func _build_character_card() -> void:
	var panel := _panel(false)
	_life_panel = panel
	panel.name = "LifeCard"
	var corner: Rect2 = _hud.corner
	var area: Vector2 = _hud.area
	panel.position = Vector2(area.x - _hud.gutter - 270.0, corner.end.y + 14.0)
	panel.size = Vector2(270.0, 0)
	_screen.add_child(panel)
	var column := _hud_column(7)
	panel.add_child(column)
	column.add_child(HudStyle.kicker("DEIN LEBEN"))
	_hud_labels["age"] = HudStyle.label("", HudStyle.TYPE_LEAD, HudStyle.CHARTA, true, 1)
	_hud_labels["age"].autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(_hud_labels["age"])
	_hud_labels["health"] = HudStyle.label("", HudStyle.TYPE_CAPTION, HudStyle.CHARTA_MUTED)
	column.add_child(_hud_labels["health"])
	_health_bar = ProgressBar.new()
	_health_bar.custom_minimum_size.y = 5
	_health_bar.show_percentage = false
	_health_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_health_bar.add_theme_stylebox_override("background", _flat(Color(0.04, 0.03, 0.02, 0.8)))
	_health_bar.add_theme_stylebox_override("fill", _flat(HudStyle.AURUM))
	column.add_child(_health_bar)
	_hud_labels["companion"] = HudStyle.label("", HudStyle.TYPE_CAPTION + 1, HudStyle.CHARTA_MUTED)
	_hud_labels["companion"].autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(_hud_labels["companion"])
	_hud_labels["squad"] = HudStyle.label("", HudStyle.TYPE_CAPTION + 1, HudStyle.CHARTA)
	_hud_labels["squad"].autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_hud_labels["squad"].tooltip_text = "Lebende Soldaten im Verhältnis zu allen bisher rekrutierten Soldaten."
	column.add_child(_hud_labels["squad"])
	var chronicle_panel := _panel(false)
	chronicle_panel.name = "ChronicleCard"
	_chronicle_panel = chronicle_panel
	chronicle_panel.position = Vector2(panel.position.x, panel.position.y + 200.0)
	chronicle_panel.size = Vector2(270.0, 0)
	_screen.add_child(chronicle_panel)
	var chronicle_column := _hud_column(8)
	chronicle_panel.add_child(chronicle_column)
	chronicle_column.add_child(HudStyle.kicker("CHRONIK"))
	_hud_labels["chronicle"] = HudStyle.label("", HudStyle.TYPE_CAPTION, HudStyle.CHARTA_MUTED)
	_hud_labels["chronicle"].autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_hud_labels["chronicle"].max_lines_visible = 5
	_hud_labels["chronicle"].text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	chronicle_column.add_child(_hud_labels["chronicle"])
	panel.resized.connect(_stack_below.bind(chronicle_panel, panel, 12.0))
	if _compact_layout:
		panel.hide()
		chronicle_panel.hide()


func _hud_column(separation: int) -> VBoxContainer:
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", separation)
	column.mouse_filter = Control.MOUSE_FILTER_PASS
	return column


## Vitality and stamina appear only when they matter (director "vitals").
func _build_vitals() -> void:
	_vitals = VitalsScript.new()
	_vitals.name = "Vitals"
	_vitals.size = Vector2(176.0, 52.0)
	_screen.add_child(_vitals)
	_director.register("vitals", _vitals, true)


## Desktop action dock (bottom left): modes, the village life and adult
## projects as compact plaques; the key hints fade after the first seconds.
func _build_toolbar() -> void:
	if _touch_enabled:
		_build_touch_toolbar()
		return
	var area: Vector2 = _hud.area
	var gutter: float = _hud.gutter
	var panel := PanelContainer.new()
	panel.name = "ActionDock"
	panel.mouse_filter = Control.MOUSE_FILTER_PASS
	panel.add_theme_stylebox_override("panel", HudStyle.velum(0, Vector4(16, 8, 44, 8), 0.5, true))
	_screen.add_child(panel)
	var column := _hud_column(6)
	panel.add_child(column)
	_hud_labels["controls"] = HudStyle.label("", HudStyle.TYPE_CAPTION, HudStyle.CHARTA_MUTED)
	_hud_labels["controls"].autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(_hud_labels["controls"])
	_director.register("controls_hint", _hud_labels["controls"], true)
	_hud_labels["controls"].autowrap_mode = TextServer.AUTOWRAP_OFF
	# Row one: modes and the village; row two: adult projects (hidden for a child).
	var modes_row := HBoxContainer.new()
	modes_row.mouse_filter = Control.MOUSE_FILTER_PASS
	modes_row.add_theme_constant_override("separation", 6)
	column.add_child(modes_row)
	var projects_row := HBoxContainer.new()
	projects_row.name = "Projects"
	projects_row.mouse_filter = Control.MOUSE_FILTER_PASS
	projects_row.add_theme_constant_override("separation", 6)
	column.add_child(projects_row)
	var modes := [["person", "Figur", "person"], ["city", "Stadt", "city"], ["map", "Karte", "map"]] if _compact_layout else [["person", "Persönlich", "person"], ["city", "Städtebau · Tab", "city"], ["map", "Landkarte · M", "map"]]
	for item in modes:
		var button := _hud_button(item[1], _emit.bind("mode_" + item[0], {}), item[2])
		_mode_buttons[item[0]] = button
		modes_row.add_child(button)
	var atlas := _hud_button("Weltkugel", func(): _emit("atlas"), "globe")
	atlas.visible = _mode == "map"
	modes_row.add_child(atlas)
	_action_buttons["atlas"] = atlas
	if _state.get("village", {}).get("enabled", false):
		modes_row.add_child(_hud_button("Dorfleben", _emit.bind("village_panel", {}), "village", true))
	var actions := [
		["build", "Hütte · 8 Holz", "Bauplan öffnen. Mit Linksklick einen erlaubten Platz bestätigen."],
		["train", "Ausbildung", "Benötigt eine fertige Hütte, eine Gefährtenentscheidung und keine offene Baustelle. Am Trainingsplatz fortsetzen."],
		["recruit", "Rekrutieren", "Ein Rekrut: 5 Denare und 2 Getreide. Ausbildung erforderlich; höchstens drei Rekruten."],
		["skirmish", "Dorf verteidigen", "Benötigt abgeschlossene Ausbildung und eine lebende eigene Truppe."]
	]
	var compact_names := {"build": "Hütte", "train": "Üben", "recruit": "Truppe +", "skirmish": "Verteidigen"}
	for item in actions:
		var button := _hud_button(compact_names[item[0]] if _compact_layout else item[1], _emit.bind(item[0], {}), "projects")
		button.tooltip_text = item[2]
		_action_buttons[item[0]] = button
		projects_row.add_child(button)
		# The row disappears with its last visible project (the child has none).
		button.visibility_changed.connect(_hide_empty_row.bind(projects_row))
	_hud.dock = panel
	_director.register("dock", panel)
	panel.minimum_size_changed.connect(_anchor_bottom_left.bind(panel, Vector2(gutter, area.y - gutter), 0.0))
	_anchor_bottom_left(panel, Vector2(gutter, area.y - gutter), 0.0)
	panel.mouse_entered.connect(func(): _director.wake("dock", 3.0))


## Touch dock (bottom centre, below the thumb zones): modes, village and the
## projects menu as short plaques with glyphs.
func _build_touch_toolbar() -> void:
	var area: Vector2 = _hud.area
	var gutter: float = _hud.gutter
	var panel := PanelContainer.new()
	panel.name = "TouchToolbar"
	panel.mouse_filter = Control.MOUSE_FILTER_PASS
	panel.add_theme_stylebox_override("panel", HudStyle.velum(2, Vector4(34, 4, 34, 4), 0.5, false))
	_screen.add_child(panel)
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_PASS
	row.add_theme_constant_override("separation", 6)
	panel.add_child(row)
	var items := [["person", "Figur", "person"], ["city", "Stadt", "city"], ["map", "Karte", "map"]]
	for item in items:
		var button := _hud_button(item[1], _emit.bind("mode_" + item[0], {}), item[2])
		_mode_buttons[item[0]] = button
		row.add_child(button)
	if _state.get("village", {}).get("enabled", false):
		row.add_child(_hud_button("Dorf", _emit.bind("village_panel", {}), "village"))
	var commands := _hud_button("Vorhaben", _toggle_command_menu, "projects")
	commands.name = "OpenCommands"
	row.add_child(commands)
	var natural := row.get_combined_minimum_size().x + 68.0
	var width := minf(natural, area.x - gutter * 2.0)
	for child: Node in row.get_children():
		if child is Button:
			_chrome_buttons.append(child as Button)
	if natural > area.x - gutter * 2.0:
		for child: Node in row.get_children():
			(child as Control).size_flags_horizontal = Control.SIZE_EXPAND_FILL
			if child is Button:
				_icon_only(child)
				child.set_meta("always_compact", true)
		panel.size = Vector2(width, _hud.dock_height)
		panel.position = Vector2((area.x - width) * 0.5, area.y - 8.0 - _hud.dock_height)
	else:
		panel.minimum_size_changed.connect(_anchor_bottom_center.bind(panel, Vector2(area.x * 0.5, area.y - 8.0), _hud.dock_height))
		_anchor_bottom_center(panel, Vector2(area.x * 0.5, area.y - 8.0), _hud.dock_height)
	_director.register("dock", panel)
	_hud_labels["controls"] = HudStyle.label("", HudStyle.TYPE_CAPTION, HudStyle.CHARTA_MUTED)
	_hud_labels["controls"].hide()
	_screen.add_child(_hud_labels["controls"])
	_touch_menu_layer = _new_touch_overlay("CommandMenu", "Dein nächster Schritt")
	var column: VBoxContainer = _touch_menu_layer.get_meta("content")
	var actions := [["build", "Hütte bauen · 8 Holz"], ["train", "Ausbildung"], ["recruit", "Truppe verstärken"], ["skirmish", "Dorf verteidigen"], ["atlas", "Weltkugel"]]
	for item in actions:
		var button := _list_button(item[1], func():
			_close_touch_overlays()
			_emit(item[0])
		)
		button.name = "Command_" + item[0]
		column.add_child(button)
		_action_buttons[item[0]] = button
	_touch_menu_layer.hide()


## Plaque for lists inside a scroll: a plain button so a swipe can cancel it.
func _list_button(text: String, callback: Callable, primary := false) -> Button:
	var button := Button.new()
	button.text = text
	HudStyle.style_plaque_button(button, primary, HudStyle.TYPE_BODY)
	button.custom_minimum_size = Vector2(0, 52)
	button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	# The enclosing scroll receives a swipe that starts on the plaque and
	# cancels its press, so scrolling never selects an entry by accident.
	button.mouse_filter = Control.MOUSE_FILTER_PASS
	button.pressed.connect(func():
		_play_click()
		callback.call()
	)
	return button


func _build_touch_controls() -> void:
	if _touch_enabled:
		var pad_rect: Rect2 = _hud.pad
		_touch_pad = TouchPadScript.new()
		_touch_pad.name = "MovementPad"
		_touch_pad.position = pad_rect.position
		_touch_pad.size = pad_rect.size
		_screen.add_child(_touch_pad)
		_touch_pad.axis_changed.connect(func(axis: Vector2): _emit("move_axis", {"x": axis.x, "y": axis.y}))
		_touch_look = TouchLookScript.new()
		_touch_look.name = "CameraLook"
		_touch_look.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		_touch_look.anchor_left = 0.35
		_screen.add_child(_touch_look)
		_touch_look.look_changed.connect(func(delta: Vector2): _emit("camera_look", {"x": delta.x, "y": delta.y}))
		_touch_look.zoom_changed.connect(func(factor: float): _emit("camera_zoom", {"factor": factor}))
		var cluster := Control.new()
		cluster.name = "TouchActions"
		cluster.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_screen.add_child(cluster)
		var entries := [["interact", "Interagieren"], ["attack", "Schlagen"], ["guard", "Deckung"], ["dodge", "Ausweichen"], ["techniques", "Techniken"], ["pace", "Gehen"]]
		for item in entries:
			var action_id := str(item[0])
			var button: Button = MedallionScript.new()
			button.text = item[1]
			button.name = action_id.capitalize()
			button.configure(action_id, 27.0, action_id == "attack")
			button.set_action_icon(action_id)
			button.set_meta("touch_action", action_id)
			button.pressed.connect(func():
				_play_click()
				_touch_action(action_id)
			)
			_touch_actions.append(button)
			cluster.add_child(button)
			if action_id == "attack":
				_touch_attack_button = button
			elif action_id == "techniques":
				_touch_technique_button = button
			elif action_id == "pace":
				_pace_button = button
			if action_id in ["attack", "guard", "dodge", "techniques"]:
				_director.register("combat", button)
		_update_pace_caption()
		# Modal native handlers run above every gameplay input control.
		if is_instance_valid(_touch_menu_layer):
			_screen.move_child(_touch_menu_layer, -1)
	_cancel_build_button = _hud_button("Bau abbrechen", func(): _emit("cancel_build"), "close")
	_cancel_build_button.name = "CancelBuild"
	var area: Vector2 = _hud.area
	var lift: float = _hud.get("lift", 120.0)
	_cancel_build_button.size = Vector2(190.0, 52.0)
	_cancel_build_button.position = Vector2(area.x - _hud.gutter - 190.0, area.y - lift - 52.0)
	_screen.add_child(_cancel_build_button)
	_update_touch_visibility()


## Arrange the visible action medallions as a thumb fan around the primary
## action in the lower right corner; the cluster's rectangle hugs them.
func _layout_touch_actions() -> void:
	var cluster := _screen.get_node_or_null("TouchActions") as Control if is_instance_valid(_screen) else null
	if cluster == null or not _hud.has("pad"):
		return
	var area: Vector2 = _hud.area
	var gutter: float = _hud.gutter
	var visible: Array[Button] = []
	for button: Button in _touch_actions:
		if is_instance_valid(button) and button.visible:
			visible.append(button)
	if visible.is_empty():
		cluster.size = Vector2.ZERO
		return
	var signature := "%s|%s" % [area, visible.map(func(button: Button) -> String: return str(button.get_meta("touch_action")))]
	if cluster.get_meta("signature", "") == signature:
		return
	cluster.set_meta("signature", signature)
	var by_action := {}
	for button in visible:
		by_action[str(button.get_meta("touch_action"))] = button
	var primary: Button = by_action.get("attack", by_action.get("interact", visible[0]))
	var others: Array[Button] = []
	for id in ["guard", "dodge", "interact", "techniques", "pace", "attack"]:
		if by_action.has(id) and by_action[id] != primary:
			others.append(by_action[id])
	var pad_rect: Rect2 = _hud.pad
	var available := area.x - gutter * 2.0 - pad_rect.size.x - HudStyle.GAP * 2.0
	var tall := bool(_hud.portrait)
	var big := area.y >= 520.0
	var radii := Vector2(36.0, 27.0) if big else Vector2(31.0, 24.0)
	var fan := [Vector2(-92, 4), Vector2(-70, -84), Vector2(6, -100), Vector2(-150, -88), Vector2(-170, 4)]
	var column_layout := [Vector2(-86, 0), Vector2(0, -98), Vector2(-86, -98), Vector2(0, -196), Vector2(-86, -196)]
	var placements := {}
	for attempt in 3:
		var table: Array = column_layout if tall or attempt == 1 else fan
		if attempt == 2:
			radii = Vector2(30.0, 24.0)
		var factor := radii.y / 27.0 * (1.0 if attempt < 2 else 0.92)
		placements.clear()
		var bounds := Rect2()
		var first := true
		for index in range(-1, others.size()):
			var button: Button = primary if index < 0 else others[index]
			var radius := radii.x if index < 0 else radii.y
			var center := Vector2.ZERO if index < 0 else (table[index] as Vector2) * factor
			if index >= 0 and index < 2 and others.size() <= 2:
				center = (table[index] as Vector2) * factor
			var box := MedallionScript.box_size(radius)
			var rect := Rect2(center - Vector2(box.x * 0.5, radius + 2.0), box)
			placements[button] = {"radius": radius, "rect": rect}
			bounds = rect if first else bounds.merge(rect)
			first = false
		placements["bounds"] = bounds
		if bounds.size.x <= available:
			break
	var bounds: Rect2 = placements.bounds
	var corner := Vector2(area.x - gutter, area.y - float(_hud.lift))
	cluster.position = corner - bounds.size
	cluster.size = bounds.size
	for button in visible:
		var entry: Dictionary = placements[button]
		var rect: Rect2 = entry.rect
		button.configure(button.glyph, float(entry.radius), button == _touch_attack_button)
		button.position = rect.position - bounds.position
		button.size = rect.size
	_hud.actions = Rect2(cluster.position, cluster.size)
	_place_vitals()


## Vitals between the thumb zones when there is room, otherwise above the pad.
func _place_vitals() -> void:
	if not is_instance_valid(_vitals):
		return
	var area: Vector2 = _hud.area
	if _touch_enabled and _hud.has("pad"):
		var pad_rect: Rect2 = _hud.pad
		var actions: Rect2 = _hud.get("actions", Rect2(area.x, area.y, 0, 0))
		var between := actions.position.x - pad_rect.end.x
		if between >= _vitals.size.x + 24.0:
			_vitals.position = Vector2(pad_rect.end.x + (between - _vitals.size.x) * 0.5, area.y - float(_hud.lift) - _vitals.size.y)
		else:
			_vitals.position = Vector2(pad_rect.position.x, pad_rect.position.y - _vitals.size.y - 6.0)
	else:
		var dock: Control = _hud.get("dock")
		var bottom := dock.position.y if is_instance_valid(dock) else area.y - 100.0
		_vitals.position = Vector2(float(_hud.gutter), bottom - _vitals.size.y - 10.0)


## Desktop key prompt for the context action (bottom centre).
func _build_prompt() -> void:
	if _touch_enabled:
		return
	var area: Vector2 = _hud.area
	_prompt_panel = PanelContainer.new()
	_prompt_panel.name = "ContextPrompt"
	_prompt_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_prompt_panel.add_theme_stylebox_override("panel", HudStyle.velum(2, Vector4(36, 6, 36, 6), 0.55, false))
	_screen.add_child(_prompt_panel)
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", 10)
	_prompt_panel.add_child(row)
	var key := PanelContainer.new()
	key.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var key_box := StyleBoxFlat.new()
	key_box.bg_color = Color(0.05, 0.035, 0.025, 0.9)
	key_box.border_color = HudStyle.AURUM
	key_box.set_border_width_all(1)
	key_box.set_corner_radius_all(3)
	key_box.content_margin_left = 8
	key_box.content_margin_right = 8
	key_box.content_margin_top = 2
	key_box.content_margin_bottom = 2
	key.add_theme_stylebox_override("panel", key_box)
	row.add_child(key)
	_prompt_key = HudStyle.label("E", HudStyle.TYPE_CAPTION + 1, HudStyle.AURUM_LIGHT, true, 0)
	key.add_child(_prompt_key)
	_prompt_label = HudStyle.label("", HudStyle.TYPE_BODY, HudStyle.CHARTA, true, 1)
	_prompt_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(_prompt_label)
	_prompt_panel.minimum_size_changed.connect(_anchor_center.bind(_prompt_panel, Vector2(area.x * 0.5, area.y * 0.74)))
	_anchor_center(_prompt_panel, Vector2(area.x * 0.5, area.y * 0.74))
	_director.register("prompt", _prompt_panel, true)


## Positions that depend on more than one element.
func _place_hud() -> void:
	if not _touch_enabled:
		_place_vitals()


# Layout callbacks are bound methods, not lambdas: they may run while a
# screen is being freed and then only find freed controls to skip.
func _anchor_top_right(control: Control, corner: Vector2, min_height: float) -> void:
	if not is_instance_valid(control) or not control.is_inside_tree():
		return
	var fitted := control.get_combined_minimum_size()
	control.size = Vector2(fitted.x, maxf(min_height, fitted.y))
	control.position = Vector2(corner.x - control.size.x, corner.y)


func _anchor_bottom_left(control: Control, corner: Vector2, width: float) -> void:
	if not is_instance_valid(control) or not control.is_inside_tree():
		return
	var fitted := control.get_combined_minimum_size()
	control.size = Vector2(maxf(width, fitted.x), fitted.y)
	control.position = Vector2(corner.x, corner.y - control.size.y)


func _hide_empty_row(row: Control) -> void:
	if not is_instance_valid(row) or not row.is_inside_tree():
		return
	var any := false
	for child: Node in row.get_children():
		any = any or (child as Control).visible
	row.visible = any


func _anchor_bottom_center(control: Control, bottom: Vector2, height: float) -> void:
	if not is_instance_valid(control) or not control.is_inside_tree():
		return
	var fitted := control.get_combined_minimum_size()
	control.size = Vector2(fitted.x, height)
	control.position = Vector2(bottom.x - fitted.x * 0.5, bottom.y - height)


func _anchor_center(control: Control, center: Vector2) -> void:
	if not is_instance_valid(control) or not control.is_inside_tree():
		return
	var fitted := control.get_combined_minimum_size()
	control.size = fitted
	control.position = center - Vector2(fitted.x * 0.5, 0)


func _fit_width(control: Control, width: float) -> void:
	if is_instance_valid(control) and control.is_inside_tree():
		control.size = Vector2(width, 0)


func _fit_tablet(tablet: Control, column: Control, frame: Rect2) -> void:
	if not is_instance_valid(tablet) or not is_instance_valid(column) or not tablet.is_inside_tree():
		return
	var fitted := minf(frame.size.y, column.get_combined_minimum_size().y + 38.0)
	tablet.size = Vector2(frame.size.x, fitted)
	tablet.position = Vector2(frame.position.x, frame.position.y + (frame.size.y - fitted) * 0.5)


func _stack_below(lower: Control, upper: Control, gap: float) -> void:
	if is_instance_valid(lower) and is_instance_valid(upper):
		lower.position.y = upper.position.y + upper.size.y + gap


func _follow_visibility(source: CanvasItem, follower: CanvasItem) -> void:
	if is_instance_valid(source) and is_instance_valid(follower) and source.is_inside_tree():
		follower.visible = source.visible


func _fit_modal_scroll(scroll: ScrollContainer, column: Control) -> void:
	if is_instance_valid(scroll) and is_instance_valid(column):
		scroll.custom_minimum_size.y = minf(column.get_combined_minimum_size().y, maxf(120, _area().y - 144))


func _hide_later(control: Control) -> void:
	if is_instance_valid(control):
		control.hide()


func _reveal_when_shown(overlay: Control, panel: Control) -> void:
	if is_instance_valid(overlay) and is_instance_valid(panel) and overlay.is_inside_tree() and overlay.visible:
		HudStyle.reveal(panel, _reduce_motion, 0.0, Vector2.ZERO)


func _touch_button(caption: String, callback: Callable, primary: bool) -> Button:
	var button: Button = TouchActionScript.new()
	button.text = caption
	HudStyle.style_plaque_button(button, primary, HudStyle.TYPE_CAPTION + 1)
	button.custom_minimum_size.y = HudStyle.TOUCH_MIN
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
		if "primary" in _pace_button:
			_pace_button.primary = _running
			_pace_button.queue_redraw()


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
	shade.color = Color(0.02, 0.015, 0.01, 0.7)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(shade)
	var panel := PanelContainer.new()
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	panel.add_theme_stylebox_override("panel", HudStyle.plaque(true, Vector4(18, 14, 18, 14), 0.94))
	var extent := _area()
	var width := minf(630.0, extent.x - 32.0)
	var height := minf(510.0, extent.y - 32.0)
	panel.position = (extent - Vector2(width, height)) * 0.5
	panel.size = Vector2(width, height)
	overlay.add_child(panel)
	var layout := _hud_column(10)
	panel.add_child(layout)
	var header := HBoxContainer.new()
	header.mouse_filter = Control.MOUSE_FILTER_PASS
	header.add_theme_constant_override("separation", 12)
	layout.add_child(header)
	var heading := HudStyle.label(title, HudStyle.TYPE_TITLE + 2, HudStyle.AURUM_LIGHT, true, 2)
	heading.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	heading.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	header.add_child(heading)
	var close := Button.new()
	close.text = "Zurück"
	close.name = "CloseOverlay"
	close.icon = HudIcons.texture("back", roundi(18 * _screen_scale), 1.6)
	HudStyle.style_plaque_button(close, false, HudStyle.TYPE_CAPTION + 1)
	close.custom_minimum_size.y = HudStyle.TOUCH_MIN
	close.pressed.connect(func():
		_play_click()
		_close_touch_overlays()
	)
	header.add_child(close)
	layout.add_child(MenuKit.Rule.new())
	var scroll := ScrollContainer.new()
	scroll.name = "ChoicesScroll"
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.follow_focus = true
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	layout.add_child(scroll)
	var content := _hud_column(8)
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(content)
	overlay.set_meta("content", content)
	overlay.visibility_changed.connect(_reveal_when_shown.bind(overlay, panel))
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
	var help := HudStyle.label("Ausdauer %d/100 · %d kontrollierte Übungstreffer\nEine Technik wählen, dann im Spiel mit der Schlagtaste ausführen." % [int(combat.stamina), int(combat.practice_hits)], HudStyle.TYPE_CAPTION + 1, HudStyle.CHARTA_MUTED)
	help.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(help)
	if combat.get("service_gear",false):
		var equipment := HudStyle.label("Dienstausrüstung: Gladius und Scutum · ausgebildeter Soldat. Wähle Faust- oder Waffentechnik.", HudStyle.TYPE_CAPTION + 1, HudStyle.CHARTA_MUTED)
		equipment.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		column.add_child(equipment)
	for technique: Dictionary in combat.techniques:
		var id := str(technique.id)
		var available := bool(technique.available)
		var caption := "%s · %d Ausdauer" % [technique.label, int(technique.cost)]
		if not available:
			caption += "\nErlernbar ab %d Übungstreffern" % int(technique.practice)
		var button := _list_button(caption, _choose_technique.bind(id), id == _selected_technique)
		button.name = "Technique_" + id
		button.icon = HudIcons.texture("gladius" if CombatActions.is_armed(id) else "attack", roundi(22 * _screen_scale), 1.6)
		button.custom_minimum_size.y = 56 if available else 68
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
	var style := panel.get_theme_stylebox("panel").duplicate() as StyleBox
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
			if action in ["attack", "guard", "dodge", "techniques"] and _child_first_mission(_state):
				button.visible = false
	if is_instance_valid(_cancel_build_button):
		_cancel_build_button.visible = _build_active and not overlay
	_layout_touch_actions()
	if is_instance_valid(_director):
		_director.context["overlay"] = overlay
		_director.context["build"] = _build_active


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


func _show_journal(pause_world := true, tab := "") -> void:
	# Root pauses the authoritative world before the reading screen replaces its pause UI.
	if pause_world:
		_emit("pause")
	if not tab.is_empty():
		_journal_tab = tab
	_open_screen("journal", true)
	var built := Codex.build(self, _state, _journal_tab)
	var focus: Button = built.get("tab")
	if focus == null:
		focus = built.resume
	focus.grab_focus.call_deferred()


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
		# Occasion and place, not a technical mission ID (HB 3.0 S. 44).
		return [str(childhood.get("hud_title", childhood.get("title", "Ein Morgen zu Hause"))), str(childhood.get("objective", "Sprich mit deiner Mutter vor dem Haus."))]
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
	quality_select.add_item("Ultra · Limit 30 FPS")
	quality_select.custom_minimum_size.y = 46
	var profiles := ["low", "balanced", "high", "very_high"]
	quality_select.selected = profiles.find(_quality)
	column.add_child(quality_select)
	quality_select.item_selected.connect(func(index: int):
		set_quality(profiles[index])
	)
	var sustained_note := _label("Fold7-Grafikziel: Hoch · 60 FPS, Ultra · 30 FPS.\nBei dauerhaft langen Bildzeiten wird nur die 3D-Auflösung reduziert; Menü und Touch bleiben scharf. Kein gemessener Temperaturwert.", 14, MUTED)
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
	width = minf(width, _area().x - 100)
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
	var kicker_label := _label(kicker, 12, BRONZE)
	RomanStyle.style_caps(kicker_label, roundi(12 * _ui_scale), RomanStyle.GOLD, 3)
	column.add_child(kicker_label)
	var heading := _label(title, 34, CREAM, true)
	heading.add_theme_font_override("font", HudStyle.display_font(700, 2))
	heading.add_theme_color_override("font_color", HudStyle.AURUM_LIGHT)
	heading.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(heading)
	column.add_child(MenuKit.Rule.new())
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
	column.minimum_size_changed.connect(_fit_modal_scroll.bind(scroll, column))
	HudStyle.reveal(panel, _reduce_motion, 0.0, Vector2.ZERO)
	return column


func _setup_theme() -> void:
	_serif = SystemFont.new()
	_serif.font_names = PackedStringArray(["DejaVu Serif", "Noto Serif", "Liberation Serif"])
	_ui_theme = Theme.new()
	# Menus speak the same language as the HUD: a book serif for reading,
	# bronze and ink plaques, gilded focus.
	_ui_theme.default_font = HudStyle.body_font()
	_ui_theme.default_font_size = roundi(16 * _ui_scale)
	_ui_theme.set_color("font_color", "Label", CREAM)
	_ui_theme.set_color("font_color", "Button", CREAM)
	_ui_theme.set_color("font_hover_color", "Button", Color("fff2d8"))
	_ui_theme.set_color("font_pressed_color", "Button", CREAM)
	_ui_theme.set_color("font_disabled_color", "Button", Color("7d786c"))
	_ui_theme.set_stylebox("normal", "Button", _button_style(false, false))
	_ui_theme.set_stylebox("hover", "Button", _button_style(false, true))
	_ui_theme.set_stylebox("pressed", "Button", _button_style(true, true))
	var disabled := _button_style(false, false)
	disabled.bg_color = Color(0.09, 0.085, 0.075, 0.75)
	disabled.border_color = Color(0.36, 0.34, 0.3, 0.7)
	_ui_theme.set_stylebox("disabled", "Button", disabled)
	var focus := _flat(Color(0, 0, 0, 0))
	focus.border_color = HudStyle.AURUM_LIGHT
	focus.set_border_width_all(2)
	focus.set_corner_radius_all(3)
	_ui_theme.set_stylebox("focus", "Button", focus)
	var tooltip := _flat(Color(0.05, 0.038, 0.028, 0.96))
	tooltip.set_content_margin_all(12)
	tooltip.set_border_width_all(1)
	tooltip.border_color = HudStyle.BRONZE
	_ui_theme.set_stylebox("panel", "TooltipPanel", tooltip)
	_ui_theme.set_color("font_color", "TooltipLabel", CREAM)


func _button_style(primary: bool, hover: bool) -> StyleBoxFlat:
	var style := _flat(Color("8a2f31") if primary and hover else Color("6e2427") if primary else Color(0.2, 0.15, 0.1, 0.95) if hover else Color(0.075, 0.058, 0.043, 0.92))
	style.border_color = HudStyle.AURUM if hover else Color(0.7, 0.53, 0.3, 0.9) if primary else Color(0.5, 0.39, 0.24, 0.85)
	style.set_border_width_all(1)
	style.border_width_bottom = 2
	style.set_corner_radius_all(2)
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
	panel.add_theme_stylebox_override("panel", HudStyle.plaque(accent, Vector4(18, 14, 18, 14), 0.93))
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
	_toast_panel = PanelContainer.new()
	_toast_panel.name = "Notice"
	_toast_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_toast_panel.add_theme_stylebox_override("panel", HudStyle.plaque(true, Vector4(22, 12, 22, 12), 0.9))
	_root.add_child(_toast_panel)
	_toast_label = HudStyle.label("", HudStyle.TYPE_BODY + 1, HudStyle.CHARTA)
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
