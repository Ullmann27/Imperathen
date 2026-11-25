# IMPERATHEN – tatsächlicher Stadtmodell-Export und Integrationsstatus

Stand: 25. November 2026. Diese Datei beschreibt die vorhandenen
GitHub-Dateien, nicht einen bereits bestandenen Android-Test.

## Identifizierte Lücke im Stadt-Stand 0

Die Spielszene `CityExploration` erwartet
`res://assets/world/roman_city_test.glb` und
`res://assets/world/roman_city_collision.glb`.
Beide Dateien waren bei der Bestandsaufnahme **nicht** in den öffentlich
zugänglichen Quellzweigen vorhanden. Die Stadt-Ladefunktion behandelt
fehlende `PackedScene`-Dateien als optional; dadurch konnten kleine
Adaptertests auf **künstlichen Prüfknoten** bestehen, ohne dass der ganze
echte Stadtrundgang vorhanden war.

Ebenfalls noch fehlend oder eigenständig zu beschaffen:
- `roman_meshy_temple_0/1/2.glb`: Original-Meshy-Tempel, nicht
  durch einen prozeduralen Ersatz als fertig ausgegeben.
- `roman_forum_paving_detail.glb` und
  `roman_forum_paving_collision.glb`: falls sie nicht im privaten
  Stadtpaket vorhanden sind, benötigen sie ebenfalls einen geprüften Export.
- Das bisher separat verwaltete Layout der echten
  `city_crowd_layout.json`-Mitspieler ist keine abgenommene,
  voll bewohnte Stadt.
- Eine endgültige hochwertige, maßstäbliche Cinematic-Stadtszene
  aus dem KI-Konzeptbild besteht noch nicht als gemessene Android-Grafik.

## Jetzt ausführbare echte Assetpipeline

`.github/workflows/roman-city-asset-build.yml` führt den vorhandenen,
originalen Blender-Generator `tools/world/build_roman_test_city.py` aus.
Er erstellt eine editierbare `.blend`-Projektdatei, eine metrische
Stadt-GLB, die separate Kollisions-GLB und das Generator-Manifest.
Die Einstellungen lauten `--surface-style viva --texture-size 1024`,
ohne fiktive Renderbilder.

Das Manifest weist **240 Wohnhausinstanzen** (fünf Grundtypen,
je drei Varianten), **63 Marktstände** und 3 Handwerksgebäude aus.
Das sind **Instanzen der bestehenden Modellformen**, nicht 240
individuell von Menschen modellierte Häuser.

Die Pipeline importiert diese echten GLBs in die bestehende Godot-4.7.2-App
und startet den neuen `roman_city_real_asset_test.gd`. Die Prüfung
unterscheidet die vollständigen Stadt- und Kollisionsobjekte ausdrücklich
von den bisherigen kleinen Dummy-Mesh-Fixtures. Sie untersucht:
- tatsächlich vorhandene 240 Wohnhäuser und 63 Marktstände,
- echte Straßen- und Handwerker-Knoten,
- separate physische Kollisionsmesh-Daten,
- die sechs tatsächlichen Ladenbeschriftungen,
- vorhandene Fassaden-MultiMeshes und neue VIVA-Portale/den Helm,
- keine vervielfachten Spieler, Kameras oder Originalhaus-Meshes.

Die entstehenden `.blend`, `.glb`, `city_manifest.json` und
Importprotokolle werden bei GitHub Actions als Artefakt bereitgestellt.
**Sie liegen nach dem Build nicht automatisch im Quellbranch und
sind auch nicht automatisch Bestandteil einer signierten APK.**

## Noch notwendige Freigaben

- Zuerst tatsächlichen erfolgreichen Blender- und Godot-Lauf abwarten,
  inklusive realer ursprünglicher Modellgeometrie.
- Anschließend identisches physisches Android-Gerät,
  gleiches Renderingprofil und 20-minütigen realen Temperatur-/Bildzeitlauf
  verwenden; aufgeladenes/ungeladenes Telefon vergleichen.
- Bei endgültiger Projektübernahme große GLBs über ein nachweisbares
  Assetlager, ein geeignetes Versionierungssystem oder einen reproduzierbaren
  Build-Schritt statt ungeprüfter privater Dateien bereitstellen.
- Die fehlenden Meshy-/Forum- und Indoor-Assets getrennt mit Quelle,
  rechtlicher Nutzbarkeit und physischer Abnahme ergänzen.
- Android-Build/Signatur bleiben separat gesperrt, bis Quelle, Tests,
  Kompatibilität und Installation tatsächlich überprüft sind.

Ein komplett grüner Dummy-Adaptertest ist kein vollständiger Stadtnachweis.
Kein Merge nach `main`; keine automatische APK.
