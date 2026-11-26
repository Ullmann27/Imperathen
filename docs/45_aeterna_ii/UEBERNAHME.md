# IMPERATHEN · Operation Aeterna II

## Ausgangspunkt und Quellen

Der neue Arbeitszweig `aeterna/living-empire-20261126` setzt auf `7f46fa0a2332f1b9b853979a60bce6a798647971` aus #101 auf. Der integrierte Prüfstand #86 lag auf `2c549548497aad901bda32d71c19c2a1961d9591`. Der Referenzzweig und seine offenen PRs bleiben als Vergleich erhalten. Fable-Übergabe und Game Direction wurden aus #96 und #97 übernommen. [Übergabe](../34_uebergabe_gpt_fable/UEBERGABEBERICHT.md) · [Entscheidungen](../00_governance/DECISION_LOG.md) · [Produktionsindex](../00_governance/PRODUCTION_INDEX.md)

Für die Fortsetzung waren die transkribierte Missionszeitleiste, die implementierten Missionsblätter, der Produktionsindex, die Übergabe und die neueren Beschlüsse zugänglich. Die vier vollständigen Originaldrehbücher und das 311-seitige Masterhandbuch lagen weder als Repository-Datei noch als Anhang vor. Die angehängte Projektbibel umfasst 31 Seiten und ist eine ältere Quelle.

## Eingebaut und geprüft

| Bereich | Bauzustand |
| --- | --- |
| I‑00 bis I‑04 | Prolog und I‑01 laufen auf dem normalen Spieleinstieg. Integriert sind der Marktgang aus I‑03 und Sextus’ Werkstattbesuch aus I‑04 mit Entscheidungen und gespeicherten Ereignissen. Spielfortschritt wird über geprüfte Befehle ausgelöst. |
| Welt und Spielstände | Die Kalender-, Siedlungs-, Stammes- und Truppenzeit verwendet eine Weltuhr. Valdoras Beleuchtung, Jahreszeit, Übersicht und Atlas folgen ihr. Aufgezeichnete Altstände behalten ihre Entscheidungen. Das Szenario um 100 n. Chr. behält seine eigene Zeitlinie. |
| Ausstattung | 21 Innenräume und 112 Kit-Requisiten. Geprüft sind auch Zugänge, Laufwege, Esse, Marktstände und die Becherpositionen. Die Tassen und der Krug folgen der Hand über einen Figurenwechsel hinweg. |
| Rom | Der Stadtspielpfad filtert epochefremde Modelle und ihre Kollisionen beim Laden. Der gesonderte neue Kolosseum-Bausatz aus #120 wurde in dessen Prüfszene erprobt. Die Reise von Valdora nach Rom ist noch offen. |
| Audio | 21 vorhandene synthetische deutsche Aufnahmen aus #122 und die Audiowerkzeuge übernommen. Der Prolog spielt exakt passende Aufnahmen ab, pausiert mit der Szene und löst die Stimme beim Sprung ins Spiel. Revidierte I‑01-Dialogzeilen brauchen aktualisierte Aufnahmen. Vollständige Lippenform-Ziele der Hauptfiguren stehen aus. |
| Bewegung | Reparatur #88 an der Originalfigur und die Nachträge aus #102 übernommen. Beide Outfitpfade verwenden das Originalrig. Handkontakt und erhaltene Requisiten sind nachgewiesen. Der strengere Motion-Gate bleibt gesperrt. |
| Überfall | Teststrecke an die erweiterten I‑01-, I‑03- und I‑04-Stationen angepasst. Der Überfall startet mit ungeklärter Herkunft. Die Tests belegen Torwege, Wachen und einen Treffer erst nach dem dargestellten Kontakt. |

## Nachweise und Grenzen

