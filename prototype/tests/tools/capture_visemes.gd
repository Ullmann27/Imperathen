extends SceneTree
## Renders the procedural test head in every viseme pose plus a timeline of a
## real I-01 line, driven through face_driver.gd (jaw bone + blend shapes).
## Run under xvfb (needs a real renderer):
##   xvfb-run -s "-screen 0 1280x720x24" godot --path prototype --resolution 480x480 \
##     --script res://tests/tools/capture_visemes.gd -- <out_dir> [line_id]

const Head = preload("res://scripts/audio/procedural_test_head.gd")
const Face = preload("res://scripts/audio/face_driver.gd")
const VoiceLines = preload("res://scripts/audio/voice_lines.gd")

var _out := "user://visemes"
var _line_id := "I-01.mother_morning"
var _head: Node3D
var _face: Node
var _jobs: Array = []
var _frame := 0
var _manifest: Array = []


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		_out = args[0]
	if args.size() > 1:
		_line_id = args[1]
	DirAccess.make_dir_recursive_absolute(_out)
	var world := Node3D.new()
	root.add_child(world)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color(0.16, 0.17, 0.19)
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color(0.55, 0.55, 0.6)
	world.add_child(env)
	var key := DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-25.0, 25.0, 0.0)
	key.light_energy = 1.2
	world.add_child(key)
	var cam := Camera3D.new()
	cam.fov = 32.0
	cam.fov = 30.0
	var eye := Vector3(0.06, 0.0, 0.42)
	cam.transform = Transform3D(Basis.looking_at(Vector3(0.0, -0.03, 0.06) - eye, Vector3.UP), eye)
	world.add_child(cam)
	_head = Head.new()
	_head.rotation_degrees = Vector3(0.0, 12.0, 0.0)
	world.add_child(_head)
	_head.build()
	_face = Face.new()
	_face.blink_enabled = false
	world.add_child(_face)
	var bound: Dictionary = _face.bind(_head)
	print("CAPTURE_BIND ", bound)
	for i in Face.VISEMES.size():
		_jobs.append({"name": "pose_%02d_%s" % [i, Face.VISEMES[i]], "track": {"segments": [[0.0, 1.0, i]]}, "t": 0.5})
	var line := {}
	for l: Dictionary in VoiceLines.all_lines():
		if str(l.line_id) == _line_id:
			line = l
	var track := VoiceLines.viseme_track(line)
	if not track.is_empty():
		for k in 8:
			var t := float(track.first_phoneme_s) + k * 0.1
			_jobs.append({"name": "line_%s_t%04d" % [_line_id, int(round(t * 1000.0))], "track": track, "t": t})


func _process(_delta: float) -> bool:
	_frame += 1
	# Even frames: pose; odd frames: grab the frame rendered with that pose.
	var job_index := (_frame - 2) / 2
	if _frame < 2:
		return false
	if job_index >= _jobs.size():
		var f := FileAccess.open(_out.path_join("captures.json"), FileAccess.WRITE)
		f.store_string(JSON.stringify({"renderer": RenderingServer.get_current_rendering_method(),
			"adapter": RenderingServer.get_video_adapter_name(), "resolution": [root.size.x, root.size.y],
			"engine": Engine.get_version_info().string, "captures": _manifest}, "  "))
		print("CAPTURE_VISEMES_DONE ", _manifest.size())
		return true
	var job: Dictionary = _jobs[job_index]
	if _frame % 2 == 0:
		_face.set_track(job.track, func() -> float: return float(job.t))
		_face.sample(float(job.t))
		_face._apply()
	else:
		# The pose set on the previous (even) frame has been drawn by now.
		var img := root.get_texture().get_image()
		var path: String = _out.path_join(job.name + ".png")
		img.save_png(path)
		_manifest.append({"file": job.name + ".png", "t": job.t, "params": _face.params.duplicate(), "activity": _face.activity})
	return false
