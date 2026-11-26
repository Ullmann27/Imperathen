# AAA Visual Quality Directive – 26.11.2026

Status: **Vorgabe des Auftraggebers**, zusätzliche Qualitätsvorgabe. Sie ersetzt weder das Masterhandbuch 3.0 noch die [Fortsetzungsanweisung](GAME_DIRECTION_2026-11-26.md) oder die [erweiterten Entscheidungen](GAME_DIRECTION_2026-11-26_B.md). Die Entscheidungen stehen als D-031 bis D-039 im [Entscheidungsprotokoll](DECISION_LOG.md). Unten folgen der Wortlaut, die Zuordnung zu den Arbeitspaketen und die Grenzen der aktuellen Prüfbarkeit. Die Zuordnung ist Planung, kein Umsetzungsnachweis.

## Wortlaut

> IMPERATHEN – AAA VISUAL QUALITY DIRECTIVE
>
> Technische und grafische Zwischenabnahme durch GPT-6.2
>
> Repository: https://github.com/Ullmann27/Imperathen
> Prüfgrundlage: PR #98, Commit "16a65213", Godot-Renderbilder vom 26.11.2026, CI-Run "45761482750".
>
> Arbeite mit sämtlichen bisherigen Agents und Entwicklungsaufträgen unverändert weiter. Diese Anweisung ist eine zusätzliche Qualitätsvorgabe und ersetzt weder das 311-seitige Masterhandbuch noch die bisherigen Game-Direction-Anweisungen.
>
> Die tatsächlichen Godot-Renderbilder wurden geprüft. Der gegenwärtige grafische Zustand liegt noch deutlich unter unserem angestrebten Qualitätsniveau.
>
> Übernimm bei der weiteren Produktion die Rolle eines leitenden AAA Game Directors, Technical Artists, Environment Artists und Rendering Engineers eines international führenden Spieleentwicklungsstudios.
>
> 1. Gebäude und Architektur
>
> Die derzeitigen Gebäude wirken zu geometrisch, zu sauber, zu gleichförmig und teilweise wie vereinfachte Architekturmodelle.
>
> Überarbeite die vorhandenen Blender-Modelle:
>
> - Realistische Steinstrukturen, Mauerfugen und Putzoberflächen.
> - Abgerundete beziehungsweise gefaste Gebäudekanten.
> - Unterschiedliche Alterungs- und Abnutzungszustände.
> - Dachziegel mit tatsächlicher räumlicher Struktur.
> - Individuelle Fenster, Türen, Beschläge und Holzrahmen.
> - Balkone, Säulen, Treppen, Vordächer und Fassadenschmuck.
> - Unterschiedliche gesellschaftliche Wohlstandsstufen.
> - Glaubwürdige, vollständig eingerichtete Innenräume.
> - Historisch passende Architektur entsprechend der Weltzeit.
>
> Vermeide erkennbare Wiederholungen identischer Gebäude. Erstelle hochwertige modulare Gebäudefamilien, aus denen zahlreiche individuelle Varianten zusammengesetzt werden können.
>
> 2. Straßen und Bodenbeschaffenheit
>
> Das derzeitige Pflaster wirkt teilweise künstlich. Die Fugen sind zu hell und zu dominant.
>
> Erstelle hochwertiges römisches Straßenpflaster mit:
>
> - Unterschiedlichen Steingrößen und Steinformen.
> - Realistischer Fugenbreite und Fugenfarbe.
> - Höhenunterschieden und abgewitterten Kanten.
> - Staub, Erde, Moos und vereinzeltem Pflanzenbewuchs.
> - Materialabhängigen Normal-, Roughness- und Height-Maps.
> - Organischen Übergängen zwischen Straßen, Gehwegen, Erde und Gebäuden.
> - Nässe und Pfützen bei entsprechenden Wetterbedingungen.
>
> Die Straßen müssen auch aus unmittelbarer Kameranähe hochwertig wirken. Bodengeometrie, Kollision und Darstellung müssen übereinstimmen.
>
> 3. Beleuchtung und Rendering
>
> Die aktuelle Beleuchtung wirkt zu flach. Teilweise erscheinen Oberflächen überbelichtet und besitzen zu wenig räumliche Tiefe.
>
> Überarbeite das vollständige Beleuchtungssystem:
>
> - Physikalisch plausible Sonnenbeleuchtung.
> - Glaubwürdige indirekte Beleuchtung.
> - Realistische Kontakt- und Gebäudeschatten.
> - Atmosphärische Tiefenwirkung.
> - Filmisches Color Grading.
> - Kontrollierte Belichtung und geeigneter Tonemapper.
> - Dynamische Tageszeiten.
> - Sonnenaufgänge und Sonnenuntergänge.
> - Fackel-, Kerzen- und Feuerbeleuchtung.
> - Wetterabhängige Lichtverhältnisse.
> - Volumetrische Effekte, sofern das Grafikprofil diese effizient unterstützt.
>
> Prüfe die tatsächlichen Möglichkeiten von Vulkan Mobile und Forward+ gegenüber dem bestehenden Compatibility-Renderer. Ein Rendererwechsel darf erst nach reproduzierbaren Vergleichstests erfolgen.
>
> Ziel ist eine natürliche, filmische Darstellung und nicht lediglich eine Erhöhung von Helligkeit, Kontrast oder Farbsättigung.
>
> 4. Menschen und Charaktere
>
> Unser Originaljunge besitzt bereits eine deutlich weiter entwickelte visuelle Grundlage als viele andere Figuren.
>
> Erhalte seine Identität und sämtliche bisherigen MoCap-Verbesserungen. Erstelle eine glaubwürdige zivile Kleidungsvariante ohne Rüstung und Waffen für den Kampagnenbeginn.
>
> Hebe anschließend sämtliche Erwachsenen, Soldaten und Bewohner auf einen vergleichbaren Qualitätsstandard.
>
> Verbindliche Anforderungen:
>
> - Anatomisch korrekte Körper.
> - Individuelle Gesichter und Körperproportionen.
> - Realistische Haut, Haare, Augen und Bärte.
> - Unterschiedliche Altersstufen.
> - Vollständige Skelette mit einzeln animierbaren Fingern.
> - Gesichtsanimationen und phonembasierte Mundsynchronisation.
> - Natürliche Blickbewegungen und Blinzeln.
> - Atmung, Gewichtsverlagerung und spontane Gestik.
> - Glaubwürdiger Bodenkontakt.
> - Korrekte Handpositionen beim Greifen von Gegenständen.
> - Kleidung mit glaubwürdigen Falten und Bewegungen.
> - Keine sichtbaren Mesh-Durchdringungen.
>
> Nutze Blender, Meshy, Motion Capture, Retargeting, inverse Kinematik und geeignete weitere Produktionswerkzeuge.
>
> Erstelle bei neuen Charakteren unmittelbar das zugehörige Skelett, die notwendigen Animationen und die jeweiligen Detailstufen. Modelle ohne funktionierende Animationen gelten nicht als vollständig produziert.
>
> 5. Lebendige Stadtbevölkerung
>
> Die derzeitige Bevölkerungsdichte entspricht noch nicht einer glaubwürdigen römischen Großstadt.
>
> Entwickle eine lebendige Bevölkerung mit:
>
> - Händlern und Handwerkern.
> - Familien und Kindern.
> - Soldaten und Wachen.
> - Reisenden und wohlhabenden Bürgern.
> - Menschen unterschiedlicher Herkunft.
> - Arbeitern und gesellschaftlich benachteiligten Bewohnern.
> - Tieren, Pferden und Transportwagen.
>
> NPCs sollen miteinander sprechen, einkaufen, arbeiten, essen, ihre Häuser betreten, Freundschaften pflegen und auf Ereignisse reagieren.
>
> Sie dürfen nicht lediglich zufällig durch Straßen laufen. Jeder relevante Bewohner benötigt einen nachvollziehbaren Lebenszusammenhang.
>
> Skaliere die Bevölkerungsdarstellung entsprechend Entfernung und Grafikprofil. Die zugrunde liegende Weltpopulation muss unabhängig von der sichtbaren Darstellung konsistent bleiben.
>
> 6. Vegetation und Landschaft
>
> Die Vegetation ist derzeit noch zu vereinfacht.
>
> Erstelle hochwertige Bäume, Sträucher, Gräser, Blumen, Nutzpflanzen und Wälder.
>
> Achte besonders auf:
>
> - Natürliche Baumstämme und Rindenstrukturen.
> - Verzweigte Äste.
> - Individuelle Blattstrukturen.
> - Windbewegungen.
> - Unterschiedliche Pflanzenhöhen und Wachstumsformen.
> - Historisch und geografisch passende Pflanzenarten.
> - Organische Waldränder und Landschaftsübergänge.
> - Flüsse, Seen, Wasserfälle und glaubwürdige Wasseroberflächen.
> - Berge, Hügel, Täler und weitreichende Sichtachsen.
>
> Vermeide künstlich wirkende, gleichmäßig verteilte Vegetation.
>
> Die Open World muss langfristig eine gewaltige zusammenhängende Landschaft ergeben und über Italien hinaus in weitere europäische Regionen wachsen können.
>
> 7. Benutzeroberfläche und Spielerlebnis
>
> Das gegenwärtige HUD wirkt noch zu technisch und beansprucht zu viel Bildschirmfläche.
>
> Entwickle eine eigenständige hochwertige Benutzeroberfläche mit römischer Identität:
>
> - Dezente Missionsanzeigen.
> - Kompakter Kompass und Orientierungssystem.
> - Dynamisch ein- und ausblendbare Informationen.
> - Kontextabhängige Interaktionen.
> - Hochwertige Inventar- und Ausrüstungsansichten.
> - Charakterentwicklung und Fähigkeiten.
> - Handels- und Verwaltungsmenüs.
> - Filmisch gestaltete Dialogentscheidungen.
> - Flüssige Menüanimationen.
> - Optimierte Touchsteuerung für das Galaxy Z Fold7.
> - Unterstützung unterschiedlicher Bildschirmformate.
> - Lesbare und skalierbare Bedienelemente.
>
> Das HUD darf die Immersion nicht zerstören. In ruhigen Erkundungsabschnitten soll möglichst viel von der eigentlichen Spielwelt sichtbar bleiben.
>
> 8. Kampf und filmische Qualität
>
> Übertrage die bisherigen Animationsverbesserungen auf das vollständige Kampfsystem.
>
> Orientiere dich qualitativ an Ryse: Son of Rome, Assassin’s Creed Valhalla und Mount & Blade II: Bannerlord, ohne deren geschützte Inhalte zu übernehmen.
>
> Erforderlich sind:
>
> - Flüssige Übergänge zwischen Bewegung, Angriff und Verteidigung.
> - Glaubwürdige Schildführung.
> - Individuelle Trefferreaktionen.
> - Materialabhängige Treffergeräusche.
> - Funken, Staub und situationsabhängige Partikeleffekte.
> - Realistische Waffenhaltung.
> - Körperliche Wucht.
> - Individuelle Kampfstile unterschiedlicher Krieger.
> - Dynamische, kontrollierbare Kameraführung.
> - Synchronität zwischen sichtbarer Animation, Treffer und Sound.
>
> Filmsequenzen müssen dieselben Charaktere, Kleidungsvarianten und Weltzustände verwenden wie das tatsächliche Spiel. Stimme, Mimik, Gestik, Kameraführung, Musik und Umgebung sollen gemeinsam eine glaubwürdige Kinofilmwirkung erzeugen.
>
> 9. Vier deutlich unterscheidbare Grafikprofile
>
> Profil| Produktionsziel
> Leicht| Leistungsorientiert bei erhaltener Spielmechanik
> Ausgewogen| Hochwertige, nachhaltig spielbare Grafik auf dem Fold7
> Hoch| Detaillierte Grafik für leistungsfähige Geräte und Gaming-PCs
> Sehr hoch| Maximaler grafischer Qualitätsanspruch für leistungsfähige PCs
>
> Die Grafikprofile müssen sich tatsächlich in Texturauflösung, geometrischer Detailtiefe, Beleuchtung, Schatten, Vegetationsdichte und weiteren grafischen Eigenschaften unterscheiden.
>
> Hoch und Sehr hoch dürfen wesentlich höhere Hardwareanforderungen besitzen.
>
> Es gibt keine künstliche Begrenzung der gesamten installierten Spielgröße. Hochwertige Originalassets müssen erhalten bleiben. Optimiere Laufzeitressourcen durch Streaming, LOD, Instancing, Culling, Texturkompression und getrennte Grafikpakete.
>
> 10. Aktuelle technische Beanstandungen
>
> Berücksichtige zusätzlich die jüngsten GitHub-Prüfergebnisse:
>
> - JSON-Parserfehler in NPC-, Inventar- und Präsentationsprüfungen untersuchen.
> - Die noch offenen Motion-Gate-Befunde systematisch bearbeiten.
> - Die separate Kalenderarchitektur in den gemeinsamen Weltzustand integrieren.
> - Sämtliche laufenden Arbeitsbranches kontrolliert zusammenführen.
> - Keine älteren Reparaturen durch neue Integrationen verlieren.
> - Tatsächliche Leistung auf dem Fold7 messen und nicht aus Cloud- oder Desktopwerten ableiten.
>
> Keine Qualitätsgrenzwerte abschwächen, um grüne Tests zu erzwingen.
>
> 11. Verbindliche grafische Abnahme
>
> Erstelle für jeden größeren Produktionsabschnitt tatsächliche Blender- und Godot-Rendernachweise.
>
> Verwende identische Kamerapositionen für Vorher-Nachher-Vergleiche und dokumentiere:
>
> - Quellcommit.
> - Verwendetes Grafikprofil.
> - Tatsächlich geladene Modelle.
> - Texturen und Materialien.
> - Beleuchtung und Renderer.
> - Sichtbare Qualitätsverbesserungen.
> - Speicherverbrauch.
> - Gemessene Leistung.
> - Verbleibende Fehler.
>
> Vergleiche diese Aufnahmen mit unseren zehn Zielbildern. Konzeptbilder dürfen niemals als tatsächliche Ingame-Grafik ausgegeben werden.
>
> 12. Selbstständige Fortsetzung
>
> Arbeite eigenständig und mit sämtlichen bisherigen Agents weiter.
>
> Denke bei jeder Implementierung mindestens drei Ebenen voraus:
>
> 1. Unmittelbare Funktion und visuelle Qualität.
> 2. Auswirkungen auf andere Spielsysteme.
> 3. Langfristige Skalierbarkeit und Weiterentwicklung.
>
> Übernimm nicht lediglich diese einzelnen Beanstandungen. Untersuche selbstständig weitere erkennbare Schwächen und entwickle geeignete Lösungen.
>
> Das angestrebte Ergebnis ist ein außergewöhnlich hochwertiges, lebendiges, historisches Open-World-Spiel mit filmischer Inszenierung, glaubwürdigen Menschen und langfristig erweiterbarer Welt.
>
> Dokumentiere sämtliche tatsächlichen Ergebnisse im Übergabebericht #96 und in den jeweiligen Pull Requests.
>
> Wichtig: Unterbrich deine bisherigen Arbeiten nicht. Diese Beanstandungen dienen der zusätzlichen Präzisierung unseres Qualitätsanspruchs. Fable 5.2 wird erst nach einer gesonderten Zwischenabnahme eingesetzt.

