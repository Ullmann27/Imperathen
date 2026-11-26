extends Node
## A single market session for the existing exploration player and camera.
## The ordinary campaign remains suspended and is never passed into this node.

signal closed
signal message(text: String)
const Model = preload("res://scripts/domain/world_model.gd")
const Trade = preload("res://scripts/city_trade.gd")
const LifeSession = preload("res://scripts/world/city_life_session.gd")
const MarketPanel = preload("res://scripts/city_support_panel.gd")
const MANIFEST := "res://assets/city_detail/shops/city_market_anchors.json"
const SAVE_PATH := "user://imperathen_city_trade.json"
const FRONT_OFFSET := Vector3(0.0, 0.92, 2.3)
var available := false
var persist := true
var save_path := SAVE_PATH
var player: CharacterBody3D
var sites: Dictionary = {}
var model
var panel
var _serial := 0
var _living_city: LifeSession


static func verified_sites(city: Node3D) -> Dictionary:
	if not is_instance_valid(city) or city.name != "RomanCity" or not city.is_inside_tree():
		return {}
	if not FileAccess.file_exists(MANIFEST):
		return {}
	var payload: Variant = JSON.parse_string(FileAccess.get_file_as_string(MANIFEST))
	if typeof(payload) != TYPE_DICTIONARY or payload.get("format", "") != "imperathen-city-market-anchors" or int(payload.get("version", 0)) != 1:
		return {}
	var entries: Variant = payload.get("shops")
	if typeof(entries) != TYPE_ARRAY or entries.size() != Trade.shop_catalog().size():
		return {}
	var expected: Dictionary = {}
	for shop: Dictionary in Trade.shop_catalog():
		expected[str(shop.id)] = true
	var result: Dictionary = {}
	for entry: Variant in entries:
		if typeof(entry) != TYPE_DICTIONARY:
			return {}
		var id := str(entry.get("shop_id", ""))
		var coordinates: Variant = entry.get("center_godot_m")
		if not expected.has(id) or result.has(id) or typeof(coordinates) != TYPE_ARRAY or coordinates.size() != 3:
			return {}
		for coordinate: Variant in coordinates:
			if typeof(coordinate) not in [TYPE_INT, TYPE_FLOAT] or not is_finite(float(coordinate)):
				return {}
		var center := Vector3(float(coordinates[0]), float(coordinates[1]), float(coordinates[2]))
		var stand := city.find_child(str(entry.get("stand_node", "")), true, false) as MeshInstance3D
		if not is_instance_valid(stand) or stand.mesh == null or stand.global_position.distance_to(center) > 0.15:
			return {}
		# The generator's front faces Godot +Z; the access point is in front
		# of the actual medium-size counter, not at the miniature test district.
		result[id] = center + FRONT_OFFSET
	return result

func setup(city: Node3D, body: CharacterBody3D, persistent: bool, stable_trader: Marker3D = null) -> bool:
	if model != null or is_instance_valid(panel) or not is_instance_valid(body):
		return false
	player = body
	persist = persistent
	sites = verified_sites(city)
	if sites.is_empty():
		message.emit("Handel nicht verfügbar: Marktstandorte fehlen oder stimmen nicht überein.")
		return false
	if is_instance_valid(stable_trader) and stable_trader.is_inside_tree():
		sites["equarius"] = stable_trader.global_position
	model = Model.new()
	model.new_game("italia", true, true)
	model.city_trade_sites = sites.duplicate(true)
	if persist and (FileAccess.file_exists(save_path) or FileAccess.file_exists(save_path + ".bak")):
		var loaded: Dictionary = model.load_game(save_path)
		if not loaded.get("ok", false):
			message.emit("Marktspielstand beschädigt. Die Datei bleibt erhalten; Handel gesperrt.")
			return false
	var enabled: Dictionary = model.execute("city_trade_enable", {})
	if not enabled.get("ok", false):
		message.emit(str(enabled.get("message", "Handel konnte nicht geöffnet werden.")))
		return false
	panel = MarketPanel.new()
	panel.layer = 21
	panel.embedded_city = true
	panel.shop_sites = sites.duplicate(true)
	add_child(panel)
	panel.command_requested.connect(execute)
	panel.closed.connect(func(): closed.emit())
	available = true
	_sync()
	return true

