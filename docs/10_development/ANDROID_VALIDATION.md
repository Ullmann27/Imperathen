# Android-APK: Prüfkriterien und Nachweisgrenzen

**Stand: 22.11.2026. Zielplattform: zuerst Android.**

Der aktuelle Liefergegenstand ist eine tatsächlich exportierte, signierte und auf der vorgesehenen Architektur installierbare APK. Der bisherige Godot-Quellstand und seine Headless-Tests sind dafür eine Grundlage. Sie ersetzen weder ein APK-Artefakt noch dessen Installation und Ausführung.

Dieses Dokument beschreibt das Prüfverfahren. Der aktuelle APK-Befund steht im vom Validator erzeugten JSON-Bericht. Das Vorhandensein dieses Dokuments bedeutet keinen erfolgreichen Android-Lauf.

## 1. Werkzeug und Aufruf

`tools/validate_android_apk.py` verwendet die Python-Standardbibliothek und vorhandene Android-SDK-Werkzeuge. Es installiert keine Pakete, startet keinen Emulator, greift nicht auf angeschlossene Geräte zu und verändert oder signiert die untersuchte APK nicht.

```sh
python3 tools/validate_android_apk.py \
  --apk build/android/IMPERATHEN-debug-arm64.apk \
  --sdk-root /pfad/zum/android-sdk \
  --expected-package at.heinz.imperathen \
  --expected-abi arm64-v8a \
  --report build/android/apk-validation.json
```

Der Dateipfad ist ein Beispiel und muss auf das tatsächlich gebaute Artefakt zeigen. Alternativ ist der APK-Pfad als positionsgebundenes Argument zulässig. `--apk` und das positionsgebundene Argument dürfen nicht gleichzeitig angegeben werden.

Für einen getrennten Emulator-Build kann `--expected-abi x86_64` verwendet werden. Dieser Build ersetzt nicht das ARM64-Hauptartefakt. Beide Dateien erhalten eigene Prüfsummen und Berichte. Standardwerte sind `at.heinz.imperathen` und `arm64-v8a`.

Die Werkzeugsuche berücksichtigt zuerst explizite Werkzeugpfade, dann `--sdk-root`, die bestehenden Umgebungsvariablen `ANDROID_HOME`/`ANDROID_SDK_ROOT`, typische SDK-Orte und zuletzt `PATH`. Ein SDK mit Build Tools 35.0.1 ist ein vorgesehener Aufrufer; der Validator verlangt keine Neuinstallation. Einzelne Pfade können über `--aapt`, `--aapt2`, `--apkanalyzer`, `--apksigner` und `--zipalign` angegeben werden. Ein Werkzeugaufruf besitzt ein Zeitlimit von standardmäßig 45 Sekunden.

## 2. Verbindliche statische Prüfungen

| Prüfung | Voraussetzung für einen positiven Befund |
|---|---|
| Tatsächliche Datei | Vorhandene APK-Datei mit dokumentierter Größe und SHA-256. Eine Dateiendung allein genügt nicht. |
| ZIP-Verzeichnis | Lesbare Struktur, keine doppelten oder unsicheren Pfade, keine verschlüsselten Mitglieder oder symbolischen Links; dokumentierte Größenlimits. Es wird nichts entpackt. |
| ZIP-Inhalt | Alle Mitglieder werden tatsächlich gelesen und auf CRC-Fehler geprüft. |
| Android-Grundstruktur | Nicht leere `AndroidManifest.xml`, `resources.arsc` und `classes.dex`; passende Binärheader sowie plausible deklarierte DEX-Dateilänge. |
| Native Engine | `lib/<erwartete ABI>/libgodot_android.so` existiert als ELF64 mit passender Maschinenkennung und Shared-Library-Typ. ARM64 und x86_64 werden unterschieden. Weitere enthaltene ABIs werden ausgewiesen. |
| Godot-Projekt | Projektkonfiguration und die tatsächlichen Kernressourcen des vorhandenen Prototyps sind enthalten. Ein Engine-Template ohne Spielprojekt genügt nicht. |
| Manifest | `aapt`, `aapt2` oder `apkanalyzer` decodiert das kompilierte Manifest. Paketname muss dem erwarteten Wert entsprechen; eine startbare Activity muss vorhanden sein. |
| Signatur | Ein vorhandenes `apksigner` führt `verify --verbose` am untersuchten APK tatsächlich erfolgreich aus. |
| ZIP-Ausrichtung | Wenn vorhanden, führt `zipalign -c -v 4` eine echte Prüfung durch. Ein fehlendes `zipalign` wird offen ausgewiesen. |

