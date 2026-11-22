extends RefCounted
## Deterministic, mobile-sized scenery for the art review. Geometry stays in all profiles.
## Public API: build_ground(parent: Node3D), build_trees(parent: Node3D).
## Uses Godot's clockwise front-face convention, verified against the installed PlaneMesh.

const TERRAIN_STEP := 2.5
const TERRAIN_X_MIN := -125.0
const TERRAIN_X_MAX := 125.0
const TERRAIN_Z_MIN := -150.0
const TERRAIN_Z_MAX := 90.0
const SEED := 2601122
const CROWN_SEGMENTS := 12
const CROWN_LEVELS := 15

static func _noise() -> FastNoiseLite:
	var noise := FastNoiseLite.new()
	noise.seed = SEED
	noise.frequency = 0.025
	noise.fractal_octaves = 4
	noise.fractal_lacunarity = 2.1
	noise.fractal_gain = 0.48
	return noise

static func _height(x: float, z: float, noise: FastNoiseLite) -> float:
	# All six placed game assets and the existing grass field share an exactly flat pad.
	var village_distance := maxf(absf(x), absf(z))
	var edge := smoothstep(27.0, 43.0, village_distance)
	var rolling := 0.8 + 1.8 * noise.get_noise_2d(x, z)
	# Connected height-field ridges, rather than intersecting spherical props.
	var front_crest := -66.0 + 8.0 * sin(x * 0.038) + 7.0 * noise.get_noise_2d(x, 91.0)
	var front_envelope := exp(-pow((z - front_crest) / 22.0, 2.0))
	var front_height := 12.0 + 5.5 * sin(x * 0.049 + 0.7) + 7.0 * absf(noise.get_noise_2d(x * 1.3, -73.0))
	var rear_envelope := exp(-pow((z + 112.0 + 6.0 * sin(x * 0.027)) / 25.0, 2.0))
	var rear_height := 19.0 + 8.0 * noise.get_noise_2d(x * 0.9, -150.0) + 4.0 * sin(x * 0.071)
	var side_envelope := smoothstep(45.0, 92.0, absf(x))
	var side_ridge := side_envelope * (5.0 + 6.0 * absf(noise.get_noise_2d(x, z * 0.7)))
	return edge * maxf(-0.16, rolling + front_envelope * front_height + rear_envelope * rear_height + side_ridge)

static func _normal(x: float, z: float, noise: FastNoiseLite) -> Vector3:
	var epsilon := 0.35
	return Vector3(_height(x - epsilon, z, noise) - _height(x + epsilon, z, noise),
		2.0 * epsilon, _height(x, z - epsilon, noise) - _height(x, z + epsilon, noise)).normalized()

static func _terrain_color(x: float, z: float, height: float, noise: FastNoiseLite) -> Color:
	var macro := noise.get_noise_2d(x * 1.45 + 341.0, z * 1.45 - 236.0)
	var patches := smoothstep(-0.35, 0.35, macro)
	var earth_tint := Color(0.94, 0.91, 0.80)
	var sparse_grass_tint := Color(0.69, 0.79, 0.58)
	var color := earth_tint.lerp(sparse_grass_tint, patches * 0.58)
	var distance_tint := smoothstep(36.0, 85.0, -z)
	color = color.lerp(Color(0.69, 0.78, 0.64), distance_tint * 0.70)
	if height > 14.0:
		color = color.lerp(Color(0.86, 0.85, 0.75), smoothstep(14.0, 28.0, height) * 0.45)
	return color

static func _material(texture_name: String, tint: Color, vertex_colors: bool = false) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = tint
	mat.roughness = 0.94
	mat.vertex_color_use_as_albedo = vertex_colors
	mat.vertex_color_is_srgb = true
	mat.cull_mode = BaseMaterial3D.CULL_BACK
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	if texture_name != "":
		mat.albedo_texture = load("res://materials/" + texture_name + "_basecolor.png") as Texture2D
		mat.normal_enabled = true
		mat.normal_texture = load("res://materials/" + texture_name + "_normal.png") as Texture2D
		mat.normal_scale = 0.36
		mat.roughness_texture = load("res://materials/" + texture_name + "_roughness.png") as Texture2D
	return mat

static func _add_vertex(surface: SurfaceTool, position: Vector3, normal: Vector3, color: Color, uv: Vector2) -> void:
	surface.set_normal(normal)
	surface.set_color(color)
	surface.set_uv(uv)
	surface.add_vertex(position)

static func _mesh_instance(parent: Node3D, label: String, mesh: Mesh, mat: Material) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.name = label
	node.mesh = mesh
	node.material_override = mat
	node.set_meta("essential_environment", true)
	parent.add_child(node)
	return node

