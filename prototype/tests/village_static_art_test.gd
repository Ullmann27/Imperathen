extends SceneTree
const Art = preload("res://scripts/world/village_art.gd")
const Dressing = preload("res://scripts/world/village/frontier_dressing.gd")
var failures := 0
var checks := 0

func _initialize() -> void:
	run.call_deferred()

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)

func run() -> void:
	var fixture := Node3D.new()
	root.add_child(fixture)
	fixture.position = Vector3(7, 2, -5)
	fixture.rotation.y = .4
	var paint := Art.material(Color("a57642"))
	var isolated_paint := Art.material(Color("a57642"))
	isolated_paint.albedo_color = Color.RED
	check(paint.albedo_color!=isolated_paint.albedo_color, "Mutable material factories remain independent")
	var first := Art.box(fixture, Vector3.ONE, Vector3.ZERO, paint)
	var nested := Node3D.new()
	nested.position = Vector3(2, .4, 1)
	nested.rotation.y = .7
	fixture.add_child(nested)
	var second := Art.box(nested, Vector3.ONE, Vector3(.4, 0, -.2), paint)
	second.rotation.z = .3
	var expected := [first.global_transform, second.global_transform]
	var prepared := [Art._relative_transform(first, fixture), Art._relative_transform(second, fixture)]
	check(first.mesh==second.mesh, "Identical primitives reuse actual immutable mesh resources")
	var solid := Art.box(fixture, Vector3.ONE, Vector3(4,0,0), paint, true)
	var live := Art.box(fixture, Vector3.ONE, Vector3(-4,0,0), paint)
	var shape := solid.find_child("*", true, false)
	var before_colliders := fixture.find_children("*", "CollisionShape3D", true, false)
	var result := Art.batch_static(fixture, [live])
	check(result.replaced_mesh_nodes==2 and result.multimesh_nodes==1, "Only eligible static leaves are batched")
	check(is_instance_valid(solid) and is_instance_valid(live) and is_instance_valid(shape), "Collision-bearing and explicitly live mesh nodes remain addressable")
	check(fixture.find_children("*", "CollisionShape3D", true, false)==before_colliders, "Batching preserves the exact collision objects")
	var batch := fixture.find_children("*", "MultiMeshInstance3D", true, false)[0] as MultiMeshInstance3D
	for index in 2:
		# Godot's dummy renderer returns identity for every MultiMesh transform;
		# verify CPU submission geometry here, plus uploaded poses on a real renderer.
		var local: Transform3D = prepared[index] if DisplayServer.get_name()=="headless" else batch.multimesh.get_instance_transform(index)
		var actual := batch.global_transform*local
		check(actual.is_equal_approx(expected[index]), "Nested authored transform preserved for instance %d: %s == %s" % [index, actual, expected[index]])
		var bounds: AABB = local*batch.multimesh.mesh.get_aabb()
		check(batch.multimesh.custom_aabb.encloses(bounds) or batch.multimesh.custom_aabb.is_equal_approx(bounds), "Batch bounds include authored instance %d" % index)
	live.material_override = isolated_paint
	check(batch.material_override==paint, "Changing the live repair mesh cannot recolour a static batch")
	var dressing := Dressing.new()
	root.add_child(dressing)
	dressing.build()
	var axle := dressing._wagon_axle
	dressing.set_wagon_progress(0)
	var unfinished := axle.material_override
	dressing.set_wagon_progress(1)
	check(is_instance_valid(axle) and axle.material_override!=unfinished, "Actual supply-wagon repair cue survives batching")
	check(dressing.find_children("*", "CollisionShape3D", true, false).size()==8, "All eight authored frontier collision shapes remain")
	for profile: String in ["low", "balanced", "high", "very_high"]:
		dressing.set_quality(profile)
		var expected_range := float({"low":24,"balanced":42,"high":65,"very_high":90}[profile])
		var correct := true
		var batches := 0
		for group: Node3D in dressing._detail_nodes:
			for item: GeometryInstance3D in group.find_children("*", "GeometryInstance3D", true, false):
				correct = correct and is_equal_approx(item.visibility_range_end, expected_range)
				if item is MultiMeshInstance3D: batches += 1
		check(correct and batches>0, profile+" culling reaches compact MultiMesh details")
	for index in 160:
		Art._box_mesh(Vector3(1000+index, .1, .2))
		Art._cylinder_mesh(1000+index, .1, .2)
		Art._sphere_mesh(1000+index)
	check(Art._boxes.size()<=128 and Art._cylinders.size()<=128 and Art._spheres.size()<=128, "Procedural variation cannot grow primitive caches without bound")
	fixture.free()
	dressing.free()
	print("VILLAGE_STATIC_ART_TEST ",checks," checks, ",failures," failed")
	quit(0 if failures==0 else 1)
