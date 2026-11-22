# Übergabe für den nächsten Entwicklungsdurchgang

Stand 22.11.2026. Arbeitszweig `feature/prototype-foundation-20261122`, Koordination [#17](https://github.com/Ullmann27/Imperathen/issues/17). Die spätere Bearbeitung mit Sol 6.2 oder Astra 6.2 wurde vom Nutzer vorgesehen; dieser Entwicklungsblock schaltet selbst kein Modell und keinen Tarif um.

## Erst vorhandenen Stand prüfen

1. Repository, aktuelle Branches, offene Pull Requests und neue Kommentare in #16, #17 und #18 lesen. Parallel arbeitende Teams können seit dieser Lieferung weitere Änderungen veröffentlicht haben.
2. `AGENTS.md`, `prototype/README.md`, diese Übergabe und `VALIDATION.md` lesen. Die ältere Projektmappe bleibt Herkunft, nicht der alleinige aktuelle Arbeitsauftrag.
3. Godot 4.7.2 ausführen und `python tools/check_prototype.py` im eigenen Arbeitsverzeichnis starten. Tatsächliche Ergebnisse prüfen, nicht nur den früheren Report lesen. Der Läufer verhindert versehentliches Überschreiben persönlicher Spielstände durch isolierte Testordner.
4. In einer Umgebung mit funktionierender grafischer Ausgabe den echten Hauptmenü-, Personen-, Stadt-, Karten-, Kampf- und Touchablauf prüfen und Bilder aus der Engine erfassen. Der vorhandene Hüttenrender ersetzt diese Abnahme nicht.

## Linien bewusst zusammenführen

| Arbeitslinie | Verantwortliche Pfade | Integration |
| --- | --- | --- |
| #16 Einstieg und Produktionsbasis | `preview/`, `game/`, `coordination/`, `tools/agent_pipeline.py`, eigene CI | Neue veröffentlichte Dateien zuerst prüfen. Unreal-Projektgrundlage und Webvorschau sind nicht automatisch derselbe ausführbare Godot-Prototyp. |
| #17 Spielmechanik und 3D-Ablauf | `prototype/`, `tools/check_prototype.py`, `tools/build_frontier_*.py`, `art/source/`, `docs/10_development/` | Laufende Funktionsbasis dieses Branches. Zustands- und Eingabeverträge bei Übernahme bewahren. |
| #18 Grafikqualität | `art/visual_benchmark/`, `tools/art/`, `docs/11_visual_quality/` | Nach tatsächlicher Lieferung Geometrie, Pivot, Materialzahl, Lizenzherkunft, Animation und Collider abgleichen. |

Gemeinsame Dokumentdateien wie README, Status und AGENTS können in mehreren Branches geändert sein. Inhalte zusammenführen und neuere Nutzerentscheidungen berücksichtigen. Keine Paralleländerung mit einer älteren Komplettkopie überschreiben. Keinen unaufgeforderten Merge nach main ausführen.

## Aktuelle Zielplattform

In den Koordinationsnachrichten aus #18 wurde Android ausdrücklich als Hauptziel eingetragen, PC als spätere Erweiterung. Diese Korrektur ist in Touchbedienung, skalierbarer Oberfläche und drei Compatibility-Grafikprofilen berücksichtigt. Eine Freigabe auf konkreten Handys, Konsolen oder einem Store liegt damit noch nicht vor.

Die drei Grafikprofile ändern MSAA und Schattendistanz. Ihr endgültiger Inhalt hängt von tatsächlichen Android-Messungen und der Assetlieferung ab. „Ausgewogen“ ist derzeit kein Versprechen nativer 1920×1080-Auflösung auf jedem Gerät. Keine Grafikoption darf Ressourcen, Trefferlogik, KI-Entscheidungen oder andere Regeln verändern.

## Wichtigste offene Arbeit in sinnvoller Reihenfolge

### 1. Spielbarkeit auf einem echten Android-Gerät

Engineentscheidung bewusst festhalten, Exportvorlagen/SDK einrichten, reproduzierbar ein Debug-APK bauen und den vollständigen Weg auf mindestens einem konkreten Gerät prüfen. Dokumentieren: Gerät, Betriebssystem, Auflösung, Renderer, Profil, Energie-/Temperaturverhalten und tatsächlich gemessene Bildzeiten. Vorher sind alle Zahlen nur Zielwerte. Für gerätespezifische Fehler zuerst Eingaben, Layout und Speicherzugriff prüfen.

### 2. Grafische und ergonomische Abnahme

Echte Enginebilder bei kleiner und großer Bildschirmfläche, Schriftvergrößerung und allen Grafikprofilen aufnehmen. HUD darf Interaktion nicht verdecken; virtuelles Steuerkreuz und Kamera müssen mit mehreren Fingern funktionieren. Pointerverlust, App-Hintergrund und Rückkehr dürfen keine gehaltene Bewegung hinterlassen. Notches und sichere Bildschirmränder brauchen einen Gerätetest.

### 3. Assetübernahme

Die vorhandene Hütte hat gemessene Abmessungen von etwa 4,387m Breite, 3,74m Höhe und 4,24m Tiefe. Sie nutzt Metermaßstab, glTF-Y-up, Bodenmittelpunkt und Eingang nach +Z. Fertige Collider sind separat und lassen eine Tür offen. Größere Ersatzmodelle benötigen passende Bauabstände und Collider.

Figuren besitzen aktuell einfache animierte Gliedknoten. Ein detailliertes statisches Modell ist kein Ersatz für einen funktionierenden Bewegungs-/Kampfanimationssatz. Bei neuen Figuren zuerst Bodenpivot, Capsule, Waffenposition, erwachsene/juvenile Rolle und Animation vereinbaren; vorhandene Spielfunktion nicht durch eine ausschließlich optische Änderung verlieren.

### 4. Begrenztes Kapitel erweitern

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

> Übernimm IMPERATHEN auf dem tatsächlich aktuellen GitHub-Stand. Lies AGENTS.md, die Dateien unter docs/10_development/ und die Koordination in #16/#17/#18. Prüfe zuerst den vorhandenen Godot-Prototyp mit dem mitgelieferten Prüfläufer und einem echten grafischen Durchlauf. Bewahre öffentliche Repository-Sichtbarkeit, vorhandene Paralleländerungen, Android als Hauptziel und die regelgebundene Speicherung. Arbeite anschließend den wichtigsten noch offenen Schritt vollständig ab, vorzugsweise echten Android-Export und Geräteabnahme. Nutze vorhandene Werkzeuge, repariere nachgewiesene Fehler, dokumentiere tatsächliche Ausführung und halte generierte Inhalte getrennt von bestätigten Spielfakten. Schalte keine kostenpflichtigen Dienste oder Modell-Abos ein. Behaupte weder Endgrafik noch große Armeen oder Wochenbalance ohne entsprechenden Nachweis. Hinterlasse einen prüfbaren Branch/PR mit konkreten Ergebnissen und verbleibenden Grenzen.
