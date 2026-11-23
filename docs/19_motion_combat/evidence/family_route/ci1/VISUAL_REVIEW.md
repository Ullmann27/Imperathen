# CI 1: Prüfung der tatsächlichen Familienroute

Stand: 23.11.2026. [GitHub Actions 45206876533](https://github.com/Ullmann27/Imperathen/actions/runs/45206876533), Job `137804871265`, erfolgreich abgeschlossen. Quelle: `62adc18e9c7be9f8318ea93aea716a499bdfced7`.

## Ergebnis und Herkunft

| Nachweis | Tatsächliches Ergebnis |
| --- | --- |
| [Headlessbericht](headless/action-route-review.json) | 77/77 Prüfungen, vollständig, Exit 0, `ACTION_ROUTE_REVIEW_PASS` |
| [Grafikbericht](graphical/action-route-review.json) | 89/89 Prüfungen, vollständig, Exit 0, `ACTION_ROUTE_REVIEW_PASS` |
| Quellen | Beide `clean_checkout`, 65 identische Quellhashes, keine Änderungen während der Läufe; auch mit den 65 entsprechenden lokalen Dateien abgeglichen, ohne Abweichung |
| Route | Je zwölf Stationen und 666 Trajektorienpunkte; 66,55 s Simulation, rund 62,5396 m tatsächlicher Weg; kein Teleport und keine Questinjektion |
| Fortschritt | Tatsächliche Mutter- und Wasserhandlung, 21 verdiente Kontakte mit acht Techniken, Speichern, neue Main-Instanz, Fortsetzen und weiterer Gehabschnitt bestanden |
| Grafik | Godot 4.7.2, `low`, Xvfb/X11, OpenGL-Kompatibilität, `llvmpipe (LLVM 20.1.2, 256 bits)` |

Die zusätzliche Prüfung gegenüber dem lokalen 76-Check-Lauf betrifft die echte Qualitätsauswahl; die zwölf weiteren Grafikprüfungen bestätigen die Speicherung der Stationsbilder. Das Grafikprotokoll enthält eine V-Sync-Warnung des Softwaretreibers, keine fehlgeschlagene Prüfung und keinen Scriptfehler.

Das unveränderte Originalartefakt `14833893321` hatte 9.842.687 Bytes. Sein SHA-256 wurde nach dem Download gegen den [GitHub-Artefaktdatensatz](github-artifact-metadata.json) geprüft: `fb11fb5ba15183c3a68d41642ba90d64b959e379080394be05b7963efcf2808b`. Die 20 Originaldateien wurden nach dem Kopieren nochmals byteweise beziehungsweise per Hash verglichen. Das ZIP wird im Repository nicht zusätzlich dupliziert.

## Sichtprüfung aller zwölf Originalbilder

Alle zwölf PNGs wurden einzeln mit dem Bildbetrachter geöffnet. Die folgende Bewertung beruht auf diesen tatsächlich gerenderten Bildern.

| Stationen | Beobachtung |
| --- | --- |
| [01 Anfang](graphical/01_family_opening.png), [02 Familienraum](graphical/02_family_room.png), [03 Haustür](graphical/03_family_door_outside.png) | Erkennbares Familienhaus mit Einrichtung und offener Tür. Einleitung, Aufgabenanzeige und Touchbuttons sind lesbar. Die Arme ruhen sichtbar seitlich. In der Außenansicht nimmt die nahe Gebäudekante einen großen Teil des rechten Bildbereichs ein. |
| [04 Mutterdialog](graphical/04_mother_conversation.png) | Dialogtext und bestätigter Haushaltsdenar sind vollständig lesbar. **Die Gesprächskamera zeigt hinter dem Dialog nur eine nahe Hauswand; Antonia ist verdeckt.** Eine erfolgreiche Interaktion belegt hier keine gute Gesprächsansicht. |
| [05 Wasserauftrag](graphical/05_family_water.png) | Echte Wasserbestätigung und nächste Aufgabe an den Vater lesbar. Raum und Wassergefäße sichtbar; die Bestätigung liegt vor dem Oberkörper der Figur. |
| [06 Dorfweg](graphical/06_walk_from_home.png), [07 Laufabschnitt](graphical/07_run_square.png), [08 Übungsplatz](graphical/08_practice_arrival.png), [09 Übungsabschluss](graphical/09_practice_complete.png) | Dorf, Bewohner und Übungspfahl sichtbar; Controls und Aufgabenlesbarkeit erhalten. Der Zähler steigt sichtbar von 0 auf 21, die gewählte Technik zeigt Highkick. In 08/09 ist die Weltbeschriftung zum Sammelpunkt rechts angeschnitten. |
| [10 Gespeicherte Pause](graphical/10_saved_pause.png) | Speicherbutton und Bestätigung sind lesbar. Der Menüinhalt steht im Scrollbereich nach unten versetzt; die oberste Textzeile ist teilweise abgeschnitten. Die Bestätigung überlagert vorübergehend weitere Menüzeilen. |
| [11 Fortgesetzt](graphical/11_resumed.png), [12 Weitergegangen](graphical/12_continued_walk.png) | Wiederhergestellte 21 Treffer und Ladebestätigung sichtbar, anschließend veränderte echte Position. Die Aktionsauswahl zeigt nach Neustart wieder Gerade L. Der erworbene Übungsfortschritt bleibt erhalten. |

In mehreren Bildern liegen die Füße unter der unteren Navigation oder außerhalb des unteren Bildrands. Daher lässt sich die vollständige Bein- und Fußhaltung aus diesen Stationsbildern nicht überall beurteilen. Station 09 zeigt den Zustand nach dem Angriff; sie ist kein Einzelbildnachweis jeder ausgeführten Technik.

## Aussagegrenzen

Die Grafikaufnahme rendert echte Frames an den Stationen bei unveränderter 60-Hz-Physik; die automatische Dauerrenderschleife ist ausgeschaltet. Es handelt sich **weder um eine FPS-Messung noch um eine Prüfung kontinuierlich flüssiger Animation oder einen Android-Gerätetest**. Keine Aussage über Telefonleistung oder Temperatur wird daraus abgeleitet. Der Neustart ersetzt Main innerhalb desselben Engine-Prozesses. Die beobachteten Kamera-, Text- und Bildausschnittgrenzen bleiben dokumentierte offene Punkte; für diese Abnahme wurde keine Produktionsdatei verändert.
