extends SceneTree
## Real village labels and camera positions: no near-plane text or modal overlap.

const World = preload("res://scripts/world/game_world.gd")
const Model = preload("res://scripts/domain/world_model.gd")
var failures: Array[String] = []
var checks := 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	root.size = Vector2i(1280, 720)
	var model := Model.new()
	model.new_game("italia", true)
	var world := World.new()
	root.add_child(world)
	world.setup(model.data)
	world.set_active(true)
	world.set_physics_process(false)
	world._update_camera(1.0)
	await process_frame
	var village: Node3D = world.village_life_world
	var camera: Camera3D = world._camera
	var label := village.actors.decimus.get_node("Nameplate") as Label3D
	_check(village.actors.size() == 15, "The test uses the actual inhabited village")
	for actor: Node3D in village.actors.values():
		var plate := actor.get_node("Nameplate") as Label3D
		if plate.visible:
			_check(_projected_width(camera, plate) < root.size.x * 0.42, "Starting nameplate fits in the view: " + actor.name)
	# Preserve the authored label and move only the test camera. A radial range
	# of three metres would admit this label despite its very small view depth.
	camera.global_transform = Transform3D(Basis.IDENTITY, label.global_position + Vector3(-3.5, 0, 0.2))
	village._update_nameplates()
	_check(not label.visible, "A label beside the near plane never stretches across the screen")
	camera.global_transform = Transform3D(Basis.IDENTITY, label.global_position + Vector3(0, 0, 0.2))
	village._update_nameplates()
	_check(not label.visible, "A label directly next to the camera remains hidden")
	camera.global_transform = Transform3D(Basis.IDENTITY, label.global_position + Vector3(0, 0, -4.0))
	village._update_nameplates()
	_check(not label.visible, "A label behind the camera remains hidden")
	camera.global_transform = Transform3D(Basis.IDENTITY, label.global_position + Vector3(0, 0, 4.0))
	village._update_nameplates()
	_check(label.visible, "An unobstructed readable nameplate remains available")
	_check(_projected_width(camera, label) < root.size.x * 0.42, "The readable label occupies less than half the view")
	camera.global_transform = Transform3D(Basis.IDENTITY, label.global_position + Vector3(0, 0, 8.0))
	village._update_nameplates()
	_check(not label.visible, "Distant inhabitants do not cover the village with labels")
	world.get_node("Player").position = village.actor_position("decimus") + Vector3(0, 1, 0.5)
	world.focus_village_npc("decimus")
	world._update_camera(1.0)
	village._update_nameplates()
	_check(_all_labels_hidden(village), "Conversation title is not repeated over the speaker")
	world.clear_frontier_focus()
	camera.global_transform = Transform3D(Basis.IDENTITY, label.global_position + Vector3(0, 0, 4.0))
	world.set_active(false)
	_check(_all_labels_hidden(village), "Paused and modal screens hide world nameplates")
	world.set_active(true)
	village._update_nameplates()
	_check(label.visible, "Returning to play restores a readable resident label")
	# The older authored population also appears on the continuous atrium route.
	# Its names must obey the same camera-depth rule as the newer village people.
	var population: Node3D = world.population
	var cassian: Node3D = population.actors.cassian
	var legacy_label := cassian.get_node("Nameplate") as Label3D
	for offset: Vector3 in [Vector3(-3.5, 0, 0.2), Vector3(0, 0, 0.2), Vector3(0, 0, -4.0)]:
		camera.global_transform = Transform3D(Basis.IDENTITY, legacy_label.global_position + offset)
		population.update_nearby(cassian.global_position, true)
		_check(not legacy_label.visible, "Atrium resident label stays hidden beside, near or behind the camera: " + str(offset))
	camera.global_transform = Transform3D(Basis.IDENTITY, legacy_label.global_position + Vector3(0, 0, 4.0))
	population.update_nearby(cassian.global_position, true)
	_check(legacy_label.visible and _projected_width(camera, legacy_label) < root.size.x * 0.42, "The actual Cassian label remains readable without covering the atrium entrance")
	population.update_nearby(cassian.global_position, false)
	_check(not legacy_label.visible, "Hiding world labels also hides the authored population")
	population.update_nearby(cassian.global_position, true)
	population.set_active(false)
	_check(not legacy_label.visible, "Pausing immediately hides the authored population label")
	world.free()
	await process_frame
	print("VILLAGE_NAMEPLATES_RESULT checks=%d failures=%d" % [checks, failures.size()])
	for message: String in failures:
		printerr("FAIL: " + message)
	print("VILLAGE_NAMEPLATES_PASS" if failures.is_empty() else "VILLAGE_NAMEPLATES_FAIL")
	quit(0 if failures.is_empty() else 1)


func _projected_width(camera: Camera3D, label: Label3D) -> float:
	var font: Font = label.font if label.font != null else ThemeDB.fallback_font
	var pixels := font.get_string_size(label.text, HORIZONTAL_ALIGNMENT_LEFT, -1, label.font_size).x
	var half_width := pixels * label.pixel_size * 0.5
	var right := camera.global_basis.x * half_width
	return camera.unproject_position(label.global_position - right).distance_to(camera.unproject_position(label.global_position + right))


func _all_labels_hidden(village: Node3D) -> bool:
	for actor: Node3D in village.actors.values():
		if actor.get_node("Nameplate").visible:
			return false
	return true


func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)
