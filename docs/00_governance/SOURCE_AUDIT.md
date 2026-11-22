# IMPERATHEN – Prüfung der bisherigen Projektmappe

**Stand:** 22. November 2026 · **Geltung:** Vorproduktion · **Name:** vorläufig  
**Prüfgegenstand:** beigefügte `IRON_BANNERS_Projektmappe.zip`, insbesondere Konzept, Arbeitsauftrag, Architektur, Datenschemata, Beispielwelt, Validator, Entwicklungsplan und Abnahmekatalog.

Die Unterlagen wurden gelesen und statisch verglichen. Bei dieser Prüfung wurden weder Spielcode geändert noch Validator-Tests, Blender oder Unreal ausgeführt. Zahlen aus alten Protokollen bleiben historische Angaben. Dieser Bericht ersetzt keine technische Abnahme und erklärt den Namen nicht für markenrechtlich freigegeben.

## 1. Verbindliche Leitplanken und offene Vorschläge

Die aktuellen Nutzeraufträge gehen den älteren Ausführungsanweisungen voraus: Projektgründung und sorgfältige Vorbereitung sind beauftragt; die eigentliche Spielprogrammierung soll noch nicht beginnen. Der vorläufig gewählte Name lautet **IMPERATHEN**. Der ältere Titel IRON BANNERS wird als Herkunftsbezeichnung erhalten, nicht als zweites aktives Produkt.

| Thema | Aus dem Nutzerauftrag zu bewahren | Noch keine verbindliche Nutzerentscheidung |
|---|---|---|
| Spielkern | Kampagnenstrategie, selbst errichtete Städte, Wirtschaft, eigene Armeen und persönliche Teilnahme am Kampf gehören zu derselben Welt. | Engine, Programmiersprache, konkrete technische Module und fertige Plattformzusagen. |
| Aufstieg | Bescheidener Anfang; Fähigkeiten, Entscheidungen, Beziehungen und tatsächliche Erfolge verändern die Laufbahn. Ein Lebensbogen kann als Soldat enden; Kaiser ist keine Garantie. | Ein einzelner universeller Talentwert, feste Gewichtungen oder ein unwiderruflicher Rangdeckel nach einem einzigen Tutorial. |
| Ausbildung | Gute Ausbildung erschließt mehr Fähigkeiten; fehlende Fähigkeiten können später durch Kämpfen und Erfahrung erworben werden. | Jede Fähigkeit sofort nachholbar oder jeder Karrierepfad stets wieder erreichbar. Beides wäre eine zusätzliche Designentscheidung. |
| Gefährte | Ein früher Gefährte kann Freund, Feind oder politischer Konkurrent werden. | Name Marcus, exakte Alterswerte, Dialoge und Zahlen für Beziehungen. |
| Langzeitspiel | Mehrwöchige Entwicklung und unterschiedliche, aus dem Spielverlauf entstehende Geschichten; erneutes Spielen soll andere Entwicklungen ermöglichen. | Genaue Kampagnenstunden, 45-Minuten-Einstieg, automatische tägliche Cloud-Abfrage oder konkretes Bezahlmodell. |
| Größenmaßstab | Große Heere und ein deutlich wachsender Machtbereich bleiben das Fernziel. | 500.000 gleichzeitig sichtbare, individuell animierte und physikalisch simulierte Soldaten. Die Quellen selbst schlagen stattdessen mehrere Simulationsebenen vor. |

`01_Konzept/MASTER_GDD.md`, Abschnitte 3.2 und 3.3, unterscheidet Ausbildung, spätere Karriere und politische Nachfolge bereits sinnvoll. Die dort zusätzlich vorgeschlagenen Chronik-, Nachspiel- und Dynastiemodi bleiben Vorschläge. Sie dürfen weder den gewünschten möglichen Soldatenabschluss entfernen noch als bereits bestellte Zusatzprodukte behandelt werden. Ein Entwurf für faire Rückmeldungen ist sinnvoll; die genaue Offenlegung späterer Ranggrenzen muss den Wunsch des Nutzers nach Entdeckung während des Spielens respektieren.

## 2. Konkrete Widersprüche und ihre Behandlung

### A. Sofortige Umsetzung ist überholt

`README_START_HIER.md` fordert unter „Sofort für Fable 5.2 verwenden“ die Umsetzung von P0. `02_Arbeitsauftrag/FABLE_5_2_MASTER_AUFTRAG.md` verlangt ein Engine-Projekt, Datenmodell, Spielfigur, Dorf, Bau, Kampf und einen PC-Debugbuild. Abschnitt 12 verlangt bei fehlender Engine sogar einen eigenständig implementierten Simulationskern.

