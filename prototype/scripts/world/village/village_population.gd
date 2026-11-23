extends Node3D
## Stable residents and authored routines. No production, recruitment or narrative rewards.

const Layout = preload("res://scripts/world/village/village_layout.gd")
const Person = preload("res://scripts/visuals/village_person.gd")
const Art = preload("res://scripts/world/village_art.gd")
var actors: Dictionary = {}
var origin_id := ""
var active := false
var seconds := 0.0
var profile := "balanced"
var focused_id := ""
var recruited := 0
var excluded_ids: Array[String] = []
var _player_position := Vector3.ZERO

func show_origin(id: String, time: float, recruited_count: int) -> void:
	if origin_id != id:
		origin_id = id
		for actor: Node3D in actors.values():
			remove_child(actor)
			actor.free()
		actors.clear()
		if id == "italia":
			for index in Layout.RESIDENTS.size():
				_add_resident(Layout.RESIDENTS[index],index)
	set_recruited(recruited_count)
	advance_to(time,true)

func _add_resident(item: Dictionary, index: int) -> void:
	var actor := Node3D.new()
	actor.name = item.id
	actor.set_meta("resident_id",item.id)
	actor.set_meta("occupation",item.occupation)
	add_child(actor)
	var figure := Person.new()
	figure.name = "Figure"
	figure.position.y = .9
	actor.add_child(figure)
	figure.configure("resident","italia",int(item.age))
	if figure.has_method("configure_appearance"):
		figure.configure_appearance(item.appearance,index)
	figure.profile = profile
	var nameplate := Art.label(actor,item.name+" · "+item.occupation,Vector3(0,2.05,0),Color("#efdbad"),29)
	nameplate.name = "Nameplate"
	nameplate.visibility_range_end = 7.0
	nameplate.hide()
	actors[item.id] = actor

func set_recruited(count: int) -> void:
	recruited = clampi(count,0,Layout.VOLUNTEERS.size())
	for id: String in actors:
		var index := Layout.VOLUNTEERS.find(id)
		actors[id].visible = (index < 0 or index >= recruited) and not excluded_ids.has(id)


func set_excluded_ids(ids: Array) -> void:
	# An identity rendered by the authoritative economy/childhood view is never
	# simultaneously rendered by this older ambient layer. Clearing restores it.
	excluded_ids.clear()
	for id: Variant in ids:
		if id is String and not excluded_ids.has(id):
			excluded_ids.append(id)
	set_recruited(recruited)

func set_quality(next_profile: String) -> void:
	if next_profile not in ["low","balanced","high","very_high"]:
		return
	profile = next_profile
	for actor: Node3D in actors.values():
		actor.get_node("Figure").profile = profile
		actor.get_node("Figure").refresh_lod(get_viewport().get_camera_3d())

func set_active(enabled: bool) -> void:
	active = enabled
	if not active:
		for actor: Node3D in actors.values():
			actor.get_node("Figure").drive(0.0)

func advance_to(time: float, force := false) -> void:
	if not active and not force:
		return
	seconds = maxf(0.0,time)
	for index in Layout.RESIDENTS.size():
		var item: Dictionary = Layout.RESIDENTS[index]
		if not actors.has(item.id):
			continue
		var actor: Node3D = actors[item.id]
		if not actor.visible or focused_id == item.id:
			continue
		var pose: Dictionary = Layout.pose_at(item,seconds,index)
		actor.position = pose.position
		var facing: Vector3 = pose.direction
		if float(pose.speed) > .01:
			actor.rotation.y = atan2(-facing.x,-facing.z)
		var figure: Node3D = actor.get_node("Figure")
		figure.drive(pose.speed)
		if pose.activity == "work":
			figure.keep_working()
		actor.set_meta("activity",pose.activity)

func update_nearby(player_position: Vector3, show_labels: bool) -> void:
	_player_position = player_position
	var closest := nearest_npc(player_position,5.0)
	for id: String in actors:
		var actor: Node3D = actors[id]
		actor.get_node("Nameplate").visible = show_labels and actor.visible and id == closest and focused_id.is_empty()

func nearest_npc(position: Vector3, radius: float) -> String:
	var best := ""
	var distance := radius+1.0
	for id: String in actors:
		var actor: Node3D = actors[id]
		if not actor.visible:
			continue
		var value := Vector2(position.x,position.z).distance_to(Vector2(actor.global_position.x,actor.global_position.z))
		if value > radius:
			continue
		# A passer-by should not steal a nearly equal-range conversation with the
		# stationary person at a desk or shop. Close residents still take priority.
		var priority := value-(.35 if id in ["livia","cassian","aulus","titus"] else 0.0)
		if priority < distance:
			distance = priority
			best = id
	return best

func actor_position(id: String) -> Vector3:
	return (actors[id] as Node3D).global_position if actors.has(id) else Vector3.INF

func info(id: String) -> Dictionary:
	var definition := Layout.resident(id)
	if definition.is_empty() or not actors.has(id) or not actors[id].visible:
		return {}
	return {"id":id,"name":definition.name,"occupation":definition.occupation,"greeting":definition.greeting,"position":actor_position(id)}

func focus(id: String, viewer: Vector3) -> bool:
	if not actors.has(id) or not actors[id].visible:
		return false
	focused_id = id
	var actor: Node3D = actors[id]
	var offset := viewer-actor.global_position
	if Vector2(offset.x,offset.z).length() > .1:
		actor.rotation.y = atan2(-offset.x,-offset.z)
	actor.get_node("Figure").drive(0.0)
	actor.get_node("Figure").cue("talk")
	return true

func clear_focus() -> void:
	if not focused_id.is_empty() and actors.has(focused_id):
		actors[focused_id].get_node("Figure").reset_motion()
	focused_id = ""

func set_wagon_work(enabled: bool) -> void:
	if enabled and active and actors.has("titus"):
		actors.titus.get_node("Figure").keep_working()

func snapshot() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for id: String in actors:
		var actor: Node3D = actors[id]
		result.append({"id":id,"position":actor.position,"visible":actor.visible,"activity":actor.get_meta("activity","idle")})
	return result
