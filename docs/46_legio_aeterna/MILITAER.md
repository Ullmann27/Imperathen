# Erwachsene im Talgefecht

Im Hauptmenü öffnet **Talgefecht erproben** die Übung. In der angehaltenen Aufstellung stehen im **Aufgebot** drei konkret besetzte Kontingente bereit. Vier haeduische Reiter kosten 20 Denare, vier Rationen, vier Dienstpferde und vier Futterportionen. Die Ortswehr kostet zehn Denare und fünf Rationen. Von 30 Übungsdenaren bleiben nach beiden Verpflichtungen null. Diese Preise, Liefermengen und Personennamen sind Spielrekonstruktionen.

Jeder angenommene Vertrag erzeugt einmalig die namentliche Musterliste im bestehenden BattleModel. Die Musterrolle zeigt Sollstärke, verfügbare Personen, Verwundete, Gefallene, Ausbildung und den aktuell verantwortlichen Offizier. Ist ein Offizier ausgefallen, übernimmt die vorhandene Stellvertretung nach den Gefechtsregeln. Ein geflohener Verband kann Personal besitzen und zugleich keine einsatzbereiten Soldaten melden.

Über die Verbandskarte, **Bewegung**, **Formation** und **Kampf** erhält ein Kontingent Befehle. Aufsteigen und Absitzen sind nur für ausgebildete Reiter im Halt verfügbar. Ein abgesessener Reiter führt sein Pferd mit. Eine Formation kann nur mit geeigneter Ausrüstung und Ausbildung errichtet werden. Das Schilddach setzt zudem einen in der Gefechtsepoche verfügbaren Truppentyp in römischem Dienst voraus.

## Kampagne und Zuständigkeit

Im regulären Dorf führt der bisherige Karrierevertrag nach der Erwachsenenausbildung, der Rekrutierung von Wachleuten und der verteidigten Siedlung zur einsatzbezogenen Unterstellung der **Passwache**. Das Recht wird auf der taktischen Karte bei jedem Eintritt aus Alter, Rolle, Dienststand und überlebendem Wachpersonal abgeleitet. Die überregionale Fußtruppe und die Bogenschützen haben eigene Befehlshaber. Die Kindheitsbegleitung in Valdora erteilt keine militärische Ernennung.

PersonRegistry.patrol_uid erhält die Identität eines Dorfbewohners beim Wachwechsel. Die Darstellung gleicht Mitglieder anhand ihrer UID ab und entfernt bei Verlust genau den betroffenen Akteur. Der separate Feldverband bezieht Stammrolle, Ausrüstung, Beziehungen und Dienstgeschichte aus SoldierRoster und TroopCatalog. Die Unterkunftsgruppe, Centurie, Kohorte, Legion, Hilfskontingente und das germanische Gefolge sind im selben Epochenkatalog verzeichnet. Die acht Organisationsdatensätze dienen der Einordnung und der Musterrolle. Die steuerbare Hierarchie im Tal umfasst Heer, Gefechtsgruppe und Kontingent.

Die Übung ist eine explizite BattleModel-Szenariovariante. Ihre Szenario-ID verweist auf die sortierten angenommenen Verträge. Bei der Wiederherstellung werden Verfügbarkeit, Depot und Personendaten überprüft. WorldModel.checkpoint_valley nimmt nur registrierte Kampagnenszenarien an. Das Übungsdepot belastet die Kampagnenwirtschaft nicht. Ein Neustart der Übung im Hauptmenü beginnt eine neue Aufstellung.

## Identitätsgleiche Darstellung und Messung

Die Erwachsenenübung verwendet die Formationsagenten aus PR #112 mit der Slotstruktur des integrierten BattleModel. Die Spielregeln bleiben für Moral, Verlust und Erfahrung zuständig. Nahansicht und mittlere Distanz interpolieren dieselben individuellen Agenten mit räumlich indizierter Nachbarschaft. Jenseits des Detailbudgets folgen Personen dem Verband mit begrenzter Geschwindigkeit. Der Übergang erhält UID und Ausrüstung. Pferd und Reiter teilen die Bewegung, der Sitz folgt dem Skelettsockel des vorhandenen Valdora-Pferdes. Entfernte Reiter werden am Verbandszeichen gezählt.

Der CPU-Messlauf erzeugte je Stufe 16, 64, 256, 512 und 1.024 Identitäten und simulierte 300 Agententicks. Die Zeitmessung umfasst das Fortschalten der Formationsagenten im laufenden Gefecht. Sie schließt Bildausgabe und Rechenzeit des übergeordneten BattleModel aus. Auf diesem AMD EPYC 9V74 mit Godot 4.7.2 ergaben sich folgende Zeiten in Millisekunden je Agententick für die gesamte Gruppe.

