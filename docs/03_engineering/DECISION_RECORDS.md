# IMPERATHEN – Technische Entscheidungsakte

**Stand:** 22.11.2026 · **Phase:** Vorproduktion. Die aktuelle Benutzeranweisung setzt Spielprogrammierung aus. Die nachfolgenden Entscheidungen organisieren eine spätere Umsetzung; sie führen keine aus.

## Statusmodell

**Vorgabe** bezeichnet eine im Gespräch festgelegte Produkt- oder Arbeitsgrenze. **Vorschlag** ist eine fachliche Ausgestaltung, die noch anhand der Voraussetzungen zu prüfen ist. **Offen** bedeutet, dass entscheidende Informationen fehlen. **Verworfen** setzt eine dokumentierte Begründung voraus. Kein Vorschlag wird durch seine Aufnahme in ein Markdown-Dokument automatisch als implementiert oder getestet behandelt.

| ID | Frage | Status | Vorgesehene Entscheidung / Begründung |
|---|---|---|---|
| ADR-001 | Beginnt jetzt die Programmierung? | Vorgabe | Nein. Dokumentation, Aufgaben, Abhängigkeiten und Übergabe werden vorbereitet. |
| ADR-002 | Teilen die Spielansichten eine Welt? | Vorgabe | Ja. Gebäude, Personen, Armeen und Ereignisse bleiben über Perspektivenwechsel konsistent. |
| ADR-003 | Welche Engine und Version? | Vorschlag/offen | Unreal Engine 5.x evaluieren; exakte Version, Plugins und Buildumgebung noch offen. |
| ADR-004 | Wie entstehen neue Storyfolgen? | Vorgabe + Vorschlag | Kausal aus Spielerereignissen; strukturierte Kandidaten und regelgebundene Prüfung als technischer Ansatz. |
| ADR-005 | Benötigt jeder Spieler zwei GPUs? | Nicht festgelegt | Keine entsprechende Mindestvoraussetzung. Getrennte Hardware erst bei gemessenem Bedarf erwägen. |
| ADR-006 | Wie werden große Heere gerechnet? | Vorschlag | Individuelle Nähe, formationsbasierte Mitteldistanz, aggregierte Ferne; Bestände konservieren. |
| ADR-007 | Was bedeutet ein schwacher Karrierebeginn? | Designentscheidung offen | Unterschiedliche Enden einschließlich Soldatenabschluss erhalten. Zeitpunkt und Auslöser bleiben offen; Abschluss als terminalen Zustand und Ereignis speichern, unvereinbare Reserven verwerfen. Kaiserantritt ist Rollenwechsel mit Fortsetzung. |
| ADR-008 | Muss die Story täglich außerhalb des Spiels laufen? | Vorschlag/offen | Ereignisabhängige Vorbereitung; Offline-, Hintergrund- und Dienstvarianten getrennt planen. |
| ADR-009 | Brauchen Planungsentwürfe schon eine Markenfreigabe? | Arbeitsgrenze | Planung und ihre Veröffentlichung im ausdrücklich öffentlichen Repository sind unter gekennzeichnetem Arbeitstitel vorgesehen. Eine endgültige Markenfreigabe oder Registrierung wird dadurch nicht behauptet. |
| ADR-010 | Welche Inhalte gehören ins öffentliche Repository? | Vorgabe | Das Repository bleibt ausdrücklich öffentlich. Die vorbereiteten fachlichen Dokumente dürfen auf dem Planungsbranch veröffentlicht werden; Schlüssel und personenbezogene Fremddaten gehören nicht hinein. |

## ADR-011 – Transaktionen statt einzelner isolierter Prüfungen

**Problem:** Der beigefügte Demonstrationsvalidator prüft jeden Befehl gegen denselben Ausgangsbestand. Mehrere gültig aussehende Einzeltransfers können zusammen mehr verbrauchen als vorhanden. Auch aufsummierte Beziehungen und Befehlsberechtigungen sind nicht vollständig abgebildet.

