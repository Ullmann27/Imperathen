# Tatsächliche Android-Liefernachweise

Geprüfter Spielquellstand: `b3d8e01e64663480d228777a7244a2a882bcac18`. Der [GitHub-Lauf 45038377950](https://github.com/Ullmann27/Imperathen/actions/runs/45038377950) ist erfolgreich. Spätere reine Dokumentationscommits ändern diesen in die APK eingebauten Quellstand nicht.

| Nachweis | Datei |
| --- | --- |
| Zuordnung von Quellcommit, Artefakten, APKs und Grenzen | [delivery_record.json](delivery_record.json) |
| Unabhängiger Abgleich der tatsächlichen Dateien und Bilder | [independent_audit.json](independent_audit.json) |
| ARM64-Bauherkunft und Paket-/Signaturprüfung | [Build](IMPERATHEN-0.1.0-arm64.build.json), [Validierung](IMPERATHEN-0.1.0-arm64.validation.json) |
| Separates x86_64-Testpaket | [Build](IMPERATHEN-0.1.0-emulator.build.json), [Validierung](IMPERATHEN-0.1.0-emulator.validation.json) |
| Tatsächliche Android-Installation und Eingaben | [runtime-report.json](runtime-report.json) |
| App- und Emulatorprotokoll | [logcat.txt](logcat.txt), [android-emulator.log](android-emulator.log) |
| Engine-Regressionslauf aus demselben CI-Bau | [engine-validation-report.json](engine-validation-report.json) |
| Echte Bilder bei 1280 × 720 | [Menü](01_android_menu.png), [Dorf](02_android_world.png), [Pause](03_android_pause.png) |

Die XML-Dateien halten die tatsächlich gelesene Android-Oberfläche vor und nach dem ersten Vollbildhinweis fest. Die zugehörigen APK-Dateien liegen im verlinkten GitHub-Bauartefakt und sind dem Projektinhaber zusätzlich direkt bereitgestellt. Private Signierschlüssel gehören nicht in diesen Ordner.

## Grenzen

Der Android-Lauf verwendet x86_64, API 35 und einen Emulator mit Softwaregrafik. Er bestätigt keinen Lauf der ARM64-Datei auf einem physischen Telefon, keine mobile FPS-/Energie-/Temperaturleistung und keinen vollständigen Android-Durchgang durch Sammeln, Bauen und Kampf. Letzteren Ablauf prüfen die separaten tatsächlichen Headless-Integrationstests. Die drei Bilder wurden visuell gesichtet; im Pausebild überlagert die vorübergehende Willkommensmeldung den unteren Menüteil. Das bleibt ein dokumentierter UI-Befund.
