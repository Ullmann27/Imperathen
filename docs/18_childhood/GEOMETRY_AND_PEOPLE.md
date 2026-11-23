# Begehbares, bewohntes Dorf

Stand: 23.11.2026. Diese Änderungen betreffen die tatsächlich aufgebaute Godot-Szene. Eine neue Android-Laufzeitabnahme und eine Prüfung auf Heinz’ Telefon sind getrennte Lieferaufgaben.

## Konkrete Korrekturen

Die früheren römischen Häuser besaßen Wandkollisionen, aber keine Kollision für den erhöhten Innenboden. Die Figur stand deshalb weiter auf dem Landschaftsboden. Die sichtbaren Bodenplatten liegen bei 0,3925 m: `FLOOR_Z = 0.38`, Plattenmitte `FLOOR_Z - 0.025`, Plattenstärke 0,075 m im [ursprünglichen Architektur-Generator](../../tools/art/build_architecture.py). Die neue Bodenkollision hat genau diese Oberkante. Ein sichtbarer flacher Holzaufgang über den beiden Eingangsstufen teilt seine Form und Lage mit der Kollision. Es gibt keinen pauschalen Y-Versatz, der die Spielfigur lediglich schweben lässt.

Auch die Domus besitzt nun einen Boden auf 0,065 m, eine Kollisionsfläche für ihre Schwelle und einen flachen Anlauf. Das Wasserbecken, die vorhandenen Tische, Bänke und neuen Betten haben eigene Hindernisse. Die Produktionsfigur wurde außerdem durch die vorhandene, vom Spieler baubare Hütte bewegt; dort ist der 0,14 m hohe Boden ebenfalls physisch wirksam.

Aurelia stand ursprünglich bei `(8,18)` direkt in der alten inneren Palisade. Für das bewohnte Dorf wird diese veraltete innere Unterteilung mitsamt ihrer Kollisionsschicht deaktiviert. Die äußere Befestigung bleibt bestehen. Varro steht bei `(-10,-13)` außerhalb des Hauses; Arbeitskräfte stehen vor den Arbeitsstätten, mit 2,1 m Abstand zur jeweiligen Standortmitte in Z-Richtung. Bäume und Bodenbewuchs lassen die Arbeitsflächen und die Wege zu den drei Schmiedestationen frei.

## Sichtbarer Ausbau

Die Siedlung enthält jetzt **20 tatsächlich instanzierte, betretbare Wohnhäuser**, zuvor 13, zusätzlich zur vorhandenen Domus und den Geschäftsgebäuden. Sie liegt weiterhin innerhalb der bestehenden äußeren Dorfgrenze. Sieben Häuser füllen nachvollziehbare Wohnzeilen und den südlichen Bereich; der südliche Fußweg führt um diese Häuser herum. Der freie Baugrund wird nicht mit statischen Wohnhäusern belegt.

Ein neues [Modul für Haushalte und Werkstatt](../../prototype/scripts/world/village/settlement_dressing.gd) ergänzt Betten mit Decken, Regale, Krüge mit offenen Mündungen, Becher, Brot, Hocker, Vorräte und Feuerholz. Das Familienhaus hat einen konkret auffindbaren Trinkkrug und Becher. Die neue Schmiede besitzt einen geschützten Arbeitsbereich mit Feuerstelle, Blasebalg, Amboss, Werkzeugen und Kühlbottich. Marktlieferungen, ein Straßentrog und kleine Küchengärten ergänzen den Alltag. Diese Geometrie entsteht aus eigenem Code und wiederverwendbaren Grundformen; es wurden keine fremden oder kostenpflichtigen Assets eingeführt.

Die **26 Hintergrundbewohner** besitzen eindeutige Namen, Tätigkeiten, Begrüßungen und Wege. Zusammen mit den 15 sichtbaren Figuren des Dorfmodells sind 41 benannte erwachsene Dorfbewohner vorhanden. Antonia, Sextus und Quintus sind bestehende wirtschaftliche Personen; für die Kindheitsgeschichte werden keine doppelten Eltern oder zweiten Schmiede erzeugt. Die 26 Hintergrundbewohner werden nicht als zusätzliche verfügbare Arbeitskräfte in die Ressourcenbilanz gerechnet.

## Bewegung und persönliche Abstände

Die Hintergrundbewohner sind jetzt `CharacterBody3D`-Körper. Normale Wegbewegungen werden durch die echte Physik geprüft, statt die Figuren an jedem Zeitpunkt direkt auf den nächsten Punkt zu setzen. Bei einer besetzten Stelle warten sie oder machen einen kurzen, ebenfalls auf Kollision geprüften Seitenschritt. Die Zeit ihres Weges läuft nicht weit voraus, während sie an einem Hindernis warten. Wände werden nicht durch einen Ersatztransform übersprungen.

