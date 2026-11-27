extends SceneTree
## Tests the real imported Blender asset and production I-01 animator,
## independently of the full mission and of expensive graphical captures.
const Water = preload("res://scripts/world/village/i01_water_motion.gd")
const ASSET = "res://assets/architecture/village_well.glb"

class RegionFixture extends Node3D:
	var water_well: Node3D

class WorldFixture extends Node3D:
	var regional: Node3D

var failures := 0
var checks := 0

func _initialize() -> void:
	_run.call_deferred()

func _check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error("I01_WELL_ASSET_FAIL: " + label)

func _run() -> void:
	var scene := load(ASSET) as PackedScene
	_check(scene != null, "Original imported GLB loads as PackedScene")
	if scene == null:
		quit(1)
		return
	var world := WorldFixture.new()
	root.add_child(world)
	var region := RegionFixture.new()
	world.add_child(region)
	world.regional = region
	var first := scene.instantiate() as Node3D
	region.add_child(first)
	first.position = Vector3(-7, 0, 6)
	first.rotation.y = 0.4
	region.water_well = first
	var holder := Node3D.new()
	world.add_child(holder)
	var motion := Water.new()
	motion.setup(holder)
	_check(motion.bind_well(), "All independently animated original mesh nodes are bound")
	if not motion.bind_well():
		world.free()
		quit(1)
		return
	_check(motion.parts.size() == Water.BUCKET_PARTS.size(), "Every bucket component has a separate transform")
	var original_bucket: Dictionary = {}
	var original_winding: Dictionary = {}
	for part: Dictionary in motion.parts:
		var node: Node3D = part.node
		original_bucket[node] = node.transform
		_check(node is MeshInstance3D, "Actual imported bucket mesh: " + str(node.name))
	for part: Dictionary in motion.winding_parts:
		var node: Node3D = part.node
		original_winding[node] = node.transform
		_check(node is MeshInstance3D, "Actual imported winding mesh: " + str(node.name))
	_check(motion.hanging is MeshInstance3D and motion.crank is MeshInstance3D, "Imported rope and crank are not placeholder nodes")
	var original_rope: bool = motion.hanging.visible
	var lift := Vector3(0, 0.45, 0)
	var rest: Transform3D = motion.bucket_base()
	var pose := rest
	pose.origin += lift
	var before_global: Dictionary = {}
	for node: Node3D in original_bucket:
		before_global[node] = node.global_position
	_check(motion.windlass(0.45).is_finite(), "Crank returns a finite world-space contact")
	motion.bucket_at(pose, 0.75)
	for node: Node3D in before_global:
		var before: Vector3 = before_global[node]
		_check(node.global_position.is_equal_approx(before + lift), "Bucket mesh follows exact lift: " + str(node.name))
	var changed := false
	for node: Node3D in original_winding:
		if not node.transform.is_equal_approx(original_winding[node]):
			changed = true
	_check(changed, "The original winding assembly rotates")
	_check(motion.rope.visible and not motion.hanging.visible, "Only the animated rope is visible during the lift")
	_check(motion.bucket_surface.visible, "Bucket fill surface visible")
	var start := pose * Water.BUCKET_LIP + Vector3.UP
	var end := start + Vector3(0.25, -0.5, 0)
	motion.water_between(start, end, 1.0)
	_check(motion.stream[0].visible and motion.stream[-1].visible, "Water stream has visible geometry")
	motion.finish()
	for node: Node3D in original_bucket:
		_check(node.transform.is_equal_approx(original_bucket[node]), "Bucket restored: " + str(node.name))
	for node: Node3D in original_winding:
		_check(node.transform.is_equal_approx(original_winding[node]), "Winding restored: " + str(node.name))
	_check(motion.hanging.visible == original_rope and not motion.rope.visible and not motion.bucket_surface.visible, "Original rope restored and transient meshes hidden")
	for segment: MeshInstance3D in motion.stream:
		_check(not segment.visible, "Transient stream cleared")
	# The original node can survive briefly when a new origin is streamed in.
	motion.windlass(0.3)
	motion.bucket_at(pose, 1.0)
	var second := scene.instantiate() as Node3D
	region.add_child(second)
	second.position = Vector3(13, 0, 8)
	region.water_well = second
	_check(motion.bind_well() and motion.well == second, "Rebind selects the current real well instance")
	for node: Node3D in original_bucket:
		_check(node.transform.is_equal_approx(original_bucket[node]), "Old streamed bucket restored: " + str(node.name))
	for node: Node3D in original_winding:
		_check(node.transform.is_equal_approx(original_winding[node]), "Old streamed winding restored: " + str(node.name))
	motion.finish()
	world.free()
	print(("I01_WELL_ASSET_PASS" if failures == 0 else "I01_WELL_ASSET_FAILED") + " checks=%d failures=%d" % [checks, failures])
	quit(0 if failures == 0 else 1)
