# Persönliche Absprachen unterwegs

Am Holzlager in I-04 kann Marcus den Weg zeigen und Silvanus beim Tragen helfen. Nach der Handlung ergreift ein anwesender Gefährte das Wort. Marcus bietet an, den nächsten Gang zu führen. Sein Vater bietet an, schwere Lasten zu übernehmen. Wenn zwei Personen wiederholt beide den Weg vorgeben wollen, kann eine von ihnen künftig die Reise unter der Leitung der anderen ablehnen. Der Spieler kann ihnen weiterhin unterschiedliche Aufgaben anbieten.

Im Gefährtenfenster zeigt **Unterwegs erlebt** das Datum, die miterlebte Aufgabe, die persönliche Rolle und die Beziehungen zu den Mitreisenden. Eine Zustimmung ändert den tatsächlich ausgeführten Begleitauftrag. Eine Absage lässt den bisherigen Auftrag bestehen. Das gilt auch für Aurelias Wunsch, die Hände für Hilfe frei zu halten, und für Varros Wunsch, nach den Hufspuren die Straße zu beobachten. Die Vorschläge sind kreative Spielergänzungen. Die ursprünglichen Missionsentscheidungen bleiben beim Spieler.

## Technischer Vertrag

`CompanionStory.credit` läuft nach einer erfolgreichen Missionshandlung am Ort des autorisierten Schritts. Sie berücksichtigt beobachtete, verfügbare Reisende im Radius von 3,5 Metern, die folgen oder helfen. In der laufenden 3D-Welt prüft die gemeinsame Sichtabfrage zusätzlich freie Strahlen auf Brust- und Augenhöhe zwischen den Beteiligten. Wer eine passende Aufgabe übernommen hat, erhält die bestehende Rollengutschrift. Ein Gesprächspartner am Ziel kann die Übergabe miterleben. Der Empfang der Übergabe verleiht ihm keine zusätzliche Helfergutschrift.

Ein Eintrag in `world_state.party.outings` enthält die bestätigte Schritt-ID, den julianischen Tag, die anwesenden Personen-UIDs mit Rollen und ihre tatsächlich beantworteten Vorschläge. Ein älterer Spielstand ohne Unternehmungen beginnt mit leerer sozialer Vorgeschichte. Beim Laden gelten die erwiesenen Missionsschritte, gültige Rollen und Mitgliedschaften, Datum und Eindeutigkeit. Entlassene und verstorbene Personen bleiben in bereits aufgezeichneten Ereignissen identifizierbar.

`party_conversations.gd` berechnet gerichtete Meinungen aus der Zusammenarbeit und berücksichtigt bestehende Dorffreundschaften. Zwei komplementäre Rollen können mit der Zeit Freundschaft begründen. Wiederholter Wettbewerb um die Führung kann für Marcus oder Varro in Rivalität übergehen. Gemeinsame Arbeit mit getrennten Rollen kann diese Reibung wieder mindern. Die Berechnung verwendet die Dimensionsgrenzen und Einstufungen von `ActorRelations`. Sie beginnt mit einer neuen, nur im Arbeitsspeicher vorhandenen Projektion. Das Stammesregister und die Wirtschaftsbestände bleiben in ihren vorhandenen Zuständigkeiten.

Der Modellbefehl `party_exchange(actor_uid, step, choice)` akzeptiert nur den jüngsten offenen Vorschlag der angesprochenen anwesenden Person. Nähe, aktive Mitgliedschaft, Gesundheit, Gefahr und bereits erfolgte Antworten begrenzen die Ausführung. Beim Tod, einer Entlassung oder einer Ablehnung eines alten Vorschlags entstehen keine neuen Gutschriften.

## Abnahme mit Godot 4.7.2

| Lauf | Ergebnis |
| --- | --- |
| Neue Sozialprüfung mit dem regulären Missionsfortschritt von I-01 bis I-04 | 90 Prüfungen ohne Grafik, 0 Fehler |
| Dieselbe Prüfung mit sichtbarem Gefährtenfenster und Bildexport | 91 Prüfungen, 0 Fehler |
| `party_world_test` mit bewegten Gefährten in der Spielwelt | 76 Prüfungen, 0 Fehler |
| `party_ui_test` mit dem normalen Hauptspiel, Touchsteuerung und Dialogen | 78 Prüfungen, 0 Fehler |
| `world_state_test` mit Schreibgrenzen zwischen temporärer Gefährtenansicht und persistenten Stammesbeziehungen | 217 Prüfungen, 0 Fehler |

Die neue Prüfung setzt als Fixture Spielerpositionen und NPC-Beobachtungen an den Gesprächs- und Arbeitsorten. Die Mission, die Einladungen, das Angebot, die beiden Antworten und die Ablehnung einer Stellvertretung laufen über die regulären Modellbefehle. In einem zweiten Fortgang wird Silvanus entlassen und Varros Tod als Fixture in seinem vorhandenen Dorfbewohner-Datensatz gesetzt. Beide behalten ihre frühere Erinnerung, erhalten anschließend keine neue und erscheinen nach dem Laden im jeweils richtigen Zustand.

```sh
godot --headless --path prototype -s res://tests/party_conversations_test.gd
LEGIO_SOCIAL_FRAME="$PWD/docs/46_legio_aeterna/evidence/gefaehrten-gespraech.webp" godot --path prototype --rendering-method gl_compatibility --audio-driver Dummy --fixed-fps 60 -s res://tests/party_conversations_test.gd
```

[Godot-Aufnahme von Marcus’ tatsächlichem Gefährtenfenster](evidence/gefaehrten-gespraech.webp)
