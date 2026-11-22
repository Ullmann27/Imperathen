extends CanvasLayer
## Opt-in frame measurements for the same viewport used by the village and valley.

const SafeArea = preload("res://scripts/ui/safe_area.gd")

var _profiles: Dictionary
var _quality := "balanced"
var _units := Vector3i(-1, -1, -1)
var _label: Label
var _panel: PanelContainer
var _sample_start := 0
var _sample_frames := 0


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


func apply_quality(profile: String) -> void:
	if not _profiles.has(profile):
		return
	_quality = profile
	var settings: Dictionary = _profiles[profile]
	Engine.max_fps = 30 if profile == "low" else 60
	var viewport := get_viewport()
	viewport.mesh_lod_threshold = float(settings.mesh_lod_threshold)
	viewport.msaa_3d = Viewport.MSAA_4X if settings.msaa_samples == 4 else (Viewport.MSAA_2X if settings.msaa_samples == 2 else Viewport.MSAA_DISABLED)
	RenderingServer.directional_shadow_atlas_set_size(int(settings.shadow_atlas_size), true)
	_on_size_changed()


func _on_size_changed() -> void:
	# The window size is in output pixels. The canvas visible rectangle uses UI units.
	var output := get_window().size
	var pixels := maxf(float(output.x) * float(output.y), 1.0)
	get_viewport().scaling_3d_scale = clampf(sqrt(float(_profiles[_quality].max_3d_pixels) / pixels), 0.25, 1.0)
	_place_overlay()


func set_unit_counts(near_count: int, middle_count: int, far_count: int) -> void:
	_units = Vector3i(near_count, middle_count, far_count)


func set_diagnostics(enabled: bool) -> void:
	_panel.visible = enabled
	set_process(enabled)
	if DisplayServer.get_name() != "headless":
		RenderingServer.viewport_set_measure_render_time(get_viewport().get_viewport_rid(), enabled)
	if enabled:
		_label.text = "Bildzeiten werden erfasst …"
		_place_overlay()
		_restart_sample()


func _place_overlay() -> void:
	var safe := SafeArea.for_viewport(get_viewport())
	_panel.position = safe.position + Vector2(12, 74)


func _restart_sample() -> void:
	_sample_start = Time.get_ticks_usec()
	_sample_frames = 0


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_RESUMED and is_instance_valid(_panel) and _panel.visible:
		_restart_sample()
		_place_overlay.call_deferred()


func _process(_delta: float) -> void:
	_sample_frames += 1
	var interval := Time.get_ticks_usec() - _sample_start
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
	if _units.x >= 0:
		_label.text += "\nSoldaten nah / mittel / fern: %d / %d / %d" % [_units.x, _units.y, _units.z]
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
