# Römische Ämter und Zuständigkeiten

Der Katalog beschreibt 13 Ämter, Stellungen und Sondervollmachten vom Kampagnenbeginn 58 v. Chr. bis zum Ende des im Epochenregister hinterlegten Tiberius-Fensters. Ein Eintrag beschreibt die Amtsform und ihre Zuständigkeit. Ein belegtes Amt kann zu einem bestimmten Zeitpunkt besetzt sein. Der Katalog führt weder Wahlen durch noch trägt er Amtsträger ein.

| Bereich | Amtsform | Verfahren im Spielkatalog |
|---|---|---|
| Aquileia | Dekurion | Aufnahme in den örtlichen Rat |
| Aquileia | Aedilizische Funktion, Quattuorvir | Örtliche Wahl als gekennzeichnete Rekonstruktion |
| Rom | Quästor, Ädil, Volkstribun, Prätor, Konsul | Wahl nach den jeweiligen Verfahren. Die Katalogdaten unterscheiden Republik und frühes Prinzipat. |
| Rom | Senator | Aufnahme als Statusakt nach der jeweiligen Ordnung |
| Rom / Provinzmandat | Prokonsul | Zuweisung eines gesonderten Mandats |
| Rom | Pontifex Maximus | Gesondertes religiöses Besetzungsverfahren |
| Rom | Die Diktaturen Caesars und Augustus als Princeps | Geschützte historische Ereignisse |

## Belege und Modellgrenzen

- Für die sullanische Ordnung belegen Oxford und Cambridge die Abfolge Quästur, Prätur und Konsulat. Die römische Ädilität und das Volkstribunat sind eigene Ämter. Der Katalog macht beide für die Prätur entbehrlich. Polybios liefert für eine frühere Zeit die funktionale Unterscheidung von Konsuln, Senat und Volksversammlung. Die Amtsbeschreibungen fassen gewöhnliche Aufgaben zusammen. Historische Altersgrenzen, Karenzfristen, Ausnahmeregelungen und die Unterscheidung der beiden Ädilitäten brauchen weitere Verfahren. [Oxford Classical Dictionary](https://academic.oup.com/edited-volume/61673/chapter-abstract/548724163) · [Cambridge University Press](https://www.cambridge.org/core/books/rome-and-the-making-of-a-world-state-150-bce20-ce/city-of-rome-scene-of-politics-and-growing-metropolis/6248904FDF5D1A1D83AB182CF5A3101B) · [Polybios, Historien 6.12–16](https://penelope.uchicago.edu/Thayer/E/Roman/Texts/Polybius/6%2A.html)
- Die Quattuorvirn sind für das republikanische Aquileia epigraphisch belegt. Vergleichbare italische Städte kannten lokale Räte, Ädilen und unterschiedliche Amtskollegien. Die *Tabula Heracleensis* trägt nur begrenzt zur Rekonstruktion von Aquileias eigener Verfassung bei. Herkunfts- und Zulassungsregeln bleiben als örtliche Rekonstruktion ausgewiesen. Valdoras Gemeinwesen braucht eine eigene, fiktionale Ordnung. [Marina Chiabà, Universität Triest](https://arts.units.it/handle/11368/2912467) · [Cambridge, The Italian Curial Councils](https://www.cambridge.org/core/services/aop-cambridge-core/content/view/FAF49065CAEC9DA310BE4BE3C2B55774/9781009496964c06_107-121.pdf/the-italian-curial-councils.pdf) · [Oxford Classical Dictionary, lex Iulia municipalis](https://academic.oup.com/edited-volume/61673/chapter-abstract/550529649)
- Augustus’ Ehrenname ist ab dem 16. Januar 27 v. Chr. über das bestehende Epochenregister sichtbar. Der Eintrag nennt gesonderte Vollmachten und ihre Entwicklung, insbesondere 23 v. Chr. Die Stellung endet für diesen Eintrag mit dem 19. August 14 n. Chr. Die gewöhnlichen Magistraturen laufen weiter. Tacitus berichtet von der Verlagerung der Wahlen in den Senat unter Tiberius. Die republikanischen Diktaturen Caesars kennzeichnet das Register mit einem gemeinsamen Erzählfenster. [Res Gestae 34](https://penelope.uchicago.edu/Thayer/E/Roman/Texts/Augustus/Res_Gestae/6%2A.html#34) · [Cambridge Ancient History](https://www.cambridge.org/core/books/abs/the-cambridge-ancient-history/augustus-power-authority-achievement/442B55852429098188A81FE9870DB062) · [Tacitus, Annalen 1.15](https://www.perseus.tufts.edu/hopper/text?doc=Tac.%20Ann.%201.15)
- Der Prokonsulat braucht ein konkretes Mandat und eine zuständige Instanz. Die Prätur dient in der ersten Prüfung als regulärer Zugang. Die Pontifikats-Stelle ist eine selbständige religiöse Besetzung. Augustus beschreibt die Übernahme des Amtes nach dem Tod seines Vorgängers in seiner eigenen Rechenschaftsschrift. [Cambridge, Proconsuls](https://www.cambridge.org/core/books/abs/proconsuls/roman-origins/50265CF797EB1F23F3B8CAB4855EFFF2) · [Res Gestae 10](https://penelope.uchicago.edu/Thayer/E/Roman/Texts/Augustus/Res_Gestae/2%2A.html#10)

## Vertrag für die Integration

- `get_office(id, jdn)` gibt die am Tag sichtbare Form mit Zuständigkeit, Verfahren, Belegstatus und Quellen zurück. `available(jdn, scope)` liefert die sichtbaren Formen für `rome` oder `municipal`. Ein leerer Scope liefert beide.
- `candidacy(id, jdn, person, jurisdiction)` liefert `eligible`, `reasons`, `missing_offices` und den Katalogeintrag. Der Aufrufer bezieht Geburtsdatum, Todesdatum, Bürgerschaft, Geschlecht, gegebenenfalls Plebejerstand, lokale Mitgliedschaft und bisherige Ämter aus dem autoritativen Weltzustand. Die Ortskennung für kommunale Vorprüfungen ist `aquileia`, die für römische Staatsämter `rome`.
- Die Vorprüfung verwendet 18 Jahre als Kampagnenuntergrenze. Das ist eine Spielregel für den Einstieg und lässt die historischen Mindestalter offen. Eine erfolgreiche Vorprüfung erlaubt dem Aufrufer die weiteren Prüfungen, etwa auf einen freien Sitz, die buchhalterischen und politischen Voraussetzungen, ein gültiges Mandat oder eine Entscheidung des zuständigen Gremiums.
- Der Katalog ist schreibgeschützt. Wahl, Aufnahme, Ernennung, Amtsbesitz und historische Divergenz benötigen eigene autoritative Befehle und Weltzustand. Dieses Modul legt keine Ämter in einem Spielstand ab.

```sh
godot --headless --path prototype --script res://tests/political_offices_test.gd
```
