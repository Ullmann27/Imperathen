# Arbeitsauftrag für Agenten – IMPERATHEN

## Präzisierung der Game Direction – 26.11.2026

Verbindlich ergänzend zum Masterhandbuch 3.0 (Wortlaut und Folgen: [docs/00_governance/GAME_DIRECTION_2026-11-26.md](docs/00_governance/GAME_DIRECTION_2026-11-26.md), Entscheidungen D-015 bis D-022):

- Kampagnenbeginn 58 v. Chr. in Valdora bei Aquileia, Held zwölf Jahre; die Welt verändert sich über Jahrzehnte (keine statische historische Welt).
- Kein binäres Freund-/Rivale-Flag als Grundlage; Marcus und schrittweise alle wichtigen NPCs mit Erinnerungen, Beziehungen, Interessen, eigenen Entscheidungen und Alterung.
- Regulärer Start ohne Geld, Waffen oder Rüstung; 30 Denare nur in gekennzeichneten Test-/Entwicklungsszenarien; bestehende Saves unbeschädigt.
- Drehbuchfiguren bleiben; Nerva, Livia und Priscilla werden eigenständige Bewohner statt Doppelrollen.
- Germanische Gruppen als eigenständige Zivilisationen, nicht automatisch Feinde.
- Überfälle aus dem Fraktionssystem mit Ursachen und Folgen; I-10 bleibt geschützt; keine endlosen Überfallserien.
- Ein autoritativer Weltzustand für Strategie, Open World und Missionen; die Welt entwickelt sich auch ohne den Spieler.
- Zielbilder als Orientierung; keine künstliche Größenbegrenzung, aber Paket- und Streaming-Architektur; kostenpflichtige Dienste (z. B. Meshy) erst nach Freigabe von Umfang und Kosten; Fable 5.2 erst nach gesonderter Zwischenabnahme; kein Merge nach `main`.
- Ergänzt (D-023 bis D-030, [Wortlaut](docs/00_governance/GAME_DIRECTION_2026-11-26_B.md)): Talgefecht als Prüfstand 58 v. Chr. Rom gegen eine eigenständige germanische Gruppe, Kind ohne Befehlsgewalt; Axt und Schild nur seltene rekonstruierte Variante, weitere Kriegerfamilien, keine umgefärbten Römer; Militärweg freiwillig, Führung nur über Laufbahn; hybrides Kampfsystem in drei Ebenen, kein Schaden vor dem Trefferzeitpunkt, keine Duplikate beim Ebenenwechsel; Soldaten als Menschen mit Lebenslauf; Bände I–IV 58–27 v. Chr., Zeitarchitektur ohne Jahr null; Dynastie später, ohne P0/P1 zu verzögern.

## Präzisierung nach dem Spieltest – 23.11.2026

Heinz bewertet die bisherige APK als sehr frühe Rohfassung. Der neue Anfang soll einen Zwölfjährigen in einem **bereits bestehenden, funktionierenden Dorf** mit Eltern, Nachbarn, Markt und Handwerk zeigen. Der frühere sofortige Wiederaufbau und die erste selbst gebaute Hütte sind für diesen neuen Einstieg überholt. Beziehungen, sinnvolle verbundene Aufgaben, Schmiedelehre, beaufsichtigte Kontrollrunde und vorübergehende Wachhilfe gehen dem überraschenden nächtlichen Überfall voraus. Kein automatischer kurzer Sprung vom Kind zum Erwachsenen, Soldaten oder Kaiser.

Weitere ausdrückliche Ziele sind natürliche Arm- und Körperbewegungen, normales Gehtempo und getrenntes Laufen, erlernbare unbewaffnete Techniken, später ausrüstungsgebundener Schwert-/Schildkampf, ein größeres bewohntes Dorf, nutzbare Innenräume ohne Boden- oder Personendurchdringung, eine Zielkarte und größere Touchflächen. Konsolenqualität bleibt ein Ziel; Entlastung und Wärmeverhalten des Handys müssen gemessen werden. Die vorhandenen Befugnisse und Grenzen für Entwicklung, Android-Prüfbau, isolierte Branches und Draft-PRs bestehen weiter.

Der aktuelle Arbeitszweig heißt `feature/childhood-village-20261123`. Vor Änderungen [die tatsächliche Übergabe](docs/18_childhood/HANDOFF.md) lesen. Der neue Abschnitt wird nur für ausdrücklich neue römische Kindheitsspiele aktiviert; alte Saves behalten ihren bisherigen Weg. Die zwei gewünschten Folgechat-Prompts liegen unter `docs/18_childhood/CHAT_A_BEWEGUNG_KAMPF_STEUERUNG.md` und `CHAT_B_DORF_GESCHICHTE_WELT.md`, jeweils mit drei Arbeitsagenten. Den Remote-Stand prüfen und fremde Änderungen erhalten.

## Aktueller Entwicklungsauftrag – 22.11.2026

### Erweiterung vom 23.11.2026: gelebtes Dorf und offene Römerwelt

Heinz beauftragt drei Agenten, den Anfang mit Handlung, Gesprächen und tatsächlicher Spielmechanik auszubauen. Zunächst regiert ein anderer. Der Spieler hilft beim Wiederaufbau, lernt Menschen und Berufe kennen, lebt im Dorf, verteidigt es und entwickelt Fähigkeiten durch seine Handlungen. Reale Einwohner besetzen Arbeitsplätze und fehlen dort, wenn sie verteidigen oder zur Truppe wechseln. Die langfristige Richtung ist eine offene Römerwelt mit historisch belegter Ausgangslage und durch Spielerhandlungen abweichenden Verläufen. Der Kampagnenbeginn ist 58 v. Chr. in Valdora bei Aquileia (Vorgabe D-015 vom 26.11.2026; ersetzt das frühere Startjahr um 100 n. Chr.); lokale Fiktion, belegte Ereignisse und alternative Geschichte sind ausdrücklich zu unterscheiden.

Der integrierte Entwicklungsstand und die tatsächlichen Grenzen stehen in `docs/17_village_life/PLAYER_VISION.md`, `ECONOMY.md`, `STORY.md` und `ASSETS_AND_WORLD.md`. 32 × 32 km sind eine eigene technische Geländeplanung, keine verifizierte GTA-VI-Fläche und keine Behauptung einer fertig bevölkerten Welt. Android bleibt erstes Ziel; ein PS5-/AAA-Niveau ist das Gestaltungsziel, kein bereits belegtes Ergebnis. Die bisherigen Befugnisse für isolierte Implementierung, Tests, Android-Prüfbau und Draft-PR gelten weiter.

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