Diese Befehle sind mit der aktuellen Pause der Spielprogrammierung unvereinbar. Die Dateien bleiben unverändert im Herkunftsarchiv. Ein neuer Einstieg muss ausdrücklich auf den aktuellen Gründungsauftrag verweisen. Alte Prompts dürfen nicht ungeprüft an einen nächsten Arbeitsagenten übergeben werden. Dokumente, Anforderungslisten und vorbereitete Ordner sind erlaubt; ein vermeintlich „nur vorbereitender“ Spielkern wäre bereits Programmierung.

### B. P0 bezeichnet zwei verschiedene Lieferumfänge

Im GDD, Abschnitt 15, und in `04_Entwicklungsplan/UMSETZUNGSPLAN.md` umfasst P0 vor allem Grundgerüst, Speicherbasis und Werkzeugablauf; Dorf, Kampf, Wirtschaft, Karte und Story folgen in P1 bis P5. Im Master-Auftrag, Abschnitt 4, umfasst P0.1 bis P0.8 bereits weite Teile dieser späteren Phasen.

**Behandlung:** Gründung als eigenständige Vorproduktionsphase führen. Für die spätere Umsetzung eine einzige Meilensteinliste mit eindeutigen Ergebnissen und Voraussetzungen erstellen. Der vollständige Spielausschnitt bleibt ein späteres integriertes Ziel, kein erledigtes Gründungspaket. Die alten Zeitangaben sind Schätzungen und keine zugesagten Termine.

### C. Herkunft und Lebensalter sind nicht konsistent ausformuliert

GDD 2.1 nennt drei Herkunftsprofile, 2.2 beschreibt fünf. Der Standardstart ist zwölf Jahre alt; GDD 1.2 und 3.3 verlangen plausible Altersübergänge. Die 45-Minuten-Referenzsequenz im Entwicklungsplan führt jedoch vom Einstieg über Ausbildung zu einem Konflikt mit acht Verbündeten, ohne einen Altersübergang festzulegen.

**Behandlung:** Fünf Herkünfte als Ideenbestand erhalten; Anzahl für den ersten Spielausschnitt ausdrücklich offenlassen. Kindheitsaufgaben, Ausbildung und erwachsene militärische Verantwortung getrennt planen. Ein späterer Zeitsprung ist ein Lösungsvorschlag, keine bereits bestätigte Szene. Die 45 Minuten beschreiben einen Demonstrationsablauf, nicht die Dauer eines vollständigen Lebensaufstiegs.

### D. Offline-Betrieb und Inhaltsreserve sind unterschiedlich beschrieben

Master-Auftrag P0.7 enthält die Formulierung „offline ohne KI-Fallback“. GDD 9.7, Architektur G und der Abnahmekatalog verlangen dagegen nutzbare Offline-Fortsetzungen. Architektur H verwendet als Nachladegrenze das 75. Perzentil jüngerer Sitzungen plus 60 Minuten; andere Texte sprechen allgemein von typischer Sitzungsdauer plus einer Stunde.

**Behandlung:** Offline-Spielbarkeit mit vorbereiteten, regelbasierten Inhalten als Architekturvorschlag klar formulieren; ein lokales Sprachmodell ist dafür nicht automatisch erforderlich. Für die Inhaltsreserve später einen gemeinsamen Schätzer einschließlich Erststart, Ausreißern und fehlender Historie festlegen. Eine geschätzte Stunde Inhalt ist keine garantierte Stunde Spielzeit. KI-Ausfälle dürfen das vorhandene Spiel nicht sperren.

### E. Erzählvertrag und vorhandenes JSON stimmen nicht überein

GDD 9.5 verlangt unter anderem `trigger`, `state_changes`, `failure_paths`, `escape_paths`, `relevance_to_history` und `validation_report`. `03_Technik/QUEST_EPISODE_SCHEMA.json` enthält stattdessen einen wesentlich kleineren Vertrag aus Voraussetzungen, Auswahlmöglichkeiten und drei Befehlsarten. Eine Bindung an eine bestimmte Weltrevision fehlt.

