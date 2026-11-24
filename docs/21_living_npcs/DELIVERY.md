# IMPERATHEN 0.5.0 – Bewegung, Bewohner und Meshy-Figuren

Stand: 24. November 2026. Ausgangspunkt ist
`d7e3a7306f84ee61d74609e127b87d6b34a96efd` auf
`integration/build68-story-meshy-20261123`. Die Änderungen liegen getrennt auf
`feature/living-npcs-meshy-movement-20261124`.

## Gehen und laufende Arbeit

Der Fehler ließ sich am ursprünglichen Stand reproduzieren: Ein gespeicherter
Arbeitsauftrag erzwang weiterhin die Arbeitsanimation, obwohl sich der Spieler
bewegte, die Arbeitsstelle verlassen hatte oder die Arbeitszeit bereits beendet
war. Derselbe Hinweis konnte Treffer- und Todesanimationen verdrängen.

Jetzt haben tatsächliche Bewegung und Kampfreaktionen Vorrang. Eine Arbeitsgeste
setzt eine aktive, noch unvollständige Aufgabe, die richtige Station, passende
Reichweite, Stillstand und einen verfügbaren Ausbilder voraus. Sie läuft kurz aus,
wenn diese Voraussetzungen entfallen. Der vorhandene Arbeitsfortschritt bleibt
gespeichert; Zurückkehren zur Schmiede setzt ihn korrekt fort.

Der isolierte Vergleich enthält **24 Prüfungen**: am Ausgangsstand fünf gezielte
Fehler, mit Bewegungskorrektur keinen. Auch der kombinierte Stand mit Bewohnern
und Meshy besteht diese 24 Prüfungen. Die Prüfung misst den tatsächlichen
Spielerkörper und importierte Beinknochen bei gehaltenen Touchereignissen.
Belege: [Lokomotion](evidence/locomotion/comparison.json),
[kombinierter Lauf](evidence/locomotion/integrated.json).

## Bewohnerentscheidungen

Die 42 vorhandenen Identitäten erhalten Interessen, individuelle Gewichtungen,
Erschöpfung, Gesellschaftsbedarf und Anspannung. Sie wählen daraus ihre nächste
Tätigkeit und reagieren auf Nähe, Beziehungen, Regen und lebende Angreifer.
Bewegliche Einwohner nutzen ihre bestehenden Wege mit tatsächlicher Kollision.
Eine Pause eines Arbeiters zählt auch in der Dorfwirtschaft als Abwesenheit.

Die Gesprächsanzeige ergänzt die aktuelle Reaktion, ohne vorhandene Storytexte
oder Entscheidungen zu entfernen. Interessen werden in der Personenübersicht
erst bei bekannten Bewohnern angezeigt. Bedürfnisse, Absichten, beobachtete
Positionen und begrenzte Erinnerungen bleiben im Spielstand erhalten. Bestehende
Kindheitssaves werden nach erfolgreicher Validierung ergänzt.

Julia, Silvanus, Sextus und andere feste Gesprächsorte behalten ihre notwendigen
Anker. Diese Figuren können ihre Tätigkeit unterbrechen und Aufmerksamkeit
zeigen. Die Umsetzung enthält noch keine beliebige Navigation durch neue
Innenräume oder frei erzeugte Sprachdialoge. Details und Grenzen stehen in
[NPC_DECISIONS.md](NPC_DECISIONS.md).

## Neue Figuren

Zwei der vorhandenen Meshy-Quellen werden als angepasste Spielfiguren verwendet:

- `unit_roman_signifer` für Severus;
- `unit_germanic_axe_fighter` für einen Teil der vorhandenen Angreifer.

Die abgeleiteten Modelle besitzen je ein angepasstes Skelett mit 15 Knochen,
elf Bewegungsclips und vier Detailstufen. Kinder behalten ihre vorhandenen
Altersmodelle. Die Quelldateien enthielten selbst weder Skelett noch Animationen;
die Anpassung erfolgt durch die lokale Blender-Pipeline im Repository.

Die vorhandene Meshy-Axt, der Rundschild und das Feldzeichen werden separat an
die tatsächlich animierten Handknochen angeschlossen. Sie besitzen kleine nahe
und entfernte Detailstufen und werden beim Wechsel des Körpermodells erneut
angebunden. Dadurch verliert der ersetzte Angreifer seine sichtbare Ausrüstung
nicht. Dieser Darstellungsanschluss erzeugt keine neuen Inventargegenstände,
Schadenswerte oder Belohnungen.

Fünf weitere Quellen sind dokumentiert, aber noch nicht als bewegliche Figuren
freigegeben: Zwei enthalten Pferd und Reiter in einem verbundenen Modell; die
anderen benötigen eine Trennung von Sockel, Ausrüstung oder verschränkten Armen.
Die konkrete Prüfung jeder Quelle steht in
[CHARACTER_SOURCE_REVIEW.json](../20_meshy_assets/CHARACTER_SOURCE_REVIEW.json).
Die Quelldateien werden nicht zusätzlich in die Android-App aufgenommen.

