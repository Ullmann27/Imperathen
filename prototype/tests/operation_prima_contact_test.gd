extends SceneTree

const Person := preload("res://scripts/visuals/village_person.gd")

var checks := 0
var failures: Array[String] = []


func _initialize() -> void:
	_run.call_deferred()


func _check(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failures.append(label)


func _run() -> void:
	var stage := Node3D.new()
	root.add_child(stage)
	var actor := Person.new()
	stage.add_child(actor)
	actor.set_process(false)
	actor.configure("player", "italia", 18)
	await process_frame
	_check(actor.body != null, "Production adult actor rig loads")
	if actor.body == null:
		await _finish(stage)
		return
	var piece := {
		"slot": "main_hand",
		"item_id": "gladius",
		"quality": 3,
		"wear": 0.0,
		"model": "weap_roman_gladius_pompeii",
		"model_dir": "equipment",
		"lods": 3,
		"attach": "hand_right"
	}
	actor.set_market_gear([piece])
	await process_frame
	_assert_contact(actor._market_nodes, "_0.glb")
	actor._reload(1)
	await process_frame
	_assert_contact(actor._market_nodes, "_1.glb")
	actor._reload(3)
	await process_frame
	_assert_contact(actor._market_nodes, "_2.glb")
	actor.set_market_gear([])
	_check(actor._market_nodes.is_empty(), "Unequipping clears the shared visual attachment")
	await _finish(stage)


func _assert_contact(attachments: Array[Node3D], expected_lod: String) -> void:
	_check(attachments.size() == 1, "One real gladius attaches at " + expected_lod)
	if attachments.size() != 1:
		return
	var attachment := attachments[0] as BoneAttachment3D
	var grip := attachment.find_child("Grip", true, false) as Node3D
	var prop := attachment.find_child("Prop", true, false) as Node3D
	var socket := prop.find_child("SOCKET_RIGHT_HAND", true, false) as Node3D if prop != null else null
	_check(grip != null and socket != null, "Grip and authored hand socket survive at " + expected_lod)
	_check(str(attachment.get_meta("model_path", "")).ends_with(expected_lod), "Expected production item LOD is selected: " + expected_lod)
	if grip == null or socket == null:
		return
	var contact := grip.global_transform.affine_inverse() * socket.global_transform
	var basis_error := (contact.basis.x - Vector3.RIGHT).length() + (contact.basis.y - Vector3.UP).length() + (contact.basis.z - Vector3(0.0, 0.0, 1.0)).length()
	_check(contact.origin.length() < 0.001, "Authored socket origin resolves exactly to the grip at " + expected_lod)
	_check(basis_error < 0.003, "Authored socket rotation resolves exactly to the grip at " + expected_lod)


func _finish(stage: Node3D) -> void:
	stage.queue_free()
	await process_frame
	for failure: String in failures:
		push_error(failure)
	print("OPERATION_PRIMA_CONTACT_RESULT checks=%d failures=%d" % [checks, failures.size()])
	quit(1 if not failures.is_empty() else 0)