**Behandlung:** Das Schema als Demonstration kennzeichnen. Vor Implementierung festlegen, welche Angaben ein Planer liefert, welche ein Validator erzeugt und welche erst die Laufzeit ergänzt. Ein vom Modell mitgelieferter positiver Prüfbericht wäre kein unabhängiger Nachweis. Auch ein formal gültiges JSON beweist noch keine korrekte Geschichte.

## 3. Statische Prüfung von Schemas und Validator

`08_Werkzeuge/chronicle_validator.py` bezeichnet sich zutreffend als kleine Demonstration und ausdrücklich nicht als fertige Unreal-Integration. Es prüft Struktur, einige Referenzen und einzelne Befehlsvoraussetzungen. Es führt keine Spielbefehle aus. Architektur G beschreibt deutlich umfangreichere, erst geplante Prüfungen auf Rechte, Erreichbarkeit, Alter, verfügbare Inhalte und Konflikte.

### Entscheidende Lücken

1. **Mehrere Änderungen werden nicht gemeinsam geprüft.** Jeder Befehl wird gegen denselben unveränderten Ausgangszustand geprüft. Bei zwölf Holzeinheiten könnten zwei Transfers zu je acht innerhalb derselben gewählten Option einzeln die Bestandsprüfung bestehen. Entsprechend könnten mehrere Beziehungsänderungen gemeinsam die Grenzen überschreiten. Dies ist ein aus dem gelesenen Code abgeleitetes Gegenbeispiel, kein ausgeführter Test. Später ist jede gewählte Befehlsfolge auf einer fortgeschriebenen Kopie atomar zu validieren; alternative Entscheidungen bleiben getrennt.

2. **Revision und erneute Anwendung sind ungesichert.** Das Schema verlangt weder die geprüfte Weltrevision noch eine einmalig ausführbare Transaktionskennung. Zwischen Planung und Auslösung kann die Welt bereits verändert sein. Revalidierung, Wiederholschutz, Konfliktbehandlung und Rücknahme gehören in einen späteren ausführbaren Vertrag.

3. **Referenzen ersetzen keine Handlungsbefugnis.** `transfer_resource` prüft vorhandene Siedlungen und Bestand, aber keine Verfügungsrechte oder Transportstrecke. `record_promise` prüft vorhandene Personen und Betrag null, jedoch nicht deren Lebensstatus. Eine nicht in `actor_ids` genannte Person kann über Befehlsparameter vorkommen. Vollständige Referenz-, Rollen- und Lebensstatusregeln fehlen.

4. **Kontinuität ist nur teilweise prüfbar.** Vorhandene `source_event_ids` belegen lediglich, dass die IDs gespeichert sind. Das Ereignis muss damit noch nicht die Behauptung im freien Szenentext stützen. Auch `required_asset_ids` werden nicht gegen einen tatsächlichen Inhaltskatalog geprüft. Faktische Behauptungen, Wissensgrenzen und Asset-Verfügbarkeit brauchen eigene Regeln.

5. **Das Weltmodell ist stark verkürzt.** `WORLD_STATE_SCHEMA.json` enthält Personen, Siedlungen, einfache Gebäude, Fraktionen und Ereignis-IDs. Gebäude besitzen keine Position, Grundfläche oder Material-/Arbeitsaufträge; Armeen und ein vollständiges Ereignisprotokoll fehlen. Die Beziehung ist ein einzelner Zahlenwert, während GDD 4.2 mehrere Dimensionen vorsieht. Das ist für ein Beispiel zulässig, aber noch kein verbindliches Datenmodell des Spiels.

6. **Das Episodenbeispiel trägt seine Voraussetzungen nicht vollständig.** `BEISPIEL_KI_FOLGESZENE.json` beschreibt einen Holzbedarf; seine maschinenlesbaren Voraussetzungen prüfen nur Personen, Ort und ein vorheriges Ereignis. Der Ressourcenbedarf ist nicht als Bedingung abgebildet. Außerdem muss eindeutig definiert werden, ob eine Beziehungsänderung von Spieler zu Marcus auch Marcus’ Vertrauen zum Spieler ausdrücken soll; gerichtete Beziehungen sind nicht automatisch gegenseitig.

### Aussagekraft der vorhandenen Tests

`08_Werkzeuge/test_chronicle_validator.py` enthält acht Testfälle: gültige Episode, toter Akteur, fehlender Ort, fehlendes Ursprungsereignis, unbekannter Akteur, Beziehungsgrenze, doppelte Wahl-ID und unbekannte Befehlsart. Für `transfer_resource` und `record_promise` gibt es dort keine eigenen Fälle. Kumulierte Änderungen, Revisionskonflikte, Berechtigungen und Assets sind nicht abgedeckt.

