# Weltgröße, Ladeplanung und Römermodelle

Recherche und ausführbarer Planer: 23. November 2026. Diese Datei trennt implementierte Koordinaten-/Laderegeln, geplante regionale Inhalte und recherchierte Fremdassets. Kein gekauftes oder extern heruntergeladenes Menschenmodell wurde in diesem Arbeitsschritt ins Repository aufgenommen.

## Eigene große Welt statt einer unbelegten Vergleichszahl

Der Nutzer beschreibt GTA VI als Vorbild für eine große frei begehbare, bevölkerte Welt. Die offiziellen Rockstar-Seiten zeigen Leonida, unterschiedliche Regionen, Figuren und eine herunterladbare offizielle Karte. Aus den hier abgerufenen Primärseiten wurde keine belastbare Quadratkilometerangabe gewonnen. Deshalb bezeichnet die folgende Größe eine eigene Projektentscheidung und keine vermessene GTA-VI-Fläche.

- [Rockstar: GTA VI](https://www.rockstargames.com/VI)
- [Rockstar: People & Places / Only in Leonida](https://www.rockstargames.com/VI/only-in-leonida)
- [Rockstar: Media, einschließlich Leonida Map & Cover Art Poster](https://www.rockstargames.com/VI/media)

`prototype/scripts/world/world_stream_plan.gd` definiert eine **32 × 32 km große regionale Koordinatenwelt**, insgesamt **1.024 km²**, mit **128 × 128 Sektoren zu 250 m**. Das ergibt **16.384 adressierbare Sektoren**. Diese Größe ist ein technischer Weltrahmen. Sie behauptet keine vollständig ausgestaltete Welt und keine erreichte Bildrate auf einem Telefon.

Die regionale Karte enthält neun benannte Landschaftszonen, vierzehn Orte und sechzehn Straßenverbindungen. Jede geplante Ortschaft ist vom Ausgangsdorf über den Straßengraphen erreichbar. Die Namen bezeichnen eine fiktive Spielregion, keine archäologisch vermessene römische Provinz. Das bestehende Grenzdorf trägt den Inhaltsstatus `existing_village`; die dreizehn Fernorte tragen `planned`. Ihre Kartenposition allein erzeugt weder Gebäude noch Einwohner, Händler oder Quests.

Die Planerdaten umfassen Höfe, Waldarbeiterlager, Steinbruch, Brücke, Grenzwache, Marktstadt, Waldsiedlung, zwei Pässe, östliche Brüche, eine Furt, eine Flussstadt und einen Hafen. Dadurch sind Wirtschaftswege und spätere Überfall-/Bündnisrouten räumlich vorbereitet. Ein Handelsweg muss später aus dem wirklichen Handelszustand gespeist werden; die Kartenlinie selbst produziert keine Waren.

## Ausführbarer Vertrag für die Weltintegration

| Funktion | Ergebnis und Grenze |
| --- | --- |
| `bounds()` | Eigene Fläche, sektorisierte Ausdehnung und ausdrücklicher Planungsstatus |
| `sector_for_position(Vector3)` | Stabile Ganzzahladresse, auch für negative Koordinaten; Randwerte werden begrenzt, nichtfinite Werte abgewiesen |
| `sector_origin(Vector2i)` | Absoluter Sektorursprung; ungültige Adressen liefern keine gültige Nullposition |
| `local_coordinates(Vector3)` | JSON-fähige Ursprungs-/Lokalkoordinaten für spätere Ursprungsverschiebung; versetzt keine Figur |
| `region_at(Vector3)` / `region_label(Vector3)` | Benannter fiktiver Landschaftsbereich |
| `terrain_height(Vector2)` | Deterministische globale Höhenfunktion; bis 125 m um das Dorf flach, Übergang bis 500 m, Höhenbereich −35 bis 320 m |
| `points_of_interest()` / `roads()` | Kopierte Daten mit Inhaltsstatus; aufrufender Code kann die kanonische Karte nicht versehentlich verändern |
| `plan(Vector3, quality)` | Entfernungsgeordnetes Verlangen nach Sektoren; legt keine Nodes an und verändert keinen Spielstand |
| `transition(previous, current, create_budget)` | Priorisierte Erzeugungs-/LOD-Wechsel und Entlade-IDs mit begrenztem Erzeugungsbudget |
| `overview(Vector3, quality)` | Zusammenfassung für die Dorf-/Regionskarte, einschließlich tatsächlich bestehender Orts-IDs |

Jeder angeforderte Sektor besitzt `id`, `x`, `z`, `origin`, `lod`, `ring`, `collision`, `full_simulation`, `region_id` und `biome`. `origin` ist ein Array aus drei globalen Koordinaten. Nahsektoren erhalten den Anspruch auf Kollision und vollständige Simulation; der Planer führt diese Arbeit nicht selbst aus. Der Sektor der Spielerfigur steht immer an erster Stelle.

| Profil | Nahe Sektoren | Mittlere Sektoren | Ferne Sektoren | Höchstens gleichzeitig angefordert | Geplantes Detailpersonenbudget |
| --- | ---: | ---: | ---: | ---: | ---: |
| Niedrig | 1 | 8 | 24 | 33 | 16 |
| Ausgewogen | 9 | 16 | 32 | 57 | 32 |
| Hoch | 9 | 40 | 48 | 97 | 48 |
| Sehr hoch | 25 | 56 | 64 | 145 | 72 |

Diese Obergrenzen sind Arbeitsbudgets, keine vermessenen Leistungszusagen. Der Integrator muss Geometrie, Texturen, Animationen, Schatten und Physik zusätzlich budgetieren. Eine Figur, die als Fernzustand simuliert wird, bleibt dieselbe Person mit derselben Tätigkeit; der Darstellungswechsel darf keine Arbeiter, Ressourcen oder Vertrauenswerte vervielfachen. Das Detailpersonenbudget ersetzt keine Einwohnerobergrenze.

Die Höhenfunktion benutzt absolute Weltkoordinaten. Identische Grenzpunkte benachbarter Sektoren haben daher identische Höhen. Verschiedene LOD-Randauflösungen brauchen beim tatsächlichen Meshaufbau weiterhin gemeinsame Randpunkte oder Geometrieschürzen; die Höhenfunktion allein behebt keine T-Verbindungen. Eine vollständige Verschiebung des Weltursprungs ist noch nicht angeschlossen. Im Dorf wird die vorhandene Geometrie erhalten.

## Tatsächlich erzeugte Geländegrundlage

Der gemeinsame Adapter `prototype/scripts/world/regional_terrain.gd` setzt den Bedarf inzwischen in echte `ArrayMesh`-Sektoren um. Pro `follow()`-Aufruf entstehen höchstens zwei neue Sektoren. Jeder Sektor besitzt ein 12 × 12 Felder großes Dreiecksnetz und eine gemeinsame Kantenauflösung, auch bei einem Profilwechsel. Der Nahbereich erhält `StaticBody3D`-Kollision; entfernte Sektoren und nicht mehr benötigte Kollisionskörper werden freigegeben.

`prototype/tests/regional_terrain_test.gd` instanziiert diesen Produktionsadapter in einer echten Godot-3D-Welt. **862 Assertions bestanden**: erzeugte Vertex-/Normal-/Farbdaten, Godots Vorderseitenwindung, identische Nachbarkanten, einseitige Physikstrahlen im Dorf, positive und negative Fernpositionen, Weltgrenze, unmittelbare Kollisionsbereitschaft an Sektorübergängen, Profilwechsel von 145 auf 33 Sektoren und Rückkehr zu den ursprünglichen Node-/Orphan-Zahlen. Ein echter `CharacterBody3D` mit Kapselkollision landet auf dem Gelände und läuft ohne Verlust des Bodenkontakts über die 250-m-Sektorgrenze.

Damit ist eine **physikalisch begehbare, gestreamte Geländegrundlage** nachgewiesen. Die fern liegenden Städte, Lager, Einwohner und Handlungen bleiben geplante Inhalte. Der Test belegt noch nicht, dass der komplette Spielweltcontroller jede Position freigibt oder dass Ferninhalte bereits spielerisch ausgestaltet sind. Eine Bildabnahme und eine Messung auf einem physischen Android-Gerät sind hiervon getrennt.

Im protokollierten Headless-Prozess benötigten 280 `follow()`-Aufrufe zusammen 223,066 ms; der längste einzelne Aufruf dauerte 3,244 ms. Das sind beobachtete CPU-Zeiten in dieser Testumgebung, **keine Bildrate, keine Mobilmessung und keine dauerhafte Zeitgarantie**. Die tatsächlichen Quellen und das genaue Ergebnis stehen in `world-assets-review.json`.

## Geprüfte Assetkandidaten

Die technischen Angaben in dieser Tabelle sind **Angaben der jeweiligen Anbieter**, keine bereits an heruntergeladenen Bytes verifizierten Befunde. Download, tatsächliche Skelettstruktur, Animationsexport und Godot-Import sind bei diesen Fremdmodellen noch nicht nachgewiesen.

| Kandidat | Nachvollziehbare Angaben | Bewertung für IMPERATHEN |
| --- | --- | --- |
| [Andy Woodhead: Rigged for UE4 – Roman – free](https://sketchfab.com/3d-models/rigged-for-ue4-roman-free-a488272c15cc4aa5898c28e5141e939d) | Die indexierte Originalseite nennt CC Attribution, ungefähr 280.600 Dreiecke und 140.700 Vertices. Der Autor beschreibt den originalen FBX-Download und einen in UE 4.27 getesteten Mannequin-Anschluss. | Interessante frei lizenzierte Ausgangsfigur für eine Prüfung und mögliche LOD-/Retopologiearbeit. Die Dreieckszahl ist für zahlreiche gleichzeitig detaillierte mobile NPCs ungeeignet. GLB und übertragene Animationen wurden nicht bestätigt. Der direkte Abruf lieferte HTTP 403; kein Download und keine Integration erfolgt. |
| [Yevhen Huk: Roman Legionary Armor auf Fab](https://www.fab.com/listings/8fae7528-57cb-4111-a38a-e1ecf2ea4f9c) | Produktseite nennt rund 25.292 Dreiecke, Epic-Skeleton-Rig, 4K-PBR-Texturen, FBX und konvertierte GLB-/glTF-Dateien. Beschrieben wird Kettenrüstung mit dekorativer Offiziersgestaltung und mehreren Farbstellungen. | Technisch näher an einem begrenzten Detail-NPC. Verwendbarkeit als vollständiger Mensch sowie Kiefer/Gesichtsrig und enthaltene Bewegungsclips sind nicht nachgewiesen. Angebot verlangt Lizenz-/Kaufauswahl; Preis und konkrete Lizenz wurden nicht bestätigt, nichts gekauft. Farbvarianten ersetzen keine verschiedenen Menschen. |
| [Poly Haven: Stone Wall](https://polyhaven.com/a/stone_wall) und [Plastered Stone Wall](https://polyhaven.com/a/plastered_stone_wall) | Originalseiten bieten mehrere Auflösungen und Diffuse-, Normal-GL-, Rauheits-, AO-/ARM- sowie Displacementdaten. Stone Wall ist mit 2 m, Plastered Stone Wall mit 2,5 m physischer Breite angegeben. Poly Haven veröffentlicht seine Assets unter CC0. | Geeignete Materialquellen für eigene Mauern, beschädigten Putz und wiederaufgebaute Dorfhäuser. Dies sind Materialien, keine fertigen Häuser. Maßstab, Mipmap-/Kompressionsqualität und Materialwiederholung sind im Spiel zu prüfen. In diesem Schritt recherchiert, nicht neu importiert. |

[Poly Havens eigene Lizenzseite](https://polyhaven.com/license) bestätigt die CC0-Veröffentlichung seiner HDRIs, Texturen und Modelle sowie kommerzielle Verwendung und Weitergabe. [ambientCGs Lizenzdokumentation](https://docs.ambientcg.com/license/) bestätigt CC0 1.0 auch für seine Material-/Modell-Dateien; es ist eine ergänzende Materialquelle. Hier wird keine neue Rechtsposition über die Aussagen der Anbieter hinaus zugesichert.

### Zwei Funde mit deutlichen Grenzen

[MoonyState: Roman Legionary Rigged-Animated](https://www.fab.com/listings/69690f20-9332-4db6-92f3-f5600be1dc3e) nennt die Bewegungen Idle, Walk, Run, Slash und Impact, 4K-Texturen und einen Mixamo-basierten Blender-Rig. Der Anbieter warnt selbst vor anderen Programmen. Die Formatanzeige führt OBJ und konvertiertes GLB/glTF. Das ist kein Beweis, dass der konvertierte Download diese Skelett-/Animationsdaten enthält. Ein Kauf ohne Prüfung des Originalpakets wäre für die Integration unzuverlässig.

[Shuriken Studio: Roman Legionary Soldier](https://shuriken.studio/models/characters/roman-legionary-soldier) ist als kostenloses GLB mit 2.662 Dreiecken beschrieben. Der Anbieter bezeichnet ihn ausdrücklich als Cartoon-Modell. Er erfüllt damit den verlangten realistischen Menschenstil nicht und wird nicht als grafische Aufwertung übernommen.

## Historische Passung und Truppendarstellung

Eine beliebige als „Roman“ bezeichnete Rüstung passt nicht automatisch in jedes Jahrhundert. MoonyStates Modell wird beispielsweise ausdrücklich als Legionär des ersten Jahrhunderts beschrieben und enthält Segmentpanzer. Der Museumsdatensatz [London Museum A24145](https://www.londonmuseum.org.uk/collections/v/object-9423/fastening-hook-lorica-segmentata-fastening-hook/) datiert sein konkretes Segmentpanzer-Beschlagstück in die Mitte des ersten bis frühe zweite Jahrhundert. Diese Quelle belegt den einzelnen Fund; sie ist kein Freibrief für eine pauschale Rückdatierung aller gezeigten Ausrüstung. Für eine republikanische Startkampagne muss jede Rüstungsfamilie gesondert zum gewählten Jahr passen.

Ein Kohortenverband benötigt im Spiel einzelne Menschen und Rollen, Formation, Befehle, Waffen, Moral, Versorgung und Verluste. Ein zusammengebackenes „Kohortenmodell“ würde diese Mechanik behindern. Mehrere Gesichter, Körperproportionen, Kleidungszustände und Ausrüstungen sollen daher auf kompatiblen Rigfamilien beruhen. Wache, Legionär und Offizier sind Rollen mit unterschiedlichen Aufgaben; das Modell allein schafft diese Aufgaben nicht.

Für jedes tatsächlich übernommene Modell bleiben Originalquelle, Autor, genaue Lizenz, Datei-Prüfsumme, Polygon-/Materialzahl, Texturgrößen, Gelenke und Animationen zu erfassen. Es folgen Godot-Import, Maßstab, Füße/Boden, Hand-/Waffenkontakt, Gesicht, Kampfbewegungen, LOD-Wechsel und ein Blick auf mehreren Menschen gleichzeitig. Die lokale `game-dev`-CLI war nicht im PATH verfügbar; deshalb wird hier keine Prüfung durch dieses Werkzeug behauptet. Es wurden keine Anbieterjobs oder Käufe ausgelöst.

## Nachweis des Planers

`godot --headless --path prototype --script res://tests/world_stream_plan_test.gd` wurde mit der vorhandenen Godot-Version 4.7.2 ausgeführt: **5.241 gezielte Assertions, keine Fehler**. Die hohe Zahl entsteht aus einem Raster an globalen Höhen-/Grenzpunkten und aus den Sektorlisten aller vier Grafikprofile, nicht aus 5.241 verschiedenen Gameplay-Szenen.

Geprüft wurden negative Koordinaten, Weltgrenzen, NaN/Unendlich, JSON-fähige Übersicht, exakte lokale Rückrechnung, gültige und eindeutige Sektoren, alle LOD-Obergrenzen, Vorrang des Spielersektors, deterministische Höhen und Übergänge, flaches bestehendes Dorf, Wiederverwendung stabiler Sektoren, begrenzter Aufbau bei Bewegung/Profilwechsel und Erreichbarkeit aller geplanten Orte. Ein Headless-Planertest belegt weder Grafikqualität noch Handy-FPS. Die ergänzende tatsächliche Mesh-/Kollisionsprüfung des Adapters ist oben gesondert dokumentiert.
