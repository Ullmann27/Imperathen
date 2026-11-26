extends SceneTree
## Real main.tscn render review of the in-game HUD (D-038 evidence). The same
## script runs on the "before" and "after" source: a fresh Roman childhood is
## started, the film choice is made, and identical states are captured at
## 1280 x 720 and 1384 x 1536: calm exploration, a dialogue with choices, the
## inventory and the pause menu. It also measures the screen share of the HUD
## in calm exploration, geometrically and by a pixel difference against the
## same frame without the HUD layer.
## Usage: godot --path prototype --script res://tests/roman_hud_review.gd -- <output> [label]

const EntryScene = preload("res://main.tscn")
const Life = preload("res://scripts/story/village_life.gd")
const UI = preload("res://scripts/ui/game_ui.gd")
const Model = preload("res://scripts/domain/world_model.gd")
const Economy = preload("res://scripts/domain/village_economy.gd")
const MarketPanel = preload("res://scripts/city_support_panel.gd")
const SIZES := [Vector2i(1280, 720), Vector2i(1384, 1536)]
const CALM_SECONDS := 14.0
const DRY_CALM_SECONDS := 2.0
const YARD := Vector2(-8.6, 6.9)
const CAMERA_YAW := 2.45

var game
var output := ""
var label := "review"
var captures: Array[Dictionary] = []
var measurements: Array[Dictionary] = []
var notes: Array[String] = []
var failed := false
## Headless logic check only (no pixels): IMPERATHEN_REVIEW_DRYRUN=1.
var dry_run := false


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	dry_run = DisplayServer.get_name() == "headless" and OS.get_environment("IMPERATHEN_REVIEW_DRYRUN") == "1"
	if args.is_empty() or (DisplayServer.get_name() == "headless" and not dry_run) or OS.get_environment("IMPERATHEN_ISOLATED_TEST") != "1":
		printerr("An isolated real viewport and an output folder are required.")
		quit(2)
		return
	output = args[0]
	if args.size() > 1:
		label = args[1]
	DirAccess.make_dir_recursive_absolute(output)
	_run.call_deferred()


func _run() -> void:
	root.content_scale_size = Vector2i.ZERO
	root.size = SIZES[0]
	game = EntryScene.instantiate()
	root.add_child(game)
	await _frames(4)
	game.ui.set("_touch_enabled", true)
	game.ui.set_quality("balanced")
	game.ui._finish_intro()
	await _frames(2)
	game.ui.action_requested.emit("new_game", {})
	await _frames(4)
	game._opening_skip()
	game._opening_next()
	await _frames(6)
	game._opening_skip()
	if game.screen == "opening":
		game.opening_overlay.choice_requested.emit("i01_help")
		await _frames(4)
		game._opening_skip()
		game._opening_next()
	await _frames(10)
	_expect(game.screen == "playing", "The fresh childhood reaches play")
	await _sequence()
	var report := {
		"label": label, "engine": Engine.get_version_info().string,
		"renderer": RenderingServer.get_current_rendering_method(),
		"adapter": RenderingServer.get_video_adapter_name(), "vendor": RenderingServer.get_video_adapter_vendor(),
		"api": RenderingServer.get_video_adapter_api_version(), "display_driver": DisplayServer.get_name(),
		"quality_profile": game.ui.get_quality(), "world_profile": game.world.get_quality_profile(),
		"touch_hud": true, "calm_seconds": CALM_SECONDS, "camera_yaw": CAMERA_YAW, "yard_position": [YARD.x, YARD.y],
		"loaded_models": _loaded_models(), "ui_assets": _ui_assets(), "lighting": _lighting(),
		"captures": captures, "hud_area": measurements, "notes": notes,
		"performance_note": "Software rendering under xvfb (llvmpipe); frame times are relative only and say nothing about the Fold7.",
	}
	game.queue_free()
	await _frames(3)
	game = null
	await _fixtures()
	var file := FileAccess.open(output.path_join("roman-hud-review-%s.json" % label), FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "  ") + "\n")
	file.close()
	print("ROMAN_HUD_REVIEW_FAIL" if failed else "ROMAN_HUD_REVIEW_PASS")
	quit(1 if failed else 0)


