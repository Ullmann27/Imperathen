extends SceneTree
## Exercise the production autoload with independent focus/lifecycle events.

var checks := 0
var failures: Array[String] = []


func _initialize() -> void:
	if OS.get_environment("IMPERATHEN_ISOLATED_TEST") != "1":
		push_error("Run the display lifecycle test with isolated user data.")
		quit(2)
		return
	_run.call_deferred()


func _run() -> void:
	var display = root.get_node("RuntimeDisplay")
	display._notification(Node.NOTIFICATION_APPLICATION_RESUMED)
	display._notification(Node.NOTIFICATION_APPLICATION_FOCUS_IN)
	display.set_diagnostics(true)
	var caps := {"low": 30, "balanced": 60, "high": 60, "very_high": 30}
	for profile in caps:
		display.apply_quality(profile)
		_check(Engine.max_fps == caps[profile], "%s keeps its foreground limit" % profile)

	display.apply_quality("high")
	_seed_measurements(display)
	display._notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	_check(Engine.max_fps == 15, "Focus loss caps background rendering")
	_check(not display.is_processing(), "Focus loss suspends diagnostic callbacks")
	_check(display._panel.visible, "Focus loss preserves the user's diagnostic preference")
	_check_clean_window(display, "focus loss")
	display._process(10.0)
	_check_clean_window(display, "a pending background process callback")
	_check(display._label.text == "Bildzeitmessung pausiert.", "Background work is not presented as gameplay timing")
	display.apply_quality("very_high")
	_check(Engine.max_fps == 15 and display._quality == "very_high", "Profile changes in background retain the render cap")
	display._notification(Node.NOTIFICATION_APPLICATION_FOCUS_IN)
	_check(Engine.max_fps == 30 and display.is_processing(), "Focus return restores the newly selected 30 FPS profile")
	_check_clean_window(display, "focus return")

	# Resume and focus are independent on Android; neither can override a
	# still-pending pause/focus-loss event from the other notification family.
	display._notification(Node.NOTIFICATION_APPLICATION_PAUSED)
	display._notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	display.apply_quality("balanced")
	display._notification(Node.NOTIFICATION_APPLICATION_RESUMED)
	_check(Engine.max_fps == 15 and not display.is_processing(), "Resume while unfocused remains capped and unsampled")
	display._notification(Node.NOTIFICATION_APPLICATION_FOCUS_IN)
	_check(Engine.max_fps == 60 and display.is_processing(), "Focus after resume restores the selected 60 FPS limit")
	display._notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	display._notification(Node.NOTIFICATION_APPLICATION_PAUSED)
	display._notification(Node.NOTIFICATION_APPLICATION_FOCUS_IN)
	_check(Engine.max_fps == 15 and not display.is_processing(), "Focus while still paused cannot restore foreground rendering")
	display._notification(Node.NOTIFICATION_APPLICATION_RESUMED)
	_check(Engine.max_fps == 60 and display.is_processing(), "Resume after focus restores rendering")
	_check_clean_window(display, "resume after focus")

	display.set_diagnostics(false)
	display._notification(Node.NOTIFICATION_APPLICATION_PAUSED)
	display.apply_quality("low")
	display._notification(Node.NOTIFICATION_APPLICATION_RESUMED)
	_check(Engine.max_fps == 30, "The frame cap restores even when diagnostics were disabled")
	_check(not display.is_processing() and not display._panel.visible, "Resume never enables diagnostics against the user's setting")
	display._notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	display.set_diagnostics(true)
	_check(not display.is_processing(), "Enabling diagnostics in the background cannot start sampling")
	display._notification(Node.NOTIFICATION_APPLICATION_FOCUS_IN)
	_check(display.is_processing(), "Requested diagnostics begin on foreground return")

	_seed_measurements(display)
	display.apply_quality("balanced")
	_check_clean_window(display, "profile switch")
	# Emit the real connected resize signal after changing output dimensions.
	# No rendering delay or synthetic frame time is counted as a device sample.
	root.size = Vector2i(2160, 2160)
	_seed_measurements(display)
	root.size_changed.emit()
	_check(is_equal_approx(root.scaling_3d_scale, 2.0 / 3.0), "Square output retains the 2.07 MP budget after resize")
	_check_clean_window(display, "unfolded viewport")
	root.size = Vector2i(1280, 720)
	_seed_measurements(display)
	root.size_changed.emit()
	_check(is_equal_approx(root.scaling_3d_scale, 1.0), "Smaller output restores native 3D scale without supersampling")
	_check_clean_window(display, "smaller viewport")
	_check(Engine.max_fps == 60, "Resize preserves the selected foreground frame limit")

	_seed_measurements(display)
	display.apply_quality("not_a_profile")
	_check(display._quality == "balanced" and Engine.max_fps == 60, "Unknown profile cannot change active render settings")
	_check(display._sample_frames == 45, "Rejected profile cannot invalidate valid frame samples")
	display.set_diagnostics(false)
	display.apply_quality("balanced")
	if failures.is_empty():
		print("RUNTIME_DISPLAY_LIFECYCLE_PASS checks=%d; headless lifecycle and resize contracts, no device-performance claim" % checks)
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		quit(1)


func _seed_measurements(display: Node) -> void:
	display._sample_start = 1
	display._sample_frames = 45
	display._previous_frame_usec = 1234
	display._recent_times.assign([16.0, 17.0])


func _check_clean_window(display: Node, label: String) -> void:
	_check(display._sample_frames == 0 and display._previous_frame_usec == 0 and display._recent_times.is_empty() and display._sample_start > 1,
		"Fresh timing window after " + label)


func _check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures.append(label)
