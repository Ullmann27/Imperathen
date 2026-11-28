# Reproduzierbare Prüfungen
Godot **4.7.2 stable**. Die PRIMA-CI prüft das offizielle Archiv gegen den veröffentlichten SHA512-Index. Projekt ist `prototype/`, nicht Repository-Wurzel. Tests mit Speichern nur mit isolierten Datenverzeichnissen; keine Spielstände anderer Personen verwenden.

```sh
export IMPERATHEN_ISOLATED_TEST=1
d=$(mktemp -d)
export XDG_DATA_HOME="$d/data" XDG_CONFIG_HOME="$d/config" XDG_CACHE_HOME="$d/cache"
godot --headless --path prototype --import --quit
for suite in genesis_mission_event_batch operation_prima_story i01_slice i04_slice campaign_forge_continuity; do
  godot --headless --path prototype --fixed-fps 60 --script "res://tests/${suite}_test.gd" || exit 1
done
node tools/architecture/test_index.mjs && node tools/architecture/build_index.mjs --check
```

Ein bestandener neuer Batchtest endet in `GENESIS_MISSION_BATCH_RESULT checks=10 failures=0`. Zusätzlich die Logs nach `SCRIPT ERROR:`/Engine-`ERROR:` prüfen; unsere CI wertet sie als Fehler. Die letzten beiden Suiten verwenden die bestehende Schmiedelogik bzw. die echte Spielszene. Für die komplette PRIMA-Route siehe `tools/ci/operation_prima.sh`. V1/V2 von Grafik mit identischer Kamera und Profil abgleichen; kein Headless-Bild als GPU-Benchmark verwerten.

Android-Einstieg: `docs/10_development/ANDROID_INSTALL.md` und vorhandene Projekt-Workflows, Paketidentität und Signatur prüfen. Signing-/APK-Produktion ist kein Teil des neuen Batchtests. `tools/fold7_physical_qa.py` benötigt ein echtes freigegebenes Gerät; ein CI-APK belegt keine Temperaturmessung.
