# IMPERATHEN – installierbare Android-APK bauen

**Ziel:** eine tatsächlich exportierte, signierte APK des vorhandenen Spiels. Android ist die Hauptplattform. Spieler installieren die fertige APK auf ihrem Gerät; Godot, Java und das Android-SDK werden ausschließlich auf dem Baurechner benötigt.

## Festgelegter Bauweg

| Eigenschaft | Festlegung |
| --- | --- |
| Engine | Godot 4.7.2 stable, passende offizielle Exportvorlagen |
| Paketkennung | `at.heinz.imperathen` |
| Version dieses Prototyps | `0.1.0-prototype`, Android-Versionscode 1 |
| Hauptdatei für Geräte | APK mit `arm64-v8a` |
| Zusätzliche Prüfdatei | APK mit `x86_64` für einen Android-Emulator |
| Darstellung | Compatibility, Querformat; Sensor-Querformat ist zulässig |
| Exportverfahren | Vorgebaute Android-APK-Vorlage, ohne eigenen Gradle-/NDK-Bau |
| Signierung | Privater Debug-Schlüssel außerhalb des Repositorys |
| Netzfunktion des Spiels | Offline; keine Internetberechtigung im Exportpreset angefordert |

Der [Exportpreset](../../prototype/export_presets.cfg) enthält ARM64 als Vorgabe. Das [Bauwerkzeug](../../tools/build_android_prototype.py) kann für den Emulator ausschließlich seine temporäre Projektkopie auf x86_64 umstellen. Beide Varianten verwenden dieselben Spielquellen. Die Android-Mindest- und Zielversion werden aus dem **erzeugten Manifest** geprüft und berichtet; die leeren Gradle-Felder im Preset sind keine Zusage einer bestimmten Gerätekompatibilität.

## Voraussetzungen auf dem Linux-Baurunner

Dieser Baupfad verwendet Python ab 3.10, JDK 17, Android Platform-Tools, SDK Platform 35 und Build-Tools 35.0.1. Das offizielle Vorlagenpaket muss `android_debug.apk` und die zugehörige `version.txt` für `4.7.2.stable` enthalten. Der Prüfläufer benötigt die tatsächlich ausführbaren Werkzeuge `aapt`, `apksigner` und `zipalign`. Der Build lädt diese Voraussetzungen nicht selbstständig nach.

Die Versionsauswahl folgt der [offiziellen Android-Exportanleitung für Godot 4.7](https://docs.godotengine.org/en/4.7/tutorials/export/exporting_for_android.html). Diese nennt zusätzliche Werkzeuge für umfassendere Android-Bauumgebungen. Hier wird der bereits kompilierte Enginekern übernommen; eigene native Erweiterungen und ein eigener Gradle-Bau gehören nicht zu diesem APK-Schritt.

## Privaten Signierschlüssel bereitstellen

Der Keystore liegt außerhalb des Repositorys. Schlüsseldateien, tatsächliche Passwörter und ein gegebenenfalls vorhandenes `.godot/export_credentials.cfg` werden nicht veröffentlicht. Das Passwort wird über `GODOT_ANDROID_KEYSTORE_DEBUG_PASSWORD` an den Prozess übergeben. Dateipfad und Alias können über `--keystore` und `--keystore-user` oder über `GODOT_ANDROID_KEYSTORE_DEBUG_PATH` und `GODOT_ANDROID_KEYSTORE_DEBUG_USER` bereitgestellt werden. Das sind die von Godot dokumentierten [Export-Umgebungsvariablen](https://docs.godotengine.org/en/4.7/tutorials/export/exporting_for_android.html#environment-variables).

Der gleiche private Schlüssel muss für spätere direkt darüber installierbare Aktualisierungen erhalten bleiben. Eine neue Signatur bei gleicher Paketkennung ist keine austauschbare Sicherung desselben Entwicklerschlüssels. Die tatsächliche Wiederherstellung des Schlüssels wird getrennt vom öffentlich teilbaren APK-Artefakt verwaltet.

## Ausführen

Die folgenden Pfade sind Parameter des Baurunners. Das Passwort ist vorher in dessen geschützter Prozessumgebung bereitzustellen; es erscheint nicht in der Befehlszeile.

```sh
python tools/build_android_prototype.py \
  --godot /pfad/zu/godot \
  --sdk-root /pfad/zum/android-sdk \
  --java-home /pfad/zum/jdk17 \
  --template-dir /pfad/zu/4.7.2.stable \
  --keystore /privater/pfad/imperathen-debug.keystore \
  --keystore-user imperathen-debug \
  --abi arm64-v8a \
  --output builds/android/IMPERATHEN-arm64-v8a-debug.apk
```

Mit denselben Parametern und `--check` wird ausschließlich geprüft, ob die Voraussetzungen vorliegen. Für den Emulator werden `--abi x86_64` und ein anderer Ausgabename verwendet. Ein fehlendes SDK, eine falsche Engineversion oder unvollständige Signierung führen zu einem Fehlerstatus und keiner Erfolgsmeldung.

## Ablauf und tatsächliche Nachweise

Das Werkzeug kopiert das Projekt ohne Editorcache und vertrauliche Exportdateien in einen temporären Ordner. Dort setzt es die Java-/SDK-Pfade, importiert die Assets und führt den echten Godot-Export aus. Anschließend wird [validate_android_apk.py](../../tools/validate_android_apk.py) mit dem erwarteten Paket und ABI aufgerufen. Nur ein vollständig erfolgreicher Prüfbericht mit passender APK-Prüfsumme erlaubt die Übernahme der Datei an den gewünschten Ausgabeort. Eine alte APK wird bei einem zuvor fehlgeschlagenen Export nicht als neu erzeugt ausgegeben.

Neben der APK entstehen eine SHA-256-Datei, ein Bericht über Engine, Vorlage und Quellstand sowie der tatsächliche APK-Prüfbericht. Letzterer trennt Paketprüfung, Signatur und Architektur von Gerätetests. Der Buildmarker lautet erst nach Erfolg `ANDROID_BUILD_PASS`.

Der Bauablauf ist durch festgelegte Werkzeuge, Quell- und Vorlagenprüfsummen nachvollziehbar wiederholbar. Eine bitidentische ZIP-Datei über sämtliche Laufzeit- und Signierumgebungen wird damit nicht behauptet. Ein erfolgreicher APK-Export belegt außerdem noch keine Bildrate oder Bedienbarkeit auf einem bestimmten Telefon. Dafür folgt ein Start- und Spieltest unter Android; der zusätzliche Emulatorlauf muss mit seiner tatsächlichen Architektur und seinen Grenzen ausgewiesen werden.

**Status dieser Anleitung:** Bauverfahren und Prüfbedingungen sind implementiert. Ob ein konkreter Export oder Gerätelauf bestanden ist, ergibt sich aus dessen erzeugten Berichten und dem Workflow-Ergebnis, nicht aus dieser Anleitung.
