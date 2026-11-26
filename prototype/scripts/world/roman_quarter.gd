extends Node3D
## Authored workshop street beside the forum. The small stone reliefs and
## pebbles never enter the collision or the city economy.

const ORIGIN := Vector3(28.0, 0.125, 0.0)
const PAVING := "res://assets/roman_quarter/paving/paving.glb"
const WORKSHOP := "res://assets/roman_quarter/workshop/roman_workshop.glb"
const WORKSHOP_COLLISION := "res://assets/roman_quarter/workshop/roman_workshop_collision.glb"
const DOMUS := "res://assets/roman_quarter/workshop/roman_narrow_domus.glb"
const DOMUS_COLLISION := "res://assets/roman_quarter/workshop/roman_narrow_domus_collision.glb"
const FOUNTAIN := "res://assets/roman_quarter/fountain/fontana.glb"
const TABLET := "res://assets/roman_quarter/tablet/wax_tablet.glb"
const WORKSHOP_POSITION := Vector3(4.5, 0.159, 0.0)
const DOMUS_POSITION := Vector3(-4.5, 0.159, 2.9)
const FOUNTAIN_POSITION := Vector3(-5.34, 0.159, -4.3)
const TABLET_POSITION := WORKSHOP_POSITION + Vector3(4.70, 1.047, 3.28)
const TABLET_APPROACH := WORKSHOP_POSITION + Vector3(3.8, 0.9, 3.27)

var _tablet: Node3D


func install(profile: String, add_imported_colliders: Callable) -> void:
	var paving := _model(PAVING, "Paving", Vector3.ZERO)
	if paving == null:
		return
	var pebbles := paving.find_child("Kiesel_am_Rinnstein", true, false) as GeometryInstance3D
	if pebbles != null:
		pebbles.visible = profile != "low"
		pebbles.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		match profile:
			"balanced": pebbles.visibility_range_end = 19.0
			"high": pebbles.visibility_range_end = 29.0

	_road_surface()
	for side: float in [-1.0, 1.0]:
		_floor_box(Vector3(side * 3.91, 0.159, 0.0), Vector3(1.18, 0.15, 26.0))
	_floor_box(Vector3(-5.42, 0.159, -4.275), Vector3(1.86, 0.15, 3.75))
	for x: float in [-2.55, -1.85, -0.13, 1.62, 2.39]:
		_floor_box(Vector3(x, 0.159, 6.2), Vector3(0.52, 0.15, 0.69))

	if _place_building(WORKSHOP, WORKSHOP_COLLISION, "WorkshopAndTavern",
			WORKSHOP_POSITION, 0.0, add_imported_colliders):
		_tablet = _model(TABLET, "WaxTablet", TABLET_POSITION)
		if _tablet != null:
			_tablet.rotation_degrees.y = -13.0
	_place_building(DOMUS, DOMUS_COLLISION, "StreetDomus", DOMUS_POSITION, PI, add_imported_colliders)
	var fountain := _model(FOUNTAIN, "StreetFountain", FOUNTAIN_POSITION)
	if fountain != null:
		fountain.rotation_degrees.y = 90.0
		_floor_box(FOUNTAIN_POSITION + Vector3(0.0, 0.78, 0.0), Vector3(1.44, 0.78, 2.40))
		_floor_box(FOUNTAIN_POSITION + Vector3(-0.58, 1.67, 0.0), Vector3(0.28, 0.91, 0.88))


func tablet_reachable(player: CharacterBody3D) -> bool:
	if not is_instance_valid(_tablet) or player.position.distance_to(ORIGIN + TABLET_APPROACH) > 1.25:
		return false
	var eye := player.global_position + Vector3.UP * 0.43
	var query := PhysicsRayQueryParameters3D.create(eye, _tablet.global_position + Vector3.UP * 0.08, 1, [player.get_rid()])
	return get_world_3d().direct_space_state.intersect_ray(query).is_empty()


func _place_building(path: String, hulls: String, node_name: String, at: Vector3, yaw: float, add_imported_colliders: Callable) -> bool:
	var collision := _model(hulls, node_name + "HullSource", at)
	if collision == null:
		return false
	var model := _model(path, node_name, at)
	if model != null:
		model.rotation.y = yaw
		collision.rotation.y = yaw
		add_imported_colliders.call(collision, "QuarterCollision_" + node_name + "_")
	collision.queue_free()
	return model != null


func _model(path: String, node_name: String, at: Vector3) -> Node3D:
	if not ResourceLoader.exists(path, "PackedScene"):
		return null
	var packed := load(path) as PackedScene
	if packed == null:
		return null
	var model := packed.instantiate() as Node3D
	model.name = node_name
	model.position = at
	add_child(model)
	return model


func _road_surface() -> void:
	# The worn curb is represented by a short, walkable bevel. Paving chips
	# and wheel ruts preserve their visual depth without catching the capsule.
	var cross_section := [
		Vector2(-3.34, 0.159), Vector2(-3.06, 0.0), Vector2(-1.18, 0.047),
		Vector2(0.0, 0.076), Vector2(1.18, 0.047),
		Vector2(3.06, 0.0), Vector2(3.34, 0.159),
	]
	var triangles := PackedVector3Array()
	for index in range(cross_section.size() - 1):
		var left: Vector2 = cross_section[index]
		var right: Vector2 = cross_section[index + 1]
		var a := Vector3(left.x, left.y, -13.0)
		var b := Vector3(right.x, right.y, -13.0)
		var c := Vector3(right.x, right.y, 13.0)
		var d := Vector3(left.x, left.y, 13.0)
		triangles.append_array(PackedVector3Array([a, b, c, a, c, d]))
	var shape := ConcavePolygonShape3D.new()
	shape.set_faces(triangles)
	_collider(shape, Vector3.ZERO)


func _floor_box(top: Vector3, size: Vector3) -> void:
	var shape := BoxShape3D.new()
	shape.size = size
	_collider(shape, top - Vector3.UP * size.y * 0.5)


func _collider(shape: Shape3D, at: Vector3) -> void:
	var body := StaticBody3D.new()
	body.position = at
	body.collision_layer = 1
	body.collision_mask = 0
	var collider := CollisionShape3D.new()
	collider.shape = shape
	body.add_child(collider)
	add_child(body)
