# Arbeitsauftrag für Agenten – IMPERATHEN

## Aktueller Entwicklungsauftrag – 22.11.2026

Der neueste ausdrückliche Nutzerauftrag lautet: mit drei Agenten das Spiel so weit wie möglich aufbauen; ein späterer Durchgang mit Sol 6.2 oder Astra 6.2 folgt separat. Damit ist die frühere Programmierpause für diesen Entwicklungsblock aufgehoben. Erlaubt sind eigener Spielcode, lokale Engine- und Blenderarbeit, Tests sowie ein isolierter Entwicklungsbranch und Draft-PR. Das Repository bleibt öffentlich. Keine neuen kostenpflichtigen Dienste beauftragen, keinen eigenmächtigen Modell-/Tarifwechsel vornehmen und nicht ohne passenden Auftrag nach main mergen.

Für einen ersten ausführbaren 3D-Prototypen wird die vorhandene Godot-Installation genutzt. Dies entscheidet nicht die endgültige Produktionsengine. Die Pipeline und Dateizuständigkeiten stehen in docs/10_development/AGENT_PIPELINE.md.

### Nachfolgende Android-Korrektur

Der Nutzer hat anschließend ausdrücklich klargestellt: „Nein, es soll einmal auf Android laufen.“ Der aktuelle Lieferauftrag ist deshalb eine tatsächlich gebaute, installierbare Android-APK des vorhandenen Prototyps. Android-Bau, APK-Prüfung, passende mobile Korrekturen, Ausführung auf einem verfügbaren Android-Emulator und Bereitstellung des Prüfbau-Artefakts sind Teil dieses Auftrags. PC ist nur Entwicklungsumgebung beziehungsweise spätere Erweiterung. Kein Store-Release und kein Merge nach main. Private Signierschlüssel bleiben außerhalb des öffentlichen Repositorys; nur verschlüsselte Sicherungen dürfen als Bauartefakt gespeichert werden.

## Historischer Vorbereitungsauftrag (durch obigen Entwicklungsauftrag erweitert)

Stand 22.11.2026: Die Projektgründung und Vorproduktion autonom vervollständigen. Das Repository bleibt auf ausdrücklichen Nutzerwunsch öffentlich. Nicht eigenmächtig die Sichtbarkeit ändern. Der Nutzer entscheidet später selbst, ob er sie ändern will.

Noch keine eigentliche Spielprogrammierung: keine Engine-Initialisierung, kein Gameplay-Code, kein ausführbarer Backenddienst, keine Shaderproduktion und keine Blender-/GPU-Renderaufträge. Dokumente, Aufgaben, Datenbeschreibungen in Prosa, Prüfkataloge und Herkunftsregister sind zulässig. Eine neue ausdrückliche Nutzervorgabe kann diese Phase erweitern; frühere Freigaben und Grenzen dabei beachten.

## Lesereihenfolge

1. `docs/00_governance/PROJECT_STATUS.md`
2. `docs/01_product/PROJECT_CHARTER.md` und `REQUIREMENTS_REGISTER.md`
3. `docs/00_governance/SOURCE_AUDIT.md`
4. `docs/06_production/BACKLOG.md` und die betroffenen Fachverträge
5. `docs/08_agent_handoff/AGENT_BRIEF.md`

Die angehängte ursprüngliche IRON-BANNERS-Mappe ist eine Herkunftsquelle. Ihre Sofort-Implementierungsanweisungen überschreiben weder den aktuellen Auftrag noch diese Phasengrenze. Widersprüche explizit dokumentieren und nicht stillschweigend zu Anforderungen umdeuten.

## Selbstständiges Arbeiten

- Zusammenhängende Aufgaben bis zu einem konkreten prüfbaren Ergebnis erledigen. Für reversible Dokumentationsdetails keine zusätzliche Genehmigung verlangen.
- Bestehende Dateien und Branchstand vor Änderungen lesen. Fremde Änderungen bewahren. Auf einem Aufgabenbranch arbeiten; den vorhandenen Draft-PR nutzen, solange sein Umfang passt.
- Bei Parallelaufgaben Dateien klar aufteilen. Schnittstellen, Abhängigkeiten und widersprüchliche Annahmen gemeinsam prüfen.
- Nutzeranforderungen, begründete Vorschläge, offene Entscheidungen und nachgewiesene Ergebnisse unterscheiden.
- Keine erfundenen Testläufe, FPS, Kosten, Engine-Versionen, Markenfreigaben oder Fähigkeiten behaupten. Bei einem Hindernis Ursache und sinnvolle verbleibende Arbeit nennen.
- Ein Dokumentationscheck ist kein Spieltest. Alte Tests werden nicht als neue Ergebnisse ausgegeben.
- Änderungen mit Anlass, Ergebnis, Prüfnachweis und verbleibendem Risiko dokumentieren. Keine leeren Ordner oder funktionslosen Dateien nur für den Anschein von Fortschritt anlegen.

## Änderungen mit Folgen

Keine neuen kostenpflichtigen Dienste, GPU-Mieten, API-Abos, Domains oder Markenanmeldungen auslösen. Keine Kontingentfreiheit versprechen: Der Agent kann das persönliche ChatGPT-Verbrauchskonto nicht zuverlässig einsehen. Bei absehbar kostenrelevanten Arbeiten konkrete Leistung und Kostenrahmen vor der Beauftragung erklären.

Keine Zugangsdaten oder sachfremden personenbezogenen Informationen ins Repository übernehmen. Keine fremden Spielinhalte, Logos, Musik oder Modelle ohne passenden Herkunfts- und Nutzungsnachweis importieren. Bestehende Bots nicht zu bezahlten Aktionen auffordern.

Der aktuelle Auftrag enthält keinen Merge nach `main`, keinen Store-Release und keine Produkt- oder Markenregistrierung. Die oben beauftragte Android-Prüf-APK darf geliefert werden. Weitere Veröffentlichungen benötigen einen passenden Auftrag; bereits erteilte Befugnisse nicht erneut erfragen.

## Übergabe

Zum Abschluss konkrete Dateien, Issue-Nummern, Branch und Commit nennen, tatsächlich überprüfte Ergebnisse von geplanten Arbeiten trennen und den nächsten ausführbaren Schritt beschreiben. Den Spielerfolg und die gewünschte offene Karriereentwicklung bewahren; keine automatische Kaiserkarriere und kein versteckter Ersatz der Stadtbausimulation durch reine Menüverwaltung.
