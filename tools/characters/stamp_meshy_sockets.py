"""Add observable local grip frames without changing reviewed GLB mesh bytes.

The existing equipment generator centres every reviewed prop on its physical
grip. This migration makes that frame explicit in the six previously exported
models. A normal Blender rebuild now exports the same named empty itself.
"""
from __future__ import annotations

import hashlib
import json
from pathlib import Path
import struct

ROOT = Path(__file__).resolve().parents[2]
REPORT = ROOT / "docs/20_meshy_assets/equipment-build.json"
SOCKETS = {
    "weap_germanic_hand_axe": "SOCKET_RIGHT_HAND",
    "gear_germanic_round_shield": "SOCKET_LEFT_HAND",
    "gear_roman_signum": "SOCKET_RIGHT_HAND",
}


def digest(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def stamp(source: bytes, socket: str) -> tuple[bytes, dict]:
    if len(source) < 20 or struct.unpack_from("<4sII", source) != (b"glTF", 2, len(source)):
        raise ValueError("Expected a complete glTF 2 binary")
    size, kind = struct.unpack_from("<II", source, 12)
    if kind != 0x4E4F534A or 20 + size > len(source):
        raise ValueError("Missing complete glTF JSON chunk")
    document = json.loads(source[20:20 + size])
    roots = document["scenes"][document.get("scene", 0)]["nodes"]
    if len(roots) != 1:
        raise ValueError("Expected reviewed single equipment root")
    nodes = document["nodes"]
    root = nodes[roots[0]]
    if "mesh" not in root or any(key in root for key in ("matrix", "translation", "rotation", "scale")):
        raise ValueError("Grip-centred equipment root changed; inspect before migration")
    found = [index for index, node in enumerate(nodes) if node.get("name") == socket]
    if found:
        if len(found) != 1 or nodes[found[0]] != {"name": socket} or found[0] not in root.get("children", []):
            raise ValueError("Existing grip marker is not the reviewed local origin")
        return source, {"already_present": True, "binary_payload_sha256": digest(source[20 + size:])}
    root.setdefault("children", []).append(len(nodes))
    nodes.append({"name": socket})
    encoded = json.dumps(document, separators=(",", ":"), ensure_ascii=False).encode("utf-8")
    encoded += b" " * (-len(encoded) % 4)
    payload = source[20 + size:]
    result = struct.pack("<4sIIII", b"glTF", 2, 20 + len(encoded) + len(payload), len(encoded), 0x4E4F534A) + encoded + payload
    return result, {"already_present": False, "binary_payload_sha256": digest(payload)}


def main() -> None:
    registry = json.loads(REPORT.read_text())
    updates, records = [], []
    for entry in registry["equipment"]:
        socket = SOCKETS[entry["stable_id"]]
        for tier in entry["tiers"]:
            path = ROOT / tier["path"]
            source = path.read_bytes()
            if digest(source) != tier["sha256"]:
                raise ValueError("Derivative differs from its provenance report: " + tier["path"])
            result, evidence = stamp(source, socket)
            updates.append((path, result))
            records.append({"path": tier["path"], "socket": socket,
                            "before_sha256": digest(source), "after_sha256": digest(result),
                            "geometry_textures_animation_bytes_unchanged": True, **evidence})
            tier.update(sha256=digest(result), size_bytes=len(result), socket=socket, socket_local_origin=[0, 0, 0])
    for path, result in updates:
        path.write_bytes(result)
    REPORT.write_text(json.dumps(registry, indent=2) + "\n")
    evidence_path = ROOT / "docs/25_team_a/evidence/assets/socket_markers.json"
    evidence_path.parent.mkdir(parents=True, exist_ok=True)
    evidence_path.write_text(json.dumps({"migration": str(Path(__file__).relative_to(ROOT)),
        "source_geometry_modified": False, "new_meshy_generation_submitted": False,
        "records": records}, indent=2) + "\n")
    print(json.dumps({"socket_markers": len(records), "geometry_modified": False}))


if __name__ == "__main__":
    main()
