# Historischer Personenkatalog

Der Katalog ordnet Caesar, Marcus Brutus, Cicero, Pompeius und Octavian ein. Die fünf Identitäten bleiben über Namens- und Amtswechsel stabil. `PoliticalPersons.for_world(id, world)` liest den aktuellen JDN aus `WorldClock`. `at_day(id, jdn)` liefert dieselbe Ansicht für eine Datumsabfrage. Der Katalog ist ein lesender Ausgangspunkt für Chronik, Dialog und Figurenauswahl. Der Spielstand erhält durch die Abfrage keine neuen Einträge.

| ID | Name zu Kampagnenbeginn am 1. Mai 58 v. Chr. | Einordnung am Starttag |
| --- | --- | --- |
| `hist:caesar` | Gaius Julius Caesar | 41, Prokonsul in Gallien und Illyricum |
| `hist:brutus` | Marcus Junius Brutus | 26–27 nach Geburtsannahme um 85 v. Chr. |
| `hist:cicero` | Marcus Tullius Cicero | 48, im Exil |
| `hist:pompeius` | Gnaeus Pompeius Magnus | 47, Bündnis mit Caesar und Crassus |
| `hist:octavian` | Gaius Octavius | 4, später Octavian und Caesar Augustus |

## Datierung und Vertrag

- `birth` und `death` geben die Genauigkeit und ihr Zeitfenster an. Bei Brutus bezeichnet `approximate_year` das wahrscheinliche Geburtsjahr und ergibt eine Altersspanne. Für seinen Tod bei Philippi wird der belegte Monat verwendet. Quellen variieren bei Pompeius' Todestag zwischen dem 28. und 29. September 48 v. Chr.
- `life_status` liefert `not_born`, `birth_window`, `alive`, `death_window` oder `dead`. Erst `alive` gibt Alter und Rollen frei. Beim belegten Todestag gilt der gesamte JDN für Live-Auftritte als gesperrt. Bei einem offenen Todeszeitraum blockiert bereits dessen frühester erfasster Tag die automatische Verwendung als lebende Person. Eine später inszenierte, stundengetreue Todesszene benötigt ihren eigenen Missionszustand.
- `roles` führt ausgewählte Amts-, Ehren- und Kontextrollen. Intervalle schließen den ersten Tag ein und enden vor dem angegebenen Endpunkt. `consular_year` und `year_window` sind zeitlich grobe Zeiträume. `attested_window` gibt eine konservative Teilstrecke der belegten Rolle an. Die Auswahl umfasst beim zweiten Triumvirat die erste Amtsperiode und bei Brutus' Prätur die Zeit vor den Iden. Pompeius' erstes Triumvirat erscheint als politisches Bündnis.
- Für Octavian ist der 1. Juli 44 v. Chr. eine redaktionelle Anzeigegrenze nach den frühesten Belegen der Namensverwendung. Die formale Bestätigung der Adoption folgte 43 v. Chr. Der klar datierte Ehrenname Augustus gilt ab dem 16. Januar 27 v. Chr. [Cassius Dio 46.47](https://penelope.uchicago.edu/Thayer/E/Roman/Texts/Cassius_Dio/46%2A.html) · [Kommentierte Ausgabe des Augustus von Sueton mit Cicero-Belegen](https://brittlebooks.library.illinois.edu/brittlebooks_open/Books2009-06/sueton0001divaug/sueton0001divaug.pdf)
- Alle vorjulianischen Daten sind nominale Angaben im gemeinsamen proleptisch-julianischen Kalender des Spiels. Der Katalog dient der historischen Ausgangslage. Abweichende Lebensverläufe, Begegnungsorte und Familienbeziehungen brauchen ihre eigene geprüfte Domänenintegration.

## Quellen

- `caesar_life` · Konsulat, Provinzkommando, Tod und alternative Tagesangaben zur üblichen Geburt im Juli 100 v. Chr. [Loeb-Einleitung zu Caesar, Bellum Gallicum](https://penelope.uchicago.edu/Thayer/E/Roman/Texts/Caesar/Gallic_War/Introduction%2A.html) · [Livius, Quellen zu Caesar](https://www.livius.org/articles/person/caesar/caesar-12/)
- `caesar_dictatorship` · Der Amtswechsel zur dauerhaften Diktatur liegt zwischen dem 9. und 15. Februar 44 v. Chr. Der Katalog beginnt am späteren Termin. [Epigraphical Notes on Julius Caesar, Journal of Roman Studies](https://www.cambridge.org/core/journals/journal-of-roman-studies/article/abs/epigraphical-notes-on-julius-caesar/A8A86448755560292062D2B61862AAD8)
- `brutus_praetor` und `brutus_philippi` · Wahrscheinliche Geburt 85 v. Chr., Stadtprätur 44, Tod nach der zweiten Schlacht bei Philippi im Oktober 42. [Oxford Classical Dictionary, Marcus Junius Brutus](https://academic.oup.com/edited-volume/61673/chapter-abstract/549651963?login=true) · [Plutarch, Brutus 52–53](https://penelope.uchicago.edu/Thayer/E/Roman/Texts/Plutarch/Lives/Brutus%2A.html) · [Appian, Bürgerkriege 4.125–132](https://www.livius.org/articles/battle/philippi-42-bce/)
- `cicero_chronology`, `cicero_death` und `cicero_exile` · Geburtstag, Konsulat 63, Tod am 7. Dezember 43. Der Exilabschnitt beginnt mit dem dokumentierten Abreisetag in Brundisium und endet mit der Rückberufung. [Dickinson College Commentaries, Chronologie](https://dcc.dickinson.edu/cicero-de-imperio/chronological-table) · [York University, Chronologie Ciceros](https://www.yorku.ca/pswarney/3106/cic-chron.htm) · [Cicero, Ad familiares 14.4](https://www.attalus.org/cicero/adfam14.html) · [Ciceros Briefwechsel, Rückberufung](https://elekpub.bib.uni-wuppertal.de/download/pdf/7554835.pdf)
- `pompeius_chronology` und `pompeius_death` · Geburtstag 106, Konsulate 70 und 55, konkurrierende Lesarten des Todestags 48. [Dickinson College Commentaries, Chronologie](https://dcc.dickinson.edu/cicero-de-imperio/chronological-table) · [Plutarch, Pompeius 79](https://penelope.uchicago.edu/Thayer/E/Roman/Texts/Plutarch/Lives/Pompey%2A.html) · [Dictionary of Greek and Roman Biography and Mythology, Pompeius](https://en.wikisource.org/wiki/Dictionary_of_Greek_and_Roman_Biography_and_Mythology/Pompeius_22.)
- `octavian_name` und `augustan_fasti` · Ciceronische Briefbelege und spätere formale Namensbestätigung. Inschriftliche Fasti für Geburt, ersten Triumviratszeitraum, Verleihung des Ehrennamens und Tod. [Cassius Dio 46.47](https://penelope.uchicago.edu/Thayer/E/Roman/Texts/Cassius_Dio/46%2A.html) · [Fasti in der Sammlung von Ehrenberg und Jones](https://www.attalus.org/docs/ej_fasti.html)

## Test

    godot --headless --path prototype --script res://tests/political_persons_test.gd
