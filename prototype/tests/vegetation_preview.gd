extends SceneTree
## Vegetation-only preview in a neutral scene (flat village plane, regional
## terrain, the scenery's backdrop hills): renders the ecology from fixed
## cameras per profile to iterate on assets and placement without the game.
## Not a substitute for tests/vegetation_review.gd (the real game path).
## Usage: --script res://tests/vegetation_preview.gd ++ <out_dir> [profiles,csv]

const Field = preload("res://scripts/vegetation/vegetation_field.gd")
const Ground = preload("res://scripts/vegetation/vegetation_ground.gd")
const Scenery = preload("res://scripts/world/village/village_scenery.gd")
const Layout = preload("res://scripts/world/village/village_layout.gd")
const VIEWS := {
	"edge": [Vector3(-21.0, 1.75, -4.0), Vector3(-70.0, 5.0, -12.0)],
	"brook": [Vector3(-23.2, 2.1, 15.0), Vector3(-30.5, 1.6, -22.0)],
	"fields": [Vector3(12.0, 2.6, 33.0), Vector3(4.0, 0.8, 75.0)],
	"hills": [Vector3(2.0, 1.75, -54.0), Vector3(-6.0, 9.0, -120.0)],
	"close": [Vector3(-36.0, 1.6, 2.0), Vector3(-44.0, 3.0, -6.0)],
	"aerial": [Vector3(60.0, 45.0, 90.0), Vector3(-10.0, 0.0, -10.0)],
}


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var out := args[0] if not args.is_empty() else "user://vegetation_preview"
	var profiles: Array = Array(args[1].split(",")) if args.size() > 1 else ["balanced"]
	DirAccess.make_dir_recursive_absolute(out)
	var environment := Environment.new()
	environment.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	sky.sky_material = ProceduralSkyMaterial.new()
	environment.sky = sky
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	environment.ambient_light_energy = .7
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	environment.fog_enabled = true
	environment.fog_density = .0018
	var world_env := WorldEnvironment.new()
	world_env.environment = environment
	root.add_child(world_env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-42, -28, 0)
	sun.light_energy = 1.1
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 80
	root.add_child(sun)
	var scenery := Scenery.new()
	root.add_child(scenery)
	scenery.create_land()
	var ground := Ground.new()
	ground.add_mesh(scenery.get_node_or_null("Foothills") as MeshInstance3D)
	var camera := Camera3D.new()
	camera.far = 300
	root.add_child(camera)
	camera.current = true
	var random := RandomNumberGenerator.new()
	random.seed = 104729
	var sites := []
	for index in range(38):
		var x := random.randf_range(-61, -33) if index < 22 else random.randf_range(-20, 43)
		var z := random.randf_range(-42, 28) if index < 22 else random.randf_range(-46, -27)
		if Layout.reserved(Vector2(x, z), 1.3) or Layout.road(Vector2(x, z)):
			continue
		sites.append({"kind": "oak", "position": Vector3(x, 0, z), "scale": 1.0, "yaw": random.randf_range(-PI, PI)})
	var started := Time.get_ticks_msec()
	var field := Field.new()
	root.add_child(field)
	field.build(ground.height, sites)
	print("VEGETATION_PREVIEW build_ms=", Time.get_ticks_msec() - started, " placed=", field.placed_trees)
	field.set_wind_time(4.0)
	scenery.set_presentation_time(4.0)
	for profile: String in profiles:
		field.set_quality(profile)
		for view: String in VIEWS:
			camera.global_position = VIEWS[view][0]
			camera.look_at(VIEWS[view][1], Vector3.UP)
			field.refresh(camera)
			for i in 4:
				await RenderingServer.frame_post_draw
			var image := root.get_texture().get_image()
			image.save_png(out.path_join("%s-%s.png" % [view, profile]))
			print("VEGETATION_PREVIEW ", view, " ", profile, " ", JSON.stringify(field.stats()))
	print("VEGETATION_PREVIEW_DONE")
	quit(0)
