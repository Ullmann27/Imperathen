extends SceneTree
## Production UI/world flow. Explicit fixture travel is not a measured playthrough.
const Entry=preload("res://main.tscn")
const Childhood=preload("res://scripts/story/village_childhood.gd")
const Life=preload("res://scripts/story/village_life.gd")
const Diagnostics=preload("res://scripts/ui/android_village_diagnostics.gd")
var game
var checks:=0
var failures: Array[String]=[]
var captures: Array=[]
var capture_dir:=""
var capture_quality:=""

func _initialize() -> void:
	if OS.get_environment("IMPERATHEN_ISOLATED_TEST")!="1":
		printerr("Childhood integration requires isolated settings and saves.")
		quit(2)
		return
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--capture-dir="):
			capture_dir=arg.trim_prefix("--capture-dir=")
		elif arg.begins_with("--quality="):
			capture_quality=arg.trim_prefix("--quality=")
	if not capture_quality.is_empty() and capture_quality not in ["low","balanced","high","very_high"]:
		printerr("Unknown capture quality profile")
		quit(2)
		return
	_run.call_deferred()

func check(value: bool,message: String) -> void:
	checks+=1
	if not value:
		failures.append(message)
		printerr("CHILDHOOD_INTEGRATION_FAIL: "+message)

func frames(count:=5) -> void:
	for i in count:
		await process_frame

