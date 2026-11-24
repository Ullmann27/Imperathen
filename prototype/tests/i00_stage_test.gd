extends SceneTree
## I-00 must stay presentation-only while exposing deterministic cinematic anchors.

const Stage = preload("res://scripts/cinematic/i00_stage.gd")

var checks := 0
var failures: Array[String] = []


func _initialize() -> void:
	var stage := Stage.new()
	root.add_child(stage)
	stage.ensure_built()
	var ranks: Node3D = stage.get_node_or_null("LegionBlocks")
	_check(ranks != null and ranks._batches.has("spear"),"I-00 uses the shared animated soldier silhouette batch")
	var bodies: MultiMeshInstance3D = ranks._batches.spear
	_check(bodies.multimesh.visible_instance_count == 54,"Three distant formations contain54 actual soldier silhouettes")
	_check(bodies.multimesh.mesh == ranks.SoldierVisual.far_mesh("spear"),"Cinematic bodies include the authored attached spear and shield")
	var before: float = ranks._last_fraction
	stage._process(1.0/60.0)
	_check(ranks._last_fraction > before,"Cinematic formation advances its measured idle phase")
	stage.hide()
	before = ranks._last_fraction
	stage._process(1.0/60.0)
	_check(ranks._last_fraction == before,"Hidden cinematic formations stop their presentation clock")
	stage.show()
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
