# IMPERATHEN – Grenzdorf

Ein spielbarer historischer Strategieprototyp mit Dorfleben, taktischem Talgefecht und saisonaler Weltkampagne. Android, Windows und Linux führen dieselben Spielbefehle aus.

## Auf Android anfangen

Lade die Datei **IMPERATHEN-…-arm64.apk** aus der gewünschten Prüffassung herunter und öffne sie auf dem Gerät. Nach dem Vorspann zeigt **Figuren** die 18 Charakterbilder. Wähle eine Herkunft und **Neues Leben**, um im Dorf anzufangen. Godot und Blender werden nur auf dem Entwicklungsrechner benötigt. Frühere Debugbauten können eine andere Signatur tragen. [Aktueller Download](https://github.com/Ullmann27/Imperathen/releases) · [Installationshinweise des Dorf-Prototyps](../docs/10_development/ANDROID_INSTALL.md)

## Editorstart

1. Godot **4.7.2** verwenden; genau diese Version wurde in diesem Entwicklungsblock ausgeführt.
2. Dieses Repository herunterladen oder den Entwicklungsbranch auschecken.
3. Im Godot-Projektmanager `prototype/project.godot` importieren. Der erste Import wandelt GLB und WAV automatisch in Engine-Ressourcen um.
4. **F5** startet `main.tscn`, den Vorspann und das Hauptmenü.

Alternativ im Repository: `godot --path prototype`. Für Headless-Prüfungen: `python tools/check_prototype.py`.

Der Android-Workflow baut die Prüfpakete mit den passenden offiziellen Exportvorlagen. Auf dem Spielgerät genügt die ARM64-APK. [Android-Bauweg](../docs/10_development/ANDROID_BUILD.md)

## PC-Grafikkarte

Im Windows-Archiv startet `IMPERATHEN.exe` die Compatibility-Fassung. `IMPERATHEN-Vulkan.cmd` startet dieselbe EXE mit Vulkan und dem Godot-Renderer Forward+. Unter Linux funktioniert `./IMPERATHEN.x86_64 --rendering-method forward_plus --rendering-driver vulkan`. `--verbose` zeigt die erkannten Vulkan-Geräte an. `--gpu-index 0` wählt den Adapter mit Index 0. Auf dem PC umfasst das Profil Hoch ein 3D-Pixelbudget bis 3.840 × 2.160, auf Android bis 2.560 × 1.440. Die tatsächlich verwendete Auflösung, der Renderer und der Adapter stehen in der Leistungsdiagnose. Die Szenen und gespeicherten Spielregeln sind gemeinsam.

## Herkunft und Spielstand

Italien unter römischer Herrschaft, die Gemeinschaft östlich des Rheins, der Weichselraum, die Östlichen Han und Wa in der Yayoi-Zeit bieten unterschiedliche Einstiege, Gefährten, Siedlungsbilder und saisonale Geschichten. Rom ist vorausgewählt. Die Dorfaufgaben nutzen denselben geprüften Regelkern. Der nachstehende Dorfweg beschreibt den römischen Einstieg.

## Formationskampf im Tal

Im Hauptmenü **Talgefecht erproben** öffnen. Die Schlacht beginnt in taktischer Pause. Eine Einheitenkarte oder einen Verband auf dem Gelände wählen und mit **Fortsetzen** die Zeit starten. Das Talzeichen 120 Spielsekunden verteidigen oder die Gegenseite zum Rückzug bringen. Beide Seiten beginnen mit 30 Soldaten.

| Eingabe | Wirkung |
| --- | --- |
| Touch | Antippen selektiert einen Verband. Danach befiehlt ein Geländetipp den Marsch. **Gruppe +** schaltet Mehrfachauswahl. Lang drücken und ziehen zeigt die neue Front mit einem Platz pro Soldat. Loslassen bestätigt. Zwei Finger verschieben oder zoomen die Kamera. |
| Maus | Linksklick wählt, Umschalt ergänzt die Auswahl, Linksziehen spannt das Rechteck. Rechtsklick erteilt den Zielbefehl, Rechtsziehen richtet die Formation aus. Mitteltaste verschiebt, das Rad zoomt. |
| Tastatur | WASD verschiebt die Kamera, Q/E drehen. Leertaste pausiert, H hält, R sammelt. Strg+Ziffer speichert eine Gruppe, Ziffer ruft sie auf. |
| Befehlsleiste | Verband, Formation und Befehl wählen. Zielgerichtete Aufträge erwarten anschließend einen Geländepunkt oder Gegner. **Tempo** wechselt zwischen Echtzeit und 0,35-facher Geschwindigkeit. |

Die sieben räumlichen Formationen sind Linie, Kolonne, Schildwall, Testudo, Keil, lockere Ordnung und Phalanx. Ausrüstung und Ordnung bestimmen, ob ein Wechsel möglich ist. Das Pausenmenü des Dorfes öffnet nach dem gewonnenen Dorfgefecht und der Folgeentscheidung den persistenten Einsatz der Grenzlegion. Android-Hintergrundwechsel und Rückkehr ins Dorf sichern den Gefechtsstand. Fällt die Talstraße, verbraucht der Umweg bei Nachschubaufträgen einen zusätzlichen Reisevorrat.

## Weltkugel und Winter

Im freien Szenario beginnt die Regionalkampagne im Frühjahr 100 n. Chr. am gewählten Herkunftsort. Die Weltkugel lässt sich ziehen und zoomen. Punkte auf der Kugel und die Ortsliste wählen dieselben 32 Regionen. Linien markieren erfundene Verbindungen des Strategiespiels. Eigene Gebiete erscheinen türkis, das gewählte Gebiet goldfarben.

Pro Saison stehen zwei Vorbereitungen zur Verfügung. Die Anzeige nennt Korn, eingelagerte Menge, Winterbedarf, Reisevorräte und Unruhe. **Ernten** und **Einlagern** bereiten die Mission vor. Der erste schlecht versorgte Winter lässt Zeit zur Erholung. Zwei mangelhaft versorgte Winter können den Auftrag beenden. Ein erneuter Auftrag bleibt möglich. Ein größeres Mandat erhöht Bedarf und mögliche Gebietsverluste. Die persönliche Kaiser- oder Königslaufbahn ist ein Ausbauziel.

Der Lebenslauf beginnt 94 n. Chr. mit zwölf Jahren. Nach dem sechsjährigen Ausbildungsübergang und der Dorfverteidigung wirkt die Kartenzeit auf dieselbe Welt und auf das Alter der Figuren. Jede Herkunft hat eine Herbstentscheidung mit konkreten Folgen und einem späteren Chronikeintrag. Die Jahreszeiten sind ein vereinfachtes Versorgungsmodell. Südliche Auftragsregionen haben entgegengesetzte Jahreszeiten. [Zeitstellung und historische Einordnung](../docs/12_integration/ATLAS_SOURCES.md)

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
| Kameraabstand im Dorf | Mausrad | zwei Finger im freien Weltbereich spreizen oder zusammenführen |
| Pause | Escape oder Menü im HUD | Menü im HUD |

Touch wird auf passenden Geräten automatisch angeboten und kann in den Einstellungen auch manuell eingeschaltet werden. Mehrfingerbedienung, Eingabeabbruch in Dialogen und dieselben Spielregeln für beide Eingabearten sind Teil der Funktionsprüfung. Ein realer Handytest steht noch aus.

Einstellungen umfassen UI-Größe, reduzierte Bewegung, Lautstärke, Touchanzeige und drei Grafikprofile. Die Profile ändern tatsächlich Darstellungseinstellungen; sie sind noch keine Vermessung bestimmter Mobilchips. Das Spielgeschehen bleibt identisch.

## Speicherung

Das Spiel speichert unter Godots `user://`-Verzeichnis; im Editor lässt sich der Benutzerordner über das Projektmenü öffnen. Hauptdatei: `imperathen_campaign.json`, Sicherung: `imperathen_campaign.json.bak`. Die Oberfläche speichert außerdem ihre Einstellungen separat.

Gespeichert wird bei wichtigen bestätigten Entscheidungen, über die Speichern-Schaltfläche und während des Spiels regelmäßig nach 45 Sekunden. Schreiben verwendet eine temporäre Datei, prüft deren Inhalt und übernimmt erst dann die neue Datei. Laden prüft Format, Prüfsumme, Typen, Bilanzen, Fortschritt und IDs. Eine beschädigte Hauptdatei kann durch die letzte gültige Sicherung ersetzt werden. Sind beide ungültig, wird die laufende Welt nicht mit unvollständigen Daten überschrieben.

Die Sicherung ist kein Archiv mehrerer Lebensläufe. Eine neue Partie ersetzt die aktive Partie nach Bestätigung. Prüfsummen erkennen Beschädigung und sind kein Schutz gegen absichtliches Editieren durch den Eigentümer der Datei.

## Aufbau und Ausbaugrenzen

- `scripts/domain/` verwaltet Lebenslauf, Dorf, Saisonkampagne und versionierte Spielstände.
- `scripts/battle/` verarbeitet Gefechtsbefehle, löst Formation und Verluste auf und zeichnet die taktische Szene.
- `scripts/world/` enthält Dorf, Kamera und Weltkugel. Menüs und HUD liegen in `scripts/ui/`.
- `scripts/main.gd` verbindet die Szenen mit dem gemeinsamen Spielstand. Die freien Szenarien im Hauptmenü erlauben das Erproben unabhängig vom laufenden Lebenslauf.
- `assets/` enthält importierbare GLBs, Texturen und Umgebungston. Blender-Quellen und Freisteller liegen unter [art/](../art).

Im Dorf ist die Hütte der erste selbst errichtbare Gebäudetyp. Die Weltkampagne bildet 32 Orte über ein Routennetz ab. Politische Laufbahnen, Diplomatie und regionale Kampagnenarmeen sind weitere Ausbauschritte. Das Talgefecht verwendet für alle Herkünfte dasselbe Grenzlegion-Szenario. Der Regelkern bewahrt bis zu 1.024 erfolgreiche explizite Befehlskennungen und 256 Chronikeinträge.

## Spielbilder und Originalmodelle

[Das Tal in Godot](../docs/12_integration/evidence/valley-balanced.webp) · [Das römische Dorf](../docs/12_integration/evidence/village-italia.webp) · [Die Weltkugel mit Han-Einstieg](../docs/12_integration/evidence/globe-han.webp) · [Transparente Modellstudien](../art/landscape/README.md)
