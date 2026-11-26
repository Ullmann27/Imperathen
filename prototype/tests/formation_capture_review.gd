extends SceneTree
## Real-viewport frame sequences of the valley encounter for visual review of
## formation movement: wheel, march stride, charge into contact, LOD crossing.
## Needs a graphical display (xvfb is fine) and an isolated user directory:
##   godot --path prototype --resolution 1280x720 --script res://tests/formation_capture_review.gd ++ <out_dir> <profile>
## The scene is advanced manually at 60 Hz so every run shows the same moments.

const Valley = preload("res://scripts/tactics/valley_scene.gd")
const HZ := 60.0
const SHOTS := {
	"wheel": [0.6, 1.6, 2.6, 3.6],
	"march": [5.0, 5.2, 5.4, 5.6],
	"charge": [9.5, 10.5, 11.0, 11.5, 12.0, 12.5, 13.0, 14.0],
	"lod": [15.0, 15.75, 16.5, 17.25, 18.0, 18.75, 19.5, 20.25, 21.0],
}
var output := ""
var profile := "balanced"
var v
var log_lines: Array[String] = []


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if OS.get_environment("IMPERATHEN_ISOLATED_TEST") != "1" or args.size() < 2 or DisplayServer.get_name() == "headless":
		printerr("A graphical viewport, isolated user directory, output dir and profile are required.")
		quit(2)
		return
	output = args[0]
	profile = args[1]
	DirAccess.make_dir_recursive_absolute(output)
	_run.call_deferred()


func _camera(t: float) -> void:
	var m = v.model
	var guard: Dictionary = m.squads.valley_guard
	var spears: Dictionary = m.squads.valley_spears
	if t < 4.0:
		v.focus = Vector2(spears.x, spears.z)
		v.distance = 15.0
		v.azimuth = -0.25
	elif t < 9.0:
		v.focus = Vector2(guard.x, guard.z)
		v.distance = 10.0
		v.azimuth = 1.05
	elif t < 15.0:
		v.focus = v.focus.lerp(Vector2(guard.x, guard.z - 2.0), 0.08)
		v.distance = 13.0
		v.azimuth = 0.45
	else:
		# Dolly 10 m -> 58 m -> 10 m across every LOD radius while the melee goes on.
		var u := clampf((t - 15.0) / 6.0, 0.0, 1.0)
		v.distance = lerpf(10.0, 58.0, sin(PI * u))
		v.azimuth = 0.45
	v._place_camera()


func _script(t: float) -> void:
	var m = v.model
	if t >= 0.05 and t - 1.0 / HZ < 0.05:
		m.order(["valley_spears"], "deploy", {"start": Vector2(1, 6), "end": Vector2(8, 3.5)})
	if t >= 4.0 and t - 1.0 / HZ < 4.0:
		m.order(["valley_guard"], "move", Vector2(-7, 1))
	if t >= 8.0 and t - 1.0 / HZ < 8.0:
		m.order(["valley_guard"], "form", "line")
	if t >= 9.0 and t - 1.0 / HZ < 9.0:
		m.order(["valley_guard"], "attack", "ridge_guard")
		m.order(["valley_spears"], "attack", "ridge_spears")


func _run() -> void:
	var display := root.get_node_or_null("RuntimeDisplay")
	if display:
		display.apply_quality(profile)
	v = Valley.new()
	root.add_child(v)
	v.set_process(false)
	v.set_quality(profile)
	v.hud.hide()
	v.paused = false
	var pending := []
	for scenario: String in SHOTS:
		for at: float in SHOTS[scenario]:
			pending.append([at, scenario])
	pending.sort_custom(func(a, b): return a[0] < b[0])
	var frame := 0
	var shot := 0
	while not pending.is_empty() and frame < int(22.0 * HZ):
		frame += 1
		var t := float(frame) / HZ
		_script(t)
		_camera(t)
		v._process(1.0 / HZ)
		if t + 0.0001 >= float(pending[0][0]):
			var entry: Array = pending.pop_front()
			await RenderingServer.frame_post_draw
			var image := root.get_texture().get_image()
			var name := "%s_%02d_t%05.2f.png" % [entry[1], shot, t]
			shot += 1
			if image == null or image.is_empty() or image.save_png(output.path_join(name)) != OK:
				printerr("Empty capture ", name)
			var counters: Dictionary = v.formation_counters() if v.has_method("formation_counters") else {}
			log_lines.append(JSON.stringify({"file": name, "t": t, "profile": profile, "camera_distance": v.distance,
				"draw_calls": root.get_render_info(Viewport.RENDER_INFO_TYPE_VISIBLE, Viewport.RENDER_INFO_DRAW_CALLS_IN_FRAME),
				"primitives": root.get_render_info(Viewport.RENDER_INFO_TYPE_VISIBLE, Viewport.RENDER_INFO_PRIMITIVES_IN_FRAME),
				"rigs_near": counters.get("rigs_near", -1), "rigs_mid": counters.get("rigs_mid", -1),
				"far": counters.get("far_instances", -1), "visible": counters.get("visible", -1),
				"alive": counters.get("strength", -1)}))
	var handle := FileAccess.open(output.path_join("frames.jsonl"), FileAccess.WRITE)
	handle.store_string("\n".join(log_lines) + "\n")
	handle.close()
	print("FORMATION_CAPTURED ", shot, " frames ", profile)
	v.free()
	quit(0)
