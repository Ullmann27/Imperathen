extends CanvasLayer
## Opt-in frame measurements for the same viewport used by the village and valley.

const SafeArea = preload("res://scripts/ui/safe_area.gd")
const SustainedQuality = preload("res://scripts/rendering/fold7_quality_policy.gd")
const RenderProfile = preload("res://scripts/rendering/render_profile.gd")
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
var _sustained_scene := false
var _sustained_paused := false
var _governor: Dictionary = SustainedQuality.initial("balanced")
var _render_applied: Dictionary = {}
var _environment_watcher: EnvironmentWatcher


## Applies profile post-processing (ambient occlusion) to whichever Environment
## the 3D view renders with, including worlds created after the profile change.
class EnvironmentWatcher extends Node:
	var _environment_id := 0
	var _profile := ""

	func _process(_delta: float) -> void:
		var environment := RenderProfile.active_environment(get_viewport())
		var id := environment.get_instance_id() if environment != null else 0
		if id == _environment_id and _profile == RenderProfile.current_profile():
			return
		_environment_id = id
		_profile = RenderProfile.current_profile()
		RenderProfile.apply_environment(environment, _profile)


func _ready() -> void:
	_profiles = JSON.parse_string(FileAccess.get_file_as_string("res://assets/quality_profiles.json")).profiles
	# Texture packages replace imported textures and must be mounted before any
	# scene loads them: use the saved profile; a change applies at next start.
	var saved := ConfigFile.new()
	var saved_profile := "balanced"
	if saved.load("user://imperathen_ui.cfg") == OK:
		saved_profile = str(saved.get_value("graphics", "quality", "balanced"))
	RenderProfile.mount_texture_package(RenderProfile.texture_tier(saved_profile))
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
	_environment_watcher = EnvironmentWatcher.new()
	_environment_watcher.name = "ProfileEnvironment"
	_environment_watcher.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(_environment_watcher)
	get_tree().node_added.connect(_on_node_added)
	set_diagnostics(false)
	if OS.is_debug_build() and OS.has_feature("android") and FileAccess.file_exists("user://graphics-probe.txt"):
		var probe = preload("res://scripts/ui/android_graphics_probe.gd").new()
		add_child.call_deferred(probe)


func apply_quality(profile: String) -> void:
	if not _profiles.has(profile):
		return
	_quality = profile
	_governor = SustainedQuality.initial(profile)
	var settings: Dictionary = _profiles[profile]
	_foreground_fps = 30 if profile in ["low", "very_high"] else 60
	_apply_frame_limit()
	var viewport := get_viewport()
	viewport.msaa_3d = Viewport.MSAA_4X if settings.msaa_samples == 4 else (Viewport.MSAA_2X if settings.msaa_samples == 2 else Viewport.MSAA_DISABLED)
	# Shadow atlases and filters, LOD threshold, anisotropy, AO quality and the
	# positional light budget (scripts/rendering/render_profile.gd).
	_render_applied = RenderProfile.apply_viewport(viewport, profile)
	_on_size_changed()


func _on_node_added(node: Node) -> void:
	if node is Light3D and node.is_in_group(RenderProfile.LIGHT_GROUP):
		RenderProfile.configure_light(node, _quality)


func _on_size_changed() -> void:
	# The window size is in output pixels. The canvas visible rectangle uses UI units.
	var output := get_window().size
	get_viewport().scaling_3d_scale = SustainedQuality.effective_render_scale(render_scale_for(output, _profiles[_quality], OS.has_feature("pc")), _governor)
	# A fold/resize or profile change starts a new, comparable measurement window.
	_reset_measurements()
	_place_overlay()


static func render_scale_for(output: Vector2i, settings: Dictionary, desktop: bool) -> float:
	var budget: float = settings.max_3d_pixels
	if desktop:
		budget = settings.get("desktop_max_3d_pixels", budget)
	var pixels := maxf(float(output.x) * float(output.y), 1.0)
	return clampf(sqrt(budget / pixels), 0.25, 1.0)


