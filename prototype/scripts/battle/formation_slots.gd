extends RefCounted

const NAMES := {
	"line": "Linie", "column": "Marschkolonne", "shield_wall": "Schildwall",
	"testudo": "Schilddach / Testudo", "wedge": "Keil", "loose": "Lockere Ordnung",
	"phalanx": "Speerformation / Phalanx",
}
## Formed in place and facing every way; not drawn along a front (Caes. Gall. 4,37; 5,33).
const ALL_ROUND := {"orbis": "Kreis / Orbis"}
const ORBIS_SPACING := 0.9
const ORBIS_DEPTH := 1.0


static func natural_columns(shape: String, count: int) -> int:
	match shape:
		"column": return 2
		"line": return ceili(count * 0.75)
		"shield_wall": return ceili(count * 0.6)
		_: return ceili(sqrt(count))


## Rank spacing front to back. Casualty selection groups soldiers by this depth.
static func rank_depth(shape: String) -> float:
	match shape:
		"loose": return 1.55
		"shield_wall", "testudo": return 0.8
		"phalanx": return 1.28
	return 1.05


static func offsets(shape: String, count: int, width: float) -> Array[Vector2]:
	return layout(shape, count, width).offsets


## Rank of every slot: 0 is the front rank (towards the facing), rising to the rear.
static func ranks(shape: String, count: int, width: float) -> Array[int]:
	return layout(shape, count, width).ranks


static func layout(shape: String, count: int, width: float) -> Dictionary:
	var result: Array[Vector2] = []
	var rank_of: Array[int] = []
	if count == 0:
		return {"offsets": result, "ranks": rank_of}
	if shape == "orbis":
		return _orbis(count)
	var spacing := 0.95
	var depth := 1.05
	match shape:
		"loose":
			spacing = 1.65
			depth = 1.55
		"shield_wall", "testudo":
			spacing = 0.77
			depth = 0.8
		"phalanx":
			spacing = 0.89
			depth = 1.28
	var columns := natural_columns(shape, count)
	if width > 0.0:
		columns = clampi(roundi(width / spacing) + 1, 1, count)
		match shape:
			"column":
				columns = mini(columns, maxi(2, ceili(count * 0.25)))
			"testudo", "wedge":
				columns = mini(columns, ceili(sqrt(count)))
			"shield_wall", "phalanx":
				columns = mini(columns, ceili(count * 0.6))
		spacing = minf(spacing * 1.4, width / maxi(1, columns - 1))
	var i := 0
	var row := 0
	var center := Vector2.ZERO
	while i < count:
		var n := mini(columns, count - i)
		if shape == "wedge":
			n = mini(mini(row + 1, columns), count - i)
		for j in range(n):
			var slot := Vector2((j - (n - 1) * 0.5) * spacing, row * depth)
			if shape == "loose" and row % 2 == 1:
				slot.x += spacing * 0.42
			result.append(slot)
			rank_of.append(row)
			center += slot
		i += n
		row += 1
	center /= float(count)
	for k in range(count):
		result[k] -= center
	return {"offsets": result, "ranks": rank_of}


static func world_slots(shape: String, count: int, width: float, center: Vector2, facing: float) -> Array[Vector2]:
	var points := offsets(shape, count, width)
	for i in range(points.size()):
		points[i] = center + points[i].rotated(-facing)
	return points


## Concentric rings, outer ring first (rank 0), about ORBIS_SPACING apart along each ring.
## Slot 0 of every ring points to the local front (-Y).
static func _orbis(count: int) -> Dictionary:
	var result: Array[Vector2] = []
	var rank_of: Array[int] = []
	var rings := maxi(1, ceili(count / 40.0))
	var outer := maxf(1.2 + (rings - 1) * ORBIS_DEPTH, (count * ORBIS_SPACING / TAU + rings * (rings - 1) * 0.5 * ORBIS_DEPTH) / rings)
	var radii := []
	var total := 0.0
	for k in range(rings):
		radii.append(outer - k * ORBIS_DEPTH)
		total += radii[k]
	var left := count
	for k in range(rings):
		var n := left if k == rings - 1 else clampi(roundi(count * radii[k] / total), 1, left - (rings - 1 - k))
		for j in range(n):
			var angle := TAU * j / n
			result.append(Vector2(sin(angle), -cos(angle)) * radii[k])
			rank_of.append(k)
		left -= n
	return {"offsets": result, "ranks": rank_of}


static func ring_radius(count: int) -> float:
	var points: Array = _orbis(count).offsets
	return 0.0 if points.is_empty() else points[0].length()
