# Chat B – Kindheit, Dorf und Nachtüberfall

Stand: 23. November 2026. Arbeitsbranch: `feature/chat-b-village-world-20261123`.
Ausgangspunkt: `2909040deeb33b99ad4180b884b38921f28233a9` auf
`feature/childhood-village-20261123`. Der zwischenzeitliche Koordinatorstand
`e5735509622c9a94564dc5fe21257c07074f9df5` ist in diese Fassung integriert.
[Entwurfs-PR #37](https://github.com/Ullmann27/Imperathen/pull/37) führt die Arbeit
zurück zum Koordinatorzweig. Die alten veröffentlichten APKs sind kein
Prüfnachweis für diese Änderungen.

**Abgeschlossen:** Die [geprüfte Android-APK und ihre vollständigen Nachweise](ANDROID_DELIVERY.md) sind veröffentlicht. Der abschließende Cloudlauf zum Spielquellstand `3325a0b3` bestand 103 Python-Prüfungen, 51 Godot-Prüfgruppen und 50 Android-Laufzeitprüfungen.

## Ergebnis und neue Erzählvorgabe

Eine neue römische Partie beginnt als Zwölfjähriger bei Julia und Silvanus in
einem bestehenden Dorf. Sextus ist Silvanus' bester Freund und wird durch drei
Besuche zu einem persönlichen Mentor. Vier Dorftage verbinden Familie, Marcus,
Arbeit, Waren, Geld, kleine Fehler, Ausrüstung und eine beaufsichtigte Runde.
Die ausdrückliche letzte Nachtruhe öffnet den Überfall; anschließend folgt ein
eigener Morgen mit Überlebenden, Erinnerungsorten und Racheschwur.

| Tatsächlicher Handlungsweg | Silvanus, Vater | Sextus, Schmied | Julia, Mutter |
| --- | --- | --- | --- |
| Hinausgehen und Verteidigung oder Rettung tatsächlich unterstützen | Stirbt | Stirbt | Überlebt |
| Sich ausdrücklich mit beiden Eltern im Familienhaus verstecken | Stirbt | Stirbt | Stirbt |

Das Warten auf eine Entscheidung wählt keinen Zweig aus. Im Verteidigungsweg
zählt ein tatsächlicher Einsatz: bestätigter Treffer, abgewehrter Angriff,
gültige Rettung oder die räumlich abgeschlossene Begleitung Julias zum
Nachbarhaus. Ein bloßes Versprechen erzeugt keinen Rettungserfolg. Die Folgen
werden einmalig an den vorhandenen Einwohner-IDs verbucht und überleben einen
Neustart. Der Schwur macht das Kind weder älter noch zum Soldaten oder Herrscher.

Der eigene Erzählentwurf [NARRATIVE_ARC.md](NARRATIVE_ARC.md) beschreibt einen
Ausbau auf sechs Abschnitte und 240 dramaturgische Minuten. Das ist ein
Schreib- und Produktionsziel, **keine gemessene Spielzeit und kein fertiger
vierstündiger Film**. Der aktuelle Szenenkatalog umfasst 43 Zustände einschließlich
Verzweigungen, Nachtwartephasen und Abschluss. Ein einzelner Weg durchläuft
nicht automatisch jeden Katalogeintrag.

## Was im Spiel funktioniert

### Aufträge, Zeit und Speicherung

Die ersten Aufgaben verlangen konkrete Orte und reale Entscheidungen: einen
Essenskorb übernehmen oder ablehnen, dem Vater berichten, mit Marcus einen
verlorenen Riemen suchen, die Beobachtungen ehrlich oder vorschnell deuten,
Sextus Material bringen und brauchbare oder misslungene Griffe herstellen.
Später folgen eine Lieferung, eine weitere Werkstattbegegnung, die Hilfe wegen
einer erkrankten Wache und eine begleitete Runde. Abgelehnte und misslungene
Hilfe besitzen erreichbare Fortsetzungen.

Der nächste Dorftag beginnt durch eine gespeicherte Schlafentscheidung nach
dem Tagesabschnitt. Wirtschaftszeit darf während des Spielens verstreichen,
überspringt jedoch weder Szenen noch Lebensjahre. Dialoge, Journal, Handel und
Pause halten die Simulation an. Offlinezeit erzeugt keinen Fortschritt.

Auftragskarte und Kompass verwenden die autoritative Szene und die tatsächlich
verfügbare Person. Ein Hausziel führt zuerst zum passenden Eingang. Nähe allein
erlaubt kein Gespräch durch eine Wand. Nach dem Überfall führen die Aufträge zu
Überlebenden und Erinnerungsorten; tote Pflichtpersonen werden nicht verlangt.

`WorldModel` migriert frühere Spielstände auf Schema 6, ohne ihnen nachträglich
diese Kindheit aufzuzwingen. Der neue Hauptmenüstart aktiviert den Abschnitt
ausdrücklich. Ältere Dorf-, Frontier- und Karrierewege bleiben als geladene
Spielstände erhalten und werden weiterhin geprüft. Der genaue Vertrag steht
in [STORY_TIME_CONTRACT.md](STORY_TIME_CONTRACT.md).

### Häuser und Personen

Die Zusammenführung erhält alle 20 Wohnhäuser des parallelen Koordinatorstands.
Familienhaus, Nachbarhaus und bestehende Schmiede besitzen eigene Innenräume, Möbel,
Krüge, Geschirr, Vorräte, Schlafstellen und Arbeitsgegenstände. Eine Gasse
verbindet die Häuser. Türen, Eingangsschrägen, Fußböden und Möbel wurden mit
echten Physikkörpern geprüft; beim Betreten blendet die Darstellung das Dach
des betreffenden Hauses aus. Standardböden und Möbel dieser drei Häuser werden
gezielt umgeschaltet, sodass keine doppelten Kollisionskörper entstehen. Die
anderen 17 Häuser behalten die zwischenzeitlich gebaute Grundausstattung.

Julia, Silvanus und Sextus behalten ihre vorhandenen IDs. Die Szene erzeugt
keine zusätzlichen Wirtschaftspersonen für die Familie. Überschneidungen mit
der älteren Hintergrundbevölkerung werden gezielt ausgeschlossen. Tote
Einwohner verschwinden als aktive Personen und hinterlassen keine unsichtbaren
Kollisionskörper. Die Dorfübersicht zählt die tatsächlich Lebenden. Im neuen
Dorf werden 26 Hintergrundbewohner sowie 14 Wirtschaftspersonen und Decimus
dargestellt, jeweils mit einem Körper auf Bürgerschicht 8. Marcus bleibt ein
gesonderter Gefährte: zusammen 42 benannte NPCs neben dem Spieler. Diese Zahl
ist keine zusätzliche Wirtschaftsbevölkerung.

Julias Weg zum Nachbarhaus ist 15,718 Meter lang. Ihr gespeicherter Fortschritt
wird vor jedem Schritt durch eine echte Kapselprüfung gegen Häuser, Gegenstände,
Spieler und andere Personen begrenzt. Sie kann auf Hindernisse warten. Erst die
tatsächliche Ankunft ihrer ganzen Kapsel im Innenraum erlaubt die Bestätigung.
Ein Neustart setzt dieselbe Julia an dieselbe gespeicherte Stelle zurück.

Die Originaldatei `frontier_house.glb` und ihre Blender-Erzeugungsquelle bleiben
erhalten. Die zusätzliche Einrichtung und die Dachaufteilung sind reproduzierbarer
eigener Code. Details, Koordinaten und Schnittstellen stehen im
[VILLAGE_IDENTITY_CONTRACT.md](VILLAGE_IDENTITY_CONTRACT.md).

### Handel und Ausrüstung

Cassias Angebote verwenden endliche Warenbestände und eine endliche Kasse.
Käufe und Verkäufe verschieben tatsächlich Güter und Münzen. Ganze Denare
bleiben im bisherigen Geldbestand; ein Rest von 0–15 As ermöglicht Kleingeld.
Die historische Umrechnung lautet 1 Denar = 4 Sesterzen = 16 As. Die konkreten
Spielpreise sind eigene Balancewerte, keine behaupteten historischen Marktpreise.
Ein bereits verbrauchtes Angebot kann durch einen zweiten Tastendruck oder
Neustart nicht nochmals bezahlt werden.

Sextus' Übungsgegenstand kann ausgeliehen, später gekauft oder zurückgegeben
werden. Ein kleiner Darstellungsanschluss nutzt dafür das bereits vorhandene,
an die Hand gebundene `PracticeBlade`-Mesh. Der kurze Übungsstab ist während
Leihe oder Eigentum sichtbar und verschwindet nach Rückgabe. Modell- und
Detailwechsel erhalten diesen Zustand. Kampfwerte, Animationsclips und die
bisherige Erwachsenenregel wurden dafür nicht ersetzt.

### Nacht und Reiter

Die erzählte Nacht schaltet bereits vor der Entscheidung auf Nachtlicht. Der
Anritt und die spätere Angriffsphase verwenden gespeicherte Zeit und einen
gespeicherten Variantenwert. Daraus entstehen dieselben 30 berittenen
Darstellungsfiguren nach einem Neustart. Drei Spuren und zehn Reihen trennen
die Pferde räumlich; die Geländeprojektion verwendet die bestehende Höhenfunktion.

Die neuen Pferde und sitzenden Figuren sind eigene vereinfachte Geometrie.
Zehn gemeinsam verwendete Geometriegruppen und vier Detailprofile begrenzen
die Darstellungskosten. Sie ersetzen keine vorhandenen Originalfiguren.
**30 sichtbare Reiter bedeuten noch keine 30 vollständig ausgearbeiteten
berittenen Einzelkampfgegner.** Die vorhandenen Kampfregeln behalten ihre
eigene Autorität; Chat A kann daran die weitere Kampf- und Animationsarbeit
anschließen.

Der historische Rahmen verwendet ein fiktives Dorf im römischen Donauraum um
100 n. Chr. Die Angreifer bleiben eine unbekannte fiktive Bande. Sie werden
nicht ohne Beleg einem Volk oder einem bestimmten historischen Feldzug
zugeschrieben. Quellen und Aussagegrenzen stehen in
[HISTORICAL_CONTEXT.md](HISTORICAL_CONTEXT.md) und
[HISTORICAL_SOURCES.json](HISTORICAL_SOURCES.json).

## Prüfung und Bildbelege

Die elf neuen gezielten Modul- und Integrationsszenarien wurden einzeln mit
Godot 4.7.2 ausgeführt:

| Szenario | Einzelprüfungen |
| --- | ---: |
| Story, alternative Ausgänge, Zeit, Speicherung, Migration | 345 |
| Handel | 101 |
| Handel über das tatsächliche WorldModel | 39 |
| Reiterzustand und Darstellung | 144 |
| Hauszugänge, Böden und Dächer, Umschaltung alter Einrichtung | 138 |
| Einwohneridentitäten, Todeszustände und Wechsel alter/neuer Saves | 101 |
| Physischer Fluchtweg und Blockaden | 22 |
| Sichtbare Leih-/Eigentumsausrüstung | 37 |
| Tatsächliche Oberfläche: erste Tage, Arbeit, Handel, Neustart | 116 |
| Beide Nächte bis zum Schwur mit tatsächlichen Main-Neustarts | 231 |
| Migration echter Basis-Saves, getrennte Storyformen, neuer Faustkampf im Nachtzweig | 65 |
| **Summe dieser elf Szenarien** | **1.339** |

Der Nachtlauf führte beide Zweige mit gültigen Befehlen durch. Er enthält fünf
vollständige Main-Neustarts zusätzlich zur anfänglichen Instanz. Reiseabschnitte
der Integrationsfälle verwenden ausdrücklich gesetzte Testpositionen; die
separaten Haustür- und Eskortentests prüfen tatsächliche Bewegung und Kollision.
Diese Unterscheidung steht auch in den jeweiligen Testquellen.

Der lokale zusammengeführte Gesamtlauf zum Quellstand `9d90a8fe` ist unter
[evidence/merged-validation/validation_report.json](evidence/merged-validation/validation_report.json)
einschließlich Einzelprotokollen und Quellhashes abgelegt. Er enthält 51 Gruppen,
darunter die erhaltenen Prüfungen für Bewegung, Faustkampf, alle Häuser und den
früheren Kindheitsbogen. Der erste Chat-B-Lauf mit 43 Gruppen bleibt unter
`evidence/validation` erhalten; die 40 Gruppen unter `evidence/engine` gehören
zum früheren Koordinatorstand und werden nicht als neue Mergeprüfung ausgegeben. Aufruf:

```bash
python3 tools/check_prototype.py --report docs/18_childhood/evidence/merged-validation
python3 -m unittest discover -s tests -p 'android_*_test.py'
```

Die 92 Python-Prüfungen zum Quellstand `9d90a8fe` verwenden ausdrücklich synthetische
Paket- und Beobachterdaten. Das damalige Protokoll steht unter
[evidence/android-harness](evidence/android-harness). Die nachfolgend ergänzte
native Touchkontaktsteuerung erhält elf weitere synthetische Regressionen.
Die insgesamt 103 Python-Fälle wurden im erfolgreichen abschließenden Cloudlauf geprüft; dessen Bericht trägt den tatsächlichen neuen
Quellcommit. Synthetische Prüfungen ersetzen keinen APK-Lauf.

Die folgenden Bilder stammen aus der tatsächlichen Godot-Engine, mit
GL Compatibility und llvmpipe. Sie sind keine Konzeptbilder:

- [Zusammengeführter Spielstart mit größerer Touchbedienung](evidence/merged-ui-review/01-childhood-hud.png)
- [Familienhaus von außen](evidence/after/family-street.png)
- [Familienhaus von innen](evidence/after/family-room.png)
- [Erweiterte Häusergruppe](evidence/after/neighbourhood.png)
- [Tatsächlicher Spielstart mit Touchoberfläche](evidence/runtime-ui/01-childhood-hud.png)
- [Erstes Gespräch mit Julia](evidence/runtime-ui/02-julia-dialogue.png)
- [Reiter in der isolierten Prüfszene](evidence/mounted-raiders/raiders-very_high.png)
- [Pferd und Reiter im Detail](evidence/mounted-raiders/rider-detail.png)

`evidence/baseline` hält die vor der Hausänderung aufgenommenen Vergleichsblicke
fest. Die drei Ansichten unter `evidence/after` verwenden dieselben Kameras,
Blickziele, Bildgrößen und dasselbe Grafikprofil. Metadaten und Laufprotokolle
liegen neben den Bildern. Die Reiteraufnahmen zeigen ausdrücklich eine isolierte
Prüfbühne. Aus diesen Softwareaufnahmen folgt keine Android-Bildrate oder
Aussage zur Temperatur eines echten Handys. Die Bilder unter `after` und
`runtime-ui` zeigen den ersten Chat-B-Stand vor der Zusammenführung. Vom neuen
grafischen Main-Lauf entstand genau das verlinkte HUD-Bild; der Prozess endete
danach mit Code −9, bevor das Julia-Bild und die Abschlussmeldung entstanden.
[Umfang und Fehlerbeleg](evidence/merged-ui-review/review-scope.json) grenzen
diese einzelne Aufnahme ausdrücklich von einer vollständigen Grafikabnahme ab.

## Android-Lieferweg

Der Prüfbau verwendet Paketversion `0.4.0-childhood`, Versionscode 4, und den
bestehenden Android-Workflow. Der Aufgabenbranch wurde dessen erlaubten
Auslösern hinzugefügt. Der Workflow baut ARM64 und einen separaten
Emulator-Prüfbau, prüft die tatsächlichen exportierten Module und startet den
vorhandenen Android-Emulatorlauf.

Die neue Android-Strecke bedient die echte Touchoberfläche: kurze Bewegung im
Familienhaus, nach dem Loslassen nachgewiesener Stillstand, Julia ansprechen,
den Essenskorb zusagen, angehaltene Dialogzeit
prüfen, zurückkehren und nach Prozessneustart dieselbe Welt, Szene, Position,
Tag und Alter nachweisen. Sie schreibt keine Spielentscheidungen über einen
Testkanal. Das endgültige Ergebnis gehört zum konkreten Workflowlauf und dessen
APK-Hash; ein älterer erfolgreicher Android-Bericht gilt dafür nicht.

Der erste Lauf von `98bec146` erzeugte beide APKs und bestand die Engine- und
Paketprüfungen, scheiterte jedoch bei der nativen Touchbewegung: 2,389 Meter
überschritten die unveränderte Obergrenze von 1,6 Metern. Dieser alte Stand
verwendete noch 4,6 m/s statt des integrierten Kindheits-Gehtempos von 1,5 m/s.
Der zusammengeführte Stand erhält außerdem den Touch-Loslassfix des Koordinators.
Auch dieser Stand hatte einen eigenen fehlgeschlagenen Emulatorlauf
[`45196810548`](https://github.com/Ullmann27/Imperathen/actions/runs/45196810548):
Die 450-ms-Geste erzeugte dort keine messbare Bewegung. Über mehrere weitere
Beobachtungen blieb die Position gleich, während die Welt weiterlief. Bei etwa
einer Sekunde Simulationszeit pro dreizehn Sekunden Echtzeit lässt sich aus einer
so kurzen Geste kein zuverlässiger Bewegungsnachweis ableiten.

Die abschließende Kindheits-Prüfroute verwendet deshalb echte native
`touchscreen motionevent DOWN/MOVE/UP`-Ereignisse. Ein geringer Ausschlag des
beobachteten Steuerfelds wird bis zur ersten tatsächlich beobachteten Bewegung
gehalten. Loslassen wird auch bei Fehlern ausgeführt. Die Grenze von insgesamt
1,6 Metern und der anschließende Stillstandsnachweis von höchstens 0,02 Metern
bleiben bestehen. Dieser Eingabeweg verändert keinen Spielzustand über einen
Testkanal. Der erfolgreiche neue Lauf `45200099195` hat die APK-Bereitstellung geöffnet;
keiner der früheren Fehlerläufe wird nachträglich als Erfolg gewertet.

Die letzte Textüberarbeitung entfernt technische Speicher-/Prüfformulierungen
aus den sichtbaren Dialogen. Die drei Werkstattbesuche sprechen Schwert, Schild
und Speer als Lerngegenstände an; die unterschiedlichen Lektionen sind im
Erzählbogen ausgearbeitet. Aus diesen Gesprächen entstehen keine erfundenen
Inventargegenstände oder bereits erlernten Kampftechniken. Der Schwur nennt
Rache nun ausdrücklich. Szenenkennungen, Wege, Belohnungen und Folgen bleiben
dabei erhalten.

Die Bereitstellung ist auf die erlaubten Aufgabenbranches begrenzt. Der
Publisher verlangt den erfolgreichen Vorgängerjob desselben Workflowlaufs,
alle Kindheits-/Migrations-/Kampfgruppen und die acht nativen Kindheitschecks.
Er gleicht Quellcommit, ARM64-APK, Emulator-APK, exportierte Module, Prüfsummen
und Berichte ab. Erst dann entsteht eine gesonderte Vorabversion mit APK und
sechs nicht geheimen Belegdateien. Es gibt keinen Merge nach `main` und keine
Storeveröffentlichung.

## Erhaltene parallele Arbeit und nächste Integration

Chat B ergänzt in `main.gd` den neuen Start, Dialoge, Handel, Journal und die
Kette Kollision prüfen → autoritativen Schritt anwenden → gespeicherte Julia
darstellen. `game_world.gd` verbindet Räume, Ziele, Nachtlicht, Reiter und das
sichtbare Ausrüstungsflag. Die UI ergänzt Tagesanzeige, Kompass und passende
Dialogaktionen. `android_village_diagnostics.gd` erweitert ausschließlich die
lesende Beobachtung um aktuelle Kindheits- und Touchdaten.

Der Anschluss an die Figur in `village_person.gd` schaltet das vorhandene
Übungsmesh sichtbar. Die parallelen Bewegungs-, Faustkampf-, Ausrüstungs- und
Touchänderungen bleiben erhalten: getrenntes Gehen/Laufen, größere Bedienflächen,
zehn Übungstechniken, tatsächliche Trefferprüfung und Knochenanbindung der
früheren Wachausrüstung. Die alte Kindheitsgeschichte verwendet ihre damaligen
Personenzuordnungen nur beim Fortsetzen tatsächlicher alter Saves. Neue Partien
verwenden die aktuelle Vorgabe mit Julia, Silvanus und Sextus. Gemischte
Zustandsformen werden abgelehnt. Echte unveränderte Basis-Saves belegen diese
Migration; sie wurden nicht mit dem neuen Modell nachgebaut.

Die moderne Julia-Begleitung bleibt in jedem aktiven Frame durch die Weltkollision
begrenzt. Die ältere Simulation behält ihre vorhandene gebündelte Verarbeitung.
Der Anschluss `combat_sight_check` bleibt mit der tatsächlichen Sichtprüfung
verbunden. Fremde uncommittete Worktrees wurden nicht verändert.

Für den nächsten Inhaltsblock sind die ersten Ermittlungs- und Verfolgungsmissionen
nach dem Schwur auszuarbeiten. Der aktuelle Abschluss bleibt ein gespeicherter
Aufbruch, keine bereits fertig erzählte Rachekampagne. Weitere Waffenübungen,
individuelle berittene Kämpfe, ausgeführte Trink-/Essenshandlungen, vollständige
Vertonung und vier Stunden Filmregie sind zusätzliche Produktionsarbeit. Die
vorhandenen Gegenstände und Tagesposen belegen diese noch offenen Animationen
nicht. Für Leistungszusagen bleibt ein längerer Test auf einem konkreten
Android-Gerät erforderlich.
