# C3 – Android-Signatur und Liefernachweise

## Befund und Änderung am 24. November 2026

Die Android-Pipeline prüfte eine gültige APK-Signatur, zeichnete aber bisher
keine Identität des tatsächlichen Signierzertifikats im Buildnachweis auf.
Damit ließ sich auch nicht prüfen, ob ARM64-Lieferpaket und Emulatorpaket
mit demselben Zertifikat signiert waren. Der Workflow erzeugt nach wie vor
pro Lauf einen neuen Debug-Keystore. Diesen Schlüsselwechsel behebt der
vorliegende begrenzte Nachweis-Patch nicht.

`tools/android_signing_identity.py` ruft ausschließlich das vorhandene
`apksigner verify --verbose --print-certs` auf. Es liest keine privaten
Schlüssel, erzeugt keinen Keystore und signiert keine Datei. Nur nach
erfolgreicher Signaturprüfung werden die öffentlichen SHA-256-Fingerprints
aller nummerierten Signierzertifikate erfasst und an den APK-Hash gebunden.
Fehlende, doppelte, fehlerhafte oder unvollständige Angaben, ein fehlender
Verifikationsmarker, fehlende bestätigte Signaturschemata und während der
Prüfung veränderte APK-Bytes führen zum Fehler.

Der Android-Baustein speichert diese `signing_identity` im Buildnachweis.
Eine bekannte öffentliche Referenz kann über `--expected-signer-sha256`
oder `IMPERATHEN_EXPECTED_SIGNER_SHA256` übergeben werden. Beide Angaben
müssen übereinstimmen, falls sie gleichzeitig gesetzt sind. Ein einzelner
Pin verlangt genau dieses eine Signierzertifikat; zusätzliche Signierer
werden nicht stillschweigend akzeptiert. Der Vergleich geschieht vor der
atomaren Übernahme der APK. Ein Fehler lässt das vorherige Paket und seinen
zugehörigen alten Nachweis unverändert und erzeugt keinen neuen PASS.
Ein vorhandener alter Nachweis bleibt an seinen alten Quellcommit und
Paket-Hash gebunden und darf nicht als Ergebnis des fehlgeschlagenen
Versuchs verwendet werden.

Ohne Referenz lautet der Vergleich ausdrücklich `not_checked`. Mit passender
Referenz lautet er `matched_expected_certificate`. Dieser Status bestätigt
nur den Zertifikatsvergleich. Er belegt keine Installation als Update auf
Heinz' Fold7; Paketkennung, Versionsregeln, vorhandene Installation und
gegebenenfalls Signaturhistorie bleiben gesonderte Bedingungen.

Der Publisher verlangt vor dem Anlegen des öffentlichen Ausgabeverzeichnisses
vollständige, paketgebundene Signaturnachweise für beide ABIs. Ihre gesamten
Zertifikatsmengen und Referenzverträge müssen übereinstimmen. Der öffentliche
Buildnachweis übernimmt die gemessenen Fingerprints und den Vergleichsstatus.
Ältere Artefakte ohne diesen Nachweis werden bei einem neuen Publikationsversuch
als unvollständig abgelehnt; bestehende Releases werden nicht verändert.

## Technische Quellen und Grenzen

- [Android Developers: apksigner](https://developer.android.com/tools/apksigner)
  dokumentiert `verify`, `--verbose` und `--print-certs`.
- [AOSP: ApkSignerTool.java](https://android.googlesource.com/platform/tools/apksig/+/master/src/apksigner/java/com/android/apksigner/ApkSignerTool.java)
  definiert Verifikationsmarker, Signiereranzahl und Ausgabe der
  Zertifikats-Fingerprints. Public-Key- und Source-Stamp-Fingerprints sind
  andere Werte und werden nicht als APK-Signierzertifikat verwendet.
- [Android Developers: Sign your app](https://developer.android.com/studio/publish/app-signing)
  beschreibt die Bedeutung der Signaturidentität für Updates.

SDK-abhängige Signaturrotation mit `Signer (minSdkVersion=...)` wird hier
absichtlich nicht als einfacher Zertifikatsvergleich behandelt. Dafür wäre
eine ausdrückliche Prüfung der Signaturhistorie nötig. Das Prüfwerkzeug
lehnt diese Ausgabe derzeit mit einer verständlichen Fehlermeldung ab.

## Nicht abgeschlossene Lieferbedingungen

Ein wiederverwendbarer passender privater Signierschlüssel und ein aus der
installierten Referenz abgeleiteter Zertifikatspin wurden in diesem Auftrag
nicht beschafft oder konfiguriert. Deshalb ist noch keine Updatekompatibilität
zur vorhandenen Installation zugesagt.

Der strenge Motion-Quality-Gate-Zweig
[#48](https://github.com/Ullmann27/Imperathen/pull/48) ist nicht Bestandteil
der Team-C-Basis `7a21dca5dad83bf637cfbe9c02f4d9ab5cd97337`. Er umfasst auch
Bewegungs-, Modell- und Weltänderungen und muss mit Team A integriert werden.
Die dort noch offenen Bewegungsbefunde werden nicht durch diesen Patch
behoben. Ein grüner Python- oder Engine-Test bedeutet keine visuelle
Bewegungsabnahme und keinen Fold7-Leistungsnachweis.

Die jüngste bei der Prüfung vorhandene veröffentlichte APK war
[0.7.0, Quellstand 7c3194db](https://github.com/Ullmann27/Imperathen/releases/tag/cc0-motion-2026-11-24-7c3194db)
mit 184.262.016 Bytes; deren Release verweist auf
[Android-Lauf 45372220049](https://github.com/Ullmann27/Imperathen/actions/runs/45372220049).
Die dortige Emulatorprüfung gilt für diesen Quellstand. Sie belegt weder
die späteren AP1/AP2-Änderungen noch diesen Team-C-Patch.

## Fokussierter Regressionstest

`python3 -m unittest discover -s tests -p 'android_signing_identity_test.py'`
prüft Erfolg, fehlende Referenz, bekannte Abweichung, mehrere Signierer,
unvollständige Verifier-Ausgaben, Rotation, Zeitüberschreitung, Paketmutation,
Erhalt der vorherigen APK bei Abweichung und die ARM64-/Emulator-Kopplung.
Die Verifier-Ausgaben sind ausdrücklich kontrollierte Testdaten. Der Test
erzeugt keinen echten Android-Bau und ersetzt keine Geräteprüfung.

Ausgeführt auf dem Team-C-Arbeitsstand: **22/22 neue Signaturtests** und
**6/6 unveränderte Tests des vorhandenen Publikationswegs** erfolgreich.
`git diff --check` war ohne Befund; die CLI-Hilfe enthält den neuen optionalen
Zertifikatspin. Ein echtes APK wurde in diesem Teilauftrag weder gebaut noch
signiert oder veröffentlicht.

Der Signaturhelfer verwendet chunkweises SHA-256-Hashing und bleibt dadurch
mit dem vom Buildwerkzeug zugesagten Python 3.10 kompatibel. Ein zusätzlicher
Test entfernt `hashlib.file_digest` aus dem Testprozess und prüft den
vollständigen Signaturidentitätspfad weiterhin erfolgreich.
