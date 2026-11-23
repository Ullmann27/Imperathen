# IMPERATHEN – Bevor die Straße ruft

**Arbeitsstand: 23. November 2026.** Dieses Regiebuch beschreibt die neu verfassten, ausführbaren Erzählbausteine des Auftakts. Bildnachweise und der tatsächliche Integrationsstand werden gesondert dokumentiert; der Text allein belegt keine fertige Konsolengrafik oder Vertonung.

## Dramatischer Kern

Der erste Wunsch ist überschaubar: einen eigenen trockenen Schlafplatz schaffen und im Dorf ankommen. Der Spieler beginnt mit zwölf Jahren. Livia erklärt im römischen Einstieg, wo er bereitgelegtes Holz nutzen und eine Unterkunft bauen darf. Dadurch haben das Sammeln und die freie Bauplatzwahl einen Anlass und einen verständlichen Ort. Ein Verlust der Eltern, ein Dorfbrand oder eine andere neue Familienvorgeschichte wird nicht erfunden.

Marcus hat ein eigenes Problem: Am Brunnen ist eine Strebe gebrochen. Er braucht vier Holzstücke und weiß zugleich, dass der Spieler Material für das eigene Dach benötigt. Hilfe, Ablehnung und spätere Rückkehr sind verständliche Antworten. Die Begegnung wird im Intro vorbereitet; die eigentliche Entscheidung fällt erst im spielbaren Dorf und über den vorhandenen, geprüften Spielbefehl.

Die Straße verbindet das kleine Leben mit dem größeren römischen Zusammenhang. Der Auftakt kündigt weder einen sicheren Kaisertitel an noch erklärt er ein Kind zum Soldaten. Das bestehende Erwachsenen-Kapitel „Die Straße zur Legion“ bleibt ein späterer Anschluss. Sein Lieferweg über Livia, Cassian, Titus und Aulus wird durch die neue Kindheitsinszenierung nicht ersetzt.

## Ablauf des ersten Tages

Die fünf Einstellungen haben zusammen ungefähr 43 Sekunden automatische Lesezeit. Der tatsächliche Wert wird je Text aus einer Mindestdauer und rund 17 Zeichen pro Sekunde zuzüglich zwei Sekunden Orientierung berechnet. Vorwärtsgehen, Lesepause und Überspringen sind Aufgabe der Oberfläche. Jede Einstellung besitzt eine stabile Kennung; Kamera und Untertitel können dadurch gemeinsam wechseln.

Die Main-Integration ergänzt nach diesen fünf Einstellungen eine **dauerhaft wartende Zielkarte**. „Überspringen“ führt ebenfalls auf diese Karte; erst „Ins Dorf“ übergibt die Steuerung. Damit kann der Spieler den Film auslassen und trotzdem den Anlass, den Materialbedarf und die nächste Handlung lesen. Bei der Erwachsenenmontage lautet die abschließende Aktion „Zur Ausbildung“. Die Weltzeit, Baustellen und Ressourcen laufen während Film und Zielkarte nicht weiter. Der Lesemodus hält jede Einstellung bis zum eigenen Weitergehen, die Pausenfunktion hält zusätzlich die Kamerafahrt an.

