# Freie Teststadt und spätere Lebenswege

## Aktuelle Entscheidung

Die erste Runde ist eine frei erkundbare Teststadt mit dem vorhandenen Objektbestand. Sie startet ohne Mission und verändert weder Alter noch Karriere noch den Spielstand der bestehenden Geschichte. Unterschiedliche Bauzeiten dürfen hier nebeneinander stehen. Gebäude werden in Metern zur etwa 1,50 m großen Ausgangsfigur geprüft.

Die vier vorhandenen Geschichtenbücher bleiben erhalten. Die spätere Kampagne soll das persönliche Leben vom Dorf bis zur Herrschaft erzählen. Erst ein bestätigtes Kaiseramt eröffnet die Weltkampagne; ein militärischer Beruf allein genügt nicht. Siege, Niederlagen und Kommandos sind mögliche spätere Storyereignisse, hier noch keine implementierten Aufstiegsmissionen.

Bauer, Händler und andere zivile Wege bleiben spielbare Lebensläufe. Der Spieler darf die offene Welt weiterführen und später ein tatsächlich angebotenes anderes Handwerk oder den Soldatenweg aufnehmen. Ein freiwilliger Neubeginn verwendet einen weiteren Spielstand. Eine Berufsentscheidung löscht niemals das bisherige Leben.

## Historische Zeit und Bauwerke

Der bestehende frische Dorfstart liegt 58 v. Chr.; die Figur ist zwölf. Der aktuelle Prototyp enthält außerdem ältere Spielstände und ein älteres Weltmodell. Die Teststadt ist davon getrennt.

| Ereignis | Datum | Alter derselben Figur bei lückenlosem Kalender |
| --- | --- | ---: |
| Ausgangspunkt der bestehenden Kindheit | 58 v. Chr. | 12 |
| Sechs Jahre später | 52 v. Chr. | 18 |
| Ermordung Caesars | 44 v. Chr. | 26 |
| Beginn der Herrschaftsordnung unter Augustus | 27 v. Chr. | 43 |
| Einweihung des Kolosseums | 80 n. Chr. | 149 |

Zwischen 1 v. Chr. und 1 n. Chr. liegt ein Jahr; es gibt hier kein Jahr null. Ein natürliches einzelnes Leben kann daher nicht zugleich diesen Kindheitsbeginn und die Einweihung des Kolosseums umfassen. Für die spätere historische Erzählung braucht es datierte Kapitel, passende Gebäudezustände und gegebenenfalls eine ausdrücklich als Generationenfortsetzung gestaltete Nachfolge. Ein anderer Storyzeitpunkt oder eine alternative Geschichte bleibt eine bewusste spätere Autorenentscheidung. Die Sandbox darf schon jetzt alle gewünschten Epochen zum Prüfen zeigen.

Primärquellen zur Einordnung:

- Parco archeologico del Colosseo, Bauwerk: https://colosseo.it/en/area/the-colosseum/
- Parco archeologico del Colosseo, Einweihungsinschrift von 80 n. Chr.: https://colosseo.it/en/event/stories-from-the-colosseum-epigraphy-lessons-the-lampadius-inscription/
- Metropolitan Museum of Art, Republik und Caesar: https://www.metmuseum.org/essays/the-roman-republic
- Metropolitan Museum of Art, frühe Kaiserzeit ab 27 v. Chr.: https://www.metmuseum.org/essays/the-roman-empire-27-b-c-393-a-d

## Konkreter Code und Grenzen

`prototype/scripts/story/life_path_policy.gd` ist eine isolierte, optional anschließbare Regelkomponente. Sie erzeugt einen serialisierbaren Lebenswegzustand, prüft vorhandene Berufsangebote, schützt die Kontinuität des Spielstands und beschränkt die Weltkampagne auf das von außen bestätigte Kaiseramt. Ein Amtsverlust fällt in die offene Welt zurück. Die Komponente enthält außerdem die historische Jahresrechnung und einen einfachen Datumsfilter für Gebäude.

Sie ändert das bestehende Schema-5-Weltmodell nicht automatisch. Vor einer Integration sind echte Autoritätsereignisse, eine Spielstandmigration und die Benutzeroberfläche erforderlich. Der bestehende Strategiepfad wird durch diese Datei noch nicht umgeschrieben. Weder Kaiseraufstieg noch Händlerquests, Nachfolge oder eine neue Generation werden als bereits fertig implementiert ausgegeben.

Prüfung: `godot --headless --path prototype --script res://tests/life_path_policy_test.gd`. Der Test behandelt Berufswechsel, erhaltene Weltidentität, eigenständige Neustarts, Kaisergrenze und Amtsverlust, Sandbox-Trennung, JSON-Speicherung sowie historische Kalendergrenzen. Die jeweilige tatsächliche Ausführung wird im Übergabebericht vermerkt.
