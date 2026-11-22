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
const TouchPadScript := preload("res://scripts/ui/touch_pad.gd")
const TouchActionScript := preload("res://scripts/ui/touch_action.gd")

class Atmosphere extends Control:

	var menu_style: bool = false

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		resized.connect(queue_redraw)

	func _draw() -> void:
		if menu_style:
			for index in range(48):
				var fraction := float(index) / 48.0
				var opacity := lerpf(0.94, 0.14, smoothstep(0.30, 0.96, fraction))
				draw_rect(Rect2(fraction * size.x, 0, size.x / 48.0 + 1, size.y), Color(0.025, 0.043, 0.043, opacity))
		else:
			draw_rect(Rect2(Vector2.ZERO, size), Color(0.025, 0.039, 0.043, 0.86))
		draw_line(Vector2(24, 23), Vector2(size.x - 24, 23), Color(0.72, 0.57, 0.36, 0.52), 1)
		draw_line(Vector2(24, size.y - 23), Vector2(size.x - 24, size.y - 23), Color(0.72, 0.57, 0.36, 0.36), 1)

class ImperialMark extends Control:

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var center := size * 0.5
		var radius := minf(size.x, size.y) * 0.38
		var color := Color("b99563")
		draw_arc(center, radius, 0.0, TAU, 72, Color(color, 0.42), 1.0, true)
		for column in range(3):
			var x := center.x + (column - 1) * radius * 0.45
			draw_line(Vector2(x, center.y - radius * 0.35), Vector2(x, center.y + radius * 0.45), color, 2.0, true)
		draw_line(center + Vector2(-radius * 0.75, radius * 0.53), center + Vector2(radius * 0.75, radius * 0.53), color, 2.0, true)
		draw_line(center + Vector2(-radius * 0.75, -radius * 0.45), center + Vector2(radius * 0.75, -radius * 0.45), color, 2.0, true)
		draw_polyline(PackedVector2Array([center + Vector2(-radius * 0.8, -radius * 0.55), center + Vector2(0, -radius * 0.91), center + Vector2(radius * 0.8, -radius * 0.55)]), color, 1.5, true)

var origin_id := "italia"
var _root: Control
var _screen: Control
var _toast_panel: PanelContainer
var _toast_label: Label
var _toast_tween: Tween
var _intro_tween: Tween
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
var _volume := 0.55
var _sound_player: AudioStreamPlayer
var _serif: SystemFont
var _ui_theme: Theme
var _hud_labels: Dictionary = {}
var _action_buttons: Dictionary = {}
var _mode_buttons: Dictionary = {}
var _health_bar: ProgressBar
var _touch_enabled := false
var _compact_layout := false
var _touch_pad: Control
var _touch_actions: Array[Button] = []
var _cancel_build_button: Button
var _build_active := false
var _quality := "balanced"
var _diagnostics := false
var _layout_queued := false
var _dialog_data: Dictionary = {}
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
	_setup_toast()
	get_viewport().size_changed.connect(_viewport_changed)


func _notification(what: int) -> void:
	if what in [NOTIFICATION_APPLICATION_PAUSED, NOTIFICATION_APPLICATION_FOCUS_OUT, NOTIFICATION_WM_WINDOW_FOCUS_OUT]:
		_reset_touch()
	elif what == NOTIFICATION_APPLICATION_RESUMED and is_instance_valid(_root):
		_viewport_changed()


func _exit_tree() -> void:
	_reset_touch()
	if _intro_tween != null and _intro_tween.is_valid():
		_intro_tween.kill()
	if _toast_tween != null and _toast_tween.is_valid():
		_toast_tween.kill()
	if is_instance_valid(_sound_player):
		_sound_player.stop()
		_sound_player.stream = null


