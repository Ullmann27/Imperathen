extends SceneTree
## Tests the catalog bridge on installed frontier GLBs; the recovered full
## morph test remains a separate gate for future model exports.
const Person := preload("res://scripts/visuals/village_person.gd")
const Identity := preload("res://scripts/visuals/resident_identity.gd")
var failures := 0
var checks := 0

func _initialize() -> void:
	_run.call_deferred()

func _check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(label)

func _spawn(id: String, kind: String, years: int) -> Person:
	var actor := Person.new()
	root.add_child(actor)
	actor.set_process(false)
	actor.configure_resident("italia", years, kind, 3, null, "vil:" + id)
	return actor

func _cloth(actor: Person) -> StandardMaterial3D:
	var tunic := actor.body.find_child("HeroTunic", true, false) as MeshInstance3D if actor.body else null
	return tunic.get_active_material(0) as StandardMaterial3D if tunic and tunic.mesh and tunic.mesh.get_surface_count() > 0 else null

func _run() -> void:
	var first := _spawn("livia", "civilian_woman", 41)
	var second := _spawn("cassia", "civilian_woman", 35)
	var expected_a := Identity.look("livia", "civilian_woman", 3, 41)
	var expected_b := Identity.look("cassia", "civilian_woman", 3, 35)
	_check(first.resident_id == "livia" and first.identity == "resident_livia", "prefixed live resident UID resolves original catalog")
	_check(second.resident_id == "cassia" and second.identity == "resident_cassia", "a second named UID has its own identity")
	_check(first.look == expected_a and second.look == expected_b, "live actors use exact authored identity data")
	for level in 4:
		first._reload(level)
		second._reload(level)
		_check(first.body != null and second.body != null and first.detail == level and second.detail == level, "both actors retain actual LOD %d" % level)
		var expected_path := "res://assets/characters/frontier_civilian_woman_%d.glb" % level
		_check(first.body != null and first.active_model_path == expected_path and first.body.scene_file_path == expected_path, "named resident uses exact original civilian woman GLB at LOD %d" % level)
		_check(second.body != null and second.active_model_path == expected_path and second.body.scene_file_path == expected_path, "second resident uses same original family, separate appearance at LOD %d" % level)
		var digest := FileAccess.get_sha256(expected_path)
		_check(digest.length() == 64, "original civilian model bytes available for provenance")
		print("AETERNA_ATELIER_RUNTIME ", JSON.stringify({"family": "civilian_woman", "lod": level, "path": expected_path, "sha256": digest, "actor": first.resident_id, "instantiated_scene": first.body.scene_file_path if first.body != null else ""}))
		var a := _cloth(first)
		var b := _cloth(second)
		_check(a != null and b != null and a != b and a.albedo_color != b.albedo_color, "same base model displays distinct named clothing at LOD %d" % level)
		if a and b:
			var tunic := first.body.find_child("HeroTunic", true, false) as MeshInstance3D
			var source := tunic.mesh.surface_get_material(0) as StandardMaterial3D
			_check(source != null and source.albedo_color == Color.WHITE, "shared original material is not mutated")
		_check(first.identity == "resident_livia" and first.look == expected_a, "identity persists across LOD swaps")
	first.configure_resident("italia", 41, "civilian_woman", 8, null, "vil:livia")
	_check(first.look == expected_a and first.identity == "resident_livia", "population order does not change named identity")
	var generic := _spawn("unregistered_test_resident", "civilian_man", 30)
	_check(generic.body != null and generic.look.is_empty(), "unregistered actor retains existing appearance")
	var child := _spawn("livia", "civilian_woman", 12)
	_check(child.body != null and child.look.is_empty() and not child.active_model_path.contains("frontier_"), "adult catalog never replaces a child")
	var mismatched := _spawn("livia", "civilian_man", 41)
	_check(mismatched.look.is_empty() and mismatched.active_model_path.contains("frontier_civilian_man_"), "catalog cannot overwrite roster anatomy")
	first.configure("player", "italia", 25)
	_check(first.look.is_empty() and first.resident_id.is_empty(), "player identity stays separate from residents")
	for actor: Person in [first, second, generic, child, mismatched]:
		actor.free()
	print("RESIDENT_CATALOG_BRIDGE_PASS" if failures == 0 else "RESIDENT_CATALOG_BRIDGE_FAIL", " ", checks, " checks, ", failures, " failed")
	quit(0 if failures == 0 else 1)
