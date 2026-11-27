# Kimi K3.1 Pro – permanenter Entwicklungsauftrag

90 initiale, adaptive Arbeitspakete (K01–K90). K01–K06 sind die erste bereits eingereichte Spezialrunde. Die folgenden IDs sind **Backlog**, nicht bereits gestartete API-Anfragen oder fertiggestellte Änderungen. Nach jeder Runde Status, aktuellsten Branch, Abhängigkeiten und reale Tests prüfen; neue Aufgaben ergänzen, obsolete schließen, Konflikte vermeiden. Nacht K07–K12, Alterung K13–K22 und individuelle Haushalte K61–K70 haben nächste Priorität. Kanonische Storydateien und vorhandene Alters-/Kalenderlogik sind verbindlich, keine willkürlichen Storyänderungen.

## Produktionsvertrag

**Verbindlich für alle K01–K90 und Folgeaufträge:** [REALISM QUALITY GATE](KIMI_REALISM_QUALITY_GATE.md). Jedes Asset wird tatsächlich gerendert, kritisch begutachtet, iterativ verbessert und anhand seiner Einzelbefunde, Godot-Verträge und Fold7-Zielprofile abgenommen. Der erste Entwurf ist niemals automatisch die finale Fassung. Dies gilt ausdrücklich auch für kleinste Gegenstände. Die Anforderungen in jede neue Kimi-Anfrage aufnehmen; laufende Anfragen im nächsten Review anhand dieses Standards nachprüfen.

Kimi erhält gepinnte, öffentliche Quelltexte und ausgewählte echte Review-Bilder. Pro Anfrage ein vollständiger prüfbarer Patch oder Blender-Generator. Die Entwicklungsleitung prüft vorgeschlagenen Code unabhängig, setzt ihn auf isoliertem Branch um, committet und öffnet PRs. Keine automatische Ausführung beliebigen Modelloutputs, keine Ausgabe von Secrets, kein unkontrollierter Write-Zugriff, kein automatisches Merge oder APK-Release. Vor jedem nächsten Batch laufende Jobs prüfen, Quoten beachten, höchstens zwei gleichzeitige API-Aufträge, keine endlosen Retries. Modellantworten und Tests sind unterschiedliche Zustände. Für Grafik: echte Blender-/Godot-Render, für Android: reale Gerätedaten oder ausdrücklich ausstehend. Nemotron liefert unabhängig konkrete Codepatches, Review und Gegenprüfungen; bei Konflikten Evidenz statt Vertrauen.

## Erste grafische Spezialrunde

- [ ] **K01 – Charaktere und Ausrüstung:** Legionär und Kind: Anatomie, Gesichtsdetails, PBR, Rigging und Materialtrennung.
- [ ] **K02 – Stadtarchitektur:** Modulare, maßstäbliche Häuser und Tabernae mit benutzbaren Innenräumen, Kollision und UV/PBR.
- [ ] **K03 – Geländedarstellung:** Natürliche Reliefs, Felsen, Vegetation und Übergänge ohne Änderung der Streamingautorität.
- [ ] **K04 – Bewegungsanalyse:** Geh-/Laufkontinuität, Fußkontakt, Armbewegung und messbare Drift.
- [ ] **K05 – Filmischer Prolog:** Vexillum-Geometrie, Stoff und Beleuchtung aus den tatsächlichen Blender-Rendern.
- [ ] **K06 – Fold7-Rendering:** Messbare GPU-/CPU- und Frame-Pacing-Verbesserung ohne willkürliche Qualitätsabsenkung.

## Nacht und Erkennbarkeit – höchste nächste Priorität

- [ ] **K07 – Mondlicht und Nachthimmel:** Zeitabhängige Mondrichtung, Farbtemperatur, Umgebungseinfluss und Schatten; keine starre schwarze Nacht.
- [ ] **K08 – Wald bei Nacht:** Sichtbarkeit von Pfaden, Baumstämmen, Geländekanten, Gegnern und Pferd bei kontrollierter Dunkelheit.
- [ ] **K09 – Fackeln und Öllampen:** Historisch plausible Lichtquellen an Straßen, Türen, Lagern und Innenräumen; begrenzte Lichtreichweite und Lichtbudget.
- [ ] **K10 – Nachtexposition:** Belichtungsübergang Dämmerung/Nacht/Innenraum, Mindestlesbarkeit, keine ausgebrannten Flammen oder überhellte Nacht.
- [ ] **K11 – Reiten bei Nacht:** Sichtbarer Weg, Hindernisse, Kamera und getragenes Licht; Nachtmission ohne Änderung der Missionsregeln.
- [ ] **K12 – Nacht-Abnahme:** Reproduzierbare Godot-Captures bei Dämmerung, Mondnacht, Wolken und Innenraum; Gerätetest und objektive Sichtbarkeitskriterien.

