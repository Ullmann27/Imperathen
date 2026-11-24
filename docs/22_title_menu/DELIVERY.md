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
