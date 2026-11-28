extends SceneTree
## Candidate acceptance: apply the sibling study patch before running.

const RomanFaces := preload("res://scripts/visuals/roman_faces.gd")
const SILVANUS_LOOK := {
	"id": "silvanus",
	"kind": "civilian_man",
	"skin": {"tone": Color(0.44, 0.31, 0.22)},
	"hair": {"color": Color(0.15, 0.11, 0.08), "grey": 0.02, "keys": {}},
}
const OTHER_LOOK := {
	"id": "sextus",
	"kind": "civilian_man",
	"skin": {"tone": Color(0.44, 0.31, 0.22)},
	"hair": {"color": Color(0.15, 0.11, 0.08), "grey": 0.02, "keys": {}},
}

var checks := 0
var failures: Array[String] = []


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	for lod: int in range(4):
		var path := "res://assets/characters/frontier_civilian_man_%d.glb" % lod
		var packed := load(path) as PackedScene
		_check(packed != null, "Original public LOD%d asset loads" % lod)
		if packed == null:
			continue
		var model := packed.instantiate() as Node3D
		root.add_child(model)
		await process_frame
		var mesh_count := model.find_children("*", "MeshInstance3D", true, false).size()
		var body := model.find_child("HeroBody", true, false) as MeshInstance3D
		_check(body != null, "LOD%d retains its original HeroBody" % lod)
		if body != null:
			var source := body.mesh.surface_get_material(0) as StandardMaterial3D
			RomanFaces.apply(model, 1, SILVANUS_LOOK)
			var finish := body.material_override as ShaderMaterial
			_check(finish != null, "Silvanus LOD%d uses the resident skin layer" % lod)
			if finish != null:
				_check(is_equal_approx(float(finish.get_shader_parameter("scalp")), 1.0),
					"Silvanus LOD%d activates the authored scalp mask" % lod)
			_check(body.mesh.surface_get_material(0) == source, "LOD%d source material stays unchanged" % lod)
		_check(model.find_children("*", "MeshInstance3D", true, false).size() == mesh_count,
			"LOD%d adds no replacement body or hair geometry" % lod)
		model.queue_free()
		await process_frame

	var packed := load("res://assets/characters/frontier_civilian_man_0.glb") as PackedScene
	var other := packed.instantiate() as Node3D
	root.add_child(other)
	await process_frame
	var other_body := other.find_child("HeroBody", true, false) as MeshInstance3D
	RomanFaces.apply(other, 1, OTHER_LOOK)
	_check(not (other_body.material_override is ShaderMaterial), "Other residents keep the legacy skin material")
	other.queue_free()
	await process_frame
	for failure: String in failures:
		push_error(failure)
	print("ROMAN_FACES_SILVANUS_HAIR_RESULT checks=%d failures=%d" % [checks, failures.size()])
	quit(1 if not failures.is_empty() else 0)


func _check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures.append(label)
		push_error("ROMAN_FACES_SILVANUS_HAIR_FAIL " + label)
