# Läden, Ausrüstung und das Zuhause als Basis (D-058)

Stand: 26. November 2026, Zweig `feat/meshy-assets-shops-20261126`. Was davon ausgeführt und geprüft ist, steht ausschließlich in [STATUS.md](STATUS.md). Dieses Dokument beschreibt den Aufbau und die Lücken.

Der Auftraggeber will die Struktur eines üblichen Open-World-Spiels: Läden, Missionsabholung und eine Basis. Die Basis ist zuerst das Elternhaus in Valdora, später die Heimatstadt; der Spieler zieht weiter und findet Arbeit in anderen Städten. Die vorhandenen Meshy-Modelle gehören in die passenden Läden, bessere Schwerter sehen besser aus und kämpfen besser.

## 1. Was neu ist

| Teil | Datei | Aufgabe |
| --- | --- | --- |
| Ausrüstungskatalog | `prototype/assets/shops/gear_catalog.json` | Gegenstände mit Familie, Handbuchpreisen Q0–Q4, Zugangsregeln, Epochenfenster, vier Läden und die Truhe zu Hause |
| Ausrüstungsmarkt | `prototype/scripts/domain/gear_market.gd` | Kaufen, Verkaufen, Anlegen, Einlagern über Befehle des Weltmodells; Belege für Besitz und Geld |
| Sichtbare Ausrüstung | `prototype/scripts/visuals/gear_visuals.gd` | Qualitätsbild, Beschläge, Trageplätze an der Figur |
| Laufzeitmodelle | `tools/art/build_meshy_gear.py`, `prototype/assets/meshy/gear_profiles.json` | Blender-Ableitung aus den gesperrten Meshy-Quellen |

Die bisherigen Marktwaren (`city_trade.gd`: Brot, Tunika, Dienstausrüstung, Auszeichnungen) bleiben unverändert. Der Ausrüstungsmarkt steht daneben und benutzt dieselbe Geldbörse (`resources.denarii`) und dieselbe Händlerkasse.

## 2. Läden und Sortiment

| Laden | Zugang | Sortiment | Vorgesehener Ort |
| --- | --- | --- | --- |
| Schmied und Waffenhändler (`smith`) | frei | Gladius, Pugio, Stoßspeer, Handaxt, Rundschild | Stadt: Stand `armorer`; Valdora: Schmiede |
| Legionsausstatter (`outfitter`) | nur Soldaten im Dienst | Gladius, Pilum, Scutum, Reiterschild, Reiterlanze, Spatha | Aquileia (Ort fehlt) |
| Stall und Pferdehändler (`stable`) | frei | Reisepferd | Aquileia oder Gutshof (Ort fehlt) |
| Markt (`market`) | frei | Schleuder, gebrauchte Handaxt, gebrauchter Rundschild | Stadt: Stand `clothier`; Valdora: Markt |

