extends SceneTree
## I-00 must stay presentation-only while exposing deterministic cinematic anchors.

const Stage = preload("res://scripts/cinematic/i00_stage.gd")
const Vexillum = preload("res://scripts/cinematic/i00_vexillum.gd")

var checks := 0
var failures: Array[String] = []


func _initialize() -> void:
	var stage := Stage.new()
	root.add_child(stage)
	stage.ensure_built()
	var ranks: Node3D = stage.get_node_or_null("LegionBlocks")
	_check(ranks != null and ranks._batches.has("spear"),"I-00 uses the shared animated soldier silhouette batch")
	var bodies: MultiMeshInstance3D = ranks._batches.spear
	_check(bodies.multimesh.visible_instance_count == 45 and stage._foreground.size() == 9, "54 formation slots are preserved: 45 far, nine actual near rigs")
	var seen := {}
	var signifers := 0
	for figure in stage._foreground:
		var source: String = figure.active_model_path
		_check(figure.detail == 0 and figure.body != null and figure.animator != null, "Front rank owns a real close-detail animated body")
		_check(source.begins_with("res://assets/characters/frontier_legionary_") or source.begins_with("res://assets/meshy/characters/unit_roman_signifer_"), "Front rank uses the installed military asset, not a civilian or distant proxy")
		var slot: int = figure.get_meta("i00_slot")
		_check(not seen.has(slot), "Front rank slot is unique")
		seen[slot] = true
		if source.contains("unit_roman_signifer"):
			signifers += 1
			_check(figure.body.find_child("MeshyEquipment_gear_roman_signum",true,false) != null, "Meshy signifer has its imported hand-attached signum")
	_check(signifers == 1, "The existing Meshy standard bearer is used once, not as the whole legion")
	_check(stage._standards.size() == 3, "All three stands use woven cloth rather than a solid slab")
	for banner in stage._standards:
		_check(banner.cloth.mesh is ArrayMesh and banner.cloth.mesh.surface_get_array_len(0) > 500, "Cloth has a tessellated deformation surface")
		_check(banner.cloth.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_ON, "The cloth participates in lighting and shadows")
		if OS.get_environment("IMPERATHEN_REQUIRE_I00_VEXILLUM") == "1":
			_check(banner.imported and banner.textile.get_shader_parameter("use_atlas") == true, "Actual Blender GLB and textile atlas are bound")
	var front = stage._standards[0]
	_check(front.global_position.is_equal_approx(stage.anchor("i00_standard")), "Opening shot is anchored to the real standard")
	var rest := Vector3(0,Vexillum.TOP,Vexillum.FRONT)
	_check(Vexillum.displaced(rest,Vector2(.5,0),1.0).is_equal_approx(rest), "The sewn top edge cannot leave the crossbar")
	var hem := Vector3(0,Vexillum.TOP-Vexillum.HEIGHT,Vexillum.FRONT)
	var fold_a := Vexillum.displaced(hem,Vector2(.5,1),0.0)
	var fold_b := Vexillum.displaced(hem,Vector2(.5,1),.6)
	_check(fold_a.distance_to(fold_b) > .005 and fold_a.distance_to(hem) < .20 and fold_b.distance_to(hem) < .20, "Hem moves in a bounded wind fold")
	_check(bodies.multimesh.mesh == ranks.SoldierVisual.far_mesh("spear"),"Cinematic bodies include the authored attached spear and shield")
	var before: float = ranks._last_fraction
	stage._process(1.0/60.0)
	_check(ranks._last_fraction > before,"Cinematic formation advances its measured idle phase")
	stage.hide()
	before = ranks._last_fraction
	stage._process(1.0/60.0)
	_check(ranks._last_fraction == before,"Hidden cinematic formations stop their presentation clock")
	stage.show()
	stage.set_presentation_paused(true)
	var wind_before: float = front.textile.get_shader_parameter("wind_seconds")
	stage._process(.5)
	_check(is_equal_approx(float(front.textile.get_shader_parameter("wind_seconds")),wind_before), "Pause freezes cloth animation")
	stage.set_presentation_paused(false)
	stage._process(.5)
	_check(not is_equal_approx(float(front.textile.get_shader_parameter("wind_seconds")),wind_before), "Resume continues the wind clock")
	var rain := stage.get_node_or_null("Rain") as GPUParticles3D
	_check(rain != null and rain.amount >= 700 and rain.lifetime > 1.0, "The Aquileia cold open owns a real rain layer")
	var caesar := stage.speaker("caesar")
	var labienus := stage.speaker("labienus")
	_check(caesar != null and labienus != null and caesar != labienus, "Caesar and Labienus have separate presentation figures")
	_check(str(caesar.get_parent().get_meta("historical_visual_status", "")) == "placeholder_pending_reference_review", "Caesar preview is explicitly blocked from being mistaken for a reviewed historical likeness")
	_check(str(labienus.get_parent().get_meta("historical_visual_status", "")) == "placeholder_pending_reference_review", "Labienus preview is explicitly blocked from being mistaken for a reviewed historical likeness")
	var anchors := ["i00_standard","i00_legions","i00_caesar","i00_labienus","i00_road"]
	var positions: Array[Vector3] = []
	for key: String in anchors:
		var at: Vector3 = stage.anchor(key)
		_check(at.is_finite(), "Cinematic anchor is finite: " + key)
		positions.append(at)
	_check(positions[1] != positions[2] and positions[2] != positions[3], "Legion and commander compositions use distinct anchors")
	var authority_nodes := stage.find_children("*", "CollisionObject3D", true, false)
	_check(authority_nodes.is_empty(), "I-00 contains no collision, combat or gameplay authority")
	stage.queue_free()
	print("I00_STAGE_RESULT checks=%d failures=%d" % [checks, failures.size()])
	for failure in failures:
		printerr("FAIL: " + failure)
	print("I00_STAGE_PASS" if failures.is_empty() else "I00_STAGE_FAIL")
	quit(0 if failures.is_empty() else 1)


func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)