func _run() -> void:
	root.content_scale_size=Vector2i.ZERO
	root.size=Vector2i(1280,720)
	game=Entry.instantiate()
	root.add_child(game)
	if not capture_quality.is_empty():
		game.ui.set_quality(capture_quality)
	await frames()
	game.set_process(false)
	game.set_physics_process(false)
	game.ui._touch_enabled=true
	game.ui._finish_intro()
	game.ui.action_requested.emit("new_game",{})
	await frames()
	check(game.screen=="opening" and game.opening_sequence.id=="childhood_home","New Life uses the family opening")
	check(Childhood.enabled(game.model.data),"Fresh Roman campaign contains the new chapter")
	game._opening_skip()
	game._opening_next()
	await frames(12)
	check(game.screen=="playing","Family opening hands over control")
	check(game.model.data.player.age==12 and game.model.data.buildings.is_empty(),"Child has existing family home without a mandatory built hut")
	check(game.world.get_player_position().y>.9,"Boy is above the raised family floor")
	check(game.ui._objective(game._ui_state())[0]=="Ein Morgen zu Hause","HUD points to mother, not rebuilding")
	game.ui.update_navigation(game.world.navigation_view())
	check(game.world.navigation_view().has_target,"First map goal is ready without completing an errand")
	var observer=Diagnostics.new()
	observer.session=game
	root.add_child(observer)
	observer.set_process(false)
	var observed_before:=var_to_bytes(game.model.data)
	var observed:Dictionary=observer.snapshot()
	check(observed.has("childhood_runtime") and observed.childhood_runtime.stage=="mother_morning","Android observer exposes the actual family start")
	check(var_to_bytes(game.model.data)==observed_before,"Android family observer cannot mutate authoritative state")
	check(observed.action_runtime.touch_camera_managed,"Family controls retain managed camera ownership")
	await capture("01-family-home")
	game._pause()
	var life_state:=JSON.stringify(game.model.data)
	game._physics_process(20.0)
	game._process(20.0)
	check(JSON.stringify(game.model.data)==life_state,"Pause does not consume childhood or work time")
	game._resume()
	await frames()
	var mother:=Life.actor_position(game.model.data,"julia")
	game.world.get_node("Player").position=Vector3(mother.x+.8,1,mother.y+1.1)
	game.model.set_player_position(game.world.get_player_position())
	game.world.sync_state(game.model.data)
	game.ui.action_requested.emit("interact",{})
	await frames()
	check(game.screen=="village_dialog" and game.village_npc=="julia","Actual interaction reaches named mother")
	var choice:=find_button(game.ui,"Mit Mutter den Morgen besprechen")
	check(choice!=null,"Connected first errand has a real dialogue control")
	check(observer.snapshot().get("controls",{}).has("childhood_mother_morning"),"Actual mother choice retains command metadata for read-only Android geometry")
	if choice!=null:
		touch(choice.get_global_rect().get_center(),7,true)
		touch(choice.get_global_rect().get_center(),7,false)
	await frames()
	check(game.model.data.village.childhood.completed==["mother_morning"],"Native touch advances exactly the agreed family action")
	check(game.model.data.village.childhood.carried.has("household_coin"),"Family errand has a carried coin")
	await capture("02-mother-conversation")
	game._resume()
	await frames()
	game.ui.update_navigation(game.world.navigation_view())
	check(game.world.navigation_view().has_target,"Minimap has an authoritative next destination")
	var target:Vector2=game.world.navigation_view().target
	check(target.distance_to(Childhood.POINTS.family_water)<.01,"Map goal follows next quest station")
	await capture("03-village-controls")
	# Explicit fixture placement checks the production item action; ADB uses
	# the actual joystick route instead and never writes the player position.
	var water:Vector2=Childhood.POINTS.family_water
	game.world.get_node("Player").position=Vector3(water.x,1.35,water.y)
	game.model.set_player_position(game.world.get_player_position())
	game.world.sync_state(game.model.data)
	await frames()
	var interact:=find_action(game.ui,"interact")
	check(interact!=null,"Family item action has the actual touch control")
	if interact!=null:
		touch(interact.get_global_rect().get_center(),8,true)
		touch(interact.get_global_rect().get_center(),8,false)
	await frames()
	check(game.model.data.village.childhood.completed==["mother_morning","fill_water"],"Native interaction completes the real water station after the mother action")
	check(game.model.data.village.childhood.carried.has("water_jug"),"The filled family jug is an actual carried item")
	var checkpoint:Dictionary=observer.snapshot().get("childhood_runtime",{})
	check(checkpoint.get("stage")=="father_morning" and checkpoint.get("carried",[]).has("water_jug"),"Android observer reports the new target and stable carried item ID")
	var saved_id:String=game.model.data.world_id
	check(game._save(false).ok,"Childhood state saves through production Main")
	game._show_menu()
	game._continue_game()
	await frames()
	check(game.model.data.world_id==saved_id and game.model.data.village.childhood.completed==["mother_morning","fill_water"],"Continue retains both completed family actions without another reward")
	check(game.model.data.player.age==12,"Continue does not age the boy")
	check(game.model.data.village.childhood.carried.has("household_coin") and game.model.data.village.childhood.carried.has("water_jug"),"Continue retains the actual household coin and filled jug")
	for resolution in [Vector2i(960,540),Vector2i(1280,720),Vector2i(1384,1536)]:
		root.size=resolution
		await frames(12)
		game.ui.show_game(game._ui_state())
		await frames(8)
		var pad:Control=game.ui._touch_pad
		var rect:Rect2=pad.get_global_rect()
		check(rect.size.x>=179 and rect.size.y>=179,"Larger touch pad at "+str(resolution))
		check(rect.end.y<=game.ui._content_size().y-70,"Touch pad raised above bottom edge at "+str(resolution))
		var navigation=game.ui._screen.find_child("VillageCompass",true,false)
		check(navigation!=null and navigation.is_visible_in_tree(),"Compass visible at "+str(resolution))
		if navigation!=null:
			var objective:Control=game.ui._screen.find_child("ObjectiveCard",true,false)
			check(not navigation.get_global_rect().intersects(objective.get_global_rect()),"Family objective and north map remain separate")
			check(not navigation.get_global_rect().intersects(rect),"North map does not cover movement")
		var combat_controls:Control=game.ui._screen.find_child("TouchActions",true,false)
		check(combat_controls!=null and not rect.intersects(combat_controls.get_global_rect()),"Combat and movement hit areas do not overlap")
		var all: Array[Node]=combat_controls.find_children("*","Button",true,false)
		for button:Button in all:
			check(button.get_global_rect().size.y>=48,"Usable combat button height")
		var at:=rect.get_center()+Vector2(0,-rect.size.y*.28)
		touch(at,3,true)
		await frames(2)
		var axis:Vector2=game.world.get("_touch_move")
		check(axis.length()>.25,"Native larger pad generates analog movement")
		var jab:=find_action(game.ui,"attack")
		check(jab!=null,"Selected technique uses the actual merged attack control")
		if jab!=null:
			touch(jab.get_global_rect().get_center(),4,true)
			touch(jab.get_global_rect().get_center(),4,false)
		await frames(2)
		check(game.world.get("_touch_move").length()>.25,"Attack pointer does not cancel movement pointer")
		touch(at,3,false)
		await frames(2)
		if game.world.get("_touch_move")!=Vector2.ZERO:
			print("PAD_RELEASE_DIAGNOSTIC ",{"index":game.ui._touch_pad.touch_index,"mouse":game.ui._touch_pad._mouse_captured,"axis":game.ui._touch_pad.axis,"world":game.world.get("_touch_move"),"screen":game.screen,"same_pad":pad==game.ui._touch_pad})
		check(game.world.get("_touch_move")==Vector2.ZERO,"Movement release cannot stick")
		game._physics_process(.8)
		game._process(.8)
	root.size=Vector2i(1280,720)
	await frames(12)
	game.ui.show_game(game._ui_state())
	await frames()
	var pace:=find_action(game.ui,"pace")
	var pace_events:Array=[]
	game.ui.action_requested.connect(func(action:String,payload:Dictionary):
		if action=="movement_pace":pace_events.append(payload.duplicate(true))
	)
	check(pace!=null,"Merged walking/running control exists")
	if pace!=null:
		touch(pace.get_global_rect().get_center(),9,true)
		touch(pace.get_global_rect().get_center(),9,false)
	await frames()
	check(game.world.is_running(),"Native tempo control selects running")
	pace=find_action(game.ui,"pace")
	if pace!=null:
		touch(pace.get_global_rect().get_center(),9,true)
		touch(pace.get_global_rect().get_center(),9,false)
	await frames()
	check(not game.world.is_running(),"Walk remains explicitly selectable")
	check(pace_events==[{"running":true},{"running":false}],"Two native tempo taps send exactly one command each")
	check(not game.ui._running and find_action(game.ui,"pace").text=="Gehen","Walking caption and UI state agree with the actual world")
	await tap_action("pace",11)
	check(game.world.is_running() and game.ui._state.get("running",false),"A native run tap updates the cached layout state immediately")
	root.size=Vector2i(480,840)
	await frames(12)
	check(game.world.is_running() and game.ui._running and find_action(game.ui,"pace").text=="Laufen","Portrait resize preserves the selected running mode and caption")
	game.ui.show_game(game._ui_state())
	await frames()
	check(game.world.is_running() and game.ui._running,"Explicit show_game reads the current world pace without changing it")
	root.size=Vector2i(1280,720)
	await frames(12)
	check(game._save(false).ok,"Running session saves through the actual Main path")
	game._show_menu()
	game._continue_game()
	await frames(12)
	check(not game.world.is_running() and not game.ui._running and find_action(game.ui,"pace").text=="Gehen","Continue reflects the world's fresh walking mode instead of reapplying stale UI running")
	game.world.set_running(true)
	game._refresh()
	check(game.ui._running and find_action(game.ui,"pace").text=="Laufen","Live state refresh reflects running selected by the world")
	game.world.set_running(false)
	game._refresh()
	check(not game.ui._running and find_action(game.ui,"pace").text=="Gehen","Live state refresh reflects walking selected by the world")
	var techniques:=find_action(game.ui,"techniques")
	check(techniques!=null,"Merged technique picker exists")
	if techniques!=null:
		touch(techniques.get_global_rect().get_center(),10,true)
		touch(techniques.get_global_rect().get_center(),10,false)
	await frames()
	check(game.screen=="playing" and game.ui._technique_menu_layer.visible,"Technique selection uses the existing modal inside gameplay")
	check(not game.ui._touch_pad.is_visible_in_tree() and game.world.get("_touch_move")==Vector2.ZERO,"Technique modal cancels and hides gameplay contacts")
	var palette:Dictionary=observer.snapshot()
	check(palette.get("controls",{}).has("technique_jab_right") and not palette.get("controls",{}).has("move_pad"),"Android geometry includes selectable techniques and excludes blocked controls")
	await capture("04-techniques")
	root.go_back_requested.emit()
	check(game.screen=="playing" and not game.ui._technique_menu_layer.visible,"Android Back closes the technique modal first")
	check(not game.model.execute("train",{}).ok,"New chapter rejects old six-year shortcut")
	check(not game.model.execute("village_request_work",{}).ok,"A child cannot redistribute all villagers")
	if not capture_dir.is_empty():
		var file:=FileAccess.open(capture_dir.path_join("integration-report.json"),FileAccess.WRITE)
		file.store_string(JSON.stringify({"checks":checks,"failures":failures,"captures":captures,"quality":game.world.get_quality_profile(),"travel":"explicit test fixture positioning; not a timed player walkthrough"}, "\t"))
		file.close()
	observer.queue_free()
	game.queue_free()
	await frames()
	print(("CHILDHOOD_INTEGRATION_PASS" if failures.is_empty() else "CHILDHOOD_INTEGRATION_FAILED")+" checks=%d failures=%d"%[checks,failures.size()])
	quit(0 if failures.is_empty() else 1)

