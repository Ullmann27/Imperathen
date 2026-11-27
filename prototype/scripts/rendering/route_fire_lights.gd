extends Node3D
## Visible roadside braziers with one batched holder mesh, one flame batch and
## a bounded reusable pool of nearby unshadowed lights. No gameplay collision,
## no new saved state, no dependence on volumetric or Forward+ rendering.
const Layout := preload("res://scripts/world/village/village_layout.gd")
const Land := preload("res://scripts/world/village/valdora_land.gd")
const FLAME := preload("res://scripts/rendering/fire_flame.gdshader")
const CITY_GRAPH := "res://assets/city/street_graph.json"
const MAX_LIGHTS := 4
const SPACING := 6.0
const RANGE := 11.5
const PATH_LOOKAHEAD := 15.0
var _route_player := Vector3.INF
var _route_samples := PackedVector2Array()
var sites: Array[Vector3] = []
var _candidates: Array[Vector3] = []
var _pool: Array[OmniLight3D] = []
var _flames: MultiMeshInstance3D
var _clock := 0.0
var _night := 0.0
var _elapsed := 0.0
var _budget := 2
var _installed := false

static func village_candidates() -> Array[Vector3]:
	var points: Array[Vector3] = []
	# Central lane, civic crossroad, east lane, south road and both ends of
	# the bridge. Offset from the actual tread; never put a bowl in the lane.
	for z: int in range(-45,30,6):
		var side := 1.0 if posmod(floori(float(z+45)/6.0),2)==0 else -1.0
		points.append(Vector3(Land.lane_x(z)+side*2.9,0,z))
		points.append(Vector3(Land.lane_x(z)-side*2.9,0,z+1.5))
	for z: int in range(-42,28,7):
		points.append(Vector3(26.9, 0, z))
	for x: int in range(-16,29,7):
		points.append(Vector3(x, 0, -33.8))
	for x: int in range(-16,45,7):
		points.append(Vector3(x, 0, 30.1))
	for at: Vector3 in [Vector3(-23,0,7.2), Vector3(-34,0,7.2), Vector3(46,0,-10.0), Vector3(4,0,-48)]:
		points.append(at)
	# Outer gate approach: fixed road edge sites on the level village plane.
	for x: int in range(54,87,7):
		points.append(Vector3(x,0,-10.0))
		points.append(Vector3(x,0,-16.0))
	var result: Array[Vector3] = []
	for p: Vector3 in points:
		var planar := Vector2(p.x, p.z)
		if not Layout.reserved(planar, 0.40) and not Layout.road(planar) and Land.water_distance(planar, -100.0) > 1.0:
			result.append(p)
	return result

static func city_candidates() -> Array[Vector3]:
	var result: Array[Vector3] = []
	if not FileAccess.file_exists(CITY_GRAPH):
		return result
	var graph: Variant = JSON.parse_string(FileAccess.get_file_as_string(CITY_GRAPH))
	if not graph is Dictionary or graph.get("schema") != 1:
		return result
	var nodes: Array = graph.get("nodes", [])
	var anchors: Dictionary = graph.get("anchor_nodes", {})
	var keys: Array = anchors.keys()
	keys.sort()
	for key: String in keys:
		# A light beside a stall, arcade or neighborhood meeting place,
		# not on the resident's interaction point or an exit centreline.
		if not (key.begins_with("market.stall_") or key.begins_with("forum.portico_") or key.begins_with("residential.gossip_") or key.begins_with("quarter.")):
			continue
		var index := int(anchors[key])
		if index < 0 or index >= nodes.size():
			continue
		var row: Array = nodes[index]
		if row.size() != 3:
			continue
		var p := Vector3(float(row[0]), float(row[1]), float(row[2]))
		if key.begins_with("market.stall_"):
			p += Vector3(3.4, 0, 2.3)
		else:
			p += Vector3(1.65, 0, 1.15)
		result.append(p)
	return result

func configure(points: Array[Vector3], profile: String) -> void:
	_candidates = points.duplicate()
	set_quality(profile)
	set_physics_process(true)

func set_quality(profile: String) -> void:
	_budget = int({"low":1, "balanced":2, "high":3, "very_high":4}.get(profile, 2))

func set_darkness(value: float) -> void:
	var next := clampf(value,0.0,1.0)
	if is_equal_approx(next,_night):
		return
	_night=next
	_update_flames()
	if _night <= 0.04:
		for light: OmniLight3D in _pool:
			light.hide()
	_elapsed = 0.0

## Use the same actual mission route as the HUD. Select forward sample points
## by path distance, not straight lines through houses. No light is invented
## at a mission marker: only verified, fixed roadside fixtures may illuminate.
func set_route_context(player_at: Vector3, route: PackedVector2Array) -> void:
	if not player_at.is_finite():
		return
	_route_player=player_at
	_route_samples=PackedVector2Array()
	var last:=Vector2(player_at.x,player_at.z)
	var distance:=0.0
	var next_sample:=4.0
	for point: Vector2 in route:
		if not point.is_finite():
			continue
		var segment:=last.distance_to(point)
		while segment>0.001 and next_sample<=minf(PATH_LOOKAHEAD,distance+segment):
			_route_samples.append(last.lerp(point,clampf((next_sample-distance)/segment,0.0,1.0)))
			next_sample+=4.0
		distance+=segment
		last=point
		if distance>=PATH_LOOKAHEAD:
			break
	if distance<PATH_LOOKAHEAD and not route.is_empty():
		_route_samples.append(last)
	_elapsed=0.0


