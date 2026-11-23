extends Node3D
## Original, bounded horse/rider geometry. The saved story is the only clock.
## These thirty visual identities never become village workers or award combat hits.

const RIDER_COUNT := 30
const APPROACH_SECONDS := 32.0
const LANE_SPACING := 4.2
const ROW_SPACING := 6.0
const TRAVEL_METRES := 84.0
const COATS := [Color("765039"), Color("3f332e"), Color("ae8b61"), Color("766d62"), Color("513c2e")]
const CLOTH := [Color("756354"), Color("7b473d"), Color("46524a"), Color("8e805c"), Color("51465e")]
const PROFILES := {
	"low":{"near":30.0, "near_count":6, "distance":220.0},
	"balanced":{"near":50.0, "near_count":12, "distance":240.0},
	"high":{"near":75.0, "near_count":20, "distance":280.0},
	"very_high":{"near":100.0, "near_count":30, "distance":320.0}
}
const PARTS := ["body", "kit", "rider", "limb", "hoof"]
var active := false
var quality := "balanced"
var _sequence: Dictionary = {}
var _batches: Dictionary = {}
var _bodies: Array[StaticBody3D] = []
var _ground_sampler := Callable()
var _built := false
var _last_samples: Array[Dictionary] = []
var _counts := {"near":0, "far":0, "culled":0}
var _triangle_counts: Dictionary = {}


func set_active(value: bool) -> void:
	# There is deliberately no process clock to run while paused or offline.
	active = value


func set_ground_sampler(sampler: Callable) -> void:
	_ground_sampler = sampler


func sync_state(data: Dictionary, profile: String = "balanced") -> void:
	quality = profile if PROFILES.has(profile) else "balanced"
	var village: Variant = data.get("village", {})
	var childhood: Variant = village.get("childhood", {}) if typeof(village) == TYPE_DICTIONARY else {}
	var sequence: Variant = childhood.get("night_raid", {}) if typeof(childhood) == TYPE_DICTIONARY else {}
	var enabled: bool = typeof(village) == TYPE_DICTIONARY and village.get("enabled", false) == true
	if not enabled or typeof(sequence) != TYPE_DICTIONARY or not _valid_sequence(sequence) or sequence.phase not in ["approach", "attack"]:
		_hide_sequence()
		return
	_sequence = sequence.duplicate(true)
	_last_samples = sample_riders(_sequence)
	if not _built:
		_build()
	visible = true
	_render_samples()


static func sample_riders(sequence: Dictionary) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if not _valid_sequence(sequence) or sequence.phase not in ["approach", "attack"]:
		return result
	var progress := clampf(float(sequence.elapsed) / APPROACH_SECONDS, 0.0, 1.0) if sequence.phase == "approach" else 1.0
	var eased := progress * progress * (3.0 - 2.0 * progress)
	var travel := TRAVEL_METRES * eased
	var speed := TRAVEL_METRES * 6.0 * progress * (1.0 - progress) / APPROACH_SECONDS if sequence.phase == "approach" else 0.0
	var seed := int(sequence.seed)
	for index in RIDER_COUNT:
		var row := floori(float(index) / 3.0)
		var lane := index % 3 - 1
		var variant := posmod(seed + index * 7, COATS.size())
		var wobble_phase := float(posmod(seed, 29)) * 0.13 + row * 0.51 + progress * PI
		var lateral := sin(wobble_phase) * 0.14
		var lateral_slope := cos(wobble_phase) * 0.14 * PI / TRAVEL_METRES
		result.append({
			"id":"mounted_raider_%02d" % index, "index":index,
			"position":Vector3(float(lane) * LANE_SPACING + lateral, 0.0, -142.0 + travel - float(row) * ROW_SPACING),
			"yaw":PI + atan(lateral_slope), "scale":0.97 + float(posmod(seed + index * 3, 7)) * 0.012,
			"coat":variant, "cloth":posmod(seed * 3 + index * 2, CLOTH.size()),
			"gait_phase":travel * 2.2 + float(index) * 1.73,
			"speed":speed, "travel_metres":travel
		})
	return result


func debug_snapshot() -> Dictionary:
	var instances := {}
	for key: String in _batches:
		instances[key] = int((_batches[key] as MultiMeshInstance3D).multimesh.visible_instance_count)
	return {"visible":visible, "riders":_last_samples.size(), "near":int(_counts.near),
		"far":int(_counts.far), "culled":int(_counts.culled), "profile":quality,
		"multimesh_groups":_batches.size(), "instances":instances,
		"mesh_triangles":_triangle_counts.duplicate(), "colliders":_bodies.size(),
		"sequence":_sequence.duplicate(true), "source":"original_runtime_geometry",
		"clock":"saved_story_elapsed_only"}


