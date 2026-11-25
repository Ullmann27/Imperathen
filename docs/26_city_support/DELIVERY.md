# Stadtunterstützung: Detailarbeit, Markt und Übergabe

Stand: 25. November 2026. Arbeitszweig: `feature/city-detail-commerce-support-20261125`.
Ausgangsstand: `7af39f35b1947595f95e365eb7762592feabf234` auf
`feature/team-b-living-world-20261124`.

## Ergebnis und Aufgabenverteilung

Heinz beauftragte ausdrücklich drei unterstützende Agenten für die parallel
entstehende Stadt. Die drei Fachaufgaben waren Architektur, Figurenmaterialien
und Handel/Karriere. Die gemeinsame Integration enthält echte Blenderquellen,
exportierte Spielobjekte, Regelcode und eine begehbare Prüfszene. Sie ist kein
neuer Hauptspielstand und kein Ersatz für den Stadtrundgang des anderen Chats.

| Fachblock | Geliefert | Nachweis |
| --- | --- | --- |
| Architektur | Sieben Module mit je drei Detailstufen: polygonales Steinpflaster, Rand/Rinne, Ladenhülle, Garküchentheke, Stoffdach, Amphoren, Brotbrett | [Architekturvertrag](ARCHITECTURE.md), echte GLB-Prüfung und 94 Godot-Prüfungen |
| Figuren | Ergänzte Haut-, Leinen- und Ledermaterialien am vorhandenen Hero und an geprüften Frontier-Materialen; Originalfarben und Rig bleiben erhalten | [Figurenübergabe](../../tools/city_detail/characters_review/README.md), 79 Godot-Prüfungen und vier Blender-Vergleichsbilder |
| Handel/Karriere | Sechs Läden, 16 Waren, Kauf/Verkauf, Verbrauch, Anlegen, einmalige Dienstausgabe und belegte Auszeichnungen | [Handelsvertrag](../city_detail/TRADE.md), [Regel- und Regressionsberichte](../city_detail/evidence/trade/report.json) |
| Gemeinsame Szene | Echte Touchbewegung, sieben vorhandene Figuren, Ladenoberfläche, Beutel, getrennte Besuchsspeicherung und vier Qualitätsprofile | [Finale Prüfausgaben](evidence/checks/validation_report.json), [echte Godot-Bilder](evidence/market/city-support-review.json) |

## Sichtbare Detailarbeit

Die Architektur enthält geometrische Fugen, gebrochene Steinkanten, einzelne
Dachelemente, Türgewände, Holzprofile und offene Gefäßmündungen. Diese Formen
existieren in der exportierten GLB; sie sind nicht allein Eigenschaften einer
Blenderansicht. Die Materialkarten, UVs, Normalen und Tangenten wurden am Export
geprüft. Pflaster und Randsteine werden gemeinsam instanziert.

In der Prüfszene besitzen die Brotbrettchen tatsächliche Tischplatten, Beine
und Querstreben. Die Tische stehen seitlich, sodass der zentrale Ladenzugang
frei bleibt. Der gemeinsame Laufboden endet auf derselben Höhe wie das Pflaster.
Die Randsteine laufen längs der Straße; ihre erhöhten Gehflächen besitzen
passende gemeinsame Collider. Das Tageslicht wurde nach der ersten Bildprüfung
reduziert, damit helle Fassaden und Waren ihre Oberflächen behalten.

Die Figurenänderung ist ein Materialpass: vorhandene Normalinformationen werden
mit feinen Details kombiniert, nicht durch eine leere neue Karte ersetzt.
Die Anwendung ist auf bekannte Haut-, Leinen- und Ledermaterialien beschränkt.
Low/Balanced sowie entfernte Stufen stellen die ursprünglichen Materialien
wieder her. Die 16 geprüften Quellen sind vorhandene GLB-Dateien unterschiedlicher
Nahstufen, keine 16 neu erschaffenen Personen. Neue Gesichtsmorphs, Frisuren oder
Animationen sind nicht Teil dieses Materialpasses. Der gemischte Atlas des
neuen Meshy-Jungen wird nicht pauschal überschrieben.

Das Figuren-Blenderprojekt besteht aus `hero_city_detail.blend` und dem
zugehörigen relativen Ordner `tools/city_detail/characters_review/textures/`.
Zum Bearbeiten beide gemeinsam auschecken. Die ursprünglichen Bilddaten bleiben
verlustfrei erhalten; das erneute Öffnen und die Übereinstimmung von Geometrie,
Rig und Materialaufbau sind im Figurenbericht geprüft.

