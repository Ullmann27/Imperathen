# IMPERATHEN – Grenzdorf

Ein ausführbarer, bewusst begrenzter 3D-Funktionsprototyp für den Anfang des Lebenswegs. Die größere Vision bleibt in der Projektmappe beschrieben; dieses Kapitel verbindet ihre ersten Systeme tatsächlich miteinander.

## Start

1. Godot **4.7.2** verwenden; genau diese Version wurde in diesem Entwicklungsblock ausgeführt.
2. Dieses Repository herunterladen oder den Entwicklungsbranch auschecken.
3. Im Godot-Projektmanager `prototype/project.godot` importieren. Der erste Import wandelt GLB und WAV automatisch in Engine-Ressourcen um.
4. **F5** startet `main.tscn`, den Vorspann und das Hauptmenü.

Alternativ im Repository: `godot --path prototype`. Für Headless-Prüfungen: `python tools/check_prototype.py`.

Es werden keine Python-Pakete, Cloudschlüssel oder Modell-APIs zum Spielen gebraucht. Blender wird nur zum Neuerzeugen des eigenen Hüttenmodells benötigt; die fertige GLB liegt bereits im Projekt. Keine Engine-Binärdatei ist Teil des Repositorys. Godot-Exportvorlagen, Android-SDK und ein tatsächlich getestetes APK sind in dieser Lieferung nicht enthalten.

## Spielweg

Du beginnst mit zwölf Jahren in einer bereits existierenden Grenzsiedlung. Du besitzt noch kein Holz und keine eigene Hütte. Eine erlaubte Baufläche und ein geliehenes Werkzeug ermöglichen den Anfang. Das vorhandene Dorf gehört zur Umgebung; deine neue Unterkunft entsteht erst durch deine Arbeit.

1. Gehe zu den beschrifteten Holzvorräten westlich und nördlich des Weges. Jede erfolgreiche Interaktion nimmt vier Holz aus einem endlichen Vorrat. Sammle zunächst zwölf Holz, wenn du Marcus helfen möchtest.
2. Sprich mit Marcus nahe dem Brunnen. Vier Holz zu teilen erhöht sein Vertrauen; eine Ablehnung wird ebenso als tatsächliche Entscheidung gespeichert.
3. Wähle **Hütte bauen**. Platziere die Hütte auf der markierten Fläche östlich des Dorfwegs. Ein Bau verbraucht acht Holz; belegte oder unzulässige Plätze werden abgelehnt.
4. Kehre zur persönlichen Ansicht zurück und bleibe nahe der Baustelle. Der Prototyp benötigt zwölf Sekunden anwesender Arbeit. Entfernst du dich oder pausierst das Spiel, entsteht kein heimlicher Baufortschritt. Bei mehreren Baustellen steht insgesamt nur die Arbeit einer Person zur Verfügung.
5. Nach fertiger Hütte und entschiedenem Treffen gehst du zum Übungsplatz. Der ausdrücklich beschriebene Übergang **sechs Jahre später** macht dich und Marcus erwachsen. Das ist eine kurze Darstellung für den Funktionstest; der spätere lange Jugendabschnitt ist noch nicht implementiert.
6. Triff das Übungsziel dreimal mit gültigem Abstand und Erholung zwischen Schlägen. Danach kannst du bis zu drei Freiwillige für je fünf Denarii und zwei Getreide anwerben. Sie fehlen anschließend als zivile Arbeitskräfte.
7. Beginne die Verteidigung. Drei Gegner stehen nördlich des Dorfes. Nähere dich und kämpfe persönlich; außerhalb der Reichweite oder während der Schlagpause zählt kein Treffer. Gegnerzustände und Verluste bleiben über Kamerawechsel und Speichern erhalten.
8. Nach dem Sieg entscheidest du zwischen Schutz der Siedlung und Verfolgung nach Norden. Diese Auswahl verändert Ressourcen, Vertrauen und Folgetext. Sie krönt dich nicht zum Kaiser und setzt keine endgültige Karrieregrenze. Bauen und Erkunden bleiben nach Abschluss des Prototypkapitels möglich.

Wirst du im Gefecht besiegt, endet dieser Lebensbogen. Das Hauptmenü erlaubt einen neuen Anfang. Das ist ein tatsächlicher Misserfolgszustand dieses Abschnitts, keine fertige Simulation aller späteren politischen Karrierewege.

## Bedienung

