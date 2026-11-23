# Verzögerte Mausemulation nach Touch-Release: A/B-Probe

## Ergebnis und geprüfter Umfang

Am 23. November 2026 mit **Godot 4.7.2.stable.official.ed1daf0bf**, headless, ausgeführt: **8 Prüfungen, 0 Fehler**, Prozessende 0. Die Probe verwendete die tatsächlichen Touchpad-Skripte in einer minimalen Szene und konstruierte gezielt verzögerte Eingabeereignisse. Sie führte kein Android-APK aus.

- **A:** unverändertes `prototype/scripts/ui/touch_pad.gd` aus `98bec146310877a60d2bfb36f5aa42d6f82abbce`.
- **B:** dasselbe Skript im gemergten Arbeitsstand; die Emulationsfilterung stammt aus `e5735509622c9a94564dc5fe21257c07074f9df5`.
- Betroffene Methoden: `TouchPad._input()`, `_update_axis()` und `reset()`.

Beide Pads erhalten zunächst `InputEventScreenTouch` mit Index 3, Press und Release. Nach einer tatsächlichen Timerpause von 230 ms wird ein `InputEventMouseButton` mit `device = InputEvent.DEVICE_ID_EMULATION`, linker Taste und `pressed = true` zugestellt. Damit liegt das Ereignis außerhalb der bisherigen 180-ms-Unterdrückung. Die Probe verändert diesen privaten Timer nicht.

| Prüfung | Beobachtetes Ergebnis |
|---|---|
| 1–2: ursprünglicher Pad, Touch-Press und Release | Press erzeugt Achse > 0,4 und besitzt Index 3; Release setzt Achse auf Null und Index auf −1. |
| 3–4: gemergter Pad, Touch-Press und Release | Dasselbe reguläre Verhalten bleibt erhalten. |
| 5: ursprünglicher Pad, verzögerter synthetischer Mausdruck | Er übernimmt den Pointer erneut: Achse > 0,4, `_mouse_captured = true`. |
| 6: gemergter Pad, derselbe synthetische Mausdruck | Achse bleibt exakt Null, `_mouse_captured = false`. |
| 7–8: gemergter Pad, physische Maus mit `device = 0` | Press steuert weiterhin; Release setzt Achse und Besitz sauber zurück. |

## Schlussfolgerungsgrenze

Die Probe belegt den konkreten alten Fehlerpfad: Ein verspäteter synthetischer Mausdruck kann nach bereits verarbeitetem Touch-Release erneut Bewegung auslösen. Der gemergte Filter verhindert diesen Pfad und erhält reguläre Mausbedienung. Geprüft wird die tatsächliche Ereignisverarbeitung des Skripts; die Ereignisreihenfolge wird bewusst konstruiert und beweist keine bestimmte native Android-Ereignisreihenfolge.

Der fehlgeschlagene Android-Lauf `45192941027`, Job `137755780772`, verwendete Commit A und meldete nach einer 450-ms-Geste 2,3887 m Bewegung. Seine zwei Positionsbeobachtungen enthalten keinen Pointerbesitz. Daher lässt sich daraus **nicht sicher ableiten, dass gerade der hier reproduzierte Pfad diesen Lauf verursacht hat**. Zusätzlich verwendete A allgemein 4,6 m/s, während der gemergte Stand für kindliches Gehen 1,5 m/s verwendet. Die Anteile dieser Ursachen sind mit den vorhandenen Android-Beobachtungen nicht bestimmbar. Eine neue native Android-Prüfung bleibt erforderlich; die zulässige Gestendistanz wurde nicht erhöht.

## Reproduktion

Aus der Repositorywurzel mit installiertem Godot ausführen. Die Befehle erstellen ausschließlich ein temporäres Miniprojekt. Die acht Prüfungen entsprechen der ausgeführten Probe; `TouchPad._input()` wird direkt mit den konstruierten Ereignissen aufgerufen.