func _sequence() -> void:
	# Each state is captured at every size before the story moves on, so both
	# resolutions show exactly the same game state.
	# 1. Calm exploration in the yard, the same place and camera every time.
	for extent: Vector2i in SIZES:
		var tag := "%dx%d" % [extent.x, extent.y]
		await _resize(extent)
		if game.screen != "playing":
			game._resume()
			await _frames(4)
		_place(YARD)
		game.world.set("_camera_yaw", CAMERA_YAW)
		game.ui.show_game(game._ui_state())
		var started := Time.get_ticks_msec()
		while Time.get_ticks_msec() - started < int((DRY_CALM_SECONDS if dry_run else CALM_SECONDS) * 1000.0):
			game.world.set("_camera_yaw", CAMERA_YAW)
			await process_frame
		await _frames(3)
		var frame := await _perf(90)
		await _capture("explore-" + tag, {"frame": frame})
		measurements.append(await _measure(tag))
	# 2. A conversation with choices: Julia at the family table.
	await _resize(SIZES[0])
	var julia := Life.actor_position(game.model.data, "julia")
	_place(julia + Vector2(0.9, 0.7))
	await _frames(3)
	game.ui.action_requested.emit("interact", {})
	await _frames(20)
	if game.screen not in ["village_dialog", "dialog"]:
		notes.append("interact did not open a dialogue (screen %s); asked Julia directly" % game.screen)
		game.world.action_requested.emit("village_npc", {"npc_id": "julia"})
		await _frames(20)
	for extent: Vector2i in SIZES:
		await _resize(extent)
		await _settle(0.8)
		await _capture("dialogue-%dx%d" % [extent.x, extent.y])
	game.ui.action_requested.emit("village_close", {})
	await _frames(6)
	if game.screen != "playing":
		game._resume()
		await _frames(4)
	# 3. Inventory: the boy takes the three cups first, so there is something to carry.
	_place(Vector2(-15.32, 12.05) + Vector2(0.75, -0.1))
	await _frames(3)
	if not str(game._ui_state().get("childhood_view", {}).get("carried", [])).contains("Becher"):
		game.ui.action_requested.emit("interact", {})
		await _frames(6)
	if game.ui.get_method_argument_count("_show_journal") >= 2:
		game.ui._show_journal(true, "equipment")
	else:
		game.ui._show_journal(true)
	for extent: Vector2i in SIZES:
		await _resize(extent)
		await _settle(0.8)
		await _capture("inventory-%dx%d" % [extent.x, extent.y])
	game.ui.action_requested.emit("resume", {})
	await _frames(6)
	# 3b. Character and abilities, then the child's view of village life.
	if game.ui.get_method_argument_count("_show_journal") >= 2:
		game.ui._show_journal(true, "abilities")
		for extent: Vector2i in SIZES:
			await _resize(extent)
			await _settle(0.8)
			await _capture("abilities-%dx%d" % [extent.x, extent.y])
		game.ui.action_requested.emit("resume", {})
		await _frames(6)
	game.ui.action_requested.emit("village_panel", {"tab": "overview"})
	await _frames(6)
	if game.screen == "village_panel":
		for extent: Vector2i in SIZES:
			await _resize(extent)
			await _settle(0.8)
			await _capture("village-%dx%d" % [extent.x, extent.y])
	else:
		notes.append("village panel did not open (screen %s)" % game.screen)
	game.ui.action_requested.emit("resume", {})
	await _frames(6)
	# 4. The pause menu over the live world.
	game.ui.action_requested.emit("pause", {})
	for extent: Vector2i in SIZES:
		await _resize(extent)
		await _settle(0.8)
		await _capture("menu-%dx%d" % [extent.x, extent.y])
	game.ui.action_requested.emit("resume", {})
	await _frames(6)