## Spielbarer Ablauf

Die optionale Szene startet einen zwölfjährigen Jungen ohne Zeitsprung und
ohne eine neue Mission zu erzwingen. Der vorhandene `WorldModel` bleibt die
Regelautorität. Der Besuch aktiviert seinen Stadtmarkt ausdrücklich und nutzt
dieselben Denare, atomaren Befehle und dieselbe endliche Händlerkasse.

| Anlaufstelle | Nutzbarer Inhalt |
| --- | --- |
| Bäckerei | Brot kaufen und verkaufen |
| Lebensmittelstand | Oliven, Käse, getrocknete Feigen |
| Garküche/Trinkwasser | Eintopf und Wasser |
| Töpferei | Tonbecher und Öllampen |
| Tuch-/Lederwaren | Tunika, Wollmantel, Ledergürtel |
| Ausrüstungsschmiede | Waffen, Schild, kostenlose erste Dienstausgabe und bestätigte Auszeichnungen |

Ein ausgebildeter erwachsener Soldat erhält Gladius, Scutum, Leinentunika und
Ledergürtel genau einmal kostenlos. Die Ausgabe ist eine beauftragte Spielregel.
Die Kindheitsfigur erhält deshalb keine Waffen. Belegte Wachhilfe, Verteidigung,
Versorgung und ein tatsächlicher Sieg können einmalige Belohnungen auslösen.
Erlernte Erfahrung bleibt von angelegten Gegenstandsboni getrennt. Kampf und
Abwehr wirken auf den vorhandenen Kontakt beziehungsweise das Schutzfenster;
Kommando wirkt begrenzt auf die vorhandene Truppmoral.

Die Prüfszene führt keine komplette spätere Karriere im Zeitraffer aus. Die
Regeltests erreichen die erwachsene Ausbildung über bestehende Spielbefehle.
Das ist von einem menschlichen vollständigen Kampagnendurchlauf zu unterscheiden.
Speisen besitzen bereits Verbrauch und Wirkung; Essensanimationen und sichtbare
Wechsel jedes Kleidungsstücks gehören noch nicht zum Lieferumfang.

## Anschluss an die große Stadt

Der beobachtete Stadtstand heißt
`feature/meshy-player-city-exploration-20261125`, Commit
`5b5eecad31e395e3ead48b3e631d9f48690480a6`.
Sein `city_exploration.gd` besitzt eine eigene Spielfigur, Kamera, Touchsteuerung,
Kollisionswelt und Besuchsspeicherung. Er startet ausdrücklich keine Kampagne.