func touch(at:Vector2,index:int,pressed:bool) -> void:
	var event:=InputEventScreenTouch.new()
	event.index=index
	event.position=at
	event.pressed=pressed
	Input.parse_input_event(event)

func tap_action(action:String,index:int) -> void:
	var button:=find_action(game.ui,action)
	check(button!=null,"Visible native action exists: "+action)
	if button==null:return
	var at:=button.get_global_rect().get_center()
	touch(at,index,true)
	await process_frame
	touch(at,index,false)
	await frames()

func find_action(node:Node,action:String) -> Button:
	if node.is_queued_for_deletion() or (node is Control and not node.is_visible_in_tree()):
		return null
	if node is Button and str(node.get_meta("touch_action",""))==action:
		return node
	for child:Node in node.get_children():
		var found:=find_action(child,action)
		if found!=null:return found
	return null

func find_button(node:Node,caption:String) -> Button:
	if node is Button and node.text.strip_edges().begins_with(caption):
		return node
	for child:Node in node.get_children():
		var found:=find_button(child,caption)
		if found!=null:return found
	return null

func capture(id:String) -> void:
	if capture_dir.is_empty():return
	await RenderingServer.frame_post_draw
	var screenshot:=root.get_texture().get_image()
	check(screenshot!=null and not screenshot.is_empty(),"Real rendered image for "+id)
	if screenshot==null or screenshot.is_empty():return
	DirAccess.make_dir_recursive_absolute(capture_dir)
	var path:=capture_dir.path_join(id+".png")
	check(screenshot.save_png(path)==OK,"Saved "+id)
	captures.append({"id":id,"width":screenshot.get_width(),"height":screenshot.get_height(),"file":id+".png"})