| Beat | Kamera-ID | Bildinhalt | Sprecher und Text | Zweck |
| --- | --- | --- | --- | --- |
| `road_dawn` | `valley` | Dorf und Verbindungsstraße; ein ruhiger Überblick | Chronik: „Für die Händler ist das Dorf ein Halt auf dem Weg nach Rom. Für dich kann es ein Zuhause werden.“ | Maßstab und persönliche Perspektive setzen |
| `livia_market` | `market` | Halbtotale auf den vorhandenen Markt; Livia befindet sich außerhalb des Bildes | Livia: „Du brauchst einen trockenen Schlafplatz. Das Holz westlich vom Brunnen ist freigegeben. Östlich des Weges darfst du bauen.“ | Anlass, Holzrecht und Baufläche erklären |
| `marcus_well` | `well` | Brunnen und der vorhandene Gefährte | Marcus: „He, bleib kurz! Am Brunnen ist eine Strebe gebrochen. Vier Holzstücke würden reichen. Hilfst du mir, bevor du dein Dach baust?“ | Menschen und einen echten Zielkonflikt zeigen |
| `first_roof` | `plot` | Tatsächlich freigegebene Baufläche östlich des Weges | Chronik: „Dein erstes Ziel ist ein Dach. Deinen Platz im Dorf findest du auch darin, wie du mit den anderen umgehst.“ | Unterkunft und Beziehung als zusammenhängenden Anfang vermitteln |
| `player_handoff` | `player` | Ruhige Ansicht der Spielerfigur, Anschluss an die reguläre Spielkamera | Chronik: „Finde das Holz westlich des Brunnens. Sprich mit Marcus. Deinen Bauplatz wählst du östlich des Weges.“ | Ein klares nächstes Handeln ermöglichen |

Die Namen und die Texte werden für die vier anderen bereits vorhandenen Herkünfte ausgetauscht. Dort spricht die Chronik anstelle von Livia. Albrun, Lin, Aki und Mira bleiben die jeweiligen Gefährten; ihre Anliegen stammen aus den vorhandenen Herkunftstexten. Ein Start am Reisfeld oder am Bezirksspeicher erhält keine römischen Personen und keine erzwungene Reise nach Rom.

Die geprüfte Integrationsbasis `148dd69` enthält noch kein eigenes Livia-Modell. Die Kamera zeigt deshalb den Markt, während ihre Äußerung als Untertitel erscheint; ihr wird keine vorhandene männliche Statistenfigur zugeordnet. Die Oberfläche nennt schlicht „Livia · Händlerin“. Die Anweisung „außerhalb des Bildes“ gehört zur Regie. Eine später von Chat 1 integrierte Livia-Darstellung kann diesen Bildaufbau erweitern. Eine hörbare Sprecheraufnahme ist damit nicht behauptet. Die Gesprächseinleitungen der übrigen Figuren beschreiben ebenfalls nur ihr Warten am jeweiligen Ort; nicht vorhandene Kniefälle, Handgriffe oder Korbanimationen werden nicht als sichtbar ausgegeben.

## Die erste freie Entscheidung

Marcus spricht im Dorf direkt: „Eine Strebe hält keinen vollen Eimer mehr. Vier Holzstücke, dann kann ich sie ersetzen. Ich weiß, du brauchst selbst ein Dach. Kannst du trotzdem etwas entbehren?“

| Antwort | Tatsächlicher bestehender Spielbefehl | Bereits implementierte Folge |
| --- | --- | --- |
| Vier Holz teilen | `choose_companion`, `choice=help` | Vier vorhandene Holz werden verbraucht; Vertrauen wird auf +20 gesetzt |
| Das Holz für das eigene Dach behalten | `choose_companion`, `choice=decline` | Kein Holzverbrauch; Vertrauen wird auf −5 gesetzt |
| Später wiederkommen | Nur Dialog schließen / `resume` | Keine dauerhafte Gefährtenentscheidung |

Die Hilfsantwort enthält `enabled=false` und eine verständliche Begründung, solange vier Holz fehlen. Die Oberfläche muss diese Information beachten. Ein fehlgeschlagener Spielbefehl darf keine bestätigte Reaktion spielen. Nach erfolgreicher Hilfe lautet Marcus' Antwort: „Danke. Die Strebe bekommen wir hin. Dein Holz werde ich nicht vergessen.“ Nach Ablehnung: „Verstehe. Du brauchst selbst ein Dach. Ich frage die anderen.“

Ein einziges Nein macht Marcus damit nicht sofort zum Feind. Die gespeicherte Beziehung bleibt der Ausgangspunkt für spätere Erlebnisse. Die Texte vergeben keine zusätzlichen Vorräte, Gefolgsleute oder Ränge.

