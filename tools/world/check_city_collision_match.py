#!/usr/bin/env python3
"""Compare what the exported Roman city shows with what it lets a body touch.

Reads the exact exported GLB bytes (visual city and collision city), samples
both surfaces in the height band a 1.5 m person occupies and reports

* visible geometry without a collider nearby (a person walks through it), and
* collider geometry without visible geometry nearby (an invisible wall).

Only sides count (faces a body cannot stand on), between 0.25 m (the step
limit) and 1.5 m (head height) above the object's ground:

* visible sides are reduced to 0.15 m voxels; each needs a collider face in the
  same or an adjacent voxel, or a closed collider around it (goods on a
  counter inside the counter's box);
* collider sides are reduced to 0.15 m plan cells, because a collider side
  stops the whole standing body; each needs something visible in the same or
  an adjacent column (a table top above an open underside counts).

Thin trim on a solid wall matches the wall's collider. A counter, column or
trunk without a collider, and a collider wider than what is drawn, do not.

Pure NumPy, no Blender and no engine: it runs on the files that are packaged.
"""
from __future__ import annotations

import argparse
import json
import struct
import sys
from collections import defaultdict
from pathlib import Path

import numpy as np

BAND = (0.25, 1.50)   # metres above the object's ground: from the 0.25 m step limit up to head height
SPACING = 0.10        # surface sample spacing
CELL = 0.15           # voxel size of the proximity test
BATCH_POINTS = 1_500_000
MAX_EDGE = 6.0
COMPONENT = {5120: np.int8, 5121: np.uint8, 5122: np.int16, 5123: np.uint16, 5125: np.uint32, 5126: np.float32}
WIDTH = {"SCALAR": 1, "VEC2": 2, "VEC3": 3, "VEC4": 4}
# An object may leave this share of its cells unmatched (handles, brackets,
# overhanging trim) before it counts as a mismatch.
ALLOWED_UNMATCHED_SHARE = 0.02
ALLOWED_UNMATCHED_SAMPLES = 8


class Glb:
    def __init__(self, path: Path):
        data = path.read_bytes()
        if data[:4] != b"glTF":
            raise ValueError(f"{path} is not a binary glTF file")
        length = struct.unpack_from("<I", data, 12)[0]
        self.json = json.loads(data[20:20 + length])
        self.bin = memoryview(data)[20 + length + 8:]
        self._triangles: dict[int, np.ndarray] = {}
        self.parents = {}
        for index, node in enumerate(self.json["nodes"]):
            for child in node.get("children", []):
                self.parents[child] = index

    def accessor(self, index: int) -> np.ndarray:
        acc = self.json["accessors"][index]
        view = self.json["bufferViews"][acc["bufferView"]]
        dtype = np.dtype(COMPONENT[acc["componentType"]])
        width = WIDTH[acc["type"]]
        offset = view.get("byteOffset", 0) + acc.get("byteOffset", 0)
        stride = view.get("byteStride", 0)
        if stride and stride != dtype.itemsize * width:
            raw = np.frombuffer(self.bin, np.uint8, stride * acc["count"], offset).reshape(acc["count"], stride)
            return raw[:, :dtype.itemsize * width].copy().view(dtype).reshape(acc["count"], width)
        return np.frombuffer(self.bin, dtype, acc["count"] * width, offset).reshape(acc["count"], width)

    def triangles(self, mesh: int) -> np.ndarray:
        """(n, 3, 3) float64 triangle corners of a mesh in its local space."""
        if mesh not in self._triangles:
            parts = []
            for primitive in self.json["meshes"][mesh]["primitives"]:
                if primitive.get("mode", 4) != 4:
                    continue
                points = self.accessor(primitive["attributes"]["POSITION"]).astype(np.float64)
                if "indices" in primitive:
                    indices = self.accessor(primitive["indices"]).astype(np.int64).reshape(-1, 3)
                else:
                    indices = np.arange(len(points)).reshape(-1, 3)
                parts.append(points[indices])
            self._triangles[mesh] = np.concatenate(parts) if parts else np.zeros((0, 3, 3))
        return self._triangles[mesh]

    def local_matrix(self, index: int) -> np.ndarray:
        node = self.json["nodes"][index]
        if "matrix" in node:
            return np.array(node["matrix"], float).reshape(4, 4).T
        x, y, z, w = node.get("rotation", [0, 0, 0, 1])
        rotation = np.array([[1 - 2 * (y * y + z * z), 2 * (x * y - z * w), 2 * (x * z + y * w)],
                             [2 * (x * y + z * w), 1 - 2 * (x * x + z * z), 2 * (y * z - x * w)],
                             [2 * (x * z - y * w), 2 * (y * z + x * w), 1 - 2 * (x * x + y * y)]])
        matrix = np.eye(4)
        matrix[:3, :3] = rotation * np.array(node.get("scale", [1, 1, 1]), float)
        matrix[:3, 3] = node.get("translation", [0, 0, 0])
        return matrix

    def world_matrix(self, index: int) -> np.ndarray:
        matrix = self.local_matrix(index)
        while index in self.parents:
            index = self.parents[index]
            matrix = self.local_matrix(index) @ matrix
        return matrix

    def world_triangles(self, index: int) -> np.ndarray:
        node = self.json["nodes"][index]
        if "mesh" not in node:
            return np.zeros((0, 3, 3))
        matrix = self.world_matrix(index)
        return self.triangles(node["mesh"]) @ matrix[:3, :3].T + matrix[:3, 3]

    def subtree(self, index: int) -> list[int]:
        found, todo = [], [index]
        while todo:
            current = todo.pop()
            found.append(current)
            todo.extend(self.json["nodes"][current].get("children", []))
        return found


