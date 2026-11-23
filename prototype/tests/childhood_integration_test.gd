extends SceneTree
## Compatibility UI/world flow for an actual schema-5 Base childhood save.
## Fresh New Life is covered by childhood_experience/night_integration_test.
## Explicit fixture travel is not a measured playthrough.
const Entry=preload("res://main.tscn")
const Childhood=preload("res://scripts/story/village_childhood.gd")
const CurrentChildhood=preload("res://scripts/story/childhood_story.gd")
const OpeningStory=preload("res://scripts/story/opening_story.gd")
const Life=preload("res://scripts/story/village_life.gd")
const BASE_SAVE="res://tests/fixtures/base_childhood_start_e573550.json"
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
	game.ui._touch_enabled=true
	game.ui._finish_intro()
	# Preserve the bytes produced by the previous published WorldModel. Continue
	# must migrate and retain them; New Life never selects this earlier story.
	var fixture := FileAccess.get_file_as_string(BASE_SAVE)
	check(not fixture.is_empty(),"An actual published Base childhood save fixture exists")
	if fixture.is_empty():
		game.queue_free()
		quit(1)
		return
	var save := FileAccess.open(game.SAVE_PATH,FileAccess.WRITE)
	check(save!=null,"The isolated legacy save destination is writable")
	if save==null:
		game.queue_free()
		quit(1)
		return
	save.store_string(fixture)
	save.close()
	game._show_menu()
	game.ui.action_requested.emit("continue",{})
	await frames()
	check(game.screen=="playing" and Childhood.enabled(game.model.data) and not CurrentChildhood.enabled(game.model.data),"Actual Continue preserves the earlier family's own saved story")
	game._begin_opening(OpeningStory.childhood())
	await frames()
	check(game.screen=="opening" and game.opening_sequence.id=="childhood_home","The explicitly loaded legacy campaign retains its own family introduction")
	check(Childhood.enabled(game.model.data),"The earlier saved childhood remains active without rewriting its format")
	game._opening_skip()
	game._opening_next()
	await frames(12)
	check(game.screen=="playing","Family opening hands over control")
	check(game.model.data.player.age==12 and game.model.data.buildings.is_empty(),"Child has existing family home without a mandatory built hut")
	check(game.world.get_player_position().y>.9,"Boy is above the raised family floor")
	check(game.ui._objective(game._ui_state())[0]=="Ein Morgen zu Hause","HUD points to mother, not rebuilding")
	game.ui.update_navigation(game.world.navigation_view())
	check(game.world.navigation_view().has_target,"First map goal is ready without completing an errand")
	await capture("01-family-home")
	var life_state:=JSON.stringify(game.model.data)
	game._pause()
	game._process(20.0)
	check(JSON.stringify(game.model.data)==life_state,"Pause does not consume childhood or work time")
	game._resume()
	await frames()
	var mother:=Life.actor_position(game.model.data,"antonia")
	game.world.get_node("Player").position=Vector3(mother.x+.8,1,mother.y+1.1)
	game.model.set_player_position(game.world.get_player_position())
	game.world.sync_state(game.model.data)
	game.ui.action_requested.emit("interact",{})
	await frames()
	check(game.screen=="village_dialog" and game.village_npc=="antonia","Actual interaction reaches named mother")
	var choice:=find_button(game.ui,"Mit Mutter den Morgen besprechen")
	check(choice!=null,"Connected first errand has a real dialogue control")
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
	var saved_id:String=game.model.data.world_id
	check(game._save(false).ok,"Childhood state saves through production Main")
	game._show_menu()
	game._continue_game()
	await frames()
	check(game.model.data.world_id==saved_id and game.model.data.village.childhood.completed==["mother_morning"],"Continue retains the completed errand without another reward")
	check(game.model.data.player.age==12,"Continue does not age the boy")
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
		var jab:=find_button(game.ui,"Gerade L")
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
		game._process(.8)
	root.size=Vector2i(1280,720)
	await frames(12)
	game.ui.show_game(game._ui_state())
	game.ui.action_requested.emit("run_toggle",{})
	check(game.world.is_running(),"Dedicated run control switches pace")
	game.ui.action_requested.emit("run_toggle",{})
	check(not game.world.is_running(),"Walk remains explicitly selectable")
	game.ui.action_requested.emit("combat_palette",{})
	await frames()
	check(game.screen=="combat_palette","Technique selection pauses the world")
	await capture("04-techniques")
	root.go_back_requested.emit()
	check(game.screen=="playing","Android Back leaves the technique selection")
	check(not game.model.execute("train",{}).ok,"The saved childhood still rejects the six-year shortcut")
	check(not game.model.execute("village_request_work",{}).ok,"A child cannot redistribute all villagers")
	if not capture_dir.is_empty():
		var file:=FileAccess.open(capture_dir.path_join("integration-report.json"),FileAccess.WRITE)
		file.store_string(JSON.stringify({"checks":checks,"failures":failures,"captures":captures,"quality":game.world.get_quality_profile(),"scenario":"schema-5 Base childhood compatibility; not the current New Life entry","travel":"explicit test fixture positioning; not a timed player walkthrough"}, "\t"))
		file.close()
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
