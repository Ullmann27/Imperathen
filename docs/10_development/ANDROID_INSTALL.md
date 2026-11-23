# IMPERATHEN – Dorfleben auf Android installieren und anfangen

**Anleitung zur Prüffassung `0.3.0-village` · Stand: 23.11.2026.** Du spielst einen zwölfjährigen Bewohner einer römischen Grenzsiedlung. Decimus verwaltet das Dorf; Wiederaufbau, persönliche Beziehungen, Berufe und Verteidigung entwickeln sich während deiner Partie.

[Downloads und Prüffassungen](https://github.com/Ullmann27/Imperathen/releases) · [Dorfleben-Lieferbericht mit Prüfstatus und Nachweisen](../17_village_life/DELIVERY.md) · [Ausführliche Spielanleitung](../../prototype/README.md)

## Geprüfter Download

**[IMPERATHEN-e1b1c1fb-arm64.apk herunterladen](https://github.com/Ullmann27/Imperathen/releases/download/village-2026-11-23-e1b1c1fb/IMPERATHEN-e1b1c1fb-arm64.apk)** ·
150,4 MB · ARM64 · `0.3.0-village` (3).

[Veröffentlichung mit allen Prüfdateien](https://github.com/Ullmann27/Imperathen/releases/tag/village-2026-11-23-e1b1c1fb) ·
[Erfolgreicher Android-Lauf 25](https://github.com/Ullmann27/Imperathen/actions/runs/45178232563).
Die vollständige Dorfbedienung bestand 50 Prüfungen im x86_64-Emulator;
die ARM64-Datei wurde zusätzlich unter Übersetzung installiert und gestartet.
Ein physisches Telefon ist noch nicht geprüft.

APK-Quellstand: `e1b1c1fb16d63056e4eb80891d84ed75c79b4ed6`  
SHA-256: `9b9d6655cca0ee4d04b67cd318dbb74c11cec9523cf9d4e94306975c690d2015`

## Die passende Datei installieren

1. Lade die oben verlinkte **`IMPERATHEN-e1b1c1fb-arm64.apk`** auf dein Android-Telefon. Dateiname, Quellstand und SHA-256 müssen zu derselben Lieferung gehören. Bei einem ZIP-Download entpackst du zuerst die ARM64-APK; die zusätzliche Datei mit `emulator` im Namen gehört zum x86_64-Prüfrechner.
2. Öffne die APK im Downloadbereich oder Dateimanager. Falls Android es verlangt, erlaube die Installation für diesen Browser oder Dateimanager unter **Unbekannte Apps installieren** beziehungsweise **Aus dieser Quelle zulassen**. Die genaue Bezeichnung hängt vom Gerät ab. [Android-Anleitung zur Installation aus anderen Quellen](https://developer.android.com/studio/publish#unknown-sources).
3. Prüfe den App-Namen **IMPERATHEN**, wähle **Installieren** und anschließend **Öffnen**. Das App-Paket heißt `at.heinz.imperathen`. Bei einer bereits installierten Prüffassung beachte zuerst den Abschnitt **Spielstand und Updates** weiter unten.
4. Halte das Gerät im **Querformat**. Für das Spielen brauchst du weder einen PC noch Godot, Blender, ein Benutzerkonto oder einen KI-API-Schlüssel. Das Spiel läuft lokal; das [Android-Exportpreset](../../prototype/export_presets.cfg) fordert keine Internetberechtigung an.

## Den neuen Dorfanfang starten

Wähle im Hauptmenü **Rom · Italien** und **Neues Leben**. Nach dem filmischen Einstieg bestätigt **Ins Dorf** die Zielkarte und übergibt dir die Steuerung. Auch nach **Überspringen** bleibt diese Bestätigung erforderlich. **Fortsetzen** lädt deine aktive gespeicherte Partie.

**Der erweiterte Dorfweg ist derzeit für eine neue römische Partie aktiviert.** Andere Herkünfte und ältere übernommene Spielstände erhalten Decimus, Arbeitszuweisungen und die neuen Dorfregeln nicht automatisch. Eine neue Partie ersetzt nach Bestätigung den bisherigen aktiven Spielstand.

### Deine ersten Schritte

1. **Decimus kennenlernen:** Gehe zum Verwalter, tippe **Interagieren** und wähle **Beim Wiederaufbau mithelfen**. Dadurch erhältst du die Erlaubnis, Helfer und Reparaturen zu koordinieren.
2. **Holz, Marcus und eine Hütte:** Sammle Holz an den beschrifteten Vorräten. Zwölf Holz reichen für Marcus’ Bitte um vier Holz und die erste Hütte für acht Holz; seine Bitte abzulehnen ist ebenfalls eine gültige Entscheidung. Wähle **Hütte bauen** beziehungsweise **Hütte**, bestätige eine erlaubte Baufläche und bleibe in der persönlichen Ansicht nahe der Baustelle, bis die Arbeit abgeschlossen ist.
3. **Arbeit organisieren:** Öffne **Dorfleben → Arbeit & Versorgung** und scrolle zu **Einwohner zuweisen**. Tippe das Auswahlfeld neben einem Namen und dann den gewünschten Arbeitsplatz an. Du kannst beispielsweise Fabius und Drusa dem **Holzfällerlager** zuweisen. Starte dessen **Wiederaufbauen**-Auftrag, sobald das dort angezeigte Material vorhanden ist. Die Dorffelder sind anfangs bereits mit Vibius und Julia besetzt.
4. **Zeit weiterlaufen lassen:** Verlasse die Übersicht mit **Zurück ins Dorf**. Gespräche, Dorfübersichten und Pausen halten die Simulation an; Arbeit schreitet währenddessen nicht fort. Im Holzfällerlager werden zwei arbeitsfähige Helfer benötigt. Die Übersicht erklärt, warum ein Betrieb ruht.
5. **Menschen und Berufe entdecken:** **Menschen & Berufe** zeigt Beziehungen und aktuelle Aufenthaltsorte. Suche die Personen im Dorf auf. Hilfe bei ihrer Bitte oder mindestens acht Vertrauen öffnet die jeweilige **Beruf lernen**-Auswahl. Arbeitszuweisungen können ihre Aufenthaltsorte verändern.

Nach fertiger Hütte, drei Dorfbekanntschaften und 120 Sekunden aktiver Dorfzeit kann die erste Überfallwarnung beginnen. Achte auf Aufklärung, Alarm und Verteidigung; eingesetzte Verteidiger fehlen an ihren Arbeitsplätzen. Der ausdrücklich angekündigte Altersübergang zur erwachsenen Ausbildung erfordert zusätzlich Marcus’ entschiedene Begegnung, einen beendeten Überfall und insgesamt 240 Sekunden aktive Dorfzeit. Dafür dürfen weder offene Hüttenbaustellen noch eine laufende Warnung oder ein Angriff bestehen. Den vollständigen Ablauf erklärt die [Spielanleitung](../../prototype/README.md#spielweg-im-neuen-römischen-dorf).

## Touch-Steuerung und Darstellung

| Aktion | Bedienung |
| --- | --- |
| Figur bewegen | Linken Analogbereich ziehen; Loslassen stoppt. |
| Kamera drehen / Abstand ändern | Im freien Weltbereich ziehen / zwei Finger spreizen oder zusammenführen. |
| Sprechen, sammeln oder helfen | Nahe an das Ziel gehen und **Interagieren** antippen. |
| Kämpfen | **Angreifen**, beim Dorfüberfall auch **Blocken** und **Ausweichen**. |
| Lange Dorfübersicht lesen | Über Texte oder Karten wischen; Auswahlfelder durch kurzes Antippen öffnen. |
| Pausieren und speichern | **Pause → Spiel speichern**; **Weiterspielen** setzt fort. |
| Gespräch oder Dorfübersicht verlassen | Android-Zurück; im laufenden Spiel öffnet es die Pause. |

In **Einstellungen** findest du UI-Größe, reduzierte Bewegung, Lautstärke und Touchanzeige. Die Grafikprofile heißen **Leicht**, **Ausgewogen**, **Hoch** und **Sehr hoch**. Ihre Bildratenlimits sind Einstellungen, keine auf deinem Telefon gemessenen Leistungszusagen.

**Talgefecht erproben**, **Weltkugel erkunden** und **Figuren** sind zusätzliche Hauptmenüangebote. Die ersten beiden öffnen gesonderte freie Szenarien; für den oben beschriebenen Lebenslauf verwendest du **Neues Leben**.

## Spielstand und Updates

Der Spielstand liegt im internen App-Speicher. **Fortsetzen** lädt ihn; **Spiel speichern**, wichtige Entscheidungen, regelmäßige automatische Sicherungen und Hintergrundwechsel sichern die Partie. Eine zusätzliche Sicherungsdatei schützt den letzten gültigen Stand. Sie ist kein Archiv mehrerer Lebensläufe. Ein komfortabler Spielstandexport und Cloud-Synchronisierung sind noch nicht vorhanden.

**Deinstallieren oder App-Daten löschen entfernt den lokalen Spielstand. Deinstalliere deshalb nicht vorschnell, wenn ein Update abgelehnt wird.** Android entfernt appinterne Dateien bei einer Deinstallation; siehe [Android-App-Speicher](https://developer.android.com/training/data-storage/app-specific).

Für ein direktes Update muss die Signatur zur installierten Fassung passen. **Der aktuelle Android-Prüfworkflow erzeugt noch bei jedem Lauf einen neuen Signierschlüssel.** Deshalb ist ein direktes Update zwischen beliebigen Prüfbauten nicht zugesagt. Bewahre bei einem Installationsfehler den genauen Meldungstext und die APK-Dateinamen auf; der passende signierte Updateweg muss vor einem datenlöschenden Schritt geklärt werden. Zum Spielen benötigst du keine Signierschlüssel. [Projekt-Bauweg](ANDROID_BUILD.md) · [Android-Signaturregeln für Updates](https://developer.android.com/studio/publish/app-signing#considerations).

## Prüfstand und Grenzen

Der [Lieferbericht](../17_village_life/DELIVERY.md) ordnet APK, Quellcommit und tatsächliche Prüfungen ein. **Ein physisches ARM64-Telefon ist noch nicht geprüft.** Paketprüfung und Android-Emulatorlauf belegen keine Bildrate, Wärmeentwicklung, Akkulaufzeit oder fehlerfreie Bedienung auf deinem konkreten Gerät.

Die Bilder, Prüfsummen und Berichte unter [`evidence/android/`](evidence/android/) dokumentieren die frühere **0.1.0-Lieferung**. Sie bleiben historische Nachweise und gelten nicht als Prüfung der aktuellen Dorfleben-APK.

Die Fassung ist ein begrenzter Prototyp. Der große Geländerahmen ist noch keine vollständig bewohnte offene Welt, die Herrscherlaufbahn bleibt ein Ausbauziel. Nach dem Altersübergang sind Dorfchronik und Saisonanzeige der Weltkugel noch nicht synchron. Weitere Grenzen und die zugrunde liegenden Spielregeln stehen in der [aktuellen Projektanleitung](../../prototype/README.md).