Der neue `city_exploration_detail_adapter.gd` ergänzt ausschließlich seine
eigenen markierten Architekturgruppen unter `RomanCity`. Er verwendet die
tatsächlich gelesenen Stadtkoordinaten und Standnamen. Am Ende von `_load_city()`
genügt nach dem Preload der Aufruf mit dem geladenen Stadtknoten und `profile`.
Der separate [Draft-PR #60](https://github.com/Ullmann27/Imperathen/pull/60)
enthält diese konkrete Änderung im Commit
`de2aeaad19ded95ca055261b2a5b9cc3f668aa1e`. Die vollständige
Marktprüfszene darf nicht als zweiter Spielmodus innerhalb dieser Stadt
instanziert werden.

Der Adapter ergänzt ein 20 × 12 m großes Pflasterstück auf der Hauptstraße bei
y=0,115 m, einen passenden gemeinsamen Laufboden und seitliche Gefäße/Theke an
vorhandenen Marktständen. Er ersetzt keine bestehenden Gebäude. Low schaltet
die Ergänzung ab; andere Profile verwenden reduzierte beziehungsweise nahe
Detailstufen mit begrenzter Sichtweite. Wiederholte Installation verwaltet nur
die eigenen Gruppen. Die Adapterprüfung verwendet ein dokumentiertes Fixture
mit den echten Knotennamen; sie ersetzt nicht den noch ausstehenden vollständigen
Rundgang durch die große Stadt auf Android.

### Noch offene gemeinsame Handelsanbindung

Die Weltorte der großen Stadt sind andere als die sechs Orte der kleinen
Prüfszene. Die neue Wirtschaft darf dort erst nach einer gemeinsamen Orts- und
Zustandsanbindung aktiviert werden. Im beobachteten Stadtgenerator liegt der
zentrale Markt auf Z=47; die eigentliche Bäckerei und Schmiede liegen an den
äußeren Parzellen. `city_catalog.json` ist dagegen das Modellpark-Verzeichnis,
kein Ladenverzeichnis.

[PR #57](https://github.com/Ullmann27/Imperathen/pull/57) arbeitet parallel an
Innenräumen, Ausrüstungsobjekten und einem angekündigten `roman_commerce.gd`.
Am geprüften Commit `1c0575096bd51c7da9e1ab83bcb2abf61306d0b9` war nur dessen
Koordinationsvertrag veröffentlicht. Eine zweite fertige Geldverwaltung ist
dadurch nicht belegt. Vor der gemeinsamen Integration müssen Kataloge, Orte,
Inventar und Einmalbelohnungen auf eine Transaktionsautorität abgestimmt werden.
Der genaue Lesebefund steht im [Koordinationsnachweis](../city_detail/evidence/trade/parallel_commerce_review.json).

## Ausführen und nachprüfen

```sh
godot --headless --path prototype --import --quit
godot --path prototype res://scenes/city_support_district.tscn

python tools/check_prototype.py --only city_trade city_character_detail city_support city_exploration_detail --report docs/26_city_support/evidence/checks
python tools/city_detail/architecture_verify.py
python tools/city_detail/architecture_check.py

LP_NUM_THREADS=2 python tools/cinematic/capture_settlement.py --script res://tests/city_support_graphics_review.gd --output docs/26_city_support/evidence/market --resolution 1280x720 --quality very_high
```

WASD oder linker Touchstick bewegt die Figur. Umschalt erlaubt auf dem Desktop
Laufen. Rechte Maustaste beziehungsweise Wischen rechts dreht die Kamera.
Die Schaltflächen öffnen einen nahen Laden oder den Beutel. Speichern/Laden
verwendet ausschließlich `user://imperathen_city_support.json`; ein beschädigter
vorhandener Besuchsspielstand wird nicht automatisch überschrieben.

Die Nachweise enthalten echte Engineausgaben, Hashes und Szenenbilder. Der
Oberflächentest verwendet tatsächliche Touchereignisse für Bewegung und Kauf;
Ortswechsel zwischen den Prüfstationen sind ausdrücklich Testpositionierungen.
Die Bilder werden vom Godot-Viewport gespeichert. Es gibt keinen nachträglich
gemalten Spielbildersatz. Die Architektur-MultiMesh-Rückleseprüfung benötigt
den echten Grafikpfad, weil Godots Headless-Dummy dafür keine reale
Instanztransformation zurückliefert.

Bei der Endkontrolle wurden die vier Figurenkarten auf tatsächliche Mipketten
umgestellt und die importierten `CompressedTexture2D`-Ressourcen geprüft.
Die Importmetadaten werden mitgeliefert. Die Architekturtexturen besaßen bereits
vollständige Ketten. Grafikläufe endeten zwischenzeitlich mit Signal 9; die genaue
externe Ursache ist nicht belegt. Deshalb sind der vollständige Verhaltenstest
mit 36 Prüfungen und die abschließende Bildprüfung getrennte Prozesse. Der
Bildtest startet eine frische Szene mit dem höchsten Profil, prüft einen echten
Touchkauf und speichert vier Kamerablicke. Ein doppelter anfänglicher
Architekturaufbau wird vermieden; die Kamera steht vor der ersten Händler-LOD-Wahl
an ihrer tatsächlichen Position. Diese Softwareaufnahme ist keine Android-
Speicher- oder FPS-Messung.

## Android und Aussagegrenzen

Vorhanden sind drei reduzierte Architektur-LODs, gemeinsam genutzte Meshes und
Materialien, MultiMesh-Bündelung, Mipmaps und anisotrope Filterung. Die feineren
Figurenkarten werden gezielt zugeschaltet. Dies sind konkrete Mittel zur
Entlastung, aber keine auf dem Telefon gemessene Leistungszusage.

Blender 4.3.2 und Godot 4.7.2 wurden lokal verwendet. Die grafische Prüfung läuft
über OpenGL/Mesa mit Softwaredarstellung. Eine stabile Android-Bildrate,
Wärmeentwicklung, Speicherfreigabe auf dem Fold7, neue installierte APK oder
fertige PC-/AAA-Qualität wird mit diesem Paket nicht behauptet. Die Änderungen
liegen in Unterstützungszweigen und Draft-PRs; sie sind nicht nach `main`
übernommen.