Die wirtschaftlichen Figuren behalten die Positionen der Spielregeln als maßgebliche Quelle. Ihre Körper blockieren Spieler und andere Bewohner. Tote, unsichtbare oder rekrutierte zivile Darstellungen hinterlassen keinen unsichtbaren Personenkörper. Bürger nutzen Kollisionsschicht 8; die Spielfigur berücksichtigt diese Schicht zusätzlich zu Landschaft und Truppe.

Das Laden eines Spielstands bleibt eine ausdrückliche Platzierung am gespeicherten Zeitpunkt. Dabei werden überlappende Anfangspositionen gegen die vorhandene Physik und andere Bewohner geprüft. Die Routinen sind örtlich verfasste Dorfwege, keine allgemeine Navigation einer fertig bevölkerten offenen Welt.

## Tatsächlich ausgeführte Prüfungen

Alle folgenden Ergebnisse stammen aus Godot 4.7.2 mit echten Physikkörpern und Kollisionsabfragen. Sie sind keine Bildratenmessung und keine Android-Geräteprüfung.

| Prüfung | Beobachtetes Ergebnis |
| --- | --- |
| `settlement_geometry_test.gd` | 1496 Prüfungen bestanden: 20 Bodenflächen, Hausabstände, echte Kapselbewegung durch Familienhaus, gedrehtes Schmiedehaus und Domus, Wandblockierung, Bewohner gegen Bewohner und Spieler, vollständige Wegsegmente |
| `village_collision_test.gd` | 184 Prüfungen bestanden: tatsächliche Kindheitswelt, innere Palisade ohne Restkollision, 15 wirtschaftliche Figuren außerhalb von Wänden/Möbeln, alle erlaubten Arbeitsplätze, alle Aktionsstandorte, Produktionsfigur auf Familienboden und in baubarer Hütte |
| `frontier_population_test.gd` | 841 Prüfungen bestanden: vollständige bisherige Welt mit erweitertem Viertel, Wege gegen Weltkollisionen, Gesprächspositionen, Pausieren, gespeicherte Zeit und Rekrutierung |

Die [Prüfprotokolle und Prüfsummen](evidence/world/verification.json) liegen zusammen mit den Bildern im Repository. Nach der Umstellung auf den einmaligen Bewohner-Modellstart und nach Ergänzung des offenen Türflügels wurden alle drei Gruppen erneut erfolgreich ausgeführt.

**Sechs echte Aufnahmen der Produktionswelt wurden erzeugt und einzeln angesehen:** Godot OpenGL Compatibility, Mesa llvmpipe, Profil `low`, 854 × 480 Pixel. Der [Innenraum](evidence/world/01-family-interior.png) zeigt den Jungen mit Füßen auf den Bodenplatten, dazu Bett, Tisch, Krüge und Becher. [Haustür und Eltern](evidence/world/02-family-doorstep.png), [Schmiede](evidence/world/03-village-forge.png), [Markt](evidence/world/04-market-homes.png), [Wohnstraße](evidence/world/05-residential-street.png) und [Dorfübersicht](evidence/world/06-settlement-overview.png) zeigen die übrigen tatsächlich vorhandenen Bereiche. Die Kameras und Spielerpositionen wurden für die Prüfung ausdrücklich gesetzt; dies ist keine aufgezeichnete Touch-Spielrunde. Der [Aufnahmebericht](evidence/world/settlement-review.json) und die [Dateiprüfsummen](evidence/world/capture-receipt.json) halten Umfang und Umgebung fest.

[settlement_graphics_review.gd](../../prototype/tests/settlement_graphics_review.gd) enthält die sechs Kamerablicke. [capture_settlement.py](../../tools/cinematic/capture_settlement.py) startet Godot und einen privaten Xorg-Server gemeinsam, damit sie denselben Netzwerkraum benutzen. Das Programm verlangt einen echten OpenGL-Start und neu geschriebene PNGs; vorhandene alte Bilder gelten nicht als neuer Prüfnachweis. Der anfängliche vollständige 720p-Lauf wurde vor dem ersten Bild mit Prozesscode −9 beendet. Die erfolgreiche, nachfolgende Prüfung mit reduziertem Profil ist deshalb kein Nachweis für 720p, das Profil `balanced` oder die Geschwindigkeit auf einem Android-Gerät.

## Darstellungsgrenzen

Die feste Anordnung und die begrenzten Tageswege sind bewusst klein genug, um sie gegen die vorhandene Weltgeometrie zu prüfen. Es gibt noch keine allgemeine freie Navigation für eine beliebig erweiterte Stadt. Die zusätzlichen Räume und Werkzeuge bleiben eine prototypische, römisch inspirierte Darstellung. Reale Gerätegeschwindigkeit, Detailqualität auf einem Telefon und die neue Android-Lieferung müssen am jeweiligen neuen Bau geprüft werden.
