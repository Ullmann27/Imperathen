class_name BreakfastActing
extends RefCounted
## Close-range, silent gaze turns for the first family breakfast.

const I01 := preload("res://scripts/story/i01_three_cups.gd")
const DialoguePlayerScript := preload("res://scripts/audio/dialogue_player.gd")
const TURN_SECONDS: float = 3.0
const TABLE_RADIUS: float = 0.55
const MAX_DETAIL: int = 1

var _elapsed: float = 0.0
var _focus_id: String = ""


func advance(world: Node3D, life: Node3D, delta: float, data: Dictionary) -> void:
	if not _scene_ready(world, life, data):
		_stop(life)
		return
	var actors: Dictionary = life.get("actors")
	var julia := actors.get("julia") as Node3D
	var silvanus := actors.get("silvanus") as Node3D
	if not _actor_ready(world, julia, "julia", I01.POINTS.julia_table) or not _actor_ready(world, silvanus, "silvanus", I01.POINTS.silvanus_table):
		_stop(life)
		return
	_elapsed = fposmod(_elapsed + maxf(delta, 0.0), TURN_SECONDS * 2.0)
	var next_focus := "julia" if _elapsed < TURN_SECONDS else "silvanus"
	if next_focus != _focus_id:
		_set_focus(actors, next_focus)


func focus_id() -> String:
	return _focus_id


func owns_gaze(actor_id: String) -> bool:
	return not _focus_id.is_empty() and actor_id in ["julia", "silvanus"]


func _scene_ready(world: Node3D, life: Node3D, data: Dictionary) -> bool:
	if not is_instance_valid(world) or not is_instance_valid(life):
		return false
	if not bool(world.get("_active")) or str(world.get("_mode")) != "person":
		return false
	if not bool(life.get("active")) or not bool(life.get("visible")) or not str(life.get("focused")).is_empty():
		return false
	var session := world.get_parent()
	if not is_instance_valid(session) or str(session.get("screen")) != "playing" or str(session.get("mode")) != "person":
		return false
	if not str(session.get("village_npc")).is_empty() or not str(session.get("frontier_npc")).is_empty():
		return false
	var voice := session.get("opening_voice") as DialoguePlayerScript
	if is_instance_valid(voice) and voice.is_active():
		return false
	var director := session.get("opening_director") as Node
	var dialog_actor := world.get("_gaze_dialog_actor") as Node3D
	if is_instance_valid(director) or is_instance_valid(dialog_actor):
		return false
	var village: Dictionary = data.get("village", {})
	var childhood: Dictionary = village.get("childhood", {})
	var screenplay: Dictionary = childhood.get("screenplay", {})
	var completed: Array = childhood.get("completed", [])
	var path := str(screenplay.get("i01_path", ""))
	var presentation := I01.presentation(data)
	return str(screenplay.get("i01", "")) == "pending" and completed.is_empty() and path in ["help", "yard"] \
		and bool(presentation.get("julia_at_table", false)) and bool(presentation.get("silvanus_at_table", false))


func _actor_ready(world: Node3D, actor: Node3D, actor_id: String, seat: Vector2) -> bool:
	if not is_instance_valid(actor) or not actor.visible or bool(actor.get_meta("physical_social_pose", false)):
		return false
	var point := world.to_global(Vector3(seat.x, actor.global_position.y, seat.y))
	var actual := actor.global_position
	if Vector2(actual.x, actual.z).distance_to(Vector2(point.x, point.z)) > TABLE_RADIUS:
		return false
	var figure := _figure(actor)
	if not is_instance_valid(figure) or not figure.visible:
		return false
	if int(figure.get("detail")) < 0 or int(figure.get("detail")) > MAX_DETAIL:
		return false
	if float(figure.get("speed")) > 0.08 or bool(figure.get("_posed")) or bool(figure.get("_service_external")):
		return false
	if not str(figure.get("_combat_id")).is_empty() or str(figure.get("clip")) != "idle":
		return false
	return not bool(figure.get("_conversation_focused"))


func _set_focus(actors: Dictionary, next_id: String) -> void:
	if not _focus_id.is_empty():
		var previous := _figure(actors.get(_focus_id) as Node3D)
		var previous_partner := _figure(actors.get("silvanus" if _focus_id == "julia" else "julia") as Node3D)
		if is_instance_valid(previous):
			previous.clear_gaze_target()
		if is_instance_valid(previous_partner):
			previous_partner.clear_gaze_target()
	var focused := _figure(actors.get(next_id) as Node3D)
	var listener_id := "silvanus" if next_id == "julia" else "julia"
	var listener := _figure(actors.get(listener_id) as Node3D)
	if not is_instance_valid(focused) or not is_instance_valid(listener):
		_focus_id = ""
		return
	_focus_id = next_id
	focused.set_gaze_target(listener)
	listener.set_gaze_speaker(focused)


func _stop(life: Node3D) -> void:
	if _focus_id.is_empty():
		_elapsed = 0.0
		return
	var actors_value: Variant = life.get("actors") if is_instance_valid(life) else {}
	var actors: Dictionary = actors_value if actors_value is Dictionary else {}
	var focused_id := str(life.get("focused")) if is_instance_valid(life) else ""
	for actor_id: String in ["julia", "silvanus"]:
		var actor := actors.get(actor_id) as Node3D
		var figure := _figure(actor)
		if not is_instance_valid(figure) or bool(actor.get_meta("physical_social_pose", false)):
			continue
		if actor_id != focused_id:
			figure.clear_gaze_target()
	_focus_id = ""
	_elapsed = 0.0


func _figure(actor: Node3D) -> Node3D:
	return actor.get_node_or_null("Figure") as Node3D if is_instance_valid(actor) else null
