extends SceneTree

const Actor = preload("res://scripts/visuals/soldier_visual.gd")

func _initialize() -> void:
	run.call_deferred()

func run() -> void:
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color("#72858d")
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color("#fff2e2")
	env.environment.ambient_light_energy = 0.49
	root.add_child(env)
	var sun := DirectionalLight3D.new()
	root.add_child(sun)
	sun.rotation_degrees = Vector3(-40, -34, 0)
	sun.light_energy = 1.05
	sun.shadow_enabled = true
	root.msaa_3d = Viewport.MSAA_4X
	var floor_mesh := MeshInstance3D.new()
	floor_mesh.mesh = PlaneMesh.new()
	floor_mesh.mesh.size = Vector2(200,200)
	var ground := StandardMaterial3D.new()
	ground.albedo_color = Color("#838a87")
	floor_mesh.material_override = ground
	root.add_child(floor_mesh)
	var cam := Camera3D.new()
	root.add_child(cam)
	cam.position = Vector3(.15,2.15,7)
	cam.look_at(Vector3(0,1.08,0))
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.size = 2.73
	for i in range(4):
		var actor := Actor.new()
		actor.configure(Actor.ROLES[i])
		root.add_child(actor)
		actor.position.x = (i-1.5)*1.17
		actor.rotation.y = -.16 if i == 2 else .14
		actor.play_state(["wall","idle","shoot","march"][i],.60 if i == 2 else .4)
		actor.player.pause()

	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(ProjectSettings.globalize_path("res://../art/soldiers/runtime_review.png"))
	quit()