```bash
touch_probe_dir="$(mktemp -d)"
git show 98bec146310877a60d2bfb36f5aa42d6f82abbce:prototype/scripts/ui/touch_pad.gd > "$touch_probe_dir/old_touch_pad.gd"
cp prototype/scripts/ui/touch_pad.gd "$touch_probe_dir/merged_touch_pad.gd"
cat > "$touch_probe_dir/project.godot" <<'PROJECT'
config_version=5
[application]
config/name="Touch release regression"
[rendering]
renderer/rendering_method="gl_compatibility"
PROJECT
cat > "$touch_probe_dir/check.gd" <<'GDSCRIPT'
extends SceneTree

var failures: Array[String] = []
var checks := 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	root.size = Vector2i(800,600)
	var old_pad: Control = load("res://old_touch_pad.gd").new()
	var merged_pad: Control = load("res://merged_touch_pad.gd").new()
	old_pad.size = Vector2(200,200)
	merged_pad.size = Vector2(200,200)
	merged_pad.position = Vector2(300,0)
	root.add_child(old_pad)
	root.add_child(merged_pad)
	await process_frame
	for pad: Control in [old_pad,merged_pad]:
		var point := pad.get_global_rect().get_center() + Vector2(50,0)
		var down := InputEventScreenTouch.new()
		down.index = 3
		down.position = point
		down.pressed = true
		pad._input(down)
		_check(pad.axis.x > .4 and pad.touch_index == 3, "Actual screen pointer controls " + pad.get_script().resource_path)
		var up := down.duplicate()
		up.pressed = false
		pad._input(up)
		_check(pad.axis == Vector2.ZERO and pad.touch_index == -1, "Screen release clears " + pad.get_script().resource_path)
	# Exercise the actual timestamp boundary; do not modify the private timer.
	await create_timer(.23).timeout
	for pad: Control in [old_pad,merged_pad]:
		var delayed := InputEventMouseButton.new()
		delayed.button_index = MOUSE_BUTTON_LEFT
		delayed.device = InputEvent.DEVICE_ID_EMULATION
		delayed.pressed = true
		delayed.position = pad.get_global_rect().get_center() + Vector2(50,0)
		pad._input(delayed)
	_check(old_pad.axis.x > .4 and old_pad._mouse_captured, "98bec reproduces ownership reacquisition from delayed synthetic press")
	_check(merged_pad.axis == Vector2.ZERO and not merged_pad._mouse_captured, "Merged input ignores delayed synthetic press after release")
	var real_mouse := InputEventMouseButton.new()
	real_mouse.button_index = MOUSE_BUTTON_LEFT
	real_mouse.device = 0
	real_mouse.pressed = true
	real_mouse.position = merged_pad.get_global_rect().get_center() + Vector2(50,0)
	merged_pad._input(real_mouse)
	_check(merged_pad.axis.x > .4 and merged_pad._mouse_captured, "A physical desktop mouse still controls the merged pad")
	real_mouse.pressed = false
	merged_pad._input(real_mouse)
	_check(merged_pad.axis == Vector2.ZERO and not merged_pad._mouse_captured, "Physical mouse release still clears the merged pad")
	print("DELAYED_TOUCH_RELEASE_AB ", JSON.stringify({"checks":checks,"failures":failures,
		"old_source":"98bec146310877a60d2bfb36f5aa42d6f82abbce",
		"scope":"actual production touch scripts in a minimal headless scene; constructed delayed emulation events, no Android execution"}))
	quit(0 if failures.is_empty() else 1)


func _check(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failures.append(label)
		printerr(label)
GDSCRIPT
godot --headless --path "$touch_probe_dir" --script res://check.gd
```

Erwarteter Abschlussmarker: `DELAYED_TOUCH_RELEASE_AB` mit `"checks":8` und `"failures":[]`. Ein fehlgeschlagener Einzelcheck führt zu Prozessende 1.
