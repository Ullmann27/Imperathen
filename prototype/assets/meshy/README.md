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