| Personen | Stufe B Mittel / P95 | Stufe C Mittel / P95 |
| ---: | ---: | ---: |
| 16 | 0,54 / 0,55 | 0,16 / 0,31 |
| 64 | 1,73 / 2,54 | 0,54 / 0,96 |
| 256 | 7,96 / 11,01 | 2,81 / 5,37 |
| 512 | 16,97 / 23,85 | 4,75 / 9,13 |
| 1.024 | 39,00 / 68,19 | 11,25 / 25,94 |

1.024 vollständige B-Agenten überschreiten bereits im Mittel das 33,3-ms-Budget bei 30 Hz. Die Ebene C reduziert in diesem Lastfall die mittlere Agentenzeit um etwa 71 Prozent. Ein Test auf dem Galaxy Z Fold7 und ein Vergleich einschließlich Grafik und BattleModel bleiben offen. [Messdaten](evidence/formation-benchmark.json)

## Prüfabläufe

Vom Repository-Wurzelverzeichnis aus laufen die Godot-Prüfungen mit:

```sh
godot --headless --path prototype --script res://tests/valley_muster_test.gd
godot --headless --path prototype --script res://tests/formation_scale_benchmark.gd -- /tmp/imperathen-formation.json
godot --headless --path prototype --script res://tests/battle_command_test.gd
godot --headless --path prototype --script res://tests/battle_rules_test.gd
godot --headless --path prototype --script res://tests/troop_catalog_test.gd
godot --headless --path prototype --script res://tests/soldier_gait_test.gd
godot --headless --path prototype --script res://tests/valley_orders_test.gd
```

Mit einem Grafiktreiber und Ausgabeverzeichnis nach `--` zeichnet `valley_muster_test.gd` das tatsächliche Aufgebot sowie den gemeinsamen Einsatz der Reiter und Fußtruppe auf. Der Test prüft zwei abgeschlossene Angriffsaktionen am selben Ziel, Ausrüstungsverschleiß, Übergänge zwischen Detailstufen und Wiederherstellung der identischen Stammrolle. Der Lauf im Headless-Modus ergab 36 bestandene Prüfungen. In den vorhandenen Suiten bestanden 413 Befehls-, 145 Gefechtsregel-, 232 Katalog-, 125 Gangbild- sowie 28 HUD-Prüfungen.

## Historische Einordnung und offene Umsetzung

Caesar beschreibt im ersten Buch Reiter aus der Provinz, von den Haeduern und von deren Verbündeten. Die Passagen 1,15 und 1,18 wurden im lateinischen Text überprüft. 1,48 und 4,2 berichten über Reiter und Fußbegleiter beziehungsweise das Absitzen. In 7,65 und 7,80 werden rechtsrheinische Reiter im Feldzug von 52 v. Chr. genannt. Daher ist dieser römische Dienstvertrag im Jahr 58 v. Chr. gesperrt. Unsere Reiterfiguren und ihre individuellen Familien sind fiktiv. [Caesar, De bello Gallico](https://github.com/PerseusDL/canonical-latinLit/blob/master/data/phi0448/phi001/phi0448.phi001.perseus-lat2.xml)

Bürgerkrieg 3,88–89 nennt unterschiedliche reale Mannschaftsstärken für Kohorten im Feld. Für die frühe Kaiserzeit enthält der Stärkebericht der ersten Tungrerkohorte 752 Personen auf der Liste und 265 Gesunde am Standort. Beide Quellen begründen die Trennung von Sollstärke, Anwesenheit und Einsatzfähigkeit. Die Datierung im Katalog beschreibt die freigegebenen Spielabschnitte. [Caesar, De bello civili](https://github.com/PerseusDL/canonical-latinLit/blob/master/data/phi0448/phi002/phi0448.phi002.perseus-lat2.xml) · [Vindolanda-Tafel 154](https://romaninscriptionsofbritain.org/inscriptions/TabVindol154)

Die vollständige Übernahme der individuellen Kontakt- und Nahkampfsteuerung aus PR #111 in das laufende Formationsgefecht, dauerhaft finanzierte Mehrheere und eine frei vergebbare militärische Ämterhierarchie sind offen. Der Nachweis dieses Abschnitts umfasst die spielbare Erwachsenenübung, die begrenzte Kampagnendelegation und die angegebenen Messläufe.
