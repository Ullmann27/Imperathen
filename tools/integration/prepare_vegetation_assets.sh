#!/usr/bin/env bash
# Produce the original authored vegetation's missing impostors.
# Run before import, source fingerprints, regressions and Android export.
set -euo pipefail
cd "$(git rev-parse --show-toplevel)"
verify() {
python3 - <<'PY'
import json
from pathlib import Path
root = Path("prototype/assets/vegetation")
assets = json.loads((root / "manifest.json").read_text())["assets"]
missing = []
for name, meta in assets.items():
    if meta["kind"] in ("cards", "vine"):
        continue
    if not meta.get("impostor"):
        missing.append(name + ": missing impostor metadata")
    for mode in ("albedo", "normal"):
        path = root / "textures" / f"impostor_{name}_{mode}.png"
        if not path.is_file() or path.stat().st_size < 100:
            missing.append(str(path))
        else:
            with path.open("rb") as stream:
                if stream.read(8) != b"\x89PNG\r\n\x1a\n":
                    missing.append(str(path) + ": invalid PNG")
if missing:
    print("Unbaked vegetation:", *missing, sep="\n")
    raise SystemExit(1)
print("VEGETATION_IMPOSTORS_PRESENT")
PY
}
if verify; then exit 0; fi
# CI already installs Blender through the trusted Ubuntu package repository.
# Bake from the exact checked-in GLBs instead of re-exporting the geometry or
# downloading a second Blender build from an unreliable external endpoint.
command -v blender >/dev/null
blender -b -t 3 --python-exit-code 1 -P art/vegetation/bake_existing_impostors.py
python3 art/vegetation/import_settings.py
verify
