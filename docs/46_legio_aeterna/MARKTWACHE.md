# Der Wachzug auf der Marktstraße

Der Stadtmarkt ist über den gewöhnlichen Valdora-Spielstand erreichbar. Zwischen 6 und 19 Uhr patrouilliert dort ein römischer Wachführer mit bis zu fünf Soldaten. Sie gehen in einer zweireihigen Kolonne über das Straßennetz beim Markt. Ein vorbeigehender Spieler kann seinen Weg fortsetzen. Wer den Zug länger behindert, hört eine Aufforderung, Platz zu machen. Bei engem Kontakt kann die Wache den Spieler seitlich abdrängen.

Anhaltende Behinderung oder nahes Hinterherlaufen nach der Verwarnung lässt die Gruppe anhalten. Der Wachführer geht auf den Spieler zu. Der Spieler kann Platz machen, weggehen oder widersprechen. Ein Wortwechsel kostet zwei Punkte lokales Ansehen. Erwachsene können sich anschließend bewusst widersetzen. Das kurze Handgemenge lässt sich durch Abstand oder Deckung ohne Gesundheitsschaden überstehen. Der Wachführer kehrt zu Fuß an seinen Platz zurück. Die kreative Begegnung ergänzt die Stadt und respektiert die geschützte Überfallsequenz.

## Anbindung

- `city_watch.gd` leitet sechs stabile Personen mit Kultur, Herkunft, Alter und Aussehensmerkmalen aus `SoldierRoster`, dem gemeinsamen Truppenkatalog und dem Spielstand ab. Der Personenindex verwendet deren Soldaten-UIDs. Die Jahrgänge altern nach dem Kampagnenkalender. Mit dem Ausscheiden des Wachführers endet der Einsatz dieser Gruppe.
- `city_watch_patrol.gd` nutzt die Straßen des Stadtbetriebs, die Kolonnenplätze aus `FormationSlots`, die vorhandenen Soldatenmodelle und physische Kapseln. Beim Ansprechen berücksichtigt der Wachführer Kameradengeometrie und Sicht. Die Soldaten wechseln ihre Darstellungsstufe mit Abstand und Grafikprofil. Oberkörperkontakt, Reichweite und Deckungszeitfenster stammen aus dem laufenden Spiel.
- `CityExploration` stellt dem gemeinsamen `WorldModel` für die Dauer des Besuchs eine Beobachtung zur Verfügung. Antworten sind über die Schaltflächen der Ansprache möglich. Position, Anwesenheit, Alter, aktueller Gesprächsschritt und ein eventuelles Trefferfenster werden geprüft. Erfolgreiche Schritte aktualisieren den gewöhnlichen Kampagnenzustand. Das optionale Wachbuch unter `world_state.politics.street_watch` speichert das Datum, die letzte Antwort und die kumulierten Vorfälle. Ein Vorfall pro Tag begrenzt erneute Buchungen. Ein offenes Gespräch endet beim Verlassen des Besuchs.

## Geprüft

Godot 4.7.2, Linux, Physik mit 60 Schritten je Spielsekunde. Der Test startet je einen echten Stadtbesuch mit einem zwölfjährigen und einem über die Kampagnenuhr gealterten 18-jährigen Spieler. Der Kindertest folgt nach der ersten Verwarnung länger als zwei Sekunden hinter dem Zug. Der Erwachsenentest behindert ihn weiter und wählt nach dem Wortwechsel das Handgemenge. Das Testskript platziert und steuert den Spieler für die Begegnung. Die Soldaten führen ihre Bewegungen selbst aus.

| Messung | Kind, 58 v. Chr. | Erwachsener, 106 n. Chr. |
| --- | ---: | ---: |
| Physisch sichtbare Soldaten | 6 | 6 |
| Straßenrunde | 161,04 m | 161,04 m |
| Marsch über 75 Physikschritte | 1,688 m | 1,688 m |
| Größter physischer Einzelschritt | 0,0313 m | 0,0313 m |
| Weg des Wachführers bis zur Ansprache, Luftlinie | 1,611 m | 1,609 m |
| Laufzeit dieser 75 Schritte, Linux headless, ein Lauf | 301,4 ms | 88,4 ms |

Der Stadttest bestand 46 Prüfungen headless und 49 beim Renderlauf einschließlich drei Bildern. Im bestehenden Politiktest bestanden 40 Prüfungen. Die Desktop-Laufzeiten umfassen die Stadtszene und die parallel laufenden Prozesse. Die Leistung auf dem Galaxy Z Fold7 ist damit offen.

```sh
godot --headless --path prototype --fixed-fps 60 -s res://tests/city_watch_test.gd
godot --headless --path prototype -s res://tests/valdora_politics_test.gd
godot --path prototype --rendering-method gl_compatibility --audio-driver Dummy --fixed-fps 60 -s res://tests/city_watch_test.gd -- --capture-dir="$PWD/docs/46_legio_aeterna/evidence"
```

Die drei Godot-Aufnahmen verwenden die laufende Stadt, geänderte Kamerastandorte und den Linux-Kompatibilitätsrenderer. Für das Marschbild blendet der Aufnahmelauf die Bedienoberfläche aus. Der Kinderspielstand verwendete bei diesem Lauf das vom HUD ausgewiesene Ersatzmodell. Beim erwachsenen Durchlauf kam die vorhandene spätere Italien-Kampagne zum Einsatz. Eine vollständige Legion, Marschverkehr zwischen allen Städten und ein freier Mehrgegnerkampf gehören weiterhin zum Ausbau.

[Marsch auf der Marktstraße](evidence/marktwache-marsch.webp) · [Streit im Kinderspielstand](evidence/marktwache-streit.webp) · [Erwachsener widersetzt sich](evidence/marktwache-handgemenge.webp)