Die Brunnenstrebe ist inzwischen tatsächlich in der Spielwelt dargestellt. Vor der Hilfe zeigt sie einen gebrochenen Holzverbinder mit Splittern und loser Bindung; nach einer erfolgreich bezahlten Hilfsentscheidung erscheinen die durchgehende Ersatzstrebe, seitliche Laschen und neue Bindungen. Der kaputte Zustand besitzt 1.156 Dreiecke, der reparierte 2.656; beide verwenden höchstens drei Materialflächen mit den vorhandenen Holz- und Leinentexturen einschließlich Normalen- und Rauheitskarten. Die kleine seitliche Konstruktion sitzt am tatsächlichen Brunnen und ersetzt weder dessen Dach noch dessen Grundkörper.

`opening_props.gd` leitet die Darstellung ausschließlich aus `origin_id` und der bereits gespeicherten `companion.choice` ab. Abgelehnte oder mangels Holz fehlgeschlagene Hilfe repariert das sichtbare Bauteil nicht. Nach Laden entsteht derselbe bestätigte Zustand wieder. Für die vier anderen Herkünfte wird diese römische Brunnenreparatur ausgeblendet. Es gibt dafür keine zusätzliche Belohnung, keinen zweiten Reparaturzustand und keine neue Kollision. Der sichtbare Zustandswechsel ist implementiert; eine ausgespielte Arbeitsanimation von Marcus gehört weiterhin zu einer späteren Ausbaustufe.

## Verständlicher Übergang zum Erwachsenen

Der bestehende Domainbefehl `train` verlangt eine fertiggestellte Unterkunft, die Gefährtenentscheidung, keine offene Baustelle und die Anwesenheit am Übungsplatz. Erst sein Erfolg erhöht die gemeinsame Weltzeit um sechs Jahre und das Alter beider Figuren auf 18.

`OpeningStory.adulthood(state)` liefert die folgenden drei Einstellungen ausschließlich für einen tatsächlich bestätigten Erwachsenenstand in der Phase `training`:

| Beat | Kamera-ID | Inhalt |
| --- | --- | --- |
| `six_years` | `plot` | Sichtbarer Titel „Sechs Jahre später · 18 Jahre“; die Unterkunft ist Teil der Heimat geworden; beide Figuren sind erwachsen |
| `remembered_choice` | `well` | Der Gefährte erinnert sich ausdrücklich an das geteilte Holz oder daran, dass der Spieler zunächst das eigene Dach versorgt hat |
| `adult_first_step` | `player` | Die erste Waffenübung beginnt jetzt: Abstand, kontrollierte Treffer und Ruhe zwischen den Schlägen |

Die Sequenz liest nur den Weltzustand. Wiederholung, Wiederaufnahme einer Einstellung oder Überspringen können weder ein zweites Mal altern noch eine Belohnung vergeben. Die Übergangsentscheidung sollte vor Ausführung des Zeitsprungs im laufenden Spiel verständlich angekündigt werden. Die Montage ist eine lesbare Zusammenfassung; sie behauptet keine sechs Jahre bereits vollständig simulierter Dorfalltagsereignisse.

Die aktualisierte Aufgabenkarte kündigt vor dem Trainingsbeginn ausdrücklich an, dass danach sechs Jahre vergehen. Der vorhandene Befehl wird über denselben Main-Pfad sowohl vom HUD als auch vom Übungsplatz ausgelöst. Die Montage beginnt erst nach dessen Erfolg. Ein Versuch ohne fertige Unterkunft, Gefährtenentscheidung oder Nähe zum Übungsplatz bleibt ein abgewiesener Spielbefehl und erzeugt keinen Altersfilm.

## Datenvertrag für Chat 1 und Integration

Implementierung: `prototype/scripts/story/opening_story.gd`.

