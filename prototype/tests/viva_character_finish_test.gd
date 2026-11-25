extends SceneTree
const Detail := preload("res://scripts/rendering/city_character_detail.gd")
var failures := 0
func _initialize() -> void:
	call_deferred("_check")
func expect(value: bool, msg: String) -> void:
	if not value:
		failures += 1
		printerr(msg)
func _check() -> void:
	var image := Image.create(8,8,false,Image.FORMAT_RGBA8)
	image.fill(Color(0.51,0.48,1.0))
	var original_normal := ImageTexture.create_from_image(image)
	var rough := ImageTexture.create_from_image(image)
	for name: String in Detail.KNOWN:
		var mat := StandardMaterial3D.new()
		mat.resource_name = name
		mat.albedo_color = Color(0.5,0.3,0.2,0.6)
		mat.normal_enabled = true
		mat.normal_texture = original_normal
		mat.roughness_texture = rough
		mat.normal_scale = 0.39
		var mesh := PlaneMesh.new()
		mesh.material = mat
		var node := MeshInstance3D.new()
		node.mesh = mesh
		expect(Detail.apply_to(node,"very_high",0)==1,"missing detail: "+name)
		var detail := node.get_active_material(0) as StandardMaterial3D
		expect(detail != mat and detail.normal_texture==original_normal and detail.roughness_texture==rough,"original maps lost: "+name)
		expect(is_equal_approx(detail.normal_scale,0.39) and detail.albedo_color==mat.albedo_color,"original identity lost: "+name)
		expect(Detail.apply_to(node,"low",0)==1 and node.get_active_material(0)==mat,"restore failed: "+name)
		node.free()
	print("VIVA_CHARACTER_FINISH_" + ("PASS" if failures==0 else "FAIL"))
	quit(0 if failures==0 else 1)
