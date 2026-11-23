# Meshy source assets

`manifest.json` is the authoritative registry for Meshy-generated source
assets intended for IMPERATHEN.

No GLB is considered present merely because its Meshy task succeeded. The
`source/` paths in the manifest are intended destinations. They become
runtime candidates only after the exact binary is downloaded, hashed, validated
and imported into Godot.

Validate the registry:

```sh
python tools/art/validate_meshy_manifest.py
```

See `docs/20_meshy_assets/ASSET_LEDGER.md` and
`docs/20_meshy_assets/INTEGRATION.md`.

## Downloaded GLBs stage

After downloading a canonical GLB from the Meshy card, validate and place it
without renaming by hand:

```sh
python tools/art/stage_meshy_assets.py \\
  --asset weap_roman_gladius_pompeii=/path/to/download.glb
```

The command writes the binary to the path declared by `manifest.json` and
creates/updates `prototype/assets/meshy/lock.json` with SHA-256, byte size,
triangle/vertex counts, material/texture counts and rig/animation gates. It does
**not** set `runtime_ready=true`; Godot visual, socket, collision and Android
acceptance remain separate.

Inspect already staged binaries without copying anything:

```sh
python tools/art/inspect_meshy_glb.py \\
  --report docs/20_meshy_assets/binary-inspection.json
```

Use `--require-all` only when every final Meshy GLB is expected to be present.

## Modular loadouts

`loadouts.json` assembles canonical Stable-IDs without granting inventory or
combat ownership. It currently defines seven presentation templates, including
Roman heavy/light cavalry as separate rider + horse + saddle + weapon + shield
components. Validate them against the asset manifest with:

```sh
python tools/art/validate_meshy_loadouts.py
```

The horse and Galena entries are intentionally allowed to remain untextured
source geometry; neither becomes runtime-ready through the loadout contract.