## Alterung, Identität und Story

- [ ] **K13 – Identitätsvertrag des Protagonisten:** Gesichtslandmarken, Augen, Haarfarbe und Narben als persistente Identität; Stage-Assets statt einfacher Skalierung.
- [ ] **K14 – Kind:** Eigenständige kindliche Körperproportionen, Mimik, Hände, Rig und Schrittweite.
- [ ] **K15 – Jugend:** Storygebundene Altersstufe, Wachstum, Gesichtskontinuität und altersgerechte Bewegung.
- [ ] **K16 – Junger Erwachsener:** Skelett, Anatomie, Trainingszustand, Gear-Fit und Kontinuität zur Jugend.
- [ ] **K17 – Reifer Erwachsener:** Falten, Muskel-/Haltungsvariation, Beruf, Kleidung und Narben ohne Änderung der Identität.
- [ ] **K18 – Spätere Altersstufen:** Spezifische Meshes, Haaralterung, Haltung und robuste Bewegung; aus kanonischem Kalender abgeleitet.
- [ ] **K19 – Altersübergang:** Kalenderereignis, Animation-Retargeting, Inventar-/Save-Erhalt und keine doppelten Charaktere.
- [ ] **K20 – Familie und Freunde:** Storyfiguren aus den kanonischen Bänden identifizieren und pro Figur wiedererkennbare Asset-/Voice-/Rig-Verträge definieren.
- [ ] **K21 – Berufs-/Lebenspfade:** Militär, Handel, Handwerk und Verwaltung nach vorhandener Wahl- und Storyautorität; sichtbare Kleidung und Ausrüstung.
- [ ] **K22 – Storykontinuität:** Routen, Beziehungen, Entscheidungen und Alterungsstufen mit bestehenden Storytests verbinden; keine freie Erfindung kanonischer Fakten.

## Rigging und Animation

- [ ] **K23 – Humanoid-Skelett:** Einheitliche Bone-Namen, Ruhepose, Orientierung, Gewichte und Retarget-Tests.
- [ ] **K24 – Hautgewichtung:** Schulter, Ellenbogen, Hüfte, Knie und Handgelenk; Deformations- und Clipping-Prüfung.
- [ ] **K25 – Gehzyklus:** Natürlicher Armschwung, Beckenrotation, Schrittphase und Fußkontakt.
- [ ] **K26 – Lauf und Sprint:** Beschleunigung, Bremsung, Richtungswechsel, Körperneigung und Übergänge.
- [ ] **K27 – IK auf unebenem Gelände:** Fußkontakt und stabile Hüfte auf Treppen, Hängen und Wegen.
- [ ] **K28 – Gesicht und Blick:** Blinzeln, Augenfokus, Gesichts-Morphs und Emotionen ohne groteske Deformation.
- [ ] **K29 – Dialoganimation:** Lippen-/Kieferbewegung, Hände, Blickwechsel, Sprecherwechsel und bestehende Viseme.
- [ ] **K30 – Alltagsarbeit:** Schmieden, Wasserholen, Tragen, Sitzen und Essen mit Hand-/Objektkontakt.
- [ ] **K31 – Pferd und Reiter:** Pferdeskelett, Schritt/Trab/Galopp, Sattelkontakt, Auf-/Absteigen und Zügel.
- [ ] **K32 – Animationstests:** Messungen über verschiedene Geschwindigkeiten, Altersmodelle, Höhen und Frameraten.

## Kampf und Ausrüstung

