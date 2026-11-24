# Prüfung der Drehbuchquellen für Team C

Stand 24. November 2026. Geprüfte Codebasis `7a21dca`.

**Die Missionskennungen und Titel der verfügbaren Bände 2 bis 4 stimmen mit dem Kampagnenkatalog überein. Die Dialoge sind noch nicht für eine unveränderte Vertonung freigegeben.** Der neue lokale Auditor findet 96 gesprochene Zeilen mit technischen Produktionsbegriffen. Wiederholungen und eine abweichende Altersangabe werden getrennt zur redaktionellen Prüfung gemeldet.

Das Werkzeug verändert weder Drehbuchdateien noch Kampagnenreihenfolge, Spielzustände oder bestehende Saves. Die Original-DOCX und ihre Volltextextraktionen gehören weiterhin nicht in das öffentliche Repository. Der [maschinenlesbare Befund](story_source_audit.json) enthält Prüfsummen, Missionskennungen, Absatzstellen und Erkennungsmerkmale, aber keine Dialogvolltexte.

## Quellen und tatsächlicher Prüfumfang

Die Nummern `P…` zählen sämtliche Absätze in `word/document.xml` in Dokumentreihenfolge, einschließlich Tabellenzellen und leerer Absätze. Sie sind keine Seitenzahlen. Kommentare, Fußnoten, Layout, Audio und Engine-Ausführung sind nicht Gegenstand dieses Audits. Der Vergleich von Missionen umfasst Kennung, Reihenfolge und Titel sowie weitere Metadaten, soweit der bestehende Katalog sie tatsächlich führt. Die Katalogeinträge der Bände 2 bis 4 führen bisher nur Kennung und Titel.

| Band | Aktuell verfügbar | SHA256 der tatsächlich gelesenen DOCX |
| --- | --- | --- |
| 1 Das Feuer von Valdora | Nein | In diesem Lauf nicht neu geprüft |
| 2 Der Adler und der Rubikon | Ja | `6b55e0ca2e0b74354323524408e5188152e1bc8c3ed260d3b3690bb07e1c699f` |
| 3 Die Iden | Ja | `ed597fcb569083e1bc130194003d9ec2a55d8e4f22b28c11fa65d05920ffe3d2` |
| 4 Das Reich danach | Ja | `608ff71e62c70926227a0544582d2ed2cbe415e2630b35df948b9df5a1bf768a` |

Die drei verfügbaren Prüfsummen stimmen mit dem früheren [Quellenprotokoll von AP1 und AP2](../24_ap1_ap2/QUELLENPRUEFUNG.md) überein. Dessen frühere Prüfung von Band 1 ersetzt keinen neuen Zugriff auf die hier fehlende Datei. Auch `IRON_BANNERS_Projektmappe.zip` war in diesem Arbeitslauf nicht verfügbar.

| Gemessener Umfang | Band 2 | Band 3 | Band 4 | Gesamt |
| --- | ---: | ---: | ---: | ---: |
| Hauptmissionen | 25 | 25 | 31 | 81 |
| Nebenquest-Kennungen | 24 | 24 | 24 | 72 |
| Nummerierte Hauptmissionsdialoge | 250 | 250 | 310 | 810 |
| Zeilen mit erkannten Produktionsbegriffen | 33 | 36 | 27 | 96 |
| Szenen mit identischen wiederholten Sprecherzeilen | 24 | 25 | 28 | 77 |
| Zusätzliche identische Zeilenvorkommen innerhalb derselben Szene | 69 | 83 | 98 | 250 |

„Identisch“ bedeutet gleiche Sprecherkennung und gleichen Text nach Unicode- und Leerraumnormalisierung. Die 250 Vorkommen verteilen sich auf 210 Wiederholungsgruppen. Eine wiederholte Frage, ein Refrain oder eine alternative Aufnahme kann sinnvoll sein; deshalb blockiert dieser Befund allein keine Produktion. Über alle 810 nummerierten Zeilen ergeben sich 65 verschiedene Kombinationen aus Sprecher und Wortlaut. Nebenquestdialoge und unnummerierte Äußerungen sind in diesen Dialogzahlen nicht enthalten.

