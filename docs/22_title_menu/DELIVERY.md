# Vorspann, römisches Hauptmenü und Menümusik – Übergabe 24.11.2026

Branch `ui/roman-menu-intro-20261124`, Basis Build 7 (`7c3194db13acef2702e5e92336b94e9be41c7b58`). Anlass: Heinz' Wunsch nach stilvollen römischen Buttons, römischer Musik und einem Intro mit Schwert, Blutspur, „IMPERATHEN“, „VENI VIDI VICI“ und aufsteigendem Legionsadler.

## Umgesetzt

- **Vorspann** (`prototype/scripts/ui/imperial_intro.gd`, `prototype/shaders/intro_backdrop.gdshader`): Echtzeit-Sequenz in Godot, zeitgesteuert statt Tweens. Der Adler steigt hinter dem Titel auf, ein Gladius fährt quer durchs Bild, die Blutspur legt den Schriftzug frei, danach Tropfen, kurzer Aufprall-Ruck, Glut-Partikel und „VENI · VIDI · VICI“. Ein kurzer, synthetisch erzeugter Schwertklang wird zur Laufzeit erzeugt.
  - Vollständig (8,8 s) nur beim ersten Start oder mit der Einstellung „Vorspann bei jedem Start vollständig zeigen“; sonst eine Titelkarte von 3 s. In den Einstellungen gibt es außerdem „Vorspann jetzt ansehen“.
  - Überspringen per Tippen/Klick irgendwo, Enter/Leertaste/Esc, Android-Zurück oder die Schaltfläche. „Bewegungseffekte reduzieren“ zeigt eine ruhige Titelkarte ohne Schwertfahrt.
  - Bei Drehung des Geräts wird neu angeordnet, ohne neu zu starten. Während des deckenden Vorspanns wird das 3D-Dorf nicht gezeichnet (`main.gd`).
- **Hauptmenü** (`game_ui.gd` → `show_menu`, Bausteine in `roman_style.gd`): gerahmte Tafel mit Adler zwischen Lorbeerzweigen, Titel in Cinzel, Mäanderband und Buttons als *tabula ansata* (römische Inschriftentafel mit Schwalbenschwanz-Griffen und Nagellöchern). Es gibt Zustände für normal, Hover, gedrückt, deaktiviert und Fokus. Alle Buttons und Aktionen sind unverändert erhalten.
  - Querformat: Titel oben, zwei Spalten, bei 1280 × 720 ohne Scrollen. Vorher war der Titel durch die Fokus-Scrollposition abgeschnitten.
  - Hochformat (Telefon): eine große Spalte, die auf die Bildschirmbreite skaliert wird (vorher eine sehr kleine Spalte oben links). Der Verlauf hinter dem Menü wird jetzt ohne Streifen gezeichnet.
- **Musik** (`prototype/assets/ui/menu_theme.ogg`, Generator `tools/ui/build_menu_music.py`): eigene, synthetische Komposition in d-Moll mit 66 BPM, 58 s nahtlos geloopt. Sie klingt nach Wasserorgel-Bordun, Lyra, Aulos-Melodie, Cornu-Signal und Rahmentrommel; eine Rekonstruktion antiker Musik ist sie nicht. Sie läuft im Vorspann, im Menü und in Menü-Einstellungen/-Galerie und blendet beim Spielstart aus. In den Einstellungen gibt es einen eigenen Regler „Musik im Hauptmenü“ (0 % = stumm), zusätzlich zur Gesamtlautstärke.

## Herkunft und Lizenzen

Eingetragen in `prototype/assets/asset_manifest.json`:

| Datei | Herkunft | Lizenz |
|---|---|---|
| `assets/ui/fonts/Cinzel-Variable.ttf` | Google Fonts `ofl/cinzel` (Upstream NDISCOVER/Cinzel, Commit 8271e162), Natanael Gama | SIL Open Font License 1.1; Lizenztext `Cinzel-OFL.txt` liegt bei und wird mit exportiert, Lizenzangabe ist auch in den Font-Metadaten |
| `assets/ui/menu_theme.ogg` | eigene numpy-Synthese, Seed 20261124, Vorbis q4 | eigenes Werk, keine Rechte Dritter |
| `assets/ui/aquila.svg`, `assets/ui/gladius.svg` | prozedural aus `tools/ui/build_imperial_emblems.py` | eigenes Werk; provisorische, stilisierte Embleme, keine historische Rekonstruktion |

## Prüfungen

- `python3 -m unittest discover -s tests -p 'android_*_test.py'`: 143/143 OK
- `tools/check_prototype.py --godot <4.7.2> --keep-going`: 58/58 PASS (57 bestehende und die neue Prüfung `roman_menu`)
- `prototype/tests/roman_menu_test.gd` (119 Prüfungen): Erststart vollständig, danach kurz; Tippen, Klick, Tasten und Android-Zurück überspringen genau einmal; natürliches Ende; Zeitachse (Titel erst nach der Klinge, Blutspur folgt, Adler steigt); Hochformat-Neuanordnung; jeder Menübutton löst seine Aktion aus; Layout ohne Scrollen bei 1280×720, 1560×720, 720×1280 und 1080×2340; Touch-Höhe; Musik-Loop; Einstellungen bleiben gespeichert.
- Laufzeit-Screenshots und Video: `prototype/tests/menu_review.gd` (xvfb, llvmpipe), Video mit Godot `--write-movie` und 30 fixen Bildern pro Sekunde.

