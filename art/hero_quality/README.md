# Anatomischer Hauptcharakter – Arbeitsstand 22. November 2026

Dieser Ordner enthält den reproduzierbaren 3D-Hauptcharakter und echte Blender-Prüfrender für den Android-Prototyp. Das Modell ersetzt beim freigegebenen Italia-Spieler die alte prozedurale Grundfigur. Die Bildreferenz ist eine gestalterische Zielvorgabe; sie ist kein Screenshot der laufenden Anwendung.

## Enthalten

- `hero.blend`: bearbeitbare Geometrie, UVs, gepackte Texturen, 15 Knochen, Alters-/Gesichtsformen und elf Animationen.
- `review/hero_child_face.png`, `hero_child_full.png`, `hero_adult_face.png`: tatsächlich mit Blender Cycles gerenderte Ansichten derselben Geometrie wie im Export.
- `review/hero_blink.png`, `hero_jaw.png`, `hero_run.png`: bewusst sichtbare Deformationsproben, kein Ersatz für die Prüfung aller Posen.
- `build_report.json`: Blender-Version, Exportdateigrößen, Dreieckzahlen, Bildgrößenlimits und SHA-256 der tatsächlich erzeugten GLBs.
- `validation.json`: unabhängiger Audit der vier tatsächlichen GLB-Dateien; prüft unter anderem normalisierte Skin-Gewichte, Joint-Indizes, nichtleere Morphdeltas, veränderliche Animationskanäle, Bildgrößen und strikt fallende Dreieckzahlen.
- `source/provenance.json` und `source/system_assets/provenance.json`: konkrete Quellen, Revisionen, Prüfsummen und Lizenzbelege.

Die vier spielbaren Dateien liegen unter `prototype/assets/characters/hero_quality_0.glb` bis `hero_quality_3.glb`. Die vorhandenen Figuren bleiben als Rückfallmöglichkeit erhalten.

## Offline reproduzieren

Ab dem Repository-Hauptverzeichnis, mit Blender 4.3.2 und dessen gebündeltem NumPy:

```sh
blender -b -t 4 -P tools/characters/build_hero.py -- --preview-only
blender -b -t 4 -P tools/characters/build_hero.py -- --export
python tools/characters/validate_hero.py
```

`--no-render --export` erzeugt die Geometrie und vier Exporte ohne erneute Prüfbilder. Alle erforderlichen grafischen Ausgangsdaten sind im Repository enthalten; es ist kein Netzabruf und kein bezahlter Dienst für diesen Build nötig. Die Animationserstellung verwendet zusätzlich den vorhandenen lokalen Projektcode `art/soldiers/build.py`.

## Vertrag mit dem Spiel

| Eigenschaft | Wert |
|---|---|
| Koordinaten im Blender-Modell | Meter, Füße bei Z = 0, Blick nach −Y |
| Grundgröße | 1,50 m anatomischer Körper, Haare/Sandalen können darüber hinausreichen |
| Altersübergang | `Mature` verändert die lokale Anatomie; vorhandene Laufzeitskalierung 1,14 vergrößert den Erwachsenen |
| Hauptmeshes | `HeroBody`, `HeroEyes`, `HeroHair`, `HeroTunic`, `HeroTunicSkirt`, `HeroBelt` |
| Haut / Stoff | `HeroSkin`, `HeroLinen`; kein Ersatz durch den alten Frontporträt-Atlas |
| Gesichtsformen | `Blink_L`, `Blink_R`, `JawOpen`, `Smile`, `BrowDown` |
| Weitere Formen | `Mature`, `Companion` |
| Ausrüstungskompatibilität | `PracticeBlade` als separat schaltbares Mesh |
| Animationen | `idle`, `march`, `run`, `gather`, `talk`, `train`, `work`, `block`, `attack`, `hit`, `death` |

Die Knochen heißen `Pelvis`, `Spine`, `Head` sowie jeweils links/rechts `Arm`, `Forearm`, `Hand`, `Thigh`, `Shin`, `Foot`. Es gibt höchstens vier normalisierte Hautgewichte pro Vertex. Die Kleidung besitzt eigene Geometrie; vollständig verdeckte Körperflächen sind zur Vermeidung von Durchbrüchen entfernt.

| Datei | Entfernung | Dreiecke im Build | Dateigröße | Bildkante höchstens |
|---|---|---:|---:|---:|
| `hero_quality_0.glb` | nah | 32.820 | 13.64 MB | 2048 px |
| `hero_quality_1.glb` | mittel | 16.417 | 6.03 MB | 1024 px |
| `hero_quality_2.glb` | fern | 7.222 | 3.03 MB | 512 px |
| `hero_quality_3.glb` | sehr fern | 2.820 | 0.97 MB | 256 px |