- `godot --headless --path prototype --fixed-fps 60 --script res://tests/i01_playthrough_test.gd` mit `IMPERATHEN_ISOLATED_TEST=1` und leeren XDG-Pfaden. 18 Prüfpunkte, 49,4 m gesteuerter Weg, Familiengespräche, Becher, Brunnen und Save/Load am Beginn von I‑02. Filmzeit wurde für diese automatisierte Abnahme beschleunigt. Die Neuinstanz der Hauptszene liest den Spielstand von Platte. Ein Prozessneustart auf Android ist gesondert zu prüfen.
- `python3 tools/check_prototype.py --keep-going --only house_interiors mission_bridge_data roman_hud world_state` für die gezielte Integration. 7.940 Innenraumprüfungen, 224 Brückenprüfungen über den v5/v6-Speicherwechsel und 354 Layoutprüfungen. Die simulierten Display-Geometrien enthalten Safe-Area und Fold7-Dichten.
- `godot --headless --path prototype --script res://tests/era_registry_test.gd` und `--fixed-fps 60 --script res://tests/roman_city_real_walk_test.gd` mit per Blender neu erzeugten Stadt-GLBs. In der Stadtszene waren 58 v. Chr. null Kolosseum-Meshes und null zugehörige Kollisionskörper sichtbar bzw. aktiv. 80 n. Chr. waren es 13/13.
- `godot --headless --path prototype --fixed-fps 60 --script res://tests/opening_voice_test.gd` für Produktionseinstieg, konkrete Zeilen-ID, Pause, Weiterlauf und Stimmenende. Die automatisierte Laut-/Viseme-Suite wurde separat ausgeführt und erreichte im ersten Lauf ihr Zeitlimit.
- Innenraum-, Stadt- und Bewegungsbilder stammen aus Godot 4.7.2 mit Mesa llvmpipe. Die Bildgebung am Desktop belegt den Szeneninhalt. Physische Fold7-Abnahme, Spielbarkeit der kompletten Strecke bis I‑10 auf Android und Leistungsfreigaben bleiben offen.

## Weitere Arbeitsstände

#111 persönlicher Nahkampf und #112 Formationen bleiben eigene Stände. #113 ist ein Ermittlungsentwurf. #115 germanische Krieger, #116 Vegetation und #117 Gesichts-/Fingerrigging benötigen eigene Abnahme. #119 Meshy/Ausrüstung ist ein Bestands- und Werkstattstand. Seine gesperrten Quellen bleiben in seinem Herkunftsregister. #121 besteht zum großen Teil als deterministische Stadtbevölkerung. Eine öffentliche Spielanbindung fehlt, die Budgetprüfung meldete unter gemeinsamer CPU-Last Überschreitungen. #123 bleibt ein eigener Profiling-Stand. Keiner dieser Bestände wurde als fertige Spielfunktion angenommen.

## Werkzeug- und Paketstand

Die installierbare lokale QA ist auf Spielrevision `4c2ad6e` festgelegt. Sie verwendet `at.heinz.imperathen.qa` und eine getrennte QA-Signatur. Ein Update der produktiven App setzt deren ursprüngliche Signatur voraus. Die QA verwendet die freigegebenen Derivate des Originaljungen mit angepasster ACCAD-Aufnahme. Die zivile Variante wurde in Godot sichtbar geprüft und bleibt wegen des Befunds von 24,10 mm Durchdringung an LOD1 bei einer 10-mm-Grenze außerhalb des Pakets. Der private Tempel ist lokal gesichert. Seine etwa 4,67 Mio. Dreiecke in LOD0 benötigen vor Aufnahme eine eigene Android- und Kollisionsabnahme.

Der bisherige Fold7-Bauworkflow des Referenzkandidaten endete vor dem Export. Sein getrennter QA-Lauf erzeugte eine andere, installierbare APK für den automatischen PR-Mergecommit `13836cb8`. Die Build-Fertigstellung gilt für die jeweilige Datei. [Fehlgeschlagener regulärer CI-Lauf](https://github.com/Ullmann27/Imperathen/actions/runs/45786535254) · [Früheres isoliertes QA-Artefakt](https://github.com/Ullmann27/Imperathen/actions/runs/45786535453/artifacts/15101113650)
