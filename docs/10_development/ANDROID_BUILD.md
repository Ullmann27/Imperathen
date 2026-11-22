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

Die Werkzeuge für Bau und Laufzeitprüfung verwenden Python ab 3.11, JDK 17, Android Platform-Tools, SDK Platform 35 und Build-Tools 35.0.1. Das offizielle Vorlagenpaket muss `android_debug.apk` und die zugehörige `version.txt` für `4.7.2.stable` enthalten. Der Prüfläufer benötigt die tatsächlich ausführbaren Werkzeuge `aapt`, `apksigner` und `zipalign` sowie für die Aliasprüfung `apkanalyzer` aus den Android Command-line Tools. Das Bauwerkzeug lädt diese Voraussetzungen nicht selbstständig nach.

Im Projekt muss außerdem `rendering/textures/vram_compression/import_etc2_astc=true` gesetzt sein. Der erste tatsächliche CI-Export wurde wegen dieser fehlenden Android-Importvoraussetzung abgebrochen. Die Projekteinstellung ist inzwischen ergänzt, und das Bauwerkzeug prüft sie vor dem Export. Der nachfolgende Export hat diese Hürde bestanden.

Die Versionsauswahl folgt der [offiziellen Android-Exportanleitung für Godot 4.7](https://docs.godotengine.org/en/4.7/tutorials/export/exporting_for_android.html). Diese nennt zusätzliche Werkzeuge für umfassendere Android-Bauumgebungen. Hier wird der bereits kompilierte Enginekern übernommen; eigene native Erweiterungen und ein eigener Gradle-Bau gehören nicht zu diesem APK-Schritt.

## Privaten Signierschlüssel bereitstellen

Der Keystore liegt außerhalb des Repositorys. Private Schlüsseldateien und ein gegebenenfalls vorhandenes `.godot/export_credentials.cfg` werden nicht veröffentlicht. Das Passwort wird über `GODOT_ANDROID_KEYSTORE_DEBUG_PASSWORD` an den Prozess übergeben. Dateipfad und Alias können über `--keystore` und `--keystore-user` oder über `GODOT_ANDROID_KEYSTORE_DEBUG_PATH` und `GODOT_ANDROID_KEYSTORE_DEBUG_USER` bereitgestellt werden. Das sind die von Godot dokumentierten [Export-Umgebungsvariablen](https://docs.godotengine.org/en/4.7/tutorials/export/exporting_for_android.html#environment-variables).

**Der derzeitige CI-Einstiegsbau erzeugt bei jedem Lauf einen neuen Signierschlüssel.** Er verschlüsselt dessen Keystore mit dem öffentlichen Wiederherstellungszertifikat als CMS-Datei mit AES-256-GCM. Dieser verschlüsselte Keystore und das öffentliche Zertifikat dürfen im Bauartefakt liegen. Der dazugehörige private RSA-Wiederherstellungsschlüssel und der eigentliche Keystore werden getrennt privat gesichert; sie gehören weder in das Repository noch in den öffentlichen APK-Download. Das Debug-Passwort allein bildet dabei keine Geheimhaltungsgrenze für den Keystore.

Vor einer Aktualisierung bereits verteilter Installationen muss der zu deren APK gehörende **gleiche private Signierschlüssel** privat in den Bauprozess eingespeist werden. Der momentan automatische Neuschlüsselbau erfüllt diese Updatevoraussetzung nicht. Eine neue Signatur bei gleicher Paketkennung ist keine austauschbare Sicherung desselben Entwicklerschlüssels. Daher wird für beliebige aufeinanderfolgende CI-Artefakte kein direkt darüber installierbares Update versprochen. Die endgültige Lieferdokumentation ordnet APK, Signatur und private Wiederherstellungssicherung dem konkreten Bau zu.

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

## Realisierter CI-Bau und geklärte Launcher-Prüfung

Der eingerichtete Workflow [Android prototype APK](../../.github/workflows/android-prototype.yml) führt den Bau auf GitHub mit Ubuntu 24.04 aus. Er prüft die offiziellen Engine- und Vorlagenarchive gegen deren SHA-512-Summen, nutzt JDK 17 sowie die festgelegten Android-Werkzeuge und führt vor dem Export die vorhandenen Engine-Regressionsprüfungen aus. Er sieht getrennte ARM64- und x86_64-Exporte, APK-Prüfberichte, Artefaktübernahme und anschließend einen Android-Emulatorlauf vor.

**Bereits tatsächlich erreicht:** Die sechs Engine-Prüfgruppen, die Vorlagenprüfung und die Android-Bauvorbereitung sind im CI gelaufen. Nach Korrektur der ETC2-/ASTC-Einstellung wurde eine ARM64-APK tatsächlich exportiert. Deren Android-Signatur wurde mit `apksigner` einschließlich v2 und v3 bestätigt; Ressourcen- und Architekturprüfungen bestanden ebenfalls. Dieser Nachweis ist kein Platzhalterexport und keine bloß umbenannte Datei. Er allein ist noch kein abgeschlossener Start- oder Bediennachweis auf Android.

Die anschließende Prüfung stieß auf eine Eigenheit der verwendeten Werkzeuge: Godot 4.7.2 definiert in seiner [originalen AndroidManifest.xml](https://github.com/godotengine/godot/blob/4.7.2-stable/platform/android/java/app/src/main/AndroidManifest.xml) eine private Aktivität `.GodotApp` und den exportierten Alias `.GodotAppLauncher`. Der Alias besitzt im selben Intent-Filter `MAIN`, `DEFAULT` und `LAUNCHER`. Das klassische [AAPT-Badging](https://github.com/aosp-mirror/platform_frameworks_base/blob/master/tools/aapt/Command.cpp) erkennt für seine Ausgabe `launchable-activity` nur den Elementtyp `activity`; ein gültiger `activity-alias` kann deshalb in dieser Zusammenfassung fehlen. Godots [eigener Exporter](https://github.com/godotengine/godot/blob/4.7.2-stable/platform/android/export/export_plugin.cpp) berücksichtigt den Launcher-Alias beim Android-Start ausdrücklich.

Der Validator prüft deshalb zusätzlich das tatsächlich exportierte Manifest über `apkanalyzer`: Eine aktivierte, exportierte Aktivität oder ein entsprechender Alias muss `MAIN` und `LAUNCHER` gemeinsam in einem Intent-Filter besitzen. Bei einem Alias muss die Zielaktivität existieren und aktiviert sein; ihre eigene Einstellung `exported=false` ist zulässig. Die Presetwerte `show_in_app_library=true` und `show_as_launcher_app=false` bleiben unverändert. Der zweite Wert entscheidet laut [Godot-Referenz](https://docs.godotengine.org/en/4.7/classes/class_editorexportplatformandroid.html#class-editorexportplatformandroid-property-package-show-as-launcher-app) über die Rolle als Android-Home-App und ist kein Schalter zum Beheben dieser AAPT-Auslassung.

## Grafiktreiber des Android-Prüflaufs

Ein nachfolgender x86_64-Android-Lauf startete die App und den neuen Lebensbogen, zeigte jedoch schwarze Spielbilder. Das Emulatorprotokoll nannte `gles_mode_selected:swiftshader` und `OpenGL ES 3.0 SwiftShader 4.0.0.1`; Godot meldete wiederholt `Fragment shader active uniforms exceed GL_MAX_FRAGMENT_UNIFORM_VECTORS (261)`. Dieser Lauf gilt deshalb nicht als bestandene Grafik- oder Spielabnahme.

Der Workflow verwendet jetzt `-gpu swangle` statt `-gpu swiftshader_indirect`. Die [aktuelle Android-Dokumentation](https://developer.android.com/studio/run/emulator-acceleration?hl=en) führt den alten Parameter seit Emulator 36.4.9 als veraltet und unterstützt `swangle` als ANGLE-Modus über SwiftShader. Die [SwiftShader-Dokumentation](https://android.googlesource.com/platform/external/swiftshader/+/953cd0fb18b779b33e00286e1721cfb8ab0d8278/docs/ANGLE.md) empfiehlt für GLES ebenfalls ANGLE über SwiftShader-Vulkan. Die Korrektur wechselt den Grafiktreiber des Prüfrechners; sie ändert den Compatibility-Renderer des Spiels nicht.

**Tatsächlich geprüfte Lieferung:** Commit `b3d8e01e64663480d228777a7244a2a882bcac18`, [CI-Lauf 45038377950](https://github.com/Ullmann27/Imperathen/actions/runs/45038377950) vollständig erfolgreich. Die separate x86_64-APK wurde auf Android API 35 installiert und bedient. Das tatsächliche Protokoll nennt ANGLE über SwiftShader und OpenGL ES 3.1; Menü, Dorf und Pause sind sichtbar. Die vollständigen Beobachtungen und Grenzen stehen in [ANDROID_INSTALL.md](ANDROID_INSTALL.md).

Der Laufzeittest berücksichtigt den tatsächlich beobachteten Android-Erststarthinweis: Dessen XML-Paket heißt `android`; Titel und Bestätigung werden anhand von `android:id/immersive_cling_title` und `android:id/ok` erkannt. Klickkoordinaten stammen aus dem frischen UI-Dump. Frühere Annahmen über `com.android.systemui` führten zu einem sichtbaren Hinweis, der die Zurück-Eingabe abfing; dieser Prüfablauffehler ist behoben. Auf dem langsamen Software-Renderer wartet der Test auf echte Engine-/Menümarker mit begrenzten Fristen, statt Laufzeiterfolg aus einer kurzen festen Wartezeit abzuleiten. Sämtliche Godot-/Skript-/Shaderfehler bleiben blockierend.

Der Bauablauf ist durch festgelegte Werkzeuge, Quell- und Vorlagenprüfsummen nachvollziehbar wiederholbar. Eine bitidentische ZIP-Datei über sämtliche Laufzeit- und Signierumgebungen wird damit nicht behauptet. Ein erfolgreicher APK-Export belegt außerdem noch keine Bildrate oder Bedienbarkeit auf einem bestimmten Telefon. Dafür folgt ein Start- und Spieltest unter Android; der zusätzliche Emulatorlauf muss mit seiner tatsächlichen Architektur und seinen Grenzen ausgewiesen werden.

## Dorf-Basis vom 22. November 2026

Vor der Integration des Talgefechts wurde der zusammengeführte Dorfstand `ebcf2d8` mit Godot 4.7.2 als ARM64-APK exportiert. Der lokale Prüfbau umfasst 28.698.864 Byte und hat SHA-256 `5e3f049bd5e93ffa647a3395be648f5c11d44dd56b0acbf40ad608a8ad311e87`. Das kompilierte Manifest nennt API 24 als Minimum, API 36 als Ziel, die Launcher-Alias-Klasse `com.godot.game.GodotAppLauncher` und keine angeforderten Berechtigungen. Die Signaturen v2 und v3 wurden verifiziert. Der CI-Export desselben Quellstands erzeugte zwei separat signierte APKs. [Dorf-Baulauf](https://github.com/Ullmann27/Imperathen/actions/runs/45035264853)

## Desktop aus denselben Spielquellen

Die offiziellen Vorlagen für Godot 4.7.2 enthalten `linux_debug.x86_64` und `windows_debug_x86_64.exe`. Die Presets betten die Spieldaten in die jeweilige ausführbare Datei ein. Von der Repository-Wurzel aus:

```sh
mkdir -p builds/desktop
godot --headless --path prototype --editor --import
godot --headless --path prototype --export-debug "Linux x86_64" "$PWD/builds/desktop/IMPERATHEN.x86_64"
godot --headless --path prototype --export-debug "Windows x86_64" "$PWD/builds/desktop/IMPERATHEN.exe"
builds/desktop/IMPERATHEN.x86_64 --headless --quit-after 10
```

Der Workflow speichert die Windows-EXE, ein Linux-Tararchiv mit Ausführungsrecht und SHA-256-Werte im Desktop-Artefakt. Beide Desktop-Ausgaben unterstützen Maus und Tastatur. [Exportpresets](../../prototype/export_presets.cfg)

**Stand der früheren Dorf-Lieferung.** Die dokumentierte ARM64-APK besitzt einen erfolgreichen statischen Bau-/Signaturnachweis; der getrennte x86_64-Android-Test ist erfolgreich. [Installationsanleitung](ANDROID_INSTALL.md), tatsächliche Berichte und APK-Prüfsummen ordnen die Ergebnisse dem konkreten Quellcommit zu. Ein vollständiger Spieltest auf einem physischen ARM64-Telefon bleibt offen.
