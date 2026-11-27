extends SceneTree
const Map := preload("res://scripts/ui/regional_map.gd")
const Plan := preload("res://scripts/world/world_stream_plan.gd")
var failed := 0
func check(ok: bool, label: String) -> void:
	if not ok:
		failed+=1
		push_error(label)
func _initialize() -> void:
	_run.call_deferred()
func _run() -> void:
	var map := Map.new()
	root.add_child(map)
	map.size=Vector2(1000,620)
	map.update_view({"player":Vector2(241,119),"heading":0.0})
	await process_frame
	var canvas = map.canvas
	canvas.focus_player()
	check(canvas.center==Vector2(241,119),"Map centers on actual player")
	var p:=Vector2(123,-456)
	check(canvas.unproject(canvas.project(p)).distance_to(p)<.01,"World-to-pixel mapping is invertible")
	for i in 8:
		canvas.zoom(1)
	check(canvas.level==4 and Map.SPANS[canvas.level]==Plan.WORLD_SIZE_M,"Full regional extent available")
	for i in 8:
		canvas.zoom(-1)
	check(canvas.level==0,"Zoom cannot leave supported range")
	map._select("market_town")
	check(map.route_button.disabled,"Unbuilt town cannot be selected as a live route")
	map._select("willow_station")
	check(not map.route_button.disabled,"Actual waystation is navigable")
	check(map.view.player==Vector2(241,119),"Panning or selecting cannot move player")
	map.free()
	print("REGIONAL_MAP_PASS" if failed==0 else "REGIONAL_MAP_FAIL")
	quit(0 if failed==0 else 1)
