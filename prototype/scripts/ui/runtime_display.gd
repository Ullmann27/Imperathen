extends CanvasLayer
## Opt-in frame measurements for the same viewport used by the village and valley.

const SafeArea = preload("res://scripts/ui/safe_area.gd")
const BACKGROUND_FPS := 15

var _profiles: Dictionary
var _quality := "balanced"
var _units := Vector3i(-1, -1, -1)
var _label: Label
var _panel: PanelContainer
var _sample_start := 0
var _sample_frames := 0
var _adapter_line := ""
var _previous_frame_usec := 0
var _recent_times: Array[float] = []
var _foreground_fps := 60
var _application_focused := true
var _application_paused := false


func _ready() -> void:
	_profiles = JSON.parse_string(FileAccess.get_file_as_string("res://assets/quality_profiles.json")).profiles
	layer = 100
	process_mode = Node.PROCESS_MODE_ALWAYS
	_panel = PanelContainer.new()
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var background := StyleBoxFlat.new()
	background.bg_color = Color(0.04, 0.07, 0.07, 0.9)
	background.set_content_margin_all(8)
	_panel.add_theme_stylebox_override("panel", background)
	add_child(_panel)
	_label = Label.new()
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_label.add_theme_font_size_override("font_size", 14)
	_panel.add_child(_label)
	get_viewport().size_changed.connect(_on_size_changed)
	set_diagnostics(false)
	if OS.is_debug_build() and OS.has_feature("android") and FileAccess.file_exists("user://graphics-probe.txt"):
		var probe = preload("res://scripts/ui/android_graphics_probe.gd").new()
		add_child.call_deferred(probe)


func apply_quality(profile: String) -> void:
	if not _profiles.has(profile):
		return
	_quality = profile
	var settings: Dictionary = _profiles[profile]
	_foreground_fps = 30 if profile in ["low", "very_high"] else 60
	_apply_frame_limit()
	var viewport := get_viewport()
	viewport.mesh_lod_threshold = float(settings.mesh_lod_threshold)
	viewport.msaa_3d = Viewport.MSAA_4X if settings.msaa_samples == 4 else (Viewport.MSAA_2X if settings.msaa_samples == 2 else Viewport.MSAA_DISABLED)
	RenderingServer.directional_shadow_atlas_set_size(int(settings.shadow_atlas_size), true)
	_on_size_changed()


func _on_size_changed() -> void:
	# The window size is in output pixels. The canvas visible rectangle uses UI units.
	var output := get_window().size
	get_viewport().scaling_3d_scale = render_scale_for(output, _profiles[_quality], OS.has_feature("pc"))
	# A fold/resize or profile change starts a new, comparable measurement window.
	_reset_measurements()
	_place_overlay()


static func render_scale_for(output: Vector2i, settings: Dictionary, desktop: bool) -> float:
	var budget: float = settings.max_3d_pixels
	if desktop:
		budget = settings.get("desktop_max_3d_pixels", budget)
	var pixels := maxf(float(output.x) * float(output.y), 1.0)
	return clampf(sqrt(budget / pixels), 0.25, 1.0)


func set_unit_counts(near_count: int, middle_count: int, far_count: int) -> void:
	_units = Vector3i(near_count, middle_count, far_count)


func set_diagnostics(enabled: bool) -> void:
	_panel.visible = enabled
	_update_diagnostics_processing()
	_reset_measurements()
	if enabled:
		_adapter_line = "%s · %s" % [RenderingServer.get_current_rendering_method(), RenderingServer.get_video_adapter_name()]
		_place_overlay()


func _application_active() -> bool:
	return _application_focused and not _application_paused


func _apply_frame_limit() -> void:
	# This is a render limit, not a change to the simulation clock or selected profile.
	Engine.max_fps = _foreground_fps if _application_active() else mini(_foreground_fps, BACKGROUND_FPS)


func _update_diagnostics_processing() -> void:
	var enabled := _panel.visible and _application_active()
	set_process(enabled)
	if DisplayServer.get_name() != "headless":
		RenderingServer.viewport_set_measure_render_time(get_viewport().get_viewport_rid(), enabled)


func _place_overlay() -> void:
	var safe := SafeArea.for_viewport(get_viewport())
	_panel.position = safe.position + Vector2(12, 74)


func _restart_sample() -> void:
	_sample_start = Time.get_ticks_usec()
	_sample_frames = 0


func _reset_measurements() -> void:
	_previous_frame_usec = 0
	_recent_times.clear()
	_restart_sample()
	if is_instance_valid(_panel) and _panel.visible:
		_label.text = "Bildzeiten werden erfasst …" if _application_active() else "Bildzeitmessung pausiert."