## Opt-in QA bridge. Never attach to the persisted legacy free-city wallet:
## campaign and city simulation must eventually be committed in ONE save.
func attach_living_city(session: LifeSession) -> bool:
	if not available or persist or is_open() or _living_city != null or session == null or session.life == null:
		return false
	_living_city = session
	return true

func is_open() -> bool:
	return available and is_instance_valid(panel) and panel.is_open()

func nearest() -> Dictionary:
	var id := ""
	var distance := INF
	if available and is_instance_valid(player):
		for key: String in sites:
			var d: float = player.global_position.distance_to(sites[key])
			if d < distance:
				id = key
				distance = d
	var label := ""
	for shop: Dictionary in Trade.shop_catalog(sites.has("equarius")):
		if shop.id == id:
			label = str(shop.name)
			break
	return {"id": id, "distance": distance, "label": label, "reachable": not id.is_empty() and distance <= Trade.RANGE}

func open_shop() -> bool:
	if not available or is_open():
		return false
	var target := nearest()
	if not target.reachable:
		message.emit("Gehe zum gewünschten Marktstand (höchstens 3 m).")
		return false
	model.set_player_position(player.global_position)
	_sync()
	panel.open_shop(str(target.id))
	panel.notify("")
	return true

func open_inventory() -> bool:
	if not available or is_open():
		return false
	model.set_player_position(player.global_position)
	_sync()
	panel.open_inventory()
	panel.notify("")
	return true

func close() -> void:
	if is_open():
		panel.close()

func _sync() -> void:
	if is_instance_valid(panel):
		panel.update_state(model.data)

func execute(command: String, args: Dictionary) -> Dictionary:
	if not is_open() or command == "city_trade_enable" or not Trade.COMMAND_FIELDS.has(command):
		return {"ok": false, "message": "Kein aktiver Handelsdialog."}
	if args.has("shop_id") and str(args.shop_id) != str(panel.shop_id):
		return {"ok": false, "message": "Der Auftrag gehört zu einem anderen Marktstand."}
	var coupled := _living_city != null and command in ["city_buy", "city_sell"]
	var buying := command == "city_buy"
	var amount := 0
	if coupled:
		var problem: String = Trade.validate_arguments(command, args)
		if not problem.is_empty():
			panel.notify(problem)
			message.emit(problem)
			return {"ok": false, "message": problem}
		var item: Dictionary = Trade.item_catalog()[str(args.item_id)]
		amount = int(args.quantity) * int(item.price if buying else item.sell_price)
		var issue: String = _living_city.trade_error(str(args.shop_id), str(args.item_id), int(args.quantity), amount, buying)
		if not issue.is_empty():
			var notice := "Stadtwirtschaft: Handel nicht möglich (%s)." % issue
			panel.notify(notice)
			message.emit(notice)
			return {"ok": false, "message": notice}
	model.set_player_position(player.global_position)
	var before: Dictionary = model.data.duplicate(true)
	_serial += 1
	var id := "city-%d-%d-%d" % [Time.get_ticks_usec(), int(model.data.revision), _serial]
	var result: Dictionary = model.execute(command, args, id)
	if result.get("ok", false) and coupled:
		if not _living_city.book_trade(str(args.shop_id), str(args.item_id), int(args.quantity), amount, buying):
			model.data = before
			model.changed.emit()
			result = {"ok": false, "message": "Handel zurückgenommen: Stadtwirtschaft konnte nicht buchen."}
	if result.get("ok", false) and persist:
		var saved: Dictionary = model.save_game(save_path)
		if not saved.get("ok", false):
			model.data = before
			model.changed.emit()
			result = {"ok": false, "message": "Handel zurückgenommen: " + str(saved.get("message", "Speichern fehlgeschlagen."))}
	_sync()
	panel.notify(str(result.get("message", "")))
	message.emit(str(result.get("message", "")))
	return result