Die Hilfsfunktion ersetzt mit `world or self.world` beziehungsweise `episode or self.episode` leere Objekte durch die Standarddaten. Ein späterer Test mit `{}` würde deshalb nicht den beabsichtigten leeren Eingang prüfen. Mehrere Tests verlangen lediglich irgendeinen Fehler; sie identifizieren die gewünschte Fehlerursache nicht. Das Altprotokoll über acht erfolgreiche Tests belegt somit eine begrenzte Demonstration. Es belegt weder die Spielbarkeit noch den aktuellen Zustand einer anderen Umgebung. Abhängigkeiten und Laufzeitversionen müssen für spätere Wiederholbarkeit festgehalten werden.

## 4. Darstellung, Abnahme und Leistungsbehauptungen

Die 13 Szenenbilder sind Konzeptdarstellungen. Sie belegen keine Engine-Grafik, Bedienbarkeit, Xbox-/PlayStation-Fassung oder erreichbare Bildrate. Die beschriebenen 30–40 Grundfiguren mit Varianten sind eine Produktionsidee; sie reduzieren weder Animation, Rigging und Optimierung noch die Laufzeitkosten automatisch auf null.

`08_Werkzeuge/blender_generate_blockout.py` ist ein grober Szenenentwurf. Schon seine Beschreibung und Schleifen unterscheiden sich: angekündigt werden zwölf Palisadenpfosten und eine Kiste, angelegt werden neun Pfosten und drei Kisten. Fertige betretbare Häuser, Spielkollisionen, LODs und ein geprüfter Engine-Export folgen daraus nicht. Die Datei wurde hier nicht gestartet.

GDD 6.4 und Architektur I trennen strategische Soldaten, taktische Simulation, sichtbare Figuren und vollständige Physik-/Animationsakteure. Diese Unterscheidung muss jedes spätere Leistungsblatt erhalten. 500.000 ist ein unbewiesenes strategisches Fernziel. Konkrete Hardwarepflichten, Bildraten und Konsolenfreigaben werden erst durch passende Builds und Messungen belastbar.

`07_Abnahme/QA_ABNAHMEKATALOG.md` führt 92 Fälle als nicht durchgeführt. Eine ausgefüllte Anforderungsliste ist kein Testnachweis. Künftige Abnahmen benötigen Build, Plattform, Eingangsdaten, erwartetes Ergebnis und tatsächliche Beobachtung. Ein bestandenes Teilziel darf andere offene Punkte nicht verdecken.

## 5. Verbindliche Ordnung für die weitere Vorbereitung

Die Herkunftsmappe bleibt nachvollziehbar erhalten. Aktive Dokumente verwenden IMPERATHEN mit vorläufigem Namensstatus. Zusammengeführte Projektbibel, Einzeldokumente und alte Prompts dürfen keine konkurrierenden aktuellen Wahrheiten werden.

Jede wesentliche Aussage erhält einen Status: **Nutzerentscheidung**, **Entwurf**, **offene Entscheidung**, **historischer Nachweis** oder **aktuell nachgewiesenes Ergebnis**. Neue Aufgaben verweisen auf eine Anforderung und ein prüfbares Ergebnis. Änderungen an Kernabsichten werden als Entscheidungsvorschlag dokumentiert; sie werden nicht stillschweigend als technische Vereinfachung eingeschrieben.

Für den Abschluss der Gründung sind damit insbesondere erforderlich: aktueller Einstieg mit Programmierpause; eindeutige Dokumentzuständigkeiten; priorisiertes Backlog; abgegrenzter erster Spielausschnitt; Entscheidungsregister für Herkunft, Alter, Karriere und Engine; Prüfplan für Story-Verträge; Asset- und Quellenregister; nachvollziehbarer Namensprüfungsstand. Diese Arbeiten können vorbereitet werden, ohne bereits ein Spielprojekt zu implementieren.

**Gesamtbefund:** Die Mappe enthält eine umfangreiche, größtenteils stimmige Spielvision und brauchbare Demonstrationen. Ihr größtes unmittelbares Risiko ist die Verwechslung von älterem Ausführungsauftrag, Architekturentwurf und bereits nachgewiesener Funktion. Die Gründung sollte diese Ebenen zuerst sauber trennen und dabei die gewünschte, ergebnisabhängige Lebensgeschichte vollständig erhalten.