## Zuordnung zu Arbeitspaketen (Stand 26.11.2026, 06:10 UTC)

| Punkt | Arbeitspaket (Branch) | Stand |
|---|---|---|
| 1 Gebäude | `feat/architecture-families-20261126` (neu: modulare Gebäudefamilien in Blender, Fasen, Ziegelgeometrie, Wohlstandsstufen); `fix/city-ground-walls-20261126` (Reparaturen Stadt); `feat/house-interiors-detail-20261126` (Innenräume) | neu beauftragt / in Arbeit |
| 2 Straßen | `feat/architecture-families-20261126` (Pflaster als Material- und Geometriefamilie); Stadtreparatur für Boden-Kollision | neu beauftragt |
| 3 Licht und Renderer | `feat/village-lookdev-20261126` (Licht, Material, Atmosphäre Valdora); `feat/render-profiles-study-20261126` (neu: reproduzierbarer Vergleich Compatibility / Mobile / Forward+, Grafikprofile) | in Arbeit / neu beauftragt |
| 4 Menschen | `feat/youth-civil-clothing-20261126` (neu: zivile Kleidung des Originaljungen ohne Rüstung und Waffe); `feat/people-detail-realism-20261126`; `feat/germanic-warrior-families-20261126` | neu beauftragt / in Arbeit |
| 5 Stadtbevölkerung | nach dem NPC-Persönlichkeitskern (D-016) und dem Bewohnermodell (D-018); Weltpopulation unabhängig von sichtbarer Darstellung | geplant |
| 6 Vegetation | `feat/vegetation-20261126` (neu: Bäume, Sträucher, Gräser, Wind, Artenliste Oberitalien 58 v. Chr.); `fix/village-backdrop-terrain-20261126` | neu beauftragt / in Arbeit |
| 7 HUD | `feat/roman-hud-20261126` (neu); ruhiges Kinder-HUD bereits in `feat/i01-three-cups-slice-20261126` | neu beauftragt / in Arbeit |
| 8 Kampf | `feat/melee-combat-core-20261126`, `feat/formation-movement-20261126`, `feat/troops-command-core-20261126`, `fix/village-raid-approach-20261126` | in Arbeit |
| 9 Grafikprofile | `feat/render-profiles-study-20261126` | neu beauftragt |
| 10 Technik | JSON-Parserfehler: Ursache in #87 (`youth_sole_contact.gd`), Korrektur 89e735d; Motion-Gate: `feat/motion-gate-blockers-20261126` (neu); Kalender in den Weltzustand: Integrationsschritt des Leads nach #98 und der Stammeswelt (gemeinsame Schemaanhebung); kontrollierte Zusammenführung: Integrationsbranch mit Volltest und Motion-Gate, kein Main-Merge | in Arbeit |
| 11 Abnahme | Nachweisschema für jeden Abschnitt (unten) | verbindlich |

