# Architektur, Bewegung und PC-Rendering

## Das Atrium im Dorf

Im römischen Dorf führt der Weg durch die nördliche Öffnung der Palisade zum Atriumhaus bei (14, −30). Die Tür liegt an seiner dem Dorf zugewandten Seite. Vom Eingang führt der Korridor in den Hof mit vier Säulen und Regenbecken. Die sichtbaren Türflügel stehen offen. Der Kapseltest bewegt die 56 cm breite Spielfigur durch den Eingang und prüft das Abstoßen an Korridorwänden und Säulen. Im Personenmodus erlauben zwei Finger im freien Weltbereich eine Nahansicht bis 1,7 Meter Kameraabstand. Das Analogpad hat eine eigene Berührung.

Die offiziellen Ortsbilder von GTA VI dienten als visueller Vergleich für die Lesbarkeit unterschiedlich großer Strukturen. Für die Ausführung der römischen Bauteile ist die antike Bauweise maßgeblich. Ein Teil der Vorlagen sind Fotos und Beschreibungen des Hauses der Vettier in Pompeji. Das Dorfhaus hat einen eigenen Grundriss. [Rockstar Games, Mediengalerie](https://www.rockstargames.com/VI/media) · [Archäologischer Park Pompeji, Haus der Vettier](https://pompeiisites.org/en/archaeological-site/house-of-the-vettii/)

Die neue Fassade hat geöffnete Brettertüren mit Beschlägen, vergitterte Fenster mit Läden, einen steinernen Sockel und geschichteten Putz. Das Dach führt über überlappende Flach- und Deckziegel zum Compluvium. Der Hof hat bemalte Wandfelder, Mosaikbänder, sichtbare Traghölzer und ein eigenes Wasserfeld. Aus einer Spielkamera entlang der Straße, einer im Hof und einer über dem Dach wurden vor und nach dem Umbau dieselben Ansichten gerendert. Der finale Godot-Import hat eine Materialoberfläche, 21.756 Dreiecke in der höchsten Stufe und fünf erzeugte LOD-Stufen bis 240 Dreiecke. Zuvor waren es 4.912 in der höchsten Stufe. [Straße vorher](../../art/architecture/review/strasse_before.png) · [Straße nachher](../../art/architecture/review/strasse_after.png) · [Innenhof](../../art/architecture/review/hof_after.png) · [Dach](../../art/architecture/review/dach_after.png) · [Importdaten](../../art/architecture/review/after.json)

## Gehende Soldaten

Das Spiel hält die Position und Identität jedes Soldaten im taktischen Modell. Die Darstellung vermittelt zwischen den 0,2 Sekunden auseinanderliegenden Simulationsschritten. Strecke und Bewegungstempo treiben den Gangzyklus. Die Phase bleibt beim Wechsel des Detailgrads erhalten. Füße haben eine Standphase, während Knie, Becken und Oberkörper weiterarbeiten. Ein stehender Verband behält seine Position. Für die Ferne verwendet die Darstellung weiterhin rollenweise gebündelte Instanzen. Die taktile Bedienung und das Ziehen einer Front bleiben unabhängig von der Animation. [Feral Interactive, ROME: Total War für Mobilgeräte](https://www.feralinteractive.com/en/games/rometw/android-ios/) · [Drei Sekunden aus dem marschierenden Verband](../../art/soldiers/field_march.webm)

Der Test prüfte vier Rollen, zwei geriggte Detailstufen sowie Marsch, Lauf und Rückzug. Auf ebenem Untergrund betrugen der größte horizontale Schlupf des aufgesetzten Fußes 1,19 cm und die maximale vertikale Abweichung 0,56 cm. Für die echte bewegte Nahaufnahme wurden in einem festen 24-Hz-Aufnahmetakt 72 Bilder aus Godot ausgegeben. Für erreichbare Spielbildraten auf Mobilsilizium ist eine getrennte Hardwaremessung nötig. Die Fotos in der Figurengalerie und die animierten Schlachtmodelle haben unterschiedliche Detailgrade. [Animationsprüfung](evidence/motion/soldier_gait.log) · [Modell- und Renderwerte](../../art/soldiers/README.md)

In der festen 1.280 × 800 großen Schlachtübersicht mit 60 Soldaten betrug die Framezeit p50 mit llvmpipe 73,0 / 334,5 / 523,3 ms für Niedrig / Ausgewogen / Hoch. Die entsprechenden p95-Werte waren 90,4 / 564,0 / 600,5 ms. Die Engine meldete 70 / 139 / 246 Draw Calls und 423 / 522 / 630 MiB als höchsten abgelesenen Prozess-RSS. Je Profil wurden zwölf Bilder zum Aufwärmen und 55 zum Messen verwendet. Beim Profilwechsel blieb der taktische Zustand gleich. [Aktuelle Messreihe mit CPU- und Software-GPU-Zeiten](evidence/motion/frames.json)

## PC und Android aus demselben Projekt

Im Windows-ZIP steht neben `IMPERATHEN.exe` der zusätzliche Starter `IMPERATHEN-Vulkan.cmd`. Er öffnet dieselben Inhalte und denselben Speicherpfad mit Godots Forward+-Renderer. Für die Auswahl einer Grafikkarte unterstützt er die Godot-Argumente `--verbose` und `--gpu-index`. Die direkte EXE verwendet die Compatibility-Voreinstellung. Unter Linux gelten dieselben Startargumente.

```bat
IMPERATHEN-Vulkan.cmd --verbose --gpu-index 0
```

```sh
./IMPERATHEN.x86_64 --rendering-method forward_plus --rendering-driver vulkan --gpu-index 0
```

Der Windows-Start per CMD unter Wine und der Linux-Start wurden mit Vulkan 1.4.305 und Mesa llvmpipe geprüft. Auf beiden Wegen erreichte das Spiel den Startmarker. Bei Hoch gilt auf dem Desktop ein Budget von 8.294.400 internen 3D-Pixeln, auf Android von 3.686.400. Niedrig und Ausgewogen behalten die gemeinsamen Budgets 921.600 und 2.073.600. Ausgabeformat und UI-Auflösung bleiben vom 3D-Budget unabhängig. Der Diagnoseschalter zeigt Grafikadapter, Renderer, berechnete interne 3D-Auflösung und Fensterauflösung an. Die Grenzwerte sind im Test für ein 4K-Fenster geprüft. Hier stand weder ein physischer Windows-PC mit diskreter GPU noch ein Fold7 zur Verfügung. [Linux-Startlog](evidence/motion/linux-vulkan.log) · [Windows-Startlog](evidence/motion/windows-vulkan-launcher.log)
