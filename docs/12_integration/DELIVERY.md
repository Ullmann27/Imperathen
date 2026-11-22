# IMPERATHEN · Android, Talgefecht und saisonale Weltkampagne

**Spielstand vom 22. November 2026.** Android, Windows und Linux werden aus demselben Godot-Projekt gebaut. Die APK ist ein mit einem privaten Debugschlüssel signierter Prüfbau. [Spielanleitung](../../prototype/README.md) · [Pull Request #22](https://github.com/Ullmann27/Imperathen/pull/22)

## Aktuelle Fassung mit Figurengalerie

Spielquellen `a2d321d87a340a8a38b09eba34f5fc548d69a73c`. Hauptmenü → **Figuren** öffnet die Sammlung der 18 Personen. Im gespeicherten Lebenslauf zeigt die Chronik die Hauptfigur und den Gefährten der gewählten Herkunft. Bei der ersten Begegnung ist der junge Gefährte im Dialog zu sehen. Im italienischen Lebenslauf kommen ab 18 zwei weitere Darstellungen hinzu. Erstellt wurden drei Figurenbögen und drei separate hochauflösende Bilder für Legionär, Kaiser und erwachsene Hauptfigur. Die 3D-Kampfszene verwendet weiterhin die vier animierten Blender-Figuren. [Freigegebene Downloads](https://github.com/Ullmann27/Imperathen/releases/tag/prototype-2026-11-22-a2d321d8) · [Darsteller und Bildquellen](../../art/portraits/README.md) · [Galerie im Spiel](evidence/portraits/legionary.webp) · [Aki in der Chronik](evidence/portraits/chronicle-wa.webp)

Alle elf Godot-Prüfgruppen bestanden. Der lokale Galerietest meldete 49 erfolgreiche Prüfungen mit echten Texturen. Er öffnete alle 18 Darstellungen, durchlief die Kategorien, prüfte Aki im ersten Dialog und den Rückweg in die pausierte Chronik ohne Änderung am Weltzustand. Der alte Dorfspielstand bleibt ladbar. [Galerieprotokoll](evidence/portraits/figure_gallery.log) · [Alle Gruppen](evidence/portraits/validation_report.json) · [Buildlauf](https://github.com/Ullmann27/Imperathen/actions/runs/45040762060)

Die 64.802.890 Byte große ARM64-APK trägt SHA-256 `f88f0b8a5359744bfbe1284679bc9d19878edda324c0dce6eacf1cb30911ebf3`. 37 von 37 Android-15-Laufzeitprüfungen bestanden. Der x86-64-Prüfbau zeichnete den Legionär nach einem echten Tipp im Menü und kehrte per Android-Zurück zurück. Seine 18 importierten Texturen entsprechen bytegenau denen der ARM64-APK. Die veröffentlichte ARM64-Datei startete per Übersetzung bis zum sichtbaren Vorspann. Die Windows-EXE startete unter Wine und der Linux-Build nativ, jeweils im grafischen Fenster. [Originaler Android-Screenshot](evidence/portraits/android-gallery.webp) · [Laufzeitbericht](evidence/portraits/runtime.json) · [Alle Prüfsummen](https://github.com/Ullmann27/Imperathen/releases/download/prototype-2026-11-22-a2d321d8/IMPERATHEN-a2d321d8-SHA256SUMS.txt)

## Basisbuild vor der Figurengalerie

| Download aus demselben Build | Größe in Byte | SHA-256 |
| --- | ---: | --- |
| [Android ARM64, APK](https://github.com/Ullmann27/Imperathen/releases/download/prototype-2026-11-22-02c56681/IMPERATHEN-02c56681-arm64.apk) | 58.597.583 | `dede9302c2f96b3b4908aba04c7d50675215c1fa5bdca2812618695501295cc2` |
| [Windows x86-64, ZIP](https://github.com/Ullmann27/Imperathen/releases/download/prototype-2026-11-22-02c56681/IMPERATHEN-02c56681-Windows-x86_64.zip) | 64.047.242 | `15a0577ad440c4966cb32499b1861aad54c4dc673c5ebd84383cf43802de86c2` |
| [Linux x86-64, tar.gz](https://github.com/Ullmann27/Imperathen/releases/download/prototype-2026-11-22-02c56681/IMPERATHEN-02c56681-Linux-x86_64.tar.gz) | 57.126.600 | `f8bc67b2410945fe491afa85e61904e3eaf60798558e2d36c7b98c55e0ef002a` |

Der gebaute Commit ist `02c566815deebabe6b96c2f25ec0c52a94d35415`, Paketkennung `at.heinz.imperathen`. Für nachfolgende Änderungen am Android-Prüfläufer und an der Dokumentation bleibt dieser ausführbare Spielstand die Referenz. Die CI-Artefakte enthalten zusätzliche Exportnachweise und die separate x86-64-Emulator-APK. [Bauprotokoll](https://github.com/Ullmann27/Imperathen/actions/runs/45038276162) · [Android-Artefakte](https://github.com/Ullmann27/Imperathen/actions/runs/45038276162/artifacts/14760198132) · [Desktop-Artefakte](https://github.com/Ullmann27/Imperathen/actions/runs/45038276162/artifacts/14760473062)

**Gleich ausprobieren.** Im Hauptmenü zuerst die Herkunft wählen und mit *Neues Leben* das Dorf betreten. *Talgefecht erproben* öffnet in Pause eine Schlacht mit 30 gegen 30 Soldaten. Eine Kohorte auswählen, mit langem Druck und Ziehen ihre Front aufstellen und die Zeit fortsetzen. *Weltkugel erkunden* öffnet den Saisonmodus. Eine andere Herkunft lässt sich im Hauptmenü wählen.

## Zusammenführung und Arbeitsteilung

| Grundlage | Integrierter Git-Stand | Nutzung |
| --- | --- | --- |
| #1 | `a3e036b` | Governance, Abnahmematrix, GDD-Auswertung und Fachverträge |
| #19 | `201298a` | Unreal-Projekt, Webvorschau und bestehende Agentenwerkzeuge |
| #20 | `ea430f5`, Laufzeitkorrekturen bis `b3d8e01`, Lieferbelege `11909b7` | Godot-Dorf, Gefährte, Bau, persönlicher Kampf, geprüfte Speicherung und Android-Bauweg |
| #21 | `1afdbf4` | Originalassets, Blender-Quellen, Schauraum und Qualitätsstufen |

Die drei Entwicklungsagents arbeiteten in getrennten Dateibereichen. Agent A lieferte Regeln, Formationen, KI und Tests (`6a24724`, `a4260d8`, `d07fd51`). Agent B lieferte Rigs, Animation, Architektur, Vegetation und Freisteller (`8ace3c8`, `be3863b`, `4caf7d5`, `94ee544`). Agent C betreute Export, Diagnose, Safe-Area- und Emulatorprüfungen für Android und Desktop (`3d72400`, `b35e3ac`, `035e263`). Die Integration verband die Szenen mit der Kampagne (`90a2617`, `eb0d6b2`) und prüfte die Ergebnisse (`ffffaf9`, `02c5668`). Der separate Integrationsbranch heißt `integration/android-formation-20261122` und basiert im PR auf `docs/bootstrap-governance-20261122`. [Engineentscheidung und Projektbibel](../03_engineering/ADR_GODOT_ANDROID.md)

**Reihenfolge.** Zunächst wurde der integrierte Dorfstand `ebcf2d8` als echte ARM64-APK exportiert. Der lokale 28.698.864-Byte-Bau hatte SHA-256 `5e3f049bd5e93ffa647a3395be648f5c11d44dd56b0acbf40ad608a8ad311e87`. Erst danach entstanden Formationskampf, animierte Truppen und die neue Kampagne. [Dorf-Baulauf](https://github.com/Ullmann27/Imperathen/actions/runs/45035264853) · [Android-Exportanleitung](../10_development/ANDROID_BUILD.md)

## Spielsysteme

- **Gefechtsführung.** Beide Armeen arbeiten mit festen Identitäten für Verbände, Kohorten und Soldaten. Linie, Marschkolonne, Schildwall, Testudo, Keil, lockere Ordnung und Phalanx berechnen räumliche Plätze. Ausrüstung, benötigte Zeit, Gelände und Feinddruck beeinflussen die Aufstellung. Spieler können bewegen, halten, Formation wechseln, die Front ziehen, angreifen, im Angriff vorrücken, verteidigen, flankieren, zurückziehen, sammeln, Reserve bilden, Fernfeuer konzentrieren und Feuer einstellen. Maus und Touch geben dieselben Regelbefehle. Die Ausdauer, Verluste und Befehle überstehen den Szenenwechsel.
- **Gefecht und Folgen.** Die KI berücksichtigt Gelände, Flanken, Fernkämpfer, Reserven und Moral. Reichweite, Schildrichtung, Ausrüstung und Ermüdung wirken auf den vom Regelkern bestimmten Treffer. Angriffsereignisse lösen den zugehörigen Clip aus. Ein verlorenes Tal verteuert die spätere Nachschubroute. Der Gefechtskern löst Treffer auf Verbandsebene auf. Schwert- und Speerklingen haben keine physikalisch simulierten Einzelkontakte.
- **Lebenslauf.** Das bekannte Dorfkapitel bleibt spielbar. Fünf Herkünfte verändern den Ort, seine Ausstattung, den Gefährten und mindestens eine regionale Entscheidung samt späterer Folge. Alle verwenden dasselbe Dorfkapitel und dieselben Grundregeln. Die Auswahl umfasst das römische Italien, Gemeinschaften östlich des Rheins, den Weichselraum, die Östlichen Han und Wa der Yayoi-Zeit.
- **Welt und Jahreszeiten.** Die drehbare Reliefkugel enthält 32 spielbare, verbundene Orte auf sechs bewohnten Kontinenten und im Pazifik. Vier Saisons ergeben ein Jahr. Südliche Auftragsgebiete haben einen versetzten Winter. Mit Ernte und Einlagerung lässt sich die Versorgung vorbereiten. Frühe Engpässe erlauben Erholung, wiederholt verfehlte Winter können einen Auftrag beenden. Ein größeres Mandat erhöht den Bedarf und mögliche Gebietsverluste. Der Test eroberte alle 32 Regionen über zulässige Züge und verlor nach absichtlich schlechter Versorgung sieben. Die Jahresrechnung aktualisiert auch das Alter im verbundenen Lebenslauf.
- **Speichern.** Schema 3 übernimmt ältere Dorfspielstände, schreibt temporär, prüft die Nutzdaten und lädt bei Beschädigung die letzte gültige Sicherung. Persistierte Verluste und IDs vermeiden zusätzliche Soldaten, Ressourcen oder Auszahlungen nach dem Laden. Freie Szenarien aus dem Hauptmenü sind unabhängig vom laufenden Lebenslauf. [Integrationstest](evidence/godot/integration.log) · [Regeltests](evidence/godot/domain.log)

## Originalgrafik und historische Einordnung

Die vier Rollen sind schwerer Infanterist mit Schild und Schwert, Speerträger, Bogenschütze und Offizier. Nah und mittel besitzen 15 oder 17 Knochen und elf Animationsclips einschließlich Marschieren, Schießen, Blocken, Treffer, Rückzug und Tod. Jede Rolle verfügt über drei Geometriestufen. Ferne Soldaten werden pro Rolle gemeinsam gezeichnet. Drei riggbasierte Feldarbeiter, Pinie, Olive und Eiche mit räumlichen Zweigen und ausgeschnittenem Blattwerk ergänzen die Siedlungen. Die Transparenzstudien liegen als 22 RGBA-PNGs vor. Die Figuren und Gebäude im laufenden Spiel sind die zugrunde liegenden 3D-Modelle. [Freigestellte Modellplatten](../../art/landscape/README.md) · [Soldatenrigs und Clipnamen](../../art/soldiers/README.md) · [Nahaufnahme im Spiel](evidence/valley-close.webp)

Das römische Dorf umfasst Grenzhaus, Brunnen und ein begehbares Atriumhaus mit Dachöffnung und Impluvium. Die regionale Ausstattung enthält ein Han-inspiriertes Haus, einen erhöhten Yayoi-Speicher, eine Yayoi-Wohnhütte und ein mitteleuropäisches Langhaus. Der Lebenslauf beginnt 94 n. Chr., das freie Szenario im Frühjahr 100 n. Chr. Geographie, Zeitstellung und archäologische Bezüge sind mit Quellen dokumentiert. Die 32 vereinfachten Regionen und überseeischen Spielverbindungen dienen der alternativen Geschichte. [Dorfansicht](evidence/village-italia.webp) · [Weltkugel](evidence/globe-han.webp) · [Quellen und Grenzen der Rekonstruktion](ATLAS_SOURCES.md)

## Bildzeiten und Sichtbarkeit

Linux, Godot 4.7.2 Compatibility, Mesa llvmpipe, 1.280 × 800 Pixel, feststehende Kamera und derselbe pausierte Zustand mit 60 Soldaten. Zwölf Aufwärmbilder pro Profil, danach 55 gemessene Bilder. Die GPU-Zeit stammt vom Software-Renderer. Die Framezeit enthält die Wartezeit der Bildbegrenzung. RSS ist der höchste Stichprobenwert des Prozesses.

| Profil | Framezeit p50 / p95 | Render-CPU / Render-GPU p50 | Draw Calls p50 | RSS | Spielbild |
| --- | ---: | ---: | ---: | ---: | --- |
| Niedrig | 63,9 / 73,7 ms | 59,0 / 55,0 ms | 70 | 425 MiB | [Niedrig](evidence/valley-low.webp) |
| Ausgewogen | 298,1 / 356,0 ms | 295,6 / 291,9 ms | 139 | 510 MiB | [Ausgewogen](evidence/valley-balanced.webp) |
| Hoch | 540,0 / 842,5 ms | 518,4 / 511,4 ms | 246 | 617 MiB | [Hoch](evidence/valley-high.webp) |

Die Sichtbarkeitsprüfung übergibt in der Startansicht 54 von 114 Bäumen an den Renderer und in der geprüften Nahansicht keinen. Die Simulation blieb beim Wechsel der Profile identisch. Der isolierte Ferntest benötigte für 64 Soldatendarstellungen vier Draw Calls. Messungen auf Mobilhardware, Dauerlast, Temperatur und spielbare Obergrenzen für Hunderte Soldaten stehen aus. [Messdaten](evidence/frames.json) · [Vergleich vor der Baumsichtprüfung](evidence/frames-before-culling.json)

## Laufzeit und Reproduktion

```sh
python3 tools/check_prototype.py --report /tmp/imperathen-release-qa
npm run check
python3 tools/art/run_visual_pipeline.py --assets-only
IMPERATHEN_ISOLATED_TEST=1 godot --path prototype --resolution 1280x800 --rendering-method gl_compatibility --script res://tests/visual_benchmark.gd -- /tmp/imperathen-frames
```

Alle zehn lokalen Godot-Prüfgruppen waren erfolgreich, darunter 329 Dorfregel-, 128 UI-, 64 Integrations-, 142 Gefechts-, 199 Saison- und 325 Soldatenprüfungen. Der grafische Soldatentest prüfte zusätzlich die gebündelte Ferndarstellung. Die Windows-EXE und das Linux-Programm aus den CI-Downloads erreichten auf dem Linux-Host im gerenderten Fenster den Startmarker. Für die Windows-EXE lief Wine 10 mit llvmpipe. Für einen nativen Windows-Gerätetest steht ein Hardwarelauf aus. [Alle Godot-Logs und Quellprüfsummen](evidence/godot/validation_report.json) · [Build- und Laufzeitworkflow](../../.github/workflows/android-prototype.yml)

Der erste Emulatorlauf des gebauten Pakets wurde von einer ANR-Meldung des Pixel-Launchers überdeckt. Im erneuten Durchlauf bestätigte die Prüfroutine den Systemdialog über dessen Paket und Fenstereigentümer. Sie installierte die exakt gleichen APK-Dateien per Prüfsumme. 30 von 30 Prüfungen bestanden auf Android 15 (API 35). Die veröffentlichte ARM64-Datei startete unter Übersetzung auf dem x86-64-Emulator bis zum sichtbaren Vorspann. Der ausführlichere x86-64-Durchlauf desselben Spielstands bestätigte Menü, Dorf, Zurück, Home, Fortsetzen nach Prozessneustart, Talgefecht, quadratisches Fenster und Weltkugel. In zehn kurzen Tal-Stichproben wurden 0,35–1,35 FPS mit dem Software-Renderer gemessen. Eine Speicherstichprobe ergab rund 218 MiB PSS und 320 MiB RSS. Android 17 (API 37) scheiterte beim Start des System-Compositors vor der App-Installation an `hasReadColorBufferDma`. [Bytegenauer Android-Nachtest](https://github.com/Ullmann27/Imperathen/actions/runs/45039240541) · [Android-Bericht](evidence/runtime-pilot.json) · [APK-Validierung](evidence/apk-pilot.json)

Im interaktiven Test der Windows-EXE unter Wine gelangen der Einstieg ins Dorf, der Rückweg über Pause ins Menü, der Klick ins Talgefecht, die Wahl der Talwache, die Frontausrichtung per Rechtsziehen und das Fortsetzen per Leertaste. [Windows-Start](evidence/windows-pilot.log) · [Spielbild](evidence/windows-valley.webp)

## Behobene Fehler und nächste Abnahme

Korrigiert wurden die Prüfung des Godot-Launcher-Alias im kompilierten Manifest, der AVD-Suchpfad, überdeckte Emulator-Screenshots, die Weitergabe der Android-Zurück-Taste an die aktive Ansicht und unnötig eingereichte Vegetation außerhalb der Kamera. Der Test vergleicht gespeicherte Koordinaten mit einer Toleranz von 0,00001 Metern. Identitäten, Bestände und Verluste müssen exakt erhalten bleiben.

Der nächste Geräteversuch sollte dieselbe APK auf dem Galaxy Z Fold7 im geschlossenen und offenen Zustand mit Mehrfingerbedienung, Szenenwechseln und längerer Last ausführen. Für den grafischen Ausbau stehen Gesichter, Hand- und Waffenkontakte, Laufzeit-IK sowie eine größere gemessene Gefechtsleiter aus. Das Tal verwendet für alle Herkünfte das römische Referenzszenario. Eigene militärische Laufbahnen bis zum Germanenkönig oder Kaiser, Diplomatie, regionales Langzeitklima und weitere lokale Schauplätze gehören zum weiteren Spielausbau.
