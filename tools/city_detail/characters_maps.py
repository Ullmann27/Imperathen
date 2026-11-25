"""Author deterministic normal/roughness data for existing character materials.

These are original technical surface maps, not generated portraits. All colour,
anatomy, UVs, blend shapes and skeletal data remain in the existing game assets.
"""
from __future__ import annotations
import hashlib
import io
import json
import struct
from pathlib import Path
import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "prototype/assets/city_detail/characters"
SEED = 25112026
SOURCE = ROOT / "prototype/assets/characters/hero_quality_0.glb"

def periodic_smooth(values: np.ndarray, radius: float) -> np.ndarray:
    fy = np.fft.fftfreq(values.shape[0])[:, None]
    fx = np.fft.rfftfreq(values.shape[1])[None, :]
    kernel = np.exp(-2.0 * np.pi**2 * radius**2 * (fx * fx + fy * fy))
    return np.fft.irfft2(np.fft.rfft2(values) * kernel, s=values.shape)

def unit_field(values: np.ndarray) -> np.ndarray:
    return (values - values.mean()) / max(float(values.std()), 1e-8)

def normal_from_height(height: np.ndarray, slope_rms: float) -> np.ndarray:
    # Periodic differences avoid discontinuities at repeating UV borders.
    dx = (np.roll(height, -1, axis=1) - np.roll(height, 1, axis=1)) * 0.5
    dy = (np.roll(height, -1, axis=0) - np.roll(height, 1, axis=0)) * 0.5
    gain = slope_rms / max(float(np.sqrt(np.mean(dx * dx + dy * dy))), 1e-8)
    vectors = np.stack((-dx * gain, dy * gain, np.ones_like(height)), axis=2)
    vectors /= np.linalg.norm(vectors, axis=2, keepdims=True)
    return np.uint8(np.clip(np.rint((vectors * 0.5 + 0.5) * 255), 0, 255))

def source_maps(path: Path) -> tuple[dict, dict]:
    raw = path.read_bytes()
    json_size = struct.unpack_from("<I", raw, 12)[0]
    gltf = json.loads(raw[20:20 + json_size])
    binary = raw[28 + json_size:]
    def texture_image(index):
        view = gltf["bufferViews"][gltf["images"][gltf["textures"][index]["source"]]["bufferView"]]
        start = view.get("byteOffset", 0)
        return Image.open(io.BytesIO(binary[start:start + view["byteLength"]])).convert("RGB")
    maps, records = {}, {}
    for material in gltf["materials"]:
        category = {"HeroSkin": "skin", "FrontierSkin": "skin",
                    "HeroLinen": "linen", "FrontierCloth": "linen"}.get(material["name"])
        if category is None:
            continue
        normal = texture_image(material["normalTexture"]["index"])
        maps[category] = (normal, float(material["normalTexture"].get("scale", 1.0)))
        records[category] = {"normal_pixels_sha256": hashlib.sha256(normal.tobytes()).hexdigest(),
                             "normal_strength": maps[category][1], "size": list(normal.size)}
        if category == "skin":
            pbr = material["pbrMetallicRoughness"]
            roughness = texture_image(pbr["metallicRoughnessTexture"]["index"]).getchannel("G")
            maps["skin_roughness"] = (roughness, float(pbr.get("roughnessFactor", 1.0)))
    return maps, records


def combine_normals(base: Image.Image, base_strength: float, detail: np.ndarray,
                    detail_strength: float) -> np.ndarray:
    # Reoriented Normal Mapping preserves the original tangent-space normal.
    size = (detail.shape[1], detail.shape[0])
    b = np.asarray(base.resize(size, Image.Resampling.BILINEAR), dtype=float) / 255 * 2 - 1
    d = detail.astype(float) / 255 * 2 - 1
    for normal, strength in [(b, base_strength), (d, detail_strength)]:
        normal[:, :, :2] *= strength
        normal[:, :, 2] = np.sqrt(np.maximum(0, 1 - np.sum(normal[:, :, :2] ** 2, axis=2)))
    t = b + np.array([0., 0., 1.])
    u = d * np.array([-1., -1., 1.])
    r = t * (np.sum(t * u, axis=2) / np.maximum(t[:, :, 2], 1e-8))[:, :, None] - u
    r /= np.linalg.norm(r, axis=2, keepdims=True)
    return np.uint8(np.clip(np.rint((r * 0.5 + 0.5) * 255), 0, 255))


