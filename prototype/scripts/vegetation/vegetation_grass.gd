extends Node3D
## Meadow grass with individual blades around the camera (owner decision
## D-060). The land is cut into 8 m cells; cells inside the profile's range
## are filled with blade tufts on a jittered grid where the ecology lets
## meadow grow (vegetation_ecology.grass_cover) and kept as one MultiMesh
## each. Nearby cells draw the full blade tuft, the outer ring a lighter
## one and a thinned share; cells are built a few per frame while the
## camera moves and dropped far behind it. Placement is a pure function of
## the cell, so the same meadow comes back on every visit and profile.
## Visual only: no collision, no simulation state.

const Library = preload("res://scripts/vegetation/vegetation_library.gd")
const Safe := preload("res://scripts/vegetation/vegetation_safe.gd")
const CELL := 8.0
const KEEP_CELLS := 420
## Cover is sampled on a coarse lattice per cell and interpolated per tuft.
const LATTICE := 4

var ecology
var end_m := 0.0
var near_m := 0.0
var density := 0.0
var far_share := 0.5
var cells_per_frame := 1
var _cells: Dictionary = {}     # Vector2i -> {node, count, lod} or {} when bare
var _visible := {"cells": 0, "instances": 0, "triangles": 0, "built_cells": 0}
var _triangles := {"near": 0, "far": 0}


func configure(budget: Dictionary) -> void:
	var next_density := float(budget.get("grass_density", 0.0))
	if not is_equal_approx(next_density, density):
		clear()
	density = next_density
	end_m = float(budget.get("grass_end_m", 0.0))
	near_m = float(budget.get("grass_near_m", 0.0))
	far_share = float(budget.get("grass_far_share", .5))
	cells_per_frame = maxi(1, int(budget.get("grass_cells_per_frame", 1)))
	# Ensure the grass material exists before the first season update.
	var material := Library.grass_material()
	if not Safe.active():
		material.set_shader_parameter("fade_end", maxf(end_m, 1.0))
	visible = density > 0.0 and end_m > 0.0


func clear() -> void:
	for cell: Dictionary in _cells.values():
		if cell.has("node"):
			(cell.node as Node3D).hide()
			(cell.node as Node).queue_free()
	_cells.clear()


## Shows the cells around the eye; builds missing ones nearest first, at most
## cells_per_frame per call unless complete is set (reviews, tests).
func update(eye: Vector3, forward: Vector2, half_fov_deg: float, complete := false) -> void:
	_visible = {"cells": 0, "instances": 0, "triangles": 0, "built_cells": _cells.size()}
	if ecology == null or not visible:
		return
	if _triangles.near == 0:
		_triangles.near = Library._triangles(Library.grass_mesh("grass_tuft_near"))
		_triangles.far = Library._triangles(Library.grass_mesh("grass_tuft_far"))
	var centre := Vector2i(floori(eye.x / CELL), floori(eye.z / CELL))
	var reach := ceili(end_m / CELL) + 1
	var missing := []
	var wanted := {}
	for dz in range(-reach, reach + 1):
		for dx in range(-reach, reach + 1):
			var key := centre + Vector2i(dx, dz)
			var middle := (Vector2(key) + Vector2(.5, .5)) * CELL
			var d := maxf(0.0, Vector2(eye.x, eye.z).distance_to(middle) - CELL * .71)
			if d > end_m:
				continue
			wanted[key] = d
			if not _cells.has(key):
				missing.append([d, key])
	missing.sort_custom(func(a: Array, b: Array) -> bool: return a[0] < b[0])
	var allowance := missing.size() if complete else cells_per_frame
	for i in mini(allowance, missing.size()):
		_cells[missing[i][1]] = _build(missing[i][1])
	for key: Vector2i in _cells:
		var cell: Dictionary = _cells[key]
		if not cell.has("node"):
			continue
		var node: MultiMeshInstance3D = cell.node
		if not wanted.has(key):
			node.visible = false
			continue
		var d: float = wanted[key]
		var middle := (Vector2(key) + Vector2(.5, .5)) * CELL
		var offset := middle - Vector2(eye.x, eye.z)
		# Behind the camera only the cells right around it stay drawn.
		if forward != Vector2.ZERO and offset.length() > CELL * 1.5:
			var spread := rad_to_deg(asin(clampf(CELL * .71 / offset.length(), 0.0, 1.0)))
			if absf(rad_to_deg(forward.angle_to(offset))) > half_fov_deg + spread:
				node.visible = false
				continue
		node.visible = true
		var lod := "near" if d < near_m else "far"
		if cell.lod != lod:
			node.multimesh.mesh = Library.grass_mesh("grass_tuft_" + lod)
			cell.lod = lod
		var share := lerpf(1.0, far_share, smoothstep(end_m * .45, end_m * .9, d))
		var count := ceili(int(cell.count) * share)
		node.multimesh.visible_instance_count = count
		_visible.cells += 1
		_visible.instances += count
		_visible.triangles += count * int(_triangles[lod])
	_visible.built_cells = _cells.size()
	if _cells.size() > KEEP_CELLS:
		_trim(centre, reach + 3)


