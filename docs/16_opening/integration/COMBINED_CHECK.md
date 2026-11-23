# Gemeinsamer Godot-Nachweis: Opening und Frontier

**23. November 2026 · Godot 4.7.2 · isolierte Prüffassung**

Der vorbereitete Dreiwege-Patch wurde zusammen mit dem aktuellen erfassten Frontier-Arbeitsstand tatsächlich in Godot ausgeführt. **Frischer Import und alle sechs abschließenden Szenario-/Regelgruppen bestanden; 1.419 Einzelprüfungen, keine Warnungen.** Die drei zusammengeführten Produktionsdateien benötigten nach diesem Lauf keine weitere Korrektur.

## Tatsächlich geprüfte Zusammenstellung

Eine neue Kopie wurde unter `/tmp/imperathen-chat1-preview` erstellt. Grundlage waren 422 Quelldateien des aktuellen Opening-Prototyps. Darüber wurden sämtliche 88 zu diesem Zeitpunkt geänderten oder unversionierten `prototype/`-Dateien aus Chat 1 gelegt; zuletzt wurden die drei gesondert aufgelösten Hauptdateien eingesetzt. Das ergab 498 Eingangsdateien. Der generierte `.godot`-Ordner wurde nicht übernommen; der Importcache entstand frisch.

Das [Eingangsmanifest](combined-evidence/combined-input-manifest.json) enthält die SHA-256 jeder Opening-Quelldatei, jedes Peer-Beitrags, der drei Auflösungen und des kombinierten Eingangsstands. Die Peer-Dateien wurden vor Erstellung stabil gelesen und nach Abschluss erneut verglichen: **keine Änderung gegenüber dem geprüften Snapshot**. An Chat 1s aktivem Checkout wurde nichts geschrieben.

Jeder ausführbare Prüflauf erhielt eigene temporäre `XDG_DATA_HOME`-, `XDG_CONFIG_HOME`- und `XDG_CACHE_HOME`-Ordner. Die Prüfung verwendete die vorhandene Engine und dieselbe Auswertung von Exitcodes, Skriptfehlern und Erfolgsmeldungen wie `tools/check_prototype.py`. Spielerstände und Einstellungen außerhalb der temporären Prüfläufe wurden nicht verwendet.

## Ergebnis

| Prüfung | Tatsächliches Ergebnis | Beleg |
| --- | --- | --- |
| Frischer Import | Exit 0, keine Skript-/Parserfehler, keine Warnungen | [Importlog](combined-evidence/fresh_import.log) |
| Frontier-Geschichte und Zustand | 308 Prüfungen, 0 Fehler | [Storylog](combined-evidence/frontier_story.log) |
| Frontier-Figuren, Rig und Darstellungsstufen | 251 Prüfungen, 0 Fehler | [Figurenlog](combined-evidence/frontier_people.log) |
| Bevölkerung, Wege, Gesprächskamera und Herkunft | 659 Prüfungen, 0 Fehler | [Bevölkerungslog](combined-evidence/frontier_population.log) |
| Neuer Opening-Ablauf über Main/UI | 32 Prüfungen, 0 Fehler | [Openinglog](combined-evidence/opening_flow.log) |
| Bestehender vollständiger Spielablauf | 67 Prüfungen bestanden | [Integrationslog](combined-evidence/integration.log) |
| Frontier-Ablauf mit tatsächlicher Filmübergabe | 102 Prüfungen, 0 Fehler | [Gemeinsamer Frontier-Log](combined-evidence/frontier_integration_adapted.log) |

Der [maschinenlesbare Abschlussbericht](combined-evidence/combined-validation-report.json) enthält Laufzeiten, Exitcodes, Warnungen, den endgültigen getesteten Quellstand und die Beschreibung der folgenden Testanpassung.

## Ein tatsächlich gefundener Testanschluss-Konflikt

Der unveränderte neue Frontier-Integrationstest ging nach `new_game` und `train` unmittelbar von `screen == "playing"` aus. Der neue Anfang hält an diesen Stellen absichtlich die Film- beziehungsweise Zielkarte offen. Der ursprüngliche gemeinsame Lauf endete deshalb nach acht Assertions mit drei Fehlern: Spielmodus noch nicht erreicht, der anschließend erwartete entfernte Gesprächsversuch noch im Film und das deshalb blockierte Gespräch mit Aulus. Dieser Ausgangslauf bleibt im [unveränderten Testlog](combined-evidence/frontier_integration_unchanged.log) erhalten.

Die gelieferte Testanpassung benutzt die tatsächlichen Funktionen der Opening-Oberfläche zum Überspringen und zum anschließenden Annehmen der Zielkarte. Sie prüft zusätzlich die erwartete Sequenz, das Warten auf der Zielkarte und den unveränderten Kampagnenzustand während der Übergabe. Diese Ergänzung erfolgt für den ersten Einstieg, den zweiten getesteten Einstieg und beide Erwachsenenübergänge. **Keine vorhandene Testbedingung wurde entfernt oder abgeschwächt.** Der angepasste Lauf prüft anschließend weiterhin beide Frontier-Kostenpfade, echte Dialogschaltflächen, tatsächliche Arbeit am Wagen, Pause, Speichern, Fortsetzen und die einmalige Vergütung.

Die Änderung liegt als separater `frontier-integration-test.patch` mit eigenem SHA-Manifest vor. Der bereits geprüfte Produktionspatch `chat1-opening.patch` ist dadurch nicht erweitert oder verändert worden.

## Grenzen und nächste Verwendung

Dies ist ein tatsächlicher Headless-Engine-Lauf mit importierten Assets, aktiven Szenen, Eingaben und Persistenz. Er belegt die technische Zusammenführung des erfassten Arbeitsstands. Er misst weder Bildrate noch Thermik und enthält keine neue physische Android-Prüfung. Eine fertige PS5-Grafikqualität, Sprecheraufnahmen oder ein APK-Release werden daraus nicht abgeleitet.

Für die Übernahme zuerst die zusätzlichen Opening-Module bereitstellen und den Produktionspatch mit seinem SHA-Guard prüfen. Die ergänzte Testdatei anschließend anhand ihres eigenen Manifests übernehmen. Sollte Chat 1 seit dem dokumentierten Snapshot weitergeschrieben haben, wird auf dessen neuem Inhalt zusammengeführt; alte Komplettdateien werden nicht darüberkopiert. Sämtliche genannten Produktions- und Teständerungen sind weiterhin getrennt von einem Merge nach `main`.