func show_intro() -> void:
	_open_screen("intro", true)
	_intro_done = false
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_screen.add_child(center)
	var column := _column(15)
	column.custom_minimum_size.x = minf(760, _content_size().x - 48)
	center.add_child(column)
	var mark := ImperialMark.new()
	mark.custom_minimum_size = Vector2(88, 88)
	mark.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	column.add_child(mark)
	var kicker := _label("EIN LEBEN. EIN REICH.", 15, BRONZE)
	kicker.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(kicker)
	var title := _label("IMPERATHEN", _title_font_size("IMPERATHEN", 76, _content_size().x - 64), CREAM, true)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(title)
	var subtitle := _label("Nicht jeder Aufstieg führt auf einen Thron.\nJede Entscheidung hinterlässt eine Spur.", 21, MUTED)
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(subtitle)
	var skip := _button("Überspringen" if _touch_enabled else "Überspringen  ·  Enter", func(): _finish_intro(), false, 14)
	skip.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	skip.offset_left = -260
	skip.offset_right = -34
	skip.offset_top = -78
	skip.offset_bottom = -34
	_screen.add_child(skip)
	skip.grab_focus.call_deferred()
	if OS.is_debug_build() and OS.has_feature("android"):
		_log_intro_skip.call_deferred(skip)
	_intro_tween = create_tween()
	if _reduce_motion:
		_intro_tween.tween_interval(3.0)
	else:
		column.modulate.a = 0.0
		subtitle.modulate.a = 0.0
		_intro_tween.tween_property(column, "modulate:a", 1.0, 1.2).set_trans(Tween.TRANS_SINE)
		_intro_tween.tween_property(subtitle, "modulate:a", 1.0, 0.9)
		_intro_tween.tween_interval(3.0)
		_intro_tween.tween_property(column, "modulate:a", 0.0, 0.7)
	_intro_tween.tween_callback(_finish_intro)


func show_menu(can_continue: bool) -> void:
	_can_continue = can_continue
	_open_screen("menu", true, true)
	var margin := _margin(34 if _compact_layout else 58, 32 if _compact_layout else 44, 30, 28)
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_screen.add_child(margin)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.follow_focus = true
	scroll.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	scroll.custom_minimum_size.x = minf(620, _content_size().x - 76)
	margin.add_child(scroll)
	var layout := _column(8)
	layout.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	layout.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.add_child(layout)
	var mark := ImperialMark.new()
	mark.custom_minimum_size = Vector2(44, 44)
	layout.add_child(mark)
	mark.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	layout.add_child(_label("DIE CHRONIK EINES AUFSTIEGS", 13, BRONZE))
	layout.add_child(_label("IMPERATHEN", _title_font_size("IMPERATHEN", 57, scroll.custom_minimum_size.x - 20), CREAM, true))
	var pitch := _label("Dein Anfang ist klein.\nWas daraus wird, entscheidest du.", 18, MUTED)
	layout.add_child(pitch)
	_spacer(layout, 16)
	var buttons := _column(10)
	buttons.custom_minimum_size.x = 350
	buttons.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	layout.add_child(buttons)
	var continue_button := _button("Fortsetzen", func(): _emit("continue"), true)
	continue_button.disabled = not can_continue
	continue_button.tooltip_text = "Deinen gespeicherten Lebensweg fortsetzen." if can_continue else "Es wurde noch kein Spielstand gefunden."
	buttons.add_child(continue_button)
	_add_origin_picker(buttons)
	var new_button := _button("Neues Leben", _request_new_game, not can_continue)
	buttons.add_child(new_button)
	var demo_button := _button("Talgefecht erproben", func(): _emit("valley_demo"))
	buttons.add_child(demo_button)
	var atlas_button := _button("Weltkugel erkunden", func(): _emit("atlas_demo"))
	buttons.add_child(atlas_button)
	var gallery_button := _button("Figuren", func(): _show_gallery("menu"))
	buttons.add_child(gallery_button)
	if OS.is_debug_build() and OS.has_feature("android"):
		_log_menu_buttons.call_deferred(demo_button, atlas_button, continue_button, gallery_button, scroll)
		scroll.get_v_scroll_bar().value_changed.connect(func(_value: float):
			_log_gallery_button.call_deferred(gallery_button,scroll)
		)
	buttons.add_child(_button("Einstellungen", func(): _show_settings("menu")))
	buttons.add_child(_button("Spiel beenden", func(): _confirm("Spiel beenden?", "Ein laufender Lebensweg wird vor dem Beenden gespeichert.", "quit", {})))
	var filler := Control.new()
	filler.size_flags_vertical = Control.SIZE_EXPAND_FILL
	filler.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layout.add_child(filler)
	layout.add_child(_label("GRENZDORF  /  SPIELBARER FUNKTIONSPROTOTYP", 12, BRONZE))
	layout.add_child(_label("Vom ersten Holz bis zur gemeinsamen Verteidigung.\nEin erster Abschnitt der größeren Spielidee.", 14, MUTED))
	(continue_button if can_continue else new_button).grab_focus.call_deferred()
	var province := _panel(false)
	province.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	province.offset_left = -337
	province.offset_right = -52
	province.offset_top = -136
	province.offset_bottom = -56
	_screen.add_child(province)
	var province_content := _column(5)
	province.add_child(province_content)
	province_content.add_child(_label("AN DER GRENZE DES REICHES", 12, BRONZE))
	province_content.add_child(_label("Eine Heimat. Eine Entscheidung.", 17, CREAM, true))
	province.visible = not _compact_layout


