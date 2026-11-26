# Valdora – Innenräume der Wohnhäuser (Paket I, Runde 1)

Stand 26.11.2026, Branch `feat/house-interiors-detail-20261126`. Gilt für das italische Dorf Valdora (Kampagnenjahr 58 v. Chr., Umland von Aquileia, Gallia Cisalpina). Die Stadthäuser aus `tools/world/build_roman_test_city.py` sind ein späteres Paket.

## Bestand (aus dem Code)

| Gebäude | Quelle | Betretbar | Boden | Licht innen |
| --- | --- | --- | --- | --- |
| 20 Wohnhäuser `Layout.HOMES` | `regional_village.gd`, `frontier_house.glb` | ja, Tür +Z, Rampe | 0,3925 m, Kollision | Herdfeuer (neu) |
| davon `baker_home` (Familienhaus) | I-01-Abschnitt | ja | wie oben | keines (Befund für I-01) |
| Atriumhaus (14, 0, −30) | `atrium_house.glb` | ja, Fauces | 0,065 m | Kohlebecken (neu) |
| Schmiede (Anbau) | `settlement_dressing.gd` | offen | Gelände | Esse (neu) |
| Werkstatt, Lager, Markt | `village/*.glb` | offen/teilweise | Gelände | – |
| Spielerhütte `village_art.hut()` | `game_world.gd` | ja (Baumodus) | 0,14 m | – (nicht Teil dieser Runde) |

Alle 20 Wohnhäuser teilen dieselbe Hülle (Innenmaß 5,36 × 4,34 m, Wandkrone 2,87 m über dem Boden). Darin liegen fest: Tisch (NW, Platte 0,85 m), Wandbank (Ostwand, 0,50 m), Vorratskrug (SW neben der Tür) und der nach innen geöffnete Türflügel. Bisher stand in allen Häusern derselbe generische Satz aus Bett, Regal, Krügen, Bechern, Brot und Hocker, ohne Herd und ohne Lichtquelle.

## Haushalte und Ausstattung

Haushaltszuordnung nach Kennung und den Bewohnern in `village_layout.gd`; Familienangaben und Wohlstand sind Designannahmen. Die vollständigen Stücklisten stehen in `household_designs.gd` und werden vom Test gegen die gebaute Szene geprüft.

HAUSHALTSTABELLE

## Quellen und Annahmen

Belegt (Text oder Archäologie, Zeitstellung beachtet):

- Cato, *De agri cultura* 10–11 (um 160 v. Chr.): Inventare eines Guts mit Betten, Decken, Vorratsgefäßen (*dolia*), Handmühlen, Kochgeschirr; 74–76: Backen unter der irdenen Glocke (*sub testu*) – Bäckerherd mit *testum*.
- Plautus, *Aulularia*, Prolog (um 190 v. Chr.): Lar familiaris am Herd des Hauses – Hausaltar.
- Varro, *De lingua Latina* 5,125 (um 45 v. Chr.): steinerner Tisch (*cartibulum*) am Impluvium – Atriumhaus.
- Asconius zu Ciceros *Pro Milone* (Ereignisse 52 v. Chr.): Webstühle, die „nach altem Brauch im Atrium“ standen – Webstuhl im Atrium.
- Strabon 5,1,12: in der Gallia Cisalpina Wein in Holzfässern – Fässer bei Winzerin und Fassbinder (Strabon schreibt um die Zeitenwende, also später).
- Varro, *Res rusticae* 2,11 (37 v. Chr.): Käseherstellung – Milch- und Käsehaushalt.
- Polybios 6,23: ovaler Schild (*scutum*); Helmtyp Montefortino (4.–1. Jh. v. Chr.) – Ausrüstung der Wache.
- Archäologie: Weinamphore Dressel 1A (Italien, ca. 130–50 v. Chr.); Gewichtswebstuhl mit pyramidenförmigen Tongewichten; Drehmühle (in Italien seit dem 3./2. Jh. v. Chr.); eiserne Feuerböcke der Spätlatènezeit; republikanische Öllampen.

Designannahmen (nicht einzeln belegt, bewusst gekennzeichnet):

- Ein offener Bodenherd im Wohnraum jedes Hauses (keine eigene Küche); Rauchabzug über Tür, Fenster und Dachdeckung.
- Gedrechselte Bettfüße und Kopflehne (*fulcrum*) beim Ältestenhaus; Schrank (*armarium*), Dreifußtisch und Korbsessel im Atriumhaus. Erhaltene Stücke dieser Art stammen überwiegend aus Pompeji/Herculaneum (79 n. Chr.) oder sind später; für 58 v. Chr. sind sie plausible Vorläufer, keine Belege.
- Binsenmatten, Färbungen (Krapp, Wau, Waid, naturbraun) und die Zahl der Kinder je Haushalt.
- Valdora hat im aktuellen Layout keine Taverne (*caupona*). Laden/Taberna: Tuchhändlerin mit Ladentisch; Bäckerin mit Brotregal.

## Technik

- `art/interiors/interior_surfaces.py`: 15 periodische PBR-Sätze (Albedo, Normal, ORM; Glut zusätzlich Emission), 512², eigene Prozedur.
- `art/interiors/build_interior_kit.py` + `kit_geometry.py` (Blender 4.3.2): KIT_ANZAHL Requisiten mit echten Profilen (Gefäße hohl, Fassdauben, Webgewichte, Decken als Tuch mit Dicke), abgefaste Kanten, Godot-Importstufen (LOD) je Requisit. `kit_manifest.json` hält Maße und Dreiecke.
- `prototype/scripts/world/village/interior_kit.gd`: Materialien je Qualitätsstufe (Leicht ohne Normalmap, Hoch/Sehr hoch mit AO und anisotroper Filterung), Auflagehöhen, Kollisionsformen.
- `household_designs.gd`: Haushalte, Stücklisten, Hüllenmaße, Laufziele.
- `house_interiors.gd`: platziert, legt je Haus und Ebene (Möbel, Kleinteile) ein Mesh mit einer Fläche je Material an, erzeugt die Kollision (in allen Profilen gleich) und Herdlicht. Sichtweite Möbel/Kleinteile: Leicht 10/5 m, Ausgewogen 14/7 m, Hoch 24/12 m, Sehr hoch 30/16 m (aus einer Straßenabschätzung: Ausgewogen im Median etwa 22, im 95. Perzentil etwa 52 zusätzliche Zeichenaufrufe vor Frustum-Culling bei 350 erlaubten). Nur das der Kamera nächste Feuer leuchtet als echtes OmniLight (Ausgewogen bis 9 m, Leicht keines), ohne Schatten.
- Einbindung: `regional_village.gd` (+8 Zeilen), `settlement_dressing.gd` (`release_household()` angehängt; die Türvorräte außen bleiben).

## Prüfungen

TESTERGEBNISSE

## Bilder und Kosten

BILDER

## Offene Punkte

OFFEN
