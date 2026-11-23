# Dorfleben, Beziehungen und Verteidigung

Stand: 23. November 2026. Ausführbare Regeln: `prototype/scripts/story/village_life.gd`. Die gemeinsamen Rohstoffe liegen weiterhin ausschließlich in `data.resources`. NPCs, Arbeitskräfte, Verletzungen und Wachen beziehen sich auf dieselben benannten Personen in `data.village.economy.people`.

## Ausgangspunkt und tatsächlicher Umfang

Der neue römische Dorfabschnitt beginnt innerhalb der bestehenden Epoche um **100 n. Chr.** Der Spieler ist Bewohner unter einer bereits bestehenden Herrschaft. **Trajan** ist der historische Kaiser; **Decimus** ist ein für dieses Spiel geschaffener örtlicher Verwalter. Dorf, Mentoren, ihre persönlichen Dialoge und die lokalen Plündererüberfälle sind eigenständige Fiktion. Sie werden ausdrücklich nicht als nachgewiesene historische Begebenheiten ausgegeben.

Das historische Bezugssystem enthält Trajans Regierungszeit 98–117 n. Chr. sowie seine Dakerkriege 101–102 und 105–106 n. Chr. Das italienische Kulturministerium nennt diese Daten auf seiner [Seite zur Trajanssäule](https://cultura.gov.it/luogo/parco-archeologico-del-colosseo-colonna-traiana). Die [staatliche interaktive Darstellung der Säule](https://colonnatraiana.cultura.gov.it/) gliedert die beiden Kriege entsprechend. Der vorhandene bestätigte sechsjährige Altersübergang würde aus dem Startjahr 100 das Jahr 106 machen. Caesar und Trajan werden nicht in dieselbe Lebenszeit versetzt.

Die historischen Anker sind Daten für spätere große Missionen. **Eine spielbare Dakerkriegskampagne oder die Umschreibung ihres Ausgangs ist mit diesem Beitrag noch nicht implementiert.** Dorfentscheidungen markieren einen eigenen fiktiven Lebensweg (`fictional_branch`); sie ändern keine historischen Quellen. Andere bestehende Herkünfte behalten ihren bisherigen Regionalpfad. Ihre Darstellung behauptet keine römische Herrschaft.

## Personen, Freundschaft und Beruf

| Person | Aufgabe und Persönlichkeit | Möglicher Lebensweg |
| --- | --- | --- |
| Decimus | Bestehender Verwalter; erklärt Verantwortung und Arbeitskoordination | Bewohner mit begrenztem Aufbauauftrag |
| Aelia | Steinmetzin; sieht zuerst Tragwerk und Gefahren | Steinmetzlehre |
| Varro | Späher; liest Spuren und plant Proviant | Späherlehre |
| Fabius | Holzfäller; besteht auf einem zweiten Arbeiter | Holzfällerlehre |
| Aurelia | Heilerin; verbindet Behandlung mit Versorgung | Heilkundelehre |
| Cassia | Händlerin; denkt an Wagen, Wege und eingehaltene Zusagen | Handelslehre |
| Severus | Wachausbilder; lehrt Abstand, Ausdauer und rechtzeitige Abwehr | Wachausbildung |

Ein erstes wirklich ortsgebundenes Gespräch gibt drei Vertrauen. Eine konkrete, einmalig bezahlte Hilfe gibt sieben. Die erste Lehre bei diesem Mentor gibt zwei weitere Punkte. Wiederholtes Begrüßen, erneutes Einlösen derselben Bitte und wiederholte Bündnisbestätigungen erzeugen nichts. Jede Person besitzt ihren eigenen Beziehungszustand.

Eine Lehre setzt Kennenlernen sowie erfüllte Hilfe oder mindestens acht auf anderem Weg verdiente Vertrauenspunkte voraus. Ein zunächst abgelehnter Mentor kann damit später durch echte Dorfverteidigung gewonnen werden. Die erste Lehre kostet kein zusätzliches Geld; der Wechsel zu einem anderen erlernten Beruf verbraucht drei Denarii. Ein persönliches Bündnis verlangt zwölf Vertrauen und zwei Getreide für gemeinsame Versorgung.

Berufe werden an echte Regeln angeschlossen: Wachausbildung erhöht den eigenen bestätigten Nahkampfschaden. Heilkundelehre verbessert die Rettungsbehandlung. Holzfäller-, Steinmetz-, Handels- und Heilkundewissen beeinflussen die tatsächlich besetzten Wirtschaftsbetriebe beziehungsweise Versorgung; deren Mengen und Bestände prüft das Wirtschaftsmodul. Ein Verbündeter zählt nicht als zusätzlich erschaffener Soldat. Nur eine tatsächlich gesunde, eingeteilte und räumlich nahe Person verbessert die gemeinsame Verteidigungswirkung.

`actor_position(data, npc_id)` ist die gemeinsame Ortsquelle für Darstellung und Gesprächsreichweite. Ein zugeteilter Mentor steht an seinem Arbeitsort. Ein Gespräch an seinem früheren Wohnplatz wird abgewiesen. Mehrere Beschäftigte erhalten unterschiedliche Positionen am selben Betrieb. Der Rettungsfall nutzt ebenfalls diese Funktion und dieselbe Personenidentität.

## Alltag und erster Angriff

Ein Prototyptag dauert 120 tatsächlich fortgeschrittene Spielsekunden. Das ist ausdrücklich ein Tempo für den spielbaren Systemnachweis, keine historische Zeitbehauptung. Pausiert der Hauptablauf, wird diese Zeit nicht fortgeschrieben.

Die erste Warnung kann frühestens nach 120 Sekunden beginnen und setzt eine fertige Unterkunft sowie drei tatsächliche Bekanntschaften voraus. Während der 45 Sekunden langen Warnung sind drei Vorbereitungen verbunden:

1. Bei Varro Wissen holen und am nordwestlichen Waldrand die Spur untersuchen.
2. Am Nordposten Alarm geben.
3. Wirkliche Arbeitskräfte zur Verteidigung einteilen und dadurch aus ihrer bisherigen Arbeit abziehen.

Danach kommen zunächst drei Angreifer aus dem Norden. Sie bewegen sich durch die Spielwelt, greifen nahe Spieler nach einem zeitlichen Ansatz an und versuchen, Vorräte zu erreichen. Weitere Überfälle erhöhen die Gruppe bis höchstens sechs Angreifer. Zwischen abgeschlossenen Angriffen liegen 360 Sekunden. Ein Angriff dauert höchstens 150 Sekunden; die Beute ist auf sechs Getreide begrenzt. Der nächste Angriff beginnt nicht parallel zum älteren Gefechtssystem.

Die Wachwirkung verlangt mindestens zwei einsatzfähige Personen in tatsächlicher Reichweite des Gegners. Ein beschädigter Stadtposten stellt keine einsatzbereite Postenwache dar; ausdrücklich eingeteilte Verteidiger können trotzdem gemeinsam antreten. Fernwirkung quer durch das Dorf ist ausgeschlossen.

## Persönlicher Kampf und Fähigkeiten

| Handlung | Geprüfte Bedingungen | Tatsächliche Folge |
| --- | --- | --- |
| Schlagen | Lebendes Ziel, höchstens 2,8 Meter, 0,65 Sekunden Erholung, zwölf Ausdauer | Bestätigter Schaden; Kampf wächst nur für wirksame Treffer |
| Blocken | 16 Ausdauer, 0,9 Sekunden Schutzfenster | Erst ein tatsächlich abgefangener Angriff zählt als Block |
| Ausweichen | 22 Ausdauer, 0,55 Sekunden Schutzfenster | Erst ein tatsächlich vermiedener Angriff erhöht Scharfsinn |
| Früher Alarm | Richtiger Ort, aktive Warnung, einmal pro Angriff | Taktik und bessere vorbereitete Wachwirkung |
| Spur lesen | Varro bekannt, richtige Spur, aktive Warnung, einmal pro Angriff | Scharfsinn und konkrete Gegnerzahl |
| Rettung | Aktiver Überfall, reale gefährdete Person, tatsächliche Nähe | Diese Person wird versorgt; Mut und Aurelias Vertrauen wachsen |

Blocken und Ausweichen teilen eine Erholungszeit von 1,1 Sekunden. Schutz läuft ab und erzeugt keine dauerhafte Unverwundbarkeit. Gegner bestimmen ihren Schaden nach Entfernung und Angriffstakt; kein öffentliches Kommando akzeptiert frei angegebene Erfahrung oder Schadenshöhe.

Bei einer eigenen Niederlage bleibt die Gesundheit bei eins. Vorratsverlust und eine Verletzung im wirklichen Verteidigerroster bleiben erhalten. Aurelia bietet außerhalb akuter Angriffe und erst nach dem Kennenlernen eine Versorgung an: ein Getreide für bis zu 25 Gesundheit, begrenzt auf 100. Die Behandlung gibt keine Erfahrung. Das ermöglicht eine Fortsetzung, ohne einen neuen Spieler mit einer unheilbaren Ein-Punkt-Gesundheit zurückzulassen.

Eine abgeschlossene Dorfverteidigung gewährt dem Spieler nur bei tatsächlich erfasster Beteiligung einen Abschlussfortschritt. Siege seiner Wachen werden nicht als eigene Kampferfahrung verbucht. Die spätere Ausbildung wird frühestens ab dem dritten Prototyptag nach drei Bekanntschaften und mindestens einem abgeschlossenen Angriff frei. Ein einziges Dach überspringt damit nicht das Dorfleben.

## Zustand, Bilanzen und Speicherung

- `social`: Begegnungen, individuelle Entscheidungen, gewählter Beruf, tatsächliche Dorfzeit und eigener Güterbeleg.
- `raid`: Warnung, lebende Angreifer, Bewegungs- und Angriffszeiten, Ausdauer, Rettungsidentität, Beteiligung und Folgen.
- `attributes`: Mut, Kampf, Scharfsinn und Taktik aus den geprüften Handlungen.
- `history`: dokumentierter Ausgangsrahmen sowie begrenzte eigene Ereignisse mit Herkunft `fictional_playable_event`.

Jeder Rohstoffabzug steht zusätzlich im signierten Mengenbeleg `social.ledger`; das Hauptmodell kann dadurch die Gesamtbilanz zusammen mit der Wirtschaft erhalten. Vorhandene Gefährten- und Frontier-Entscheidungen werden nicht überschrieben. Das Modul liest die bestehende Bevölkerung und verändert nur konkret betroffene Personen.

Die Regeln laufen in Zeitschritten von 0,1 Sekunden. Unterteilungen eines identischen Zeitraums ändern weder den Warnbeginn noch die Kampfauflösung. JSON speichert Zahlen als Zahlen; die Wiederherstellung prüft deren Inhalt, Grenzen und Widersprüche. Präsentationsabfragen sind Kopien und mutieren keinen Spielzustand.

## Nachweis

`godot --headless --path prototype --script res://tests/village_life_test.gd` bestand im ausgeführten Lauf **157 Einzelprüfungen** ohne Fehler. Darunter: räumliche Gesprächsvoraussetzungen, wiederholte Antworten, echte Güterkosten, Berufswechsel, Bündnisse, Warnung und Alarm, konkrete Treffer, bestätigter Block und Ausweichen, Verlust und Heilung, reale Rettungsidentität, gemeinsame Arbeitsorte, fehlende Wachfernwirkung, Zeitschrittunterteilung, JSON-Fortsetzung sowie beschädigte Eingaben. Verstorbene oder mit der Miliz abwesende Mentoren bieten keine zivile Lehre, Bündnisse oder Heilung an; ihre Beziehungsgeschichte bleibt gespeichert.

Dieser Nachweis prüft Spielregeln. Modellqualität, Animationsqualität, Androidleistung und vollständige Darstellung im kombinierten Spiel benötigen die gesonderten Integrations- und Bildnachweise des Hauptdurchgangs.

## Fortsetzungsprüfung am 23. November 2026

Die erneute Prüfung hat einen Fortschrittsfehler bei bereits hohem Vertrauen gefunden: Die einmaligen Zuwächse für Kennenlernen, erfüllte Hilfe und erste Lehre konnten den zulässigen Höchstwert 100 überschreiten. Dadurch wurde eine berechtigte Hilfe oder Berufswahl vollständig verworfen. Auch Aurelias erste persönliche Begegnung konnte nach vorherigen Rettungen betroffen sein. Diese drei Zuwächse werden jetzt auf 100 begrenzt; echte Vorratskosten und die Einmaligkeit einer Hilfsbitte bleiben erhalten.

Die gezielte Regression umfasst einen aus JSON wiederhergestellten hohen Vertrauensstand, die tatsächlich bezahlte Hilfe, die erste Berufslehre, die erste Begegnung mit Aurelia und abgewiesene Wiederholungen. Gegen die unveränderte Ausgangsdatei scheiterten sechs dieser Prüfungen; mit der Korrektur besteht `village_life_test.gd` **167 Prüfungen ohne Fehler**. Ebenfalls erneut ausgeführt: Dorfmodell **227**, Domain **329**, Dorfwirtschaft **189** und Frontier-Geschichte **308** Prüfungen, jeweils ohne Fehler; insgesamt **1.220 bestandene Prüfungen** mit getrennten temporären Benutzerverzeichnissen.

Die Speichermigration 1–5 wurde erneut geprüft. Sie erhält frühere Karrieren, Befehlskennungen und die ursprünglichen Dateiinhalte; die neue Dorfphase wird alten Karrieren nicht rückwirkend auferlegt. Eine weiterhin bestehende Grenze des älteren Hauptmodells ist das Protokoll von höchstens 1.024 erfolgreichen Befehlen mit Kennung: Ist es voll, werden neue gekennzeichnete Befehle abgewiesen. Diese Grenze ist vor einer längeren frei fortgesetzten Kampagne zu überarbeiten. Die vorliegenden Prüfungen belegen keine unbegrenzte Spielzeit und keine Android-Bildrate.
