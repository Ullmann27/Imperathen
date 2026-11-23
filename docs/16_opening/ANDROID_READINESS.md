# Android-Bau des neuen Spielanfangs

**Stand: 23. November 2026. Status: CI-Bau 45115192890 auf `b356a0c8e3a01285d5c55fc426299fe94d8b30d9` erfolgreich abgeschlossen; APKs und Desktop-Exporte gebaut, 41 Android-Laufzeitprüfungen bestanden.**

## Gewählter Bauweg

Der bestehende Workflow [Android prototype APK](../../.github/workflows/android-prototype.yml) berücksichtigt jetzt zusätzlich `feature/cinematic-opening-20261123`. Die einzige Workflowänderung ergänzt diesen Namen in `on.push.branches`. Runner, Berechtigungen, Werkzeuge, Signierung, Prüfungen, Laufzeitgrenzen, Artefakte und alle bisherigen Branches bleiben unverändert.

Ein Push mit einer Änderung unter `prototype/`, einem bereits aufgelisteten Android-Werkzeug oder der Workflowdatei selbst löst damit den vorhandenen Bau aus. Reine Dokumentationsänderungen lösen wegen des bestehenden Pfadfilters keinen Bau aus. Ein passender Push muss tatsächlich bei GitHub angekommen sein; ein lokal gültiges YAML ist kein gestarteter oder bestandener CI-Lauf.

Der Job verwendet `ubuntu-24.04` und hat im geprüften Workflow **78 Minuten** Gesamtlaufzeitgrenze. Die vorhandene Emulatorstufe besitzt separat 58 Minuten. Das sind Obergrenzen und keine Zusage zur wirklichen Bauzeit.

## Konkrete bestehende Stufen

| Stufe | Tatsächlich im Workflow vorgesehen |
| --- | --- |
| Quelle | Checkout des ausgelösten Commitstands; Dateinamen enthalten dessen kurze SHA |
| Engine | Godot 4.7.2 und passende offizielle Exportvorlagen; die heruntergeladenen Archive werden gegen die veröffentlichten SHA-512-Summen geprüft |
| Android-Werkzeuge | JDK 17, SDK Platform 35 und Build-Tools 35.0.1; vorhandener SDK-Installationsschritt bei fehlenden Build-Tools |
| Regressionsprüfung | `tools/check_prototype.py` mit den bestehenden und hinzugefügten Engine-Suiten |
| Gerätedatei | Signierter ARM64-Debugexport von `prototype/` über `tools/build_android_prototype.py` |
| APK-Nachweis | `tools/validate_android_apk.py` prüft die echte Datei, Projektressourcen, Manifest, Signatur, ABI und ZIP-Ausrichtung |
| Emulatordatei | Getrennter x86_64-Export aus denselben Quellen; eigener statischer Prüfbericht |
| Laufzeit | Eigener Android-35-Emulator im CI mit `swangle`; `tools/android_runtime_smoke.py` bedient den echten Einstieg einschließlich neuer Intro-/Pause-/Zielkartenwege |
| Nachweise | APKs, SHA-256-Dateien, Commitzuordnung, Engine-/APK-Berichte und gesonderte Emulatorbilder und -protokolle als vorhandene Actions-Artefakte |

Der vorhandene Workflow erzeugt außerdem seine bereits vorgesehenen Desktop-Dateien. Die zusätzliche, branchgebundene Grafik-Soak-/Vulkan-Prüfung ist auf diesem Opening-Branch weiterhin deaktiviert; ihre vorhandene Bedingung betrifft `integration/realistic-android-23`.

Der private APK-Keystore wird ausschließlich im temporären Runnerbereich erzeugt. Die bestehende CMS-Verschlüsselung mit dem öffentlichen Wiederherstellungszertifikat sichert ihn als verschlüsseltes Artefakt; ein unverschlüsselter Keystore oder privater Wiederherstellungsschlüssel gehört nicht in das Repository. Der bisherige Workflow erzeugt pro Lauf einen neuen Schlüssel und verspricht deshalb kein direktes Update einer beliebig früher signierten Installation. Die tatsächliche Signatur des neuen Baus muss aus dessen Bericht übernommen werden.

## Runner und Kostenrahmen

