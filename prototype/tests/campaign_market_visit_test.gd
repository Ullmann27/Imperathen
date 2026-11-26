extends SceneTree
## An actual market visit from the I-02 migration fixture through Main, its
## pause menu, the exploration player's walking controller and the shop UI.
const Main = preload("res://main.tscn")
const Fixture := "res://tests/fixtures/mission_bridge_data/handoff_i02_correct_v5.json"
const Save := "user://imperathen_campaign.json"
var game
var checks := 0
var errors: Array[String] = []
var capture_dir := ""

func _initialize() -> void:
	if OS.get_environment("IMPERATHEN_ISOLATED_TEST") != "1" or FileAccess.file_exists(Save):
		printerr("Der Markttest braucht ein leeres isoliertes Godot-Benutzerverzeichnis.")
		quit(2)
		return
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--capture-dir=") and DisplayServer.get_name() != "headless":
			capture_dir = arg.trim_prefix("--capture-dir=")
			DirAccess.make_dir_recursive_absolute(capture_dir)
			RenderingServer.render_loop_enabled = false
	_run.call_deferred()

func _run() -> void:
	root.size = Vector2i(1000, 600)
	root.content_scale_size = Vector2i.ZERO
	game = Main.instantiate()
	root.add_child(game)
	game._show_menu()
	var file := FileAccess.open(Save, FileAccess.WRITE)
	file.store_string(FileAccess.get_file_as_string(Fixture))
	file.close()
	game.ui.action_requested.emit("continue", {})
	await process_frame
	if expect(game.screen == "playing" and game.model.data.player.age == 12, "I-02-Spielstand als Kind geladen"):
		await _visit()
	game.free()
	await process_frame
	print("CAMPAIGN_MARKET_VISIT_RESULT ", JSON.stringify({"checks": checks, "fehler": errors}))
	print("CAMPAIGN_MARKET_VISIT_PASS" if errors.is_empty() else "CAMPAIGN_MARKET_VISIT_FAIL")
	quit(0 if errors.is_empty() else 1)

