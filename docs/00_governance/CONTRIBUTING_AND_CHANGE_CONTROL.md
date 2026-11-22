# Arbeits- und Änderungsregeln

## Arbeit mit Branches

`main` bleibt die stabile Basis. Der aktuelle Vorbereitungsauftrag nutzt `docs/bootstrap-governance-20261122` und Draft-PR #1. Weitere abgegrenzte Dokumentationsarbeiten können `docs/<thema>` verwenden; spätere Implementierung erhält eigene Aufgabenbranches. Keine erzwungenen Updates oder Überschreibung fremder Änderungen. Vor jedem Update den aktuellen Stand lesen und bei einer Abweichung zunächst den Unterschied prüfen.

## Was autonom entschieden werden kann

Gliederung, Benennung von Dokumenten, Verweisreparaturen, nachvollziehbare Fachvorschläge, Aufgabenzerlegung und Konsistenzkorrekturen innerhalb des erteilten Auftrags. Der Nutzer muss diese gewöhnlichen Vorbereitungsschritte nicht einzeln bestätigen. Eine fachliche Alternative bleibt als Vorschlag erkennbar, wenn sie einen Nutzerwunsch verändert.

## Was einen passenden weiteren Auftrag braucht

Der Start der Spielprogrammierung, eine Beauftragung kostenpflichtiger Leistungen, die Anmeldung einer Marke, die Veröffentlichung eines Builds oder die Zusammenführung dieses Drafts nach `main` gehören nicht zur aktuellen Vorarbeit. Frühere und spätere konkrete Nutzerfreigaben gelten in ihrem jeweiligen Umfang weiter; keine Genehmigungsschleife für bereits autorisierte Handlungen schaffen.

## Öffentliches Repository

Die öffentliche Sichtbarkeit entspricht der ausdrücklichen Nutzerentscheidung vom 22.11.2026. Sie blockiert die Fachplanung nicht. Zugangsdaten und sachfremde persönliche Informationen werden nicht gespeichert. Größere Binärquellen und Fremdassets werden anhand Herkunft, Nutzungsrecht und einer passenden Versionsstrategie beurteilt; der Sichtbarkeitsstatus ersetzt diese Prüfung nicht.

## Statusbegriffe

| Status | Bedeutung |
| --- | --- |
| Vorgabe | Vom Nutzer ausdrücklich gewünschte Eigenschaft oder Einschränkung |
| Vorschlag | Begründete Arbeitsannahme; keine behauptete Nutzerentscheidung |
| Dokumentiert | Eine auffindbare, in sich prüfbare Beschreibung liegt vor |
| Implementiert | Die betreffende Funktion besitzt tatsächlich ausführbare Umsetzung |
| Verifiziert | Ein konkreter Test mit Version, Umgebung und Ergebnis wurde durchgeführt |
| Ausgeliefert | Ein nachvollziehbarer Build wurde bereitgestellt |

## Quellen und Änderungen

Anforderungen erhalten IDs. Materielle Entscheidungen stehen im Entscheidungsprotokoll. Originalquellen behalten ihren Namen und ihre Prüfsumme; das Umbenennen des Projekts ist kein Anlass, historische Belege umzuschreiben. Links, Aufgaben und Fachverträge werden bei Änderungen gemeinsam aktualisiert.

## Prüfungen

Für diese Dokumentationsphase: Inhalte lesen, relative Verweise prüfen, Anforderungen auf Abdeckung und widersprüchliche Aussagen prüfen, externe Behauptungen mit passenden Quellen belegen. Keine Tests erzeugen, die lediglich die Dokumentstruktur nachbauen. Spätere Systemtests richten sich nach tatsächlichen Risiken und den Abnahmekriterien.

## Rücknahme

Eine fehlerhafte Dokumentationsänderung mit einer gezielten Folgeänderung korrigieren. Bereits veröffentlichte Commits nicht heimlich aus der Historie entfernen. Das Schließen eines Issues benötigt den passenden Liefer- oder Entscheidungsnachweis, nicht nur einen optimistischen Statussatz.
