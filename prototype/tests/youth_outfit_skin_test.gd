extends SceneTree
## Engine cross-check of every installed youth outfit with the motion gate's
## own skin fixture: skin_edge_violations (posed edge > 7 x rest + 3 cm) and
## the lowest sole vertex in every clip, at LOD 0 and LOD 2. The offline
## 60 Hz check of all four LODs is tools/characters/check_youth_civil_outfit.py.
const Person = preload("res://scripts/visuals/village_person.gd")
const SkinFixture = preload("res://tests/motion_skin_measurement.gd")
const FISTS := ["jab_left","jab_right","hook_left","hook_right","uppercut_left","uppercut_right","front_kick","side_kick"]
const PHASES := [0.0, 0.125, 0.25, 0.375, 0.5, 0.625, 0.75, 0.875, 0.999]
var checks := 0
var failures: Array[String] = []
var result := {}


func _initialize() -> void:
	_run.call_deferred()


func _check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures.append(label)
		printerr("YOUTH_OUTFIT_SKIN_FAIL: " + label)


func _run() -> void:
	for outfit: String in ["armoured", "civil"]:
		if not Person.youth_outfit_installed(outfit):
			continue
		result[outfit] = {}
		for level in [0, 2]:
			var actor := Person.new()
			root.add_child(actor)
			actor.set_process(false)
			actor.position = Vector3(0, .9, 0)
			actor.configure("player", "italia", 12)
			actor.configure_meshy_youth(true, outfit)
			actor._reload(level)
			actor._check_lod = 100000.0
			await process_frame
			var skin := SkinFixture.new()
			skin.bind(actor.body)
			_check(skin.errors.is_empty(), "%s LOD%d skin fixture binds: %s" % [outfit, level, str(skin.errors)])
			var per_clip := {}
			var total := 0
			var lowest := INF
			for clip: StringName in actor.animator.get_animation_list():
				var name := String(clip)
				if name == "RESET":
					continue
				var violations := 0
				var clip_lowest := INF
				var worst := {}
				var worst_phase := -1.0
				for phase: float in PHASES:
					if name in FISTS:
						actor.sample_combat(name, phase)
					else:
						actor.sample_pose(name, phase)
					actor._motion.skeleton.force_update_all_bone_transforms()
					var observed: Dictionary = skin.sample()
					_check(bool(observed.finite), "%s LOD%d finite %s %.3f" % [outfit, level, name, phase])
					violations += int(observed.skin_edge_violations)
					if float(observed.get("worst_skin_edge", {}).get("excess_m", 0.0)) > float(worst.get("excess_m", 0.0)):
						worst = observed.worst_skin_edge.duplicate(true)
						worst_phase = phase
					if observed.lowest_sole_m != null:
						clip_lowest = minf(clip_lowest, float(observed.lowest_sole_m))
				if name in FISTS:
					actor.cancel_action()
				per_clip[name] = {"skin_edge_violations": violations, "lowest_sole_m": clip_lowest,
					"worst_edge_excess_m": float(worst.get("excess_m", 0.0)), "worst_edge_mesh_surface": [worst.get("mesh", ""), worst.get("surface", -1)],
					"worst_edge_phase": worst_phase if worst_phase >= 0.0 else null, "worst_edge": worst}
				total += violations
				lowest = minf(lowest, clip_lowest)
			result[outfit]["lod%d" % level] = {"clips": per_clip.size(), "skin_edge_violations": total, "lowest_sole_m": lowest, "per_clip": per_clip}
			actor.free()
	if result.has("civil"):
		for key: String in result.civil:
			_check(int(result.civil[key].skin_edge_violations) == 0, "civil %s: no torn skin edge in any clip (%d)" % [key, int(result.civil[key].skin_edge_violations)])
			if result.has("armoured"):
				_check(absf(float(result.civil[key].lowest_sole_m) - float(result.armoured[key].lowest_sole_m)) < .0005, "civil %s soles as low as the armoured counterpart" % key)
	print("YOUTH_OUTFIT_SKIN_RESULT " + JSON.stringify({"checks": checks, "failures": failures, "result": result}))
	print("YOUTH_OUTFIT_SKIN_PASS" if failures.is_empty() else "YOUTH_OUTFIT_SKIN_FAIL")
	quit(0 if failures.is_empty() else 1)
