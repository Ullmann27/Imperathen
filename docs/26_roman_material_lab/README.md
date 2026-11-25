# Roman material lab – Anschluss an #57
Drei getrennte Arbeitspakete, in einer Sitzung umgesetzt; keine unabhängigen Agentenprozesse behauptet.
- A: vier Eisen-Oberflächen, Gebrauchsspuren, Pitting, Oxidation, Bürstung.
- B: Leder, Eichenholz, Kalkputz für Rüstung, Werkstatt und Innenräume.
- C: numerische Prüfung, Blender-Materialadapter und isolierter Godot-Materialprüfraum.

Generator erstellt 21 prozedurale PNG-Review-Maps; 256×256 sind die mobile Prüfstufe. 512/1024/2048 werden unterstützt. Ein 1024er Eisen-Datensatz wurde numerisch geprüft. Keine fertigen Rüstungs-GLBs, keine Gameplay- oder historischen Schutzwerte.

## Befehle
Aus Repositorywurzel: `node tools/roman_material_lab/generate.mjs 256`; hochauflösend ohne Überschreiben der Prüfbilder: `node tools/roman_material_lab/generate.mjs 1024 /tmp/imperathen-materials-hi`.
Godot: `godot --path prototype --editor --import`, dann `godot --path prototype res://scenes/roman_material_lab/material_preview.tscn`.
Blender: `build_material(repo_root, "iron_service")` aus apply_blender.py; Materialslot optional anhängen, Polygonzuweisung bewusst separat.
    
## Prüfgrenzen
Generator und numerische Checks tatsächlich ausgeführt; Blender- und Godot-Adapter nicht in einer Engine ausgeführt. Keine visuelle Freigabe, keine FPS-Messung, kein APK-Build, kein Merge. Normalmap als tangent-space +Y vorgesehen; beim Import Normalmap-Erkennung/Orientierung prüfen. AO wird in Godot separat verwendet; in Blender nicht direkt in Albedo gebacken. Texturen sind eigene prozedurale Studien; Materialwirkung hängt von UVs, Mesh, Licht und Import ab.
