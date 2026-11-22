# Übergabe für den nächsten Entwicklungsdurchgang

**Aktueller Integrationsstand.** Die zusammengeführte Android- und Desktop-Linie, Abnahme und offene Punkte stehen im [Lieferbericht](../12_integration/DELIVERY.md). Die folgenden Angaben dokumentieren den vorausgehenden Arbeitsstand.

Stand 22.11.2026. Arbeitszweig `feature/prototype-foundation-20261122`, Koordination [#17](https://github.com/Ullmann27/Imperathen/issues/17). Die spätere Bearbeitung mit Sol 6.2 oder Astra 6.2 wurde vom Nutzer vorgesehen; dieser Entwicklungsblock schaltet selbst kein Modell und keinen Tarif um.

## Android zuerst: vorhandenen Stand übernehmen

Der Nutzerstart ist die installierbare **ARM64-Test-APK**, nicht der Editor. Eine ARM64-APK wurde bereits exportiert. Die zugehörige CI einschließlich des Android-x86_64-Laufzeittests ist erfolgreich; Quellcommit `b3d8e01e64663480d228777a7244a2a882bcac18`, [Lauf 45038377950](https://github.com/Ullmann27/Imperathen/actions/runs/45038377950). Eine Ausführung auf einem echten ARM64-Gerät wurde noch nicht nachgewiesen. Download, Prüfsumme und tatsächlicher aktueller Android-Laufbefund gehören in [ANDROID_INSTALL.md](ANDROID_INSTALL.md). Einen erfolgreichen Export oder x86_64-Emulatorlauf nicht als ARM64-Geräteabnahme ausgeben.

1. Repository, aktuelle Branches, offene Pull Requests und neue Kommentare in #16, #17 und #18 lesen. Parallel arbeitende Teams können seit dieser Lieferung weitere Änderungen veröffentlicht haben.
2. `AGENTS.md`, `prototype/README.md`, diese Übergabe sowie `ANDROID_INSTALL.md`, `ANDROID_BUILD.md` und die tatsächlichen Prüfberichte lesen. Die ältere Projektmappe bleibt Herkunft, nicht der alleinige aktuelle Arbeitsauftrag.
3. Aktuellen Android-CI-Lauf und seine Artefakte dem geprüften Commit zuordnen. APK, Signaturprüfung und Laufzeitbericht getrennt beurteilen. Bei einem Fehler zuerst den konkreten Blocker reparieren; vorhandenen Exportweg und Prüfwerkzeuge weiterverwenden.
4. Als Entwickler Godot 4.7.2 verwenden und `python tools/check_prototype.py` im eigenen Arbeitsverzeichnis starten. Der vorliegende Stand besteht **115 UI-Prüfungen** und **35 Integrationsprüfungen**, siehe [UI-Protokoll](evidence/ui.log) und [Integrationsprotokoll](evidence/integration.log). Ergebnisse des neuen Laufs tatsächlich prüfen. Der Läufer verwendet isolierte Testordner, damit persönliche Spielstände nicht überschrieben werden.
5. Die installierte APK auf einem tatsächlich verfügbaren Android-Gerät prüfen: Hauptmenü, Personen-, Stadt-, Karten-, Kampf- und Touchablauf. Gerät, ABI und getestete APK-Prüfsumme dokumentieren und echte Spielbilder erfassen. Der vorhandene Hüttenrender und Headless-Tests ersetzen diese Abnahme nicht.

## Linien bewusst zusammenführen

| Arbeitslinie | Verantwortliche Pfade | Integration |
| --- | --- | --- |
| #16 Einstieg und Produktionsbasis | `preview/`, `game/`, `coordination/`, `tools/agent_pipeline.py`, eigene CI | Neue veröffentlichte Dateien zuerst prüfen. Unreal-Projektgrundlage und Webvorschau sind nicht automatisch derselbe ausführbare Godot-Prototyp. |
| #17 Spielmechanik und 3D-Ablauf | `prototype/`, `tools/check_prototype.py`, `tools/build_frontier_*.py`, `art/source/`, `docs/10_development/` | Laufende Funktionsbasis dieses Branches. Zustands- und Eingabeverträge bei Übernahme bewahren. |
| #18 Grafikqualität | `art/visual_benchmark/`, `tools/art/`, `docs/11_visual_quality/` | Nach tatsächlicher Lieferung Geometrie, Pivot, Materialzahl, Lizenzherkunft, Animation und Collider abgleichen. |

Gemeinsame Dokumentdateien wie README, Status und AGENTS können in mehreren Branches geändert sein. Inhalte zusammenführen und neuere Nutzerentscheidungen berücksichtigen. Keine Paralleländerung mit einer älteren Komplettkopie überschreiben. Keinen unaufgeforderten Merge nach main ausführen.

## Aktuelle Zielplattform

Der aktuelle ausdrückliche Nutzerauftrag verlangt zuerst eine spielbare Android-APK; die Koordination in #16/#17/#18 führt Android als Hauptziel und PC als spätere Erweiterung. Touchbedienung, skalierbare Oberfläche, sichere Bildschirmränder und drei Compatibility-Grafikprofile gehören zur vorhandenen Umsetzung. Eine Freigabe auf konkreten Handys, Konsolen oder einem Store liegt damit noch nicht vor. Editorstart und Desktop-Eingaben dienen der Entwicklung.

Android-Zurück ist über `Window.go_back_requested` an genau einen UI-Pfad angebunden. Die Integration prüft Pause, Fortsetzen und vorrangigen Bauabbruch einschließlich der Reihenfolge Notification vor Signal. App-Hintergrund pausiert eine laufende Simulation, setzt gehaltene Eingaben zurück und speichert. Diese lokal geprüfte Logik ersetzt nicht den Nachweis der tatsächlichen Betriebssystemereignisse in der installierten APK.

Die drei Grafikprofile ändern MSAA und Schattendistanz. Ihr endgültiger Inhalt hängt von tatsächlichen Android-Messungen und der Assetlieferung ab. „Ausgewogen“ ist derzeit kein Versprechen nativer 1920×1080-Auflösung auf jedem Gerät. Keine Grafikoption darf Ressourcen, Trefferlogik, KI-Entscheidungen oder andere Regeln verändern.

## Wichtigste offene Arbeit in sinnvoller Reihenfolge

### 1. Vollständigen Spielweg auf einem ARM64-Gerät prüfen

Der vorhandene Export-, APK-Prüf- und Emulatorweg ist für die dokumentierte Lieferung erfolgreich abgeschlossen. Nach einer Änderung muss der tatsächliche neue Lauf weiterhin geprüft werden. Als nächsten Nachweis den vollständigen Spielweg auf mindestens einem konkreten ARM64-Gerät prüfen. Dokumentieren: Gerät, Betriebssystem, ABI, APK-Prüfsumme, Auflösung, Renderer und Profil. Energie-/Temperaturverhalten und Bildzeiten nur nennen, wenn tatsächlich gemessen. Für gerätespezifische Fehler zuerst Eingaben, Layout und Speicherzugriff prüfen.

### 2. Grafische und ergonomische Abnahme

Die echten Android-Aufnahmen liegen in `evidence/android/`. Bekannter kleiner Befund: Die kurzlebige Willkommensmeldung liegt im Pausebild vor dem unteren Menüteil. Bei der nächsten UI-Änderung Hinweise beim Öffnen eines modalen Menüs passend ausblenden oder anordnen und am tatsächlichen Bild prüfen.

Echte Enginebilder bei kleiner und großer Bildschirmfläche, Schriftvergrößerung und allen Grafikprofilen aufnehmen. HUD darf Interaktion nicht verdecken; virtuelles Steuerkreuz und Kamera müssen mit mehreren Fingern funktionieren. Pointerverlust, App-Hintergrund und Rückkehr dürfen keine gehaltene Bewegung hinterlassen. Notches und sichere Bildschirmränder brauchen einen Gerätetest.

### 3. Assetübernahme

Die vorhandene Hütte hat gemessene Abmessungen von etwa 4,387m Breite, 3,74m Höhe und 4,24m Tiefe. Sie nutzt Metermaßstab, glTF-Y-up, Bodenmittelpunkt und Eingang nach +Z. Fertige Collider sind separat und lassen eine Tür offen. Größere Ersatzmodelle benötigen passende Bauabstände und Collider.

Figuren besitzen aktuell einfache animierte Gliedknoten. Ein detailliertes statisches Modell ist kein Ersatz für einen funktionierenden Bewegungs-/Kampfanimationssatz. Bei neuen Figuren zuerst Bodenpivot, Capsule, Waffenposition, erwachsene/juvenile Rolle und Animation vereinbaren; vorhandene Spielfunktion nicht durch eine ausschließlich optische Änderung verlieren.

### 4. Begrenztes Kapitel erweitern

Vorhanden ist eine kleine zusammenhängende Schleife: Holz sammeln, über Hilfe für Marcus entscheiden, eine Hütte auf erlaubter Fläche bauen, durch einen erklärten Zeitsprung erwachsen werden, drei gültige Übungstreffer absolvieren, bis zu drei Rekruten anwerben, drei Gegner bekämpfen und eine Folgeentscheidung speichern. Niederlage beendet diesen Lebensbogen; der erfolgreiche Kapitelabschluss ist keine feste Karriereobergrenze des Gesamtspielkonzepts. Die Kartenansicht bleibt dieselbe lokale Dorfwelt. Sie implementiert noch keine Provinzeroberung.

Als nächster inhaltlicher Schritt eignet sich eine zweite zusammenhängende Dorfsituation mit tatsächlicher Produktion und einem neuen Konflikt. Dafür zuerst endliche Holzquellen, Arbeitskräfte, Nahrung, Baukategorien, Zeitbudget und UI-Anzeige erweitern. Erst anschließend neue Geschichten darauf aufsetzen. Die bisherigen Zahlen (12 Sekunden Bau, drei Trainingstreffer, drei Gegner) sind Demonstrationswerte und bilden keine Wochenkampagne ab.

### 5. Architektur vor großer Skalierung prüfen

Der Regelkern kopiert kleine Dictionaries und prüft streng. Das ist übersichtlich für dieses Kapitel, aber kein Leistungsbeleg für 100.000 Personen. Vor großer Welt: persistenten Ereignisverlauf, Command-ID-Aufbewahrung, Save-Migration, chunkweise Simulation und messbare Detailstufen entwerfen. Die begrenzte ID-Tabelle und Chronik dürfen nicht unbemerkt zum Karriereabbruch einer langen Kampagne führen.

### 6. Erzählung kontrolliert erweitern

Der aktuelle Verlauf ist deterministisch und reagiert auf festgehaltene Entscheidungen. Keine KI generiert schon Kapitel im Hintergrund. Für späteren Modelleinsatz zunächst nur strukturierten Inhalt in einem geprüften Schemenformat akzeptieren, kanonische Fakten und Ressourcen schützen, ungültige Antworten verwerfen und einen vollständig offline spielbaren Ersatzablauf erhalten. Keine Laufzeit-Ausführung beliebigen generierten Codes und keine automatische kostenpflichtige API-Nutzung.

## Konkrete Entwurfsentscheidungen dieses Prototyps

- Eine maßgebliche Domäne entscheidet über gültige Befehle. UI und Welt dürfen denselben Zustand darstellen, aber Ressourcen und Kampfergebnisse nicht selbst überschreiben.
- Kamerawechsel verändert keine Simulationswelt und teleportiert die Figur nicht.
- Jugendbeginn und erwachsene Ausbildung werden durch einen ausdrücklichen gemeinsamen Zeitsprung verbunden. Das ist kein automatisches Alter durch fünf Minuten Spielzeit.
- Ein fertiger Prototypabschnitt ist nicht gleichbedeutend mit einer endgültigen Karrieregrenze. Eine Kaiserkarriere ist hier weder implementiert noch versprochen.
- Speichersummen dienen Beschädigungserkennung; der Benutzer besitzt seine lokalen Dateien. Keine falsche Behauptung eines Manipulationsschutzes.
- Ausführung in Godot wurde gewählt, weil die Engine in dieser Umgebung tatsächlich vorhanden ist. Der Produktionsentscheid zwischen dieser Linie und einer späteren Unreal-Umsetzung bleibt bewusst offen und muss zu Android passen.

## Arbeitsauftrag zum Weitergeben

> Übernimm IMPERATHEN auf dem tatsächlich aktuellen GitHub-Stand. Lies AGENTS.md, die Dateien unter docs/10_development/ und die Koordination in #16/#17/#18. Prüfe den aktuellen Android-CI-Lauf und die tatsächlich exportierte APK samt Prüfsumme; bewahre den erfolgreichen x86_64-Laufzeitnachweis und vervollständige den noch fehlenden vollständigen ARM64-Gerätedurchgang. Nutze für Regressionen den vorhandenen Godot-Prüfläufer. Bewahre öffentliche Repository-Sichtbarkeit, vorhandene Paralleländerungen, Android als Hauptziel und die regelgebundene Speicherung. Halte die fertige APK als primären Nutzerstart dokumentiert; der Editor ist ein Entwicklerwerkzeug. Nutze vorhandene Export- und Prüfwerkzeuge, repariere nachgewiesene Fehler, dokumentiere tatsächliche Ausführung und halte generierte Inhalte getrennt von bestätigten Spielfakten. Schalte keine kostenpflichtigen Dienste oder Modell-Abos ein. Behaupte weder Endgrafik noch große Armeen oder Wochenbalance ohne entsprechenden Nachweis. Hinterlasse einen prüfbaren Branch/PR mit konkreten Ergebnissen und verbleibenden Grenzen.
