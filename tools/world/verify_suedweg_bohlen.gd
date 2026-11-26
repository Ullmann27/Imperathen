extends SceneTree
## Import the model and verify the physical clue independently of the story.

const EVIDENCE := preload("res://assets/politics/suedweg/suedweg_bohlen.glb")
const STOCK := preload("res://assets/politics/suedweg/suedweg_ersatzbohlen.glb")
var checks := 0
var failures := 0


func _initialize() -> void:
	_run.call_deferred()


func _check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("SUEDWEG_MODEL_FAIL " + label)


func _run() -> void:
	var evidence := EVIDENCE.instantiate() as Node3D
	var replacement := STOCK.instantiate() as Node3D
	root.add_child(evidence)
	root.add_child(replacement)
	_check(evidence.find_children("*", "MeshInstance3D",true,false).size() == 4,
		"three timber boards and a separate eroded bed")
	_check(evidence.find_children("*","CollisionObject3D",true,false).is_empty()
		and replacement.find_children("*","CollisionObject3D",true,false).is_empty(),
		"all parts are decorative geometry with no obstruction")
	var fallen := evidence.find_child("Bohle_Abgesackt") as MeshInstance3D
	_check(fallen != null, "damaged plank has a stable scene name")
	if fallen != null:
		var board: Array = fallen.mesh.surface_get_arrays(0)
		var source: PackedVector3Array = board[Mesh.ARRAY_VERTEX]
		var near_end := -1.0
		var far_end := -1.0
		for p: Vector3 in source:
			if p.x < -.58:
				near_end = maxf(near_end,p.y)
			if p.x > .61:
				far_end = maxf(far_end,p.y)
		_check(near_end - far_end > .090 and near_end - far_end < .128,
			"visible timber end drops approximately 11 cm")
		var mat := fallen.get_active_material(0) as StandardMaterial3D
		_check(mat != null and mat.albedo_texture != null and mat.normal_texture != null,
			"original wood material is embedded")
	_check(replacement.find_child("Suedweg_Ersatzbohlen") is MeshInstance3D,
		"replacement stock is a separate, independently visible asset")
	if "--capture" in OS.get_cmdline_user_args() and DisplayServer.get_name() != "headless":
		await _capture(replacement)
	print("SUEDWEG_MODEL_%s checks=%d failures=%d" % ["PASS" if failures == 0 else "FAIL",checks,failures])
	quit(0 if failures == 0 else 1)


func _capture(stock: Node3D) -> void:
	stock.position.z = 1.08
	var ground := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(18,18)
	ground.mesh = plane
	var earth := StandardMaterial3D.new()
	earth.albedo_color = Color("#8c7556")
	ground.material_override = earth
	root.add_child(ground)
	var camera := Camera3D.new()
	root.add_child(camera)
	camera.fov = 43
	camera.current = true
	camera.position = Vector3(2.12,1.18,1.51)
	camera.look_at(Vector3(.02,.09,.47))
	var sun := DirectionalLight3D.new()
	root.add_child(sun)
	sun.rotation_degrees = Vector3(-49,-36,0)
	sun.light_energy = .98
	sun.shadow_enabled = true
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color("#a5b5ba")
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_energy = .59
	camera.environment = environment
	for i in range(3):
		await RenderingServer.frame_post_draw
	var capture := root.get_texture().get_image()
	_check(capture.save_png("/tmp/valdora-suedweg-bohlen.png") == OK, "local Godot shot written")