## Grenzen

- Die Musik wurde nur technisch geprüft (Pegel −15,8 LUFS, kein Clipping, nahtloser Loop, Spektrum), nicht durch Anhören. Für ein orchestrales Thema in Produktionsqualität wäre ein Komponist oder ein Musik-Generator mit klaren Nutzungsrechten nötig.
- Adler und Schwert sind flache Vektor-Embleme, kein 3D-Modell. Ein animierter 3D-Adler mit Flügelschlag braucht ein geriggtes Modell (Blender-Handarbeit oder ein 3D-Generator mit Lizenznachweis).
- Leistung und Ton auf einem echten Android-Gerät sind nicht gemessen; die Bilder stammen aus einer Software-Renderung.

## Stufe 2: Trailer-Fassung (24.11.2026, nach Heinz' Rückmeldung „impulsiver, mächtiger, gewaltiger“)

Buttons und Menüaufbau sind unverändert geblieben (Heinz mag sie); geändert wurden Inszenierung, Bühne und Ton.

### Vorspann (`imperial_intro.gd`, Bausteine in `imperial_fx.gd`)

- **Schnittrhythmus wie im Trailer:** schwarzer Beginn. Drei Trommelschläge zünden nacheinander die Ebenen: Legion bei 0,45 s, Feldzeichen und Banner bei 1,45 s, Adler bei 2,45 s. Dann folgen eine Steigerung, der Gladius-Schnitt mit Einschlag bei 4,25 s und „VENI · VIDI · VICI“ Wort für Wort auf drei Schlägen (5,55 / 6,15 / 6,75 s). Zum Schluss kommen ein Glanzlicht über den Adler und ein Cornu-Ruf bei 7,6 s. Gesamtlänge 10,8 s.
- **Kamera:** langsamer Push-in (bis etwa 7 %), Parallaxe zwischen fernen und nahen Ebenen, kurzer Zoom-Stoß und Kamera-Shake beim Einschlag, leichte Stöße bei den Trommelschlägen. In Querformat gibt es Cinemascope-Balken (2,39:1); im Hochformat wird die volle Höhe genutzt.
- **Legion:** marschierende Kohorten als Silhouetten. Sie wurden in Blender (`tools/ui/render_legion_silhouettes.py`) aus den projekteigenen Feldkompanie-Rigs gerendert (`art/soldiers/heavy|spear|officer.blend`, Marsch-Action). Es entsteht ein Atlas mit 12 Bildern pro Rolle. Die ferne Reihe wird per Mip-Unschärfe weichgezeichnet (Tiefenunschärfe), die nahe Reihe erhält ein warmes Gegenlicht (Rim). Schrittlänge und Animationstakt passen zusammen, die Füße rutschen also nicht. Feldzeichen werden mitgetragen: rote Vexilla mit Goldkante und Signa mit Phalerae. Hinter dem Titel bleibt die nahe Reihe frei von Feldzeichen.
- **Licht und Atmosphäre:** volumetrisch wirkende Lichtstrahlen hinter der Aquila, Rauch und Nebel zwischen den Ebenen, Glut-Partikel und ein Aufblitzen bei jedem Schlag.
- **Metall:** Titel und Motto in poliertem Gold mit Horizontlinie, Glanzlicht-Sweep und kurzer Glut beim Einschlag (`shaders/imperial_metal.gdshader`); die Aquila erhält ebenfalls ein Glanzlicht.
- **Gladius:** Bewegungsunschärfe aus Geisterbildern und heißem Schlierenstreifen, Funkenflug entlang der Klinge, Funkenregen beim Einschlag, anamorphotischer Lichtstreifen über dem Titel.
- **Blutspur:** Schichten von dunklem Rand bis hellem Kern, die nachdunkeln. Dazu kommen ein wandernder Nassglanz, Tropfen mit schwerem Kopf und Glanzpunkt sowie Spritzer, die von der Klinge geschleudert werden. Das ist ein gezeichneter 2D-Effekt, keine Fluidsimulation.
- **Banner:** zwei rot-goldene Banner mit gestickter Aquila, Faltenwurf im Wind und Schwalbenschwanz-Saum (`shaders/roman_banner.gdshader`).
- **Ton:** eigener Trailer-Sound `assets/ui/intro_trailer.ogg` (Generator `tools/ui/build_intro_trailer.py`). Er enthält Taiko-artige Schläge mit Sub-Boom, Braams, eine Steigerung, den Schwertschwung (links nach rechts im Stereobild), den Einschlag mit Stahlklang, drei Motto-Schläge und einen Cornu-Ruf über einem Blechbläser-Akkord. Die Marken liegen auf denselben Zeitpunkten wie im Bild. Vor dem Einschlag fällt alles außer dem Schwung kurz weg. Die Menümusik startet erst nach dem vollständigen Vorspann; der Trailer folgt dem Regler „Musik im Hauptmenü“.
- **Kurzfassung (3 s) und reduzierte Bewegung:** Die Titelkarte spielt den Einschlag-Ausschnitt des Tons. Bei „Bewegungseffekte reduzieren“ gibt es keinen Push-in, keinen Shake, keine Partikel und kein Geisterbild; die Banner bewegen sich nur wenig.