func _add_origin_picker(parent: VBoxContainer) -> void:
	parent.add_child(_label("Herkunft für ein neues Leben", 13, BRONZE))
	var picker := OptionButton.new()
	picker.name = "OriginPicker"
	picker.custom_minimum_size.y = 46
	for id in ORIGIN_IDS:
		picker.add_item(String(Origins.PEOPLES[id].name))
	picker.selected = ORIGIN_IDS.find(origin_id)
	parent.add_child(picker)
	var description := _label(String(Origins.PEOPLES[origin_id].intro), 14, MUTED)
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
	_state = state.duplicate(true)
	_open_screen("game", false)
	_hud_labels.clear()
	_action_buttons.clear()
	_mode_buttons.clear()
	_build_top_bar()
	_build_objective_card()
	_build_character_card()
	_build_toolbar()
	_build_touch_controls()
	update_state(state)
	set_mode(_mode)


func update_state(state: Dictionary) -> void:
	_state = state.duplicate(true)
	if _view_state != "game":
		return
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
	_hud_labels["age"].text = "%d Jahre  ·  %s" % [int(player.get("age", 12)), _career_name(String(progress.get("stage", "prologue")))]
	var health := clampf(float(player.get("health", 100)), 0, 100)
	_health_bar.value = health
	_hud_labels["health"].text = "Lebenskraft   %d / 100" % int(health)
	_hud_labels["companion"].text = "%s · Vertrauen %+d" % [_companion_name(state), int(companion.get("trust", 0))] if bool(companion.get("met", false)) else "%s wartet im Dorf." % _companion_name(state)
	_hud_labels["squad"].text = "Truppe   %d / %d am Leben\nMoral   %d / 100" % [int(squad.get("alive", 0)), int(squad.get("recruits", 0)), int(squad.get("morale", 0))]
	if _hud_labels.has("compact_life"):
		_hud_labels["compact_life"].text = "Leben %d/100  ·  Truppe %d/%d" % [int(health), int(squad.get("alive", 0)), int(squad.get("recruits", 0))]
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
	var ended := String(progress.get("stage", "")) in ["ended", "fallen"]
	_action_buttons["build"].disabled = int(resources.get("wood", 0)) < 8 or ended
	_action_buttons["train"].disabled = not completed or not bool(companion.get("met", false)) or unfinished or trained or ended
	_action_buttons["recruit"].disabled = not trained or int(squad.get("recruits", 0)) >= 3 or int(resources.get("denarii", 0)) < 5 or int(resources.get("grain", 0)) < 2 or ended
	_action_buttons["skirmish"].disabled = not trained or int(squad.get("alive", 0)) <= 0 or bool(encounter.get("active", false)) or bool(progress.get("skirmish_won", false)) or ended
	if bool(encounter.get("active", false)):
		var remaining := 0
		for enemy in encounter.get("enemies", []):
			if float(enemy.get("health", 0)) > 0:
				remaining += 1
		_hud_labels["status"].text = ("ANGRIFF  ·  %d Gegner" if _compact_layout else "VERTEIDIGUNG  ·  %d Gegner") % remaining
	else:
		_hud_labels["status"].text = ("ABSCHLUSS" if ended else "GRENZDORF") if _compact_layout else "GRENZDORF  ·  " + ("ABSCHNITT BEENDET" if ended else "DEIN LEBENSWEG")


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
		column.add_child(choice_button)
		if first_button == null:
			first_button = choice_button
	if choices.is_empty():
		first_button = _button("Zurück ins Spiel", func(): _emit("resume"), true)
		column.add_child(first_button)
	first_button.grab_focus.call_deferred()


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
			"person": "Links bewegen · Rechts interagieren oder angreifen · Im freien Bild ziehen, um die Kamera zu drehen.",
			"city": "Hütte wählen · Freien Bauplatz antippen · Zum Beenden Bau abbrechen wählen.",
			"map": "Im freien Bild ziehen · Figur wählen, um zurückzukehren · Deine Figur bleibt an ihrem Ort."
		}
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
		"game": _emit("cancel_build" if _build_active else "pause")
		"pause", "journal": _emit("resume")
		"gallery": _close_gallery()
		"settings": _return_to(_settings_return)
		"confirm": _return_to(_confirm_return)
		"menu": _confirm("Spiel beenden?", "Ein laufender Lebensweg wird vor dem Beenden gespeichert.", "quit", {})
		"dialog": notify("Wähle eine Antwort, um dieses Gespräch abzuschließen.")
		_: return false
	return true


