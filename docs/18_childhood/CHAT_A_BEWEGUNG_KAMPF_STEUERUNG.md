# Folgechat A – Bewegung, Kampf und Android-Steuerung

Kopiere den folgenden Auftrag vollständig in einen neuen Chat mit GitHub-Zugriff.

---

Du arbeitest am bestehenden Spiel **IMPERATHEN**, GitHub-Repository **Ullmann27/Imperathen**, im Auftrag von Heinz. Arbeite mit **genau drei tatsächlichen Arbeitsagenten** und übernimm selbst die Integration. Falls diese Funktion nicht verfügbar ist, sage das offen; simuliere keine Agenten und erfinde keine Testergebnisse.

## Ausgangspunkt und Zusammenarbeit

Das ist ein Entwicklungsauftrag am vorhandenen Godot-Spiel, kein Auftrag zu einem neuen Spiel oder einer bloßen Konzeptantwort. Android ist das erste Ziel. Das Repository bleibt öffentlich. Eigener Code, Blender-Arbeit, Tests, ein eigener Arbeitsbranch, Draft-PR und eine geprüfte Android-Testfassung sind erlaubt. Kein Merge nach main, kein Store-Release, keine kostenpflichtigen Dienste oder Assetkäufe.

Der letzte vor diesem Umbau bestätigte Stand ist f2900eb86b90b185627dcd490fef550fd0cbed11; die zuvor gelieferte APK basiert auf e1b1c1fb16d63056e4eb80891d84ed75c79b4ed6. **Diese alten Nachweise belegen deine Änderungen nicht.** Der koordinierende Chat baut gerade den Dorf- und Kindheitsanfang auf dem Arbeitszweig feature/childhood-village-20261123 um. Prüfe zuerst den tatsächlichen aktuellen Remote-Stand, offene PRs, AGENTS.md, docs/18_childhood und den aktuellen Lieferbericht. Falls der Zweig noch nicht verfügbar ist, lies den vorhandenen Code und kennzeichne die fehlende neue Grundlage, bevor du Integrationsdateien bearbeitest.

Erstelle einen eigenen isolierten Branch für Chat A. Bewahre fremde Änderungen. Stimme Dateizuständigkeiten anhand der vorhandenen Übergaben ab. Dieser Chat besitzt Figurenbewegung, Kampfdarstellung und Touchsteuerung. Der andere Folgechat besitzt Geschichte, Dorf und Alltagswirtschaft. Änderungen an gemeinsamem Weltmodell, main.gd, game_world.gd und Speicherschema als kleine klar bezeichnete Integrationspatches liefern; keine konkurrierende Gesamtrewrite.

## Spielerwunsch

Die Arme dürfen im normalen Stand nicht unnatürlich nach vorne zeigen. Beim Gehen sollen Arme und Beine gegensinnig arbeiten, Hüfte, Rücken, Schultergürtel und Kopf glaubwürdig mitgehen. Die Figur soll ruhig stehen, Gewicht verlagern und in normalem Schritttempo gehen können. Gehen, Laufen, Anhalten, Drehen und Richtungswechsel müssen auseinanderzuhalten sein. Joystickauslenkung und Körperbewegung müssen zusammenpassen; keine gleitenden Füße.

Heinz nennt Assassin’s Creed Valhalla, GTA VI und Ghost Recon Wildlands als Referenzen für Gewicht, Lesbarkeit, Kamera und Bediengefühl. Prüfe offizielle Materialien. Behaupte keine exakten Geschwindigkeiten dieser Spiele ohne verlässliche Messung. Übernimm keine fremden Modelle, Animationen, Musik oder Markeninhalte.