func _notification(what: int) -> void:
	match what:
		NOTIFICATION_APPLICATION_PAUSED:
			_application_paused = true
		NOTIFICATION_APPLICATION_RESUMED:
			_application_paused = false
		NOTIFICATION_APPLICATION_FOCUS_OUT:
			_application_focused = false
		NOTIFICATION_APPLICATION_FOCUS_IN:
			_application_focused = true
		_:
			return
	# Android may deliver focus and lifecycle events in either order. Both must
	# allow foreground rendering before the selected limit and sampling resume.
	_apply_frame_limit()
	if is_instance_valid(_panel):
		_update_diagnostics_processing()
		_reset_measurements()
		if _application_active() and _panel.visible:
			_place_overlay.call_deferred()


func _process(_delta: float) -> void:
	if not _application_active() or not _panel.visible:
		return
	var now := Time.get_ticks_usec()
	if _previous_frame_usec > 0:
		_recent_times.append((now - _previous_frame_usec) * 0.001)
		if _recent_times.size() > 180:
			_recent_times.pop_front()
	_previous_frame_usec = now
	_sample_frames += 1
	var interval := now - _sample_start
	if interval < 1000000:
		return
	var viewport := get_viewport()
	var rid := viewport.get_viewport_rid()
	var frame_ms := interval / (1000.0 * _sample_frames)
	var cpu_ms := RenderingServer.viewport_get_measured_render_time_cpu(rid)
	var gpu_ms := RenderingServer.viewport_get_measured_render_time_gpu(rid)
	var ram := _resident_memory_kib()
	var draws := viewport.get_render_info(Viewport.RENDER_INFO_TYPE_VISIBLE, Viewport.RENDER_INFO_DRAW_CALLS_IN_FRAME)
	var primitives := viewport.get_render_info(Viewport.RENDER_INFO_TYPE_VISIBLE, Viewport.RENDER_INFO_PRIMITIVES_IN_FRAME)
	_label.text = "%.1f FPS · %.1f ms/Bild\nRender-CPU %s · GPU %s\nRAM (RSS) %s · %d Draw Calls\n%d sichtbare Primitive" % [
		1000.0 / frame_ms, frame_ms, _timing(cpu_ms), _timing(gpu_ms),
		"%.1f MiB" % (ram / 1024.0) if ram > 0 else "unbekannt", draws, primitives]
	if _recent_times.size() >= 10:
		var sorted := _recent_times.duplicate()
		sorted.sort()
		var n := sorted.size()
		_label.text += "\nBildzeit P50/P95/P99: %.1f / %.1f / %.1f ms" % [
			sorted[ceili(n * 0.50)-1], sorted[ceili(n * 0.95)-1], sorted[ceili(n * 0.99)-1]]
		if n == 180 and sorted[ceili(n * 0.95)-1] > 1000.0 / 30.0:
			_label.text += "\nÜber 33 ms: Grafikstufe bei Bedarf senken."
	var output := get_window().size
	var internal := Vector2i((Vector2(output) * viewport.scaling_3d_scale).round())
	_label.text += "\n%s\n3D %d × %d · Ausgabe %d × %d" % [_adapter_line, internal.x, internal.y, output.x, output.y]
	if _units.x >= 0:
		_label.text += "\nSoldaten nah / mittel / fern: %d / %d / %d" % [_units.x, _units.y, _units.z]
	if OS.is_debug_build() and OS.has_feature("android"):
		print("IMPERATHEN_DISPLAY_SAMPLE " + JSON.stringify({
			"gpu": RenderingServer.get_video_adapter_name(), "quality": _quality,
			"renderer": RenderingServer.get_current_rendering_method(), "driver": RenderingServer.get_current_rendering_driver_name(),
			"fps": 1000.0 / frame_ms, "frame_rate_limit": Engine.max_fps,
			"mean_frame_ms": frame_ms, "frames": _sample_frames,
			"render_cpu_ms": cpu_ms if cpu_ms > 0 else null,
			"render_gpu_ms": gpu_ms if gpu_ms > 0 else null,
			"rss_kib": ram if ram > 0 else null, "visible_primitives": primitives,
			"draw_calls": draws, "near_mid_far": [_units.x, _units.y, _units.z],
			"output": [get_window().size.x, get_window().size.y], "scale_3d": viewport.scaling_3d_scale}))
	_restart_sample()


func _timing(milliseconds: float) -> String:
	return "%.2f ms" % milliseconds if milliseconds > 0.0 else "unbekannt"


func _resident_memory_kib() -> int:
	if OS.get_name() not in ["Android", "Linux"]:
		return -1
	var status := FileAccess.open("/proc/self/status", FileAccess.READ)
	if status == null:
		return -1
	# procfs reports a zero file length. Read a bounded buffer and parse VmRSS.
	var lines := status.get_buffer(32768).get_string_from_ascii().split("\n")
	for line in lines:
		if line.begins_with("VmRSS:"):
			return line.trim_prefix("VmRSS:").strip_edges().get_slice(" ", 0).to_int()
	return -1
