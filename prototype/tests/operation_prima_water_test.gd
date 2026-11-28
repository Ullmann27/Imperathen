extends SceneTree
## Exercises the production I-01 water animator against the imported well.
const Water = preload("res://scripts/world/village/i01_water_motion.gd")
const WELL_ASSET := "res://assets/architecture/village_well.glb"

class RegionFixture extends Node3D:
	var water_well: Node3D

class WorldFixture extends Node3D:
	var regional: Node3D

var checks := 0
var failures := 0

func _initialize() -> void:
	_run.call_deferred()

func _check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error("OPERATION_PRIMA_WATER_FAIL: " + label)

func _run() -> void:
	var packed := load(WELL_ASSET) as PackedScene
	_check(packed != null, "Original imported well scene loads")
	if packed == null:
		quit(1)
		return

	var world := WorldFixture.new()
	root.add_child(world)
	var region := RegionFixture.new()
	world.add_child(region)
	world.regional = region
	var first_well := packed.instantiate() as Node3D
	region.add_child(first_well)
	first_well.position = Vector3(-7.0,0.0,6.0)
	first_well.rotation.y = .4
	region.water_well = first_well
	var holder := Node3D.new()
	world.add_child(holder)
	var motion := Water.new()
	motion.setup(holder)
	_check(motion.bind_well(), "Production well parts bind in a translated, rotated village")
	if not motion.bind_well():
		world.free()
		quit(1)
		return

	var camera := Camera3D.new()
	world.add_child(camera)
	camera.make_current()
	await process_frame
	_check(motion._stream_segment_count(2.0) == 8, "Near stream uses full detail")
	_check(motion._stream_segment_count(12.0) == 4, "Mid-distance stream uses half the segments")
	_check(motion._stream_segment_count(25.0) == 2, "Far stream uses two segments")
	_check(motion._stream_segment_count(NAN) == 8, "Invalid camera distance safely selects full detail")

	var start := Vector3(0.0,1.0,-2.0)
	var finish := Vector3(0.0,.2,-2.0)
	motion.water_between(start,finish,1.0)
	_check(_visible_count(motion.stream) == 8, "Near pour draws all stream segments")
	_check(_segment_end(motion.stream[0],-1.0).is_equal_approx(start), "Stream begins at the real spout anchor")
	_check(_segment_end(motion.stream[7],1.0).is_equal_approx(finish), "Stream ends at the real target anchor")

	camera.position = Vector3(0.0,0.0,-14.0)
	motion.water_between(start,finish,1.0)
	_check(_visible_count(motion.stream) == 4, "Camera distance reduces mid-range stream geometry")
	camera.position = Vector3(0.0,0.0,-25.0)
	motion.water_between(start,finish,1.0)
	_check(_visible_count(motion.stream) == 2, "Camera distance reduces far stream geometry")
	motion.water_between(start,finish,Water.STREAM_MIN_STRENGTH)
	_check(_visible_count(motion.stream) == 0, "Existing minimum-flow threshold still clears the stream")
	motion.water_between(start,finish,NAN)
	_check(_visible_count(motion.stream) == 0, "Non-finite flow clears stale stream geometry")
	motion.water_between(start,finish,1.0)
	_check(_visible_count(motion.stream) == 2, "A valid pour re-enters after cancellation without stale segments")
	motion.water_between(finish,start,1.0)
	_check(_visible_count(motion.stream) == 0, "Upward flow is rejected")

	var original_bucket := _save_transforms(motion.parts)
	var original_winding := _save_transforms(motion.winding_parts)
	var original_hanging_visible: bool = motion.hanging.visible
	var bucket_pose := motion.bucket_base()
	bucket_pose.origin += Vector3.UP*.45
	motion.windlass(.45)
	motion.bucket_at(bucket_pose,2.0)
	_check(motion.bucket_surface.visible, "Finite overfill clamps to a visible full-bucket surface")
	_check(motion.bucket_surface.global_position.is_equal_approx(bucket_pose*Vector3(0.0,.26,0.0)), "Water surface stays within the bucket fill range")
	motion.bucket_at(bucket_pose,.5,.45)
	_check(not motion.bucket_surface.visible, "Existing tilt threshold hides the bucket surface")
	motion.bucket_at(bucket_pose,.5,-.45)
	_check(not motion.bucket_surface.visible, "Reverse tilt also hides the bucket surface")
	motion.bucket_at(bucket_pose,.01)
	_check(not motion.bucket_surface.visible, "Existing minimum-fill threshold still hides the surface")
	motion.windlass(NAN)
	_check(_transforms_match(original_bucket) and _transforms_match(original_winding), "Invalid windlass input cancels and restores well parts")
	_check(motion.hanging.visible == original_hanging_visible, "Cancellation restores imported hanging-rope visibility")
	motion.bucket_at(bucket_pose,.8)
	motion.finish()
	_check(_transforms_match(original_bucket) and _transforms_match(original_winding), "Finish restores bucket and winding transforms")
	_check(not motion.rope.visible and not motion.bucket_surface.visible and _visible_count(motion.stream) == 0, "Finish clears every transient water mesh")
	motion.bucket_at(bucket_pose,.8)
	motion.finish()
	_check(_transforms_match(original_bucket) and _transforms_match(original_winding), "Repeated action entry and finish remain reversible")
	motion.bucket_at(bucket_pose,.8)
	motion.bucket_at(Transform3D(Basis.IDENTITY,Vector3(NAN,0.0,0.0)),.5)
	_check(_transforms_match(original_bucket) and _transforms_match(original_winding), "Invalid bucket pose cancels without corrupting source transforms")

	var second_well := packed.instantiate() as Node3D
	region.add_child(second_well)
	second_well.position = Vector3(4.0,0.0,-3.0)
	second_well.rotation.y = -.7
	var second_bucket_before: Dictionary = {}
	var second_winding_before: Dictionary = {}
	motion.bucket_at(bucket_pose,.7)
	region.water_well = second_well
	_check(motion.bind_well(), "Re-entry binds a replacement imported well")
	_check(_transforms_match(original_bucket) and _transforms_match(original_winding), "Rebinding restores the previous well before switching")
	second_bucket_before = _save_transforms(motion.parts)
	second_winding_before = _save_transforms(motion.winding_parts)
	motion.bucket_at(motion.bucket_base(),.7)
	motion.finish()
	_check(_snapshot_matches(second_bucket_before) and _snapshot_matches(second_winding_before), "Replacement well returns to its own imported rest pose")

	world.free()
	if failures == 0:
		print("OPERATION_PRIMA_WATER_PASS: %d checks" % checks)
	else:
		push_error("OPERATION_PRIMA_WATER_FAIL: %d of %d checks failed" % [failures,checks])
	quit(1 if failures > 0 else 0)

func _visible_count(items: Array[MeshInstance3D]) -> int:
	var count := 0
	for item: MeshInstance3D in items:
		if is_instance_valid(item) and item.visible:
			count += 1
	return count

func _segment_end(segment: MeshInstance3D, sign: float) -> Vector3:
	return segment.global_position + segment.global_transform.basis.y*(sign*.5)

func _save_transforms(parts: Array[Dictionary]) -> Dictionary:
	var snapshot: Dictionary = {}
	for part: Dictionary in parts:
		var node: Node3D = part.node
		snapshot[node] = node.transform
	return snapshot

func _transforms_match(snapshot: Dictionary) -> bool:
	return _snapshot_matches(snapshot)

func _snapshot_matches(snapshot: Dictionary) -> bool:
	for node_variant: Variant in snapshot:
		var node := node_variant as Node3D
		if not is_instance_valid(node):
			return false
		var expected: Transform3D = snapshot[node_variant]
		if not node.transform.is_equal_approx(expected):
			return false
	return true
