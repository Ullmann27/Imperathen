extends SceneTree
## Matched before/after Godot captures of the Valdora houses and lanes (D-038).
## Builds the real village pieces the game uses (regional_village.gd with all
## 20 households, village_scenery.gd land, workshop/store/market) under the
## game's own spring atmosphere values (game_world.gd _create_atmosphere +
## village_scenery.apply_season(0)), then renders fixed cameras.
##
## xvfb-run godot --path prototype --rendering-method gl_compatibility \
##   --script "$PWD/art/architecture/valdora_family/capture_valdora.gd" -- \
##   --out=<dir> --label=before|after --profile=balanced [--commit=<sha>]
##
## Output per shot: <label>_<profile>_<shot>.png plus one <label>_<profile>.json
## with commit, renderer, resolution, camera, lighting, loaded models with
## SHA-256, render counters, memory and frame times (software renderer: the
## times are relative and say nothing about a phone GPU).

const Village = preload("res://scripts/world/regional_village.gd")
const Scenery = preload("res://scripts/world/village/village_scenery.gd")
const SIZE := Vector2i(1280, 720)
## name: [camera position, look-at target, vertical fov]
const SHOTS := {
	"familienhaus": [Vector3(-9.6, 1.62, 18.4), Vector3(-13.2, 1.9, 11.0), 55.0],
	"westgasse": [Vector3(-9.3, 1.70, -4.0), Vector3(-10.4, 1.6, -36.0), 55.0],
	"ostzeile": [Vector3(30.6, 1.70, -4.5), Vector3(38.5, 1.9, -28.0), 55.0],
	"dach_nah": [Vector3(-9.1, 5.30, 15.6), Vector3(-13.0, 3.6, 11.0), 50.0],
	"schwelle_nah": [Vector3(-12.1, 0.85, 15.9), Vector3(-13.0, 0.35, 13.4), 60.0],
	"ueberblick": [Vector3(14.0, 17.0, 34.0), Vector3(4.0, 0.0, -14.0), 52.0],
}

var _out := ""
var _label := "after"
var _profile := "balanced"
var _commit := "unknown"


func _initialize() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--out="):
			_out = argument.trim_prefix("--out=")
		elif argument.begins_with("--label="):
			_label = argument.trim_prefix("--label=")
		elif argument.begins_with("--profile="):
			_profile = argument.trim_prefix("--profile=")
		elif argument.begins_with("--commit="):
			_commit = argument.trim_prefix("--commit=")
	_run.call_deferred()


