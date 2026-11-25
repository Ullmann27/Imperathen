extends SceneTree
const Atmosphere := preload("res://scripts/rendering/viva_roma_atmosphere.gd")
var failures := 0

func _initialize() -> void:
	call_deferred("_check")

func _require(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)

func _check() -> void:
	for profile: String in ["low","balanced","high","very_high"]:
		var mat := Atmosphere.ground_material(profile)
		_require(mat.shader != null, "ground shader missing")
		var sun := DirectionalLight3D.new()
		root.add_child(sun)
		Atmosphere.configure_sun(sun,profile)
		_require(sun.shadow_enabled == (profile != "low"), "shadow profile")
		_require(is_equal_approx(sun.directional_shadow_max_distance,float(Atmosphere.DISTANCE[profile])), "shadow range")
		var env := Atmosphere.environment(profile)
		_require(env.sky != null and env.fog_enabled, "environment not configured")
		_require(env.ambient_light_energy < sun.light_energy, "flat ambient lighting")
		sun.free()
	print("VIVA_ROMA_ATMOSPHERE_" + ("PASS" if failures == 0 else "FAIL"))
	quit(0 if failures == 0 else 1)
