# AP-10 · Android-Prüfbau 8

Stand: 24.11.2026. Entwicklungsbranch: `feature/ap1-ap2-companions-20261124`.
Die Implementierung von AP-1/AP-2 liegt in [PR #53](https://github.com/Ullmann27/Imperathen/pull/53).

## Auftrag und Abnahme

Dieser Schritt baut die vorhandene Implementierung für Android und prüft die
tatsächlich exportierten Dateien. Er enthält keine weitere Änderung an Handlung,
Grafik, Missions-IDs oder dem Spielstandschema v5.

| Bereich | Geplante bzw. festgelegte Prüfung |
|---|---|
| Engine und Renderer | Godot 4.7.2, `gl_compatibility` |
| Android-Paket | `at.heinz.imperathen`, Version `0.8.0-companions`, Versionscode 8 |
| Begleiter im Export | Alle drei Module von AP-1 müssen im APK vorhanden und auflösbar sein |
| Missionsdaten im Export | Alle vierzehn Missionsdateien I-01 bis I-14, Index, Loader und Fähigkeitsdaten |
| Regressionen | Vollständige Python-Tests und alle 64 Godot-Prüfgruppen |
| Android-Laufzeit | Installation und vorhandener automatisierter Touch-/Speicher-/Hintergrundtest im CI-Emulator |
| Auslieferungssignatur | Genau ein verifiziertes Zertifikat, identisch mit der veröffentlichten Build-7-APK |
| Unveränderter Spielinhalt | Byteweise Hash-Gleichheit sämtlicher Nutzdaten vor und nach der lokalen Signierung |
| Fold7 | Separater [Prüfplan](FOLD7_PRUEFPLAN.md); bisher kein ausgeführter Gerätetest |

Die Bezeichnung AP-10 bedeutet nicht, dass der gesamte Abnahmeumfang bereits
erfüllt ist. Der vorhandene Emulatorlauf durchspielt I-00 und die ersten zwei
Kindheitsaktionen. Er durchspielt weder I-02 bis I-14 noch die neuen Begleitwege.
Diese Grenzen müssen im Lieferbericht sichtbar bleiben. Die automatisierten
Godot-Integrationstests prüfen diese Logik zusätzlich außerhalb von Android.

## Lokale Prüfung vor dem CI-Export

Der vollständige Python-Lauf besteht **224 Tests**. Der vollständige erneute
Godot-Lauf besteht **64 von 64 Gruppen ohne Warnungen**. Beim ersten Lauf waren
drei Prozesse mit Exitcode −9 beendet worden; dieser Lauf wurde als fehlgeschlagen
erfasst. Nach Entfernen bereits ausgewerteter temporärer Downloads bestand der
unveränderte vollständige Testlauf. Eine konkrete Ursache des Prozessabbruchs
wird daraus nicht behauptet.

Belege: [Python-Ergebnis](evidence/local-python-summary.json) und
[Godot-Ergebnis einschließlich des ersten Abbruchs](evidence/local-engine-summary.json).
Der nachfolgende GitHub-Lauf muss diese Prüfungen erneut auf dem konkreten
Buildcommit bestehen.

## Betroffene Dateien

- `prototype/export_presets.cfg`: höhere Android-Version bei gleicher Paketkennung.
- `.github/workflows/android-prototype.yml`: APK-Bau und Emulatorlauf für den
  isolierten Entwicklungsbranch aktivieren.
- `tools/validate_android_apk.py`: vollständige Begleit- und Missionsnutzdaten
  prüfen; APK-Zertifikate erfassen und eine einzelne erwartete Signatur erzwingen.
- `tests/android_companion_payload_test.py` und `tests/android_signing_test.py`:
  fehlende, leere oder falsch verknüpfte Nutzdaten sowie falsche, fehlende oder
  mehrdeutige Signaturen müssen die jeweilige Prüfung scheitern lassen.
- `tools/resign_android_apk.py` und `tests/android_resigning_test.py`: einen
  nachgewiesenen CI-Export mit dem privaten Bestandsschlüssel signieren und
  sämtliche Nutzdaten sowie die Ausgabebelege vor Freigabe erneut prüfen.
- `docs/25_android_ap10/`: öffentlicher Prüfbericht und manueller Gerätetestplan.

## Warum die Signierung getrennt erfolgt

Der vorhandene CI-Workflow erzeugt bei jedem Lauf einen neuen privaten
Prototypschlüssel. Eine gültige APK-Signatur allein beweist deshalb keine
Übereinstimmung mit Build 7. Der öffentliche CI-Export ist in diesem Verfahren
die überprüfte Eingabe für die lokale Signierung, noch nicht die für das
Bestandsupdate vorgesehene Auslieferungsdatei.

Die private Wiederherstellungssicherung wurde mit dem öffentlichen
Wiederherstellungszertifikat des Projekts abgeglichen. Anschließend wurde der
gesicherte Build-7-Keystore entschlüsselt. Sein Zertifikat stimmt exakt mit dem
von `apksigner` verifizierten Zertifikat der veröffentlichten APK überein.
Private Schlüssel und Keystores liegen außerhalb des Repositorys.

Öffentliche Referenz:

- [Build-7-Release](https://github.com/Ullmann27/Imperathen/releases/tag/cc0-motion-2026-11-24-7c3194db)
- Commit: `7c3194db13acef2702e5e92336b94e9be41c7b58`
- APK-SHA256: `a101074668a8bf4c7c2c1fde14647032c9173f4f5ff10a79f473a9ef5f8fabe3`
- Zertifikat-SHA256: `a41d5810bcc3214bc4c8d29dcd1899210db37b82a03dec21b3c43552357ae215`
- [Maschinenlesbarer Signaturnachweis](evidence/build7-signing-proof.json)

Die Übereinstimmung gilt für diese konkrete veröffentlichte Build-7-Datei.
Welche APK tatsächlich auf dem privaten Fold7 installiert ist, wurde hier nicht
ausgelesen. Eine andere frühere APK kann ein anderes Zertifikat besitzen.

## Erste CI-Prüfung und Werkzeugkorrektur

Der erste Build-8-Lauf [#84](https://github.com/Ullmann27/Imperathen/actions/runs/45444339144)
bestand die 224 Python-Tests, den vollständigen Engine-Schritt und den
ARM64-Export mit **30 von 30 internen APK-Prüfungen**. Die nachfolgende zweite
Paketprüfung wählte jedoch automatisch Build-Tools 37.0.0. Deren neues
Zertifikatslabel wurde vom auf die vorhandene Werkzeugkette ausgerichteten
Parser nicht erkannt. Die kryptografische Prüfung bestand auch dort; der
zusätzliche Zertifikatsnachweis blieb zu Recht unvollständig.

Beide eigenständigen Workflow-Prüfungen verwenden deshalb jetzt ausdrücklich
`aapt`, `apksigner` und `zipalign` aus **Build-Tools 35.0.1**, wie bereits der
interne Buildvalidator. Keine APK-Prüfung wurde entfernt oder abgeschwächt.
Der erste Lauf wurde nicht zur Auslieferung freigegeben; Emulator-Export und
Android-Laufzeitprüfung waren dort übersprungen worden.

Der [Diagnoseauszug](evidence/run84-diagnosis.json) dokumentiert die identischen
APK-Hashes beider Prüfungen und die tatsächlich beobachteten Ausgabeformate.

## Nachweiskette für die Auslieferung

1. Den vollständigen GitHub-Lauf und seinen Quellcommit festhalten.
2. Das Bauartefakt mit seinem veröffentlichten SHA256 prüfen und die ARM64-APK
   mit ihrem passenden Buildbericht zuordnen.
3. Commit, APK-Größe, APK-SHA256 und die statischen Paketprüfungen vor dem
   Signieren kontrollieren.
4. Ausschließlich mit dem privaten Bestandsschlüssel signieren. Passwörter
   werden über Umgebungsvariablen übergeben, nicht in Dateien protokolliert.
5. Alle ZIP-Nutzdaten vor und nach dem Signieren anhand von Namen, Größe und
   SHA256 vergleichen. Nur die ausdrücklich bekannten Signaturdateien dürfen
   sich unterscheiden; doppelte oder unerwartete Archiveinträge führen zum Abbruch.
6. Die fertige Datei mit dem verpflichtenden Build-7-Zertifikat-Pin prüfen und
   APK, Prüfsumme und JSON-Nachweise zusammen in einem neuen Ausgabeverzeichnis
   freigeben. Eine bestehende Ausgabe wird nicht überschrieben.

Ein Emulatorlauf des CI-Exports ist ein Laufzeitnachweis für dessen konkrete
Datei. Nach der lokalen Signierung hat die Auslieferungs-APK einen anderen
Gesamt-Hash. Der Nutzdatenvergleich belegt identische Spiel- und Engineinhalte;
er wird nicht als eigener Installations- oder Laufzeittest der neu signierten
Datei ausgegeben. Das gilt ausdrücklich auch für die noch offene Installation
auf dem Fold7.

## Sichtprüfung und verbleibende Abnahme

Die Vorher-/Nachher-Aufnahmen zu den sichtbaren Änderungen von AP-1 liegen in
[der vorangegangenen Lieferung](../24_ap1_ap2/DELIVERY.md). Dieser Bauschritt
ändert die Darstellung nicht. Zusätzliche Emulatorbilder belegen den Start und
die dort ausgeführten Aktionen, aber keine neue Grafikverbesserung.

Erst ein tatsächlicher Fold7-Lauf kann dortige Bedienung, Anzeigewechsel,
Bildrate, Frametime, Akkuverbrauch und Wärmeverhalten nachweisen. Hierzu liegen
mir keine gesicherten Daten vor.