Diese Tabelle beschreibt die vier Entfernungs-LODs, nicht vier fest zugeordnete Grafikprofile. Die Laufzeit verschiebt die Wechselentfernungen über den Profilfaktor; auch das leichte Profil kann bei einer nahen Kamera LOD 0 laden. Eine Profilvergleichsaufnahme und eine erzwungene LOD-Vergleichsaufnahme beantworten daher unterschiedliche Fragen.

Die Gesichtsmorphs bleiben in allen vier Exporten vorhanden. Die Laufzeit deaktiviert ihre fortlaufende Aktualisierung auf den beiden einfacheren Stufen. Größen und Dreieckzahlen werden am tatsächlichen Export gemessen, nicht aus diesen Zielwerten abgeleitet.

## Materialien und Quellen

Die anatomische Ausgangsgeometrie, Altersziele, UVs, grafischen Gewichte, Augen sowie die ausgewählten Haut-/Haarbilder stammen aus den offiziellen **CC0-Grafikdaten von MakeHuman**. Das CC0 gilt hier für die grafischen Daten. Es wurde kein MakeHuman-Programmcode übernommen. Die mitgelieferten Originaldateien `source/LICENSE.md` (Abschnitt C), `source/LICENSE.ASSETS.md` und die CC0-Kopftexte der MHCLO-/MHMAT-Dateien dokumentieren diese Trennung.

Das Kernmaterial ist auf die in `source/provenance.json` genannte Git-Revision festgelegt. Für das offizielle System-Asset-Paket dokumentiert der zweite Beleg die tatsächlich heruntergeladene ZIP-Prüfsumme und die Prüfsumme jeder übernommenen Datei. Der Generator liest diese Dateien offline.

Der kindliche Körper mischt die männlichen Child-/Young-Geometrieziele im Verhältnis 0,78 zu 0,22 und normalisiert die Körpergröße. Die verwendete bartfreie Hauttextur stammt aus dem Systemordner `young_caucasian_female`; diese Wahl betrifft das Hautbild, nicht das männliche Körpermodell. Der Erwachsenenübergang verändert die Geometrie, verwendet in diesem Arbeitsstand jedoch noch dasselbe Hautbild.

Leinenfarbe, Geweberelief, Haut-Mikrorelief und Rauheit sind eigene deterministische Bildmaterialien des Generators. Das Mikrorelief ist kein Hautscan. Die Materialien bestehen aus gewöhnlichen glTF-Basisfarbe-/Normal-/Rauheitsanschlüssen und setzen kein Subsurface-Scattering voraus.

## Nachweisgrenzen und nächste Qualitätsarbeit

Der Stand ist eine anatomische und technisch integrierbare Verbesserung des Prototyps. Er erreicht noch nicht die gelieferte AAA-Dialogreferenz. Insbesondere Haar-Silhouette, Gesichtshaut, Blickwirkung, Mundinnenraum und individuell modellierte Stofffalten benötigen weitere künstlerische Arbeit. Die Tunika und die Altersanpassung nutzen eine kompakte 15-Knochen-Struktur; eine vollständige Kleidungssimulation und eine separate Erwachsenen-Skelettlösung sind nicht enthalten.

Die drei Deformationsbilder prüfen einzelne Zeitpunkte. Sie belegen keine fehlerfreie Kombination sämtlicher Animationen, Ausrüstungen und Alterswerte. Der GLB-Audit prüft Daten und echte Morph-/Animationsbewegung; die visuelle Prüfung bleibt zusätzlich erforderlich. Eine erfolgreiche Godot-Importprüfung beweist weder eine bestimmte Bildrate noch die Temperatur-/Speicherstabilität auf einem physischen Android-Gerät. Diese Freigabe benötigt weiterhin einen dokumentierten Test auf dem Zielgerät.

## Durchgeführte technische Prüfung

Der unabhängige Audit in `validation.json` besteht für alle vier Dateien. Der Godot-Import und die Integrationstests wurden mit Godot 4.7.2 durchgeführt: `HERO_FACE_TEST` 55/55 und `VILLAGE_PERSON_TEST` 221/221 erfolgreich. Der Village-Test bestätigt unter anderem Haut-Albedo sowie Leinen-Albedo, -Normal- und -Rauheitstextur, den 15-Knochen-/11-Clip-Vertrag, die Altersumschaltung, Gesichtsmorphs und den schaltbaren Übungsstab. Dies sind Daten- und Laufzeitnachweise; die visuellen und physischen Android-Grenzen oben bleiben bestehen.
