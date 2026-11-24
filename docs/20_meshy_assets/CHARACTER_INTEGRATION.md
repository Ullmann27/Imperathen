# Meshy-Figuren: Integration und Prüfstand

Stand: 24. November 2026.

## Eingebaute Figuren

Zwei vorhandene Figuren aus dem verbundenen Meshy-Konto stehen als animierte
Spielmodelle bereit: der römische Signifer und der germanische Axtkämpfer. Die
Originaldownloads enthielten weder ein Skelett noch Animationen. Die jetzt
enthaltenen Skelette und Bewegungen stammen aus der lokalen Projektpipeline.
Es wurde keine neue kostenpflichtige Meshy-Generierung angestoßen.

`village_life_world.gd` verwendet den Signifer für Severus und den Axtkämpfer
für jeden zweiten Angreifer. `VillagePerson.configure_meshy()` wählt nur
registrierte, vollständige Erwachsenenmodelle. Kinder, Spieler und Begleiter
behalten ihre bisherigen Figuren. Fehlt eine erforderliche Körper- oder
Ausrüstungsstufe, bleibt die bisherige Figur verfügbar.

Die Handgegenstände werden separat durch `meshy_equipment.gd` an die lebenden
Handknochen gebunden. Diese Darstellung vergibt keine Gegenstände im Inventar
und verändert weder Trefferreichweite noch Schaden oder Questfortschritt.
Ihre endgültige Positionierung wird unter `evidence/equipment/` geprüft.

| Figur | Höhe | Dreiecke in Stufe 0 / 1 / 2 / 3 | Knochen |
| --- | --- | --- | --- |
| `unit_roman_signifer` | 1,85 m | 28.000 / 10.000 / 3.500 / 1.199 | 15 |
| `unit_germanic_axe_fighter` | 1,78 m | 27.999 / 10.000 / 3.380 / 1.075 | 15 |

Jede der acht GLB-Dateien enthält dieselben elf Bewegungsnamen:
`idle`, `march`, `run`, `talk`, `work`, `gather`, `train`, `attack`, `block`,
`hit`, `death`. Texturkanten werden je Stufe auf höchstens 2048, 1024, 512 und
256 Pixel reduziert. Die acht Körperdateien belegen zusammen **12.634.008
Bytes**. Dateipfade, SHA-256-Werte und einzelne Größen stehen vollständig in
`character-build.json`.

## Geprüfte Fehlerkorrekturen

Die ersten geriggten Fassungen bestanden Strukturprüfungen, zeigten aber im
echten Viewport unbrauchbar gedehnte Finger und Mantelflächen. Deshalb prüft
`meshy_character_test.gd` zusätzlich die tatsächlich importierten,
knochengewichteten Eckpunkte während einer Angriffspose. Keine Kante darf in
dieser Pose länger als das Siebenfache ihrer Ruhelänge plus 3 cm werden. Dieser
Grenzwert wurde während der Korrekturen nicht erhöht.

Die Pipeline behebt die Ursachen in Geometrie und Gewichten:

- Zusammengehörige Flächen werden für konsistente Detailstufen verschweißt;
  getrennte Flächenfächer an punktförmigen Kontakten bleiben getrennt.
- Die im Signifer-Original verbundenen Hand- und Tunikaflächen werden im
  überprüften Handbereich an ihrer Texturgrenze getrennt. Die ursprünglichen
  Dreiecke und UV-Koordinaten bleiben dabei erhalten.
- Die Handkomponenten folgen vollständig der passenden Armkette. Die
  Grundgewichtung unterhalb des Handgelenks läuft auch bei diesen Komponenten
  kontrolliert aus; ein Hautmerkmal aktiviert keinen unbegrenzten Armzug.
- Die Gewichtung an der mittleren Beinnaht geht kontinuierlich zwischen links
  und rechts über. Dadurch springt ein zusammenhängender Stoffsaum nicht
  plötzlich auf das andere Bein.
- Zwei milde Glättungsschritte entlang echter Meshkanten bereinigen die durch
  Reduktion interpolierten Gewichte. Getrennte Hand- und Stoffflächen werden
  dabei nicht wieder miteinander verbunden. Jeder Eckpunkt besitzt danach
  höchstens vier normalisierte Knochengewichte.

Die Autorenpipeline akzeptiert ausschließlich die beiden überprüften
Originaldateien mit ihren festgelegten SHA-256-Werten. Ein anderer Download
mit gleichem Dateinamen wird nicht ungeprüft an diese Formprofile angepasst.

