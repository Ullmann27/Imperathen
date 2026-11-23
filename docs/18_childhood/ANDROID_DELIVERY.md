# Android-Lieferung: Kindheit, Familie und der Schwur

Stand: 23. November 2026. Die geprüfte Vorabversion ist veröffentlicht.

## Download und zugehöriger Quellstand

- [Android-APK 0.4.0-childhood herunterladen](https://github.com/Ullmann27/Imperathen/releases/download/childhood-2026-11-23-3325a0b3/IMPERATHEN-3325a0b3-arm64.apk)
- [Vorabversion mit allen sieben Dateien](https://github.com/Ullmann27/Imperathen/releases/tag/childhood-2026-11-23-3325a0b3)
- [Erfolgreicher Bau, Laufzeitprüfung und Veröffentlichung](https://github.com/Ullmann27/Imperathen/actions/runs/45200099195)
- [Entwurfs-PR #37](https://github.com/Ullmann27/Imperathen/pull/37)

APK: `IMPERATHEN-3325a0b3-arm64.apk`. Größe: **150596125 Bytes** (rund 150,6 MB).
Versionscode: **4**. Paket: `at.heinz.imperathen`.
Spielquellstand und Testharness: `3325a0b3812d6bffbb1b31fd9405a719b50da7ff`.

SHA-256:

```text
bc6c054c6df9dde2095b199c3e3b5b6b05e29249afc7821e652fdf2d03ad2e87
```

Die abschließende Dokumentation ist ein eigener Commit. Gegenüber dem oben genannten APK-Quellstand ändert dieser ausschließlich Markdown-Dateien; das geprüfte Spiel und die Android-Werkzeuge bleiben unverändert.

## Tatsächliche Ergebnisse

| Prüfung | Ergebnis und Grenze |
| --- | --- |
| Python | **103 Prüfungen bestanden.** Synthetische Paket-, Beobachter-, Eingabeabbruch- und Veröffentlichungsfälle. |
| Godot | **51 Prüfgruppen bestanden.** Darunter beide Nächte bis zum Schwur, Handel, physische Türen und Eskorte, alte Spielstände, Faustkampf und die übrigen Spielbereiche. |
| Android-Laufzeit | **50 Prüfungen bestanden**, keine gemeldeten Laufzeitfehler; Android 15, API 35, zunächst x86_64. |
| Native Touchbewegung | Etwa **0,205 m** beim ersten Bewegungsnachweis; nach Abbremsen insgesamt **0,236 m**. Kein Eingriff in den Spielzustand über einen Testkanal. |
| Loslassen | Anschließend **0 m Drift** während rund **1,071 Sekunden aktiver Spielzeit**. |
| Familienauftrag | Julia per tatsächlicher Eingabe angesprochen, Dialogzeit angehalten, genau zwei Getreide übernommen und der erreichte Auftrag nach Prozessneustart erhalten. |
| Bestehende Android-Bereiche | Pause, Hintergrund/Rückkehr, Fortsetzen, Formationsszene, Marsch, annähernd quadratisches Display, Weltkugel und Figurengalerie geprüft. |
| ARM64-Paket | Zusätzlich im selben Emulator installiert und der tatsächliche ARM64-Prozess **unter Architekturübersetzung** gestartet. Der vollständige Familienweg wurde zuvor mit x86_64 geprüft. |

Dieser Lauf belegt keinen Test auf einem physischen Handy, keine thermische Dauerlast und keine zugesagte Bildrate auf dem Zielgerät. Die lokalen Bilder und ihre engeren Aussagegrenzen stehen im [Lieferbericht](CHAT_B_DELIVERY.md).

## Bytegenaue Belege

- [APK-Prüfung](https://github.com/Ullmann27/Imperathen/releases/download/childhood-2026-11-23-3325a0b3/IMPERATHEN-3325a0b3-APK-Pruefung.json)
- [Godot-Prüfgruppen und Quellhashes](https://github.com/Ullmann27/Imperathen/releases/download/childhood-2026-11-23-3325a0b3/IMPERATHEN-3325a0b3-Godot-Pruefungen.json)
- [Vollständiger Android-Laufzeitbericht](https://github.com/Ullmann27/Imperathen/releases/download/childhood-2026-11-23-3325a0b3/IMPERATHEN-3325a0b3-Emulatorpruefung.json)
- [Bau- und Herkunftsnachweis](https://github.com/Ullmann27/Imperathen/releases/download/childhood-2026-11-23-3325a0b3/IMPERATHEN-3325a0b3-Buildnachweis.json)
- [Prüfsummen der veröffentlichten Dateien](https://github.com/Ullmann27/Imperathen/releases/download/childhood-2026-11-23-3325a0b3/IMPERATHEN-3325a0b3-SHA256SUMS.txt)

Der Veröffentlichungsjob prüfte den erfolgreichen Vorgängerjob desselben Laufs, Quelle, beide ABI-Pakete, Pflichtgruppen und Laufzeitnachweise. Das veröffentlichte ARM64-Asset hat denselben SHA-256 wie der Laufzeitbericht. Der Download enthält keine privaten Signierschlüssel.

## Installation

Diese Prüffassung verwendet einen neuen privaten Debug-Signierschlüssel. Ein direktes Update über ältere Prüfbauten und die Übernahme ihrer App-Daten sind damit nicht zugesagt. Eine vorhandene Installation mit wichtigem Spielstand nicht ungeprüft deinstallieren.

## Einordnung der vorherigen Versuche

`98bec146` scheiterte am überschrittenen Bewegungsweg, `9d90a8fe` an fehlender Bewegung nach einer kurzen 450-ms-Geste im langsamen Software-Emulator. Beide Läufe blieben von der Veröffentlichung ausgeschlossen. Der erfolgreiche Stand verwendet die übernommene Kindheitsgeschwindigkeit und einen echten nativen, bis zum beobachteten Fortschritt gehaltenen Touchkontakt mit garantiertem Loslassversuch. Bewegungs- und Stillstandsgrenzen wurden nicht gelockert.
