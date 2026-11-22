# IMPERATHEN – Plattformen und Leistungsplanung

**Stand:** 22.11.2026 · **Status:** Planungsannahmen, keine Benchmarkergebnisse. Es werden derzeit keine Engine, Hardware, Cloudinstanz oder 3D-Assets beschafft oder eingerichtet.

## 1. Zielplattformen und Werkzeugentscheidung

Windows-PC ist der vorgeschlagene erste Entwicklungs- und Testpfad. Unreal Engine 5.x und Blender sind Kandidaten aus dem bisherigen Konzept. Eine konkrete Version wird erst nach Prüfung von Betriebssystem, Compiler, Exportformaten, benötigten Plugins und verfügbarer Hardware festgelegt. „Aktuellste Version“ ist keine reproduzierbare Produktionsdefinition. Geprüfte Versionen und relevante Einstellungen gehören später in die technische Entscheidungsakte.

Xbox und PlayStation bleiben zusätzliche Zielplattformen. Ihre Planung benötigt tatsächlichen Plattformzugang, verfügbare Werkzeuge und gesonderte Leistungsmessungen. Die vorhandenen Konzeptbilder sind weder Konsolennachweise noch Belege einer bestimmten Bildrate. Entwicklung am Handy kann Dokumentation, Aufgabensteuerung und Fernbedienung unterstützen; ein vorhandener, fernsteuerbarer Entwicklungsrechner wird dadurch nicht als bereits vorhanden angenommen.

## 2. Arbeitslasten ausdrücklich trennen

| Arbeitslast | Geplantes Verhalten | Noch zu bestimmen |
|---|---|---|
| Echtzeitgrafik und direkte Interaktion | Reaktionsfähiger lokaler Spielprozess | Renderingprofil, Auflösung, Bildrate und aktive Figuren |
| Wirtschaft und ferne Reiche | Geringere Aktualisierungshäufigkeit auf gemeinsamer Weltzeit | Maximale Städtezahl, Prozess- und Speicherbudgets |
| Narrative Planung | Asynchron, kein Warten des Renderthreads auf ein Sprachmodell | Lokaler/offener Dienstpfad, Latenz, Umfang, Kosten |
| Assetproduktion | Getrennter Entwicklungsprozess mit Importprüfung | Werkzeugversion, Quelldateien, Exportformat und Qualitätsstufen |
| Kompilierung und Verpackung | Reproduzierbare Entwicklungsumgebung | Buildrechner, Speicherplatz, Ausführung und Rechte |

Eine zweite Grafikkarte oder Wasserkühlung wird nicht zur Projektvoraussetzung erklärt. Ob getrennte Rechenressourcen später lohnen, folgt aus gemessenen Engpässen. Es gibt derzeit keine neue Einkaufs- oder Budgetempfehlung und keine bestätigte Zielhardware.

## 3. Große Heere messbar beschreiben

Jeder Bericht führt mindestens vier Zahlen: strategischer Soldatenbestand, taktisch berechnete Figuren, sichtbare Figurenrepräsentationen und Figuren mit vollständiger Animation/Kollision. „500.000 Soldaten“ ohne diese Unterscheidung ist keine aussagekräftige Leistungsangabe. Ziel ist, große Fronten darzustellen und nahe am Spieler glaubwürdig zu kämpfen; die erreichbare lokale Menge bleibt eine Messfrage.

Bei Distanzwechsel wird eine Kohorte in konkrete Kämpfer aufgelöst oder wieder zusammengefasst. Zahl, Wunden, Ausrüstung, Munition, benannte Personen und Verluste müssen dabei erhalten bleiben. Ein entfernter Soldat darf nicht gleichzeitig als vollständiger Actor und als zusätzlicher aggregierter Bestand zählen. Ein Tierwechsel ist eine Darstellungs- und Berechnungsänderung, keine Rekrutierung oder Heilung.

Dasselbe gilt für produzierende Städte: Der Wechsel zwischen naher und ferner Berechnung übernimmt den letzten bestätigten Prozessstand und die Weltzeit. Er löst weder eine zweite Produktion noch eine doppelte Lohn-, Handels- oder Steuerzahlung aus. Begonnene Baustellen behalten ihre bestätigten Teilschritte.

## 4. Geplante Benchmarkleiter

Nach späterer Programmierfreigabe: zunächst ein steuerbarer Charakter und wenige Arbeits-NPCs; dann eine kleine Formation; anschließend schrittweise größere Schlachten. Die alte Mappe nennt unterschiedliche Stufen von Tausenden bis Hunderttausenden. Diese werden in zwei Messreihen getrennt: **aktive Nahszene** und **strategische Fernsimulation**. Jede Stufe wird erst erweitert, wenn der vorige Engpass verstanden ist.

Für jede Messung: Commit und Build, konkrete CPU/GPU/RAM, Treiber, Engine-/Inhaltsversion, Grafikprofil, interne und ausgegebene Auflösung, Upscaling, Anzahl jedes Figurentyps, Dauer, Aufwärmphase, CPU-/GPU-Frametime, RAM/VRAM, Ladepausen und Bildzeitspitzen. Kaltstart und bereits vorbereitete Szene werden getrennt ausgewiesen. Ein einzelner schöner Screenshot ersetzt diese Messung nicht.

Bei Narrative-Lastmessungen werden aktive Spieldauer, Pausen/Inaktivität, tatsächlich genutzter Inhalt und verworfene Pläne getrennt berichtet. Reine Programmlaufzeit rechtfertigt weder höheren Inhaltsvorrat noch größere Generierungsbudgets.

Als vorläufige Vergleichsprofile können 1080p/30, 1440p/60 und ein späteres Qualitätsprofil dienen. Bei 60 Bildern pro Sekunde stehen rechnerisch rund 16,7 Millisekunden pro Bild zur Verfügung; dies ist ein Zeitbudget, kein nachgewiesenes Leistungsziel. Genaue Schwellen werden nach Festlegung der Referenzhardware eingetragen.

## 5. Speicher, Dateien und Auslieferung

Quelldateien, Laufzeitassets, Zwischencaches und fertige Builds werden getrennt gehalten. Große Binärdateien erhalten vor dem Import eine Entscheidung zu Versionierung, Sperren und Backup. Wiederherstellung umfasst Quellcode **und** referenzierte Assetversionen. Der alte ZIP-Umfang erlaubt keinen Rückschluss auf die spätere Spieldateigröße.

CI-Prüfungen sind derzeit nur vorgesehen. Es werden keine verpflichtenden Statuschecks benannt, bevor die tatsächlichen Jobs existieren und einmal erfolgreich gelaufen sind. Ein dokumentierter Prozess ist noch kein technisch erzwungener Schutz.

**Prüfstellen bei späterer Auswahl:** offizielle Epic-Dokumentation zu World Partition, Mass Gameplay und Packaging; Blender-Python-Dokumentation. Keine dieser Technologien wird hier als bereits integriert dargestellt.
