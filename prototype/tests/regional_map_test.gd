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
	root.size=Vector2i(1280,720)
	map.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
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
	var captions := ["20 m","100 m","500 m","2 km","8 km"]
	for level in Map.SPANS.size():
		canvas.level = level
		check(canvas.scale_caption()==captions[level],"Exact valid scale caption at zoom level "+str(level))
	canvas.level=0
	map._select("market_town")
	check(map.route_button.disabled,"Unbuilt town cannot be selected as a live route")
	map._select("willow_station")
	check(not map.route_button.disabled,"Actual waystation is navigable")
	check(map.view.player==Vector2(241,119),"Panning or selecting cannot move player")
	var args := OS.get_cmdline_user_args()
	if DisplayServer.get_name()!="headless" and not args.is_empty():
		var out := args[0]
		DirAccess.make_dir_recursive_absolute(out)
		for step in [[0,"local"],[1,"village"],[2,"routes"],[3,"district"],[4,"region"]]:
			canvas.level = int(step[0])
			canvas.center = Vector2(241,119) if canvas.level<4 else Vector2.ZERO
			canvas.queue_redraw()
			await RenderingServer.frame_post_draw
			await RenderingServer.frame_post_draw
			var image := root.get_texture().get_image()
			check(image!=null and not image.is_empty() and image.save_png(out.path_join("map-"+str(step[1])+".png"))==OK,"Actual rendered map: "+str(step[1]))
	map.free()
	print("REGIONAL_MAP_PASS" if failed==0 else "REGIONAL_MAP_FAIL")
	quit(0 if failed==0 else 1)
