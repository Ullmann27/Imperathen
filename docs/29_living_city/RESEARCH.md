# Lebendige Stadt – Stand, Technik und Quellen (26.11.2026)

## Stand (ehrlich getrennt)

**Implementiert und getestet (Gruppe `city_life`, 88 Prüfungen, Desktop-CPU, headless):**
- Aktivitätsanker: Schema, Lader, Validator (`prototype/scripts/domain/city_anchors.gd`), Epochenfilter ohne Jahr 0, Öffnungszeiten, Wohlstandsstufen, `requires_node:`-Tag. 591 gebackene Anker in `prototype/assets/city/activity_anchors/`.
- Bake aus dem gebauten Stadtmodell (`tools/world/bake_city_layout.gd`): Anker und Fußgängergraph (6199 Knoten, Kanten per Raycast gegen die Kollision geprüft, Türöffnungen der 240 Häuser gemessen).
- Bevölkerung (`city_population.gd`): 2095 Bewohner, 480 Haushalte, 120 Betriebe; Alter, Herkunft, Beruf, Arbeitsplatz, Wohlstand, Beziehungen über `actor_relations.gd`.
- Lebenssimulation (`city_life.gd`): ereignisgesteuert, deterministisch, speicherbar; Tagesablauf, Einkauf mit Feilschen, Gespräche, Lieferungen durch Träger, Wachen, Wetter- und Alarmreaktionen, Tagesabschluss (Löhne, Miete, Preise, Produktion), Stellenwechsel, Heirat mit Umzug.
- Hauptbuch: Geld und Waren bleiben nachweislich erhalten (`audit()`).
- Gesprächs-/Rufschnittstelle (`city_barks.gd`, `assets/city/barks/city_barks.json`) passend zum NPC-Stimmpool.

**Nicht implementiert (offen für die Nachfolge):**
- Sichtbare Menge (Streaming, Crowd-LOD, Erscheinungsbild), Einbindung in `city_exploration.gd`, Positionsaudio, Render-Nachweise, Messung je Grafikprofil, Durchlauftest in der 3D-Szene.
- Kopplung an `city_market_bridge.gd` (`record_player_trade` existiert, wird noch nicht aufgerufen).
- Aggregierter Mehrtages-Vorlauf für lange Abwesenheit.
- Stimmen: alle Zeilen sind reiner Text (`voiced=false`), bis die Aufnahmen des Stimmpools vorliegen.
- Motion-Gate und vollständige Regression wurden auf diesem Branch nicht ausgeführt.

**Bekannte Mängel:** einzelne `advance_to`-Aufrufe bis ca. 6 ms bei 0,5 ms Budget (Desktop, gemessen) – Ursache noch nicht eingegrenzt; Exportmengen der Werkstätten sind unausgewogen; Pferde-, Karren- und Kindermodelle fehlen im Repository.

**Offene Entscheidung des Auftraggebers:** Darstellung der Abhängigen wohlhabender Haushalte (historisch überwiegend Versklavte); derzeit neutrales Datenfeld `dependent`.

## Technik und Quellen

Recherche vom 26.11.2026; jede URL wurde abgerufen. Bei GDC-Vault-Seiten wurden nur Titel und Übersicht geprüft.

| Thema | Umsetzung hier | Quelle |
|---|---|---|
| Utility-Bewertung | Freizeitwahl nach Bedürfnis, Angebot und Bekannten vor Ort | Graham, „An Introduction to Utility Theory“, Game AI Pro 1: http://www.gameaipro.com/GameAIPro/GameAIPro_Chapter09_An_Introduction_to_Utility_Theory.pdf · Dill, „Dual-Utility Reasoning“, Game AI Pro 2: http://www.gameaipro.com/GameAIPro2/GameAIPro2_Chapter03_Dual-Utility_Reasoning.pdf |
| Zeitplan statt Planer | Rollen mit Tagesblöcken, Entscheidung nur am Ende einer Tätigkeit | Zubek, „1000 NPCs at 60 FPS“, Game AI Pro 3: http://www.gameaipro.com/GameAIPro3/GameAIPro3_Chapter34_1000_NPCs_at_60_FPS.pdf · Orkin, „Three States and a Plan“: https://www.gamedevs.org/uploads/three-states-plan-ai-of-fear.pdf |
| Smart Objects / Anker | Anker mit Plätzen, Zeiten, Epoche | de Sevin u. a., „Smart Zones to Create the Ambience of Life“, Game AI Pro 2: http://www.gameaipro.com/GameAIPro2/GameAIPro2_Chapter11_Smart_Zones_to_Create_the_Ambience_of_Life.pdf · Smrcek, GDC 2026 (KCD): https://gdcvault.com/play/1035718/Supporting-Thousands-of-NPCs-in |
| Simulations-LOD | Position als reine Funktion der Zeit auf dem Straßengraphen; Verkörperung nur in der Nähe | Iassenev-Interview (A-Life): https://www.gamedeveloper.com/game-platforms/interview-inside-the-ai-of-i-s-t-a-l-k-e-r-i- · Sunshine-Hill, „LOD Trader“: http://www.gameaipro.com/GameAIPro/GameAIPro_Chapter14_Phenomenal_AI_Level-of-Detail_Control_with_the_LOD_Trader.pdf |
| Barks | Ereignis → Zeilen nach Thema und Beziehung | Ruskin, GDC 2012: https://www.gdcvault.com/play/1015528/AI-driven-Dynamic-Dialog-through · Skubch, Game AI Pro 3: http://www.gameaipro.com/GameAIPro3/GameAIPro3_Chapter35_Ambient_Interactions_Improving_Believability_by_Leveraging_Rule-Based_AI.pdf |
| Navigation | AStar3D auf gebackenem Graphen; NavigationAgent/RVO erst für sichtbare Figuren vorgesehen | https://docs.godotengine.org/en/stable/classes/class_astar3d.html · https://docs.godotengine.org/en/stable/tutorials/navigation/navigation_optimizing_performance.html |
| Crowd-Rendering (geplant) | nah Skelett, fern MultiMesh | https://docs.godotengine.org/en/stable/tutorials/performance/using_multimesh.html |

## Nächste Schritte

1. `CityLifeWorld`-Knoten: `advance_to` je Frame mit Budget, Bewohner im Umkreis über `position_of`/`trip_path` verkörpern, `events_since` für Gespräche und Käufe.
2. `city_market_bridge.execute` → `record_player_trade`.
3. Lastspitze in `advance_to` messen und beheben; Mehrtages-Vorlauf.
4. Stimmen-Branch mergen, sobald Aufnahmen vorliegen; `Barks.recording_list()` liefert die Aufnahmeliste.
5. Nach jedem Stadtumbau `bake_city_layout.gd` erneut ausführen.
