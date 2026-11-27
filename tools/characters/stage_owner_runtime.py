#!/usr/bin/env python3
"""Stage checksum-verified, rigged owner derivatives into an isolated QA build."""
from __future__ import annotations
import argparse, hashlib, json, struct, tempfile, urllib.request, zipfile
from pathlib import Path
from urllib.parse import urlsplit
import sys
ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "tools/art"))
from inspect_meshy_glb import inspect_glb
FAMILIES = {"sextus":"unit_legacy_blacksmith", "vibius":"unit_legacy_tunic_villager"}
MANIFESTS = ROOT / "docs/20_meshy_assets"
DEST = ROOT / "prototype/assets/meshy/characters"

def digest(data):
    return hashlib.sha256(data).hexdigest()

def main():
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--family", choices=sorted(FAMILIES), default="sextus")
    ap.add_argument("--archive", type=Path, required=True)
    ap.add_argument("--report", type=Path, required=True)
    args = ap.parse_args()
    cfg = json.loads((MANIFESTS / (args.family.upper()+"_RUNTIME_CANDIDATE.json")).read_text())
    if cfg["story_id"] != args.family or cfg["asset"] != FAMILIES[args.family]:
        raise ValueError("Unexpected story model assignment")
    archive = cfg["archive"]
    if not args.archive.exists():
        url = urlsplit(archive["url"])
        if url.scheme != "https" or url.hostname != "d2ol7oe51mr4n9.cloudfront.net":
            raise ValueError("Unapproved derivative archive host")
        with urllib.request.urlopen(archive["url"],timeout=60) as response:
            raw = response.read(archive["bytes"]+1)
        if len(raw) != archive["bytes"] or digest(raw) != archive["sha256"]:
            raise ValueError("Downloaded runtime archive mismatch")
        args.archive.parent.mkdir(parents=True,exist_ok=True)
        args.archive.write_bytes(raw)
    raw = args.archive.read_bytes()
    if len(raw) != archive["bytes"] or digest(raw) != archive["sha256"]:
        raise ValueError("Runtime archive mismatch")
    expected = cfg["files"]
    names = [x["name"] for x in expected]
    if names != [f"{FAMILIES[args.family]}_{i}.glb" for i in range(4)]:
        raise ValueError("Unexpected model family")
    with zipfile.ZipFile(args.archive) as z, tempfile.TemporaryDirectory(prefix="owner-runtime-") as temporary:
        if sorted(z.namelist()) != sorted(names+["validation.json"]) or sum(x.file_size for x in z.infolist()) > 15_000_000:
            raise ValueError("Unexpected archive members or size")
        evidence = json.loads(z.read("validation.json"))
        if evidence["source_sha256"] != cfg["source_sha256"]:
            raise ValueError("Wrong original source")
        payload = []
        for i, row in enumerate(expected):
            data = z.read(row["name"])
            if len(data) != row["bytes"] or digest(data) != row["sha256"]:
                raise ValueError("Derivative mismatch " + row["name"])
            recorded = evidence["files"][i]
            if any(recorded.get(k) != row.get(k) for k in ("name","sha256","bytes","triangles","tested_frames","tear_events")) or recorded["tear_events"] != 0:
                raise ValueError("Missing exact deformation evidence")
            path = Path(temporary)/row["name"]
            path.write_bytes(data)
            audit = inspect_glb(path)
            if not audit["character_rig_gate"] or audit["triangles"] != row["triangles"]:
                raise ValueError("Rigged binary validation failed: " + row["name"])
            length = struct.unpack_from("<I",data,12)[0]
            doc = json.loads(data[20:20+length])
            if len(doc["skins"]) != 1 or len(doc["skins"][0]["joints"]) != cfg["bones"] or set(a["name"] for a in doc["animations"]) != set(cfg["clips"]):
                raise ValueError("Rig and animation contract mismatch")
            payload.append((row["name"],data))
        DEST.mkdir(parents=True,exist_ok=True)
        for name,data in payload:
            target=DEST/name
            if target.exists() and target.read_bytes()!=data:
                raise ValueError("Refusing to replace different runtime derivative")
        for name,data in payload:
            (DEST/name).write_bytes(data)
    # The runtime catalogue is generated only after the actual four GLBs
    # passed their checks. Never advertise missing assets in source control.
    catalog_path = ROOT / "prototype/assets/world/city_catalog.json"
    catalog = json.loads(catalog_path.read_text(encoding="utf-8"))
    family = {"id": "meshy/characters/" + cfg["asset"],
              "name": {"sextus": "Sextus – Schmied", "vibius": "Vibius – Dorfbewohner"}[args.family],
              "category": "models",
              "tiers": [{"level": i, "path": "res://assets/meshy/characters/" + name} for i, name in enumerate(names)]}
    existing = [x for x in catalog["families"] if x["id"] == family["id"]]
    if existing and (len(existing) != 1 or existing[0]["tiers"] != family["tiers"]):
        raise ValueError("Conflicting city catalogue family")
    if not existing:
        catalog["families"].append(family)
    catalog["families"].sort(key=lambda x: (x["category"], x["id"]))
    catalog["family_count"] = len(catalog["families"])
    catalog["binary_count"] = sum(len(x["tiers"]) for x in catalog["families"])
    catalog_path.write_text(json.dumps(catalog, ensure_ascii=False, indent=2)+"\n", encoding="utf-8")
    args.report.parent.mkdir(parents=True,exist_ok=True)
    args.report.write_text(json.dumps({"status":"STAGED_VERIFIED_QA_CANDIDATE","asset":cfg["asset"],"story_id":cfg["story_id"],"files":expected},indent=2)+"\n")
    print("OWNER_"+args.family.upper()+"_RUNTIME_STAGED lods=4 clips=11")

if __name__ == "__main__":
    main()