## Nachweisschema je Produktionsabschnitt (D-038)

Jede Rendernachweisdatei nennt: Quellcommit, Grafikprofil, Renderer und Treiber (llvmpipe/lavapipe sind Software-Renderer), Auflösung, tatsächlich geladene Modelle und Texturen mit Prüfsumme, Beleuchtung, identische Kameraposition vorher/nachher, Speicherverbrauch, gemessene Leistung mit Messumgebung, sichtbare Verbesserungen und verbleibende Fehler. Zielbilder (`docs/34_uebergabe_gpt_fable/zielbilder/`) sind Konzeptbilder und werden nur zum Vergleich daneben gestellt.

## Grenzen der Prüfbarkeit

- Kein Fold7 im Zugriff: Leistung auf dem Gerät wird nicht aus Desktop- oder Cloudwerten abgeleitet. Ohne Gerätemessung bleibt jede Fold7-Aussage offen.
- Renderer-Vergleich in der Cloud: Vulkan nur über lavapipe (Software). Er zeigt Bildunterschiede und Funktionsumfang, nicht die Mobil-GPU-Leistung. Ein Rendererwechsel setzt zusätzlich eine Gerätemessung voraus.
- Stimmen und Mundsynchronisation: Keine lokale Sprachsynthese installiert, kostenpflichtige Stimmdienste sind ohne Freigabe ausgeschlossen. Phonembasierte Mundsynchronisation kann aus Text und Zeitmarken vorbereitet, aber ohne Tonspur nicht abgenommen werden.
- Meshy und andere kostenpflichtige Dienste nur nach ausdrücklicher Freigabe von Umfang und Kosten.