Der Projektinhalt umfasst `main.tscn`, den Einstieg, den Domainkern, die Spielwelt samt Geometriehelfer und die Oberfläche samt Touch-Pad und Touch-Aktionssteuerung. Der Validator berücksichtigt direkt vorhandene Dateien, GDScript-/Szenenkonvertierungen und `.remap`-Verweise. Ein Remap besteht die Prüfung nur, wenn sein Ziel tatsächlich im APK liegt. Die Android-Exportarchitektur mit Projektdateien unter `assets/` ist in der Godot-Dokumentation beschrieben. [1]

Ein abweichender Export mit einem PCK-Paket wird erkannt, sein Inhaltsindex derzeit jedoch nicht ausgewertet. Das Ergebnis bleibt deshalb **unvollständig**, solange die erforderlichen Projektressourcen nicht bestätigt werden können. Es wird nicht durch eine optimistische Annahme auf „bestanden“ gesetzt.

Die Headerprüfungen sind begrenzte Strukturprüfungen. Sie beweisen keine korrekte Ausführung beliebigen Bytecodes oder aller nativen Funktionen. Auch die gewöhnliche ZIP-Ausrichtung beweist keine vollständige Unterstützung von Geräten mit 16-KB-Speicherseiten.

## 3. Signatur und Manifest: keine Ersatznachweise

Der Name einer `.RSA`-Datei oder ein erkennbarer APK-Signaturblock ist nur ein Hinweis auf vorhandene Signaturstrukturen. Ohne erfolgreiche kryptografische Prüfung wird keine gültige Signatur behauptet. Der Validator liest keine Keystore-Datei, keine privaten Schlüssel und keine Kennwörter. [2]

`apksigner verify` prüft standardmäßig anhand der im Manifest angegebenen Android-Kompatibilität. Ein erfolgreicher Debug-Signaturcheck ist für die technische Prototypprüfung verwendbar; er bestätigt weder die rechtliche Herausgeberidentität noch eine Storefreigabe. Der Validator signiert nichts selbst. [2]

Manifestwerte werden vom tatsächlichen APK gelesen. `apkanalyzer manifest print` ist ein offizieller Weg zur XML-Darstellung; ein im Quellprojekt eingetragener Paketname wird nicht als Ersatz für das exportierte Manifest übernommen. [3]

Ein Paketname aus `aapt dump badging` beendet die Decoder-Kette nicht vorzeitig. Wenn `apkanalyzer` vorhanden ist, hat dessen tatsächliche XML-Dekodierung Vorrang. Das ist für Godots Start-Alias wichtig: Ein `activity-alias` kann den öffentlichen Einstieg bereitstellen, während seine Zielaktivität `exported="false"` behält. Eine private Zielaktivität wird deshalb nicht als Fehler behandelt. [5]

Im XML müssen `MAIN` und `LAUNCHER` im selben Intent-Filter einer aktivierten und exportierten Startkomponente stehen. Anwendung und Komponente müssen aktiviert sein; bei einem Alias prüft der Prototyp-Validator zusätzlich das vorher deklarierte und aktivierte Ziel. Ab Ziel-API 31 wird ein fehlendes explizites `exported` bei einer Komponente mit Intent-Filter nicht als gültiger Einstieg akzeptiert. Im Bericht stehen die tatsächlichen Attribute, Filter und Ablehnungsgründe unter `manifest.launcher_diagnostics`, außerdem die begrenzte Originalausgabe des XML-Werkzeugs. Fehlende oder unaufgelöste XML-Evidenz erzeugt keinen erfolgreichen Launcherbefund; ein nachweislich fehlender Einstieg bleibt ein Fehler. [5]

## 4. JSON-Bericht und Exitcodes

Der Bericht enthält Zeitpunkt, APK-Pfad, Größe und SHA-256, erwartetes Paket und ABI, gefundene SDK-/Werkzeugpfade, Manifestmetadaten, einzelne Prüfergebnisse und begrenzte Ausgaben der tatsächlich ausgeführten Prüfkommandos.

