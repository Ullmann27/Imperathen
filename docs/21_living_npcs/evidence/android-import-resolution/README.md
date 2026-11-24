# Android-Importauflösung: gezielte Harness-Korrektur

## Anlass

Android-Lauf [72](https://github.com/Ullmann27/Imperathen/actions/runs/45344763960)
für Commit `1ac1afee0796601a5a68d704058f6014907aa32b` bestand 31 Laufzeitprüfungen.
Der nächste Check `meshy_severus_loaded` scheiterte, obwohl der echte Android-
Snapshot Severus mit 15 Knochen, beiden Gangarten und einem an `Hand_R`
gebundenen Signum nachwies. `ci72-runtime.json` ist der unveränderte JSON-Inhalt
des vom Job ausgegebenen fehlgeschlagenen Runtimeberichts, aus den Joblogs
extrahiert. Die APK-SHA256 und der Quell-/Harness-Commit stehen im Bericht.

Die alte Paketprüfung akzeptierte nur rohe `.glb` oder `.glb.remap`. Godots
Export enthält hier `.glb.import` und die referenzierte `.scn`. Der
Laufzeitnachweis wurde damit wegen eines falschen Paketpfadformats abgelehnt.

## Änderung und Grenzen

`meshy_runtime_package_check` verwendet für den tatsächlich beobachteten Körper
und das tatsächlich beobachtete Signum die bestehenden Funktionen
`resolve_resource` und `record_payload_hash`. Beide Ressourcen müssen auf
nichtleere Dateien im geprüften APK auflösen. Der Check protokolliert die
konkreten Einträge, Importdateien, Größen und SHA256-Werte. Die Hashes beziehen
sich auf exportierte Bytes; Gleichheit mit den Quell-GLBs wird nicht behauptet.

Die bisherigen Prüfungen für aktive Meshy-Figur, Knochen, `march`/`run`, Hand
und Signum bleiben erhalten. Die Geh-, Bewohner- und Neustartprüfungen werden
nicht verändert. Dieselbe korrigierte Paketprüfung wird vor und nach dem
echten Android-Neustart aufgerufen.

## Gezielte Prüfung

`python3 verify.py` in diesem Ordner führt die 96 Python-Regressionen und den
CLI-Import aus. Es baut außerdem ausschließlich im Arbeitsspeicher eine ZIP-
Fixture aus den bereits vorhandenen echten Godot-Importdateien für genau die
beiden von CI72 beobachteten Modelle. Die alte Prüfung lehnt diese Fixture ab,
die korrigierte Prüfung löst beide nichtleeren Szenen auf und hasht ihre Bytes.
Es startet keine Engine und verändert keine Importdateien.

Die acht neuen Unit-Tests prüfen Importauflösung und exakte Hashes für Körper
und Signum, weiterhin unterstützte direkte Ressourcen sowie fehlende Modelle,
fehlende oder leere Importziele, lose Importdateien und leere direkte Dateien.
Ein korrektes Paket ersetzt dabei niemals die reale Rig-/Handbeobachtung.

Die kleine ZIP in den Unit-Tests enthält synthetische Bytes im tatsächlichen
Godot-Exportlayout. Der zusätzliche Replay verwendet vorhandene echte lokale
`.import`-/`.scn`-Dateien. **Beides ist kein neuer Android-Lauf und keine Abnahme
der ARM64-APK.** Native Geh- und Neustartnachweise wurden im ursprünglichen
Lauf wegen des frühen Abbruchs noch nicht erreicht. Sie müssen im folgenden
Android-Lauf auf dessen genauem Commit und APK erneut erfolgreich durchlaufen.

Die konkreten Ergebnisse, Eingangs- und Quellhashes stehen in `validation.json`,
die ausgeführten Python- und CLI-Ausgaben in `unit-tests.log` und `cli-import.log`.