- [ ] **K33 – Unbewaffneter Kampf:** Animationen für vorhandene Schlag-/Trittaktionen, Trefferfenster und Rückführung.
- [ ] **K34 – Schwert und Schild:** Griffkontakt, Deckung, Trefferreaktion und Kollisions-/Gameplay-Vertrag.
- [ ] **K35 – Speer und Lanze:** Bewegungsreichweite, Handkontakt und bestehende Waffenlogik.
- [ ] **K36 – Bogen:** Zieh-, Ziel- und Lösebewegung, Pfeilkontakt und überprüfbare Ausrichtung.
- [ ] **K37 – Axt und schwere Waffen:** Gewicht, Schwung, Erholung, vorhandene Ausdauer- und Trefferregeln.
- [ ] **K38 – Berittener Kampf:** Reiter-/Pferdesynchronität, Animation, bestehende Trefferautorität.
- [ ] **K39 – Rüstungsbaukasten:** Historisch und zeitlich plausible Teile, PBR, LOD, Skins und Item-IDs.
- [ ] **K40 – Ausrüstungsfortschritt:** An vorhandene Level, Fähigkeiten, Markt, Beruf und Erfolge binden; keine neuen Gratis-Freischaltungen.
- [ ] **K41 – Legionäre und weitere Einheiten:** Unterschiedliche Silhouetten, Gesichter, Ausrüstung, Animation und LOD.
- [ ] **K42 – Formationsbewegung:** Versatz, synchronisierte Wendung, Fußkontakt und Performance mit vielen Figuren.

## Lebendige Welt, Städte und Film

- [ ] **K43 – Dorffamilien:** Wiedererkennbare Erwachsene/Kinder/Ältere, Kleidung, Tätigkeit und Tagesablauf.
- [ ] **K44 – Stadttore und Wachen:** Original-Geometrie, begehbare Übergänge und bestehende Zugangskontrolle.
- [ ] **K45 – Wohnhäuser und Gasthäuser:** Benutzbare Räume, Möbel, Türkontakte, Licht und Kollision.
- [ ] **K46 – Schmieden und Werkstätten:** Historisch plausible Ausstattung und animierte Arbeit; Handelsvertrag erhalten.
- [ ] **K47 – Märkte:** Warenpräsentation, Stände, NPC-Verhalten und bestehender Handel.
- [ ] **K48 – Straßen und Wege:** Beläge, Entwässerung, Weglesbarkeit, Nachtlicht und Navigation.
- [ ] **K49 – Vegetation und Wasser:** Ökologisch stimmige Verteilung, Wind, Flüsse und Ufer ohne übermäßige Draw Calls.
- [ ] **K50 – Wetter und Jahreszeiten:** Regen, Wolken, Materialnässe, Sicht und NPC-Reaktionen auf Grundlage bestehender Simulation.
- [ ] **K51 – Kameraführung:** Filmische Einstellungen, Übergänge, Figurenframing und vorhandene Barrierefreiheitsoptionen.
- [ ] **K52 – Emotionale Szenen:** Storygetreue Gesten und Mimik aus bereits festgelegten Ereignissen und Dialogen.

## Qualität, Integration und Freigabe

- [ ] **K53 – Mesh-LOD:** Silhouetten- und Materialerhalt bei kontrollierten Polygonbudgets.
- [ ] **K54 – Texturpakete:** PBR, Mipmaps, Kompression und Speicherbudgets je Grafikprofil.
- [ ] **K55 – Instancing:** Wiederholte Weltobjekte und Figuren nach zulässigen LOD-/Materialverträgen bündeln.
- [ ] **K56 – Licht-/Schattenbudget:** Priorisierte Lichtquellen, Schatten und dynamische Anpassung; Nachtlesbarkeit erhalten.
- [ ] **K57 – Thermik und Leistung:** Fold7-Messprotokoll, Frame-Pacing und Langzeitstabilität; keine simulierten Gerätemessungen.
- [ ] **K58 – Asset-Pipeline:** Blender-Originaldatei, GLB-Export, Rig-/Material-Validierung, Renderbelege und Lizenzprovenienz.
- [ ] **K59 – Integrationsprüfung:** Alle freigegebenen Änderungen zusammenführen, Story/Save/Motion/GPU-Regressionsprüfungen, keine Doppelimplementierung.
- [ ] **K60 – Abnahme und nächste Runde:** Offene Defekte aus Tests, tatsächlichen Captures und Nutzerfeedback neu priorisieren; nur geprüfte Kandidaten für APK.


## Direkter Kimi-Editor

Kimi ist Lead 3D World, Character, Animation and Graphics Engineer. Der direkte Editor `kimi_editor.py` stellt list_files, read_file, replace_text und create_file für explizit freigegebene Quelldateien bereit. `kimi_editor_request.json` bestimmt eine gepinnte Revision und erlaubte Pfade. Der Workflow erzeugt vollständige geänderte Dateien, Diff und Provenienz als unreviewte Kandidaten. Keine Shell-Ausführung, GitHub-Schreibrechte oder API-Schlüssel für das Modell. Die Entwicklungsleitung prüft und committet akzeptierte Kandidaten auf isolierte Entwicklungsbranches, führt reale Blender/Godot-/CI-Tests aus und aktualisiert den Backlog. K61 ist die erste echte Editor-Anfrage; Erfolg erst bei belegten Toolcalls und verwertbaren Dateiänderungen. Weitere Aufgaben werden aus bestätigten Fehlern, Storyfortschritt und Renderbelegen fortlaufend ergänzt. Bestehende Haushalte und originale Assets nicht neu erfinden oder duplizieren.

