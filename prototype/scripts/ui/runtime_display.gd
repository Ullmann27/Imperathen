extends CanvasLayer
## Opt-in frame measurements for the same viewport used by the village and valley.

const SafeArea = preload("res://scripts/ui/safe_area.gd")
const SustainedQuality = preload("res://scripts/rendering/fold7_quality_policy.gd")
const RenderProfile = preload("res://scripts/rendering/render_profile.gd")
const BACKGROUND_FPS := 15
const GOVERNOR_WINDOW_MS := 2000.0
const GOVERNOR_MAX_WINDOW_MS := 5000.0
const GOVERNOR_MAX_FRAMES := 360

var _profiles: Dictionary
var _quality := "balanced"
var _units := Vector3i(-1, -1, -1)
var _label: Label
var _panel: PanelContainer
var _sample_start := 0
var _sample_frames := 0
var _adapter_line := ""
var _previous_frame_usec := 0
# One-second diagnostic intervals are independent of governor windows.
var _recent_times: Array[float] = []
var _cpu_times: Array[float] = []
var _gpu_times: Array[float] = []
var _governor_frame_times: Array[float] = []
var _governor_gpu_times: Array[float] = []
var _governor_elapsed_ms := 0.0
var _last_gpu_observations: Dictionary = {}
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
		"gpu_timing_available":float(_last_gpu_observations.get("p95",-1.0))>0.0,
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
	_recent_times.clear()
	_cpu_times.clear()
	_gpu_times.clear()


func _clear_governor_window() -> void:
	_governor_frame_times.clear()
	_governor_gpu_times.clear()
	_governor_elapsed_ms = 0.0


func _reset_measurements() -> void:
	_previous_frame_usec = 0
	_restart_sample()
	_clear_governor_window()
	_last_gpu_observations.clear()
	# Focus, pause, resize and profile changes break consecutive evidence.
	# Keep the selected scale and any active post-adjustment cooldown.
	_governor.slow = 0
	_governor.fast = 0
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


## Consume each disjoint gameplay window at most once. A slow 30 FPS
## profile still gathers enough observations. A very slow or interrupted
## window cannot grow indefinitely or continue a previous pressure streak.
func _sample_governor(frame_ms: float, gpu_ms: float) -> bool:
	if not _sustained_scene or _sustained_paused or not _application_active() or not SustainedQuality.adaptive(_quality):
		return false
	if not is_finite(frame_ms) or frame_ms <= 0.0:
		return false
	_governor_frame_times.append(frame_ms)
	_governor_elapsed_ms += frame_ms
	if is_finite(gpu_ms) and gpu_ms > 0.0:
		_governor_gpu_times.append(gpu_ms)
	var count := _governor_frame_times.size()
	var ready := _governor_elapsed_ms >= GOVERNOR_WINDOW_MS and count >= SustainedQuality.MIN_SAMPLES
	if not ready and _governor_elapsed_ms < GOVERNOR_MAX_WINDOW_MS and count < GOVERNOR_MAX_FRAMES:
		return false
	if not ready:
		_clear_governor_window()
		_governor.slow = 0
		_governor.fast = 0
		return false
	var wall := SustainedQuality.observation_summary(_governor_frame_times,count)
	var gpu := SustainedQuality.observation_summary(_governor_gpu_times,count)
	_clear_governor_window()
	var before := float(_governor.ratio)
	_governor = SustainedQuality.step(_quality,_governor,float(wall.p95),float(gpu.p95),count,_application_active())
	var changed := absf(float(_governor.ratio)-before)>0.0001
	if changed and OS.is_debug_build():
		print("IMPERATHEN_ADAPTIVE_QUALITY " + JSON.stringify({
			"quality":_quality,"ratio":_governor.ratio,"reason":_governor.reason,
			"p95_ms":wall.p95,"gpu_observation_p95_ms":gpu.p95 if float(gpu.p95)>0.0 else null,
			"gpu_observations":gpu.count,"frame_intervals":count,
			"thermal_measured":false}))
	return changed