func set_sustained_scene(enabled: bool) -> void:
	# Gameplay keeps sampling even when the optional debug panel is hidden.
	# Exiting a world resets the dynamic scaling, but never the user's choice.
	if enabled == _sustained_scene:
		return
	_sustained_scene = enabled
	_sustained_paused = false
	if not enabled:
		_governor = SustainedQuality.initial(_quality)
		_on_size_changed()
	_update_diagnostics_processing()
	_reset_measurements()


func set_sustained_paused(value: bool) -> void:
	if _sustained_paused == value:
		return
	_sustained_paused = value
	_update_diagnostics_processing()
	_reset_measurements()


func quality_report() -> Dictionary:
	return {"selected":_quality,"foreground_cap":_foreground_fps,
		"sustained":_sustained_scene,"scene_paused":_sustained_paused,
		"dynamic_3d_ratio":float(_governor.get("ratio",1.0)),
		"effective_3d_scale":get_viewport().scaling_3d_scale,
		"renderer":RenderingServer.get_current_rendering_method(),
		"engine_switches":_render_applied.duplicate(true),
		"gpu_timing_available":RenderingServer.viewport_get_measured_render_time_gpu(get_viewport().get_viewport_rid())>0.0,
		"thermal_measured":false}


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
	var enabled := (_panel.visible or (_sustained_scene and not _sustained_paused)) and _application_active()
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
	if not _application_active() or not (_panel.visible or (_sustained_scene and not _sustained_paused)):
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

	# Only measured frame intervals may change the 3D buffer. The HUD remains
	# at native output resolution, and timing absence is never invented as 0 ms.
	if _sustained_scene and not _sustained_paused and _recent_times.size() >= SustainedQuality.MIN_SAMPLES:
		var measured := _recent_times.duplicate()
		measured.sort()
		var p95: float = measured[ceili(float(measured.size())*0.95)-1]
		var before_ratio := float(_governor.ratio)
		_governor = SustainedQuality.step(_quality,_governor,p95,gpu_ms,
			_recent_times.size(),_application_active())
		if absf(float(_governor.ratio)-before_ratio)>0.0001:
			_on_size_changed()
			if OS.is_debug_build():
				print("IMPERATHEN_ADAPTIVE_QUALITY " + JSON.stringify({
					"quality":_quality,"ratio":_governor.ratio,"reason":_governor.reason,
					"p95_ms":p95,"gpu_ms":gpu_ms if gpu_ms>0 else null,
					"thermal_measured":false}))
			return
	if _panel.visible and _sustained_scene:
		_label.text += "\n3D-Adaption: %d %% · Profil %s" % [roundi(float(_governor.ratio)*100.0),_quality]
	var output := get_window().size
	var internal := Vector2i((Vector2(output) * viewport.scaling_3d_scale).round())
	_label.text += "\n%s\n3D %d × %d · Ausgabe %d × %d" % [_adapter_line, internal.x, internal.y, output.x, output.y]
	if _units.x >= 0:
		_label.text += "\nSoldaten nah / mittel / fern: %d / %d / %d" % [_units.x, _units.y, _units.z]
	if OS.is_debug_build() and OS.has_feature("android"):
		var frame_p50: Variant = null
		var frame_p95: Variant = null
		var frame_p99: Variant = null
		if _recent_times.size() >= 10:
			var frame_values := _recent_times.duplicate()
			frame_values.sort()
			var amount := frame_values.size()
			frame_p50 = frame_values[ceili(amount*0.50)-1]
			frame_p95 = frame_values[ceili(amount*0.95)-1]
			frame_p99 = frame_values[ceili(amount*0.99)-1]
		print("IMPERATHEN_DISPLAY_SAMPLE " + JSON.stringify({
			"device_monotonic_ms": Time.get_ticks_msec(),
			"gpu": RenderingServer.get_video_adapter_name(), "quality": _quality,
			"renderer": RenderingServer.get_current_rendering_method(), "driver": RenderingServer.get_current_rendering_driver_name(),
			"fps": 1000.0 / frame_ms, "frame_rate_limit": Engine.max_fps,
			"mean_frame_ms": frame_ms, "frames": _sample_frames,
			"frame_p50_ms": frame_p50, "frame_p95_ms": frame_p95, "frame_p99_ms": frame_p99,
			"dynamic_3d_ratio": _governor.ratio,
			"thermal_measured":false,
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