func _hide_sequence() -> void:
	visible = false
	_sequence = {}
	_last_samples.clear()
	_counts = {"near":0, "far":0, "culled":0}
	for batch: MultiMeshInstance3D in _batches.values():
		batch.multimesh.visible_instance_count = 0
	for body: StaticBody3D in _bodies:
		body.collision_layer = 0


func _build() -> void:
	_built = true
	set_meta("historical_status", "fictional_unidentified_mounted_raiders")
	var material := StandardMaterial3D.new()
	material.vertex_color_use_as_albedo = true
	material.roughness = 0.9
	for detail: String in ["near", "far"]:
		for part: String in PARTS:
			var mesh := _part_mesh(part, detail == "near")
			mesh.surface_set_material(0, material)
			var arrays := mesh.surface_get_arrays(0)
			var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			_triangle_counts[detail + "_" + part] = floori(float(vertices.size()) / 3.0)
			var multimesh := MultiMesh.new()
			multimesh.transform_format = MultiMesh.TRANSFORM_3D
			multimesh.use_colors = true
			multimesh.mesh = mesh
			multimesh.instance_count = RIDER_COUNT * (8 if part == "limb" else (4 if part == "hoof" else 1))
			multimesh.visible_instance_count = 0
			var node := MultiMeshInstance3D.new()
			node.name = "Riders_" + detail + "_" + part
			node.multimesh = multimesh
			node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if detail == "near" else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			add_child(node)
			_batches[detail + "_" + part] = node
	# Separate simple bodies prevent the player passing through a visible horse.
	# No body receives hit points, economy identity or authority over the raid.
	var shape := BoxShape3D.new()
	shape.size = Vector3(1.15, 2.8, 2.9)
	for index in RIDER_COUNT:
		var body := StaticBody3D.new()
		body.name = "MountedBody_%02d" % index
		body.collision_layer = 0
		body.collision_mask = 0
		body.set_meta("visual_id", "mounted_raider_%02d" % index)
		var collider := CollisionShape3D.new()
		collider.shape = shape
		collider.position.y = 1.4
		body.add_child(collider)
		add_child(body)
		_bodies.append(body)


func _render_samples() -> void:
	var used := {}
	for key: String in _batches:
		used[key] = 0
	_counts = {"near":0, "far":0, "culled":0}
	var camera := get_viewport().get_camera_3d()
	var limits: Dictionary = PROFILES[quality]
	# Closest riders receive the bounded detailed geometry; identity never changes.
	var order := _last_samples.duplicate()
	if camera != null:
		order.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
			return camera.global_position.distance_squared_to(to_global(a.position)) < camera.global_position.distance_squared_to(to_global(b.position)))
	for sample: Dictionary in order:
		var at: Vector3 = sample.position
		at.y = _ground_height(Vector2(at.x, at.z))
		var scale_value := float(sample.scale)
		var frame := Transform3D(Basis(Vector3.UP, float(sample.yaw)).scaled(Vector3.ONE * scale_value), at)
		var body: StaticBody3D = _bodies[int(sample.index)]
		body.transform = frame
		body.collision_layer = 1
		var distance := camera.global_position.distance_to(to_global(at)) if camera != null else 0.0
		if distance > float(limits.distance):
			_counts.culled += 1
			continue
		var near := distance <= float(limits.near) and int(_counts.near) < int(limits.near_count)
		var detail := "near" if near else "far"
		_counts[detail] += 1
		var gait := float(sample.gait_phase)
		var stride := clampf(float(sample.speed) / 2.4, 0.0, 1.0)
		var bob := sin(gait * 2.0) * 0.028 * stride
		var torso_frame := frame * Transform3D(Basis.IDENTITY, Vector3(0, bob, 0))
		var coat: Color = COATS[int(sample.coat)]
		_add_instance(detail + "_body", torso_frame, coat, used)
		_add_instance(detail + "_kit", torso_frame, Color.WHITE, used)
		_add_instance(detail + "_rider", torso_frame, CLOTH[int(sample.cloth)], used)
		for leg in 4:
			var side := -1.0 if leg % 2 == 0 else 1.0
			var front := leg < 2
			var gait_offset := 0.0 if leg in [0, 3] else PI
			var phase := gait + gait_offset
			var z := -0.69 if front else 0.69
			var hip := Vector3(side * 0.32, 1.10 + bob, z)
			var foot := Vector3(side * 0.32, 0.085 + maxf(0.0, sin(phase)) * 0.15 * stride, z + cos(phase) * 0.24 * stride)
			# Two-link leg solution preserves plausible knees and keeps planted hooves
			# at the ground instead of rotating straight rods through it.
			var delta := foot - hip
			var length := clampf(delta.length(), 0.01, 1.079)
			var direction := delta.normalized()
			var along := (0.53 * 0.53 - 0.55 * 0.55 + length * length) / (2.0 * length)
			var bend := sqrt(maxf(0.0, 0.53 * 0.53 - along * along))
			var normal := Vector3(0, -direction.z, direction.y)
			var knee := hip + direction * along + normal * bend * (1.0 if front else -1.0)
			_add_instance(detail + "_limb", frame * _segment(hip, knee, 0.075), coat, used)
			_add_instance(detail + "_limb", frame * _segment(knee, foot, 0.052), coat.darkened(0.17), used)
			_add_instance(detail + "_hoof", frame * Transform3D(Basis.IDENTITY, foot), Color("302923"), used)
	for key: String in _batches:
		(_batches[key] as MultiMeshInstance3D).multimesh.visible_instance_count = int(used[key])