## Android-Nachweis

Der endgültige lokale Gesamtlauf besteht **alle 55 Godot-Prüfgruppen**:
[validation_report.json](evidence/engine/validation_report.json).
Die Werkzeug- und Paketkontrollen bestanden zunächst **131 Python-Prüfungen**:
[python-tooling.json](evidence/python-tooling.json). Nach der unten beschriebenen
Importkorrektur bestehen **139 Python-Prüfungen**:
[python-tooling-followup.json](evidence/python-tooling-followup.json).
Die Körperprüfung umfasst 184 Headless- und 204 Viewport-Prüfungen; die endgültige
Ausrüstung besteht 138 Prüfungen einschließlich zehn geprüfter Ansichten.
Der [reale Export-Pack](evidence/export-pack.json) enthält alle 14 neuen
Modellimporte und die benötigten JSON-Dateien, aber keine Meshy-Rohmodelle.

Beim ersten Gesamtlauf wurden zwei alte Testannahmen sichtbar: zusätzliche
starre Ausrüstung ist kein zweiter skinnender Körper; eine inaktive Welt mit
laufender Trainingspose darf keine Arbeitsanimation erzwingen. Die Testaufbauten
wurden präzisiert, ihre eigentlichen Körper-/Arbeitsprüfungen beibehalten und der
vollständige 55-Gruppen-Lauf anschließend nochmals erfolgreich ausgeführt.

Die APK-Prüfung verlangt die neue Bewohnerlogik, die Figurenregistrierung,
alle acht Figuren- und sechs Ausrüstungsdateien sowie die benötigten
Story-/Meshy-JSON-Dateien.
Die Veröffentlichung ist an denselben Quellstand, überprüfte Paketbytes,
erfolgreiche Godot-Gruppen und den Android-Laufzeitbericht gebunden.

Sieben zusätzliche Laufzeitprüfungen kontrollieren den angeschlossenen
Bewohnerzustand, fortlaufende Entscheidungen, den tatsächlich gespeicherten
Zustand und seine Erhaltung nach einem Prozessneustart. Außerdem prüfen sie
Severus' geladenes Meshy-Modell vor und nach dem Neustart sowie den Gehclip
während tatsächlich gemessener nativer Touchbewegung.

Der lokale [Diagnoseanschluss](evidence/android-observer/validation.json)
bestätigt bereits 42 beobachtete Bewohner, den Vergleich mit der echten
Speicherdatei und Severus' geladenes Modell. Diese lokale Prüfung lädt im selben
Godot-Prozess neu und wird nicht als Android-Prozessneustart ausgewiesen.
Der zum veröffentlichten APK gehörende CI-Bericht ist der maßgebliche Nachweis
für die tatsächliche Android-Prüfung. Eine Prüfung auf einem physischen Fold7
oder eine thermische Dauerprüfung ist dadurch nicht belegt.

### Korrekturen aus dem ersten Android- und Storylauf

Android-Lauf [72](https://github.com/Ullmann27/Imperathen/actions/runs/45344763960)
baute und validierte beide APKs. Der Emulator bestand 31 Laufzeitprüfungen und
zeigte Severus mit Skelett und gebundenem Feldzeichen. Die anschließende
Paketprüfung suchte jedoch nur nach rohen GLBs oder `.remap`-Dateien. Godot hatte
die Modelle als `.import` mit referenzierten `.scn`-Dateien exportiert.

Der Harness verwendet nun dieselbe Ressourcenauflösung wie die APK-Prüfung,
verlangt nichtleere Zielbytes für die tatsächlich beobachteten Modelle und
protokolliert deren Paketpfade und Hashes. Acht zusätzliche Regressionen prüfen
auch fehlende, leere und nicht korrekt verknüpfte Ressourcen. Die Anforderungen
an tatsächliche Knochen, Gangarten, Handanbindung, Gehen und Neustart bleiben
erhalten. [Nachweis und Grenzen](evidence/android-import-resolution/README.md).
Der abgebrochene Lauf ist kein abgeschlossener Geh- oder Neustartnachweis.

Im separaten Storyworkflow hinterließ ein Test eine gespeicherte Kampagne. Der
folgende Eröffnungstest erhielt deshalb die korrekte Bestätigungsabfrage für
einen vorhandenen Spielstand. Jeder Test erhält jetzt eigene temporäre
Zustandsverzeichnisse und einen begrenzten Timeout. Die betroffene Sequenz
bestand danach 96 und 45 Prüfungen. Die Sicherheitsabfrage für echte
Spielstände bleibt unverändert. [Isolationsnachweis](evidence/story-isolation/README.md).

## Installation und Spielstände

Die Version heißt `0.5.0-living-village`, Android-Versionscode 5. Die vorhandene
Buildstrecke verwendet je Prüfbau einen privaten Debug-Schlüssel. Ein direktes
Update über eine anders signierte Prüffassung ist daher nicht zugesagt.
Eine vorhandene Installation mit wichtigem Spielstand sollte vor einem
Installationswechsel gesichert werden.