## Screens the twelve-year-old does not reach yet: administration with work
## assignment, the adult character sheet and the market. The real UI classes
## show real model state on a plain backdrop (no world behind them); the
## captures are marked "fixture" and are not in-world frames.
func _fixtures() -> void:
	var backdrop := ColorRect.new()
	backdrop.color = Color(0.2, 0.22, 0.2)
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(backdrop)
	var model = Model.new()
	model.new_game("italia", true)
	model.set_player_position(Vector3(2, 1, 9))
	model.execute("village_talk", {"npc_id": "decimus", "choice": "meet"})
	model.execute("village_request_work")
	var ui = UI.new()
	root.add_child(ui)
	await _frames(4)
	ui.set("_touch_enabled", true)
	for tab in ["overview", "work", "people", "map"]:
		for extent: Vector2i in SIZES:
			await _resize(extent)
			ui.show_village_panel(model.data, tab)
			await _settle(0.6)
			await _plain("admin-%s-%dx%d" % [tab, extent.x, extent.y], "village panel, tab " + tab)
	var state: Dictionary = model.data.duplicate(true)
	state["village_view"] = Life.view(model.data)
	state["village_economy_view"] = Economy.view(model.data)
	if ui.get_method_argument_count("_show_journal") >= 2:
		for tab in ["abilities", "equipment"]:
			for extent: Vector2i in SIZES:
				await _resize(extent)
				ui.show_game(state)
				ui._show_journal(false, tab)
				await _settle(0.6)
				await _plain("character-%s-%dx%d" % [tab, extent.x, extent.y], "adult codex, tab " + tab)
	else:
		for extent: Vector2i in SIZES:
			await _resize(extent)
			ui.show_game(state)
			ui._show_journal(false)
			await _settle(0.6)
			await _plain("character-journal-%dx%d" % [extent.x, extent.y], "adult journal")
	ui.queue_free()
	await _frames(3)
	# Market and bag of the city district (adult fixture, as in city_inventory_ui_test).
	var trader = Model.new()
	trader.new_game("italia", true, true)
	trader.execute("city_trade_enable", {})
	var market_state: Dictionary = trader.data.duplicate(true)
	market_state.player.age = 18
	market_state.village.city_trade.inventory.linen_tunic = 1
	market_state.village.city_trade.purchases.clothier.linen_tunic = 1
	market_state.village.city_trade.equipment.body = "linen_tunic"
	var panel := MarketPanel.new()
	root.add_child(panel)
	await _frames(3)
	panel.update_state(market_state)
	for extent: Vector2i in SIZES:
		await _resize(extent)
		panel.open_shop("clothier")
		await _settle(0.6)
		await _plain("trade-shop-%dx%d" % [extent.x, extent.y], "market, clothier")
		panel.open_inventory()
		await _settle(0.6)
		await _plain("trade-bag-%dx%d" % [extent.x, extent.y], "market, bag")
	panel.queue_free()
	backdrop.queue_free()
	await _frames(3)
	root.size = SIZES[0]


func _plain(name: String, what: String) -> void:
	await _frames(1)
	var picture := root.get_texture().get_image() if not dry_run else Image.create(root.size.x, root.size.y, false, Image.FORMAT_RGB8)
	var saved := dry_run or (picture != null and not picture.is_empty() and picture.save_png(output.path_join(name + ".png")) == OK)
	_expect(saved, "Rendered capture " + name)
	captures.append({"file": name + ".png", "pixels": [picture.get_width(), picture.get_height()], "screen": what, "fixture": true})


func _resize(extent: Vector2i) -> void:
	if root.size != extent:
		root.size = extent
		await _frames(8)


func _place(point: Vector2) -> void:
	game.world.get_node("Player").position = Vector3(point.x, 1.35, point.y)
	game.model.set_player_position(game.world.get_player_position())
	game.world.sync_state(game.model.data)


func _frames(count: int) -> void:
	for index in count:
		if dry_run:
			await process_frame
		else:
			await RenderingServer.frame_post_draw


func _settle(seconds: float) -> void:
	var started := Time.get_ticks_msec()
	while Time.get_ticks_msec() - started < int(seconds * 1000.0):
		await process_frame
	await _frames(2)


