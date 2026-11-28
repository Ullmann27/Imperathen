# IMPERATHEN – Übergabe an die nächste Sitzung
**Sicherungsstand: 28.11.2026 UTC. Keine APK- oder Gerätefreigabe.**

## Auftrag und Grenzen
Nur GitHub [Ullmann27/Imperathen](https://github.com/Ullmann27/Imperathen) und
GitLab [Ullmann27/Imperathen](https://gitlab.com/Ullmann27/Imperathen), ID **89577832**.
Kein Zugriff auf andere Projekte. Vor Schreibzugriffen Arbeitsordner, Remote und Branch prüfen.
Astra produziert in einem eigenen Worktree, Sol integriert und baut die APK. Kein Force-Push,
Merge nach main, Store-Release, kostenpflichtiger Auftrag oder Upload privater Quellen.
Der reguläre Einstieg ist Valdora bei Aquileia, 58 v. Chr., ein zwölfjähriges Kind ohne
frei verfügbares Geld oder Militärausrüstung. Familie, freie Entscheidungen, Schmiedelehre und
der spätere Überfall bleiben bestehen. Ein autoritativer Weltzustand; deutsche Sprache und
vier Grafikprofile erhalten. Sichtbare Qualität hat Vorrang vor Gesamtgröße; RAM, GPU, Wärme
und Streaming messen. Zuerst [AGENTS](../../AGENTS.md), [Architekturindex](../../ARCHITEKTUR_INDEX.md),
[Systemkarte](../GENESIS/SYSTEM_MAP.md) und [Konvergenzregister](../GENESIS/STAND_ZERO_CONVERGENCE.md) lesen.

## Verifizierte Entwicklungslinien
Alle Commit-Angaben sind Checkpoints, keine Reset-Ziele. Für den aktuellen Handover-Tip
`git ls-remote origin refs/heads/hoplite/kolophon-ac55f0d6--viva-imperium` verwenden.

| Linie | GitHub-Branch | Referenz |
|---|---|---|
| Astra PRIMA | `feature/hoplite-operation-prima-i01` | [#213](https://github.com/Ullmann27/Imperathen/pull/213), `7070382016ec38bffb1d382ae8e031217fb24d91` |
| GENESIS I | `feature/hoplite-operation-genesis-universal-core` | [#214](https://github.com/Ullmann27/Imperathen/pull/214), `42e6579d3da5d23b84ea7976e259f40d7e515ed8` |
| GENESIS II | `feature/genesis-city-resident-integration-20261128` | [#215](https://github.com/Ullmann27/Imperathen/pull/215), `313986d6d998520659fe92a740014a2fb5c3f686` |
| GENESIS III | `fix/genesis-mission-receipt-integrity-20261128` | [#216](https://github.com/Ullmann27/Imperathen/pull/216), `d00fa3241120d25a28f7e31d517a68466bca127b` |
| Sol Stand Zero | `hoplite/kolophon-ac55f0d6--stand-zero` | `4d14cd50e3b9e5c7faebcdeab04c6ef41ad961be`; gemeinsamer Elternstand, endgültige Integration bei Sol |
| Astra VIVA | `hoplite/kolophon-ac55f0d6--viva-imperium` | `95d17f0670ae9684481e95f8541645d0b1d2968a` Modell/Integration; `f2007bccaa091ced1d10caea0e0c0b79b01cae70` Karten/Bildbelege; `5cc3dba30c879a4ddc11188d376769a7a7e73525` NPC/Story; `1b266c79a7fdb0611c8e34d5aac9a5e368d5fe79` Sprachprüfung |
| WIP-Sicherung, nicht integrieren | `hoplite/kolophon-ac55f0d6--continuity-wip` | `fc4f86012f6165777e133046d3f1ec1adec18b47`; verworfene öffentliche Mesh-Varianten, keine Produktionsmodelle |

## Assetregister – tatsächlich geliefert

**Eine neue Produktionsbaugruppe:** Frühstücksbrot mit Servierbrett, zwei editierbare
Objekte (`ScoredLoaf`, `ServingBoard`), ein exportiertes Mesh mit drei Materialien.
Keine neu erstellten Charaktere, Rüstungen, Pferde, Waffen, Gebäude, Sprachaufnahmen
oder Animationsclips in diesem Paket.

| Datei bzw. Pfad | Bedeutung / Status |
|---|---|
| `art/operation_prima/breakfast_bread.blend` | Vollständige Blender-4.0.2-Quelle; metrisches Modell und getrennte Studiokollektion. Erneut in Blender geöffnet; alle drei Texturen gepackt. |
| `art/operation_prima/build_breakfast_bread.py` und `art/operation_prima/breakfast_bread_authoring.md` | Reproduzierbare Herstellung, Export und Kameraansichten; keine Fremdtexturen oder privaten Modelle. |
| `art/operation_prima/maps/Viva_Breakfast_albedo.png`, `Viva_Breakfast_normal.png`, `Viva_Breakfast_roughness.png` (gleicher Ordner) | Originalkarten je 1.024 × 512; außerdem in Blender und GLB eingebettet. Materialien: Brett, Kruste, Einschnitte. |
| `prototype/assets/operation_prima/table_bread.glb` und `table_bread.glb.import` | 1.148 Dreiecke bei Manifestgrenze 1.184; tatsächlicher Godot-4.7.2-Import. Statische Requisite, kein Rig, keine Clips. |
| `prototype/assets/operation_prima/breakfast_bread.gd`, `prototype/scripts/world/village/interior_kit.gd`, `quality/motion_contract.json` | Gebunden an den vorhandenen Eintrag `table_bread` im Familienhaus: Hauptszene → I-00 → I-01 VID-A → `baker_home/glb_table`. Kein zweites Objekt, keine neue Inventaraktion. Vorhandene Position, Collider und Save-Daten bleiben maßgeblich. |
| `prototype/tests/operation_prima_art_test.gd` | Testet u. a. Originalplatzierung, Materialzuordnung, UV-Atlas, Budget und Collider; 28/28. Innenraumprüfung 8.037/8.037. |
| `docs/44_integration/evidence/viva/breakfast/` | Drei Blender-Renderings (`blender-three-quarter.png`, `blender-profile.png`, `blender-scored-crust.png`), zwei echte I-01-Bilder (`godot-before-i01.png`, `godot-after-i01.png`) und `production-receipt.json` mit Pfaden, Dateigrößen und SHA-256. |

Diese Produktionsdateien wurden **als vollständige GitHub-Blobs** gegen die Prüfsummen
gelesen, nicht nur als Dateinamen oder LFS-Zeiger. Vor jeder Übergabe erneut prüfbar:
siehe Befehle unten. Das unabhängige Sicherungsarchiv enthält zusätzlich **sieben**
einzigartige verworfene GLBs aus drei früheren Formationsfiguren innerhalb von
`archive/aeterna-continuity/formation/`, ein Blob-/Herkunftsregister und Diagnosen.
Die Quellen sind bereits öffentliche Imperathen-Dateien. Diese Versuche sind **fehlerhaft/WIP**;
die bestandene Version bleibt in Sols Branch. Keine Änderung am Formationscode oder am 40-mm-Limit.

## Gameplay, Tests und Grenzen

- [NPC-Leben](../44_integration/evidence/viva/npc-life.md): fünf reproduzierbare
  Diagnoseprotokolle unter `docs/44_integration/evidence/viva/npc/`. 36 Simulationsstunden,
  2.095 Bewohner, 480 Haushalte, 120 Betriebe; 1.779 Käufe und 7.776 Gespräche.
  Das ist keine Geräte-, Audio- oder vollständige Offscreen-Abnahme.
- [Story](../44_integration/evidence/viva/story-continuity.md): 113 Haupt-/96 Nebenmissions-IDs,
  nicht 209 spielbare Missionen. I-00 hat einen separaten Startpfad, I-01 bis I-14
  enthalten unterschiedliche Laufzeitschritte und Brücken. Die privaten Originalbände
  wurden nicht rekonstruiert. Keine neuen kanonischen Dialoge.
- [Sprachinventur](../44_integration/evidence/viva/voice-coverage.json) und
  [Godot-Neuexport](../44_integration/evidence/viva/voice-engine-recheck.json):
  **40 von 170** geprüften Zeilen technisch akzeptiert, **130 fehlend/ungültig**.
  I-04 ist nicht vollständig vertont. Text-/Hash-/Visem-Verifikation ist kein Hörtest;
  es wurden keine Stimmen erzeugt oder geklont.
- Frühstücksinszenierung 29/29 und I-04-Requisiten 173/173 auf der geerbten Basis;
  kein belegter Defekt, deshalb kein neuer Bewegungs-Patch. Für die VIVA-Baugruppe
  sind der neue Import, die beiden gezielten Tests und die gerenderte Tischansicht
  belegt. Keine Behauptung einer vollständigen Regression für den Übergabe-Commit.
- Weltwerkstatt, weitere Innenräume, Ausrüstungsvarianten, neue Kamerainszenierung,
  unabhängige Lebensläufe, Hör-/Geräteabnahme: nicht durch diesen Checkpoint geliefert.
  Die bestehende Vorschau ohne autoritative Interaktion nicht blind an den Start hängen.
- Auf Sols Stand `4d14cd50` bestanden Stadtbudget, I-04-Hauptszene, gezielte Grafiktests
  und [strikte Formation](https://github.com/Ullmann27/Imperathen/actions/runs/46139717576).
  Die Stadt hatte 2 Überschreitungen von 10.313 Aufrufen (unveränderter Grenzwert).
  Keine physische Fold7-Messung.
- [Fold7-Vorgänger da8d9155](https://github.com/Ullmann27/Imperathen/actions/runs/46137146624)
  endete rot, nicht beim Signieren: 169 Engine-Gruppen bestanden; der nachgeschaltete
  I-02-Originalkorbtest bestand mit 96/96. Die Stadtfassadenprüfung meldete vier
  Fehler in 20 Prüfungen: Erwartung „240 house fronts and 4 gates“ für alle vier Profile.
  Das Artefakt mit „apk“ im Namen enthielt **keine APK**. Ursache nicht vorwegnehmen.
  [Sol-Folgelauf 4d14cd50](https://github.com/Ullmann27/Imperathen/actions/runs/46139717557)
  lief beim Abruf; visueller CI-Job grün. Status live prüfen, nicht abbrechen/duplizieren.
  Keine VIVA-APK, keine Freigabe für Signatur, ARM64, Installation oder echte Hardware.

## Zustand, Zugriffsgrenzen und Reihenfolge

1. `feat/kimi-3d-special-operations-20261127:tools/agent_bridge/team_work_register.json`
   frisch lesen. GitHub beim Abgleich `afe20dcfff3012e3ae376cb3d12a60a0013b5f42`,
   Register v303: `ARGON-M28-NPC-OPPORTUNITIES` (Gemini, Opportunity-Vorschau und
   Test) und `CITY-MARKET-STAFF-AUTHORITY` (Coordinator, CityLife/Staff-Test/CI)
   reserviert. Gleichnamige GitLab-Linie wich ab (`23cddd2a`); nicht überschreiben.
2. Private Drehbuchdokumente, Meshy-Rohquellen, private Jugendrigs und Signierschlüssel
   nicht in öffentliche Branches aufnehmen. Nicht im Checkout vorhanden heißt nicht
   wiederhergestellt. Berechtigte Ableitungen nur über die vorhandenen projektseitigen
   Staging-Schritte im Fold7-Workflow beziehen; andernfalls als blockiert melden.
   Lokale Tools, Godot-Importprodukte, temporäre Save-Daten und Schlüssel gehören nicht ins Backup.
3. Nach dem Kontinuitätsauftrag zuerst Stand der Draft-Übergabe prüfen, Godot-
   Caches nicht als Quellcode behandeln. Sol übernimmt erst nach Review in den
   isolierten Integrationsbranch; kein Merge nach main und keine eigenständige APK.
4. Danach priorisiert: Fassaden-Befund gegen Originalressourcen reproduzieren (Sol);
   auf derselben Revision vollständige Bewegung/Asset/Stimme prüfen; VIVA-Brot in
   weiteren Grafikeinstellungen und auf Gerät sichten; I-01/I-04-Kontakte,
   Figurenplatzierung/Untertitel, tatsächlich fehlende autorisierte Sprachzeilen und
   danach weitere angeschlossene Regionen in getrennten Paketen bearbeiten.

## Reproduktion aus frischem Checkout
Werkzeuge: Godot **4.7.2**, Blender **4.0.2**, Python 3, Node. Unter Linux ohne Bildschirm
braucht die tatsächliche Tischaufnahme einen funktionierenden X11-/Mesa-Displayserver
(z. B. `xvfb-run`); headless allein ergibt kein Renderbild.

```sh
test "$(git remote get-url origin)" = https://github.com/Ullmann27/Imperathen.git
git fetch origin hoplite/kolophon-ac55f0d6--viva-imperium hoplite/kolophon-ac55f0d6--stand-zero
git branch --show-current
export IMPERATHEN_ISOLATED_TEST=1 GODOT_SILENCE_ROOT_WARNING=1
d=$(mktemp -d); export XDG_DATA_HOME="$d/data" XDG_CONFIG_HOME="$d/config" XDG_CACHE_HOME="$d/cache"
g=godot
"$g" --headless --path prototype --import --quit
"$g" --headless --path prototype --fixed-fps 60 --script res://tests/operation_prima_art_test.gd
"$g" --headless --path prototype --fixed-fps 60 --script res://tests/house_interiors_test.gd
node tools/architecture/test_index.mjs && node tools/architecture/build_index.mjs --check
mkdir -p "$d/frames"
xvfb-run -a "$g" --path prototype --rendering-method gl_compatibility --audio-driver Dummy --resolution 960x540 --fixed-fps 60 --script res://tests/operation_prima_table_capture.gd -- --size=960x540 --capture-on-demand --capture-dir="$d/frames"
"$g" --headless --path prototype --script res://tests/tools/export_dialogue_lines.gd -- "$d/authored.json"
python3 tools/audio/audit_german_dialogue.py "$d/authored.json" --report "$d/voice.json"
python3 -c 'import hashlib,json,pathlib; d=json.load(open("docs/44_integration/evidence/viva/breakfast/production-receipt.json")); assert all(hashlib.sha256(pathlib.Path(p).read_bytes()).hexdigest()==x["sha256"] for p,x in d["files"].items()); print("Assets OK")'
```

Optionaler **Neubau**, nicht Voraussetzung zum Öffnen der gesicherten Quelle:
`blender -b -t 2 --python-exit-code 1 -P art/operation_prima/build_breakfast_bread.py -- --studio-dir artifacts/viva-bread-review`.
Er schreibt die Blend- und GLB-Datei neu; ausschließlich auf einem eigenen, verifizierten
Arbeitsbranch ausführen, nicht für die reine Prüfung der Original-Hashes.
