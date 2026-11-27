# IMPERATHEN – 30 verbindliche visuelle und spielerische Meilensteine

Stand: 27.11.2026. Abgeleitet aus den Nutzeraufnahmen I00–I04, VIS-001–015, dem REALISM QUALITY GATE und der chronologischen Campaign Journey. Keine private Aufnahme wird in GitHub veröffentlicht. Die genaue Quellrevision der Nutzer-APK ist nicht belegt; Reproduktionsbasis für diesen Durchlauf ist Preview 1327bd623dc5a67ce1b3611a743b481addd8bf26.

Die Reihenfolge priorisiert kritische Fehler der ersten spielbaren Storysequenzen; die übrigen 90 Kimi- und 122 Journey-Aufgaben bleiben erhalten. Separate Taskbranches und aktive Edit-Leases beachten. Status: QUEUED, CANDIDATE, ENGINE_PASS, REVIEW_PENDING, DEVICE_PENDING, BLOCKED, ACCEPTED. ENGINE_PASS ist kein visueller PASS. Jeder Meilenstein erhält bei Änderung exakten Commit, Run, Prüfergebnis, V1/V2-Belege (bei Grafik), verbleibende Defekte und Gerätebefund. Keine Fortschrittsprozente aus Testzahlen. Nicht freigeben, bevor die jeweilige Abnahme tatsächlich vorliegt.