def steep(triangles: np.ndarray) -> np.ndarray:
    """Triangles a body cannot stand on: walls and sides, not floors, treads or table tops."""
    if len(triangles) == 0:
        return triangles
    normal = np.cross(triangles[:, 1] - triangles[:, 0], triangles[:, 2] - triangles[:, 0])
    length = np.linalg.norm(normal, axis=1)
    return triangles[(length > 1e-12) & (np.abs(normal[:, 1]) < 0.7 * np.maximum(length, 1e-12))]


def sample(triangles: np.ndarray, low: float, high: float, spacing: float = SPACING):
    """Yield batches of surface points (glTF Y up) with low <= y <= high."""
    if len(triangles) == 0:
        return
    heights = triangles[:, :, 1]
    triangles = triangles[(heights.max(1) >= low) & (heights.min(1) <= high)]
    if len(triangles) == 0:
        return
    # Long slivers (an 815 m kerb) are bisected first so that only the pieces
    # inside the band are sampled.
    while True:
        edges = np.stack([((triangles[:, k] - triangles[:, (k + 1) % 3]) ** 2).sum(1) for k in range(3)], 1)
        big = edges.max(1) > MAX_EDGE ** 2
        if not big.any():
            break
        large, k = triangles[big], edges[big].argmax(1)
        rows = np.arange(len(large))
        p, q, r = large[rows, k], large[rows, (k + 1) % 3], large[rows, (k + 2) % 3]
        middle = (p + q) * 0.5
        halves = np.concatenate([np.stack([p, middle, r], 1), np.stack([middle, q, r], 1)])
        heights = halves[:, :, 1]
        halves = halves[(heights.max(1) >= low) & (heights.min(1) <= high)]
        triangles = np.concatenate([triangles[~big], halves])
    if len(triangles) == 0:
        return
    a, b, c = triangles[:, 0], triangles[:, 1], triangles[:, 2]
    longest = np.sqrt(np.maximum.reduce([((a - b) ** 2).sum(1), ((b - c) ** 2).sum(1), ((c - a) ** 2).sum(1)]))
    steps = np.maximum(1, np.ceil(longest / spacing).astype(int))
    for n in np.unique(steps):
        chosen = np.flatnonzero(steps == n)
        i, j = np.meshgrid(np.arange(n + 1), np.arange(n + 1), indexing="ij")
        keep = i + j <= n
        u, v = i[keep] / n, j[keep] / n
        w = 1.0 - u - v
        batch = max(1, BATCH_POINTS // len(u))
        for start in range(0, len(chosen), batch):
            part = chosen[start:start + batch]
            points = (a[part][:, None, :] * w[None, :, None] + b[part][:, None, :] * u[None, :, None]
                      + c[part][:, None, :] * v[None, :, None]).reshape(-1, 3)
            points = points[(points[:, 1] >= low) & (points[:, 1] <= high)]
            if len(points):
                yield points


def _keys(cells: np.ndarray) -> np.ndarray:
    cells = cells.astype(np.int64) + (1 << 20)
    key = cells[:, 0]
    for axis in range(1, cells.shape[1]):
        key = (key << 21) | cells[:, axis]
    return key


def cells(triangles: np.ndarray, low: float, high: float, axes=(0, 1, 2), cell: float = CELL) -> np.ndarray:
    """Sorted unique cells the surface occupies between low and high.

    axes (0, 1, 2) gives voxels, axes (0, 2) plan cells (vertical columns)."""
    found = [np.zeros(0, np.int64)]
    for points in sample(triangles, low, high):
        found.append(np.unique(_keys(np.floor(points[:, list(axes)] / cell).astype(np.int64))))
        if len(found) > 16:
            found = [np.unique(np.concatenate(found))]
    return np.unique(np.concatenate(found))


def unmatched(own: np.ndarray, other: np.ndarray, dimensions: int) -> np.ndarray:
    """Mask of cells in `own` without an `other` cell in the same or an adjacent cell."""
    if len(own) == 0:
        return np.zeros(0, bool)
    if len(other) == 0:
        return np.ones(len(own), bool)
    near = np.zeros(len(own), bool)
    for offset in np.ndindex(*([3] * dimensions)):
        shift = 0
        for step in offset:
            shift = (shift << 21) + (step - 1)
        near |= np.isin(own + shift, other)
    return ~near


def _centres(keys: np.ndarray, dimensions: int, cell: float = CELL) -> np.ndarray:
    mask = (1 << 21) - 1
    parts = np.stack([(keys >> (21 * (dimensions - 1 - axis))) & mask for axis in range(dimensions)], 1)
    return (parts - (1 << 20) + 0.5) * cell


def inside(points: np.ndarray, triangles: np.ndarray) -> np.ndarray:
    """Mask of points enclosed by the triangle surface (vertical ray parity)."""
    result = np.zeros(len(points), bool)
    if len(points) == 0 or len(triangles) == 0:
        return result
    # A tiny shift keeps the rays off shared edges and vertices.
    points = points + np.array([0.000731, 0.0, 0.000419])
    a, b, c = triangles[:, 0], triangles[:, 1], triangles[:, 2]
    e1x, e1z = (b - a)[:, 0], (b - a)[:, 2]
    e2x, e2z = (c - a)[:, 0], (c - a)[:, 2]
    det = e1x * e2z - e1z * e2x
    usable = np.abs(det) > 1e-12            # vertical triangles never cross a vertical ray
    a, b, c, e1x, e1z, e2x, e2z, det = (v[usable] for v in (a, b, c, e1x, e1z, e2x, e2z, det))
    if len(a) == 0:
        return result
    step = max(1, 2_000_000 // len(a))
    for start in range(0, len(points), step):
        part = points[start:start + step]
        dx = part[:, None, 0] - a[None, :, 0]
        dz = part[:, None, 2] - a[None, :, 2]
        u = (dx * e2z[None] - dz * e2x[None]) / det[None]
        v = (dz * e1x[None] - dx * e1z[None]) / det[None]
        hit = (u >= 0) & (v >= 0) & (u + v <= 1)
        height = a[None, :, 1] + u * (b - a)[None, :, 1] + v * (c - a)[None, :, 1]
        result[start:start + step] = ((hit & (height > part[:, None, 1])).sum(1) % 2) == 1
    return result


def _compare(visual: np.ndarray, collision: np.ndarray, ground: float) -> dict:
    """Walk-through: 0.15 m voxels of visible walls/sides; invisible: plan cells of collider sides."""
    low, high = ground + BAND[0], ground + BAND[1]
    # 1. Visible sides in body height need a collider next to them (any
    #    collider face, one voxel above the band included) or around them.
    seen = cells(steep(visual), low, high)
    walk_through = unmatched(seen, cells(collision, low, high + CELL), 3)
    if walk_through.any() and len(collision):
        open_cells = np.flatnonzero(walk_through)
        walk_through[open_cells[inside(_centres(seen[open_cells], 3), collision)]] = False
    # 2. A collider side blocks a whole standing body, so it needs something
    #    visible in its vertical column (a table top over an empty underside counts).
    solid = cells(steep(collision), low, high, (0, 2))
    invisible = unmatched(solid, cells(visual, low, high, (0, 2)), 2)
    result = {"visible_samples": int(len(seen)), "walk_through_samples": int(walk_through.sum()),
              "collider_samples": int(len(solid)), "invisible_collider_samples": int(invisible.sum())}
    if walk_through.any():
        at = _centres(seen[walk_through][:1], 3)[0]
        result["walk_through_at"] = [round(float(at[0]), 2), round(float(at[2]), 2)]
    if invisible.any():
        at = _centres(solid[invisible][:1], 2)[0]
        result["invisible_at"] = [round(float(at[0]), 2), round(float(at[1]), 2)]
    return result


def _bad(count: int, total: int) -> bool:
    return count > max(ALLOWED_UNMATCHED_SAMPLES, ALLOWED_UNMATCHED_SHARE * total)


def audit(city_path: Path, collision_path: Path) -> dict:
    city, collision = Glb(city_path), Glb(collision_path)
    colliders = {node["name"]: index for index, node in enumerate(collision.json["nodes"]) if "mesh" in node}
    used = set()
    objects = []
    cache: dict[tuple, dict] = {}
    roots = city.json["scenes"][city.json.get("scene", 0)]["nodes"]
    for index in roots:
        node = city.json["nodes"][index]
        name = node.get("name", "node%d" % index)
        members = [i for i in city.subtree(index) if "mesh" in city.json["nodes"][i]]
        if not members:
            continue
        category = node.get("extras", {}).get("category") or city.json["nodes"][members[0]].get("extras", {}).get("category", "")
        collider = colliders.get(name + "_collision")
        if collider is not None:
            used.add(collider)
        world = city.world_matrix(index)
        ground = float(world[1, 3]) if "mesh" in node else 0.0
        key = None
        if "mesh" in node and len(members) == 1:
            # Instances of one prototype differ only by a rigid transform.
            scale = tuple(round(float(v), 5) for v in np.linalg.norm(world[:3, :3], axis=0))
            collider_mesh = collision.json["nodes"][collider]["mesh"] if collider is not None else -1
            key = (node["mesh"], collider_mesh, scale)
        if key is not None and key in cache:
            measured = dict(cache[key])
            for field in ("walk_through_at", "invisible_at"):
                measured.pop(field, None)
        else:
            if key is not None:
                # Compare in an upright frame at the origin: scale only.
                scale = np.array(key[2])
                visual = city.triangles(node["mesh"]) * scale
                solid = collision.triangles(key[1]) * scale if collider is not None else np.zeros((0, 3, 3))
                measured = _compare(visual, solid, 0.0)
                rotation = world[:3, :3] / scale
                for field in ("walk_through_at", "invisible_at"):
                    if field in measured:
                        local = np.array([measured[field][0], 0.0, measured[field][1]])
                        at = rotation @ local + world[:3, 3]
                        measured[field] = [round(float(at[0]), 2), round(float(at[2]), 2)]
                cache[key] = measured
            else:
                visual = np.concatenate([city.world_triangles(i) for i in members])
                solid = collision.world_triangles(collider) if collider is not None else np.zeros((0, 3, 3))
                measured = _compare(visual, solid, ground)
        measured.update({"name": name, "category": category, "has_collider": collider is not None})
        objects.append(measured)
    orphans = sorted(name for name, index in colliders.items() if index not in used)
    by_category: dict[str, dict] = defaultdict(lambda: {"objects": 0, "objects_walk_through": 0, "objects_invisible_collider": 0,
                                                        "visible_samples": 0, "walk_through_samples": 0,
                                                        "collider_samples": 0, "invisible_collider_samples": 0})
    failures = []
    for item in objects:
        entry = by_category[item["category"] or "uncategorised"]
        entry["objects"] += 1
        for field in ("visible_samples", "walk_through_samples", "collider_samples", "invisible_collider_samples"):
            entry[field] += item[field]
        if _bad(item["walk_through_samples"], item["visible_samples"]):
            entry["objects_walk_through"] += 1
            failures.append({"name": item["name"], "category": item["category"], "problem": "walk_through",
                             "samples": item["walk_through_samples"], "of": item["visible_samples"],
                             "at_gltf_xz_m": item.get("walk_through_at")})
        if _bad(item["invisible_collider_samples"], item["collider_samples"]):
            entry["objects_invisible_collider"] += 1
            failures.append({"name": item["name"], "category": item["category"], "problem": "invisible_collider",
                             "samples": item["invisible_collider_samples"], "of": item["collider_samples"],
                             "at_gltf_xz_m": item.get("invisible_at")})
    return {"schema_version": 1, "band_m": list(BAND), "sample_spacing_m": SPACING, "cell_m": CELL,
            "allowed_unmatched_share": ALLOWED_UNMATCHED_SHARE, "allowed_unmatched_samples": ALLOWED_UNMATCHED_SAMPLES,
            "objects": len(objects), "colliders": len(colliders), "colliders_without_visual_object": orphans,
            "categories": dict(sorted(by_category.items())), "failure_count": len(failures) + len(orphans),
            "failures": failures, "passed": not failures and not orphans}


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    parser.add_argument("--city", type=Path, default=Path("prototype/assets/world/roman_city_test.glb"))
    parser.add_argument("--collision", type=Path, default=Path("prototype/assets/world/roman_city_collision.glb"))
    parser.add_argument("--output", type=Path)
    args = parser.parse_args()
    report = audit(args.city, args.collision)
    text = json.dumps(report, indent=1)
    if args.output:
        args.output.parent.mkdir(parents=True, exist_ok=True)
        args.output.write_text(text + "\n")
    summary = {k: v for k, v in report.items() if k != "failures"}
    summary["failures"] = report["failures"][:25]
    print(json.dumps(summary, indent=1))
    print("CITY_COLLISION_MATCH_PASS" if report["passed"] else "CITY_COLLISION_MATCH_FAIL")
    return 0 if report["passed"] else 1


if __name__ == "__main__":
    sys.exit(main())