func pending(eye: Vector3) -> bool:
	if ecology == null or not visible:
		return false
	var centre := Vector2i(floori(eye.x / CELL), floori(eye.z / CELL))
	var reach := ceili(end_m / CELL) + 1
	for dz in range(-reach, reach + 1):
		for dx in range(-reach, reach + 1):
			var key := centre + Vector2i(dx, dz)
			if not _cells.has(key) and maxf(0.0, Vector2(eye.x, eye.z).distance_to((Vector2(key) + Vector2(.5, .5)) * CELL) - CELL * .71) <= end_m:
				return true
	return false


func stats() -> Dictionary:
	return _visible


func _trim(centre: Vector2i, reach: int) -> void:
	for key: Vector2i in _cells.keys():
		if absi(key.x - centre.x) > reach or absi(key.y - centre.y) > reach:
			var cell: Dictionary = _cells[key]
			if cell.has("node"):
				(cell.node as Node).queue_free()
			_cells.erase(key)


func _build(key: Vector2i) -> Dictionary:
	var origin := Vector2(key) * CELL
	var step := CELL / LATTICE
	var lattice: Array[Vector3] = []
	var any := false
	for j in LATTICE + 1:
		for i in LATTICE + 1:
			var cover: Vector3 = ecology.grass_cover(origin + Vector2(i, j) * step)
			lattice.append(cover)
			any = any or cover.x > .02
	if not any:
		return {}
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(key) ^ 0x5bd1e995
	var spacing := 1.0 / sqrt(density)
	var per_side := ceili(CELL / spacing)
	spacing = CELL / per_side
	var buffer := PackedFloat32Array()
	var low := INF
	var high := -INF
	for row in per_side:
		for column in per_side:
			var local := Vector2(column + rng.randf(), row + rng.randf()) * spacing
			var roll := rng.randf()
			var yaw := rng.randf_range(-PI, PI)
			var size := rng.randf_range(.8, 1.25)
			var variation := rng.randf()
			var thin := rng.randf()
			var fx := local.x / step
			var fz := local.y / step
			var ix := mini(int(fx), LATTICE - 1)
			var iz := mini(int(fz), LATTICE - 1)
			fx -= ix
			fz -= iz
			var a: Vector3 = lattice[iz * (LATTICE + 1) + ix]
			var b: Vector3 = lattice[iz * (LATTICE + 1) + ix + 1]
			var c: Vector3 = lattice[(iz + 1) * (LATTICE + 1) + ix]
			var d: Vector3 = lattice[(iz + 1) * (LATTICE + 1) + ix + 1]
			var cover := a.lerp(b, fx).lerp(c.lerp(d, fx), fz)
			# Beside bare ground (track, water, crop) the sward thins out faster.
			var chance := cover.x * cover.x if minf(minf(a.x, b.x), minf(c.x, d.x)) <= 0.0 else cover.x
			if roll > chance:
				continue
			var p := origin + local
			var y: float = ecology.height(p)
			var tall := .62 * cover.y * size
			var basis := Basis(Vector3.UP, yaw).scaled(Vector3(size, tall, size))
			buffer.append_array([basis.x.x, basis.y.x, basis.z.x, p.x, basis.x.y, basis.y.y, basis.z.y, y - .015,
				basis.x.z, basis.y.z, basis.z.z, p.y,
				clampf(cover.z + (variation - .5) * .3, 0.0, 1.0), lerpf(.8, 1.3, rng.randf()), variation, thin])
			low = minf(low, y)
			high = maxf(high, y)
	var count := buffer.size() / 16
	if count == 0:
		return {}
	# Profiles and distance draw the first N tufts: shuffle so thinning is even.
	var order := range(count)
	for i in range(count - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var swap: int = order[i]
		order[i] = order[j]
		order[j] = swap
	var shuffled := PackedFloat32Array()
	shuffled.resize(buffer.size())
	for i in count:
		var from: int = order[i] * 16
		for k in 16:
			shuffled[i * 16 + k] = buffer[from + k]
	var bounds := AABB(Vector3(origin.x-1.0,low-.3,origin.y-1.0),Vector3(CELL+2.0,high-low+1.8,CELL+2.0))
	var multimesh: MultiMesh
	if Safe.active():
		multimesh = Safe.new_multimesh(Library.grass_mesh("grass_tuft_far"),count,bounds)
		if not Safe.upload(multimesh,shuffled,count):
			return {}
	else:
		multimesh = MultiMesh.new()
		multimesh.transform_format = MultiMesh.TRANSFORM_3D
		multimesh.use_custom_data = true
		multimesh.mesh = Library.grass_mesh("grass_tuft_far")
		multimesh.instance_count = count
		multimesh.buffer = shuffled
		multimesh.custom_aabb = bounds
	var node := MultiMeshInstance3D.new()
	node.name = "Grass_%d_%d" % [key.x, key.y]
	node.multimesh = multimesh
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(node)
	return {"node": node, "count": count, "lod": "far"}