func _physics_process(_delta: float) -> void:
	if _installed:
		set_physics_process(false)
		return
	# Wait until the actual authored ground/static structures are present in
	# the physics world. A candidate that cannot be grounded is rejected.
	var space := get_world_3d().direct_space_state
	var shape := CylinderShape3D.new()
	shape.radius = 0.27
	shape.height = 1.40
	for candidate: Vector3 in _candidates:
		var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(candidate + Vector3.UP * 0.65, candidate - Vector3.UP * 0.85, 1))
		if hit.is_empty() or (hit.normal as Vector3).y < 0.75:
			continue
		var at: Vector3 = hit.position
		if absf(at.y - candidate.y) > 0.45:
			continue
		var fits := PhysicsShapeQueryParameters3D.new()
		fits.shape = shape
		fits.collision_mask = 1
		fits.transform.origin = at + Vector3.UP * 0.75
		if not space.intersect_shape(fits, 1).is_empty():
			continue
		var too_close := false
		for prior: Vector3 in sites:
			if prior.distance_squared_to(at) < SPACING * SPACING:
				too_close = true
				break
		if not too_close:
			sites.append(at)
	_installed = true
	_candidates.clear()
	_build_batches()
	set_physics_process(false)
	print("ROUTE_FIRE_SITES ", sites.size(), " ", name)

func _build_batches() -> void:
	if sites.is_empty():
		return
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	var post := CylinderMesh.new()
	post.top_radius = 0.035
	post.bottom_radius = 0.06
	post.height = 1.05
	post.radial_segments = 8
	post.rings = 1
	tool.append_from(post, 0, Transform3D(Basis.IDENTITY, Vector3(0,0.53,0)))
	var bowl := CylinderMesh.new()
	bowl.top_radius = 0.24
	bowl.bottom_radius = 0.10
	bowl.height = 0.19
	bowl.radial_segments = 12
	bowl.rings = 1
	tool.append_from(bowl, 0, Transform3D(Basis.IDENTITY, Vector3(0,1.12,0)))
	var foot := CylinderMesh.new()
	foot.top_radius = 0.09
	foot.bottom_radius = 0.23
	foot.height = 0.10
	foot.radial_segments = 8
	foot.rings = 1
	tool.append_from(foot, 0, Transform3D(Basis.IDENTITY, Vector3(0,0.05,0)))
	var material := StandardMaterial3D.new()
	material.albedo_color = Color("4e4237")
	material.roughness = 0.77
	material.metallic = 0.48
	tool.set_material(material)
	var holders := _batch("RoadsideBraziers", tool.commit())
	for i: int in sites.size():
		holders.multimesh.set_instance_transform(i, Transform3D(Basis.IDENTITY, to_local(sites[i])))
	var card := QuadMesh.new()
	card.size = Vector2.ONE
	_flames = _batch("RoadsideFlames", card)
	_flames.material_override = ShaderMaterial.new()
	_flames.material_override.shader = FLAME
	_flames.material_override.set_shader_parameter("brightness", 2.5)
	for i: int in sites.size():
		_flames.multimesh.set_instance_transform(i, Transform3D(Basis.from_scale(Vector3(0.45,0.63,1)), to_local(sites[i]) + Vector3.UP * 1.43))
	for i in MAX_LIGHTS:
		var light := OmniLight3D.new()
		light.name = "NearbyBrazierLight%d" % i
		light.light_color = Color("ffad62")
		light.omni_range = RANGE
		light.omni_attenuation = 1.2
		light.shadow_enabled = false
		light.light_specular = 0.20
		light.hide()
		add_child(light)
		_pool.append(light)
	_update_flames()

func _batch(id: String, mesh: Mesh) -> MultiMeshInstance3D:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = mesh
	mm.instance_count = sites.size()
	var result := MultiMeshInstance3D.new()
	result.name = id
	result.multimesh = mm
	result.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(result)
	return result

func _update_flames() -> void:
	if not is_instance_valid(_flames):
		return
	var lit := smoothstep(0.04, 0.65, _night)
	_flames.visible = lit > 0.001
	_flames.material_override.set_shader_parameter("lit", lit)

func _process(delta: float) -> void:
	if not _installed or not is_visible_in_tree() or _night <= 0.04:
		return
	var camera := get_viewport().get_camera_3d()
	if not is_instance_valid(camera):
		return
	_clock += delta
	_elapsed -= delta
	if _elapsed <= 0:
		_elapsed = 0.2
		_select_nearest(camera.global_position)
	var lit := smoothstep(0.04, 0.65, _night)
	for i in _pool.size():
		var light := _pool[i]
		if light.visible:
			var phase := light.position.x * 0.37 + light.position.z * 0.71
			light.light_energy = lit * 2.75 * (1.0 + 0.09 * sin(_clock * 9.2 + phase) + 0.045 * sin(_clock * 17.3 + phase))

func _select_nearest(eye: Vector3) -> void:
	var ranked: Array[Dictionary] = []
	var anchor := _route_player if _route_player.is_finite() else eye
	for at: Vector3 in sites:
		var distance := anchor.distance_squared_to(at)
		if distance < 29.0 * 29.0:
			var score := distance
			for point: Vector2 in _route_samples:
				score=minf(score,Vector2(at.x,at.z).distance_squared_to(point)+12.0)
			ranked.append({"at":at,"distance":distance,"score":score})
	# Keep the closest player-side light even when the camera is behind a wall.
	ranked.sort_custom(func(a: Dictionary,b: Dictionary)->bool: return float(a.distance)<float(b.distance))
	if ranked.size()>1:
		var first: Dictionary=ranked.pop_front()
		ranked.sort_custom(func(a: Dictionary,b: Dictionary)->bool: return float(a.score)<float(b.score))
		ranked.push_front(first)
	for i in _pool.size():
		var light := _pool[i]
		light.visible = i < mini(_budget, ranked.size())
		if light.visible:
			light.global_position = (ranked[i].at as Vector3) + Vector3.UP * 1.46
