"""Independent, data-only IMPERATHEN render inbox; no executable jobs or network."""
import hashlib
import json
from pathlib import Path
import re
import struct

ALLOW = {
    "prototype/assets/characters/frontier_civilian_man_0.glb",
    "prototype/assets/characters/frontier_elder_0.glb",
}
ID = re.compile(r"[a-z0-9][a-z0-9-]{2,79}")
SHA = re.compile(r"[a-f0-9]{40}")
MAX_BYTES = 100_000
MAX_ASSET_BYTES = 32 * 1024 * 1024

def load_job(file):
    raw = Path(file).read_bytes()
    if not 0 < len(raw) <= MAX_BYTES:
        raise ValueError("Invalid job size")
    return validate(json.loads(raw))

def validate(job):
    if type(job) is not dict or set(job) != {"version","project","job_id","source_revision","assets"}:
        raise ValueError("Unexpected job fields")
    if type(job["version"]) is not int or job["version"] != 1 or job["project"] != "IMPERATHEN":
        raise ValueError("Only IMPERATHEN render jobs")
    if not isinstance(job["job_id"],str) or not ID.fullmatch(job["job_id"]):
        raise ValueError("Invalid job id")
    if not isinstance(job["source_revision"],str) or not SHA.fullmatch(job["source_revision"]):
        raise ValueError("Immutable source revision required")
    assets = job["assets"]
    if not isinstance(assets,list) or not 1 <= len(assets) <= 2:
        raise ValueError("One or two reviewed assets per job")
    ids = set()
    for a in assets:
        if type(a) is not dict or set(a) != {"id","label","path","git_blob"}:
            raise ValueError("Unexpected asset fields")
        if not isinstance(a["id"],str) or not ID.fullmatch(a["id"]) or a["id"] in ids:
            raise ValueError("Invalid or duplicate asset id")
        ids.add(a["id"])
        if not isinstance(a["label"],str) or not 1 <= len(a["label"]) <= 80 or not all(c.isalnum() or c in " –-" for c in a["label"]):
            raise ValueError("Invalid label")
        if a["path"] not in ALLOW or not isinstance(a["git_blob"],str) or not SHA.fullmatch(a["git_blob"]):
            raise ValueError("Unreviewed source path or blob")
    return job

def inspect_glb(root, asset):
    root = Path(root).resolve()
    src = (root / asset["path"]).resolve()
    if not src.is_relative_to(root) or not src.is_file() or src.stat().st_size > MAX_ASSET_BYTES:
        raise ValueError("Unsafe or missing asset")
    raw = src.read_bytes()
    git_blob = hashlib.sha1(b"blob " + str(len(raw)).encode() + b"\0" + raw).hexdigest()
    if git_blob != asset["git_blob"]:
        raise ValueError("Source Git blob mismatch")
    if len(raw)<20 or struct.unpack_from("<4sII",raw)!=(b"glTF",2,len(raw)):
        raise ValueError("Invalid GLB header")
    size, tag = struct.unpack_from("<I4s",raw,12)
    if tag != b"JSON" or size<=0 or 20+size>len(raw):
        raise ValueError("Invalid GLB JSON")
    doc = json.loads(raw[20:20+size])
    if not doc.get("skins") or not doc.get("animations") or not doc.get("meshes"):
        raise ValueError("Expected existing skinned and animated character")
    # Only self-contained assets; do not resolve external URIs or fetch files.
    for entry in doc.get("buffers",[]) + doc.get("images",[]):
        if "uri" in entry and not str(entry["uri"]).startswith("data:"):
            raise ValueError("External references are not accepted")
    return src, raw, doc

def digest(path):
    raw = Path(path).read_bytes()
    return {"bytes":len(raw),"sha256":hashlib.sha256(raw).hexdigest()}