func _ground_height(at: Vector2) -> float:
	if _ground_sampler.is_valid():
		var result: Variant = _ground_sampler.call(at)
		if typeof(result) in [TYPE_INT, TYPE_FLOAT] and is_finite(float(result)):
			return float(result)
	return 0.0


func _add_instance(key: String, transform_value: Transform3D, color: Color, used: Dictionary) -> void:
	var batch: MultiMeshInstance3D = _batches[key]
	var index := int(used[key])
	batch.multimesh.set_instance_transform(index, transform_value)
	batch.multimesh.set_instance_color(index, color)
	used[key] = index + 1


static func _valid_sequence(sequence: Dictionary) -> bool:
	# The domain validates decisions and consequences. This read-only projection
	# accepts those additional saved fields without taking ownership of them.
	if not sequence.has_all(["phase", "elapsed", "seed"]):
		return false
	if typeof(sequence.phase) != TYPE_STRING or sequence.phase not in ["dormant", "approach", "attack", "aftermath"]:
		return false
	if typeof(sequence.elapsed) not in [TYPE_INT, TYPE_FLOAT] or not is_finite(float(sequence.elapsed)) or float(sequence.elapsed) < 0.0 or float(sequence.elapsed) > 1000000000.0:
		return false
	return typeof(sequence.seed) in [TYPE_INT, TYPE_FLOAT] and is_finite(float(sequence.seed)) and float(sequence.seed) == floor(float(sequence.seed)) and float(sequence.seed) >= 0.0 and float(sequence.seed) <= 2147483647.0


static func _segment(a: Vector3, b: Vector3, radius: float) -> Transform3D:
	var delta := b - a
	var y := delta.normalized()
	var x := y.cross(Vector3.FORWARD).normalized()
	if x.length_squared() < 0.01:
		x = y.cross(Vector3.RIGHT).normalized()
	var z := x.cross(y).normalized()
	return Transform3D(Basis(x, y, z).scaled(Vector3(radius, delta.length(), radius)), (a + b) * 0.5)