static func build_ground(parent: Node3D) -> Dictionary:
	var noise := _noise()
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var x_count := int((TERRAIN_X_MAX - TERRAIN_X_MIN) / TERRAIN_STEP)
	var z_count := int((TERRAIN_Z_MAX - TERRAIN_Z_MIN) / TERRAIN_STEP)
	var minimum_height := INF
	var maximum_height := -INF
	for zi in range(z_count):
		for xi in range(x_count):
			var x := TERRAIN_X_MIN + xi * TERRAIN_STEP
			var z := TERRAIN_Z_MIN + zi * TERRAIN_STEP
			var corners := [Vector2(x, z), Vector2(x + TERRAIN_STEP, z),
				Vector2(x + TERRAIN_STEP, z + TERRAIN_STEP), Vector2(x, z + TERRAIN_STEP)]
			# Opposite winding to the earlier culled ground. Cross dot UP is negative.
			for corner_index in [0, 1, 2, 0, 2, 3]:
				var point: Vector2 = corners[corner_index]
				var height := _height(point.x, point.y, noise)
				minimum_height = minf(minimum_height, height)
				maximum_height = maxf(maximum_height, height)
				_add_vertex(surface, Vector3(point.x, height, point.y), _normal(point.x, point.y, noise),
					_terrain_color(point.x, point.y, height, noise), point * 0.32)
	surface.index()
	surface.generate_tangents()
	var terrain := _mesh_instance(parent, "ContinuousFrontierTerrain", surface.commit(), _material("earth", Color.WHITE, true))
	terrain.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# Geometry is retained and opaque at every quality level. Edge colors match the field.
	var road_surface := SurfaceTool.new()
	road_surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var road_triangles := 0
	for section in range(62):
		var z0 := -42.0 + float(section) * 1.25
		var z1 := z0 + 1.25
		var bend0 := smoothstep(18.0, 42.0, -z0) * sin(z0 * 0.070) * 2.1
		var bend1 := smoothstep(18.0, 42.0, -z1) * sin(z1 * 0.070) * 2.1
		road_triangles += _path_section(road_surface, Vector2(-0.3 + bend0, z0), Vector2(-0.3 + bend1, z1), 1.9, noise)
	# Short, functional approaches terminate in front of the actual doorway positions.
	road_triangles += _path_section(road_surface, Vector2(-5.0, 0.66), Vector2(-0.3, 0.65), 0.72, noise)
	road_triangles += _path_section(road_surface, Vector2(4.85, -2.15), Vector2(-0.3, -1.65), 0.72, noise)
	road_surface.index()
	road_surface.generate_tangents()
	var road := _mesh_instance(parent, "VillageTrafficAndDoorApproaches", road_surface.commit(), _material("earth", Color.WHITE, true))
	road.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return {"terrain_triangles": x_count * z_count * 2, "road_triangles": road_triangles,
		"material_batches": 2, "terrain_bounds": [Vector3(TERRAIN_X_MIN, minimum_height, TERRAIN_Z_MIN), Vector3(TERRAIN_X_MAX, maximum_height, TERRAIN_Z_MAX)],
		"flat_village_extent_m": 54.0, "front_winding": "clockwise", "upward_normals": true}

static func _path_section(surface: SurfaceTool, from: Vector2, to: Vector2, half_width: float, noise: FastNoiseLite) -> int:
	var direction := (to - from).normalized()
	var across := Vector2(direction.y, -direction.x)
	var widths := [-1.30, -1.0, -0.72, 0.72, 1.0, 1.30]
	for band in range(widths.size() - 1):
		var left := float(widths[band]) * half_width
		var right := float(widths[band + 1]) * half_width
		var corners := [from + across * left, from + across * right, to + across * right, to + across * left]
		# Corner order follows the terrain's Godot front face for any path direction.
		for index in [0, 1, 2, 0, 2, 3]:
			var point: Vector2 = corners[index]
			var lateral := absf(left if index == 0 or index == 3 else right) / half_width
			var edge_mix := smoothstep(0.75, 1.30, lateral)
			var h := _height(point.x, point.y, noise)
			var color := Color(1.0, 0.97, 0.88).lerp(_terrain_color(point.x, point.y, h, noise), edge_mix)
			_add_vertex(surface, Vector3(point.x, h + 0.009, point.y), _normal(point.x, point.y, noise), color, point * 0.32)
	return (widths.size() - 1) * 2

static func _crown_radius(t: float) -> float:
	# A continuous narrow column with a rounded shoulder and irregular tapered tip.
	var profile := [0.18, 0.40, 0.61, 0.73, 0.74, 0.71, 0.68, 0.62, 0.54, 0.46, 0.36, 0.27, 0.18, 0.085, 0.015]
	var position := clampf(t, 0.0, 1.0) * float(profile.size() - 1)
	var index := mini(int(position), profile.size() - 2)
	return lerpf(float(profile[index]), float(profile[index + 1]), position - float(index))

static func _crown_vertex(ring: int, segment: int, variant: int) -> Vector3:
	segment = segment % CROWN_SEGMENTS
	var t := float(ring) / float(CROWN_LEVELS - 1)
	var angle := TAU * float(segment % CROWN_SEGMENTS) / float(CROWN_SEGMENTS)
	var ripple := 1.0 + 0.12 * sin(float(segment) * 2.41 + float(ring) * 1.83 + float(variant))
	ripple += 0.055 * sin(angle * 3.0 + t * 14.0 + variant * 1.3)
	var radius := _crown_radius(t) * ripple
	var bend_x := sin(t * 2.1 + variant * 1.1) * t * 0.19
	var bend_z := sin(t * 3.2 + variant * 2.4) * t * 0.13
	var y_jitter := sin(angle * 3.0 + ring * 1.7 + variant) * 0.07 * sin(t * PI)
	return Vector3(cos(angle) * radius + bend_x, 1.05 + t * 5.35 + y_jitter, sin(angle) * radius + bend_z)

