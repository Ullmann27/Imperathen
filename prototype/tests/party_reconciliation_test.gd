extends "res://tests/party_ui_test.gd"
## The recorded I-08 career chose the I-03 disagreement. The older regional
## case declines in its own actual dialogue. Both return through Main's normal UI.
const FIXTURE := "res://tests/fixtures/mission_bridge_data/handoff_i08_report_v5.json"


func _run() -> void:
	root.content_scale_size = Vector2i.ZERO
	root.size = Vector2i(960,640)
	game = Main.new()
	root.add_child(game)
	await process_frame
	game.session_started = true
	game.world.show()
	var path := "user://before_reconciliation_%d.json" % Time.get_ticks_usec()
	var copied := DirAccess.copy_absolute(ProjectSettings.globalize_path(FIXTURE),ProjectSettings.globalize_path(path))
	if _check(copied == OK and game.model.load_game(path).ok, "Load the recorded I-03 rival's career"):
		_repair()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	game.model.new_game("wa")
	game.model.set_player_position(Vector3(-3,1,4))
	_check(game.model.execute("choose_companion",{"choice":"decline"}).ok, "Aki's original regional refusal")
	_check(Party.mending_choice(game.model.data).is_empty(), "The first refusal is not immediately reversed")
	var tree_node: Dictionary = game.model.data.resource_nodes[0]
	game.model.set_player_position(Vector3(tree_node.x,1,tree_node.z))
	_check(game.model.execute("gather", {"node_id":tree_node.id}).ok, "The regional player obtains real timber for the repair")
	_repair()
	print("PARTY_RECONCILIATION_RESULT checks=%d failures=%d" % [checks, failures.size()])
	game.queue_free()
	await process_frame
	quit(0 if failures.is_empty() else 1)


func _repair() -> void:
	var original: Dictionary = game.model.data.companion.duplicate(true)
	var screenplay: Dictionary = game.model.data.village.get("childhood",{}).get("screenplay",{}).duplicate(true)
	game.world.setup(game.model.data)
	game._resume()
	var actor: CharacterBody3D = game.world._companion
	game.world._player.position = actor.position + Vector3(1,0.9,0)
	game.model.set_player_position(game.world._player.position)
	_check(not game.model.execute("party_invite",{"actor_uid":Party.FRIEND}).ok, "The old disagreement still prevents an immediate invitation")
	game._show_companion()
	if not _click("Hilfe beim Tragegestell zusagen"):
		return
	_check(game.model.data.world_state.party.get("mending") == "promised", "The personal promise survives the dialogue")
	_check(game.model.load_game(Main.SAVE_PATH).ok and Party.mending_choice(game.model.data) == "deliver", "Load the promise actually saved by Main")
	var stock: int = game.model.data.resources.wood
	game.model.set_player_position(actor.position + Vector3(18,1,0))
	var delivery := {"actor_uid":Party.FRIEND,"step":"deliver"}
	_check(not game.model.execute("party_mend",delivery).ok and game.model.data.resources.wood == stock, "No delivery or debit from a distance")
	game.world._player.position = actor.position + Vector3(1,0.9,0)
	game.model.set_player_position(game.world._player.position)
	game._show_companion()
	if not _click("Tragegestell gemeinsam reparieren · 2 Holz"):
		return
	_check(game.model.data.resources.wood == stock - Party.FRAME_WOOD and not game.model.data.world_state.party.members.has(Party.FRIEND), "Two genuine wood are spent and joining remains voluntary")
	_check(not game.model.execute("party_mend",delivery).ok and game.model.data.resources.wood == stock - Party.FRAME_WOOD, "Repair and payment occur once")
	game._show_companion()
	if not _click("Um persönliche Begleitung bitten"):
		return
	var member: Dictionary = game.model.data.world_state.party.members.get(Party.FRIEND,{})
	_check(member.get("status") == "active" and member.get("bond",0) == 12 and member.get("memories",[]).any(func(note: String) -> bool: return note.contains("Tragegestell")), "The specific promise is remembered by the same person")
	_check(game.model.data.companion == original and game.model.data.village.get("childhood",{}).get("screenplay",{}) == screenplay, "The old response, age, trust and screenplay outcomes are preserved")
	_check(game.model.load_game(Main.SAVE_PATH).ok and game.model.data.world_state.party.members.get(Party.FRIEND,{}) == member, "The accepted friendship and its creative memory survive a second file load")
