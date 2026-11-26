# Straßenwasserstelle bei Aquileia

Ein bodennaher, offener Laufbrunnen für das römische Straßenmodul. Die Gestaltung interpretiert eine republikanische Wasserstelle mit Werkstein, Bronzebeschlägen und griechisch-italischem Muscheldekor für den Spielbeginn 58 v. Chr. Die Wasserstelle ist ein Originalentwurf für Valdora.

Die bearbeitbare Blender-Quelle enthält einzeln benannte Bauteile. Das Becken besitzt eine Innenwand bis zur Sohle, flache Ausrundungen im beanspruchten vorderen Rand und eine Feuchtigkeitszone. Sechs dunklere Platten tragen das Becken. Die bogenförmige Stele trägt eine Bronzetülle mit offenem Austritt, vier Befestigungen und einem gefächerten Steinrelief. Der Wasserfaden trifft in eine unebene, undurchsichtige Wasseroberfläche. Strahl und Wellen sind statische Geometrie.

## Herkunft und Integration

Alle Formen, Profile, Skulpturflächen und Materialkarten wurden lokal für das Projekt gestaltet. Der reproduzierbare Modelliercode liegt in fontana.py. Die Travertinkarten mit Sedimentbändern, Poren, Normalen und Rauheit messen 768 × 768 px. Der Bronzeaufbau mit lokaler grüner Patina verwendet 192 × 192 px. Die Blender-Datei enthält die Bilder gepackt. Die GLB verweist auf die sechs benachbarten PNGs. Godot importiert diese mit Mipmaps und VRAM-Kompression. Das Editor-Importskript aktiviert die in glTF hinterlegte Oberflächenfärbung auf allen drei Materialien.

Der Pivot liegt mittig auf Pflasterhöhe. Die Front zeigt in Godot nach +Z. Importierte Gesamtmaße in Metern sind 2,644 × 1,670 × 1,695 (X/Y/Z). Die Frontlippe liegt auf 0,78 m, die Wasserlinie bei etwa 0,61 m. Für Kollisionen eignen sich zwei Boxen in lokalen Koordinaten.

| Teil | Mittelpunkt X/Y/Z (m) | Größe X/Y/Z (m) |
|---|---|---|
| Becken | 0 / 0,39 / 0 | 2,40 / 0,78 / 1,44 |
| Rückstele | 0 / 1,215 / −0,58 | 0,88 / 0,91 / 0,28 |

Eine optionale begehbare Sockelplatte misst 2,644 × 0,13 × 1,695 m. Ihre Oberseite liegt auf 0,13 m. Die Straßenszene setzt den gedrehten Prop und übernimmt die Kollision.

## Wiederholung

Vom Repo-Stamm mit Blender 4.3.2 (Python, Pillow, NumPy) und Godot 4.7.2 ausführen.

    blender -b -P tools/world/fontana.py
    godot --headless --path prototype --import
    godot --headless --path prototype --script ../tools/world/fontana_verify.gd
    godot --path prototype --rendering-method gl_compatibility --resolution 1040x760 --script ../tools/world/fontana_verify.gd -- --review=/tmp/fontana.png

Der Godot-Test öffnet die native GLB-Szene, kontrolliert die Abmessungen, drei Materialien, Farb-, Normal- und Rauheitskanäle, Vertex-Färbung und generierte Mesh-LOD-Daten. Die Nahansicht in fontana.webp stammt aus dem Compatibility-Renderer und zeigt das tatsächlich importierte Modell.
