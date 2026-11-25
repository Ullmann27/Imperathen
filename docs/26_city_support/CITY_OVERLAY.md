# Detailanschluss an den bestehenden Stadtrundgang

Stand: 25. November 2026. Dieser kleine Anschlusszweig baut direkt auf
`feature/meshy-player-city-exploration-20261125`, Commit
`5b5eecad31e395e3ead48b3e631d9f48690480a6`, auf.

## Konkrete Änderung

`city_exploration.gd` lädt am Ende von `_load_city()` den neuen
`CityExplorationDetailAdapter`. Dessen Bericht erscheint als
`IMPERATHEN_CITY_DETAIL` in der Engineausgabe. Die Szene verwendet weiterhin
ihren eigenen Spieler, den vorhandenen Meshy-Jungen, die Kamera, den Tempel,
die vorhandenen Stadtcollider und `city_exploration_state.gd`.

Die eigene Architekturgruppe ergänzt:

- ein 20 × 12 m großes Straßenstück mit 15 Basoli-Modulen in einem MultiMesh
  bei Oberkante 0,115 m;
- einen gemeinsamen, auf dieselbe Höhe abgestimmten Laufboden;
- zwei Amphoren seitlich am vorhandenen Stand `Market_32_Type3_Build1_Size1`;
- eine Garküchentheke neben `Market_35_Type6_Build1_Size1`.

Die ursprünglichen Standmeshes, Hauptstraßen und Gebäude werden beibehalten.
Der Anschluss erfordert die gelesene Stadthierarchie. Bei unbekannten Knoten,
unbekanntem Profil oder einer gleichnamigen fremden Gruppe liefert er einen
No-op-Bericht und verändert keine fremden Knoten. Ein Ressourcenfehler löscht
keine zuvor funktionierende Ergänzung. Wiederholte Installation sammelt keine
doppelten Gruppen an.

Low entfernt nur diese optionalen Zusatzgruppen. Balanced verwendet LOD1 mit
75 m Sichtweite, High LOD0 mit 100 m und Very High LOD0 mit 130 m Sichtweite.
Die bestehende Stadt bleibt außerhalb dieser Grenzen sichtbar. Diese Werte
sind vorläufige Detailbudgets, keine gemessenen Android-Leistungswerte.

## Herkunft und weitere Ergebnisse

Die kompakte GLB enthält sieben wiederverwendbare Modularten mit je drei LODs
und eingebetteten eigenen Projektmaterialien. Ihr SHA-256 lautet:

`f9fb217e5770dacb198e6ca569b0b0fa5351fc70ec52add93dab07f97a72a638`.

Die vollständigen editierbaren Blenderquellen, Figurenmaterialien und der
funktionierende Markt liegen im getrennten
[Unterstützungszweig](https://github.com/Ullmann27/Imperathen/tree/feature/city-detail-commerce-support-20261125).
Die [dortige Übergabe](https://github.com/Ullmann27/Imperathen/blob/feature/city-detail-commerce-support-20261125/docs/26_city_support/DELIVERY.md)
enthält Renderbilder, Prüfberichte, Quellen und den Handelsvertrag.

Dieser Anschluss aktiviert kein zweites Wirtschaftsmodell. Die Ladennähe des
separaten Handelsmoduls muss auf die tatsächlichen großen Stadtorte abgebildet
und mit der parallelen Arbeit aus PR #57 abgestimmt werden, bevor es hier
eingeschaltet wird. Die neue Marktprüfszene darf nicht als zweiter Spieler samt
Kamera in den Stadtrundgang gesetzt werden.

## Prüfumfang

`city_exploration_detail_adapter_test.gd` lädt die tatsächliche kleine
Architekturbibliothek. Das Stadtfixture besitzt die echten Knotennamen und
belegte Straßenhöhe; es ersetzt die große Stadt-GLB für diesen gezielten Test.
Geprüft werden Instanzzahl, Höhenübergang mit echten Physikstrahlen,
Idempotenz, Erhalt der Originalknoten, Profilverhalten und Konfliktfälle.

**Ausgeführt: 32/32 Fixture-Prüfungen, Exit 0.** Zusätzlich bestand der
tatsächlich geänderte `city_exploration.gd` die Godot-Syntaxprüfung.
Der [Prüfbericht](evidence/overlay/report.json) nennt Engine, Quellhashes und
beide Rohprotokolle. Die reduzierte Arbeitskopie enthält gezielt die benötigten
Ressourcen. Ein anfänglicher vollständiger Editorimport meldete deshalb
fehlende andere Hauptspielressourcen; er wird nicht als vollständige
Projektabnahme gewertet. Die beiden gezielten Abschlussprüfungen liefen ohne
Skriptfehler und mit vollständigen benötigten Ressourcen.

```sh
godot --headless --path prototype --import --quit
IMPERATHEN_ISOLATED_TEST=1 godot --headless --path prototype --script res://tests/city_exploration_detail_adapter_test.gd
```

Die Integration in `city_exploration.gd` besteht aus dem Preload und einem
Aufruf auf dem bereits geladenen `city`-Knoten. Ein vollständiger Rundgang
durch die große Stadt, die tatsächliche Android-Bildrate und der Übergang
auf dem Telefon sind mit diesem kleinen Hierarchie-/Physiktest nicht
abgenommen. Es wurde keine neue APK gebaut und nichts nach `main` übernommen.