## Konkrete Befunde vor Sprachaufnahme und Inszenierung

| Kennung | Fundstelle | Befund und erforderliche Bearbeitung |
| --- | --- | --- |
| C1-01 | Band 2, II-00, P0292 und P0300; Band 3, III-15, P1638 und P1646 | Spielerzeilen enthalten beispielsweise „persistentem Weltzustand“ beziehungsweise „abstrakte Sympathieleiste“. Solche Produktionsanweisungen müssen vor Aufnahme in tatsächlich gesprochene Handlungssätze überführt werden. Das automatische Gate meldet insgesamt 96 passende Zeilen. |
| C1-02 | Band 2, II-19, P1946 und P1985 bis P2003 | Der Storykern behandelt die Nachricht von Pompeius’ Ermordung. Der anschließende Dialogblock enthält zugleich direkte Sprecherzeilen des Pompeius; eine Rückblende oder andere zeitliche Einordnung ist dort nicht ausgezeichnet. Vor Produktion müssen Szenenzeit, Überbringer der Nachricht und gegebenenfalls eine ausdrücklich getrennte Rückblende geklärt werden. |
| C1-03 | Band 3, III-15, P1595; alle verfügbaren Bände, P0016 | Julias Szene gilt ausdrücklich nur, wenn sie lebt. Die allgemeine Cinematic-Regel verbietet das Wiedererscheinen verstorbener Personen. Die Besetzungslisten allein erfüllen diese Bedingung noch nicht. Beim späteren Szenenanschluss sind Überlebenszustand und passende Alternative gegen den tatsächlichen Save zu prüfen. Dieser Quellenlauf bewertet nicht, ob eine konkrete Runtime bereits dagegen verstößt. |
| C1-04 | Band 4, IV-18, P0145 bis P0146 und P1878; Startregel jeweils P0013 | Für 34 bis 32 v. Chr. steht Alter 34 bis 36. Aus der gemeinsamen Startregel 58 v. Chr. mit zwölf Jahren folgt auf Kalenderjahrebene Alter 36 bis 38. Das ist eine redaktionell zu klärende Abweichung; weder Geburtstagsdatum noch Kalenderänderung werden erfunden. Einzelne ungefähre Altersangaben innerhalb eines Jahresintervalls lösen keinen solchen Befund aus. |
| C1-05 | Band 4, IV-12, P1344 bis P1346 und P1389 ff. | Die Perusia-Szene verwendet nur die Sprecheridentität „Antonius“. Lucius Antonius muss dort von Marcus Antonius getrennt werden. Appian nennt Lucius als Belagerten in Perusia und beschreibt Marcus Antonius’ spätere Kenntnis der Ereignisse nach dem Aufbruch aus Alexandria. Schauspiel, Gesicht, Stimme und Figurenschlüssel dürfen diese Personen nicht vermischen. [Primärquelle: Appian, Bürgerkriege 5.14, 5.32 und 5.52](https://penelope.uchicago.edu/Thayer/E/Roman/Texts/Appian/Civil_Wars/5%2A.html). |
| C1-06 | Band 3, III-04, P0607 bis P0609 und P0652 ff. | Die Besetzung setzt Cicero an die afrikanische Küste. Für diese körperliche Anwesenheit liegt in der geprüften Stelle kein Nachweis vor. Plutarch beschreibt seine Rückkehr nach Brundisium und das Warten auf Caesar nach Pharsalos. Vor einer historischen Freigabe ist der Aufenthaltsort gesondert zu belegen oder die Nachricht als übermittelter Brief beziehungsweise zeitlich getrenntes Gespräch zu inszenieren. Die vorgeschlagenen Varianten sind keine stillschweigende Kanonänderung. [Primärquelle: Plutarch, Cicero 39](https://penelope.uchicago.edu/Thayer/E/Roman/Texts/Plutarch/Lives/Cicero%2A.html). |

Diese Fundstellen sind ein begrenzter Quellenabgleich. Die 81 Hauptmissionen sind damit weder vollständig historisch geprüft noch vollständig geschrieben, vertont oder in der Engine produziert. Insbesondere prüft der Auditor keine historischen Aufenthaltsorte, Todeszeitpunkte, impliziten Rückblenden oder die Qualität eines Dialogs; C1-02, C1-03, C1-05 und C1-06 stammen aus gezieltem Lesen und Quellenabgleich.

## Reproduzierbarer lokaler Audit

Das Werkzeug [audit_screenplays.py](../../tools/story/audit_screenplays.py) arbeitet mit Python 3.10 oder neuer und der Standardbibliothek. `STORY_SOURCE_DIR` bezeichnet das Verzeichnis mit den hier aufgeführten lokalen Dateikopien. Andere Dateinamen sind erlaubt; Identität und Band werden aus Inhalt und Prüfsumme ermittelt.

```bash
python3 tools/story/audit_screenplays.py \
  --report /tmp/imperathen-story-audit.json \
  "$STORY_SOURCE_DIR/02-IMPERATHEN_Drehbuch_Band_2_DER_ADLER_UND_DER_RUBIKON-1-.docx" \
  "$STORY_SOURCE_DIR/04-IMPERATHEN_Drehbuch_Band_3_DIE_IDEN-1-.docx" \
  "$STORY_SOURCE_DIR/05-IMPERATHEN_Drehbuch_Band_4_DAS_REICH_DANACH-1-.docx"
```

Der tatsächlich ausgeführte Lauf endet bewusst mit **Exitcode 1** und `needs_revision`, weil 96 Dialogzeilen das Gate für Produktionssprache auslösen. Es bestehen **keine gemeldeten Kennungs-, Reihenfolge- oder Titelabweichungen** zum aktuellen Kampagnenkatalog. Der Bericht nennt außerdem 210 Wiederholungsgruppen und eine Altersstelle zur Prüfung. Fehlende Katalogfelder werden nicht als widersprüchliche Werte gezählt.

Exitcode 0 bedeutet nur, dass die gelieferten Quellen im automatischen Prüfumfang keine Blocker auslösen. Exitcode 2 kennzeichnet unlesbare oder nicht unterstützte Eingaben. `--require-all-volumes` verlangt zusätzlich alle vier Bände; ohne diese Option bleibt die Teilabdeckung ausdrücklich im Bericht sichtbar. `production_clearance` bleibt stets `not_assessed`.

## Überprüfung des Werkzeugs

```bash
python3 -m unittest discover -s tests -p android_story_source_audit_test.py -v
```

Die zwölf gezielten Prüfungen bestanden. Sie verwenden kleine künstliche DOCX-Dateien, damit keine privaten Drehbücher für CI benötigt werden. Geprüft wurden insbesondere das tatsächliche titelbasierte Registryformat, vollständige Metadaten mit absichtlich falscher Besetzung, Absätze in Tabellen, Hashbelege ohne Textausgabe, Produktionssprache, Wiederholung als Prüfhinweis, unterschiedliche Sprecher, ausgelassene beziehungsweise nicht parsebare Dialogzeilen, Jahresintervalle, fehlende Bände, doppelte Eingaben, Änderungsmarkierungen und CLI-Exitcodes.

Der nächste inhaltliche Schritt ist die szenenweise Überarbeitung und Freigabe der gemeldeten Dialogstellen samt zeitlicher Besetzung. Erst danach lassen sich verbindliche Sprachaufnahmen und Cinematic-Varianten beauftragen. Der bestehende Kindheitspfad, seine Missionen und Saves bleiben von diesem Paket unverändert.
