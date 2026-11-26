# Pferdehandelshof

Originales, für Valdora um 58 v. Chr. entworfenes Hofmodul. Ein Tor in der niedrigen Straßenmauer führt über eine befahrbare Kalksteinschwelle in den offenen Hof. Die gedeckte Rückseite enthält zwei Pferdestände mit eigener Futterraufe, Einstreu, Anbinderingen und offenem Zugang. Ein steinerner Tränktrog mit sichtbarer Wasserfläche steht am westlichen Hofrand, ein Verkaufstisch mit Wachstafel und Futtergefäßen am östlichen Rand. Das Schild am Tor trägt einen modellierten Pferdekopf. Die Szene enthält weder Pferde noch Spielscripte.

## Einbau

Die Ressourcen stable.glb und stable_collision.tscn aus prototype/assets/roman_quarter/stable als gleich transformierte Geschwister instanziieren. Der Pivot liegt mittig auf Eingangshöhe. Die Straße liegt bei +Z, die Zufahrt führt nach −Z. Nach der Drehung des Hofs müssen auch die Standplatzkoordinaten über seine Node3D-Transformation in Weltkoordinaten übertragen werden.

| Lokal in Godot, Meter | Wert |
|---|---|
| Sichtbare Grenzen X | −3,921 bis +3,880 |
| Sichtbare Grenzen Y | 0 bis +3,974 |
| Sichtbare Grenzen Z | −7,510 bis +0,063 |
| Lichte Durchfahrt zwischen den Torpfeiler-Collidern | 2,58 |
| Anker linker / rechter Stand (X,Y,Z) | (−1,72, 0, −5,28) / (+1,72, 0, −5,28) |
| Blick im Stand | zum Hof, lokal +Z |

Die getrennte Physikszene enthält 21 Boxen für Boden, Wände, Einfahrt, Stützen, Abtrennung und Ausstattung. Der Bodenkörper endet auf Y=0. Der Test bewegt ein Prüfvolumen von 0,95 × 1,85 × 2,05 m von der Straße bis zu jedem Anker und kontrolliert zusätzliche Sichtgeometrie auf freier Zufahrt. Pferdehandel, Akteure und das Einsetzen in die Straße gehören zur übergeordneten Spielszene.

## Quelle und Prüfung

stable.blend enthält getrennt bearbeitbare Bauteilgruppen und gepackte Texturen. stable.py erzeugt Geometrie, Futter, Flechtwerk, Torbeschläge, Schild, Raufen und Collider lokal aus definierten Profilen und festen Seeds. Ziegel, Holz, Mauerwerk und Metall verwenden den originalen gemeinsamen Dorfatlas, der Boden verwendet die vorhandene Straßenerde. Die GLB referenziert die vier PNGs relativ unter prototype/assets/village. Sie verwendet einen Mesh-Knoten mit drei Oberflächen für Architektur, Erdreich und Wasser. Wasser und Heu sind statisch.

    blender -b --python-exit-code 5 --python tools/world/stable.py
    godot --headless --path prototype --import
    godot --headless --path prototype --script ../tools/world/stable_verify.gd
    godot --path prototype --rendering-method gl_compatibility --resolution 1080x760 --script ../tools/world/stable_verify.gd -- --shots=/tmp/stable

Die beiden Aufnahmen in stable.webp zeigen den Hof und den Blick durch die Einfahrt in Godots Compatibility-Renderer. Die Abnahme verwendet eine lokale Testszene und den ausgelieferten Mesh samt Physikszene.