def build() -> dict:
    OUT.mkdir(parents=True, exist_ok=True)
    original_maps, original_records = source_maps(SOURCE)
    rng = np.random.default_rng(SEED)
    size = 1024
    noise = rng.normal(size=(size, size))
    pores = unit_field(periodic_smooth(noise, 0.9) - periodic_smooth(noise, 2.0))
    skin = combine_normals(*original_maps["skin"], normal_from_height(pores, 0.16), 0.16)
    rough_source, rough_factor = original_maps["skin_roughness"]
    rough_base = np.asarray(rough_source.resize((size, size), Image.Resampling.BILINEAR), dtype=float) / 255 * rough_factor
    skin_roughness = np.uint8(np.rint(np.clip(
        rough_base + 0.012 * unit_field(periodic_smooth(noise, 8.0)) + 0.004 * pores,
        0.48, 0.82) * 255))
    size = 1024
    y, x = np.mgrid[:size, :size]
    phase_x = 2 * np.pi * x * 256 / size
    phase_y = 2 * np.pi * y * 224 / size
    crossing = np.sin(phase_x * 0.5) * np.sin(phase_y * 0.5)
    weave = np.cos(phase_x) * (0.70 + 0.24 * crossing)
    weave += np.cos(phase_y) * (0.70 - 0.24 * crossing)
    weave += 0.09 * periodic_smooth(rng.normal(size=(size, size)), 0.6)
    linen = combine_normals(*original_maps["linen"], normal_from_height(weave, 0.48), 0.32)
    leather_noise = rng.normal(size=(256, 256))
    leather_raw = normal_from_height(
        periodic_smooth(leather_noise, 1.0) + 0.55 * periodic_smooth(leather_noise, 4.0),
        0.30)
    neutral = Image.new("RGB", (256, 256), (128, 128, 255))
    leather = combine_normals(neutral, 0.0, leather_raw, 0.35)
    # Existing near-tier variants share the authored normal maps. Verify this
    # before reusing a combined map for their separately coloured identities.
    verified_sources = []
    candidates = [SOURCE, SOURCE.with_name("hero_quality_1.glb")]
    candidates += sorted(SOURCE.parent.glob("frontier_*_[01].glb"))
    for path in candidates:
        if not path.exists():
            continue
        _, records = source_maps(path)
        if any(record != original_records[category] for category, record in records.items()):
            raise ValueError("Source normal map changed; requires individual detail authoring: " + str(path))
        verified_sources.append({"path": str(path.relative_to(ROOT)), "sha256": hashlib.sha256(path.read_bytes()).hexdigest()})
    maps = {
        "skin_detail_normal.png": skin,
        "skin_detail_roughness.png": skin_roughness,
        "linen_detail_normal.png": linen,
        "leather_detail_normal.png": leather,
    }
    records = []
    for name, data in maps.items():
        path = OUT / name
        Image.fromarray(data).save(path, optimize=True)
        records.append({"path": str(path.relative_to(ROOT)), "width": data.shape[1],
                        "height": data.shape[0], "bytes": path.stat().st_size,
                        "sha256": hashlib.sha256(path.read_bytes()).hexdigest()})
    manifest = {
        "schema_version": 1,
        "authoring": "Original deterministic mathematical surface data, authored for IMPERATHEN",
        "seed": SEED,
        "verified_source_models": verified_sources,
        "detail_strengths_baked": {"skin": 0.16, "linen": 0.32, "leather": 0.35},
        "normal_convention": "tangent space X+, Y+, Z+; image Y increases downwards",
        "source_colour_images_modified": False,
        "source_glb_sha256": hashlib.sha256(SOURCE.read_bytes()).hexdigest(),
        "source_material_maps": original_records,
        "normal_combination": "Reoriented Normal Mapping of original authored normal and added surface detail; normal scale baked into the combined map",
        "roughness_combination": "Original roughness plus bounded authored variation; no source map discarded",
        "original_mesh_rig_animation_modified": False,
        "normal_and_roughness_colour_space": "linear/non-colour",
        "runtime_scope": "known Hero/Frontier materials; high and very_high, LOD 0/1 only",
        "android_device_validation": False,
        "files": records,
    }
    (OUT / "provenance.json").write_text(json.dumps(manifest, indent=2) + "\n")
    return manifest

if __name__ == "__main__":
    print(json.dumps(build(), indent=2))
