# C2 – Rendergrenzen und nachvollziehbare Bildzeitmessung

Stand: 24. November 2026. Ausgangspunkt: `7a21dca5dad83bf637cfbe9c02f4d9ab5cd97337`.

## Tatsächlicher Grafikstand

Der produktive Androidpfad verwendet weiterhin Godots **GL Compatibility**. Das ist direkt in `prototype/project.godot` sowohl für `renderer/rendering_method` als auch für dessen mobile Variante gesetzt. Ein Vulkan-Gerätetest oder eine Vulkan-Abnahme wird mit diesem Paket nicht behauptet. Die frühere Freigabegrenze für einen Rendererwechsel in `docs/23_handoff_sol/PLAN_CHATGPT_6_2_SOL.md` bleibt bestehen.

Die vier vorhandenen Profile aus `prototype/assets/quality_profiles.json` bleiben erhalten:

| Profil | Maximale Android-3D-Pixel | MSAA | Richtschattenweite | Vordergrundlimit |
| --- | ---: | ---: | ---: | ---: |
| Leicht | 921.600 | aus | 24 m | 30 FPS |
| Ausgewogen | 2.073.600 | 2× | 48 m | 60 FPS |
| Hoch | 3.686.400 | 4× | 85 m | 60 FPS |
| Sehr hoch | 5.760.000 | 4× | 110 m | 30 FPS |

Dies sind konfigurierte Obergrenzen, keine gemessenen Bildraten. UI-Auflösung, Bildseitenverhältnis und Vermeidung von Supersampling folgen weiterhin dem vorhandenen Viewportvertrag. Das JSON-Feld `glow` ist bisher nicht mit den Spielumgebungen verbunden; es ist deshalb kein Nachweis eines aktiven Glow-Effekts. Diese Lieferung verändert keine Shader, Materialien, Beleuchtung oder Spielfiguren.

## Reproduzierter Fehler

Eine isolierte Kopie des unveränderten `runtime_display.gd`, seiner direkten Hilfsdateien und der Profildefinitionen wurde mit Godot `4.7.2.stable.official.ed1daf0bf` im Headless-Modus ausgeführt. Der gezielt eingespeiste Fokusverlust ließ `Engine.max_fps` bei **60** und die Diagnoseverarbeitung aktiv. Ein anschließender Viewportwechsel bewahrte das vorbereitete alte Messfenster mit 45 Frames, zwei bisherigen Bildzeiten und dem alten Zeitstempel.

Damit war auf Codeebene belegt: Der Renderpfad begrenzte Hintergrundarbeit nicht gesondert; Profil-/Größenwechsel trennten die bisherigen Messwerte nicht vollständig. Der Versuch ist kein Android-Gerätetest und keine Beobachtung tatsächlicher Hintergrund-FPS.

## Änderung

`prototype/scripts/ui/runtime_display.gd` führt nun die gewählte Vordergrundgrenze getrennt vom momentan erlaubten Renderlimit. App-Pause oder Fokusverlust begrenzen laufende Hintergrunddarstellung auf höchstens **15 FPS**. Das ist eine vorsichtige technische Vorgabe, kein gemessenes thermisches Optimum. Ein vom Betriebssystem vollständig suspendierter Prozess rendert ohnehin nicht.

Fokus und Pause werden getrennt verfolgt. Erst wenn die App wieder fokussiert und fortgesetzt ist, wird die Grenze des weiterhin ausgewählten Profils wiederhergestellt. Ein Profilwechsel im Hintergrund kann die Hintergrundgrenze nicht aufheben. Die Spielsimulation, ihr Zeitmaß und das Speichern bleiben in ihren vorhandenen Zuständigkeiten.

Die freiwillige Diagnoseverarbeitung und die Renderzeitabfrage werden im Hintergrund ausgesetzt. Auch ein noch ausstehender Prozessaufruf darf dort weder Frames zählen noch Android-Diagnosezeilen ausgeben. Beim Wiederaufnehmen beginnt ein neues Messfenster; die persönliche Einstellung für die Diagnoseanzeige bleibt erhalten. Der Größenwechsel beim Falten sowie ein gültiger Profilwechsel verwerfen ebenfalls alte Mittelwertzähler, Perzentilsamples und Zeitstempel. Android-Diagnosezeilen enthalten zusätzlich die tatsächlich gesetzte `frame_rate_limit`.

## Prüfung

Der neue Test `prototype/tests/runtime_display_lifecycle_test.gd` verwendet das produktive Autoload. Er prüft beide Reihenfolgen von Fokus-/Pause-/Resume-Ereignissen, Profilwechsel im Hintergrund, die Diagnosepräferenz, einen noch anstehenden Hintergrundaufruf und die tatsächlich verbundene Viewport-Größenänderung. Die quadratische Testauflösung 2160 × 2160 ist eine Testgeometrie, keine Behauptung der Fold7-Displaydaten.

Der fokussierte Lauf mit isolierten Daten-/Konfigurations-/Cacheverzeichnissen bestand **30/30 Prüfungen**, Exitcode **0**, ohne Scriptfehler. Das vollständige Protokoll liegt unter [`evidence/render/runtime-display-lifecycle.log`](evidence/render/runtime-display-lifecycle.log).

Die Ereignisse werden gezielt in die Engine eingespeist. Erfolgreiche Verträge ersetzen weder einen echten Fold-/Hintergrundwechsel auf Android noch eine Bildzeit-, Energie- oder Wärmemessung auf dem Fold7. Der gemeinsame Prüflauf dokumentiert den aktuellen Ergebnisstand.

## API-Grundlage

- [Godot: `Engine.max_fps`](https://docs.godotengine.org/en/stable/classes/class_engine.html#class-engine-property-max-fps) beschreibt die Laufzeitgrenze als Obergrenze; die tatsächlich erzielte Bildrate kann darunter liegen.
- [Godot: Node-Benachrichtigungen](https://docs.godotengine.org/en/stable/classes/class_node.html#constants) unterscheidet App-Fokus von den mobilen Pause-/Resume-Ereignissen.
- [Godot: Rendering-Verfahren](https://docs.godotengine.org/en/stable/tutorials/rendering/renderers.html) beschreibt die verschiedenen Renderer und deren Fähigkeiten. Ein Wechsel allein belegt keine bessere Grafik oder Leistung auf dem Zielgerät.