| ID | Meilenstein / messbarer Liefergegenstand | Status / bisheriger Beleg |
|---|---|---|
| M01 | 15 Nutzerfehlergruppen und konkrete Abnahmekriterien versioniert; unbekannte APK-Revision und sachfremdes Bild ausdrücklich getrennt | ENGINE_PASS (Dokumentationsziel erfüllt, [#186](https://github.com/Ullmann27/Imperathen/pull/186)); keine visuelle Freigabe |
| M02 | Dialogkamera nutzt echte Augenanker von Erwachsenen und Jugendlichen; bisherige Achsen-, Fallback- und Lifecycle-Tests erhalten | ENGINE_PASS 368/368, [46061403644](https://github.com/Ullmann27/Imperathen/actions/runs/46061403644); visuelle Prüfung offen |
| M03 | Prolog-Lager vollständig über realem regionalen Terrain; Bodenübergang ohne Änderung der Weltphysik; tatsächliche Mesh-Vertizes geprüft | CANDIDATE: isolierter I00-Terrain-Patch, neue Tests, noch kein CI-Ergebnis |
| M04 | 5 historische Einstellungen × 3 Zeitpunkte × 2 Bildschirmformate; Zielprojektion der Feldzeichen, Kommandeure und Formationen, SHA256 und Renderbeleg | CANDIDATE: i00_terrain_capture_test.gd; tatsächliche Prüfung ausstehend |
| M05 | Keine leeren Wiesen in Legionen-/Abmarsch-Einstellungen; alle drei Blöcke in jeder entsprechenden Sequenz erkennbar | QUEUED: M03–04 als Reproduktion; Kameraframing mit bestehendem #186 koordinieren |
| M06 | Sichtlinien gegen Wände, Mobiliar und Darsteller; sichere Ausweichkamera statt Nahaufnahme in einem Körper | QUEUED: reale Bildsequenz und dynamische Okklusions-Negativkontrolle |
| M07 | I01-Familienkrug: gemessener Henkel bei leer/gefüllt/späterer Vaterübergabe und nach LOD, 2 mm Ankertoleranz | CANDIDATE [#188](https://github.com/Ullmann27/Imperathen/pull/188), [46063412333](https://github.com/Ullmann27/Imperathen/actions/runs/46063412333) |
| M08 | I03-Marktkrug: 5 mm Griffanker vor/nach LOD, bei aufeinanderfolgenden Physikframes und korrektem Loslassen | CANDIDATE [#189](https://github.com/Ullmann27/Imperathen/pull/189); [46062934470](https://github.com/Ullmann27/Imperathen/actions/runs/46062934470) war mit 54.444 mm fehlerhaft |
| M09 | Durchgängige physische Finger-/Handflächenkontakte und Wrist-/Finger-IK bei Krug, Korb, Becher; keine Mesh-Durchdringung | QUEUED: Kontaktanker allein reicht nicht |
| M10 | Jugend-Armoberflächen: echte zivile LODs, Haut-/UV-/Maskierungs-/Mesh-Seam-Diagnose und reale Nahaufnahmen | QUEUED: Originale im autorisierten Asset-Staging, keine Ersatzmodelle |
| M11 | Reparierte Jugend-Arme: keine sichtbaren Risse, verschwindenden Flächen oder Clipping bei Tragen/Gehen/Kampf; bestehende Fußgrenzen erhalten | QUEUED: abhängig von M10 |
| M12 | Julias Kleid: bisherige 10-mm-Grenze bei sämtlichen geprüften Posen einschließlich Sturz und LOD 0–3 | QUEUED: unabhängige Blender-/Godot-Messung, keine Grenzwertsenkung |
| M13 | Julia und Silvanus: eigenständige Anatomie, individuelle Identität, überprüfter GLB/Rig/Material-Import im tatsächlichen Spiel | REVIEW_PENDING: [#154](https://github.com/Ullmann27/Imperathen/pull/154), finale Integration und Abnahme offen |
| M14 | Gleiche Figurenqualität von Familie, Marcus, Cassia, Aurelia und Sextus bei vergleichbaren Licht-/Kamerabedingungen | QUEUED: individuelle Identitäten, echte Detailrender V1/V2 |
| M15 | Natürliches Blick-, Gesichts- und Gestenverhalten in Dialogen, Sprecherwechsel und Reaktionen ohne starre Puppenpose | QUEUED: kontinuierliche Filmaufnahme, keine alleinige Standbildprüfung |
| M16 | Prolog: echte römische Feldzeichen und historisch plausibel dargestellte Legionäre statt Nahbereichs-Proxy; tatsächliche Asset-IDs/LOD sichtbar | REVIEW_PENDING: vorhandene Standarte und Nahmodelle; sichtbare Qualität noch abgelehnt |
| M17 | Prolog: belebtes Lager mit logisch angeordnetem Gepäck, Versorgung, Zeltbetrieb und stimmigen Aufgaben, ohne neue kanonische Fakten | QUEUED: echte Szenen- und Performanceprüfung |
| M18 | Regen, Wolken, Materialnässe, Pfützen und Bodenkontakt mit korrekten Übergängen und begrenzten Licht-/Partikelbudgets | QUEUED: aktuelle Wetterfehler separat erfassen |
| M19 | Frühstücksszene: tatsächliche Sitz-/Stand-/Essbewegungen, Blickachsen und drei sichtbare Becher bei richtiger Handhabung | QUEUED: I01-Simulation und Dialogpfade erhalten |
| M20 | Familienhaus: glaubwürdige Haushaltsobjekte, Werkzeuge, Licht, Dach-/Wanddetails und freie Wege | QUEUED: individuelle Einrichtung, echte Innenraumbegehung |
| M21 | I02 Korb: aufheben, richtig tragen, zeigen und übergeben, sichtbare Übereinstimmung mit Storyzustand; Save/Load | QUEUED: keine Phantomgegenstände |
| M22 | I03 Münzen und Topf: Marcus trägt die genannten Gegenstände, Cassias Stand zeigt Transaktion und korrekten Besitzwechsel | QUEUED: echte Requisiten-Inserts statt Rumpfaufnahme |
| M23 | Schmiede I04: Sextus arbeitet glaubwürdig, Werkzeugkontakt, Animationen, Beleuchtung und richtige Kamera; Gameplay anschließen | QUEUED: filmische und funktionale Regressionsprüfung |
| M24 | UI: sichere Bildflächen für Gesicht, Hände und Dialog, keine störenden 3D-Labels, Hoch-/Querformat vollständig bedienbar | QUEUED: konkrete Touch-/UI-/Renderabnahme |
| M25 | Welt: natürliche Terrain-, Vegetations- und Materialübergänge; kein schwebendes/versunkenes Objekt; bestehende Streamingbudgets | QUEUED: reale Bilder, Kollision, Profilvergleiche |
| M26 | Nacht und Dämmerung: Wege, Häuser, Fackeln/Öllampen und Pferd lesbar, korrektes Lichtbudget | QUEUED: K07–K12 beibehalten, reale Nachtcaptures |
| M27 | Militär: bestehende 60/180-Soldaten-Formationstests ohne Fuß-/Phasensprünge oder Positionsfehler; echte Varianten | QUEUED: keine abgesenkten Grenzwerte |
| M28 | Valdora: organische, nicht angekündigte Nebenaufträge aus NPC-Bedürfnissen; persistente Entscheidungen und Wirtschaft | QUEUED: zunächst kleiner vollständiger Interaktionspfad mit Save/Load und ohne erzwungene Kartenmarkierung |
| M29 | Zusammenhängender Spielablauf New Life bis I04, echte Spiel-/Filmaufnahmen und alle relevanten funktionalen Regressionen in EINER gepinnten Revision | QUEUED: disjunkte geprüfte Änderungen zusammenführen, keine isolierten Tests als Integration ausgeben |
| M30 | Signierter Android-Prüfkandidat der zusammengeführten Revision; physische Fold7-Abnahme in High/Very High, Touch, Frame-Pacing, thermische Stabilität, unabhängiger visueller Vergleich | DEVICE_PENDING: kein ungeprüfter Release |

## Nächste Ausführung

M03–04 tatsächlich prüfen; neue Render- und Frustumbefunde unabhängig gegen Nutzeraufnahmen beurteilen. M07–08 prüfen, keine Kontaktgrenze lockern. M05–06 erst nach konfliktfreier Abstimmung der aktiven Kamera-Edit-Lease. M09–11 benötigen echte Rig-/Skin-/Objektmessung und reale Bildbelege; bloße Skelett-Node-Prüfung genügt nicht. M12–14 vorhandene Blender-Kandidaten vor Neuerstellung prüfen. Die bestehende stündliche Koordination soll dieses Ledger fortschreiben, ohne doppelte Modell-/CI-Aufträge. Keine API-Kosten, Secret- oder Rechteeskalation.

