# Fortsetzung: Laufbeginn, gemeinsame Animationen und gespeicherte Gegner

Stand: 25. November 2026. Basis der Fortsetzung ist
`f3ad20404f1d870162b62d71c46fb2a04b553927` im Entwurf
[#56](https://github.com/Ullmann27/Imperathen/pull/56).

## 1. Laufbeginn ohne künstliche Verzögerung des Schwingfußes

Der Weltkontaktlöser ermittelte seine Positionskorrektur beim ersten bereits
angehobenen Schwingframe. Dadurch wurde ein Teil der tatsächlich vorgesehenen
Fußbewegung wieder zurückgenommen. Der erste, schon mitten im Schwung
beginnende linke Fuß hatte dagegen noch keine solche Korrektur. Am Ende des
ersten Laufzyklus entstand deshalb ein von der Abtastung abhängiger Unterschied.

Der Löser speichert jetzt die tatsächlich benötigte Korrektur im letzten
Standframe und übernimmt ausschließlich diesen Wert in die Schwungphase.
Die Orientierung des abhebenden Fußes und die Kontaktübergabe beim LOD-Wechsel
bleiben getrennt erhalten. Die Regression beginnt ausdrücklich beim ersten
Frame und prüft jeweils drei Geh- und Laufzyklen bei 30, 60 und 120 Hz.

| Laufprüfung | Vorher: maximale Positionsnaht | Nachher |
| --- | ---: | ---: |
| 30 Hz | 4,679 mm | unter 0,001 mm |
| 60 Hz | 43,492 mm | unter 0,001 mm |
| 120 Hz | 14,862 mm | unter 0,001 mm |

Das sind numerische Knochenpositionen derselben Prüfszene, keine Behauptung
einer entsprechenden visuellen oder physischen Genauigkeit. Der bestehende
Figurenbewegungstest besteht nun 560 Prüfungen einschließlich Drehung,
Standkontakt, LOD-Übergabe und der zuvor ergänzten nichtkanonischen Restachsen.

Die gesonderte 60-Hz-Messung des tatsächlich importierten Heldenmodells LOD0
bestätigt die Verbesserung mit unverändertem Messskript: Laufnaht von
0,043491978 m auf 0,000000141 m; gemessener Sohlenversatz beim Laufen von
1,9997 auf 1,9667 mm. Der vollständige Einzelvergleich steht in
[hero0-comparison.json](evidence/motion-continuation/hero0-comparison.json).
Dieser gezielte Diagnoselauf ist ausdrücklich unvollständig (`complete=false`)
und erteilt keine Familien- oder Gesamtfreigabe.

## 2. Figuren verändern keine fremden Animationsschleifen

Eine Dorffigur und ein Soldat konnten dieselbe importierte Animation verwenden.
Der Aufruf einer einmaligen Blockaktion änderte deren `loop_mode` und beendete
damit auch die fortlaufende Schildhaltung des anderen Akteurs. Eine fehlende
Einmalanimation konnte über ihren Idle-Ersatz ebenso die Ruheanimation eines
Nachbarn stoppen.

Die beiden Figurentreiber besitzen jetzt eigene Bibliothekszuordnungen.
Benötigte Schleifenvarianten werden aus der kanonischen Originalanimation
abgeleitet. Identische Varianten werden weiterhin gemeinsam verwendet; ein
Cache mit schwachen Referenzen hält ungenutzte Ressourcen nicht künstlich am
Leben. Ein Wechsel zurück zur Ruhehaltung findet wieder dieselbe gemeinsame
Variante. Unveränderte Wiedergabe benötigt keine neue Kopie.

Die Mehrfigurenprüfung auf zwei tatsächlichen LODs erzeugte mit den vorherigen
Treibern 12 Fehler in 343 Prüfungen. Die korrigierten Treiber bestehen dieselben
343 Prüfungen. Auch der unveränderte `natural_motion_test.gd` besteht seine
116 Prüfungen einschließlich der bisherigen Ressourcen-Sharing-Anforderung.

## 3. Besiegte Angreifer nach Speichern und Fortsetzen

Die Raiderdarstellung löste ihre Todesanimation nur bei einer neuen Abnahme
der Gesundheit aus. Ein aus gespeichertem Zustand aufgebauter bereits
besiegter Gegner hat keine neue Abnahme. Auch nach einem Darstellungsreset
konnte deshalb eine lebendige Ruhehaltung erscheinen.

Die Synchronisierung stellt den gespeicherten Zustand `health <= 0` nun
unmittelbar als Tod dar. Der bestehende idempotente Aufruf startet eine bereits
laufende Fallanimation nicht erneut. Gesundheitswerte, Kampfregeln und
Speicherformat werden dabei nicht geändert.

Die Integration besiegt einen Gegner durch den tatsächlichen Kampfpfad,
speichert, wechselt ins Hauptmenü und setzt dieselbe Partie fort. Sie prüft
Todesdarstellung und deaktivierte Kollision des Besiegten, lebende und
kollidierbare Kontrollgegner sowie den vollständig frischen Aufbau der
Darstellung. Der gesamte Überfall-Integrationstest besteht 224 Prüfungen.

## 4. Verlässliche Nahtprüfung bei der Ausrüstung

Die Topologieprüfung verwechselte Rasterzellen mit geometrisch identischen
Punkten. Eng benachbarte Material-/UV-Nahtkopien des tatsächlich geschlossenen
Scutum konnten verschiedene Zellen belegen und dadurch als offen gelten.

Das Raster dient jetzt zur Nachbarsuche. Ein Nahtcluster darf nur Punkte
enthalten, deren paarweise Abstände innerhalb des bestehenden `EPSILON` von
0,00001 m liegen. Der Cache prüft dieselben Paare erneut mit derselben Grenze;
sein bisheriger zusätzlicher Faktor 1,75 entfällt. Damit können weder ein
mittlerer Punkt eine größere Öffnung überbrücken noch zwischengespeicherte
Nahtdaten einen später geöffneten Spalt als geschlossen ausgeben.

Die 16 Regressionen bestehen einschließlich realem Scutum, verschobenen und
gedrehten Nahtkopien, Mittelpunktbrücke und nachträglich geöffnetem Cache.
Eine tatsächlich fehlende Fläche bleibt offen und sperrt eine unbewiesene
Volumenprüfung. Kontaktfreistellungen, numerische Bewegungsgrenzen und
visuelle Freigaberegeln werden nicht abgeschwächt.

## Nachweise und offene Freigabe

Die [lokalen Protokolle](evidence/motion-continuation/) enthalten die
Vorher-/Nachherläufe, die 205 bestandenen Pythonprüfungen und einen
[Quellenbeleg](evidence/motion-continuation/receipt.json). Die vollständige
Prüfung der tatsächlich gespeicherten Revision wird zusätzlich durch den
bestehenden Workflow im Entwurf #56 ausgeführt.

Die Basisrevision bestand im abgeschlossenen
[Lauf 45560064886](https://github.com/Ullmann27/Imperathen/actions/runs/45560064886)
alle 70 Godot-Gruppen und 205 Pythonprüfungen. Ihr strenges Motion Gate blieb
mit 567 Einträgen gesperrt. Diese Zahlen gehören zur Basisrevision; sie werden
nicht als Ergebnis der Fortsetzung ausgegeben.

Die früher berichteten 21,2584 mm beim Helden stammen aus `death`, nicht aus
seinem Gehen oder Laufen. Dieser Wert bleibt in der gezielten Messung offen.
Weitere offene Punkte sind tatsächliche Ausrüstungsüberschneidungen mit Körper
und Kleidung, Hautgewichte und Bodenbezug anderer Modelle, Übergänge in der
Spielwelt und Fernformationen sowie die quellgebundene visuelle Abnahme.
Konservative AABB-Obergrenzen der Ausrüstungsmessung sind keine exakt bestimmten
Eindringtiefen. Die vier Korrekturen stellen keine APK-Freigabe dar.
