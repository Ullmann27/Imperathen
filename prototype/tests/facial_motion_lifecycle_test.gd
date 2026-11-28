extends SceneTree
## Regression for actual Godot blend-shape values, not rendered-image approval.
const Face = preload("res://scripts/visuals/facial_motion.gd")
var checks := 0
var failures := 0

func _initialize() -> void:
	call_deferred("_run")

func _check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("FACIAL_LOD_FAIL ", label)

func _make_face() -> MeshInstance3D:
	var mesh := ArrayMesh.new()
	mesh.blend_shape_mode = Mesh.BLEND_SHAPE_MODE_NORMALIZED
	for shape: String in Face.SHAPES:
		mesh.add_blend_shape(shape)
	var surface := []
	surface.resize(Mesh.ARRAY_MAX)
	surface[Mesh.ARRAY_VERTEX] = PackedVector3Array([Vector3.ZERO, Vector3.RIGHT, Vector3.UP])
	var shapes: Array[Array] = []
	for i in Face.SHAPES.size():
		var shape := []
		shape.resize(Mesh.ARRAY_MAX)
		shape[Mesh.ARRAY_VERTEX] = PackedVector3Array([Vector3.ZERO, Vector3.RIGHT, Vector3(0, 1, 0.01 * (i + 1))])
		shapes.append(shape)
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, surface, shapes)
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	return instance

func _neutral(instance: MeshInstance3D) -> bool:
	for shape: String in Face.SHAPES:
		var slot := instance.find_blend_shape_by_name(shape)
		if slot < 0 or not is_zero_approx(instance.get_blend_shape_value(slot)):
			return false
	return true

func _value(instance: MeshInstance3D, shape: String) -> float:
	var slot := instance.find_blend_shape_by_name(shape)
	return instance.get_blend_shape_value(slot) if slot >= 0 else -1.0

func _run() -> void:
	var model := Node3D.new()
	root.add_child(model)
	var near := _make_face()
	model.add_child(near)
	var driver := Face.new()
	driver.bind(model, "resident-001")
	driver.pose("death", 0.0, 0)
	_check(is_equal_approx(_value(near, "Blink_L"), 1.0), "near death closes left eye")
	_check(is_equal_approx(_value(near, "Blink_R"), 1.0), "near death closes right eye")
	_check(_value(near, "JawOpen") > 0.0, "near expression is active")
	driver.advance(0.0, "death", 2)
	_check(_neutral(near), "LOD entry clears live face without a rebind")
	driver.advance(1.0, "talk", 3)
	_check(_neutral(near), "distant updates remain neutral")
	var replacement := _make_face()
	root.add_child(replacement)
	driver.bind(replacement, "resident-001")
	_check(_neutral(replacement), "same-identity distant replacement is neutral")
	driver.advance(1.0, "death", 3)
	_check(_neutral(replacement), "root mesh stays neutral while distant")
	driver.advance(0.001, "talk", 0)
	_check(_neutral(replacement), "no accumulated distant interpolation time")
	driver.advance(0.10, "talk", 0)
	_check(_value(replacement, "JawOpen") > 0.0, "root mesh animates when near again")
	var jaw := _value(replacement, "JawOpen")
	driver.advance(-1.0, "death", 2)
	_check(is_equal_approx(_value(replacement, "JawOpen"), jaw), "negative delta does not mutate face")
	driver.pose("death", 0.0, 0)
	_check(is_equal_approx(_value(replacement, "Blink_L"), 1.0), "root mesh is bound")
	driver.pose("death", 0.0, 2)
	_check(_neutral(replacement), "posed distant face is neutral")
	driver.advance(0.10, "talk", 0)
	_check(_value(replacement, "JawOpen") > 0.0, "near face recovers after distant pose")
	driver.bind(replacement, "resident-002")
	_check(_neutral(replacement), "new identity starts neutral")
	driver._set_audio_jaw_owner(true)
	var jaw_index: int = replacement.find_blend_shape_by_name("JawOpen")
	replacement.set_blend_shape_value(jaw_index, 0.73)
	driver.pose("death",0.0,0)
	_check(is_equal_approx(_value(replacement,"JawOpen"),0.73), "Speech-owned jaw survives an expressive pose")
	_check(is_equal_approx(_value(replacement,"Blink_L"),1.0), "Speech ownership does not suppress eye expressions")
	driver.advance(0.1,"talk",0)
	_check(is_equal_approx(_value(replacement,"JawOpen"),0.73), "Speech-owned jaw survives live expressive update")
	driver._set_audio_jaw_owner(false)
	_check(is_zero_approx(_value(replacement,"JawOpen")), "Release resets jaw to neutral")
	driver.pose("talk",0.32,0)
	_check(_value(replacement,"JawOpen")>0.05, "Silent talk returns after release")
	model.free()
	replacement.free()
	print("FACIAL_LOD_RESULT checks=%d failures=%d" % [checks, failures])
	if failures == 0:
		print("FACIAL_LOD_PASS")
	quit(0 if failures == 0 else 1)