- `sequence(origin_id) -> Dictionary`: `id`, `version`, `origin_id`, `title`, `location`, `chapter`, `beats`, `objective_title`, `objective_text`.
- Jeder Beat besitzt `id`, `shot_id`, `speaker`, `role`, `text`, `duration`, `chapter` und `location`. Alle Untertitel bleiben unter 200 Zeichen. `shot_id` ist `valley`, `market`, `well`, `plot` oder `player`.
- `companion_dialog(state) -> Dictionary`: `title`, `text`, `choices`; Antwortfelder sind `label`, `action`, optional `choice`, außerdem `enabled` und `reason`.
- `companion_reply(state) -> String`: Reaktion auf die tatsächlich gespeicherte frühere Antwort.
- `adulthood(state) -> Dictionary`: drei Beats nach erfolgreichem `train`, davor ein leeres Dictionary.

Der Katalog verändert keine Speicherschemata und benötigt keine neue Internet- oder KI-Verbindung. Neue Spielstände werden weiterhin vom vorhandenen WorldModel angelegt. Die Kamera stellt dieselbe 3D-Welt dar, in der anschließend gespielt wird. Echte Sprecheraufnahmen und zur jeweiligen Zeile passende Schauspielanimationen sind weitere Ausbaustufen. Die sichtbare Brunnenreparatur ist ein tatsächlicher Zustandswechsel; damit ist noch kein vollständiger Arbeitsablauf mit Handgriffen und Ton behauptet.

## Unterbrechen und fortsetzen

`prototype/scripts/cinematic/opening_checkpoint.gd` speichert den Präsentationsfortschritt getrennt vom Kampagnenzustand: Version, Weltkennung, Sequenzkennung, Einstellungsnummer und Abschlussmarkierung. Die aktuelle Einstellung wird bei jedem Wechsel geschrieben. Die Weltkennung bindet den Marker an die tatsächlich geladene Partie; ein Marker eines anderen neuen Lebens wird ignoriert. Unbekannte Daten, ungültige Nummern oder eine nicht zur aktuellen Lebensphase passende Sequenz werden nicht abgespielt.

Beim Wechsel der App in den Hintergrund pausiert die Szene. Nach vollständigem Neustart und „Fortsetzen“ beginnt ein gültiger offener Film wieder am Anfang der zuletzt gespeicherten Einstellung. Die angebrochene Kamerafahrt wird damit nicht millisekundengenau fortgesetzt. Bereits abgeschlossene Filme starten beim normalen Fortsetzen nicht erneut. Ein abgebrochener Film trifft keine Gefährtenwahl; der Marker besitzt keinen Befehl zum Vergeben von Gütern, zum Ändern des Vertrauens oder zum Altern.

Ein fehlgeschlagener Kampagnen- oder Markerspeichervorgang muss als solcher behandelt werden. Das Vorliegen eines Markers ist kein Beweis, dass auch der Kampagnenzustand erfolgreich gespeichert wurde. Die zusätzliche Speicherdatei bleibt eine Komfortfunktion für den Einstieg und darf den autoritativen Weltstand nicht ersetzen. Nach einem fehlgeschlagenen Speichern des Erwachsenenwechsels hält die Main-Integration dessen Montage deshalb als `pending_opening` im Pausenzustand zurück. Erst erfolgreiches erneutes Speichern erlaubt den Übergang; eine bloße Präsentationsmarkierung behauptet keinen gespeicherten Lebenslauf.

## Übernahme in die neuere Frontier-Welt von Chat 1

Dieser isolierte Arbeitsblock setzt auf `148dd69` auf. Im parallelen Arbeitsstand von Chat 1 wurden bereits weitere Figuren, Dorfzuständigkeiten und `frontier_chapter.gd` vorbereitet. Die bestehenden Hauptdateien dürfen deshalb nicht vollständig durch ältere Kopien aus diesem Block ersetzt werden.

Bei der Zusammenführung bleiben insbesondere erhalten:

