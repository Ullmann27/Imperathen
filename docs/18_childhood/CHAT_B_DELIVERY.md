# Chat B – Kindheit, Dorf und Nachtüberfall

Stand: 23. November 2026. Arbeitsbranch: `feature/chat-b-village-world-20261123`.
Ausgangspunkt: `2909040deeb33b99ad4180b884b38921f28233a9` auf
`feature/childhood-village-20261123`. Die alten veröffentlichten APKs sind kein
Prüfnachweis für diese Änderungen.

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

Zwei südliche Häuser ergänzen die 13 vorhandenen Wohnhäuser. Familienhaus,
Nachbarhaus und bestehende Schmiede besitzen nun nutzbare Innenräume, Möbel,
Krüge, Geschirr, Vorräte, Schlafstellen und Arbeitsgegenstände. Eine Gasse
verbindet die Häuser. Türen, Eingangsschrägen, Fußböden und Möbel wurden mit
echten Physikkörpern geprüft; beim Betreten blendet die Darstellung das Dach
des betreffenden Hauses aus.

Julia, Silvanus und Sextus behalten ihre vorhandenen IDs. Die Szene erzeugt
keine zusätzlichen Wirtschaftspersonen für die Familie. Überschneidungen mit
der älteren Hintergrundbevölkerung werden gezielt ausgeschlossen. Tote
Einwohner verschwinden als aktive Personen und hinterlassen keine unsichtbaren
Kollisionskörper. Die Dorfübersicht zählt die tatsächlich Lebenden.

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

Die zehn neuen gezielten Modul- und Integrationsszenarien wurden einzeln mit
Godot 4.7.2 ausgeführt:

| Szenario | Einzelprüfungen |
| --- | ---: |
| Story, alternative Ausgänge, Zeit, Speicherung, Migration | 345 |
| Handel | 101 |
| Handel über das tatsächliche WorldModel | 39 |
| Reiterzustand und Darstellung | 144 |
| Hauszugänge, Böden und Dächer | 116 |
| Einwohneridentitäten und Todeszustände | 89 |
| Physischer Fluchtweg und Blockaden | 22 |
| Sichtbare Leih-/Eigentumsausrüstung | 37 |
| Tatsächliche Oberfläche: erste Tage, Arbeit, Handel, Neustart | 116 |
| Beide Nächte bis zum Schwur mit tatsächlichen Main-Neustarts | 231 |
| **Summe dieser zehn Szenarien** | **1.240** |

Der Nachtlauf führte beide Zweige mit gültigen Befehlen durch. Er enthält fünf
vollständige Main-Neustarts zusätzlich zur anfänglichen Instanz. Reiseabschnitte
der Integrationsfälle verwenden ausdrücklich gesetzte Testpositionen; die
separaten Haustür- und Eskortentests prüfen tatsächliche Bewegung und Kollision.
Diese Unterscheidung steht auch in den jeweiligen Testquellen.

Der vollständige aktuelle Gesamtlauf ist unter
[evidence/validation/validation_report.json](evidence/validation/validation_report.json)
einschließlich Einzelprotokollen und Quellhashes abgelegt. Aufruf:

```bash
python3 tools/check_prototype.py --report docs/18_childhood/evidence/validation
python3 -m unittest discover -s tests -p 'android_*_test.py'
```

Die 78 Python-Prüfungen des Android-Werkzeugs verwenden ausdrücklich synthetische
Paket- und Beobachterdaten. Das Protokoll steht unter
[evidence/android-harness](evidence/android-harness). Sie ersetzen keinen APK-Lauf.

Die folgenden Bilder stammen aus der tatsächlichen Godot-Engine, mit
GL Compatibility und llvmpipe. Sie sind keine Konzeptbilder:

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
Aussage zur Temperatur eines echten Handys.

## Android-Lieferweg

Der Prüfbau verwendet Paketversion `0.4.0-childhood`, Versionscode 4, und den
bestehenden Android-Workflow. Der Aufgabenbranch wurde dessen erlaubten
Auslösern hinzugefügt. Der Workflow baut ARM64 und einen separaten
Emulator-Prüfbau, prüft die tatsächlichen exportierten Module und startet den
vorhandenen Android-Emulatorlauf.

Die neue Android-Strecke bedient die echte Touchoberfläche: kurze Bewegung im
Familienhaus, Julia ansprechen, den Essenskorb zusagen, angehaltene Dialogzeit
prüfen, zurückkehren und nach Prozessneustart dieselbe Welt, Szene, Position,
Tag und Alter nachweisen. Sie schreibt keine Spielentscheidungen über einen
Testkanal. Das endgültige Ergebnis gehört zum konkreten Workflowlauf und dessen
APK-Hash; ein älterer erfolgreicher Android-Bericht gilt dafür nicht.

## Gemeinsame Dateien und nächste Integration

Chat B ergänzt in `main.gd` den neuen Start, Dialoge, Handel, Journal und die
Kette Kollision prüfen → autoritativen Schritt anwenden → gespeicherte Julia
darstellen. `game_world.gd` verbindet Räume, Ziele, Nachtlicht, Reiter und das
sichtbare Ausrüstungsflag. Die UI ergänzt Tagesanzeige, Kompass und passende
Dialogaktionen. `android_village_diagnostics.gd` erweitert ausschließlich die
lesende Beobachtung um aktuelle Kindheits- und Touchdaten.

Der einzige Anschluss an die Figur in `village_person.gd` schaltet das vorhandene
Übungsmesh sichtbar. Chat As Bewegungs- und Kampfparameter werden dadurch nicht
ersetzt. Bei der Zusammenführung sind insbesondere diese gemeinsam berührten
Dateien gezielt zu prüfen; fremde uncommittete Worktrees wurden nicht verändert.

Für den nächsten Inhaltsblock sind die ersten Ermittlungs- und Verfolgungsmissionen
nach dem Schwur auszuarbeiten. Der aktuelle Abschluss bleibt ein gespeicherter
Aufbruch, keine bereits fertig erzählte Rachekampagne. Weitere Waffenübungen,
individuelle berittene Kämpfe, ausgeführte Trink-/Essenshandlungen, vollständige
Vertonung und vier Stunden Filmregie sind zusätzliche Produktionsarbeit. Die
vorhandenen Gegenstände und Tagesposen belegen diese noch offenen Animationen
nicht. Für Leistungszusagen bleibt ein längerer Test auf einem konkreten
Android-Gerät erforderlich.