func _open_screen(screen_name: String, darken: bool, menu_style := false) -> void:
	_reset_touch()
	_touch_pad = null
	_touch_actions.clear()
	_cancel_build_button = null
	if _intro_tween != null and _intro_tween.is_valid():
		_intro_tween.kill()
	if _screen != null:
		_screen.hide()
		_screen.queue_free()
	_view_state = screen_name
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
	panel.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	panel.offset_left = 24
	panel.offset_right = -24
	panel.offset_top = 24
	panel.offset_bottom = 91
	_screen.add_child(panel)
	var row := _row(10 if _compact_layout else 22)
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
		metric.custom_minimum_size.x = 72 if _compact_layout else 115
		metric.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		row.add_child(metric)
		_hud_labels[resource] = metric
	var fill := Control.new()
	fill.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(fill)
	_hud_labels["time"] = _label("", 12, MUTED)
	_hud_labels["time"].vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(_hud_labels["time"])
	if _compact_layout:
		row.add_child(_button("Chronik", _show_journal, false, 12))
		row.add_child(_button("Pause", func(): _emit("pause"), false, 12))
	else:
		row.add_child(_button("Speichern", func(): _emit("save"), false, 13))
		row.add_child(_button("Pause  ·  Esc", func(): _emit("pause"), false, 13))


func _build_objective_card() -> void:
	var panel := _panel(true)
	panel.position = Vector2(24, 110)
	panel.size = Vector2(272, 150) if _compact_layout else Vector2(300, 180)
	_screen.add_child(panel)
	var short_layout := _compact_layout and _content_size().y < 600
	var column := _column(6 if short_layout else 10)
	panel.add_child(column)
	if not (_compact_layout and _content_size().y < 520):
		column.add_child(_label("DEIN NÄCHSTER SCHRITT", 11, BRONZE))
	_hud_labels["objective_title"] = _label("", 17 if short_layout else 19 if _compact_layout else 23, CREAM, true)
	_hud_labels["objective_title"].autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(_hud_labels["objective_title"])
	_hud_labels["objective_text"] = _label("", 12 if short_layout else 13 if _compact_layout else 15, MUTED)
	_hud_labels["objective_text"].autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	if _compact_layout:
		_hud_labels["objective_text"].max_lines_visible = 2 if _content_size().y < 520 else 3 if short_layout else 4
		_hud_labels["objective_text"].text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	column.add_child(_hud_labels["objective_text"])
	if _compact_layout:
		_hud_labels["compact_life"] = _label("", 12, BRONZE)
		_hud_labels["compact_life"].autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		column.add_child(_hud_labels["compact_life"])


func _build_character_card() -> void:
	var panel := _panel(false)
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


func _build_touch_controls() -> void:
	if _touch_enabled:
		_touch_pad = TouchPadScript.new()
		_touch_pad.name = "MovementPad"
		_touch_pad.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
		_touch_pad.offset_left = 16
		_touch_pad.offset_right = 168
		_touch_pad.offset_top = -172
		_touch_pad.offset_bottom = -20
		_screen.add_child(_touch_pad)
		_touch_pad.axis_changed.connect(func(axis: Vector2): _emit("move_axis", {"x": axis.x, "y": axis.y}))
		var right := VBoxContainer.new()
		right.name = "TouchActions"
		right.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
		right.offset_left = -168
		right.offset_right = -16
		right.offset_top = -164
		right.offset_bottom = -20
		right.add_theme_constant_override("separation", 10)
		right.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_screen.add_child(right)
		for item in [["interact", "Interagieren"], ["attack", "Angreifen"]]:
			var button: Button = _touch_button(item[1], _emit.bind(item[0], {}), item[0] == "attack")
			button.name = item[0].capitalize()
			button.custom_minimum_size.y = 62
			_touch_actions.append(button)
			right.add_child(button)
	_cancel_build_button = _touch_button("Bau abbrechen", func(): _emit("cancel_build"), false) if _touch_enabled else _button("Bau abbrechen", func(): _emit("cancel_build"), false, 14)
	_cancel_build_button.name = "CancelBuild"
	_cancel_build_button.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	_cancel_build_button.offset_left = -174 if _touch_enabled else -220
	_cancel_build_button.offset_right = -16 if _touch_enabled else -24
	_cancel_build_button.offset_top = -86 if _touch_enabled else -210
	_cancel_build_button.offset_bottom = -24 if _touch_enabled else -154
	_screen.add_child(_cancel_build_button)
	_update_touch_visibility()