func _run() -> void:
	if _out.is_empty():
		printerr("VALDORA_CAPTURE needs --out=<dir>")
		quit(2)
		return
	DirAccess.make_dir_recursive_absolute(_out)
	var view := SubViewport.new()
	view.size = SIZE
	view.own_world_3d = true
	view.msaa_3d = {"low": Viewport.MSAA_DISABLED, "balanced": Viewport.MSAA_2X}.get(_profile, Viewport.MSAA_4X)
	view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	# Same automatic-LOD bias as runtime_display.gd applies per profile.
	var profiles: Dictionary = (load("res://assets/quality_profiles.json") as JSON).data.profiles
	view.mesh_lod_threshold = float(profiles.get(_profile, profiles.balanced).mesh_lod_threshold)
	root.add_child(view)
	var stage := Node3D.new()
	stage.name = "ValdoraCaptureStage"
	view.add_child(stage)
	var scenery := Scenery.new()
	scenery.name = "VillageScenery"
	stage.add_child(scenery)
	scenery.create_land()
	scenery.set_origin("italia")
	scenery.add_businesses(stage)
	scenery.sow_field(stage)
	var village := Village.new()
	village.name = "RegionalVillage"
	stage.add_child(village)
	village.show_origin("italia")
	# Game atmosphere (game_world.gd) and the spring season of a new life.
	var environment := Environment.new()
	environment.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	sky.radiance_size = Sky.RADIANCE_SIZE_64
	sky.sky_material = scenery.sky_material
	environment.sky = sky
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.69, 0.77, 0.85)
	environment.ambient_light_energy = 0.58
	environment.ambient_light_sky_contribution = 0.0
	environment.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	environment.fog_enabled = true
	environment.fog_sky_affect = 0.06
	environment.fog_sun_scatter = 0.04
	environment.fog_density = 0.0015
	environment.fog_light_color = Color(0.63, 0.69, 0.66)
	var world_environment := WorldEnvironment.new()
	world_environment.environment = environment
	stage.add_child(world_environment)
	var sun := DirectionalLight3D.new()
	sun.name = "AfternoonSun"
	sun.light_color = Color(1.0, 0.88, 0.69)
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = float({"low": 24, "balanced": 48, "high": 85}.get(_profile, 110))
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL if _profile == "low" else (DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS if _profile == "balanced" else DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS)
	stage.add_child(sun)
	scenery.apply_season(0, sun, environment)
	scenery.set_quality(_profile)
	village.set_quality(_profile)
	scenery.set_presentation_time(4.0)
	var camera := Camera3D.new()
	camera.near = 0.05
	camera.far = 600.0
	stage.add_child(camera)
	camera.current = true
	var rid := view.get_viewport_rid()
	RenderingServer.viewport_set_measure_render_time(rid, true)
	for frame in 8:
		await process_frame
	var report := {
		"schema": "imperathen.d038.render.v1",
		"label": _label, "profile": _profile, "source_commit": _commit,
		"engine": Engine.get_version_info().string,
		"renderer": ProjectSettings.get_setting("rendering/renderer/rendering_method", ""),
		"adapter": RenderingServer.get_video_adapter_name(), "adapter_vendor": RenderingServer.get_video_adapter_vendor(),
		"api_version": RenderingServer.get_video_adapter_api_version(),
		"resolution": [SIZE.x, SIZE.y], "msaa": view.msaa_3d, "mesh_lod_threshold": view.mesh_lod_threshold,
		"stage": "res://scripts/world/regional_village.gd show_origin(italia) + village_scenery.gd create_land/add_businesses/sow_field; no palisade, trees or residents",
		"lighting": {"sun_rotation_deg": [sun.rotation_degrees.x, sun.rotation_degrees.y, sun.rotation_degrees.z],
			"sun_energy": sun.light_energy, "sun_color": sun.light_color.to_html(false),
			"ambient_color": environment.ambient_light_color.to_html(false), "ambient_energy": environment.ambient_light_energy,
			"tonemap": "linear", "fog_density": environment.fog_density, "season": "spring (apply_season 0)",
			"shadow_distance_m": sun.directional_shadow_max_distance, "presentation_time_s": 4.0},
		"models": _models(village, stage),
		"shots": {},
	}
	for shot: String in SHOTS:
		var spec: Array = SHOTS[shot]
		camera.fov = spec[2]
		camera.look_at_from_position(spec[0], spec[1], Vector3.UP)
		for frame in 6:
			await process_frame
		var started := Time.get_ticks_usec()
		var cpu := 0.0
		var gpu := 0.0
		const MEASURED := 12
		for frame in MEASURED:
			await process_frame
			cpu += RenderingServer.viewport_get_measured_render_time_cpu(rid)
			gpu += RenderingServer.viewport_get_measured_render_time_gpu(rid)
		var wall_ms := float(Time.get_ticks_usec() - started) / 1000.0 / MEASURED
		var image := view.get_texture().get_image()
		var file := "%s_%s_%s.png" % [_label, _profile, shot]
		image.save_png(_out.path_join(file))
		report.shots[shot] = {"file": file, "camera": {"position": [spec[0].x, spec[0].y, spec[0].z], "target": [spec[1].x, spec[1].y, spec[1].z], "fov_deg": spec[2]},
			"draw_calls": RenderingServer.viewport_get_render_info(rid, RenderingServer.VIEWPORT_RENDER_INFO_TYPE_VISIBLE, RenderingServer.VIEWPORT_RENDER_INFO_DRAW_CALLS_IN_FRAME),
			"primitives": RenderingServer.viewport_get_render_info(rid, RenderingServer.VIEWPORT_RENDER_INFO_TYPE_VISIBLE, RenderingServer.VIEWPORT_RENDER_INFO_PRIMITIVES_IN_FRAME),
			"objects": RenderingServer.viewport_get_render_info(rid, RenderingServer.VIEWPORT_RENDER_INFO_TYPE_VISIBLE, RenderingServer.VIEWPORT_RENDER_INFO_OBJECTS_IN_FRAME),
			"shadow_primitives": RenderingServer.viewport_get_render_info(rid, RenderingServer.VIEWPORT_RENDER_INFO_TYPE_SHADOW, RenderingServer.VIEWPORT_RENDER_INFO_PRIMITIVES_IN_FRAME),
			"render_cpu_ms": snappedf(cpu / MEASURED, .001), "render_gpu_ms": snappedf(gpu / MEASURED, .001), "wall_frame_ms": snappedf(wall_ms, .01)}
		print("VALDORA_CAPTURE shot ", shot, " ", JSON.stringify(report.shots[shot]))
	report["memory"] = {"texture_mib": snappedf(Performance.get_monitor(Performance.RENDER_TEXTURE_MEM_USED) / 1048576.0, .01),
		"buffer_mib": snappedf(Performance.get_monitor(Performance.RENDER_BUFFER_MEM_USED) / 1048576.0, .01),
		"video_mib": snappedf(Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED) / 1048576.0, .01),
		"static_mib": snappedf(Performance.get_monitor(Performance.MEMORY_STATIC) / 1048576.0, .01)}
	report["measurement_environment"] = "Software rasteriser (llvmpipe) under xvfb on a shared 4-core cloud VM; relative only, no device claim."
	var json := FileAccess.open(_out.path_join("%s_%s.json" % [_label, _profile]), FileAccess.WRITE)
	json.store_string(JSON.stringify(report, "  "))
	json.close()
	print("VALDORA_CAPTURE_DONE ", _out)
	quit(0)


