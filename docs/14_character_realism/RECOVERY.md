# Charakterstand wiederhergestellt und Android-Prüfbau abgeschlossen

**22. November 2026 · [PR #34](https://github.com/Ullmann27/Imperathen/pull/34) · Spielquellstand `d54478ec21db4c849dfa29bf7e39eab04b88c9d5`.**

Der abgebrochene Transfer der neuen Hauptfigur ist abgeschlossen. Der bestehende Charakterstand wurde erhalten: vier Hero-GLBs, bearbeitbare Blender-Datei, Herkunftsnachweise, Laufzeitcode, Vergleichsbilder und Bewegungsaufnahme. Der Featurebranch `feature/hero-realism-20261122` besitzt denselben ursprünglichen Commit wie der lokal geprüfte Kandidat.

## Quellenabgleich und frische Prüfung

Alle elf Teile des 85.441.894 Byte großen Git-Bundles wurden gegen ihre SHA-256 und Git-Blob-Kennungen geprüft. Der vollständige GitHub-Tree `1f90bbf0c3c9546d6ad5c318e19d129a0ee000fc` stimmt bei allen **977 Dateipfaden, Dateimodi und Blob-Kennungen** mit dem lokalen Kandidaten überein. [Abgleichbeleg](evidence/recovery/source-recovery.json).

Der GitHub-Importer konnte das Bundle vollständig übertragen und prüfen. Sein eigener Runner-Token durfte den Ref mit den enthaltenen Workflowänderungen nicht anlegen. Der mit den erforderlichen Rechten verbundene GitHub-Zugang hat anschließend den regulären Featurebranch auf den bereits übertragenen Originalcommit gesetzt; kein Git-Inhalt wurde dafür umgeschrieben.

Die 16 Godot-Prüfgruppen wurden erneut ausgeführt: alle bestanden, darunter 55 Hero-/Mimikprüfungen und 221 Dorfpersonenprüfungen. Die fünf APK-Payload-Tests und die bestehenden Foundation-Prüfungen bestanden ebenfalls. Der [aktualisierte Bericht](evidence/checks/validation_report.json) enthält alle 134 aktuellen Quellhashes einschließlich der zuletzt angepassten Studiobeleuchtung. Vier GLB-Dateien und 32 Herkunftsdateien wurden unabhängig geprüft.

## Tatsächlich gebautes Android-Paket

Der vollständige [Android-Baulauf 45058521723](https://github.com/Ullmann27/Imperathen/actions/runs/45058521723) ist erfolgreich abgeschlossen. Er hat ARM64- und x86_64-APKs sowie Linux-/Windows-Ausgaben aus dem oben genannten Spielquellstand erzeugt.

| Merkmal | Tatsächlicher Wert |
| --- | --- |
| Android-Datei | `IMPERATHEN-d54478ec-arm64.apk` |
| Größe | 107.809.778 Bytes, etwa 107,8 MB |
| Paket | `at.heinz.imperathen` |
| ABI | `arm64-v8a` |
| SHA-256 | `89b7bb22914c033f8dc5c41d7a40fc6db26e7da25220c00bfb339a1fa887f76f` |
| APK-Inhaltsprüfung | 16 erforderliche Prüfungen bestanden |
| Neue Figureninhalte | Vier aufgelöste Hero-Modelle und das exportierte Gesichtsskript tatsächlich im APK-Inhalt nachgewiesen |

Das heruntergeladene Android-Artifact wurde gegen seine vollständige SHA-256 geprüft. Die ARM64-APK wurde zusätzlich unabhängig direkt aus dem ZIP-Datenstrom gehasht; Größe und Hash stimmen mit den Bau- und APK-Berichten überein. [Downloadbeleg](evidence/android/download-receipt.json).

## Android-Laufzeit und sichtbare Ausgabe

Der [Runtimebericht](evidence/android/runtime-report.json) enthält **36 erfolgreiche Prüfungen** und keine gemeldeten Laufzeitfehler. Der Test lief auf einem Android-15-/API-35-x86_64-Emulator mit Softwaregrafik. Er prüfte unter anderem Dorfstart per Touch, Android-Zurück/Pause, Hintergrund und Rückkehr, gespeichertes Spiel nach Prozessneustart, Talgefecht mit bewegtem Soldaten, eine quadratische Anzeige, Weltkarte und Figurenmenü.

Die tatsächliche ARM64-Download-Datei wurde anschließend ebenfalls installiert, ihre ausgewählte ABI bestätigt und ihr Intro unter ARM64-Übersetzung gestartet. Das ist kein vollständiger ARM64-Dorf-/Kampfdurchlauf und kein physischer Fold7-Test.

- [Tatsächliches Android-Dorf](evidence/android/02_android_world.png): Umgebung, Hauptfigur von hinten, NPCs und Touchsteuerung sind sichtbar. Die Ansicht prüft weder Gesichtsmimik noch Dialog-Nahqualität.
- [Android-Menü](evidence/android/01_android_menu.png): laufender Dorfhintergrund und Menüpunkte; der Ausschnitt zeigt nicht den gesamten nach oben gescrollten Titelbereich.
- [Start der ARM64-Download-Datei](evidence/android/07_android_arm64_translated_intro.png): tatsächlich gerendertes Intro mit Diagnoseangaben des Software-Emulators.

Die Screenshot-Hashes wurden gegen den Runtimebericht geprüft. Die beobachteten Software-Emulator-Zeiten sind keine Mobilgeräte-Bildraten. Der zuvor gestoppte Grafik-Dauertest wurde nicht erneut ausgeführt.

## Direkter Downloadweg

Der getrennte Workflow [hero-download.yml](../../.github/workflows/hero-download.yml) veröffentlicht ausschließlich die bereits gebaute und geprüfte Revision über den [Hero-Prerelease](https://github.com/Ullmann27/Imperathen/releases/tag/hero-2026-11-22-d54478ec). Er verlangt den erfolgreichen Gesamtbuild, bindet beide tatsächlich gehashten APKs an ihre Bau-/Runtimebelege und prüft die Hero-Payloads erneut. Eine ausdrückliche Dateiliste enthält nur die ARM64-APK, öffentliche JSON-Nachweise, den Quellcommit, die Godot-Bewegungsaufnahme und Prüfsummen. Ein neuer Release bleibt bis zum vollständigen geprüften Upload ein Draft. Bestehende abweichende Dateien werden nicht überschrieben.

Der neue Publikationsweg und diese Nachweise ändern den Spielquellstand des gelieferten APKs nicht. Die separate parallele Waffen-/Bogenarbeit wurde nicht in die Figurendateien hineinkopiert.

## Verbleibende visuelle Arbeit

Die anatomische Hauptfigur ist technisch integriert. Haare, Augen-/Hautwirkung, Mundinnenraum, Stofffalten und natürliche Kleidungsverformung bleiben unter der vorgegebenen Referenz. Die unabhängige Sichtprüfung des Android-Dorfes zeigt keine offensichtlichen fehlenden Materialien oder ein Schwarzbild; Gesicht und Mimik sind in dieser Rückansicht nicht abnehmbar. [Issue #33](https://github.com/Ullmann27/Imperathen/issues/33) bleibt für diese Qualitätsarbeit offen. Ein frei wählbares Ausrüstungssystem, fertige historische Personen und eine physische Geräteabnahme werden durch diesen Wiederherstellungs- und Lieferabschluss nicht behauptet.
