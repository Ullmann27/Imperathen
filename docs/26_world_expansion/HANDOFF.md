# Weltbau: Übergabe an die parallelen Stadtteams

Stand: 25. November 2026. Branch `feature/world-expansion-blender-20261125`,
[Draft PR #58](https://github.com/Ullmann27/Imperathen/pull/58), auf Team B
`7af39f35b1947595f95e365eb7762592feabf234` aufgebaut.

Dieses Paket ergänzt die laufende Stadtarbeit um bearbeitbare Blenderquellen,
exportierte Modelle und eine eigene Godot-Weltwerkstatt. Die Zusammenarbeit läuft
über [Issue #16](https://github.com/Ullmann27/Imperathen/issues/16) und die
versionierten Übergaben. Das Team für Shops und Innenräume arbeitet in
[PR #57](https://github.com/Ullmann27/Imperathen/pull/57). Das sind tatsächlich
beobachtete Projektstände; fremde Chats werden dadurch nicht automatisch gesteuert.

## Zuständigkeiten

| Agent | Eigener Bereich | Übergabe |
| --- | --- | --- |
| architecture | `tools/world_art/architecture.py`, Architektur unter `art/world_expansion/` und `prototype/assets/world_expansion/` | Taberna, Insula, Basilika, Straßenmodul; vier Blenderquellen, zwölf GLBs |
| vegetation | `tools/world_art/vegetation.py`, Vegetation in denselben Assetbereichen | Feldulme, Zypresse, Lorbeer; drei Blenderquellen, neun GLBs, Windgewichte |
| environment | `prototype/scripts/world_expansion/`, zugehörige Szene, Shader und Godot-Test | Instanzierung, Landschaftsvorschau, Sonne/Mond, Wind, Atlas und Bedienung |
| root | Manifest, Prüfwerkzeuge, Workflow und diese Übergabe | Verträge, Integration, Versionsstand und überprüfbare Belege |

Die vorhandene Agent-Pipeline wird wiederverwendet. `coordination/world_expansion.json`
legt exklusive Pfade und die Abhängigkeit von Environment auf beide Assetaufgaben fest.
`tools/world_art/pipeline.py` verwendet einen eigenen lokalen Statusbereich und
verändert die bestehende Aufgabenliste nicht. Claims gelten pro Checkout;
chatübergreifende Pfadreservierungen stehen deshalb zusätzlich in Issue #16.

```sh
python3 tools/world_art/pipeline.py status
python3 tools/world_art/pipeline.py run
python3 tools/world_art/pipeline.py check --require-ready
```

Ein frischer Checkout beginnt mit offenen Aufgaben. `run` führt die Prüfungen
aus; den Status `ready` setzt erst die jeweilige, nachweisgebundene
`handoff`-Aktion nach ihrem `claim`. Deshalb ist `check --require-ready` die
Abschlusskontrolle einer übergebenen Sitzung, kein automatisches Einrichtungsprogramm.

Eine Übergabe wird nur mit bestandenem Prüflauf und unveränderten Dateifingerprints
akzeptiert. Änderungen nach einer Übergabe erfordern erneutes Claiming und Prüfen.
Die Pipeline startet keine weiteren Modelle oder bezahlten Dienste.

## Weltwerkstatt öffnen

Mit Godot 4.7.2 aus dem Repositoryverzeichnis:

```sh
godot --path prototype res://scenes/world_expansion/preview.tscn
```

Im Editor kann dieselbe Szene geöffnet und als aktuelle Szene gestartet werden.
Sie besitzt vier Ansichten: Straße, Siedlungsübersicht, Vegetation und Handelsrouten.
Auswahlfelder wechseln Siedlungsgröße und Qualitätsprofil. Die Regler verändern
Tageszeit und Wind; „Tageslauf“ aktiviert den eigenen 24-Stunden-Darstellungszyklus.
Ziehen mit linker Maustaste oder einem Finger dreht die Kamera. Mausrad sowie
Plus/Minus verändern den Abstand. Ein Klick auf einen Ort im Atlas lädt dessen
Siedlung. Die beiden Residenzen erhalten unterschiedliche, stabile Layout-Seeds.

Die Szene ist ein eigenständiges Werkzeug. Sie schreibt keine Spielstände und
greift nicht auf WorldModel oder Kampagnenzeit zu. Der Hauptmenüanschluss, neue
Android-Pakete und die Übernahme in die begehbare Spielstadt sind separate Schritte.

## Was die Größen bedeuten

| Auswahl | Gebäudeplatzierungen | Verwendbare Grundmodelle |
| --- | ---: | --- |
| Dorf | 48 | Taberna |
| Marktstadt | 256 | Taberna, Insula |
| Großstadt | 1.024 | Taberna, Insula, Basilika |
| Residenzstadt | 4.000 | Taberna, Insula, Basilika |

Das sind tatsächlich erzeugte Instanzen modularer Modelle. Die Zahlen bezeichnen
keine individuell gestalteten Häuser oder fertig bewohnten Innenräume. Der Atlas
parametrisiert fünf Orte mit zusammen 9.328 Gebäudeplatzierungen, darunter zwei
Residenzen zu je 4.000. Es wird jeweils die ausgewählte Siedlung aufgebaut; eine
gleichzeitig simulierte, nahtlos begehbare Gesamtwelt wird damit nicht behauptet.

Die Umgebungsfläche bildet ein einfaches Gelände mit ansteigenden Rändern. Namen
wie Fluss-Marktstadt und Hafenstadt sind Produktionsbezeichnungen im Atlas; sie
bedeuten noch keinen gebauten Fluss oder ausgearbeiteten Hafen. Regierungssitze
sind markiert, ohne neue Kaiserfigur, Palastmission oder Storychronologie festzulegen.

## Assetvertrag

- Maße in Metern. Blender: Z nach oben, Front −Y. GLB/Godot: Y nach oben, Front +Z.
- Pro Typ drei separate GLBs für LOD0/1/2; Texturen sind eingebettet. Die sieben
  `.blend`-Dateien enthalten gepackte Bilder und bleiben weiter bearbeitbar.
- Die Architekturunterkante liegt bei GLB-Y = 0, der innere Gebäudeboden bei
  Y = 0,12 m. `prototype/assets/world_expansion/manifest.json` reserviert für
  Gebäude konservative Rechtecke symmetrisch um diesen Ursprung. Sie umfassen
  auch asymmetrische Vorhallen und Markisen. Exakte Minima/Maxima und Dreiecke
  stehen in den Assetberichten; eine spätere Kollision übernimmt die wirklichen
  Meshgrenzen statt nur die Breite und Tiefe.
- Architektur-GLBs haben ein Mesh mit mehreren Materialoberflächen. Das ist noch
  keine automatische Einzel-Draw-Call-Zusage. Strukturboxen aus dem Export sind
  Kollisionshinweise; begehbare Räume benötigen eine eigene Kollisions- und
  Navigationsabnahme.
- Nur `basilica_lod0.glb` spart die expliziten Tangentendaten aus. Beim
  Godot-Import muss `meshes/ensure_tangents` aktiviert bleiben. Die Engine erzeugt
  daraus ihre Tangentenbasis; deren Gültigkeit und die gebundenen Normalmaps
  werden auf allen sieben Oberflächen geprüft. Bitgleiche Tangenten gegenüber
  Blender werden nicht zugesagt. Texturen, Positionen, Normalen und UVs bleiben
  beim Packschritt unverändert.
- Hohe Detailstufen sind für nahe Ansichten gedacht. Die Stadtübersicht verwendet
  die fernsten Modelle, nach Typ zusammengefasst. Straßenansichten verwenden
  räumliche Gruppen von 64 Metern und entfernungsabhängige Detailstufen.
- Vier Profile begrenzen Sichtbereiche und Schatten. Ein Profilname ist keine
  gemessene Bildrate und kein Nachweis für Fold7 oder ein anderes Android-Gerät.

### Wind: Vertexfarben bleiben Steuerdaten

| Kanal | Bedeutung |
| --- | --- |
| R | Biegung nach Höhe; verankerte Bodenpunkte 0 |
| G | Blattflattern; Holz und Blattansätze 0 |
| B | Stabile Phase je Blatt, ausschließlich für Flattern |
| A | 1 |

Der breite Schwingungsanteil verwendet den gemeinsamen Weltanker, damit Zweige
und Blattansätze zusammenbleiben. `COLOR_0` darf weder die Blattfarbe noch deren
Deckkraft ersetzen. Der Loader übernimmt Albedo-, Normal- und Materialkarten in
`vegetation_wind.gdshader` und registriert die Materialinstanzen am Controller.
Die exportierten normalisierten Integerfarben werden bei der Dateiprüfung korrekt
auf 0–1 abgebildet. Windstärke 0 beseitigt beide Bewegungsanteile.

`environment_controller.gd` bietet `set_time_of_day`, `set_wind`,
`set_wind_time`, `set_quality`, `bind_material` und `unbind_materials`. Seine
Darstellungszeit ist von Story, Alterung und Spielstand getrennt. Der Sonnenlauf
ist eine künstlerische Beleuchtungssteuerung, kein astronomisches Ortsmodell.

## Handel und Anschluss an das Shop-Team

Das Manifest enthält acht Anschlussrollen: Bäckerei, Schenke, Schmiede, Töpferei,
Weberei, Getreidehandel, Stall/Pferdehandel und Warenlager. Warenbezeichner sind
Metadaten für die weitere Zuordnung; sie erzeugen keine Käufe oder Bestände.
Die eigentlichen Angebote, Transaktionen, NPCs und Innenrauminteraktionen bleiben
bei der bestehenden Handelsarbeit. IDs zuerst mit deren Katalog abgleichen.

Fünf Routenzüge verbinden die fünf Atlasorte. `regional_routes.py` prüft
Endpunkte und zusammenhängende Verbindungen und berechnet kürzeste Wege mit
optional gesperrten Straßen. Das liefert einen prüfbaren Routengraphen, noch keine
reisenden Händler, dynamische Preise oder dreidimensionale Fernstraßen.

## Prüfungen und tatsächliche Bildbelege

```sh
python3 tools/world_art/validate.py
python3 -m unittest discover -s tools/world_art -p 'test_*.py'
python3 tools/world_art/regional_routes.py
python3 tools/world_art/verify_environment.py --render
```

Der letzte Befehl benötigt Godot und einen echten Grafikzugang oder `xvfb-run`.
Er importiert alle 21 GLBs in ein temporäres, isoliertes Projekt. Anschließend
prüft er Laufzeitverhalten und die vom Renderer zurückgelesenen Instanztransformationen.
Zehn 1280 × 720 Pixel große Enginebilder dokumentieren Mittag, Abend, Nacht,
zwei Windzeitpunkte, zwei Kontrollbilder bei Windstille, die 4.000er-Übersicht,
den Routenatlas und eine Nahaufnahme der Basilika mit ihren Normalmaps.
Jeder Lauf erhält ein neues Bildverzeichnis. Dateihashes,
Bildpixel-Fingerprints, Auswahlzustand und Gebäudezahlen stehen in den Belegen.

Die Kontrolle verlangt verschiedene Pixel bei verändertem Windzeitpunkt und
identische Pixel bei Windstille, fixierter Beleuchtung und gleicher Kamera.
Für diese Aufnahmen wird die Himmelsreflexion im Modus `Sky.PROCESS_MODE_QUALITY`
vollständig pro Aktualisierung berechnet. Damit laufen nach einem Tageszeitwechsel
keine inkrementellen Reflexionsstufen in den Ruhevergleich hinein. Der Modus der
normalen interaktiven Vorschau wird dafür nicht geändert.
Scriptfehler, fehlende Assets, falsche Gebäudezahlen oder leere Bilder lassen den
Lauf scheitern. Ein bestandener Zahlencheck ersetzt die anschließende Sichtprüfung
der tatsächlichen Bilder nicht. Der Workflow ist
`.github/workflows/world-expansion.yml`; sein Artefakt enthält Bilder, Messberichte,
GLBs und Blenderquellen. Abschließende Befunde und der geprüfte Commit stehen in
`DELIVERY.md` und `evidence/`.

## Offene Qualitätsarbeit

Die Modelle sind originale, prozedural erzeugte Spielmodule. Die Feldulme besitzt
eine noch recht offene Krone; die Makroansicht zeigt polygonale Blattkonturen.
Für eine fotorealistische Endfassung sind weitere Form- und Materialarbeit nötig.
Die Windaufnahmen zeigen mehrere Pflanzen gemeinsam. Vordergrundblätter verdecken
einen Teil des rechten Ulmenkronenrands; zwei Einzelbilder bewerten außerdem noch
nicht den natürlichen Bewegungsverlauf über eine längere Zeit.
Der Wind verformt die Geometrie; die Tangentenbasis der Blattbeleuchtung wird
noch nicht mitgedreht. Besonders bei stärkerem Wind ist das eine sichtbare
Vereinfachung gegenüber natürlicher Blattbewegung.
Innenraumwege, alle Geschosstreppen, Kollisionen, Einwohner und wirtschaftliche
Abläufe sind nicht durch diese Assetkontrolle abgenommen. Mobile Leistung muss
mit der integrierten Welt auf dem Zielgerät gemessen werden. Die Storydateien
wurden für dieses Weltbaupaket nicht ausgewertet.
