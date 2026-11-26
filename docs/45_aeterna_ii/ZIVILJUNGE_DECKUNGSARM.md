# Ziviljunge · rechter Deckungsarm

Die frühere Übergabe dokumentiert bei LOD 1 einen Kontakt von 24,10 mm im linken Haken. Nach der vorhandenen Schulterkorrektur blieb im linken Aufwärtshaken (`uppercut_left`) ein anderer Kontakt von 22,693 mm. Bei 0,75 s nähert sich der rechte Unterarm dem umgeschlagenen Ärmel. Die Schulter bewegt diesen Ärmel mit. Der zusätzliche Schritt öffnet daher nur den rechten Ellenbogen in der durch Schulter, Ellenbogen und Hand gegebenen Beugeebene. Der Winkel erreicht 11,999° und kehrt an den Clipgrenzen zur Originalpose zurück.

Der Vergleich bezieht sich auf die vier privaten, zivilen Derivate der Originalfigur und die zuvor korrigierte Deckung. Das Bauwerkzeug trägt pro LOD den maximalen Winkel und die SHA-256 des Ergebnisses in seinen Bericht ein.

| Prüfung | Ergebnis |
| --- | --- |
| Bisheriger vollständiger Vergleich bei 60 Hz | 19 Clips × 4 LODs, je 1.173 Posen. Größter Wert für „Gliedmaß in Stoff“ je LOD 2,701 / 2,062 / 1,001 / 0,000 mm. Grenzwert 10 mm. |
| Aufwärtshaken bei 240 Hz | 217 Posen je LOD. Nach Korrektur 0 mm in beiden Stoffprüfungen. Vorher bis zu 29,447 mm bei LOD 0 und 24,01 mm bei LOD 1. Der ergänzte Prüfer behält jede Pose des bisherigen 60-Hz-Laufs bei. |
| Nebenwirkungen | 0 überschrittene Hautkantengrenzen. Maximale Sohlendifferenz zum gerüsteten Referenzsatz 0 mm. Die rechte Hand weicht höchstens 42,303 mm ab, die linke Schlaghand um 0 mm. |
| GLB-Struktur | Originaler Binärpuffer jedes zuvor korrigierten zivilen GLB unverändert als Präfix erhalten. Ein neuer Rotationsaccessor für `Forearm_R` im betroffenen Clip. 18 weitere Clips unverändert, ebenso Mesh, Skin, Material und Texturen. |
| Godot 4.7.2, Desktop | `youth_outfit` 16, `youth_outfit_skin` 692, `youth_mocap` 170.999 Prüfungen bestanden. Beide Outfits geladen. |
| Godot-Posen nach Import, LOD 1 | Bei 217 abgefragten Skelettposen mit den GLB-Skinningdaten geht „Gliedmaß in Stoff“ von 23,853 auf 0 mm zurück. Die Messung verwendet die importierten Knochenposen und die GLB-Oberflächen. |
| Reproduktion | Vollständiger erneuter Durchlauf des Armkorrekturwerkzeugs ab den retargeteten GLBs und Wiederholung des Ellenbogenschritts ab den archivierten Schulterderivaten ergeben vier byteidentische GLBs. |

Im direkten Godot-Bildvergleich sind bei beiden Versionen dunkle, kantige Stellen an Ellenbogen und Handgelenk sowie eine schmale Hautspitze unter dem rechten Ärmel sichtbar. Der Ursprung in der Oberfläche, Textur oder Gewichtung muss separat untersucht werden. Die Messung betrifft die Stoffdurchdringung. Die Vergleichsaufnahmen stammen aus einem isolierten Godot-Assettest mit gleicher Kamera, Beleuchtung und Animationsphase. Prüfung in Valdora und auf dem Fold7 sowie visuelle Freigabe stehen aus.

## Reproduktion mit berechtigten privaten Eingaben

```sh
python3 tools/characters/clear_youth_civil_arms.py --input "$CIVIL_RETARGET" --output "$CIVIL_CLEAR" --report "$LAB/armkorrektur.json"
python3 tools/characters/check_youth_civil_outfit.py "$CIVIL_CLEAR"/hero_meshy_italia_{0,1,2,3}.glb --compare "$ARMOURED"/hero_meshy_italia_{0,1,2,3}.glb --report "$LAB/stoffvergleich.json"
```

Die normalen Godot-Outfittests erwarten die über das vorhandene Staging bereitgestellten Modelle in einer isolierten Projektkopie. Die drei Testskripte dort jeweils mit `godot --headless --path prototype --fixed-fps 60 --script res://tests/<name>_test.gd` ausführen.