## Vertiefung Innenräume und Haushalte

- [ ] **K61:** Generische modulare Einrichtungsbibliothek für Dorf und Stadt; vorhandene individuelle Haushalte erhalten.
- [ ] **K62:** Möbel, Textilien, Holz-, Keramik-, Bronze- und Eisenobjekte mit echter Geometrie, Material und Maßstab.
- [ ] **K63:** Einfache Wohnhäuser: Schlafstellen, Kochstelle, Vorratslager und Bewohnergeschichte.
- [ ] **K64:** Mittlere Wohnhäuser: berufsbezogene Räume und plausible Ablagen.
- [ ] **K65:** Wohlhabende Häuser: historisch passende Möbel, Atrium und funktionale Raumfolgen.
- [ ] **K66:** Gasthäuser: Schlafplätze, Schankbereich, Vorräte und Besucherführung.
- [ ] **K67:** Schmiede: Werkzeuge, Rohstoffe, sichere Interaktions- und Kollisionsverträge.
- [ ] **K68:** Lager und Wirtschaftsgebäude: Behälter, Regale, Waren und freie Wege.
- [ ] **K69:** Küchen und Essbereiche: Gefäße, Nahrungsmittel, Herd und Kontaktanimationen.
- [ ] **K70:** Schlafbereiche: Lager, Betten, Decken, Truhen und familiäre Gegenstände.

## Storyfiguren und Identität

- [ ] **K71:** Protagonist in allen kanonischen Altersstufen: persistente Gesichts- und Körpermerkmale.
- [ ] **K72:** Eltern, Schmied, Freunde und weitere Storyfiguren: individuelle Identität und korrekte Szenenbindung.
- [ ] **K73:** Gesichtslandmarken, Mimik und wiedererkennbare Augen/Haarmerkmale.
- [ ] **K74:** Eigenständige kindliche Anatomie und altersgerechte Animation.
- [ ] **K75:** Bevölkerungsvielfalt: Berufe, Altersgruppen, Geschlechter, Körperbau und Tagesablauf.
- [ ] **K76:** Kleidung und Besitz nach sozialem Stand, Region und Zeitepoche.

## Historische Gegenstände und Umgebungserzählung

- [ ] **K77:** Vorräte, Amphoren, Körbe, Werkzeuge, Behälter und ihre physischen Auflagepunkte.
- [ ] **K78:** Militärische Ablagen, Schildhalter, Waffen und Ausrüstungsgegenstände.
- [ ] **K79:** Marktstände, Waren, Stoffe, Nahrung und maßstäbliche Originalmodelle.
- [ ] **K80:** Zeitlich belegte religiöse/rituelle Gegenstände ohne historische Erfindungen.
- [ ] **K81:** Individuelle Haushaltserzählung durch platzierte und benutzbare Objekte.

## Nacht und Licht

- [ ] **K82:** Dorf bei Nacht: vorhandene Feuer- und Lampensysteme sinnvoll vernetzen.
- [ ] **K83:** Stadt bei Nacht: Straßenführung und lokale Lichtquellen.
- [ ] **K84:** Mondlicht, Waldränder, Wege und Gelände-Kontrast ohne Tageslook.
- [ ] **K85:** Reiten bei Nacht: Sichtweite, Weglesbarkeit, Schatten und Kameratest.
- [ ] **K86:** Fackeln, Öllichter und Lagerfeuer: echte Quellen, begrenztes Lichtbudget.
- [ ] **K87:** Wohnraumbeleuchtung: Feuerlicht, Raumlesbarkeit und kein Durchscheinen durch Wände.

## Alltagsanimation und Integration

- [ ] **K88:** Arbeit im Haus: Griff-, Werkzeug- und Objektkontakte.
- [ ] **K89:** Sitzen, Essen, Schlafen, Gespräche: IK und Synchronisierung.
- [ ] **K90:** Objektinteraktionen, Story-/Weltintegration und reproduzierbare Regressionen.