func _perf(count: int) -> Dictionary:
	var samples: Array[float] = []
	var last := Time.get_ticks_usec()
	for index in count:
		await _frames(1)
		var now := Time.get_ticks_usec()
		samples.append((now - last) / 1000.0)
		last = now
	samples.sort()
	var total := 0.0
	for value in samples:
		total += value
	return {"frames": count, "mean_ms": snappedf(total / samples.size(), 0.01), "median_ms": snappedf(samples[samples.size() / 2], 0.01),
		"p95_ms": snappedf(samples[int(samples.size() * 0.95)], 0.01),
		"static_memory_mb": snappedf(Performance.get_monitor(Performance.MEMORY_STATIC) / 1048576.0, 0.1),
		"video_memory_mb": snappedf(Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED) / 1048576.0, 0.1),
		"texture_memory_mb": snappedf(Performance.get_monitor(Performance.RENDER_TEXTURE_MEM_USED) / 1048576.0, 0.1),
		"draw_calls": int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)),
		"objects": int(Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME))}


func _capture(name: String, extra: Dictionary = {}) -> void:
	await _frames(1)
	var picture := root.get_texture().get_image() if not dry_run else Image.create(root.size.x, root.size.y, false, Image.FORMAT_RGB8)
	var saved := dry_run or (picture != null and not picture.is_empty() and picture.save_png(output.path_join(name + ".png")) == OK)
	_expect(saved, "Rendered capture " + name)
	var entry := {"file": name + ".png", "pixels": [picture.get_width(), picture.get_height()], "screen": game.screen,
		"ui_state": game.ui.get("_view_state"), "player": [game.world.get_player_position().x, game.world.get_player_position().z],
		"camera_yaw": game.world.get("_camera_yaw"), "objective": game.ui._objective(game._ui_state())}
	entry.merge(extra)
	captures.append(entry)


## HUD share of the frame in calm exploration. Geometric: union of every
## visible, drawing HUD element (effective opacity > 5 %). Pixel: pixels that
## differ by more than 6 % between the frame with and without the HUD layer,
## minus pixels that already differ between two HUD-less frames (world motion).
func _measure(tag: String) -> Dictionary:
	var screen: Control = game.ui.get("_screen")
	var extent := Vector2(root.size)
	var cell := 4.0
	var columns := int(ceil(extent.x / cell))
	var rows := int(ceil(extent.y / cell))
	var mask := PackedByteArray()
	mask.resize(columns * rows)
	var elements: Array[Dictionary] = []
	_cover(screen, mask, columns, rows, cell, elements, 1.0)
	var covered := 0
	for value in mask:
		covered += value
	if dry_run:
		return {"resolution": tag, "geometric_share": snappedf(float(covered) / float(columns * rows), 0.0001), "elements": elements}
	await RenderingServer.frame_post_draw
	var with_hud := root.get_texture().get_image()
	game.ui.visible = false
	await _frames(2)
	var without_a := root.get_texture().get_image()
	await _frames(1)
	var without_b := root.get_texture().get_image()
	game.ui.visible = true
	await _frames(2)
	var changed := 0
	var noise := 0
	var step := 2
	var sampled := 0
	for y in range(0, with_hud.get_height(), step):
		for x in range(0, with_hud.get_width(), step):
			sampled += 1
			var base := without_a.get_pixel(x, y)
			var moving := _differs(base, without_b.get_pixel(x, y))
			if moving:
				noise += 1
			elif _differs(with_hud.get_pixel(x, y), base):
				changed += 1
	without_a.save_png(output.path_join("explore-%s-no-hud.png" % tag))
	return {"resolution": tag, "geometric_share": snappedf(float(covered) / float(columns * rows), 0.0001),
		"pixel_share": snappedf(float(changed) / float(sampled), 0.0001),
		"pixel_noise_share": snappedf(float(noise) / float(sampled), 0.0001), "elements": elements}


func _differs(a: Color, b: Color) -> bool:
	return absf(a.r - b.r) + absf(a.g - b.g) + absf(a.b - b.b) > 0.18