- Die neuen Erwachsenen-Dialoge, `frontier_talk`, `frontier_choice`, `frontier_dialog` und ihr erlaubter Befehlspfad in Main.
- Die aus dem Weltmodell abgeleitete Frontier-Aufgabenkarte (`_ui_state()` / `frontier_objective`). Der Film ist eine zusätzliche Präsentation vor dem Spiel und beim Erwachsenenwechsel.
- Die echte Dorfpopulation, deren Positionen, Identitäten und Bewegungen sowie das Zeitupdate der Frontier-Welt.
- Die realen Anker für Markt, Gefährten, erste Hütte und Spieler. `get_cinematic_anchor()` soll diese aus der integrierten Welt lesen; ein später vorhandenes Livia-Modell muss eindeutig ihrer eigenen Figur entsprechen.

Die isolierten neuen Story-, Kamera-, Overlay- und Checkpointdateien lassen sich als eigene Bausteine übernehmen. Die Einbindungspunkte in Main, UI und Spielwelt werden mit den neueren Funktionen zusammengeführt. Der Beginn erklärt Unterkunft und erste Begegnung; „Die Straße zur Legion“ setzt anschließend weiterhin die erwachsene Dorfverteidigung und ihre Folgeentscheidung voraus.

## Herkunft, Fiktion und bestehende Grenzen

Die bestehenden regionalen Figuren und Anliegen stammen aus `prototype/scripts/strategy/origins.gd`. Dessen grobe Arbeitsannahme liegt um 100 n. Chr.; der Auftakt fügt kein konkretes Ereignis, keine neue Jahreszahl und keine angebliche historische Persönlichkeit hinzu. Die Dorfgespräche sind neu verfasste Fiktion. Historische Figuren brauchen später jeweils eine eigene zeitliche und quellenbezogene Prüfung.

Spielregeln, Ressourcenbedarf, Baufläche und Alterswechsel wurden gegen `prototype/scripts/domain/world_model.gd` abgeglichen. Der Schwerpunkt „erster Schlafplatz, Arbeit, Gefährte, nachvollziehbare Alterung“ stammt aus `docs/02_game_design/PLAYER_JOURNEY.md` und dem Abschnitt 2 des beigefügten ursprünglichen `IRON_BANNERS_Projektmappe/01_Konzept/MASTER_GDD.md`. Aktuelle Nutzer- und Repositoryanweisungen bestimmen den tatsächlich erlaubten Umfang.

## Ausgeführte Prüfung des Erzählkatalogs

Am 23. November 2026 wurde `godot --headless --path prototype --script res://tests/opening_story_test.gd` mit der lokal vorhandenen Godot-Version 4.7.2 ausgeführt und nach dem Abgleich der Dialog-Regie mit den tatsächlich sichtbaren Posen wiederholt: **59 Prüfungen, 0 Fehler**. Der letzte tatsächliche Lauf steht im [Prüflog](evidence/engine/opening_story.log).

Die Prüfung umfasst alle fünf Herkünfte, richtige Gefährten, begrenzte und lesbare Einstellungen, unveränderte Weltzustände durch Präsentationsabfragen, Hilfe mit und ohne tatsächlich gesammeltes Holz, den echten Bau- und Ausbildungsbefehl sowie beide Erinnerungsvarianten nach Speicherung und erneutem Laden. Sie prüft außerdem, dass eine Oberfläche zurückgegebene Daten verändern kann, ohne den Erzählkatalog für folgende Aufrufe zu beschädigen. Das ist ein Nachweis für den Daten- und Regelanschluss; Grafik, Ton, Touchbedienung und physische Android-Geräte benötigen ihre eigenen Integrationsnachweise.

Der abschließende, von der Root-Integration ausgeführte Engine-Lauf hat **21 Prüfgruppen bestanden, ohne Warnungen**. Darin ergeben die fünf Opening-Gruppen zusammen **269 Einzelprüfungen**: Story 59, Brunnenbauteil 36, Kamera 76, Oberfläche 66 und tatsächlicher Main-Ablauf 32. Der [vollständige Prüfbericht](evidence/engine/validation_report.json) enthält auch die Quellhashes des getesteten Stands. Diese Zahl beschreibt den Opening-Branch; die zusätzliche Zusammenführung mit Chat 1 und deren eigene Nachweise stehen getrennt im [Integrationspaket](integration/README.md).