func _models(village: Node3D, stage: Node3D) -> Dictionary:
	# Every scene file instanced under the stage, with the source file hash and
	# the textures it carries (glb-embedded images are named, not hashed apart).
	var models := {}
	for node: Node in stage.find_children("*", "Node3D", true, false):
		var path := node.scene_file_path
		if path.is_empty() or models.has(path):
			continue
		var instances := 0
		var triangles := 0
		for other: Node in stage.find_children("*", "Node3D", true, false):
			if other.scene_file_path == path:
				instances += 1
		for mesh_node: MeshInstance3D in node.find_children("*", "MeshInstance3D", true, false):
			if mesh_node.mesh:
				for surface in mesh_node.mesh.get_surface_count():
					triangles += mesh_node.mesh.surface_get_array_index_len(surface) / 3
		var textures := []
		for mesh_node: MeshInstance3D in node.find_children("*", "MeshInstance3D", true, false):
			if not mesh_node.mesh:
				continue
			for surface in mesh_node.mesh.get_surface_count():
				var material := mesh_node.get_active_material(surface)
				if material is StandardMaterial3D:
					for texture: Texture2D in [material.albedo_texture, material.normal_texture, material.roughness_texture]:
						if texture and texture.resource_name not in textures:
							textures.append(texture.resource_name if not texture.resource_name.is_empty() else texture.resource_path)
				elif material is ShaderMaterial:
					var shader_path: String = material.shader.resource_path if material.shader else ""
					if shader_path not in textures:
						textures.append(shader_path)
		models[path] = {"sha256": FileAccess.get_sha256(path), "instances": instances, "triangles_lod0": triangles, "materials_textures": textures}
	return models