static func _part_mesh(part: String, detailed: bool) -> ArrayMesh:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var sphere := SphereMesh.new()
	sphere.radius = 1.0
	sphere.height = 2.0
	sphere.radial_segments = 12 if detailed else 8
	sphere.rings = 6 if detailed else 3
	var box := BoxMesh.new()
	box.size = Vector3.ONE
	var cylinder := CylinderMesh.new()
	cylinder.top_radius = 1.0
	cylinder.bottom_radius = 1.0
	cylinder.height = 1.0
	cylinder.radial_segments = 10 if detailed else 6
	match part:
		"body":
			_piece(surface, sphere, Vector3(0,1.27,0), Vector3(.43,.42,.91), Color.WHITE)
			_piece(surface, sphere, Vector3(0,1.3,-.65), Vector3(.39,.46,.42), Color.WHITE)
			_piece(surface, sphere, Vector3(0,1.31,.65), Vector3(.43,.45,.44), Color.WHITE)
			_piece(surface, sphere, Vector3(0,1.63,-.77), Vector3(.27,.53,.31), Color.WHITE, Vector3(-.4,0,0))
			_piece(surface, sphere, Vector3(0,1.91,-1.07), Vector3(.21,.31,.36), Color.WHITE, Vector3(.5,0,0))
			_piece(surface, sphere, Vector3(0,1.69,-1.37), Vector3(.18,.17,.29), Color.WHITE)
			for side in [-1.0,1.0]:
				_piece(surface, sphere, Vector3(side*.13,2.23,-.96), Vector3(.07,.21,.09), Color.WHITE, Vector3(-.15,0,side*.2))
		"kit":
			_piece(surface, sphere, Vector3(0,1.05,1.1), Vector3(.12,.49,.18), Color("302721"), Vector3(-.35,0,0))
			_piece(surface, sphere, Vector3(0,1.79,-.69), Vector3(.085,.43,.22), Color("302721"), Vector3(-.4,0,0))
			_piece(surface, sphere, Vector3(0,1.64,-1.48), Vector3(.17,.115,.16), Color("4e3b30"))
			_piece(surface, box, Vector3(0,1.68,.07), Vector3(.68,.09,.65), Color("5a4434"))
			_piece(surface, sphere, Vector3(0,2.51,.06), Vector3(.145,.20,.145), Color("bb8c69"))
			_piece(surface, sphere, Vector3(0,2.63,.07), Vector3(.148,.105,.15), Color("4c4035"))
			if detailed:
				for side in [-1.0,1.0]:
					_piece(surface, sphere, Vector3(side*.17,1.98,-1.23), Vector3(.024,.028,.029), Color("171510"))
					_piece(surface, sphere, Vector3(side*.21,1.96,-.36), Vector3(.075,.06,.075), Color("bb8c69"))
					_piece(surface, sphere, Vector3(side*.38,.88,.07), Vector3(.11,.10,.23), Color("3a3029"))
					for end in [-1.0,1.0]:
						_piece(surface, sphere, Vector3(side*.24,1.79,end*.27), Vector3(.065,.16,.06), Color("654934"))
					_append(surface, cylinder, _segment(Vector3(side*.19,1.8,-1.26), Vector3(side*.21,1.96,-.36), .014), Color("4a3427"))
					_append(surface, cylinder, _segment(Vector3(side*.20,1.94,-1.12), Vector3(side*.18,1.59,-1.47), .022), Color("4a3427"))
				_piece(surface, box, Vector3(0,1.66,-1.48), Vector3(.38,.045,.045), Color("4a3427"))
			# Simple unmarked spear; no ethnic or unit insignia is invented.
			_append(surface, cylinder, _segment(Vector3(.45,1.0,.14), Vector3(.45,3.05,-.05), .025), Color("73583a"))
			_piece(surface, sphere, Vector3(.45,3.16,-.06), Vector3(.055,.19,.025), Color("9c9e98"))
		"rider":
			_piece(surface, sphere, Vector3(0,1.83,.09), Vector3(.28,.20,.28), Color.WHITE)
			_piece(surface, sphere, Vector3(0,2.15,.06), Vector3(.24,.38,.17), Color.WHITE, Vector3(-.1,0,0))
			for side in [-1.0,1.0]:
				_append(surface, cylinder, _segment(Vector3(side*.16,1.8,.1), Vector3(side*.39,1.44,-.11), .105), Color.WHITE)
				_append(surface, cylinder, _segment(Vector3(side*.39,1.44,-.11), Vector3(side*.38,.94,.05), .08), Color("c0b39a"))
				_append(surface, cylinder, _segment(Vector3(side*.22,2.31,.02), Vector3(side*.32,2.10,-.23), .075), Color.WHITE)
				_append(surface, cylinder, _segment(Vector3(side*.32,2.10,-.23), Vector3(side*.21,1.98,-.36), .06), Color.WHITE)
		"limb":
			_append(surface, cylinder, Transform3D.IDENTITY, Color.WHITE)
		"hoof":
			_piece(surface, box, Vector3(0,0,0), Vector3(.15,.15,.21), Color.WHITE)
	return surface.commit()


static func _piece(surface: SurfaceTool, mesh: PrimitiveMesh, at: Vector3, size: Vector3, color: Color, rotation_value: Vector3 = Vector3.ZERO) -> void:
	_append(surface, mesh, Transform3D(Basis.from_euler(rotation_value).scaled(size), at), color)


static func _append(surface: SurfaceTool, mesh: PrimitiveMesh, transform_value: Transform3D, color: Color) -> void:
	var arrays := mesh.get_mesh_arrays()
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	var normal_basis := transform_value.basis.inverse().transposed()
	for index in indices:
		surface.set_color(color)
		surface.set_normal((normal_basis * normals[index]).normalized())
		surface.add_vertex(transform_value * vertices[index])
