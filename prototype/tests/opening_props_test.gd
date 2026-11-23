extends SceneTree

const Props = preload("res://scripts/world/village/opening_props.gd")
const Model = preload("res://scripts/domain/world_model.gd")
var failures := 0
var checks := 0


func _initialize() -> void:
	if OS.get_environment("IMPERATHEN_ISOLATED_TEST") != "1":
		printerr("Use disposable XDG_DATA_HOME and IMPERATHEN_ISOLATED_TEST=1.")
		quit(2)
		return
	_run.call_deferred()


func _check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("FAIL ",message)


func _run() -> void:
	var model = Model.new()
	var view = Props.new()
	root.add_child(view)
	view.sync_state(model.data)
	var before := JSON.stringify(model.data)
	var broken: MeshInstance3D = view.get_child(0)
	_check(view.position == Vector3(-7,0,6) and broken.name == "BrokenSideBrace", "Unchosen Roman arrival shows the broken brace at the actual well")
	_geometry(broken)
	view.sync_state(model.data)
	_check(view.get_child(0) == broken and JSON.stringify(model.data) == before, "Repeated sync retains geometry without mutating campaign state")
	model.set_player_position(Vector3(-3,1,4))
	_check(not model.execute("choose_companion",{"choice":"help"}).ok, "Unfunded help is rejected by the real domain command")
	view.sync_state(model.data)
	_check(view.get_child(0) == broken, "An unsuccessful help attempt cannot repair the visible brace")
	model.set_player_position(Vector3(-8,1,2))
	_check(model.execute("gather",{"node_id":"timber_0"}).ok, "The player collects actual wood")
	model.set_player_position(Vector3(-3,1,4))
	_check(model.execute("choose_companion",{"choice":"help"}).ok, "The actual paid companion decision succeeds")
	view.sync_state(model.data)
	var repaired: MeshInstance3D = view.get_child(0)
	_check(repaired.name == "RepairedSideBrace" and model.data.resources.wood == 0, "Only confirmed help shows the repaired side brace")
	_geometry(repaired)
	var repaired_bounds := repaired.mesh.get_aabb()
	view.sync_state(model.data)
	_check(view.get_child(0) == repaired, "Regular state refresh does not rebuild the repaired mesh")
	var path := "user://opening_props_%s.json" % Time.get_ticks_usec()
	_check(model.save_game(path).ok, "The authoritative repaired choice saves")
	var restored = Model.new()
	_check(restored.load_game(path).ok, "The authoritative choice loads")
	var restored_view = Props.new()
	root.add_child(restored_view)
	restored_view.sync_state(restored.data)
	var restored_mesh: MeshInstance3D = restored_view.get_child(0)
	_check(restored_mesh.name == repaired.name and restored_mesh.mesh.get_aabb() == repaired_bounds and restored_mesh.get_meta("triangle_count") == repaired.get_meta("triangle_count"), "Loading the same decision reconstructs identical repair geometry")
	var declined = Model.new()
	declined.set_player_position(Vector3(-3,1,4))
	_check(declined.execute("choose_companion",{"choice":"decline"}).ok, "The genuine decline route remains available")
	view.sync_state(declined.data)
	_check(view.get_child(0).name == "BrokenSideBrace", "Declining keeps the brace broken without blocking the route")
	for origin in ["germania","han","wa","vistula"]:
		var other = Model.new()
		other.new_game(origin)
		view.sync_state(other.data)
		_check(not view.visible and view.get_child_count() == 0, "No Roman repair prop is shown for " + origin)
	view.sync_state(restored.data)
	_check(view.visible and view.get_child(0).name == "RepairedSideBrace", "Returning to a saved Roman life reconstructs its own repair")
	for candidate in [path,path+".bak",path+".tmp"]:
		if FileAccess.file_exists(candidate):
			DirAccess.remove_absolute(candidate)
	view.queue_free()
	restored_view.queue_free()
	await process_frame
	print("OPENING_PROPS_RESULT checks=%d failures=%d" % [checks,failures])
	quit(1 if failures else 0)


func _geometry(node: MeshInstance3D) -> void:
	var mesh: ArrayMesh = node.mesh
	var triangles := 0
	for surface in mesh.get_surface_count():
		var arrays := mesh.surface_get_arrays(surface)
		triangles += (arrays[Mesh.ARRAY_INDEX].size() if arrays[Mesh.ARRAY_INDEX] != null and not arrays[Mesh.ARRAY_INDEX].is_empty() else arrays[Mesh.ARRAY_VERTEX].size())/3
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
		var facing_valid := true
		for triangle in vertices.size()/3:
			var first := triangle*3
			var cross_normal := (vertices[first+1]-vertices[first]).cross(vertices[first+2]-vertices[first])
			facing_valid = facing_valid and cross_normal.dot(normals[first]) < -0.000000001
		_check(facing_valid, "All generated faces use Godot front-face winding with consistent normals")
		var material := mesh.surface_get_material(surface) as StandardMaterial3D
		_check(material != null and material.albedo_texture != null and material.normal_texture != null and material.roughness_texture != null, "Each brace surface uses existing PBR textures")
	_check(mesh.get_surface_count() <= 3 and triangles > 0 and triangles < 4000, "Bounded mobile mesh: %d triangles and %d material surfaces" % [triangles,mesh.get_surface_count()])
	_check(node.find_children("*","CollisionObject3D",true,false).is_empty() and node.find_children("*","CollisionShape3D",true,false).is_empty(), "Decorative consequence adds no physics or interaction")
	var bounds := mesh.get_aabb()
	_check(bounds.position.x > 1.0 and bounds.end.y < 1.8 and bounds.size.x < 1.3 and bounds.size.z < 1.2, "Metre-scale side detail remains outside the well ring and below the roof: " + str(bounds))