func _touch_button(caption: String, callback: Callable, primary: bool) -> Button:
	var button: Button = TouchActionScript.new()
	button.text = caption
	button.set_meta("base_font_size", 13)
	button.add_theme_font_size_override("font_size", roundi(13 * _ui_scale))
	button.add_theme_stylebox_override("normal", _button_style(primary, false))
	button.add_theme_stylebox_override("hover", _button_style(primary, true))
	button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	button.pressed.connect(func():
		_play_click()
		callback.call()
	)
	return button


func _reset_touch() -> void:
	if is_instance_valid(_touch_pad):
		_touch_pad.reset()
	for button in _touch_actions:
		if is_instance_valid(button):
			button.reset()
	if is_instance_valid(_cancel_build_button) and _cancel_build_button.has_method("reset"):
		_cancel_build_button.reset()


func _update_touch_visibility() -> void:
	if _view_state != "game":
		return
	var personal := _mode == "person" and not _build_active
	if is_instance_valid(_touch_pad):
		_touch_pad.visible = personal
	for button in _touch_actions:
		if is_instance_valid(button):
			button.visible = personal
	if is_instance_valid(_cancel_build_button):
		_cancel_build_button.visible = _build_active


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
	var controls := "Links bewegen. Rechts interagieren oder angreifen. Im freien Bild ziehen, um die Kamera zu drehen. Zum Bauen Hütte wählen und einen freien Bauplatz antippen." if _touch_enabled else "WASD bewegen · E interagieren · Linksklick / Leertaste kämpfen · B bauen · Tab Stadt · M Karte"
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
		"intro": show_intro()
		"game": show_game(_state)
		"menu": show_menu(_can_continue)
		"settings": _show_settings(_settings_return)
		"pause": show_pause()
		"journal": _show_journal(false)
		"confirm": _render_confirmation()
		"dialog": show_dialog(String(_dialog_data.title), String(_dialog_data.text), _dialog_data.choices)


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
	if stage == "ended":
		return ["Eine Spur bleibt", "Dieser erste Abschnitt ist abgeschlossen. Deine Entscheidung steht in der Chronik. Speichere deinen Lebensweg."]
	if bool(state.get("encounter", {}).get("active", false)):
		return ["Für das Dorf", "Bleibe bei deiner Truppe. Nutze Abstand und gezielte Treffer. Ein gefallener Gefährte kehrt nicht durch einen Kamerawechsel zurück."]
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
		return ["Der nächste Lebensabschnitt", "Gehe zum Trainingsplatz. Beginne die Ausbildung und triff den Übungspfahl dreimal. Treffer: %d / 3." % int(progress.get("training_hits", 0))]
	if int(state.get("squad", {}).get("alive", 0)) == 0:
		return ["Gemeinsam stärker", "Du hast die Grundlagen gelernt. Rekrutiere eine kleine Truppe. Jeder Rekrut braucht Sold und Nahrung."]
	return ["Verantwortung übernehmen", "Deine Truppe ist bereit. Bereite die Verteidigung vor und kämpfe persönlich an ihrer Seite."]


func _career_name(stage: String) -> String:
	match stage:
		"training": return "In Ausbildung"
		"trained": return "Ausgebildet"
		"skirmish", "aftermath": return "Truppenführer"
		"ended": return "Chronik abgeschlossen"
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
	var note := _label("Der Prototyp enthält dezente Bedienklänge. Musik und vertonte Gespräche sind noch nicht enthalten.\n\nDie Grundfunktionen sind ohne Mikrofon bedienbar.", 13, MUTED)
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
	var config := ConfigFile.new()
	if config.load(SETTINGS_PATH) == OK:
		_ui_scale = clampf(float(config.get_value("interface", "scale", 1.0)), 0.85, 1.25)
		_reduce_motion = bool(config.get_value("interface", "reduce_motion", false))
		_volume = clampf(float(config.get_value("audio", "volume", 0.55)), 0.0, 1.0)
		_touch_enabled = bool(config.get_value("input", "touch_controls", _touch_enabled))
		_diagnostics = bool(config.get_value("graphics", "diagnostics", false))
		_quality = String(config.get_value("graphics", "quality", "balanced"))
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
	config.set_value("audio", "volume", _volume)
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


func _play_click() -> void:
	if DisplayServer.get_name() == "headless":
		return
	if _sound_player != null and _volume > 0.001:
		_sound_player.play()