func _cover(node: Node, mask: PackedByteArray, columns: int, rows: int, cell: float, elements: Array[Dictionary], alpha: float) -> void:
	if node is CanvasItem:
		var item := node as CanvasItem
		if not item.visible:
			return
		alpha *= item.modulate.a
		if alpha <= 0.05:
			return
	if node is Control and _draws(node as Control):
		var control := node as Control
		var rect := control.get_global_rect().intersection(Rect2(Vector2.ZERO, Vector2(root.size)))
		if rect.has_area():
			var x0 := int(rect.position.x / cell)
			var y0 := int(rect.position.y / cell)
			var x1 := mini(columns - 1, int((rect.end.x - 0.01) / cell))
			var y1 := mini(rows - 1, int((rect.end.y - 0.01) / cell))
			for y in range(y0, y1 + 1):
				for x in range(x0, x1 + 1):
					mask[y * columns + x] = 1
			elements.append({"name": str(control.name), "class": control.get_class(), "rect": [snappedf(rect.position.x, 1), snappedf(rect.position.y, 1), snappedf(rect.size.x, 1), snappedf(rect.size.y, 1)], "opacity": snappedf(alpha, 0.01)})
	for child: Node in node.get_children():
		_cover(child, mask, columns, rows, cell, elements, alpha)


func _draws(control: Control) -> bool:
	var script: Script = control.get_script()
	var name := str(control.name)
	if name in ["CameraLook"] or control is ScrollContainer:
		return false
	if control is Label:
		return not (control as Label).text.strip_edges().is_empty()
	if control is Button or control is TextureRect or control is ProgressBar or control is ColorRect:
		return true
	if control is PanelContainer or control is Panel:
		var box := control.get_theme_stylebox("panel")
		return box != null and not box is StyleBoxEmpty
	# Custom-drawn controls (compass, map, pad, medallions) draw in _draw().
	if script != null:
		for method: Dictionary in script.get_script_method_list():
			if str(method.get("name", "")) == "_draw":
				return true
	return false


func _loaded_models() -> Array:
	var paths := {}
	for node: Node in game.world.find_children("*", "MeshInstance3D", true, false):
		var mesh: Mesh = (node as MeshInstance3D).mesh
		var path := ""
		var owner_scene: Node = node.owner
		if owner_scene != null and not owner_scene.scene_file_path.is_empty():
			path = owner_scene.scene_file_path
		elif mesh != null and not mesh.resource_path.is_empty():
			path = mesh.resource_path.get_slice("::", 0)
		if not path.is_empty() and (node as MeshInstance3D).is_visible_in_tree():
			paths[path] = int(paths.get(path, 0)) + 1
	var result: Array = []
	for path: String in paths:
		result.append({"path": path, "instances": paths[path], "sha256": _sha(path)})
	result.sort_custom(func(a, b): return a.path < b.path)
	return result


func _ui_assets() -> Array:
	var result: Array = []
	for path in ["res://assets/ui/fonts/Cinzel-Variable.ttf", "res://shaders/roman_backdrop.gdshader", "res://scripts/ui/game_ui.gd",
			"res://scripts/ui/roman_hud/hud_style.gd", "res://scripts/ui/roman_hud/hud_icons.gd"]:
		if FileAccess.file_exists(path):
			result.append({"path": path, "sha256": _sha(path)})
	return result


func _lighting() -> Dictionary:
	var result := {}
	for node: Node in game.world.find_children("*", "DirectionalLight3D", true, false):
		var light := node as DirectionalLight3D
		if light.is_visible_in_tree():
			result[str(light.name)] = {"energy": snappedf(light.light_energy, 0.01), "color": light.light_color.to_html(false), "shadow": light.shadow_enabled}
	for node: Node in game.world.find_children("*", "WorldEnvironment", true, false):
		var environment: Environment = (node as WorldEnvironment).environment
		if environment != null:
			result["environment"] = {"tonemap": environment.tonemap_mode, "exposure": snappedf(environment.tonemap_exposure, 0.01), "fog": environment.fog_enabled, "ambient_energy": snappedf(environment.ambient_light_energy, 0.01)}
	return result


func _sha(path: String) -> String:
	var source := path
	if not FileAccess.file_exists(source):
		return ""
	var context := HashingContext.new()
	context.start(HashingContext.HASH_SHA256)
	context.update(FileAccess.get_file_as_bytes(source))
	return context.finish().hex_encode()


func _expect(ok: bool, message: String) -> void:
	if not ok:
		failed = true
		printerr("FAIL: " + message)
