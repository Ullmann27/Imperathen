# Der Südweg von Valdora

Decimus, der fiktive und bereits im Dorf vorhandene Verwalter, bittet um Hilfe am ausgewaschenen Südweg. Nach I‑01 und einer persönlichen Vorstellung kann die Hauptfigur eine von zwei Antworten wählen. Sie kann den Südweg begutachten und Decimus einen Bericht bringen oder vier Holz für die Arbeiten geben. Der Bericht setzt den tatsächlichen Besuch der Stelle voraus. Die Spende wird vom vorhandenen Holzvorrat und im Dorfbuch erfasst.

Decimus spricht eine einmalige persönliche Empfehlung aus. Ein Bericht stärkt seinen Respekt, die Spende sein Vertrauen. Die Beziehung, die Empfehlung und ihre Herkunft ergeben sich aus derselben Ereignisfolge. Ab achtzehn Jahren kann die Hauptfigur damit bei anwesendem Decimus um eine Audienz bitten. Diese Möglichkeit steht sowohl zivilen als auch militärischen Lebenswegen offen. Die Audienz ist ein persönliches Gespräch über den Ort.

## Spielschnittstelle

`WorldModel.politics_view()` liest die aktuelle Verfügbarkeit, den Punkt für die Besichtigung, die Beziehung und die Empfehlung. `survey_pending` beschreibt die Relevanz der Besichtigung. Die Nähe zur Stelle prüft das Weltmodell beim tatsächlichen Befehl erneut. Die übrigen Optionen liefern Label, Befehl, Parameter und Ablehnungsgrund.

- `politics_survey` am Südweg bei `Vector2(0, 17)`.
- `politics_help {"route":"road"}` bei Decimus nach der Besichtigung.
- `politics_help {"route":"wood"}` bei Decimus mit vier Holz im Vorrat.
- `politics_audience` bei Decimus ab achtzehn Jahren mit seiner Empfehlung.

Die Ereignisse liegen in `world_state.politics.events` als eindeutige Ortsereignisse mit Weltkalendertag und Uhrzeit. Die Chronik zeigt das Tagesdatum der gemeinsamen Weltuhr. Ein alter v6-Spielstand erhält das Subschema mit leeren politischen Ereignissen. Eine vorhandene Bekanntschaft, eine frühere Entscheidung oder ein alter Geld- und Güterbestand bleibt beim Laden erhalten.

## Domänenprüfung

```sh
godot --headless --path prototype --script res://tests/valdora_politics_test.gd
```

Der Test führt beide Wege durch die normalen Befehle des Weltmodells. Er deckt Alter, falsche Orte, fehlenden Vorrat, Wiederholung, Ereignisreihenfolge, Chronikdatum und das Laden einer aufgezeichneten Kampagnenpartie ab. Die räumliche Bedienung im Spiel wird in einer eigenen Engine-Route geprüft.

## Einbau in Valdora

Decimus behält seine vorhandene Identität und seinen Platz im Dorf. Der Spieler erreicht ihn über die normale Weltinteraktion. Die Beobachtung am Südweg hat einen sichtbaren Ort mit abgesackter Bohle und ausgespülter Auflage. Ein Holzzuschuss macht bereitgelegte Ersatzbohlen sichtbar. Ein Bericht dokumentiert die Schadstelle, ohne Holz auszugeben. Der Fall vermittelt je nach Weg Grundwissen über Versorgung oder schriftliche Beobachtungen und hält Decimus’ Vertrauen und Respekt getrennt fest.

Die Ratstube steht am Dorfplatz. Ihre Tür, Fenster, Möbel und Laufwege stammen aus dem Blender-Modell und seinen separaten Kollisionshüllen. Am Amtstisch liest der Spieler den datierten Ortsvermerk und nach der Hilfe auch seine Empfehlung. Die Tafel zeigt den autoritativen Spielstand. Sie bucht weder Ressourcen noch politische Rechte. Das Schließen der Tafel gibt die Steuerung in derselben Szene zurück. Bei einem fehlgeschlagenen automatischen Speichern nimmt die Anwendung den politischen Befehl zurück.

Die End-to-End-Prüfung lädt den vorhandenen Kampagnenspielstand am Übergang zu I‑02. Beide Varianten nutzen tatsächlich die Bewegungssteuerung, Decimus’ sichtbare Dialogantworten, die gemeinsame Speicherroutine und den realen Weg durch die Tür der Ratstube.

```sh
IMPERATHEN_ISOLATED_TEST=1 godot --headless --path prototype --fixed-fps 60 \
  --script res://tests/political_reference_playthrough.gd
godot --headless --path prototype --script res://tests/political_offices_test.gd
```

Der historisch recherchierte Ämterkatalog ist ein eigener zeitgebundener Datenvertrag. Der örtliche Bürgermeistertitel wird Decimus nicht verliehen. Er bleibt Valdoras fiktiver Verwalter. Eine tatsächlich gewählte Magistratur, institutionelle Senatsabstimmungen und Caesar als animierter Gesprächspartner sind weitere Produktionsschritte. [Historische Ämter und Nachweise](../00_governance/POLITICAL_OFFICES.md)