| Exitcode | `overall_status` | Bedeutung |
|---:|---|---|
| 0 | `pass` | Alle verpflichtenden statischen Prüfungen bestanden. |
| 1 | `fail` | Mindestens ein verpflichtender Befund ist negativ, etwa CRC, ABI, Paketname oder Signatur. |
| 2 | `incomplete` | Erforderliche Evidenz fehlt, beispielsweise wegen fehlendem `apksigner`, fehlgeschlagener Werkzeugausführung oder nicht geprüftem PCK-Inhalt. |

Ungültige CLI-Argumente können ebenfalls Exitcode 2 liefern, bevor ein Bericht entsteht. Deshalb verlangt die Build-Pipeline zusätzlich die vorhandene JSON-Datei mit `passed: true`, statt nur nach einer Dateiendung oder einem einzelnen Logwort zu suchen.

`source_snapshot` enthält die SHA-256-Werte des vorhandenen lokalen Projektstands. Diese identifizieren die begleitend betrachteten Quellen; sie beweisen **nicht automatisch**, dass transformierte APK-Dateien aus exakt diesem Stand gebaut wurden. Dafür müssen Bauprotokoll, verwendeter Commit und Exportlauf zusätzlich zusammenpassen.

`device_tests.status` bleibt in diesem Validator immer `not_run`; `installability` bleibt `not_demonstrated_on_a_device`. Ein separater Lauf darf diese Grenzen nicht durch Umbenennen eines statischen Reports verdecken.

## 5. Gesonderter Android-Lauf

Ein weiterer Bericht muss das konkrete APK anhand seiner Prüfsumme zu einem tatsächlichen Installations- und Startversuch zuordnen. Zu dokumentieren sind mindestens Android-Version, Geräte-/Emulatorart, ABI, Installationsresultat, gestartete Activity und beobachtetes Verhalten. Eine fehlende oder nicht autorisierte Geräteverbindung wird als fehlende Evidenz geführt. [4]

Für den ersten Spieltest werden Vorspann, Menü, neuer Spielstand, Touchbewegung samt gleichzeitigem Angriff, Bauplatzierung, Ausbildung, Kampf, Folgeentscheidung, Speichern/Laden und App-Hintergrundwechsel überprüft. Audio, sichtbare Bildfehler und Bildschirmränder benötigen echte Beobachtungen. FPS, Energieverbrauch und thermisches Verhalten werden nur mit passenden tatsächlichen Messungen berichtet.

Ein x86_64-Emulator kann einen Start- und Ablaufnachweis für **diesen Emulator-Build** liefern. Er bestätigt keine ARM64-Ausführung auf Heinz’ Handy und keine Leistung eines konkreten Mobilchips.

## 6. Tatsächlich geprüfter Validatorstand

Bei der lokalen Werkzeugbestandsprüfung waren `/usr/bin/java`, `/usr/bin/keytool` und `/usr/bin/unzip` verfügbar. Android-SDK-Prüfwerkzeuge, ADB und Emulator wurden zu diesem Zeitpunkt weder im Suchpfad noch an den untersuchten SDK-Orten gefunden. Es wurden keine Werkzeuge durch diesen Prüfblock installiert; eine spätere CI-Umgebung besitzt einen eigenen Bestand.

Der Validator wurde mit dreizehn gezielten Negativ- und Parserprüfungen ausgeführt: fehlende Datei, Textdatei und Projekt-ZIP mit APK-Endung, unsicherer ZIP-Pfad, CRC-Beschädigung und ungültig komprimierte Daten, falsche ABI, fehlendes Remap-Ziel sowie Manifestparser. Auch ein künstliches Strukturbeispiel mit plausiblen Headern und erfundenem Zertifikatdateinamen erhielt **keinen positiven APK-Befund**. Das sind Prüfungen des Prüfwerkzeugs; es wurde dabei kein installierbares Spiel oder Gerätelauf behauptet.

## Primärquellen

1. [Godot – Android library und Projektdateien unter assets](https://docs.godotengine.org/en/stable/tutorials/platform/android/android_library.html)
2. [Android – apksigner](https://developer.android.com/tools/apksigner) und [offizielle Hilfe zu verify](https://android.googlesource.com/platform/tools/apksig/+/master/src/apksigner/java/com/android/apksigner/help_verify.txt)
3. [Android – apkanalyzer](https://developer.android.com/tools/apkanalyzer)
4. [Android – ADB und Installation einer APK](https://developer.android.com/tools/adb)
5. [Android – activity-alias](https://developer.android.com/guide/topics/manifest/activity-alias-element) und [activity](https://developer.android.com/guide/topics/manifest/activity-element)
