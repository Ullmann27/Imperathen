extends SceneTree
## Inspect the installed production assets, not a proxy head or a concept image.
const Person := preload("res://scripts/visuals/village_person.gd")
var failures := 0
var checks := 0

func _initialize() -> void:
	_run.call_deferred()

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)

func _run() -> void:
	var require_morphs := OS.get_environment("IMPERATHEN_REQUIRE_PARENT_MORPHS") == "1"
	for id: String in ["julia", "silvanus"]:
		var female := id == "julia"
		var actor := Person.new()
		root.add_child(actor)
		actor.set_process(false)
		actor.configure_resident("italia", 36 if female else 40, "civilian_woman" if female else "civilian_man", 0, null, "vil:" + id)
		for level in 4:
			actor._reload(level)
			check(actor.body != null and actor.detail == level and actor.resident_id == id, id + " retains its real identity and LOD")
			if actor.body == null:
				continue
			if require_morphs:
				check(actor.active_model_path == Person.PARENT_PATH % [id,level], id + " uses dedicated parent model rather than generic civilian")
			var body := actor.body.find_child("HeroBody", true, false) as MeshInstance3D
			check(body != null and body.mesh != null, id + " real skinned body exists")
			if body == null or body.mesh == null:
				continue
			var skin := body.get_active_material(0) as ShaderMaterial
			check(skin != null, id + " actual age-aware skin shader at LOD " + str(level))
			if skin:
				check(is_equal_approx(float(skin.get_shader_parameter("age")), float(actor.look.skin.age)), id + " visible age parameter comes from named identity")
				check(skin.get_shader_parameter("identity_mask") != null and skin.get_shader_parameter("identity_detail") != null, id + " has actual crease textures")
			var age_slot := body.find_blend_shape_by_name("ID_Age")
			if level < 2:
				if require_morphs:
					check(age_slot >= 0, id + " rebuilt near model has real age geometry")
				if age_slot >= 0:
					check(is_equal_approx(body.get_blend_shape_value(age_slot), float(actor.look.face.ID_Age)), id + " age morph is applied to actual vertices")
			print("PARENT_MODEL ", id, " LOD=", level, " path=", actor.active_model_path, " age_morph=", age_slot >= 0)
		actor.free()
	print("PARENT_VISUAL_CONTRACT_PASS" if failures == 0 else "PARENT_VISUAL_CONTRACT_FAIL", " checks=", checks, " failures=", failures)
	quit(0 if failures == 0 else 1)
