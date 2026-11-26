# Gefährten spielen und prüfen

Im regulären römischen Spiel lernt das Kind Marcus auf dem Marktweg kennen. Nach dem gemeinsamen Erlebnis kann es ihn im persönlichen Gespräch um Begleitung bitten. Auch Silvanus kann im Dorf angesprochen werden. Die zusätzlichen Einladungen, Fachkräfteverträge, freien Gesprächszeilen und Aufgabenreaktionen sind kreative Erweiterungen der vorhandenen Geschichte.

Über **Gefolge** im Spiel-HUD öffnet sich das Befehlsrad. Die Zielauswahl gilt für die nächste Bitte. **Gefährten ansehen** führt zur Personenansicht. Dort lassen sich Aufgaben verteilen, Rationen aus dem tatsächlichen Vorrat abgeben und Gegenstände überreichen oder zurücknehmen. Der erste Wanderstab kostet ein Holz, ein zurückgegebener Stab lässt sich erneut verwenden. Zum Üben gehen Kind, Lernender und Silvanus zusammen an den Übungspfahl. Eine angenommene Lektion schließt das Menü. Nach sechs gemeinsam am Platz verbrachten Simulationssekunden steigen Fähigkeit und Bindung.

Das Bildnis verwendet das aktuell sichtbare Figurenmodell und seine tatsächlichen Ausrüstungsaufsätze. Ziehen dreht die Figur. Ein eigenes SubViewport rendert beim Öffnen, Drehen und Größenwechsel. Die Bildnisfigur erhält keine Personen-ID, Kollision oder Spielaufgabe. Bei einem LOD-Wechsel bindet die Dorfansicht den Besitz an das ausgetauschte Skelett.

## Engine-Nachweise

| Prüfung | Ausführung und Ergebnis |
| --- | --- |
| HUD und Personenfenster | Godot 4.7.2, headless. 78 bestandene Prüfungen. Der Lauf erreicht die Freundschaft durch reguläre I-03-Entscheidungen, lädt beide Personen über die Gesprächswahl ein und öffnet das Rad mit einem Touchereignis. Er prüft einen Gruppenauftrag, Ausrüstungsübergabe, beaufsichtigte Ausbildung, Bildnisdrehung per Touch und Zurück-Navigation. Im älteren germanischen Spielpfad behält der bisherige Freund seine Herkunft, seinen Namen und seine gemeinsame Personen-ID beim tatsächlichen Beitritt. |
| Schmale und breite Anzeige | 400 × 800 und 800 × 400 im selben Prüflauf. Die vier Radaktionen haben mindestens 48 × 48 UI-Einheiten und überlappen sich nicht. Das Bildnis wechselt am schmalen Display über die Textspalte. |
| Grafikprofile | In Low, Balanced und Very High wurde jeweils von LOD 3 auf 0 gewechselt. Der ausgestattete Körper trug auf jeder Stufe genau einen Wanderstab. |
| Standbilder | 50 bestandene Prüfungen im grafischen Lauf bei 960 × 640. OpenGL Compatibility unter Mesa llvmpipe. Das Setup platziert die Körper für die Gesprächs- und Übergabeprüfung an begehbaren Punkten. Die Lichtstimmung stammt vom Spielkalender. |
| Durchgehender Film | 108 aufeinanderfolgende Frames des laufenden Godot-Viewports, 720 × 404, 12 Bilder pro Spielsekunde, 9 Sekunden. Nach dem Einrichten der Kamera und der Startpositionen laufen reale Bewegungs-, Ausrüstungs- und Trainingsbefehle. 48 bestandene Prüfungen einschließlich gemessenem Weg des Begleiters und durchlaufener zweiter Lektion. Die Bildrate ist die Aufnahmezeitbasis. |
| Decimus | Nach Integration von PR 129 und 131 bestanden alle 20 Prüfungen in `npc_behavior_ui_test.gd`, darunter die unveränderte Einführung im älteren Spielstand. |
| Kleidung und Markt | Der Kampagnenmarkt bestand 24 Prüfungen im grafischen Lauf. Die Szene lud die zivile Figur aus dem ursprünglichen italienischen Figurensatz. Der Figurentest bestand 16 Prüfungen mit beiden installierten Kleidungsvarianten. Die Kleidungsprüfung untersuchte 1.335 Posen je LOD anhand von 60 Hz und zusätzlich 240 Hz beim linken Aufwärtshieb. Sie fand keine gerissenen Dreieckskanten nach dem Prüfkriterium des Generators. Die größte gemessene Durchdringung zwischen Körper und Kleidung betrug 6,23 mm. |

[Gefährtenrad](evidence/befehlsrad.webp) · [Marcus mit Wanderstab](evidence/ausruestung.webp) · [Beaufsichtigte Übung](evidence/uebungsplatz.webp) · [Fähigkeit nach der Übung](evidence/training.webp) · [Film aus Valdora](evidence/valdora-uebung.mp4) · [Das Kind am Stadtmarkt](evidence/markt-zivilfigur.webp)

### Wiederholen

Die Prüfungen schreiben einen Kampagnenspeicherstand. Für jeden Lauf ein neues Datenverzeichnis verwenden.

```sh
run_dir=$(mktemp -d)
export XDG_CONFIG_HOME="$run_dir/config" XDG_DATA_HOME="$run_dir/data" XDG_CACHE_HOME="$run_dir/cache"
export IMPERATHEN_ISOLATED_TEST=1
godot --headless --path prototype --script res://tests/party_ui_test.gd
```

Für Standbilder auf einem grafischen Display `IMPERATHEN_PARTY_CAPTURE_DIR` auf ein leeres Zielverzeichnis setzen und den Test mit `--rendering-method gl_compatibility --fixed-fps 12` starten. Für den Film stattdessen `IMPERATHEN_PARTY_FRAMES` setzen. Im erzeugten Frame-Verzeichnis übernimmt FFmpeg die Bildfolge mit `ffmpeg -framerate 12 -i frame_%03d.png -frames:v 108 -c:v libx264 -crf 19 -pix_fmt yuv420p -movflags +faststart valdora-uebung.mp4`.

Der grafische Lauf meldete eine V-Sync-Warnung vom virtuellen X11-Display. Für eine Aussage zu Bildrate, Wärmeentwicklung und Akkulaufzeit des Fold7 fehlt eine Messung auf diesem Gerät.
