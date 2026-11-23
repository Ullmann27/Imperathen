extends Node
## Read-only geometry/state observer for debug Android runtime verification.
## It does not accept commands, move people, change resources or write saves.

const LOG_CHUNK_SIZE := 512
const MAX_LOG_CHUNKS := 64
const Childhood = preload("res://scripts/story/village_childhood.gd")

var session: Node
var _last_snapshot_msec := 0
var _snapshot_sequence := 0


func _process(_delta: float) -> void:
	# Observe wall time even when a software-rendered frame advances little game
	# time. This clock never advances the model, and missed samples are not replayed.
	var now := Time.get_ticks_msec()
	if now - _last_snapshot_msec < 1000:
		return
	_last_snapshot_msec = now
	var value := snapshot()
	if value.is_empty():
		return
	_snapshot_sequence += 1
	# Android log messages are bounded; encode once before splitting ASCII chunks.
	var encoded := Marshalls.utf8_to_base64(JSON.stringify(value))
	var count := ceili(float(encoded.length()) / float(LOG_CHUNK_SIZE))
	if count < 1 or count > MAX_LOG_CHUNKS:
		push_error("Village runtime snapshot exceeds the diagnostic transport limit.")
		return
	var frame := "%s-%d" % [str(get_instance_id()), _snapshot_sequence]
	for part in count:
		print("IMPERATHEN_VILLAGE_RUNTIME_CHUNK %s %d %d %s" % [
			frame, part, count, encoded.substr(part * LOG_CHUNK_SIZE, LOG_CHUNK_SIZE)])


func snapshot() -> Dictionary:
	if not is_instance_valid(session) or not is_instance_valid(session.ui):
		return {}
	var screen := str(session.screen)
	if screen not in ["playing", "village_panel", "village_dialog", "paused"]:
		return {}
	var data: Dictionary = session.model.data
	var village: Dictionary = data.get("village", {})
	if not village.get("enabled", false):
		return {}
	var economy: Dictionary = village.economy
	var world = session.world.village_life_world
	if not is_instance_valid(world):
		return {}
	var ui_state: Dictionary = session.ui.get("_state")
	var value := {"screen":screen, "world_seconds":data.world_seconds,
		"people":economy.people.size(), "actors":world.actors.size(),
		"workplaces":world.workplaces.size(), "work_permit":economy.authority.work_permit,
		"player_is_ruler":economy.authority.player_is_ruler,
		"decimus_met":village.social.npcs.decimus.met,
		"feedback":str(ui_state.get("village_feedback", "")) if screen == "village_panel" else "",
		"controls":{}}
	for person: Dictionary in economy.people:
		if person.id == "aelia":
			value["aelia_assignment"] = person.assignment
	value["action_mode"] = "unarmed" if village.has("unarmed") else "legacy"
	value["action_runtime"] = _action_state()
	value["graphics_runtime"] = {"ui_profile":session.ui.get_quality(),
		"world_profile":session.world.get_quality_profile()}
	if Childhood.enabled(data):
		value["childhood_runtime"] = _childhood_state(data)
	var collection_root: Node = session.ui
	if value.action_runtime.overlay == "techniques":
		collection_root = session.ui.get("_technique_menu_layer")
	elif value.action_runtime.overlay == "commands":
		collection_root = session.ui.get("_touch_menu_layer")
	_collect(collection_root, value)
	return value


func _collect(node: Node, value: Dictionary) -> void:
	if node is Control and not node.is_visible_in_tree():
		return
	if node is ScrollContainer and not value.has("scroll"):
		var rect: Rect2 = node.get_global_rect()
		var transform := node.get_viewport().get_screen_transform()
		var top := transform * (rect.position + Vector2(rect.size.x * 0.82, rect.size.y * 0.25))
		var bottom := transform * (rect.position + Vector2(rect.size.x * 0.82, rect.size.y * 0.80))
		value["scroll"] = {"top":[top.x,top.y], "bottom":[bottom.x,bottom.y],
			"offset":node.scroll_vertical}
	if node is Control and node.name == "MovementPad":
		value.controls["move_pad"] = _geometry(node)
		value.controls["move_pad"]["axis_points"] = _movement_points(node)
	if node is Button:
		var key := ""
		match node.text:
			"Interagieren": key = "interact"
			"Dorfleben", "Dorf": key = "village"
			"Pause": key = "pause"
			"Einstellungen": key = "settings"
			"Weiterspielen": key = "resume"
			"Arbeit & Versorgung": key = "work_tab"
			"Beim Wiederaufbau mithelfen": key = "permit"
			"Gespräch beenden": key = "dialog_close"
			"Zurück ins Dorf": key = "panel_close"
		if node.has_meta("touch_action"):
			key = str(node.get_meta("touch_action"))
		if node.get_meta("village_command", "") == "village_childhood_action":
			var args: Dictionary = node.get_meta("village_args", {})
			key = "childhood_" + str(args.get("action_id", ""))
		if str(node.name).begins_with("Technique_"):
			key = "technique_" + str(node.name).trim_prefix("Technique_")
		elif node.name == "OpenCommands":
			key = "commands"
		elif node.name == "CloseOverlay":
			key = "techniques_close" if _under_named(node, "TechniqueMenu") else "commands_close"
		if node is OptionButton:
			if node.name == "QualitySetting":
				key = "quality"
			for sibling: Node in node.get_parent().get_children():
				if sibling is Label and sibling.text.begins_with("Aelia ·"):
					key = "aelia_assignment"
		if not key.is_empty():
			value.controls[key] = _geometry(node)
			if node is OptionButton:
				value.controls[key]["selected"] = node.selected
				value.controls[key]["popup"] = _popup_state(node.get_popup())
	for child: Node in node.get_children():
		_collect(child, value)


