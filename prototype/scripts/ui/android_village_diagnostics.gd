extends Node
## Read-only geometry/state observer for debug Android runtime verification.
## It does not accept commands, move people, change resources or write saves.

const LOG_CHUNK_SIZE := 512
const MAX_LOG_CHUNKS := 64

var session: Node
var _elapsed := 0.0
var _snapshot_sequence := 0


func _process(delta: float) -> void:
	_elapsed += delta
	if _elapsed < 1.0:
		return
	_elapsed = 0.0
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
	_collect(session.ui, value)
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
	if node is Button:
		var key := ""
		match node.text:
			"Interagieren": key = "interact"
			"Dorfleben": key = "village"
			"Arbeit & Versorgung": key = "work_tab"
			"Beim Wiederaufbau mithelfen": key = "permit"
			"Gespräch beenden": key = "dialog_close"
			"Zurück ins Dorf": key = "panel_close"
		if node is OptionButton:
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


func _geometry(control: Button) -> Dictionary:
	var center := control.get_global_rect().get_center()
	var native := control.get_viewport().get_screen_transform() * center
	var visible := control.get_viewport_rect().has_point(center)
	var ancestor := control.get_parent()
	while ancestor != null:
		if ancestor is Control and ancestor.clip_contents:
			visible = visible and ancestor.get_global_rect().has_point(center)
		ancestor = ancestor.get_parent()
	return {"center":[native.x,native.y], "visible":visible, "enabled":not control.disabled,
		"instance_id":str(control.get_instance_id())}


func _popup_state(popup: PopupMenu) -> Dictionary:
	var items: Array[Dictionary] = []
	for index in popup.item_count:
		items.append({"index":index, "text":popup.get_item_text(index),
			"enabled":not popup.is_item_disabled(index) and not popup.is_item_separator(index)})
	return {"visible":popup.is_visible(), "focused":popup.get_focused_item(),
		"instance_id":str(popup.get_instance_id()), "items":items}