| Aktion | Tastatur und Maus | Touch |
| --- | --- | --- |
| Figur bewegen | WASD oder Pfeiltasten | linker Analogbereich |
| Kamera drehen | rechte Maustaste halten und ziehen | freien Weltbereich ziehen |
| Interagieren | E | Interagieren |
| Angreifen/üben | linke Maustaste oder Leertaste | Angreifen |
| Hütte planen | B oder HUD-Schaltfläche | Hütte bauen |
| Bauplatz bestätigen | freie Fläche anklicken | freie Fläche antippen |
| Bauplan abbrechen | Escape oder B | Bau abbrechen |
| Person/Stadt/Karte | HUD, Tab, M | entsprechende HUD-Schaltfläche |
| Kameraabstand | Mausrad | die festen Ansichten verwenden |
| Pause | Escape oder Menü im HUD | Menü im HUD |

Touch wird auf passenden Geräten automatisch angeboten und kann in den Einstellungen auch manuell eingeschaltet werden. Mehrfingerbedienung, Eingabeabbruch in Dialogen und dieselben Spielregeln für beide Eingabearten sind Teil der Funktionsprüfung. Ein realer Handytest steht noch aus.

Einstellungen umfassen UI-Größe, reduzierte Bewegung, Lautstärke, Touchanzeige und drei Grafikprofile. Die Profile ändern tatsächlich Darstellungseinstellungen; sie sind noch keine Vermessung bestimmter Mobilchips. Das Spielgeschehen bleibt identisch.

## Speicherung

Das Spiel speichert unter Godots `user://`-Verzeichnis; im Editor lässt sich der Benutzerordner über das Projektmenü öffnen. Hauptdatei: `imperathen_campaign.json`, Sicherung: `imperathen_campaign.json.bak`. Die Oberfläche speichert außerdem ihre Einstellungen separat.

Gespeichert wird bei wichtigen bestätigten Entscheidungen, über die Speichern-Schaltfläche und während des Spiels regelmäßig nach 45 Sekunden. Schreiben verwendet eine temporäre Datei, prüft deren Inhalt und übernimmt erst dann die neue Datei. Laden prüft Format, Prüfsumme, Typen, Bilanzen, Fortschritt und IDs. Eine beschädigte Hauptdatei kann durch die letzte gültige Sicherung ersetzt werden. Sind beide ungültig, wird die laufende Welt nicht mit unvollständigen Daten überschrieben.

Die Sicherung ist kein Archiv mehrerer Lebensläufe. Eine neue Partie ersetzt die aktive Partie nach Bestätigung. Prüfsummen erkennen Beschädigung und sind kein Schutz gegen absichtliches Editieren durch den Eigentümer der Datei.

## Aufbau und derzeitige Grenzen

- `scripts/domain/`: maßgeblicher Weltzustand, Regeln, Kapitel und Speicherung.
- `scripts/world/`: 3D-Darstellung, Kollision, Kamera und Eingaben; sie bucht keine Ressourcen selbst.
- `scripts/ui/`: Menüs, HUD, Dialoge und Eingabeelemente; sie fordert Änderungen über Signale an.
- `scripts/main.gd`: verbindet alle drei Teile, steuert Pause und Speicherung.
- `assets/`: eigenes Hüttenmodell und selbst erzeugter Umgebungston; Herkunft und Hashes im Manifest.

Die regionale Ansicht zeigt dieselbe Dorfwelt aus größerer Entfernung. Eine strategische Provinzkarte, Eroberung, Politik, Handel zwischen Städten, Kaiserkarriere, große Formationsschlachten, eine generative KI-Geschichte, Wochenbalance und Fotorealismus sind noch nicht umgesetzt. Die Gegner stehen aktuell fest und reagieren in Nahkampfreichweite; Rekruten folgen in einer einfachen Formation. Komplexe Wegsuche und vollständige Kampfanimationen fehlen.

Das Bauen umfasst einen Gebäudetyp, die Ressourcen sind begrenzt. Der Regelkern bewahrt höchstens 1024 erfolgreiche explizite Befehlskennungen und 256 Chronikeinträge. Ein unbegrenztes Langzeitspiel benötigt ein anderes Aufbewahrungs- und Fortschrittsmodell. Diese Grenzen sind bewusst sichtbar und werden nicht als fertige Großspielarchitektur ausgegeben.

## Grafikquelle

![Originales Hüttenmodell – Blender-Assetrender, kein Spielbild](../docs/10_development/evidence/frontier_hut_preview.png)

Die Bilddatei wurde aus der mitgelieferten `.blend`-Quelle gerendert. Sie zeigt das tatsächliche Modell, das auch in Godot importiert wird. Sie ist **kein Ingame-Screenshot**. Die Prototypfiguren und viele Umgebungsobjekte bestehen aus eigener einfacher Geometrie. Das parallel laufende Grafikteam liefert eine getrennte, detailliertere Assetlinie; deren Übernahme erfordert einen eigenen Abgleich.
