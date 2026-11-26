# Figuren und Schriftstücke von Valdora

## Ein Gesicht pro Person

Die römischen Bürger, Bürgerinnen, Älteren, Legionäre, Speerträger, Bogenschützen und Offiziere verwenden in der Nähe und in mittlerer Entfernung dieselben Skelette und Animationen wie bisher. Blender erzeugt für diese 14 GLBs zusätzliche Formschlüssel für Unterkiefer, Nasenrücken und Wangen. Bei den drei zivilen Figuren kommt ein Formschlüssel für den Fall des Haares hinzu. Die bestehenden Gesichtsausdrücke bleiben separat animierbar. Die Ergänzungen belegen zusammen 1.666.112 zusätzliche Bytes in den GLBs.

Beim Aufbau liest die Figur ihre dauerhafte Personenkennung oder den bereits gespeicherten Aussehens-Seed. Daraus berechnet `roman_faces.gd` die individuellen Gewichte und eine von sieben Hauttönungen. Alle Personen eines Figurentyps teilen ihre Meshes und Texturatlanten. Für Personen mit gleichem Material und gleicher Tönung wird die Materialinstanz wiederverwendet. Der Fernbereich verwendet die bestehende Silhouette. Der Originaljunge und Marcus verwenden ihre jeweiligen Jugendmodelle.

Die Ausgangsanatomie und ihre Lizenz sind im [Quellennachweis](../../art/frontier_people/provenance.json) dokumentiert. Die neuen Formschlüssel und die Inschriften wurden für IMPERATHEN gestaltet. Der [Baubericht](../../art/frontier_people/build_report.json) enthält Größen und SHA‑256-Werte pro Exportstufe.

## Vom Auftrag zum Gegenstand

Wer in I‑04 bei Sextus den Botengang wählt, trägt sein aufgeklapptes Wachstäfelchen und kann es in **Dorfleben → Bei dir** lesen. Die Holzflügel tragen den Empfänger Fabius sowie den Auftrag für zwei Körbe Kohle zum Markttag. Am Tor erhält der Spieler in I‑07 nach dem überprüften Dienst eine gerollte Durchlassnachricht für Cassias Wagen. Die lateinischen Kurztexte auf den Modellen und die im Spiel lesbaren deutschen Fassungen sind kreative Ausgestaltungen der bereits vorhandenen Aufträge.

Der Besitz kommt unmittelbar aus `village.childhood.carried`. Die Übergabe entfernt den Gegenstand auch aus Hand und Leseansicht. Bei geschlossenem Dokument belegt die Detailansicht keinen eigenen 3D-Viewport. Die Handelsstation verwendet außerdem eine verschlossene Amphora mit zwei Henkeln und die aus dem vorhandenen Ältestenmodell geschnittene Steinbüste auf ihrem Sockel.

| Export | Dreiecke | GLB in Bytes |
| --- | ---: | ---: |
| Sextus’ Wachstäfelchen | 2.060 | 87.436 |
| Durchlassnachricht | 1.602 | 72.548 |
| Transportamphora | 2.632 | 65.008 |
| Steinbüste und Sockel | 5.988 | 159.748 |

## Nachvollziehen

Die folgenden Befehle laufen vom Repository-Stamm. Der Figurenexport aktualisiert die vorhandenen Nah- und Mittelstufen. Der Werkstattgenerator baut vier Modelle und kann deren Beleuchtung separat in Blender Cycles rendern.

```sh
blender -b -t 2 -P tools/characters/sculpt_roman_faces.py
blender -b -t 2 -P tools/world/build_legio_artifacts.py
blender -b -t 4 -P tools/world/build_legio_artifacts.py -- --review docs/46_legio_aeterna/evidence/schriftstuecke-blender.webp
godot --headless --path prototype --import
godot --headless --path prototype -s res://tests/legio_art_test.gd
godot --headless --path prototype -s res://tests/frontier_people_test.gd
godot --headless --path prototype -s res://tests/i04_slice_test.gd
godot --headless --path prototype -s res://tests/band1_expansion_test.gd
```

Blender 4.3.2 erzeugte die GLBs und die [Cycles-Aufnahme der beiden Schriftstücke](evidence/schriftstuecke-blender.webp). Godot 4.7.2 bestand 157 Prüfungen für Figuren, Original-Hautatlanten und das Öffnen im regulären Dorfmenü. Mit Bildausgabe über Mesa llvmpipe kamen drei erfolgreiche Aufnahmen hinzu. Der bestehende Figurentest bestand 251, die I‑04-Prüfung 259 und der Band-I-Test einschließlich Übergabe der I‑07-Nachricht 87 Einzelprüfungen. Die Testläufe verwendeten simulierte Spielereingaben und gesetzte Spielerpositionen an den vorgesehenen Auftragsorten.

Die Aufnahmen mit 1.000 × 540 Pixeln zeigen [drei römische Soldaten](evidence/roemische-gesichter.webp), [die vier importierten Modelle](evidence/bildnis-und-missionsobjekte.webp) und [das geöffnete Schriftstück im Dorfmenü](evidence/schmiedetafel.webp). Die erste und zweite Aufnahme verwenden eine Prüfkamerabühne. Die dritte verwendet das reguläre Dorfmenü im I‑04-Spielzustand.