### Hauptmenü

- **Bühne hinter der Tafel:** Abendton und tiefe Vignette über dem Dorf, Lichtstrahlen von oben rechts, Bodennebel und Glut (`shaders/menu_grade.gdshader`). Die Kamera fliegt langsam über das Dorf (`game_world.gd` → `set_menu_flight`, aus bei reduzierter Bewegung).
- **Banner und Fackeln** stehen dort, wo die Tafel Platz lässt: neben ihr auf breiten Bildschirmen (eins bei 1280 × 720, zwei bei 2340 × 1080), über und unter ihr auf Telefonen im Hochformat. Sie überdecken keinen Button; das ist geprüft.
- **Tafel:** dunkler Marmor mit Adern in einem abgeschrägten Bronzerahmen mit Eckrosetten, innerer Goldlinie und tiefem Schatten (`RomanStyle.TabletBox`).
- **Titel:** 70 statt 58 px, poliertes Gold mit einem Glanzlicht alle 7 s; die Aquila glänzt versetzt. Bei reduzierter Bewegung steht der Glanz still.

### Grafikprofil

Die Effektstärke hängt am bestehenden Grafikprofil (`Fx.effect_level`):

- **„Leicht“:** ohne ferne Kohorte und hinteren Nebel, weniger Rauch-Oktaven, 24 Glutpartikel, 40 Einschlagfunken, im Menü 10 Glutpartikel und keine Lichtstrahlen.
- **„Ausgewogen“:** 56 Glutpartikel und 90 Funken.
- **„Hoch“ und „Sehr hoch“:** 96 Glutpartikel, 150 Funken und stärkere Tiefenunschärfe.

Alle Silhouetten einer Reihe entstehen in einem Zeichenaufruf aus einem gemeinsamen Atlas.

### Herkunft und Lizenzen (Stufe 2)

| Datei | Herkunft | Lizenz |
|---|---|---|
| `assets/ui/intro_trailer.ogg` | eigene numpy-Synthese, Seed 20261124, Vorbis q5 | eigenes Werk, keine Rechte Dritter |
| `assets/ui/legion_march.png` | Blender-Rendering der projekteigenen Rigs aus `art/soldiers` | eigenes Werk, gleiche Bedingungen wie `art/soldiers` |
| Shader `drifting_fog`, `imperial_metal`, `legion_silhouette`, `menu_grade`, `roman_banner`, `torch_flame`, `intro_backdrop` | eigener Code | eigenes Werk |

### Prüfungen (Stufe 2)

`roman_menu` umfasst jetzt 261 Einzelprüfungen. Neu geprüft werden:

- Trommelschläge zünden die Ebenen; schwarzer Beginn.
- Bewegungsunschärfe der Klinge, Shake und Zoom-Stoß beim Einschlag, Aufblitzen.
- Motto Wort für Wort.
- Balken nur im Querformat.
- Der Trailer-Sound deckt den Vorspann ab, und die Menümusik wartet.
- Das Grafikprofil steuert die Dichte; reduzierte Bewegung schaltet Kamera, Shake und Partikel ab.
- Der Menütitel ist Metall und größer, die Tafel ist der Marmor-Bronze-Stil, und die Bühne ist vorhanden.
- Banner und Fackeln überdecken bei vier Auflösungen keinen Button.

### Grenzen (Stufe 2)

- Die Legion besteht aus 2D-Silhouetten aus Blender-Renderings der vorhandenen Low-Poly-Rigs, nicht aus 3D-Figuren in Echtzeit; die Rigs zeigen keine Gesichtsdetails. Für nahe, voll beleuchtete Legionäre wären höher aufgelöste Modelle nötig (Blender-Handarbeit oder Meshy mit Lizenznachweis).
- Die Blutspur ist ein gezeichneter Effekt mit Glanz, Tropfen und Spritzern, keine physikalische Fluidsimulation.
- Der Trailer-Sound wurde technisch geprüft (Lautheit, Spitzen, Spektrum, Synchronität mit dem Bild), aber nicht angehört. Ein orchestraler Trailer-Score in Kinoqualität braucht einen Komponisten oder ein Musikmodell mit klaren Nutzungsrechten.
- Die Bildrate auf einem echten Android-Gerät ist nicht gemessen; die Aufnahmen stammen aus Software-Rendering (llvmpipe).
