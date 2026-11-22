# IMPERATHEN – Figurenvorlagen aus vier Ansichten

Jeder Ordner im ZIP gehört zu einer Figur. Für eine Mehransichten-Eingabe in Meshy die vier Einzelbilder desselben Ordners wählen. Die Dateinamen geben die Kameraansicht an. Die Kontrollbögen sind beschriftete Übersichten.

| Ordner | Figur und Ausrüstung |
| --- | --- |
| heavy | Schweres Fußvolk mit Langschild und Schwert |
| spear | Speerträger mit Speer und ovalem Schild |
| archer | Bogenschütze mit Bogen, aufgelegtem Pfeil und Köcher |
| officer | Offizier mit Helmkamm, Mantel, Schild und Schwert |
| farmer | Feldarbeiter mit Hut und Hacke |
| han_farmer | Feldarbeiter mit Wickeljacke, Hose, Kopftuch und Hacke |
| wa_farmer | Feldarbeiter mit Haarband, Schultergurt und Holzspaten |

**Kamera und Maßstab.** Front, Dreiviertel (45°), Seite (90°) und Rückseite (180°) sind orthografisch, horizontal und in der neutralen Bindepose gerendert. Alle Dateien verwenden dieselbe Bodenlinie und 1024 × 1024 Pixel für ein 2,52 × 2,52 m großes Bildfeld. Eine Strecke von einem Meter entspricht rund 406 Pixeln. Beim Drehen kann ein Körperteil die Ausrüstung verdecken. Die Modellgeometrie und Materialien stammen für jede Ansicht aus demselben Spiel-GLB.

**Herkunft.** Die vier militärischen Modelle verwenden die Nahstufe der [originalen Feldkompanie](../../soldiers/README.md). Drei weitere GLBs stammen aus den [originalen Feldarbeiterstudien](../README.md). Blender 4.3.2 und Cycles erzeugen die PNGs lokal aus diesen Dateien. `manifest.json` im ZIP enthält die Quellpfade, SHA-256-Prüfsummen, Kameraangaben und sichtbaren Rechtecke jedes Bildes. Das Paket enthält Referenzbilder zur Weiterverarbeitung. Eine Meshy-Generierung ist ein separater Arbeitsschritt.

**Erneut erzeugen.** Aus dem Repository-Stamm ausführen. Die Blender-Python-Umgebung benötigt Pillow. Die Kontrollbögen verwenden DejaVu Sans.

```sh
blender -b -t 4 --python-exit-code 1 -P art/landscape/render_meshy_views.py
```

Die Prüfung vergleicht die aus den tatsächlichen Mesh-Eckpunkten projizierten Außengrenzen mit dem Alpha-Rechteck des fertigen PNG. Außerdem müssen alle vier Bildränder transparent sein. In das ZIP gelangen die 28 geprüften Bilder, die maschinenlesbaren Ergebnisse und diese Anleitung.

**Dateien in der Repositoryansicht.** [ZIP mit 28 transparenten PNGs](IMPERATHEN-Meshy-Figurenreferenzen.zip) · [Kontrollbogen Soldaten](soldaten.png) · [Kontrollbogen Feldarbeiter](feldarbeiter.png)