Die drei Godot-Aufnahmen lassen sich auf einem Rechner mit X11-Ausgabe wiederholen.

```sh
LEGIO_CAPTURE_DIR="$PWD/docs/46_legio_aeterna/evidence" godot --display-driver x11 --rendering-method gl_compatibility --resolution 1000x540 --audio-driver Dummy --path prototype -s res://tests/legio_art_test.gd
```

## Was in Valdora tatsächlich in die Hand kommt

Die Missionschronik verzeichnet 113 Abschnitte, davon 32 in Band I. Ihr Kontinuitätsregister verbindet beispielsweise das Familienmahl mit einer späteren Erinnerung, den Münzstreit mit einer Zusage und eine Werkstatt mit ihrer späteren Nachfolge. In der spielbaren Kindheit gibt der gemeinsame Weltzustand elf verschiedene Objekt-IDs in `village.childhood.carried` aus. Hinzu kommen sieben Einträge für gerade gehandhabte Gegenstände und ausgeliehene Ausrüstung. Eine Ansicht erscheint erst, wenn der betreffende Besitz-, Hand- oder Leihzustand eintritt.

| Mission | Gegenstand in der Ansicht | Maßgeblicher Zustand |
| --- | --- | --- |
| I-01 | Julias Becher, Silvanus’ Becher, eigener schiefer Becher | Der jeweilige Becher steht in `screenplay.i01_cups` auf `hand`. Jeder verschwindet beim Abstellen an seinem Platz. |
| I-01 | Familienkrug | Der bestehende I‑01-Krugzustand ergibt `hand`, einschließlich des späteren Eintrags `water_jug`. |
| I-01 bis I-03 | Haushaltsdenar | `household_coin` bis zur Bezahlung der Bestellung bei Cassia. |
| I-01 bis I-02 | Julias Nachbarschaftskorb | `neighbor_basket` bis zur Übergabe oder Korrektur des Korbs. |
| I-03 | Familienbestellung, Wasserkrug für den Marktstand | `family_parcel` und beim entsprechenden Lösungsweg `stall_water`. |
| I-04 | Kleinholzbündel, einzelne Armvoll Kleinholz, Sextus’ Wachstäfelchen | `kindling_bundle`, `screenplay.i04_hand` beziehungsweise `sextus_note`. |
| I-05 bis I-06 | Geprüfter Truhengriff | `checked_hinge` nach der Prüfung bis zu Cassias Empfang. |
| I-07 | Versorgungspäckchen, gefüllter Krug zum Tor, Durchlassnachricht | `medicine_parcel`, `screenplay.i07_water == "carry"` beziehungsweise `gate_message`. |
| I-07 | Leihhelm und kleiner Holzschild | `childhood.gear == "loaned"`. Beide Ansichten erlöschen bei der Rückgabe. |
| I-14 | Erinnerungsstück am Waldrand | `memory_token` nach dem Schwur. Das gebrannte, unbeschriftete Scherbenstück ist eine kreative Ausgestaltung seiner im Drehbuch offenen Form. |

Für diese 18 Einträge verwendet die Inspektion 15 physische Modelle. Drei Aufträge teilen sich den Wasserkrug. Gesammeltes und umgestapeltes Kleinholz teilen sich ein Modell. Der Helm stammt aus der vorhandenen Montefortino-Studie. Zwölf weitere Objekte entstanden in Blender. Korbgeflecht, reparierter Eisengriff und Münzmotiv sind geometrisch modelliert. Leinen und die gebrochene Scherbe tragen eingebettete Farbtexturen. Die drei Becher und der Krug verwenden beim tatsächlichen Tragen im Dorf dieselben GLBs wie in der Detailansicht. Sextus’ kalter Nagel bleibt wie vorgesehen auf dem Ambossstock. Das Beobachten einer Sache erzeugt keinen Inventareintrag.

Der Test lädt den im regulären verteidigten Valdora-Durchlauf verdienten und gespeicherten Schwur, untersucht das Erinnerungsstück im Dorfmenü und vergleicht anschließend den vollständigen Spielzustand. Die Objektprüfung bestand 227 Prüfungen ohne Anzeige und 229 mit den beiden Aufnahmen. Die bestehenden Spielabläufe für I‑01 und I‑03 bestanden in isolierten Spielverzeichnissen 141 und 65 Prüfungen. Die Chronikprüfung bestand 32 Prüfungen für die 113 Missionseinträge und ihre 14 bekannten Quellenbefunde.

Der beschriftete Überblick ist eine Godot-Prüfbühne mit einzeln skalierten Modellen. Die zweite Aufnahme stammt aus dem Dorfmenü des geladenen I‑14-Spielstands. [15 Objektmodelle](evidence/gegenstaende-valdora.webp) · [Erinnerungsstück nach dem Schwur](evidence/erinnerungsstueck.webp)

```sh
blender -b -t 2 -P tools/world/build_valdora_handgoods.py
godot --headless --path prototype --import
godot --headless --path prototype -s res://tests/legio_objects_test.gd
LEGIO_CAPTURE_DIR="$PWD/docs/46_legio_aeterna/evidence" godot --display-driver x11 --rendering-method gl_compatibility --resolution 1000x540 --audio-driver Dummy --path prototype -s res://tests/legio_objects_test.gd
```