Die zwölfjährige Figur soll grundlegende unbewaffnete Techniken üben und einsetzen können: gerade Faustschläge, linker/rechter Haken, linker/rechter Uppercut, Kopfstoß, Frontkick, Sidekick und Highkick. Ausbildung verbessert Kontrolle und Können. Kinderkörper dürfen nicht bloß verkleinerte erwachsene Soldaten sein. Später folgt eine ausdrücklich erworbene Schwert-/Schildausrüstung mit Seitenhieb, Frontstoß und Schildabwehr. Ohne Ausrüstung dürfen keine Waffenaktionen vorgetäuscht werden.

## Verteile die Arbeit auf drei Agenten

**Agent 1 – Anatomie und Fortbewegung:** Prüfe die tatsächlichen Bindeposen und Knochenachsen in Blender und Godot, nicht nur Rotationszahlen im Skript. Korrigiere Ruhehaltung, Hand-/Fingerhaltung, Schrittlänge, Bodenkontakt, Schulter-/Hüftrotation, Kopf und Bremsen. Erstelle reproduzierbare Ansichten und kurze echte Engine-Aufnahmen. Erhalte unterschiedliche Gesichter und Körperproportionen. Prüfe LOD-Wechsel und Schatten auf Sprünge.

**Agent 2 – Kampfsystem und Treffer:** Verbinde jede Technik mit einer unterscheidbaren Bewegung und klaren Phasen: Vorbereitung, aktives Trefferfenster, Erholung. Reichweite, Richtung, Hindernisse, Ausdauer, Unterbrechung und Zielzustand müssen geprüft werden. Ein Schlag außerhalb der Reichweite darf keinen Schaden buchen. Ein Angriff trifft nicht mehrfach durch dieselbe Animation. Körper dürfen nicht ineinander gleiten. Übung und tatsächlicher Treffer bleiben getrennt. Arbeite mit der vorhandenen autoritativen Befehls- und Speicherstruktur; keine reine Animation mit erfundenem Kampferfolg.

**Agent 3 – Touch, Kamera und Prüfung:** Größeres, höher platziertes Steuerfeld mit großzügiger Trefferfläche, zuverlässige gleichzeitige Bewegung/Kamera/Aktion, klare Icons mit kurzen Beschriftungen und verständlich angeordnete Kampfaktionen. Gehen/Laufen müssen erreichbar sein. Auf kleinen und aufgeklappten Displays dürfen sich Steuerfeld, Aktionsleisten, Kompass, Auftrag und Dialoge nicht verdecken. Prüfe echte Touch-Ereignisse, Abbruch bei Pause/Hintergrund und Rückkehr. Kein technischer Debugtext im normalen Spielfluss.

## Abnahme und Lieferung

Führe einen zusammenhängenden Weg aus: neuer Dorfanfang → Gehen → Laufen → enge Tür → belegtes Haus → Übungsplatz → mehrere Techniken → Pause → Speichern → Neustart. Untersuche Wand-/Personenkollisionen und Fußkontakt. Zeige tatsächliche Vorher-/Nachher-Aufnahmen gleicher Perspektive und erkläre verbleibende Fehler. Godot-Headless-Tests ersetzen weder eine sichtbare Animation noch Android-Temperaturmessungen.

Miss Aufwand mit identischem Szenario und Profil. Weniger Nodes oder Drawcalls sind zunächst technische Messwerte, kein Beweis für ein kühleres Handy oder Konsolenqualität. Erhalte bzw. verbessere sinnvolle LODs, Material-/Meshwiederverwendung und Offline-Vorbereitung.

Liefere lauffähige Änderungen, gezielte Regressionstests, Herkunft der selbst erzeugten Assets, einen prüfbaren Draft-PR und eine Übergabe mit exakten Commits, Dateien, Schnittstellen und offenen Problemen. Eine APK nur mit nachgewiesenem Build- und Laufzeitstatus als getestet bezeichnen. Führe notwendige autorisierte Arbeiten selbst aus; frage nicht nach jeder Routineentscheidung. Das Ziel ist ein deutlich besser spielbarer Abschnitt, keine Liste angeblich erledigter AAA-Funktionen.
