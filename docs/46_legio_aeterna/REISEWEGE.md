# Zu Fuß zum Weidenhof

In Valdora lässt sich unter **Karte** das nächste Ziel auswählen. Am östlichen Dorfausgang beginnt die Wagenstraße. An der ersten großen Biegung zweigt der Weg zum Weidenhof ab. Der Kompass weist zur nächsten Biegung, ein Tipp darauf öffnet die Ortskarte. Am Marktstand bietet Tertia die Weiterreise auf den römischen Stadtmarkt an. Dort öffnet **Stadtplan** die Übersicht mit dem eigenen Standort, einem wählbaren Händler und der Gehstrecke. Die Rückkehr führt wieder zum Hof.

## Gelände und Darstellung

Weidenhof ist ein für IMPERATHEN erfundener Handelsplatz auf der bestehenden Strecke Valdora–Steinbruch. Die Straße verläuft über das reguläre Sektorgelände. Die Hügel, Weidenhaine und die flache Quelle daneben lassen sich frei begehen. Der Stadtmarkt lädt über den bestehenden Szenenwechsel. Die übrigen Fernorte des Regionalplans behalten ihren Planungsstatus.

Gasthaus, Vorratshaus, Marktstand mit Amphoren, Wassertrog, zweirädriger Wagen, Speichenrad, Weide, Wegrandbewuchs, Frachtmöbel mit Wachstafel und gebundene Getreidesäcke sind zehn örtlich erstellte Blender-Modelle. Der Wagen verwendet das vorhandene Pferderig.

## Getreide vom Weidenhof nach Valdora

Am Ladetisch des Weidenhofs lässt sich die Lieferung von 16 Getreide bestellen. Der angezeigte Preis beträgt sechs Denare oder fünf nach Cassias bestehender Handelslektion I-06. Ohne Geld oder verfügbare Ware bleibt der Wagen stehen. Nach Vertragsabschluss bezahlt der Spieler aus seinem Beutel in die bestehende Händlerkasse. Die Ware verlässt sofort den endlichen Notvorrat von `VillageEconomy`. Die sechs sichtbaren Säcke stellen die Ladung dar. Das Dorf erhält die 16 Spieleinheiten bei Ankunft am Osttor. Ein belegtes Empfangslager hält den beladenen Wagen dort an. Nach erfolgreichem Abladen fährt er leer zum Hof zurück.

Die Regionalansicht führt sowohl zum Ladetisch als auch zum Empfangsbuch am Osttor. Die aktuelle Fahrt ist dort mit Restweg und Empfangsstatus abrufbar. Der Spielstand speichert den Ladeschein, bezahlten Preis, Streckenfortschritt und quittierte Fahrten unter `village.economy.freight`. Alte Spielstände ohne Ladeschein besitzen denselben anfänglichen Leerlauf. `regional_freight.gd` beschreibt die bestehende Straßenverbindung und liest den Ladeschein für die Darstellung. Bestandsbewegungen erfolgen ausschließlich in den Transaktionen der Dorfwirtschaft.

Der Landschaftsgenerator verwendet dasselbe Höhenfeld und dieselben Dreiecke für Boden, Kollision und die Position der Objekte. Nahe Weidenstämme und Gebäude erhalten Kollisionen. Laub und Kräuter verwenden gemeinsame Meshes. Der Hof lädt seine Detailobjekte bei 128 Metern Entfernung und gibt sie jenseits von 188 Metern wieder frei.

## Navigation und Anschluss

- Die Einwohner und die Stadtkarte verwenden dieselbe Instanz von `CityStreets` und dieselben Händlerpositionen des Stadtmarktes. Der Wegfinder für wechselnde Spielerpositionen hinterlegt keine wachsende Liste künstlicher Anker im Stadtzustand.
- Die Valdora-Karte verwendet ein in Godot gebackenes Raster der statischen Kollisionsgeometrie mit 46.689 Proben von je 0,5 Metern Abstand. Der Bake berücksichtigt Türen, Wände, Möbel und Zäune. Eine Flutfüllung von der Hauptstraße schließt Hohlräume im Inneren geschlossener Objekte. A* vermeidet diagonales Abkürzen durch gesperrte Ecken. Ortswechsel sowie bewegliche Missionsziele aktualisieren die Weglinie. Reisende finden von außerhalb des Dorfes über die bestehende Straßenlinie zurück.
- Einstiegspunkte sind `regional_footpath.gd`, `regional_waystation.gd`, `village/mission_route.gd` und `roman_hud/city_route_chart.gd`. Stadtbesuche übernehmen den laufenden Kampagnenzustand. Der regionale Wegweiser dient als lokale Ansicht.
- Der Blender-Aufruf lautet `blender -b -t 2 --python-exit-code 1 --python tools/world/build_willow_waystation.py`. Nach Änderungen an der Dorfgeometrie erzeugt `godot --headless --path prototype -s ../tools/world/bake_valdora_route_grid.gd` das Raster erneut.

## Prüfung mit Godot 4.7.2

| Ausgeführter Prüfablauf | Beobachtung |
| --- | --- |
| I-02 laden, Weidenhof im Kartenmenü wählen, per Spielerphysik vom Osttor bis an den Tresen laufen | 287,56 m über drei Sektoren, 130,26 m mit mehr als sechs Metern seitlichem Abstand zur Straßenmitte, maximal 35,53 m seitlicher Abstand. Auf der gesamten Wegstrecke hatten die Füße in jedem gemessenen Physiktick Bodenkontakt. |
| Innenraum des Familienhauses bis zur Schmiede | 14 Stützpunkte nach Entfernen gerader Zwischenpunkte. |
| Am Tresen den Stadtmarkt besuchen, Stadtplan öffnen, Händler wählen und zurückkehren | Gleiche Kampagneninstanz, geprüfter Endpunkt am Stand und Rückkehr zur vorherigen Position und Uhrzeit. |
| Bestellung, Nachweise und Rückfahrt | 20 von 20 Prüfungen mit Aufnahme bestanden. 152 gemessene Wagenpositionen auf 249,69 m in 151,44 Simulationssekunden, zwei Sektoren. Sechs Denare wechselten die Kasse. Genau 16 Getreide erreichten das Dorf. Gegenproben umfassten zu wenig Geld, falschen Standort, wiederholten Auftrag, volles Lager, Laden unterwegs, Sektorwechsel und erneutes Laden nach Empfang. |
| Bestehende Strecke bis zum Steinbruch | 1.780,77 m zu Fuß über zehn Sektoren, ohne Verlust des Bodenkontakts. Größte Abweichung zum berechneten Boden 0,004 m. |
| Bestehende Regressionen | 5.244 Prüfungen für den Regionalplan, 8.674 für das Gelände-Streaming und 374 für das römische HUD bestanden. |

Die vier Bilder stammen direkt aus dem Godot-Kompatibilitätsrenderer unter Mesa llvmpipe. Für die Dorf- und Hofansicht verwendet die Aufnahme das Mittagslicht des Spiels. Das Prüfskript verwendet `--fixed-fps 60` als Simulationsschritt. Dieser Wert misst keine Bildrate auf dem Mobilgerät.

[Ortskarte Valdora](evidence/valdora-wegkarte.webp) · [Weidenhof](evidence/weidenhof.webp) · [Stadtplan](evidence/rom-stadtplan.webp) · [Getreidewagen auf der Fahrt](evidence/getreidewagen.webp)
