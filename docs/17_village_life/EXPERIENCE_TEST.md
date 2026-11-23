# Tatsächlicher Einstieg durch Main, Oberfläche und Spielwelt

Stand: 23. November 2026. Test: `prototype/tests/village_experience_test.gd`.

Der ausgeführte Godot-4.7.2-Lauf bestand **125 Einzelprüfungen ohne Fehler**. Der [Laufbericht](evidence/village-experience.log) enthält den tatsächlichen Hauptmenü-, Intro-, Dialog-, Pause- und Fortsetzenpfad. Es handelt sich um einen vollständigen Szenentest mit der Produktionsdatei `main.tscn`, dem echten Main-Skript, der aktuellen Oberfläche und der vorhandenen 3D-Welt.

## Durchlauf

1. Neues römisches Leben über den wirklichen Hauptmenü-Button beginnen; das neue Dorfmodul ist aktiv, der Spieler zwölf Jahre alt und Bewohner unter bestehender Herrschaft.
2. Intro überspringen, dessen Zielkarte ausdrücklich annehmen und die Weltsteuerung übernehmen.
3. Vierzehn benannte Einwohner, den Verwalter und fünf Arbeitsorte in der tatsächlichen Szenenstruktur nachweisen; der ältere generische Trainer ist ausgeblendet.
4. Decimus in der Welt ansprechen und über seine echte Dialogauswahl die Mitarbeit vereinbaren.
5. Fabius kennenlernen, zwei tatsächliche Rationen als Hilfe abgeben, die Holzfällerlehre beginnen und ein mit zwei weiteren Getreide bezahltes Bündnis schließen.
6. Aelia kennenlernen, vier endliche Holzbündel über die Weltinteraktion einsammeln und mit echtem Material sowie fortgeschriebener Bauarbeit eine Hütte errichten.
7. Fabius und Drusa über die wirklichen Arbeitsplatz-Auswahlfelder zum Lager schicken. Reparatur bezahlen, nach tatsächlicher Arbeitszeit die instandgesetzte Darstellung und endliche Produktion prüfen.
8. Drusa über die Oberfläche freistellen; die fehlende zweite Arbeitskraft stoppt die Produktion. Anschließend erneut korrekt einteilen.
9. Dorfplan aus dem Pausenmenü öffnen, Varro in der Welt kennenlernen und bis zur regelkonformen Überfallwarnung fortschreiben.
10. Spur und Alarm am richtigen Weltort über dieselbe Interagieren-Aktion wie im Spiel auslösen.
11. Region- und Arbeitsplatzansicht in 1280 × 720 und schmalen 540 × 960 prüfen; Auswahl, Resize, seitliche Panelgrenzen und Android-Zurück erhalten den korrekten Zustand.
12. Drei tatsächliche Angreifermodelle an den autoritativen Gegnerpositionen nachweisen. Abgelehnte Abwehrbefehle dürfen keine Ausweichbewegung starten; akzeptierte Befehle starten Schutzfenster, Animation beziehungsweise gemessene Positionsänderung.
13. Einen laufenden Angriff pausieren, über den echten Speicher- und Hauptmenüpfad sichern und über „Fortsetzen“ wiederherstellen. Arbeit, Vorräte, Freundschaft, Beruf, Kampfzeit und Fähigkeiten bleiben erhalten.
14. Die reale gefährdete Bewohnerin retten und über neun wirkliche Angriffseingaben alle drei Gegner besiegen. Erst danach entsteht der Verteidigungssieg, die Gegnerdarstellung endet und Fähigkeiten spiegeln die tatsächlichen Handlungen.
15. Bis zum dritten Prototyptag fortschreiben. Die spätere Ausbildung wird verfügbar, ohne den Spieler automatisch altern zu lassen. Der gesamte Zustand bleibt speicherbar.
16. Marcus über seine tatsächliche Gesprächsauswahl mit vier Holz helfen, am Übungsplatz den freigegebenen Ausbildungsübergang auslösen, die Erwachsenenmontage annehmen und drei tatsächliche Übungsschläge absolvieren.
17. Über den wirklichen Rekrutieren-Button einen vorhandenen Einwohner gegen fünf Denarii und zwei Getreide anwerben. Der sichtbare Truppactor trägt dessen `resident_id` und tatsächlichen Namen in `RecruitName`; derselbe Dorfactor wird unsichtbar. Die Arbeitsauswahl ist gesperrt und zeigt „In deiner Truppe“. Unbeteiligte ältere Frontier-Dekorpersonen werden nicht entfernt. Dieser Zustand bleibt speicherbar.

## Eingabe- und Zeitgrenzen des Nachweises

Der Test aktiviert die Produktionssignale der sichtbaren Buttons und Auswahlfelder. Für Ortswechsel verwendet er ausdrücklich Fixture-Teleports, die Modellposition und tatsächliche Spielerfigur gemeinsam versetzen. Er trägt keine Rohstoffe, Arbeiterzuweisungen, Fähigkeiten oder Questflags von Hand ein. Zeit wird kontrolliert durch `Main._process` und den tatsächlichen Weltprozess weitergegeben; dadurch muss der Test die virtuellen Minuten nicht in gleicher realer Zeit abwarten.

Der ausgeführte Lauf ist **keine Prüfung auf einem physischen Telefon**, kein Nachweis realer Fingerbedienung und keine FPS-Messung. Die Geometrieprüfungen bestätigen Szenen- und UI-Zustände; eine visuelle Qualitätsbewertung erfordert zusätzlich die echten gerenderten Aufnahmen.

Beim ersten Lauf wurden zwei Speichervergleiche zu streng formuliert: Godots JSON-Normalisierung stellt ganze Zahlen teils als Gleitkommazahlen dar und kann den letzten binären Rest eines Timers runden. Der korrigierte Vergleich prüft weiterhin rekursiv sämtliche Felder, akzeptiert aber numerisch gleiche Werte mit einer Toleranz von 0,00000001. Es wurden keine Spielstandsregeln oder Produktionsprüfungen gelockert. Ausgangslauf und Diagnose bleiben unter `evidence/village-experience-first.log` und `evidence/village-experience-diagnosis.log` erhalten.

## Optionaler echter Renderlauf

Der Test akzeptiert nach Godots `--` ein absolutes Ziel:

```text
--capture-dir=/absoluter/ausgabeordner
```

Bei einer wirklichen Renderanzeige wartet er auf `RenderingServer.frame_post_draw` und speichert:

- `01-village-start.png`
- `02-decimus-dialogue.png`
- `03-workplace-panel.png`
- `04-raid-in-world.png`
- `05-regional-map.png`
- `06-narrow-workplace-panel.png`

`experience-report.json` enthält Abmessungen, jeweiligen Spielschirm, Weltzeit, SHA-256, Engineversion und Testfehler. Ein reiner Headless-Lauf behauptet keine Bilderzeugung. Mit aktivierter Aufnahme kommen sechs Dateiprüfungen zu den 125 Ablaufprüfungen hinzu.

Für jede Ausführung müssen `IMPERATHEN_ISOLATED_TEST=1` und neue, getrennte Verzeichnisse für `XDG_DATA_HOME`, `XDG_CONFIG_HOME` und `XDG_CACHE_HOME` gesetzt werden. Dadurch kann der Szenentest keine vorhandene Benutzerpartie überschreiben.
