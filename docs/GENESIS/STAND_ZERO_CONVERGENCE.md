# Stand Zero – Integrationsabgleich, 28. November 2026

**Vergleichsbasis:** `5161c38c` im isolierten GitHub-Zweig. Originalzweige
und GitLab bleiben unverändert. Diese Liste dokumentiert Entscheidungen,
keine Freigabe. Datenquelle sind die Git-Dateibäume, die geprüften
Laufzeitpfade und, sofern angegeben, die konkreten Engine-Tests.

## Kandidaten

| Kandidat | Einordnung | Nachweis und Entscheidung |
| --- | --- | --- |
| PR #208–211 und #213–216 (Astra, PRIMA, GENESIS) | Enthalten; teils neuerer Stand | Alle acht PR-Köpfe sind im gemeinsamen Verlauf erreichbar. Bei CharacterCore, Ausrüstung, PRIMA und GENESIS nicht ältere Blobs über die Nachfolger legen. |
| `73548f99` CharacterCore | Übernommen und geprüft | Auflösung der vier Konfliktpfade in `df754516`; auf `da8d9155` 166 CharacterCore- und 62 Ausrüstungsprüfungen ohne Fehler. |
| `5d798af5` / `aacbcac8` Formation | Übernommen und repariert | `da8d9155`: [strikte Formations-CI](https://github.com/Ullmann27/Imperathen/actions/runs/46137146596) mit 60/180 Figuren, 798 Kontaktfällen und 125 Gangprüfungen grün. Grenze 40 mm. [Wiederholung auf `5161c38c`](https://github.com/Ullmann27/Imperathen/actions/runs/46138920641) ebenfalls grün. |
| `d4a74779` Marktpersonal | Übernommen und geprüft | Änderung des Zeitintervalls für tatsächlich anwesende Händler in `a0ad10a9`; Dienstende separat getestet. Markt-, Kampagnenhandels- und Bewohnerprüfungen bestanden. |
| GitLab !201 (`fb30624d`), GitHub #201/#204 | Enthalten; älterer Test ersetzt | Korb-Laufzeitskript bytegleich (`1f7966a6`). Der aktuelle Test enthält zusätzliche Rig-, Eigentums- und LOD-Prüfungen. Der lokale Checkout ohne Originalrig liefert keinen Positivnachweis; die Fold7-CI stellt das Original bereit. |
| #190, #192, #194, #196–197, #199–200, #203, #205–207, #215–216 | Enthalten (Runtime und Tests) | Verglichene Runtime-/Test-Blobs gleich; abweichende Prüfworkflows, Indexstände und Berichte separat behandeln. #207: NPC-Gedächtnisprüfung vorhanden und gezielt nachgeprüft. |
| #54, #84, #85, #185–187, #191 | Durch neuere Implementierung ersetzt | Fokus/Pause und Anzeige, LOD-Überblendung, Stadt-Teardown, Begleiterkurven, Blickanker, Kruggriff und Kamerafreiraum über neuere Runtime und entsprechende Tests erhalten. Nicht die älteren Dateien darüberkopieren. |
| #188–189 und #195 | Enthalten; für #195 neuerer Weltadapter | Verglichene Quell-/Testanteile gleich; `game_world.gd` bei #195 enthält im Integrationsstand spätere Änderungen. |
| #57 und #58 | Selektiver Abgleich erforderlich | Acht gemeinsame abweichende Kernpfade in Welt, NPC, Wirtschaft und Hauptszene; keine Methode dieser älteren GDScript-Zweige fehlt unter ihrem Namen im heutigen Runtime-Baum. Die Pakete nicht komplett übernehmen: ältere Parallelstände würden die aktuelle Simulation überschreiben. |
| #61, #193, #198 und `3d765a38` | Nicht als fertig abgenommen | Asset-/Kontakt- und Renderkandidaten ohne aktuellen Produktionsnachweis. Der [Rüstungskandidat](https://github.com/Ullmann27/Imperathen/actions/runs/46115352825) ist in CI rot; keine Rücknahme bewährter Jugend-/Formationsdaten. |
| #52, #59, #71, #76, #79, #202 und #212; GitLab `86ad95b7` | Studie, Referenz oder Automatisierung | Dokumentation, Materiallabor, eigenständiger Spaziergang, Quellbelege oder CI-Workflow, keine nachgewiesene fehlende Produktionsfunktion. GitLab-Pipeline 3125854754 prüft Branch-Parität; kein APK-Test. |
| WorldWorkshop / World-Expansion | Vorhanden als Vorschau; Produktionsanschluss blockiert | 55 von 56 betrachteten Dateien auf dem Blender-Zweig sind bereits bytegleich. Basilika und LOD-Exporte sind vorhanden. Vorschau und Batch-Siedlung haben keinen autoritativen Welt-, Speicher-, Kollisions- und Interaktionspfad; nicht in den Startpfad hängen. Geprüfte Roman-Material-, Viva-Roma-, Laden-, Landstraßen- und Dorfhintergrund-Assets waren bereits enthalten. |

## Reichweite der Prüfung

Der erneute Remote-Abgleich fand **236 GitHub-Branches** einschließlich des
Integrationszweigs, **213 GitLab-Branches** und **210** auf beiden Anbietern
identische Branch-Spitzen. Die abweichenden GitLab-Spitzen betreffen !201,
das Kimi-Arbeitsregister und die Paritätsautomatisierung. Von 106 eindeutigen,
nicht-ancestralen Dateibäumen im ersten Abgleich hatten 28 identische Blobs
für die jeweils betroffenen Quellpfade; 78 hatten Unterschiede. Nur die
oben begründeten Entscheidungen gelten als geprüft, nicht alle 78 Kandidaten
und nicht alle 2.344 erfassten Actions-Artefakte.

Die [GENESIS-Systemkarte](SYSTEM_MAP.md) erfasst alle 36 Arbeitspakete. Der
Pfadabgleich ergab für die dort konkret benannten bestehenden Quell- und
Testpfade keine fehlende Datei. Das ist keine Funktionsabnahme: Belagerung,
autonome Siedlungsplanung, universelle Chronik und Dynastie bleiben
langfristig. Die 113 Haupt- und 96 Nebenmissions-IDs sind keine Zusage
entsprechend vieler spielbarer Abschnitte.

## Quellstand und Freigabegrenzen

- [Stadtbudget-Messung](../29_living_city/RESEARCH.md): Simulation unverändert
  über 150.677 Ereignisse, identische Endzustände und Save/Load-Folge. Auf
  `5161c38c` im isolierten Godot-Lauf 19 von 10.752 Aufrufen über 4,5 ms
  (0,177 % bei erlaubten 0,5 %).
- [Fold7-Lauf auf da8d9155](https://github.com/Ullmann27/Imperathen/actions/runs/46137146624):
  Profile Hoch und Sehr hoch zeigten je drei echte, bestandene
  Godot-Kompatibilitätsaufnahmen. Das Artefakt belegt keine Fold7-Hardware,
  keine signierte APK und keine vollständige Bewegungsfreigabe.
- Startmenü, Prolog, Speichern/Fortsetzen, I-01, I-03 und der vorhandene
  I-04-Fachtest wurden lokal ausgeführt. Der I-04-Hauptszenentest prüft
  den Einstieg aus einer Vorgeschichte, Überspringen bis zur Auswahl,
  Speichern/Fortsetzen und Rückkehr ins Spiel. Das zivile Originalrig für den
  strengen I-02-Korbtest ist nur im dafür vorgesehenen Build verfügbar.
  I-03/I-04 besitzen keine vollständig abgenommene deutsche Sprachfassung.
- Das Bewegungs-Gate verlangt Messprotokolle und visuelle Abnahmen aus
  denselben Quelldateien. Fehlende private Meshy- und Drehbuchquellen werden
  nicht aus älteren Lieferungen rekonstruiert oder veröffentlicht.
