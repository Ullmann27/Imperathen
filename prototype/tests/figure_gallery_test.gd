extends SceneTree

const Gallery := preload("res://scripts/ui/figure_gallery.gd")
var failures := 0
var checks := 0
var strict := true
var game


func _initialize() -> void:
	if OS.get_environment("IMPERATHEN_ISOLATED_TEST") != "1":
		printerr("Use disposable XDG_DATA_HOME and IMPERATHEN_ISOLATED_TEST=1.")
		quit(2)
		return
	strict = not "--fallback-only" in OS.get_cmdline_user_args()
	_run.call_deferred()


func _check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("FAIL ",label)


func _frames() -> void:
	await process_frame
	await process_frame
	await process_frame


func _button(label: String) -> Button:
	for node in game.ui._screen.find_children("*","Button",true,false):
		if node.text == label:
			return node
	return null


func _click(label: String) -> void:
	var button := _button(label)
	_check(button != null and not button.disabled, "Available button: " + label)
	if button:
		button.pressed.emit()


func _run() -> void:
	root.content_scale_size = Vector2i.ZERO
	root.size = Vector2i(960,540)
	game = load("res://main.tscn").instantiate()
	root.add_child(game)
	await _frames()
	game.ui.handle_back() # Intro to real, connected main menu.
	await _frames()
	var menu_state: Dictionary = game.model.data.duplicate(true)
	_click("Figuren")
	await _frames()
	var gallery = game.ui._screen.find_child("FigureGallery",true,false)
	_check(game.screen == "menu" and game.ui._view_state == "gallery","Gallery opens over main menu")
	var ids := {}
	for group in 2:
		gallery._section.select(group)
		gallery._section.item_selected.emit(group)
		for i in gallery._picker.item_count:
			gallery._picker.select(i)
			gallery._picker.item_selected.emit(i)
			ids[gallery.current_id] = true
			var image: Texture2D = gallery._image.texture
			if strict:
				_check(image != null and image.get_width() >= 200 and image.get_height() >= 200 and not gallery._missing.visible,"Load real portrait " + gallery.current_id)
			else:
				_check(gallery._missing.visible == (image == null), "Missing artwork has a visible fallback")
	_check(ids.size() == 18 and Gallery.texture("absent_fixture") == null, "Exactly 18 catalogue identities and a safe missing-file result")
	var before: String = gallery.current_id
	_click("Nächste ›")
	_check(before != gallery.current_id,"Next changes image")
	_click("‹ Vorige")
	_check(before == gallery.current_id,"Previous restores image")
	root.size = Vector2i(480,840)
	await _frames()
	_check(gallery._body.vertical and gallery.current_id == before and gallery._stage.size.y > 150,"Portrait layout survives resize with room for art")
	root.size = Vector2i(960,540)
	await _frames()
	_click("Zurück")
	await _frames()
	_check(game.ui._view_state == "menu" and game.model.data == menu_state,"Return to menu without mutating campaign")
	var picker: OptionButton = game.ui._screen.find_child("OriginPicker",true,false)
	var wa: int = game.ui.ORIGIN_IDS.find("wa")
	picker.select(wa)
	picker.item_selected.emit(wa)
	_click("Neues Leben")
	if game.ui._view_state == "dialog":
		_click("Neues Leben beginnen")
	await _frames()
	_check(game.model.data.origin_id == "wa" and game.model.data.player.age == 12,"New game retains selected origin and age")
	game._opening_skip()
	game._opening_next()
	await _frames()
	var unchosen: Dictionary = game.model.data.companion.duplicate(true)
	game.world.action_requested.emit("companion_interact",{})
	await _frames()
	var speaker: TextureRect = game.ui._screen.find_child("Speaker_aki",true,false)
	_check(game.screen == "dialog" and game.ui._view_state == "dialog","First encounter opens through the live world signal")
	_check(not strict or (speaker != null and speaker.texture != null),"Wa encounter shows Aki")
	_check(game.model.data.companion == unchosen,"Portrait display leaves the encounter undecided")
	_click("Ich komme später wieder")
	await _frames()
	game._pause()
	_click("Chronik")
	await _frames()
	var saved: Dictionary = game.model.data.duplicate(true)
	for id in ["hero_wa","aki"]:
		var portrait: TextureRect = game.ui._screen.find_child("Journal_"+id,true,false)
		_check(portrait != null and (not strict or portrait.texture != null),"Chronicle arrival portrait " + id)
	_check(game.ui._screen.find_child("Journal_adult_italia",true,false) == null,"Child chronicle excludes adult portraits")
	_click("Aki")
	await _frames()
	gallery = game.ui._screen.find_child("FigureGallery",true,false)
	_check(gallery.current_id == "aki" and gallery._picker.item_count == 2 and "Bei der Ankunft" in gallery._caption.text,"Journal opens the selected companion in the home collection")
	game._on_go_back_requested()
	await _frames()
	_check(game.ui._view_state == "journal" and game.screen == "paused" and game.model.data == saved,"Android Back returns to journal with session frozen")
	var adult_fixture := saved.duplicate(true)
	adult_fixture.origin_id = "italia"
	adult_fixture.player.age = 18
	game.ui.update_state(adult_fixture)
	game.ui._show_journal(false)
	await _frames()
	for id in ["hero_italia","marcus","adult_italia","adult_marcus"]:
		_check(game.ui._screen.find_child("Journal_"+id,true,false) != null,"Adult chronicle retains youth and adult image " + id)
	_click("Figuren")
	await _frames()
	gallery = game.ui._screen.find_child("FigureGallery",true,false)
	_check(gallery._picker.item_count == 4 and game.model.data == saved,"Adult gallery presentation leaves the authority untouched")
	game.ui.show_dialog("Begegnung","Ein Gespräch.",[{"label":"Helfen","action":"companion_help"}])
	await _frames()
	_check(game.ui._screen.find_child("Speaker_marcus",true,false) == null,"Adult encounter avoids a present-day youth portrait")
	game.queue_free()
	await _frames()
	print("FIGURE_GALLERY_RESULT checks=%d failures=%d real_textures=%s" % [checks,failures,strict])
	quit(1 if failures else 0)