Die Repository-Metadaten wurden am 23. November 2026 über den verbundenen GitHub-Zugang gelesen: `Ullmann27/Imperathen` ist **öffentlich**. Die vorhandene Auswahl `ubuntu-24.04` gehört zu GitHubs Standardrunnern. Laut den aktuellen [GitHub-Abrechnungsregeln](https://docs.github.com/en/actions/concepts/billing-and-usage) und der [Runnerreferenz](https://docs.github.com/en/actions/reference/runners/github-hosted-runners) ist die Rechenzeit solcher Standardrunner in öffentlichen Repositorys kostenlos. Ein größerer oder kostenpflichtiger Spezialrunner wird nicht angelegt oder ausgewählt.

Die bestehende Artefaktaufbewahrung von 30 Tagen wird nicht erweitert. Aus der kostenlosen Standardrunner-Rechenzeit wird keine pauschale Aussage über sämtliche kontobezogenen Speichergebühren oder Kontingente abgeleitet; persönliche Abrechnungsdaten wurden nicht eingesehen. Es wird kein neuer Dienst oder Tarif beauftragt.

## Lokal tatsächlich festgestellter Bestand

Die lokale Vorprüfung erfolgte auf dem Opening-Quellcommit `a950c3daccfd232c2a56a991962eff4497003e16`. Sie hat **keine neue APK erzeugt**. Der ausgeführte `--check`-Aufruf endete beim fehlenden `platforms/android-35/android.jar` mit Exitcode 1.

| Bestandteil | Beobachtung |
| --- | --- |
| Godot | 4.7.2 vorhanden |
| Android-Exportvorlage | Kein passendes `android_debug.apk` mit `version.txt` in den untersuchten lokalen Verzeichnissen oder Archiven gefunden |
| SDK | Platform 36, Build-Tools 35.0.0 und ADB vorhanden; Platform 35 und Build-Tools 35.0.1 fehlen |
| Java | Systemlaufzeit 21 und separate JDK-21-Installation vorhanden; keine JDK-17-Installation gefunden |
| Emulator | Keine ausführbare Emulatorinstallation, kein Systemimage, kein laufender Emulatorprozess und kein `/dev/kvm` festgestellt |

Die untersuchten lokalen Wurzeln waren `/workspace`, `/tmp`, `/opt`, die vorhandenen Benutzer-Daten-/Cacheverzeichnisse und `/usr/lib/jvm`. Diese Beobachtung beschreibt den erfassten Rechnerbestand und ersetzt keine universelle Aussage über andere Maschinen.

Es wurden keine fremden Projektarbeitskopien, laufenden Apps, Spielstände oder Geräte verändert. Es gab keine neuen Downloads, keine lokal erzeugten Signierschlüssel und keine Installation auf einem vorhandenen ADB-Ziel. Nicht passende Werkzeuge wurden nicht mit umbenannten Verzeichnissen oder Versionsdateien als passende Voraussetzungen ausgegeben. Die exakten lokalen Werkzeugausgaben, Quellfingerprints und die fehlgeschlagene Vorprüfung liegen im vorläufigen Prüfverzeichnis `/tmp/imperathen-opening-android-qa/`; dieser Pfad ist temporär und kein veröffentlichter APK-Nachweis.

## Vorab festgelegte Abschlusskriterien

Ein bestätigtes Ergebnis benötigt die tatsächliche CI-Laufnummer und Quell-SHA, eine heruntergeladene APK mit passender SHA-256, einen positiven statischen APK-Prüfbericht und den separat ausgewiesenen Emulatorstatus. Ein vorhandenes Actions-Artefakt allein reicht nicht: Der Workflow lädt auch bei einem Fehler bereits entstandene Protokolle hoch.

Ein erfolgreicher x86_64-Emulatorlauf bleibt ein Nachweis für diese Prüffassung. Eine gegebenenfalls beobachtete ARM64-Ausführung über Emulatorübersetzung ist gesondert auszuweisen. Weder ein Software-Renderer noch die APK-Signatur belegt die Leistung oder Bedienung auf einem physischen ARM64-Telefon. Der tatsächlich erreichte CI- und Downloadstand ist im folgenden Abschnitt ergänzt.

## Bestätigter Abschluss

[Run 45115192890](https://github.com/Ullmann27/Imperathen/actions/runs/45115192890) endete am 23. November 2026 mit `completed / success`. Quellcommit ist `b356a0c8e3a01285d5c55fc426299fe94d8b30d9`. Der [Abschlussbericht](evidence/android-ci/run-45115192890-summary.json) unterscheidet die einzelnen Bau-, Export- und Laufzeitstufen.

Der echte Android-15/API-35-Bedienlauf bestand mit x86_64 sämtliche 41 Prüfungen und meldete keine Laufzeitfehler. Dazu gehören das neue Intro, Android-Zurück, Pause/Wiederaufnahme, Überspringen zur Zielkarte, deren echte Touch-Bestätigung, Speichern/Prozessneustart/Fortsetzen und die vorhandenen weiteren Spielansichten. Die ARM64-Download-APK wurde zusätzlich unter Emulatorübersetzung installiert und bis zur gerenderten Startoberfläche ausgeführt. Es fand kein physischer Telefontest statt.

Root hat die hochgeladenen APK- und Desktoparchive tatsächlich heruntergeladen und gegen ihre veröffentlichten Artefakt-SHA-256 geprüft. Die ARM64-Datei besitzt 107.859.841 Byte und SHA-256 `201d83f95c1d02613c52661073b92ce1aadfd81d67aa505150eaa468f0b6b1a7`. Ihr Inhalt enthält alle fünf Opening-Module und genau den korrigierten Wolkenshader. Der Windows-Export besitzt 112.285.576 Byte und SHA-256 `f448c1229ae87c31e6bf07a09e091c08bda347136136bf0987d791dd205cd7e7`; ZIP, x86_64-PE und eingebetteter Godot-Datenteil wurden geprüft. Es gibt keinen Windows-Laufzeittest.

Die lokalen fehlenden SDK-Voraussetzungen im vorherigen Abschnitt bleiben als tatsächlicher Vorbefund dokumentiert; der anschließende erfolgreiche Bau fand auf dem vorhandenen CI-Runner statt. Die ursprünglichen Vorbereitungs- und Abschlusskriterien sind damit anhand eines wirklichen Baus erfüllt, ohne einen lokalen Export vorzutäuschen.