func _visit() -> void:
	var purse: int = game.model.data.resources.denarii
	game.ui.action_requested.emit("pause", {})
	var travel := button(game.ui, "Stadtmarkt besuchen")
	if not expect(travel != null and game.screen == "paused", "Besuch ist in der Kampagnenpause erreichbar"):
		return
	travel.pressed.emit()
	var city = game.city_exploration
	if not expect(city != null and city.market.available and city.market.model == game.model and city.living_city != null, "Echter Stadtmarkt verwendet die laufende Kampagne"):
		if city != null:
			city._request_leave()
		return
	var home: Array = game.model.data.player.position.duplicate()
	var district = city.living_city.life
	var baker: int = district.business_for_shop("bakery")
	expect(not city.market.nearest().reachable and city.ambient_people == null and city.crowd.active.is_empty(), "Ankunft auf der Marktstraße ohne entfernten Einkauf und ohne doppelte Statisten")
	await physics_frame
	await process_frame
	await capture("01-markt-bei-ankunft")
	var settled := await _settle(city)
	if not expect(settled and baker >= 0, "Stadtbetriebe auf dem Kampagnenkalender bereit"):
		city._request_leave()
		return
	for hour in 12:
		if city.living_city.quote("bakery", "bread").reason.is_empty():
			break
		city._wait_button.pressed.emit()
		if not await _settle(city):
			break
	var quote: Dictionary = city.living_city.quote("bakery", "bread")
	if not expect(quote.reason.is_empty() and int(quote.stock) > 0, "Bäckerei ist laut Arbeitsplan besetzt: " + str(quote)):
		city._request_leave()
		return
	# Wait in engine frames for the presentation search to visit all IDs.
	for tick in 120:
		await physics_frame
	var roster: Dictionary = city.resident_view.actors
	var verified := 0
	for person: int in roster:
		var actor: Node3D = roster[person]
		if actor.get_meta("resident_name") == district.state.residents[person].name and actor.is_visible_in_tree() and actor.get_node("Figure").body != null:
			verified += 1
	expect(verified > 0 and verified == roster.size(), "Sichtbare Körper referenzieren gespeicherte Anwohner und importierte Figuren")
	await capture("02-markt-geoeffnet")
	var target: Vector3 = city.market.sites.bakery
	var start: Vector3 = city.player.position
	for _tick in 480:
		var to_counter := Vector2(target.x - city.player.position.x, target.z - city.player.position.z)
		if to_counter.length() < 1.8:
			break
		city._touch_move = to_counter.normalized().rotated(city._yaw)
		await physics_frame
	city._touch_move = Vector2.ZERO
	city._interact()
	if not expect(city.market.is_open() and city.market.panel.shop_id == "bakery", "Zu Fuß den echten Bäcker erreicht und Handelsfenster geöffnet"):
		city._request_leave()
		return
	var buy := button(city.market.panel, "Kaufen")
	if not expect(buy != null and not buy.disabled, "Der tatsächliche Kaufknopf ist freigegeben"):
		city.market.close()
		city._request_leave()
		return
	if expect(city._bakery != null, "Blender-Auslage am vorhandenen Tresen installiert"):
		city._bakery.set_stock(1)
		expect(city._bakery.loaves.filter(func(loaf): return loaf.visible).size() == 1, "Beim letzten Brot bleibt genau ein Laib ausgestellt")
		city._update_bakery()
		expect(city._bakery.loaves.filter(func(loaf): return loaf.visible).size() == 6, "Bei vollem Bestand sind alle sechs Musterlaibe sichtbar")
	var stock: int = district.state.businesses[baker].stock.bread
	var till: int = district.state.businesses[baker].till
	buy.pressed.emit()
	expect(game.model.data.resources.denarii == purse - 2 and game.model.data.village.city_trade.inventory.bread == 1, "Kauf zieht zwei Denare ab und legt Brot in den gemeinsamen Beutel")
	expect(district.state.businesses[baker].stock.bread == stock - 1 and district.state.businesses[baker].till == till + 128, "Ein Brot und 128 Quadranten korrekt beim Betrieb gebucht")
	print("MARKTBESUCH ", JSON.stringify({"bewohner": district.state.residents.size(), "sichtbar": verified, "gehstrecke_m": snappedf(start.distance_to(city.player.position), .01), "sekunde": game.model.data.calendar.clock.second, "vorrat_vorher": stock, "vorrat_nachher": district.state.businesses[baker].stock.bread}))
	await capture("03-brotkauf")
	game._on_go_back_requested()
	expect(not city.market.is_open() and not city.paused, "Zurück schließt ausschließlich den geöffneten Handel")
	city._request_leave()
	expect(game.screen == "playing" and game.model.data.player.position == home, "Die Kampagne setzt am ursprünglichen Dorfstandort fort")
	expect(not FileAccess.file_exists("user://imperathen_city_trade.json"), "Die Kampagne schreibt keinen zweiten Marktspielstand")
	game._show_menu()
	game.ui.action_requested.emit("continue", {})
	expect(game.screen == "playing" and game.model.data.resources.denarii == purse - 2 and game.model.data.village.city_trade.inventory.bread == 1, "Kauf über das Hauptmenü erneut geladen")

func _settle(city: Node) -> bool:
	# Main remains the clock owner. This loop only runs budgeted catch-up.
	for _slice in 12000:
		var progress: Dictionary = city.market.sync_campaign()
		if not progress.ok:
			return false
		if progress.done:
			await process_frame
			return true
	return false

func button(parent: Node, caption: String) -> Button:
	for control in parent.find_children("*", "Button", true, false):
		if control.text == caption and control.is_visible_in_tree():
			return control
	return null

func expect(ok: bool, label: String) -> bool:
	checks += 1
	if not ok:
		errors.append(label)
		printerr("MARKT_FEHLER ", label)
	return ok

func capture(label: String) -> void:
	if capture_dir.is_empty():
		return
	RenderingServer.render_loop_enabled = true
	await process_frame
	await RenderingServer.frame_post_draw
	expect(root.get_texture().get_image().save_png(capture_dir.path_join(label + ".png")) == OK, "Godot-Aufnahme " + label)
	RenderingServer.render_loop_enabled = false
