# Status Renderer- und Profilstudie (Stand 26.11.2026, Abschluss auf Anordnung)

Branch `feat/render-profiles-study-20261126`. Der Projektrenderer ist unverändert `gl_compatibility`.

**Kurzfassung: Die Werkzeuge, Profile und Dokumente sind da; es gibt aus dieser Sitzung kein einziges
gerendertes Bild.** Die Vergleichs- und Schaukastenläufe standen von 07:08 bis zum Abschluss in der
Warteschlange der gemeinsamen Render-Sperre und kamen nie an die Reihe. Jede Aussage über Bildunterschiede
und Kosten der Renderer fehlt deshalb noch.

## Implementiert und automatisch getestet

| Teil | Nachweis |
| --- | --- |
| Engine-Schalter der vier Profile (Schattenfilter, Schattenatlanten, Lichtbudget, Anisotropie, SSAO, Dichte-Hooks), Profilname „Ultra“ | `python3 tools/check_prototype.py --godot $G --only render_profile` → PASS (26.11., 07:10) |
| Feste Ansichten, Zähler, Probenprotokoll | `--only render_bench_views` → PASS (26.11., 07:15, nach den Schaukasten-Änderungen) |
| Vergleichsharness lädt fehlerfrei | `$G --headless --path prototype --check-only --script res://tests/render_comparison.gd` → ohne Fehler |

## Implementiert, nicht ausgeführt

- **Schaukasten-Kameraliste (D-052)** `prototype/assets/rendering/showcase_cameras.json`, zehn Ansichten.
  Die Kameras `smithy`, `landscape_path` und `city_main_street` sind neu und wurden nie gerendert: Bildausschnitt
  ungeprüft. Die Gesprächsansicht `dialogue` ist nach dem Vorbild der Lookdev-Prüfung gebaut und ebenfalls
  nicht gelaufen.
- **Nacht über die Lookdev-Datei** (`render_bench.gd`, `enter_night`): nutzt `set_time_of_day` und
  `add_fire_light` der Lookdev, wenn vorhanden. In diesem Branch fehlt die Lookdev; der Pfad ist ungetestet.
- **Aufteilen der Aufnahmen** (`--append`, Bericht nach jeder Ansicht, Abbruch der ganzen Prozessgruppe): ungetestet.
- **Ultra-Prototyp** (Variante `ultra` in `tests/render_comparison.gd`): nie gerendert.
- **Rendererwahl beim Start** über `user://render_override.cfg`: Schreiben/Löschen der Datei ist getestet
  (`render_profile`); ob Godot die Datei beim Start wirklich für den Renderer auswertet, ist **nicht belegt**
  (Probe liegt bereit, lief nicht).
- **Vorher/Nachher-Bögen** `tools/render/showcase_compare.py`: nie ausgeführt.
- **Texturpakete** `tools/render/build_texture_package.py`: nicht gebaut.
- **Gerätemessung** `tools/render/fold7_render_bench.py`: kein Gerät vorhanden.

## Dokumente

- `TECHNIQUE_RESEARCH.md`: Recherche mit Quellen (vollständig).
- `GRAPHICS_PROFILES.md`: Profilmatrix vorher/nachher, Ultra-Weg, Rendererwahl je Profil, Messharness,
  offene Entscheidungen. Abschnitt 4 (Messwerte) fehlt.
- `RENDERER_COMPARISON.md`: Harness, Szenen, Kameras. Ergebnisse (Abschnitte 1, 2, 5–7) fehlen.

## Nächste Schritte für die Fortsetzung

```bash
G=/home/user/tools/godot/Godot_v4.7.2-stable_linux.x86_64
C="python3 tools/render/compare_renderers.py --godot $G --out <dir> --showcase --variants base,ultra --frames 3 --timeout 680 --append"
# je Sperrphase (höchstens 12 Minuten) ein Aufruf:
$C --renderers compatibility --steps village --profiles balanced,very_high
$C --renderers forward_plus  --steps village --profiles very_high
$C --renderers compatibility --steps city    --profiles balanced,very_high
$C --renderers forward_plus  --steps city    --profiles very_high
$C --renderers mobile        --steps village --profiles very_high
# danach Leicht/Hoch, die Funktionsprobe (--steps probe) und --analyze-only
```

1. Erste Bilder ansehen und die drei neuen Kameras korrigieren.
2. Probe der Start-Override-Datei ausführen (Skript in der Übergabe beschrieben: Projekt mit
   `project_settings_override`, Start mit und ohne Datei, `RenderingServer.get_current_rendering_method()`).
3. Tabellen aus `summary.md` in `RENDERER_COMPARISON.md` und `GRAPHICS_PROFILES.md` Abschnitt 4 übernehmen.
4. Nach dem Zusammenführen mit der Lookdev: Schaukasten auf dem Integrationsbranch, Vorher/Nachher mit
   `showcase_compare.py`.
