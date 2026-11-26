# Legio Aeterna im Kampagnenstand

## Der erste gemeinsame Weg

Valdora beginnt am 1. Mai 58 v. Chr. In I-03 begegnet die zwölfjährige Hauptfigur Marcus über den gewöhnlichen Missionsablauf. Nach der Begegnung bietet das Ortsgespräch eine persönliche Einladung an. Silvanus kann die Familie aus eigenem Entschluss begleiten. Im Gefolge lassen sich etwa Marcus als Wegkundiger und Silvanus als Träger einteilen. Für I-04 zählt die tatsächliche Anwesenheit am Arbeitsort. Die Schmiedetafel lässt sich vor der Übergabe im Inventar lesen.

Das Gefährtenrad ist aus dem laufenden Spiel erreichbar. Ein Tipp wählt die Person, ihre Reisegruppe oder alle verfügbaren Gefährten. Warten, Folgen, Helfen und Heimkehren verändern den Bewegungsauftrag. Für die beaufsichtigte Übung treffen sich die Beteiligten am Übungspfahl. Unterbrechung und Speichern erhalten die bereits dort verbrachte Übungszeit. Einzelne Aufträge lassen sich auch allein erledigen. [Gefährtenabnahme](GEFAEHRTEN_ABNAHME.md) · [Figuren und Missionsgegenstände](FIGUREN_UND_SCHRIFTSTUECKE.md)

## Zuständigkeiten und Speicherformat

| Bereich | Eigentümer und Vertrag |
| --- | --- |
| Personen | Der PersonRegistry-Namensraum verbindet Story, Dorf, regionale Wachleute, Marktwache und benannte Soldaten. Der regionale Jugendfreund behält die ID `pc:companion`. Lokale Einwohner verwenden `vil:<id>`. Die Dorfwirtschaft besitzt ihren Gesundheitswert, Aufenthaltsbeobachtungen kommen von den tatsächlich bewegten Körpern. Soldaten behalten ihre Roster-UID beim Wechsel der Darstellung. |
| Mitgliedschaft und Arbeit | `world_state.party.members` verwendet die Person als Schlüssel. Vertrag, persönliche Besitztümer, Erfahrung und Erinnerungen bleiben bei der Person. Status, Reiseauftrag und Stellvertretung legen fest, wer gerade mitkommt. Eine Entlassung beendet die Mitgliedschaft. Bei einem erneuten Eintritt wird derselbe Datensatz verwendet. |
| Befehle | Alle schreibenden Befehle gehen durch `WorldModel.execute`. Ein Transaktionskandidat wird vollständig geprüft und erst bei Erfolg übernommen. Aufrufer können bei Wiederholungen die gleiche Befehls-ID und Nutzlast senden. Der gespeicherte Beleg verhindert eine zweite Ausführung. |
| Versorgung | Getreide wird bei der Übergabe aus dem bestehenden Vorrat abgebucht. Essen und Wasser vom Markt kommen aus persönlich erworbenem Inventar. Getragene und verzehrte Einheiten bleiben in der Warenbilanz nachweisbar. Auf der regionalen Reise beeinflusst Wassermangel die Gruppe. Löhne stammen aus der gemeinsamen Kasse. Das gemeinsame Kalenderdatum löst die Versorgung aus, auch bei mehrtägigen Übergängen. |
| Missionen | Gruppenrollen ergänzen die vorhandenen Missionsdateien. Eine abgeschlossene Aktion und eine passende Person am Missionsort lösen das Ereignis aus. Tod, Warten und Abwesenheit bleiben wirksam. Der I-10-Angriff und die Todesfälle der Folgehandlungen haben Vorrang. |
| Karriere | Nach dem in I-14 verdienten Schwur öffnet das Gefolgschaftsfenster die Wahl zwischen Zivilleben und Ausbildung. Der Zeitsprung verwendet den bestehenden Kalender. Eine spätere Einschreibung wechselt die Rolle im selben erwachsenen Spielstand. Militärische Delegation, Gefolgschaft und politisches Bekenntnis haben eigene Voraussetzungen. |
| Politik | `world_state.allegiance` speichert datierte Entscheidungen. Delegationen belasten das Getreidekonto und schreiben Lieferungen und Vertrauen in die bestehende Stammeswelt. Die freie Gefolgschaft braucht eine persönlich anwesende Unterstützerin oder einen Unterstützer. Freiwillige und Vertragspartner reagieren nach ihren Bindungen. Neue römische Kommandos erfordern eine gültige Befugnis. |
| 3D, Stadt und Karte | Gefährten nutzen die bereits bestehenden Dorfkörper. Beim Übergang auf den Markt begleitet dieselbe Figur den Spieler. Der Stadtplan verwendet denselben Straßengraphen wie die Stadtbewohner. Für das Dorf stammt die Routenkarte aus der begehbaren Kollision. Die Frachtstraße und der Handelshalt verwenden das bestehende Sektor-Streaming. |
| Gefecht | Der vorhandene Truppenkatalog und das BattleModel bestimmen die Aufstellung. Der Erwachsenenversuch läuft getrennt vom Kampagnenspeicher. Im Feld gelten Rolle, Ernennung und Ausrüstung. Eine Messreihe für 16 bis 1.024 individuelle Identitäten ist beim Militärbericht hinterlegt. |

Das äußere Speicherformat bleibt bei Version 6. Der verschachtelte Weltzustand verwendet Version 3. Beim Laden älterer Dateien werden die frühere Gefährtenentscheidung und bereits erfolgte Rekrutierungen übernommen. Die bisherige Dreiergrenze wurde durch die Verfügbarkeit tatsächlicher Personen und vorhandener Mittel ersetzt. Bereits getroffene Handlungsentscheidungen bleiben in ihren ursprünglichen Feldern. [Militär und Messwerte](MILITAER.md) · [Historischer Atlas](ATLAS_58.md)

## Laufende 3D-Welt

Weidenhof, die römische Marktstadt, der Aufmarsch und die übergebbaren Gegenstände sind in der Engine verfügbar. Der Branch enthält neben den neuen Blender-Exporten auch die zuvor separat erzeugten Stadt- und Kollisionsdateien. Die zugehörigen Generatoren bleiben im Repository. Ein frischer Godot-Import kann deshalb den Markt für die Kampagnenreise laden. Der Originaljunge und seine zivilen Bewegungen werden mit dem bereits vorhandenen Projektverfahren für den Export bereitgestellt. Die Stadt blendet Gebäude anhand des Kampagnendatums frei. [Reise und Karte](REISEWEGE.md) · [Marktwache](MARKTWACHE.md)

## Abgrenzung des Entwicklungsstands

Die Missionschronik erfasst vier Bände und 113 Abschnitte. Die ausführbaren gemeinsamen Aufgaben, die geschützte Nacht und der Übergang nach I-14 sind enger begrenzt. Das regionale Terrain umfasst weitere geplante Ziele. Eigene Staaten mit flächendeckender Territorialverwaltung, mehrere persistent finanzierte Großheere, eine vollständige Ausrüstungs- und Ausbildungslaufbahn für jede Kultur sowie die thermische und grafische Prüfung auf einem physischen Galaxy Z Fold7 bleiben offen.