func _process(_delta: float) -> void:
	if not _application_active() or not (_panel.visible or (_sustained_scene and not _sustained_paused)):
		return
	var now := Time.get_ticks_usec()
	var viewport := get_viewport()
	var rid := viewport.get_viewport_rid()
	var cpu_ms := -1.0
	var gpu_ms := -1.0
	if _previous_frame_usec > 0:
		var frame_ms := (now - _previous_frame_usec) * 0.001
		if is_finite(frame_ms) and frame_ms > 0.0:
			# Godot exposes the latest completed render timing, not its frame ID.
			# Poll once per process interval without assuming unique GPU frames.
			if DisplayServer.get_name() != "headless":
				cpu_ms = RenderingServer.viewport_get_measured_render_time_cpu(rid)
				gpu_ms = RenderingServer.viewport_get_measured_render_time_gpu(rid)
			_recent_times.append(frame_ms)
			_sample_frames += 1
			if is_finite(cpu_ms) and cpu_ms > 0.0:
				_cpu_times.append(cpu_ms)
			if is_finite(gpu_ms) and gpu_ms > 0.0:
				_gpu_times.append(gpu_ms)
			if _sample_governor(frame_ms,gpu_ms):
				_on_size_changed()
				return
	_previous_frame_usec = now
	if now - _sample_start < 1000000 and _recent_times.size() < GOVERNOR_MAX_FRAMES:
		return
	var count := _recent_times.size()
	if count == 0:
		_restart_sample()
		return
	var frame_total := 0.0
	for value: float in _recent_times:
		frame_total += value
	var mean_ms := frame_total / float(count)
	var wall := SustainedQuality.observation_summary(_recent_times,count)
	var cpu := SustainedQuality.observation_summary(_cpu_times,count)
	var gpu := SustainedQuality.observation_summary(_gpu_times,count)
	_last_gpu_observations = gpu.duplicate()
	# A release build with the HUD hidden needs no memory-file reads or
	# diagnostic formatting. Debug Android retains one-second ADB telemetry.
	var publish := OS.is_debug_build() and OS.has_feature("android")
	if not _panel.visible and not publish:
		_restart_sample()
		return
	var ram := _resident_memory_kib()
	var draws := viewport.get_render_info(Viewport.RENDER_INFO_TYPE_VISIBLE, Viewport.RENDER_INFO_DRAW_CALLS_IN_FRAME)
	var primitives := viewport.get_render_info(Viewport.RENDER_INFO_TYPE_VISIBLE, Viewport.RENDER_INFO_PRIMITIVES_IN_FRAME)
	var output := get_window().size
	if _panel.visible:
		_label.text = "%.1f FPS · %.1f ms/Bild\nRender-CPU P95 %s · GPU-Beobachtungen P95 %s\nRAM (RSS) %s · %d Draw Calls\n%d sichtbare Primitive" % [
			1000.0 / mean_ms, mean_ms, _timing(float(cpu.p95)), _timing(float(gpu.p95)),
			"%.1f MiB" % (ram / 1024.0) if ram > 0 else "unbekannt", draws, primitives]
		if count >= 10:
			_label.text += "\nBildzeit P50/P95/P99: %.1f / %.1f / %.1f ms" % [wall.p50,wall.p95,wall.p99]
		if _sustained_scene:
			_label.text += "\n3D-Adaption: %d %% · Profil %s" % [roundi(float(_governor.ratio)*100.0),_quality]
		var internal := Vector2i((Vector2(output) * viewport.scaling_3d_scale).round())
		_label.text += "\n%s\n3D %d × %d · Ausgabe %d × %d" % [_adapter_line, internal.x, internal.y, output.x, output.y]
		if _units.x >= 0:
			_label.text += "\nSoldaten nah / mittel / fern: %d / %d / %d" % [_units.x, _units.y, _units.z]
	if publish:
		print("IMPERATHEN_DISPLAY_SAMPLE " + JSON.stringify({
			"device_monotonic_ms": Time.get_ticks_msec(),
			"gpu": RenderingServer.get_video_adapter_name(), "quality": _quality,
			"renderer": RenderingServer.get_current_rendering_method(), "driver": RenderingServer.get_current_rendering_driver_name(),
			"fps": 1000.0 / mean_ms, "frame_rate_limit": Engine.max_fps,
			"mean_frame_ms": mean_ms, "frames": count,
			"frame_p50_ms": wall.p50 if count>=10 else null,
			"frame_p95_ms": wall.p95 if count>=10 else null,
			"frame_p99_ms": wall.p99 if count>=10 else null,
			"dynamic_3d_ratio": _governor.ratio,
			"thermal_measured":false,
			"render_cpu_ms": cpu_ms if is_finite(cpu_ms) and cpu_ms>0.0 else null,
			"render_gpu_ms": gpu_ms if is_finite(gpu_ms) and gpu_ms>0.0 else null,
			"render_cpu_observation_p95_ms":cpu.p95 if float(cpu.p95)>0.0 else null,
			"render_gpu_observation_p50_ms":gpu.p50 if float(gpu.p50)>0.0 else null,
			"render_gpu_observation_p95_ms":gpu.p95 if float(gpu.p95)>0.0 else null,
			"render_gpu_observation_p99_ms":gpu.p99 if float(gpu.p99)>0.0 else null,
			"gpu_observations":gpu.count,"cpu_observations":cpu.count,
			"rss_kib": ram if ram > 0 else null, "visible_primitives": primitives,
			"draw_calls": draws, "near_mid_far": [_units.x, _units.y, _units.z],
			"output": [output.x,output.y], "scale_3d": viewport.scaling_3d_scale}))
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
