# Android CI31: Prüfung der Originalbilder

Geprüft am 23. November 2026. Quelle ist [Android-Lauf 31](https://github.com/Ullmann27/Imperathen/actions/runs/45210298631), Commit `a87e3918872ad2aa76aa2359f810658b4821ca0b`, Job `137816986101`. Alle 17 hier abgelegten PNGs wurden unmittelbar angesehen und unverändert aus dem Runtime-Artefakt übernommen. Die Kopien wurden mit den entpackten Originalbytes verglichen.

Der [Originalbericht](runtime-report.json) meldet `status: passed`, **73 von 73 erfolgreiche Runtimeprüfungen** und `errors: []`. Diese Zahl bezeichnet tatsächlich ausgeführte Android-Prüfungen; die Python-Harnessprüfungen sind ein eigener Nachweis. Die vollständige Familien-/Touchstrecke lief auf Android 15/API 35 im **x86_64-Emulator**. Die zusätzliche ARM64-APK wurde installiert und unter Übersetzung bis zum Intro gestartet (`started_under_translation`). Ein physisches Android-Gerät wurde nicht geprüft.

## Sichtbare Befunde

| Originalbilder | Befund und Aussagegrenze |
| --- | --- |
| [10 – Familienintro](10_android_opening.png), [11 – erster Auftrag](11_android_opening_objective.png) | Familienhaus, junge Spielfigur und neuer Einstieg sind sichtbar. Text und Weiter-/Startknopf bleiben lesbar. Der Auftrag führt ausdrücklich zur Mutter und erklärt Gehen/Laufen. |
| [15 – Familienhaus](15_android_family_home.png), [17 – gefüllter Krug](17_android_family_jug.png), [02 – laufendes Spiel](02_android_world.png) | Das große Pad links, die sechs beschrifteten Aktionen rechts und die untere Navigation überdecken einander in diesen Aufnahmen nicht. Auftrag und Nordkarte sind sichtbar. Nach dem Wasserauftrag nennt die Zielanzeige Vater Sextus. Bild 02 zeigt außerdem die gewählte rechte Gerade. Materialien, Beleuchtung und Figurendarstellung bleiben sichtbar prototypisch. |
| [16 – Muttergespräch](16_android_mother_conversation.png) | Dialogtitel, Text, bestätigte Übergabe des Haushaltsdenars und Gesprächsende sind lesbar. **Eine nahe Wand verdeckt die Weltansicht fast vollständig; die Mutter ist im Gesprächsbild nicht sichtbar.** Die erfolgreich geprüfte Interaktion beseitigt diese offene Schwäche der Kameraführung nicht. |
| [14 – Techniken](14_android_techniques.png) | Zwei Geraden sind auswählbar, weitere sichtbare Techniken sind mit Übungsschwellen versehen. Das kompakte Overlay besitzt einen sichtbaren Scrollbalken; weitere Einträge liegen außerhalb des Ausschnitts. Der Zurückknopf bleibt frei. Das Bild allein zeigt nicht den gesamten Zehnerkatalog. |
| [18 – Grafikeinstellungen](18_android_light_settings.png) | **Das Bild zeigt noch das offene Qualitäts-Popup und den bisherigen Text „Ausgewogen · Limit 60 FPS“.** „Leicht“ ist in der Liste hervorgehoben. Dieses PNG belegt keinen abgeschlossenen Low-Wechsel. Die gesonderten frischen Laufzeitbeobachtungen `native_settings_select_light_graphics` und `native_settings_resume_preserves_light_graphics` bestätigen dagegen jeweils `ui_profile = low` und `world_profile = low`. Das Originalbild bleibt unverändert; die Ursache des zeitlichen Bild-/Zustandsversatzes wurde hier nicht weiter untersucht. |
| [03 – Pause](03_android_pause.png) | Die Bedienknöpfe einschließlich Speichern und Einstellungen sind sichtbar. Das Bild zeigt einen gescrollten Ausschnitt; Überschrift/Einleitung sind oben teilweise abgeschnitten. Es ist keine Aufnahme des gesamten Menüs auf einmal. |
| [01 – Hauptmenü](01_android_menu.png) | Herkunftswahl und „Neues Leben“ sind sichtbar. Das Menü enthält noch ältere Formulierungen zur Ankunft mit Marcus/Arbeit am Brunnen und zum ersten Holz. Diese Texte passen noch nicht vollständig zum tatsächlich geprüften neuen Familienbeginn. |
| [00 – Intro](00_android_intro.png), [07 – ARM64-Intro](07_android_arm64_translated_intro.png) | Beide Bilder erfassen eine dunkle Phase der Introeinblendung. Der Überspringenknopf ist sichtbar. Bild 07 enthält zusätzlich das aktivierte Diagnoseoverlay und belegt ausschließlich den Introstart der ARM64-Fassung unter Übersetzung, keine vollständige ARM64-Spielroute. |
| [04 – Tal](04_android_valley.png), [09 – Marsch](09_android_marching.png), [05 – annähernd quadratisches Talbild](05_android_valley_square.png) | Tatsächliche Formationen, Talziel und Befehlsleiste sind gerendert. Das für die Prüfung aktivierte Diagnoseoverlay verdeckt einen Teil der oberen Weltansicht. Diese Aufnahmen sind Laufzeit-/Darstellungsbelege für den Softwareemulator; sie sind kein Nachweis flüssiger Darstellung auf einem Telefon. |
| [06 – Weltkugel](06_android_globe.png), [08 – Figuren](08_android_figuren.png) | Weltkugel, Regionsauswahl und Figurenmenü werden tatsächlich dargestellt. Bild 08 zeigt das geladene Galerieporträt eines Legionärs; bewegte Spielfiguren werden in den Spielaufnahmen bewertet. Das Diagnoseoverlay liegt auch hier über einem Teil der Darstellung. |

Die Familien-, Dialog-, Technik- und Einstellungsbilder haben **960 × 540 Pixel**. Die Dateien 05, 06, 07 und 08 haben **920 × 900 Pixel**. Daraus folgt keine Prüfung der neuen Familienoberfläche auf jeder Fold-/Portraitgröße.

## Bewegungs- und Speicherbelege aus dem Bericht

Alle vier Familienwegpunkte wurden jeweils im ersten protokollierten Versuch mit echten nativen `DOWN`-/`MOVE`-/`UP`-Eingaben erreicht. Muttergespräch und Wasserauftrag erzeugten die tatsächlichen Gegenstände `household_coin` und `water_jug`; anschließend war `father_morning` aktiv. Der Androidumfang endet bei diesen ersten zwei Familienaktionen.

Die zusätzliche Padprüfung misst **0,8506 m horizontale Positionsänderung**. Geh-/Laufumschaltung, Öffnen der Techniken und Wahl der rechten Geraden bestanden. Pause beendete den gehaltenen Bewegungsfinger. Nach Fortsetzen und nach Prozessneustart zeigten die jeweiligen Driftprüfungen **0,0 m**; die ersten beiden Aktionen und beide Gegenstände blieben nach dem Neustart erhalten. Diese Aussagen stammen aus den frischen Diagnosewerten und tatsächlichen Eingaben im [Originalbericht](runtime-report.json), nicht allein aus Einzelbildern.

## Herkunft der Belege

Artefakt: `imperathen-android-runtime-31`, ID `14837331432`, ZIP-Größe `7.402.555` Bytes. Der ZIP-SHA256 wurde gegen die [unveränderten GitHub-Metadaten](github-run-artifacts.json) geprüft:

`359c2a2e8c3829bebae492ae09075993c3b05fe278653cbfc1056379becd0025`

Der [Downloadnachweis](download-proof.json) enthält den erfolgreichen Digestvergleich. ZIP und ausführliche Logcat-Dateien bleiben im entpackten Arbeitsnachweis; hier liegen der Originalbericht, die Originalbilder und Metadaten ohne Bildbearbeitung. Aus dieser Sichtprüfung entstand keine weitere Produktionscodeänderung und kein zusätzlicher Build.