static func _crown(variant: int) -> ArrayMesh:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for ring in range(CROWN_LEVELS - 1):
		for segment in range(CROWN_SEGMENTS):
			var corners := [Vector2i(ring, segment), Vector2i(ring, segment + 1),
				Vector2i(ring + 1, segment + 1), Vector2i(ring + 1, segment)]
			for index in [0, 1, 2, 0, 2, 3]:
				var pair: Vector2i = corners[index]
				var point := _crown_vertex(pair.x, pair.y, variant)
				var t := float(pair.x) / float(CROWN_LEVELS - 1)
				var angle := TAU * float(pair.y % CROWN_SEGMENTS) / float(CROWN_SEGMENTS)
				var slope := (_crown_radius(minf(1.0, t + 0.045)) - _crown_radius(maxf(0.0, t - 0.045))) / 0.4815
				var normal := Vector3(cos(angle), -slope, sin(angle)).normalized()
				var variation := 0.82 + 0.14 * sin(angle * 2.0 + t * 19.0 + variant * 1.9)
				var tint := Color(variation, minf(1.0, variation + 0.045), variation * 0.90)
				_add_vertex(surface, point, normal, tint, Vector2(angle / TAU, t))
	surface.index()
	return surface.commit()

static func build_trees(parent: Node3D) -> Dictionary:
	var noise := _noise()
	var rng := RandomNumberGenerator.new()
	rng.seed = SEED + 71
	var positions := [Vector2(-24,-23), Vector2(-18,-27), Vector2(-12,-29), Vector2(-7,-25),
		Vector2(12,-25), Vector2(19,-24), Vector2(-22,-12), Vector2(-23,1), Vector2(-22,14),
		Vector2(23,-13), Vector2(24,-1), Vector2(24,13), Vector2(-35,-43), Vector2(-25,-42),
		Vector2(-13,-47), Vector2(4,-43), Vector2(22,-47), Vector2(34,-42)]
	var trunk_shape := CylinderMesh.new()
	trunk_shape.bottom_radius = 0.16
	trunk_shape.top_radius = 0.045
	trunk_shape.height = 5.75
	trunk_shape.radial_segments = 9
	trunk_shape.rings = 1
	var trunk_multi := MultiMesh.new()
	trunk_multi.transform_format = MultiMesh.TRANSFORM_3D
	trunk_multi.mesh = trunk_shape
	trunk_multi.instance_count = positions.size()
	var crown_multis: Array[MultiMesh] = []
	for variant in range(3):
		var multi := MultiMesh.new()
		multi.transform_format = MultiMesh.TRANSFORM_3D
		multi.mesh = _crown(variant)
		multi.instance_count = positions.size() / 3
		crown_multis.append(multi)
	var bounds := AABB()
	for index in range(positions.size()):
		var point: Vector2 = positions[index]
		point += Vector2(rng.randf_range(-0.8,0.8),rng.randf_range(-0.8,0.8))
		var origin := Vector3(point.x, _height(point.x, point.y, noise), point.y)
		var scale := rng.randf_range(0.88,1.18)
		var width := rng.randf_range(0.88,1.10)
		var basis := Basis(Vector3.UP,rng.randf_range(-PI,PI)).scaled(Vector3(width,scale,width))
		trunk_multi.set_instance_transform(index, Transform3D(basis,origin + Vector3(0,2.875 * scale,0)))
		crown_multis[index % 3].set_instance_transform(index / 3,Transform3D(basis,origin))
		bounds = bounds.expand(origin - Vector3.ONE * 0.9)
		bounds = bounds.expand(origin + Vector3(0.9,6.6 * scale,0.9))
	var bark := _material("oak",Color("a5987f"))
	var leaves := _material("",Color("354b2f"),true)
	var trunk_node := MultiMeshInstance3D.new()
	trunk_node.name = "CypressTrunks"
	trunk_node.multimesh = trunk_multi
	trunk_node.material_override = bark
	trunk_node.set_meta("essential_environment",true)
	parent.add_child(trunk_node)
	for variant in range(3):
		var crowns := MultiMeshInstance3D.new()
		crowns.name = "IrregularCypressCrowns" + str(variant)
		crowns.multimesh = crown_multis[variant]
		crowns.material_override = leaves
		crowns.set_meta("essential_environment",true)
		parent.add_child(crowns)
	return {"trees":positions.size(), "material_batches":4,
		"crown_triangles_per_tree":(CROWN_LEVELS - 1) * CROWN_SEGMENTS * 2,
		"crown_variants":3, "bounds":bounds, "quality_visibility":"unchanged for all presets"}