func _geometry(control: Control) -> Dictionary:
	var center := control.get_global_rect().get_center()
	var native := control.get_viewport().get_screen_transform() * center
	var visible := control.get_viewport_rect().has_point(center)
	var ancestor := control.get_parent()
	while ancestor != null:
		if ancestor is Control and ancestor.clip_contents:
			visible = visible and ancestor.get_global_rect().has_point(center)
		ancestor = ancestor.get_parent()
	var native_rect: Rect2 = control.get_viewport().get_screen_transform() * control.get_global_rect()
	return {"center":[native.x,native.y], "visible":visible, "enabled":not control.disabled if control is BaseButton else true,
		"rect":[native_rect.position.x,native_rect.position.y,native_rect.size.x,native_rect.size.y],
		"instance_id":str(control.get_instance_id())}


func _popup_state(popup: PopupMenu) -> Dictionary:
	var items: Array[Dictionary] = []
	for index in popup.item_count:
		items.append({"index":index, "text":popup.get_item_text(index),
			"enabled":not popup.is_item_disabled(index) and not popup.is_item_separator(index)})
	return {"visible":popup.is_visible(), "focused":popup.get_focused_item(),
		"instance_id":str(popup.get_instance_id()), "items":items}


func _action_state() -> Dictionary:
	var ui = session.ui
	var game_world = session.world
	var pad: Control = ui.get("_touch_pad")
	var look: Control = ui.get("_touch_look")
	var actor := game_world.get_node_or_null("Player") as CharacterBody3D
	var position: Vector3 = game_world.get_player_position()
	var velocity := actor.get_real_velocity() if actor != null else Vector3.ZERO
	var body_velocity := actor.velocity if actor != null else Vector3.ZERO
	var axis: Vector2 = game_world.get("_touch_move")
	var action_touches := 0
	for button: Button in ui.get("_touch_actions"):
		if is_instance_valid(button) and int(button.get("touch_index")) >= 0:
			action_touches += 1
	var techniques: Control = ui.get("_technique_menu_layer")
	var commands: Control = ui.get("_touch_menu_layer")
	var overlay := "none"
	if is_instance_valid(techniques) and techniques.is_visible_in_tree():
		overlay = "techniques"
	elif is_instance_valid(commands) and commands.is_visible_in_tree():
		overlay = "commands"
	return {"version":1, "mode":str(session.mode), "ui_view":str(ui.get("_view_state")),
		"world_active":bool(game_world.get("_active")), "running":bool(game_world.get("_running")),
		"camera_yaw":float(game_world.get("_camera_yaw")),
		"selected_technique":str(ui.get("_selected_technique")), "overlay":overlay,
		"position":[position.x,position.y,position.z], "velocity":[velocity.x,velocity.y,velocity.z],
		"body_velocity":[body_velocity.x,body_velocity.y,body_velocity.z], "move_axis":[axis.x,axis.y],
		"movement_touch":int(pad.get("touch_index")) if is_instance_valid(pad) else -1,
		"camera_touches":look.get("contacts").size() if is_instance_valid(look) else 0,
		"action_touches":action_touches, "world_camera_touches":game_world.get("_camera_contacts").size(),
		"touch_camera_managed":bool(game_world.get("_touch_camera_managed"))}


func _childhood_state(data: Dictionary) -> Dictionary:
	var chapter := Childhood.view(data)
	var child: Dictionary = data.village.childhood
	var entrance: Vector2 = Childhood.POINTS.family_entrance
	var water: Vector2 = Childhood.POINTS.family_water
	return {"version":1, "world_id":str(data.world_id), "age":int(data.player.age),
		"day":int(child.day), "stage":str(chapter.get("stage", "")),
		"completed":child.completed.duplicate(), "carried":child.carried.duplicate(),
		"target_npc":str(chapter.get("target_npc", "")),
		"target_point":str(chapter.get("target_point", "")),
		"target_position":chapter.get("target_position", []).duplicate(),
		"target_radius":Childhood.NPC_RANGE if not str(chapter.get("target_npc", "")).is_empty() else Childhood.POINT_RANGE,
		"family_entrance":[entrance.x,entrance.y], "family_water":[water.x,water.y],
		"dialog_npc":str(session.village_npc) if str(session.screen) == "village_dialog" else ""}


func _movement_points(control: Control) -> Dictionary:
	var rect := control.get_global_rect()
	var center := rect.get_center()
	var distance := minf(rect.size.x,rect.size.y)*0.32
	var transform := control.get_viewport().get_screen_transform()
	var points := {}
	for direction: String in ["center","up","right","down","left"]:
		var offset: Vector2 = {"center":Vector2.ZERO,"up":Vector2.UP,"right":Vector2.RIGHT,"down":Vector2.DOWN,"left":Vector2.LEFT}[direction]
		var native := transform * (center+offset*distance)
		points[direction] = [native.x,native.y]
	return points


func _under_named(node: Node, ancestor_name: String) -> bool:
	var ancestor := node.get_parent()
	while ancestor != null:
		if ancestor.name == ancestor_name:
			return true
		ancestor = ancestor.get_parent()
	return false