## Nachweise

Der endgültige Körperlauf bestand **184 Prüfungen ohne Fehler** im
Headless-Modus und **204 Prüfungen ohne Fehler** im echten Godot-Viewport.
Geprüft werden alle acht importierten Stufen, die vorhandenen Texturen,
Knochen und Gewichte, sämtliche Bewegungsnamen, die Bewegung gebundener Hände
und Füße, der Erhalt der Animationsphase beim Detailwechsel sowie die
Rückfallpfade für nicht zugelassene Figuren. Starre Ausrüstungsmeshes werden
nicht versehentlich als Körper ausgewählt: Der Test prüft genau einen
skinnenden Körper und ein Skelett.

Die zehn tatsächlichen Bildaufnahmen unter `evidence/characters-viewport/`
zeigen beide Figuren in Ruhe, beim Gehen, Rennen und Angreifen sowie beim
Gehen in Stufe 2. Diese Ansichten wurden einzeln geprüft. Die früheren langen
Fingerstreifen, der mitgezogene große Mantelabschnitt und die aufbrechenden
LOD-Nähte sind darin beseitigt. `visual-review.json` verknüpft die geprüften
Bilddateien und die acht Körperdateien mit ihren SHA-256-Werten.

Die Aufnahme erfolgte mit Godot 4.7.2, OpenGL Compatibility und Mesa llvmpipe.
Sie belegt den Desktop-Import und die sichtbare Animation, keine Messung auf
einem Android-Gerät. Die Körperaufnahmen enthalten noch den früheren
Griffversatz; für den endgültigen Griff gilt die separate Ausrüstungsprüfung.

## Die übrigen fünf Quellen

Alle sieben kanonischen Figuren wurden heruntergeladen und binär sowie anhand
der Anbieterbilder geprüft. Die folgenden Quellen bleiben bewusst außerhalb
der Laufzeitregistrierung, bis ihre konkrete Geometrie überarbeitet wurde:

| Quelle | Verbleibende Arbeit |
| --- | --- |
| Schwerer römischer Reiter | Pferd und Reiter sind ein verbundenes Modell; getrennte Figuren und Pferdeskelett erforderlich. |
| Leichter römischer Reiter | Ebenfalls verbundenes Pferd/Reiter-Modell. |
| Römischer Bogenschütze | Fest angehobener Arm und Gegenstand über der Schulter müssen getrennt und neu eingerichtet werden. |
| Germanischer Speerträger | Sockel, Speer und Schild sind Bestandteil der Geometrie; Trennung und saubere Handanschlüsse erforderlich. |
| Germanischer berittener Gefolgsmann | Quelle mit verschränkten Armen und Schild; eine geeignete Ruhepose fehlt. |

`CHARACTER_SOURCE_REVIEW.json` enthält die exakten Task-IDs, Originalgrößen,
Originalhashes und den jeweiligen Status. Die Rohdownloads sind ignorierte
Autorenquellen und gelangen nicht zusätzlich in das Android-Paket. Sie sind
über ihre kanonischen Task-IDs erneut beschaffbar. Temporäre Downloadlinks
werden nicht gespeichert. Die Anbieterantwort enthielt kein Lizenzfeld;
deshalb wird hier keine unbelegte Lizenzbezeichnung ergänzt.

Die beiden eingesetzten Figuren besitzen keine einzeln beweglichen Finger,
Gesichtsmorphs oder simulierten Kleidungsstoffe. Die vorhandenen Formen und
Texturdetails der generierten Quellen bleiben sichtbar; dies ist keine
archäologische Prüfung ihrer historischen Genauigkeit.

## Reproduktion

Die exakten Originale werden gemäß `prototype/assets/meshy/source/README.md`
bereitgestellt. Danach im Repository:

```sh
blender -b -t 2 -P tools/characters/build_meshy_people.py -- --types all
godot --headless --editor --path prototype --import
IMPERATHEN_ISOLATED_TEST=1 godot --headless --path prototype --script res://tests/meshy_character_test.gd
```

Für die Bildausgabe wird derselbe Test mit einem echten Display und einem
Ausgabeordner hinter `--` gestartet. Ein erneuter Autorenbau erzeugt neue
Derivate und erfordert entsprechend eine neue Import- und Sichtprüfung.
