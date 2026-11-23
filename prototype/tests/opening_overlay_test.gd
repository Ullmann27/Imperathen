extends SceneTree
## Real Control layout/input checks; no renderer/FPS or physical-device claim.

const Overlay = preload("res://scripts/ui/opening_overlay.gd")
var ui
var counts := {"advance": 0, "pause": 0, "skip": 0, "reading": 0}
var failures := 0
var checks := 0
var sample := {
	"id": "well", "speaker": "Marcus", "role": "Am Brunnen",
	"text": "Die Halterung ist gebrochen. Vier Stücke Holz reichen für die Reparatur. Wenn du etwas übrig hast, können wir es gemeinsam versuchen.",
	"chapter": "Ein Dach für die Nacht", "location": "Ein Dorf an der Straße nach Rom"
}


func _initialize() -> void:
	_run.call_deferred()


func _frames() -> void:
	for frame in 6:
		await process_frame


func _check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("FAIL ", message)


func _run() -> void:
	root.content_scale_size = Vector2i.ZERO
	root.size = Vector2i(1280, 720)
	ui = Overlay.new()
	ui.configure({"ui_scale": 1.25, "reduce_motion": true, "touch_enabled": true})
	root.add_child(ui)
	ui.advance_requested.connect(func(): counts.advance += 1)
	ui.pause_requested.connect(func(): counts.pause += 1)
	ui.skip_requested.connect(func(): counts.skip += 1)
	ui.reading_mode_changed.connect(func(_enabled: bool): counts.reading += 1)
	ui.present(sample, 1, 5)
	await _frames()
	_check(ui.visible and ui._speaker.text.contains("MARCUS") and ui._text.text == sample.text, "Live cue is readable with its actual speaker")
	_check(ui._panel.modulate.a == 1.0, "Reduced motion shows the complete subtitle immediately")
	_check(root.gui_get_focus_owner() == ui._advance_button, "Continue has keyboard and controller focus")
	_check(sample.size() == 6 and not sample.has("final"), "Presentation does not mutate the supplied story")
	for size in [Vector2i(1280,720), Vector2i(960,540), Vector2i(820,480), Vector2i(900,900), Vector2i(480,840)]:
		root.size = size
		await _frames()
		_bounds(Rect2(Vector2.ZERO, Vector2(size)), str(size))
		_check(ui._text.text == sample.text and counts.advance == 0 and counts.skip == 0, "Resize keeps cue and decisions: " + str(size))
	root.size = Vector2i(960,540)
	await _frames()
	ui._safe_override = Rect2(42,18,876,486)
	ui._queue_layout()
	await _frames()
	_bounds(ui._safe_override, "Fold screen with cutout/navigation insets")
	ui.set_progress(0.42)
	ui.set_paused(true)
	ui.set_manual_reading(true)
	root.size = Vector2i(900,900)
	ui._safe_override = Rect2()
	await _frames()
	_check(ui._paused and ui._manual_reading and is_equal_approx(ui._story_line.progress,0.42), "Folding preserves pause, manual reading and shot progress")
	_check(ui.handle_back() and counts.pause == 1 and counts.skip == 0, "Android Back requests pause, never skips the narrative")
	var escape := InputEventKey.new()
	escape.pressed = true
	escape.keycode = KEY_ESCAPE
	root.push_input(escape, true)
	_check(counts.pause == 2 and counts.skip == 0, "Escape requests pause without discarding a cue")
	var controller := InputEventJoypadButton.new()
	controller.button_index = JOY_BUTTON_START
	controller.pressed = true
	root.push_input(controller, true)
	_check(counts.pause == 3, "Controller Start uses the same pause intent")
	_touch(1, true, ui._reading_button.get_global_rect().get_center())
	_touch(1, false, ui._reading_button.get_global_rect().get_center())
	_check(counts.reading == 1 and not ui._manual_reading, "Native touch toggles reading mode once")
	var enter := InputEventKey.new()
	enter.keycode = KEY_ENTER
	enter.pressed = true
	ui._unhandled_input(enter)
	_check(counts.advance == 0 and not ui._advance_pending and ui._advance_button.disabled, "Enter during pause cannot consume the pending continue action")
	ui.set_paused(false)
	await _frames()
	_touch(2, true, ui._advance_button.get_global_rect().get_center())
	_touch(2, false, ui._advance_button.get_global_rect().get_center())
	_check(counts.advance == 1, "Native touch requests the next cue once")
	ui._advance_button.pressed.emit()
	_check(counts.advance == 1, "A pending advance cannot emit twice for the same cue")
	ui.present(sample, 2, 5)
	await _frames()
	_touch(3, true, ui._skip_button.get_global_rect().get_center())
	_touch(3, false, ui._skip_button.get_global_rect().get_center())
	ui._skip_button.pressed.emit()
	_check(counts.skip == 1 and counts.advance == 1, "Explicit skip has a separate once-only intent")
	var final_cue := {"final":true,"objective":true,"chapter":"Ein neues Kapitel", "location":"Der Trainingsplatz", "advance_label":"Zur Ausbildung", "objective_title":"Dein eigener Weg", "objective_text":"Sprich mit Aulus. Die Ausbildung beginnt erst, wenn du bereit bist."}
	ui.present(final_cue, 4, 5)
	await _frames()
	_check(ui._objective_heading.visible and ui._objective_text.text == final_cue.objective_text and not ui._text.visible, "The last cue presents the actual first objective without duplicate dialogue")
	_check(ui._advance_button.text == "Zur Ausbildung" and not ui._skip_button.visible, "Adult handoff has its own explicit action and no skip bypass")
	_check(counts.advance == 1, "Showing the first objective never starts gameplay automatically")
	_touch(4, true, ui._advance_button.get_global_rect().get_center())
	ui.set_paused(true)
	ui.notification(Node.NOTIFICATION_APPLICATION_PAUSED)
	_check(ui._advance_button.touch_index == -1, "Backgrounding clears held native input")
	ui.notification(Node.NOTIFICATION_APPLICATION_RESUMED)
	await _frames()
	_check(ui._paused and ui._manual_reading == false, "Foregrounding does not resume the story or alter reading preference")
	ui.finish()
	ui._advance_button.pressed.emit()
	ui._skip_button.pressed.emit()
	ui._pause_button.pressed.emit()
	_check(not ui.visible and not ui.handle_back() and counts.advance == 2 and counts.skip == 1 and counts.pause == 3, "Closed overlay releases input and emits no stale actions")
	ui.queue_free()
	await _frames()
	print("OPENING_OVERLAY_RESULT checks=%d failures=%d; headless layout/input, not hardware rendering" % [checks,failures])
	quit(1 if failures else 0)


func _bounds(region: Rect2, name: String) -> void:
	for control in [ui._panel,ui._reading_button,ui._pause_button,ui._skip_button,ui._advance_button]:
		if control.is_visible_in_tree():
			_check(region.grow(0.6).encloses(control.get_global_rect()), "%s: %s stays inside safe area (%s)" % [name,control.name,control.get_global_rect()])
	_check(not ui._panel.get_global_rect().intersects(ui._toolbar.get_global_rect()), name + ": subtitle never covers playback controls")
	_check(ui._advance_button.size.y >= 48 and ui._pause_button.size.y >= 48, name + ": touch actions retain usable height")


func _touch(index: int, pressed: bool, position: Vector2) -> void:
	var event := InputEventScreenTouch.new()
	event.index = index
	event.pressed = pressed
	event.position = position
	root.push_input(event, true)