Ein Laden ohne Ort in der jeweiligen Siedlung bleibt geschlossen („… ist an diesem Ort nicht erreichbar"). Die Orte kommen als `gear_sites` aus der Darstellung ins Weltmodell, genau wie die geprüften Marktstände der Stadt.

**Noch nicht angeschlossen:** Keine Szene setzt bisher `gear_sites`, und weder das Stadtpanel noch das Dorf-HUD senden die Ausrüstungsbefehle. Im laufenden Spiel ist deshalb noch kein Ausrüstungsladen bedienbar; Kauf, Verkauf, Anlegen und Truhe sind über die Befehle des Weltmodells vorhanden und werden in den Tests mit gesetzten Orten ausgeführt. Der Aufruf, der angelegte Stücke an der Spielfigur zeigt (`game_world.gd`), ist eingebaut.

Registriert, aber ohne Modell nicht im Angebot: Muskelpanzer, Armbrust, Hörnchensattel, Kompositbogen. Der Katalog nennt je Eintrag den Grund (`unlisted_reason`). Reine Textgegenstände gibt es in den Läden nicht (Handbuch S. 82).

## 3. Qualitätsstufen

Preise sind die Zeilen des Handbuchs (S. 113–124), 1 Spielmünze = 1 Denar im Prototyp. Ergänzungen ohne Handbuchzeile folgen dem Stufenverhältnis des Handbuchs (0,32 / 0,65 / 1 / 1,8 / 3).

| Stufe | Preis Gladius | Voraussetzung | Sichtbarer Unterschied |
| --- | ---: | --- | --- |
| Q0 beschädigt/alt | 27 | Grundzugang des Gegenstands | Rostfilm, stumpf, Lederriemen-Reparatur am Griff oder Schaft |
| Q1 gebraucht | 55 | Grundzugang | leichter Flugrost, matter |
| Q2 solide | 85 | Grundzugang | unverändertes Modell |
| Q3 hochwertig | 153 | Können ≥ 45 **oder** Fürsprecher im Fach | poliert; Stichblatt und Vernietknauf aus Messing |
| Q4 Meisterarbeit | 255 | Können ≥ 65, bestätigter Erfolg **und** Fürsprecher | Hochglanz; zusätzlich Griffzwingen |

Grundzugang: alle Stücke mit Kampfplatz erst ab 18; Waffen und Schilde nach abgeschlossener Waffenausbildung; Pilum, Scutum, Reiterschild, Lanze und Spatha nur im Dienst; die Lanze nur mit eigenem Pferd; Rangstücke nur mit Ernennung (ein Rang wird verliehen, nicht gekauft). Verkauf bringt 40 % des Stufenpreises.

Die Stufe wirkt im Kampf nur über die gemeinsame Formel (`scripts/battle/combat_formula.gd`, D-042): Der Markt liefert `family`, `quality` und `wear`, die Formel rechnet. Q4 gegenüber Q1 sind rund 17 % mehr Schaden; Ausbildung wiegt schwerer.

## 4. Epochen

Was es wann gibt, entscheiden `item_families.json` und `era_registry.json`. Ein Gegenstand außerhalb seines Fensters wird nicht angezeigt und kann nicht gekauft werden; er bleibt aber registriert.

| Gegenstand | Fenster | 58 v. Chr. |
| --- | --- | --- |
| Gladius, Pilum, Scutum, Pugio, Speer, Axt, Schleuder, Rundschild, Reiterschild, Lanze, Pferd | Familienspanne | verfügbar |
| Spatha | ab 14 n. Chr. (Modellvariante der Familie Langschwert) | verborgen |
| Muskelpanzer (Paradeausführung) | ab 27 v. Chr. | verborgen |
| Armbrust (Spielkonzept) | ab 100 n. Chr. | verborgen |

Zwei Modelle zeigen spätere Formen einer 58 v. Chr. gültigen Familie: der Gladius den Typ Pompeji, das Scutum die rechteckige Form. Beide sind im Katalog so vermerkt; siehe Entscheidungen in STATUS.md.

## 5. Zuhause als Basis: Zuordnung zu den vorhandenen Systemen

| Baustein | Vorhanden | Fehlt |
| --- | --- | --- |
| **Zuhause** | Elternhaus in Valdora (`village_layout.gd`, `baker_home`; Kindheitspunkte `family_entrance`, `family_rest`); Innenräume im Paket Hausinnenräume | Ein eigener Besitz- oder Wohnstatus des Spielers; Schlafen als Zeitfortschritt mit Kalenderbuchung |
| **Lager** | Neu: Truhe im Elternhaus mit 24 Plätzen (`gear_store`, `gear_take`), nur vor Ort bedienbar, im Spielstand belegt | Möbelstück mit Anker im Innenraum; Bedienoberfläche; Lager für Marktwaren und Rohstoffe |
| **Missionsabholung** | Kindheitsaufträge als Datenschritte (`assets/story/missions/`, `mission_data.gd`), Auftraggeber über `village_talk` und `village_childhood_action`; Arbeitsfreigabe durch Decimus (`village_request_work`); Grenzkapitel mit Lieferauftrag (`frontier_chapter.gd`) | Ein allgemeines Auftragsangebot je Ort (wer gibt was, wann, mit welchem Lohn); Annahme, Ablage und Abrechnung als eine Schnittstelle |
| **Arbeit in anderen Städten** | Stadtbegehung mit sechs Marktständen (`city_exploration.gd`, `city_market_bridge.gd`); Weltzeit und Stammeswelt; Stadtkatalog der Gebäudefamilien | Reise zwischen Orten im selben Spielstand (die Stadt läuft als eigene Sitzung mit eigenem Speicherstand); Auftragslisten je Stadt; Ruf je Ort |
| **Läden** | Marktwaren der Stadt; neu der Ausrüstungsmarkt mit vier Läden | Orte für Ausstatter und Stall; begehbare Läden mit Regalen (Paket Innenräume: Schmiede mit Bestand); Bedienoberfläche für die Ausrüstung |
| **Geld** | `resources.denarii` mit Bilanzprüfung; Händlerkasse | Start ohne Geld für reguläre Spiele (D-017) ist im Weltmodell noch nicht umgesetzt; die Altersregeln des Ausrüstungsmarkts hängen nicht vom Geld ab |

## 6. Anschlüsse für andere Pakete

- **HUD/Inventar:** `GearMarket.view(data, shop_id, sites)` liefert Angebote (Preis, Bestand, Kaufbarkeit mit Grund, Modellpfad, Qualitätsbild) und das Inventar (Anlegen, Verkaufswert, Einlagern). Befehle: `gear_buy`, `gear_sell`, `gear_equip`, `gear_store`, `gear_take`.
- **Innenräume/Schmiede:** `GearVisuals.instantiate(item_id, quality, lod)` gibt ein fertiges Requisit mit dem Bild seiner Stufe. Orte der Läden werden als `gear_sites` gesetzt.
- **Nahkampf und Truppen:** `GearMarket.combat_inputs(data)` gibt Waffe, Geschoss, Schild und Rüstung als Eingaben der Formel. Verschleiß meldet die Formel zurück; das Buchen auf das Stück fehlt noch.
- **Germanische Krieger:** `mount_legacy_bay_horse_{0,1,2}.glb` (statisch, mit Sattel-, Reiter- und Kopfanker) und der Wurfspeer-Ersatz `weap_germanic_spear`. Ein Reitskelett gibt es nicht.

## 7. Technik und Quellen (D-050)

- **LOD:** Handgebaute Stufen je Datei statt nur automatischer Mesh-LOD, weil dünne Teile (Schaft, Riemen, Ring) vor der Reduktion geschützt werden müssen und die Fernstufen kleinere Texturen tragen. Die Godot-Dokumentation empfiehlt für entfernte Meshes, teure Materialmerkmale wie Normal Maps zu reduzieren, da LOD allein die Pixellast nicht senkt ([Godot: Visibility ranges (HLOD)](https://docs.godotengine.org/en/4.7/tutorials/3d/visibility_ranges.html)).
- **Flache Schichtteile:** Der ovale Reiterschild besteht aus getrennten flachen Lagen. Eine Kantenkollaps-Reduktion zerreißt sie; koplanare Flächen werden deshalb zuerst aufgelöst (Blender „Decimate/Planar"), erst danach wird kollabiert.
- **Texeldichte:** Zielwert 512–1024 px/m für Requisiten in der Verfolgerkamera, mehr für Stücke in der Hand ([Texture resolution guide](https://www.strayspark.studio/blog/texture-resolution-guide-games-512-1k-2k-4k), [Polycount-Diskussion](https://polycount.com/discussion/comment/1740644)). Die gemessenen Werte je Stufe stehen in `docs/20_meshy_assets/gear-build.json`.
- **Nicht umgesetzt, als nächster Schritt sinnvoll:** attributbewusste Vereinfachung und KTX2/Basis-Texturen mit gltfpack ([meshoptimizer/gltfpack](https://raw.githubusercontent.com/zeux/meshoptimizer/master/gltf/README.md)). Das Werkzeug ist in dieser Umgebung nicht installiert; die Dateien tragen JPEG-Texturen, die Godot beim Import für das Zielgerät komprimiert.
