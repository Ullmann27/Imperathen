# IMPERATHEN – Grenzdorf

Ein spielbarer historischer Strategieprototyp mit Wiederaufbau, Berufen, Dorfüberfällen, taktischem Talgefecht und saisonaler Weltkampagne. Diese Anleitung beschreibt die Dorfleben-Prüffassung `0.3.0-village`. Android ist die erste Zielplattform; Windows und Linux führen dieselben Spielbefehle aus.

## Auf Android anfangen

Lade die Datei **IMPERATHEN-…-arm64.apk** aus der gewünschten Prüffassung herunter und öffne sie auf dem Gerät. Wähle im Hauptmenü **Rom · Italien** und **Neues Leben**, um den erweiterten Dorfanfang zu spielen. Nach dem filmischen Einstieg führt **Ins Dorf** von der Zielkarte ins Spiel; auch nach dem Überspringen des Films bleibt diese Bestätigung erforderlich. **Fortsetzen** lädt die aktive gespeicherte Partie. **Figuren** öffnet die Bildergalerie; **Talgefecht erproben** und **Weltkugel erkunden** starten die gesonderten freien Szenarien.

Die neue Dorfmechanik mit Decimus, Arbeitszuweisung, Berufen und wiederkehrenden Überfällen ist derzeit für eine **neue römische Partie** aktiviert. Andere Herkünfte und übernommene ältere Partien erhalten diese Erweiterung nicht automatisch. Godot und Blender werden nur auf dem Entwicklungsrechner benötigt. Frühere Debugbauten können eine andere Signatur tragen. [Prüffassungen und Downloads](https://github.com/Ullmann27/Imperathen/releases) · [Aktueller Dorfleben-Lieferbericht](../docs/17_village_life/DELIVERY.md)

## Editorstart

1. Godot **4.7.2** verwenden; genau diese Version wurde in diesem Entwicklungsblock ausgeführt.
2. Dieses Repository herunterladen oder den Entwicklungsbranch auschecken.
3. Im Godot-Projektmanager `prototype/project.godot` importieren. Der erste Import wandelt GLB und WAV automatisch in Engine-Ressourcen um.
4. **F5** startet `main.tscn`, den Vorspann und das Hauptmenü. Der vollständige Vorspann läuft beim ersten Start (Tippen oder Enter überspringt); danach erscheint eine kurze Titelkarte. Einstellungen: „Vorspann bei jedem Start vollständig zeigen“, „Vorspann jetzt ansehen“ und „Musik im Hauptmenü“. Details: [Übergabe Vorspann/Menü](../docs/22_title_menu/DELIVERY.md).

Alternativ im Repository: `godot --path prototype`. Für Headless-Prüfungen: `python tools/check_prototype.py`.

Der Android-Workflow baut die Prüfpakete mit den passenden offiziellen Exportvorlagen. Auf dem Spielgerät genügt die ARM64-APK. [Android-Bauweg](../docs/10_development/ANDROID_BUILD.md)

## PC-Grafikkarte

Im Windows-Archiv startet `IMPERATHEN.exe` die Compatibility-Fassung. `IMPERATHEN-Vulkan.cmd` startet dieselbe EXE mit Vulkan und dem Godot-Renderer Forward+. Unter Linux funktioniert `./IMPERATHEN.x86_64 --rendering-method forward_plus --rendering-driver vulkan`. `--verbose` zeigt die erkannten Vulkan-Geräte an. `--gpu-index 0` wählt den Adapter mit Index 0. Auf dem PC umfasst das Profil Hoch ein 3D-Pixelbudget bis 3.840 × 2.160, auf Android bis 2.560 × 1.440. Die tatsächlich verwendete Auflösung, der Renderer und der Adapter stehen in der Leistungsdiagnose. Die Szenen und gespeicherten Spielregeln sind gemeinsam.

## Herkunft und Spielstand

Italien unter römischer Herrschaft, die Gemeinschaft östlich des Rheins, der Weichselraum, die Östlichen Han und Wa in der Yayoi-Zeit bieten unterschiedliche Einstiege, Gefährten, Siedlungsbilder und saisonale Geschichten. Rom ist vorausgewählt. Die vorhandenen Grundaufgaben verwenden denselben Regelkern; der nachstehende erweiterte Dorfweg gilt für **Rom · Italien**. Die anderen vier Herkünfte behalten ihren bisherigen kürzeren Entwicklungsweg.

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

Der neue römische Dorflebenslauf beginnt in seiner Chronik **100 n. Chr. mit zwölf Jahren**. Nach dem ausdrücklich angekündigten sechsjährigen Übergang zeigt die Dorfchronik 106 n. Chr. und ein Alter von achtzehn. Nach dem späteren Truppengefecht und der Folgeentscheidung können saisonale Kartenaktionen die gespeicherte Weltzeit und das Alter weiterführen. Jede Herkunft hat eine Herbstentscheidung mit konkreten Folgen und einem späteren Chronikeintrag. Die Jahreszeiten sind ein vereinfachtes Versorgungsmodell; südliche Auftragsregionen haben entgegengesetzte Jahreszeiten.

**Bekannte Zeitabweichung dieser Prüffassung:** Die Saisonanzeige der Weltkugel rechnet weiterhin ab 100 n. Chr. und übernimmt den sechsjährigen Vorsprung der Dorfchronik noch nicht. Diese beiden Kalenderanzeigen sind deshalb nach dem Altersübergang nicht synchron. Die historische Einordnung des neuen Dorfanfangs steht in [STORY.md](../docs/17_village_life/STORY.md), die ältere Atlasgrundlage in [ATLAS_SOURCES.md](../docs/12_integration/ATLAS_SOURCES.md).

## Spielweg im neuen römischen Dorf

Du beginnst mit zwölf Jahren in einer bereits existierenden Grenzsiedlung. **Decimus verwaltet das Dorf; du bist zunächst Bewohner.** Vierzehn namentliche Erwachsene teilen sich fünf Arbeitsstätten. Deine eigene Hütte, Beziehungen, Lehre, Arbeitseinteilung und Beiträge zur Verteidigung entstehen während dieser Partie.

1. **Decimus kennenlernen.** Gehe zum Verwalter und benutze **Interagieren** beziehungsweise **E**. Wähle **Beim Wiederaufbau mithelfen**. Erst diese Erlaubnis schaltet die Arbeitskoordination frei; Decimus bleibt Verwalter.
2. **Dach und Gefährtenentscheidung.** Sammle Holz an den beschrifteten endlichen Vorräten; jede erfolgreiche Interaktion bringt vier Holz. Zwölf Holz reichen für Marcus' Bitte um vier Holz und die erste Hütte für acht Holz. Eine Ablehnung seiner Bitte ist ebenfalls eine gültige gespeicherte Entscheidung. Wähle **Hütte bauen** beziehungsweise **Hütte** im kompakten HUD, setze sie auf die erlaubte Fläche östlich des Weges und kehre zur persönlichen Ansicht zurück. Bleibe für zwölf Sekunden Arbeit höchstens 4,5 Meter von der Baustelle entfernt. Weitere Reparaturen brauchen zusätzliche Materialien.
3. **Arbeitsgruppen zusammenstellen.** Öffne **Dorfleben** und danach ausdrücklich den Reiter **Arbeit & Versorgung**. Scrolle zu **Einwohner zuweisen**. Die erste Übersicht enthält diese Auswahlfelder noch nicht. Weise etwa Fabius und Drusa dem **Holzfällerlager** zu und starte dessen **Wiederaufbauen**-Auftrag, sobald das angezeigte Material vorhanden ist. Schließe die Übersicht mit **Zurück ins Dorf**, damit Arbeitszeit verstreicht. Weniger als zwei arbeitsfähige Helfer stoppen dieses Lager. Die Dorffelder sind zu Beginn bereits mit Vibius und Julia besetzt; ihre Nahrung versorgt dieselben Einwohner.
4. **Menschen und Berufe kennenlernen.** Suche weitere Personen persönlich auf. **Menschen & Berufe** zeigt Beziehungen und ihre aktuellen Orte; nach einer Arbeitszuweisung können sie am Betrieb stehen. Hilfe für die jeweilige Bitte oder mindestens acht Vertrauen öffnet **Beruf lernen**. Die erste Lehre kostet kein zusätzliches Geld; ein späterer Berufswechsel kostet drei Denarii. Für **Bündnis schließen** brauchst du zwölf Vertrauen und zwei Getreide. Die Gefährtenentscheidung mit Marcus ersetzt diese persönlichen Dorfbekanntschaften nicht.
5. **Auf die erste Warnung reagieren.** Sobald eine Hütte fertig ist, du mindestens drei der sieben Gesprächspersonen kennst und 120 Sekunden aktive Dorfzeit vergangen sind, beginnt die erste Überfallwarnung. Gespräche, Dorfübersichten und Pausen halten diese Zeit an. In den folgenden 45 Spielsekunden kannst du nach einem Gespräch mit Varro die Spur am nordwestlichen Waldrand untersuchen, am Nordposten Alarm auslösen und gesunde, versorgte Einwohner unter **Arbeit & Versorgung** auf **Verteidigung** setzen. Sie fehlen anschließend an ihren Arbeitsplätzen.
6. **Den Dorfüberfall erleben.** Beim Angriff zählen Entfernung, Ausdauer und Erholung zwischen Schlägen. **Blocken** und **Ausweichen** wirken nur im passenden Zeitfenster; Erfahrung entsteht erst aus tatsächlichen Aktionen. Mit **Interagieren** kannst du die gefährdete Person am nördlichen Dorfweg retten. Die Wache unterstützt nur mit geeigneten, nahen Verteidigern. Aufklärung, Alarm, Kampf, abgewehrte Treffer und Rettung entwickeln Mut, Kampf, Scharfsinn und Taktik. Eine schlechte Verteidigung kann Vorräte kosten und Menschen verletzen; dieser frühe Überfall beendet den Lebenslauf nicht automatisch.
7. **Erholen und weiter aufbauen.** Nach der Gefahr versorgt Aurelia deine Verletzungen gegen eine Getreideration. Einwohner können über **Zur bisherigen Arbeit** den Verteidigungsdienst verlassen oder mit **Frei / Erholen** wieder Reservisten werden. Vorräte und Arbeitsstätten laufen weiter; spätere Überfälle sind möglich. **Notvorrat beim Händler kaufen** tauscht sechs Denarii gegen sechzehn Getreide aus einem begrenzten Vorrat.
8. **Den nächsten Lebensabschnitt selbst beginnen.** Eine fertige Hütte und Marcus' Entscheidung genügen jetzt noch nicht. Erforderlich sind zusätzlich mindestens drei Dorfbekanntschaften, ein beendeter Überfall und zwei vollständig vergangene Dorftage, also 240 Sekunden aktive Dorfzeit. Beende sämtliche offenen Hüttenbaustellen und warte, bis weder eine Überfallwarnung noch ein Angriff läuft. Gehe zum Übungsplatz und wähle im HUD **Ausbildung** beziehungsweise **Üben**. Der folgende erklärte Übergang **sechs Jahre später** macht dich und Marcus achtzehn; die Darstellung erhält eure bisherigen Entscheidungen.
9. **Erwachsene Ausbildung und eigener Trupp.** Triff das Übungsziel dreimal mit gültigem Abstand und Erholung zwischen Schlägen. Danach kannst du über **Rekrutieren** beziehungsweise **Truppe +** bis zu drei Freiwillige für je fünf Denarii und zwei Getreide anwerben. Dafür braucht das Dorf gesunde, ausreichend versorgte Einwohner in **Frei / Erholen**, die keine der sechs Berufspersonen sind. Rekrutierte Einwohner fehlen anschließend in der zivilen Wirtschaft.
10. **Das spätere Truppengefecht.** **Dorf verteidigen** beziehungsweise **Verteidigen** startet nach der Ausbildung und mit mindestens einem lebenden Rekruten den gesonderten Gefechtsauftrag mit drei Gegnern nördlich des Dorfes. Nach dem Sieg entscheidest du zwischen Schutz der Siedlung und Verfolgung nach Norden. Diese Folgeentscheidung öffnet den weiteren regionalen Auftrag. Die Herrscherkarriere bleibt ein Ausbauziel.

Ein Dorftag dauert in dieser Prüfphase zwei Minuten aktiver Simulation. Der lange Jugendabschnitt und eine unbegrenzte Lebenssimulation sind damit noch nicht umgesetzt. Eine tödliche Niederlage im **späteren Truppengefecht** beendet den Lebensbogen; das Hauptmenü erlaubt einen neuen Anfang. Die frühen Dorfüberfälle und dieses Gefecht haben unterschiedliche Folgen.

### Die sechs Berufspersonen

| Person | Verfügbare Lehre | Erste Bitte |
| --- | --- | --- |
| Aelia | Steinmetzlehre | 2 Holz |
| Varro | Späherlehre | 2 Getreide |
| Fabius | Holzfällerlehre | 2 Getreide |
| Aurelia | Heilkundelehre | 2 Getreide |
| Cassia | Handelslehre | 2 Holz |
| Severus | Wachausbildung | 2 Holz |

Diese persönliche Berufswahl ist von der späteren erwachsenen Waffenübung getrennt. Die fünf Arbeitsstätten heißen **Dorffelder**, **Holzfällerlager**, **Steinbruch**, **Handelsplatz** und **Stadtposten**. Sie brauchen zwei, zwei, vier, zwei beziehungsweise zwei arbeitsfähige Einwohner. Die Arbeitsübersicht nennt Materialbedarf, Zustand und den konkreten Grund, wenn ein Betrieb ruht.

## Bedienung

| Aktion | Tastatur und Maus | Touch |
| --- | --- | --- |
| Figur bewegen | WASD oder Pfeiltasten | linker Analogbereich |
| Kamera drehen | rechte Maustaste halten und ziehen | freien Weltbereich ziehen |
| Interagieren | E | Interagieren |
| Angreifen/üben | linke Maustaste oder Leertaste | Angreifen |
| Dorfleben öffnen | J oder HUD | Dorfleben |
| Beim Dorfüberfall blocken | Q | Blocken |
| Beim Dorfüberfall ausweichen | R | Ausweichen |
| Hütte planen | B oder HUD-Schaltfläche | Hütte bauen |
| Bauplatz bestätigen | freie Fläche anklicken | freie Fläche antippen |
| Bauplan abbrechen | Escape oder B | Bau abbrechen |
| Person/Stadt/Karte | HUD, Tab, M | entsprechende HUD-Schaltfläche |
| Kameraabstand im Dorf | Mausrad | zwei Finger im freien Weltbereich spreizen oder zusammenführen |
| Pause | Escape oder Menü im HUD | Menü im HUD |

Touch wird auf passenden Geräten automatisch angeboten und kann in den Einstellungen auch manuell eingeschaltet werden. Android-Zurück schließt Gespräche und Dorfübersichten beziehungsweise pausiert das laufende Spiel; im filmischen Einstieg pausiert oder setzt es die Sequenz fort. Aktuelle Engine- und Android-Prüfnachweise stehen im [Dorfleben-Lieferbericht](../docs/17_village_life/DELIVERY.md). Ein physischer Handytest und dessen Temperatur-/Leistungswerte sind separat zu erbringen.

Die Einstellungen umfassen UI-Größe, reduzierte Bewegung, Lautstärke, Touchanzeige, Leistungsdiagnose und **vier Grafikprofile**:

| Android-Anzeige | Eingestellte Bildratenobergrenze |
| --- | ---: |
| Leicht | 30 FPS |
| Ausgewogen | 60 FPS |
| Hoch | 60 FPS |
| Sehr hoch | 30 FPS |

Auf dem PC ergänzt die Anzeige bei **Hoch** „bis 4K“. Die Obergrenzen und Pixelbudgets sind Einstellungen, keine gemessenen oder garantierten Gerätebildraten. Die Profile ändern die Darstellung; die Spielregeln bleiben identisch.

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

Im Dorf ist die Hütte der erste frei platzierbare Gebäudetyp; die fünf bestehenden Arbeitsstätten werden mit Material und Personal wiederaufgebaut. Die Weltkampagne bildet 32 Orte über ein Routennetz ab. Der zusätzliche 32 × 32 km große Geländerahmen enthält geplante Fernorte und ist noch keine vollständig bewohnte offene Welt. Politische Laufbahnen, Diplomatie, ausgearbeitete Großstädte und regionale Kampagnenarmeen sind weitere Ausbauschritte. Das Talgefecht verwendet für alle Herkünfte dasselbe Grenzlegion-Szenario.

Der Regelkern begrenzt erfolgreiche explizite Befehlskennungen auf 1.024 und bewahrt 256 Chronikeinträge. Diese Prüffassung ist daher noch keine unbegrenzt fortsetzbare Kampagne. Die Kalenderabweichung zwischen Dorfchronik und Weltkugel ist oben dokumentiert. Die vorhandene Grafik bleibt unter dem angestrebten AAA-Niveau.

Die beschriebenen Dorfregeln stehen in [village_life.gd](scripts/story/village_life.gd), [village_economy.gd](scripts/domain/village_economy.gd) und [world_model.gd](scripts/domain/world_model.gd). Bedienbezeichnungen kommen aus [village_life_panel.gd](scripts/ui/village_life_panel.gd) und [game_ui.gd](scripts/ui/game_ui.gd); die Saisonanzeige aus [season_campaign.gd](scripts/strategy/season_campaign.gd).

## Spielbilder und Originalmodelle

[Das Tal in Godot](../docs/12_integration/evidence/valley-balanced.webp) · [Das römische Dorf](../docs/12_integration/evidence/village-italia.webp) · [Die Weltkugel mit Han-Einstieg](../docs/12_integration/evidence/globe-han.webp) · [Transparente Modellstudien](../art/landscape/README.md)
