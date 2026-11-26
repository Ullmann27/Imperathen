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
work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT
if command -v blender >/dev/null && [[ "$(blender --version | head -1)" == "Blender 4.3.2" ]]; then
    engine="$(command -v blender)"
else
    name=blender-4.3.2-linux-x64.tar.xz
    url=https://download.blender.org/release/Blender4.3
    curl --fail --location --retry 3 "$url/$name" -o "$work/$name"
    curl --fail --location --retry 3 "$url/blender-4.3.2.sha256" -o "$work/checksums"
    (cd "$work"; awk -v file="$name" '$2 == file || $2 == "*" file {print}' checksums > selected; test -s selected; sha256sum -c selected)
    tar -xf "$work/$name" -C "$work"
    engine="$work/blender-4.3.2-linux-x64/blender"
fi
"$engine" -b -t 3 --python-exit-code 1 -P art/vegetation/build.py
python3 art/vegetation/import_settings.py
verify