**Vorschlag:** Jede auswählbare Konsequenz als vollständige Transaktion auf einer Zustandskopie prüfen. Alternativen bleiben voneinander isoliert. Vor Aktivierung werden Revision und Voraussetzungen erneut kontrolliert. Erst anschließend entsteht eine atomare Änderung mit unveränderlicher Ereignisfolge. **Nachweis später:** Doppelentnahme, doppelte Befehls-ID, konkurrierende Reservierung und Fehler im letzten Schritt müssen ohne Teilbuchung enden.

Die Transaktion umfasst unmittelbar fällige Buchungen. Ein langlaufender Bauprozess besteht aus mehreren bestätigten Schritten; sein Abbruch behandelt den aktuellen Istzustand und rollt nicht die gesamte Baugeschichte zurück. Technische Verfügungsbefugnis bleibt von spielinternem Unrecht getrennt. Ein vorgesehener Regelpfad kann unerlaubte Handlungen mit Folgen erlauben; illegales Bauen ist weiterhin offen.

## ADR-012 – Die alte Projektmappe als Quelle, nicht als ausgeführter Auftrag

Die frühere Mappe enthält unmittelbar ausführende Fable-Aufträge, Beispielskripte, historische Testprotokolle und generierte Bilder. Ihr Status bleibt nachvollziehbar archiviert. Der aktuelle Planungsauftrag hat Vorrang; alte „sofort starten“-Passagen werden in der neuen Übergabe ausdrücklich deaktiviert. Skripte werden jetzt weder erweitert noch als fertige Engine-Integration präsentiert. Bildzahlen oder Schrift im Bild werden nicht zu technischen Leistungszusagen.

## ADR-013 – Reihenfolge der Freigaben

Dokumentenprüfung und Rechte-/Namensrecherche können parallel erfolgen. Ein ungelöster Markenname soll keine Architekturüberlegung künstlich blockieren. Die Auslieferung unter einem endgültigen Produktnamen und der Start der Spielprogrammierung sind unterschiedliche Entscheidungen. Programmieren bleibt wegen der aktuellen Benutzeranweisung ausgesetzt; nicht wegen einer neu erfundenen pauschalen Pflicht, zuerst eine Marke kaufen zu müssen.

Die nächste sachliche Reihenfolge lautet: vorhandenes Material prüfen, Widersprüche auflösen, Datenverträge und ersten Spielabschnitt festlegen, tatsächliche Toolchain ermitteln und danach einen konkret beschriebenen Entwicklungsauftrag zur Entscheidung vorlegen. Kein Abonnementwechsel und keine kostenpflichtige Infrastruktur werden durch diese Akte ausgelöst.

## Pflege der Akte

Für eine Änderung sind Anlass, betroffene IDs, verworfene Alternativen, Risiken und erwarteter Prüfbeleg festzuhalten. Routineentscheidungen innerhalb freigegebener Grenzen kann der verantwortliche Agent selbst treffen. Änderungen an Spielerlebnis, Plattform, Kosten oder Veröffentlichung müssen sichtbar als Entscheidung erfolgen. Rückwirkendes Umschreiben früherer Nachweise ist ausgeschlossen; eine neue Entscheidung verweist auf die ersetzte.

**Verwandte Spezifikationen:** [Weltzustand und Zeit](WORLD_STATE_AND_TIME_CONTRACT.md), [Narrative](NARRATIVE_CONTRACT.md), [Leistungsplanung](PLATFORM_AND_PERFORMANCE_PLAN.md).


## ADR-012 – Erste ausführbare Einstiegsvorschau (22.11.2026)

Status: umgesetzt für den begrenzten Entwicklungsauftrag. Die Vorschau unter preview/ kann ohne Engine-Download und ohne externe Dienste gestartet und gebündelt werden. Die geplante Unreal-Richtung bleibt offen bis zur echten Toolchain-Abnahme; game/Imperathen ist ein separater nativer Anfang. Kein Ersatz der langfristigen 3D-Spielvision durch reine Menüverwaltung.

Die Vorstufen besitzen getrennte, ausdrücklich benannte Saveformate. Kein Konverter und keine allgemeine Produktionssave-Migration werden behauptet. Die nativen Ressourcenregeln entsprechen dem ersten Browserabschnitt. Visuelle und native UI-Qualität brauchen ihren noch ausstehenden Lauf in einer zulässigen Testumgebung.
