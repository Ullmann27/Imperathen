"""Pack authored RGBA character sheets into individually loadable Godot textures."""

from pathlib import Path
from PIL import Image, ImageOps

SOURCE = Path(__file__).resolve().parent / "source"
OUTPUT = SOURCE.parents[2] / "prototype/assets/portraits"
# Boundaries follow the spacing in the original renders, including the equipment.
SHEETS = {
    "legion": ([0, 512, 1024, 1536], [0, 489, 1024],
               ["legionary", "auxiliary_spear", "archer", "centurion", "signifer", "emperor"]),
    "origins": ([0, 320, 680, 1024], [0, 765, 1536],
               ["hero_italia", "hero_germania", "hero_han", "hero_wa", "hero_vistula", "marcus"]),
    "friends": ([0, 348, 690, 1024], [0, 777, 1536],
               ["albrun", "lin", "aki", "mira", "adult_italia", "adult_marcus"]),
}


def pack(subject, name):
    alpha = subject.getchannel("A").point(lambda a: 0 if a < 8 else a)
    subject.putalpha(alpha)
    bounds = alpha.point(lambda a: 255 if a >= 15 else 0).getbbox()
    if not bounds or max(alpha.getextrema()) < 230:
        raise ValueError(f"Missing figure in {name}")
    cropped = ImageOps.expand(subject.crop(bounds), 8, fill=(0, 0, 0, 0))
    cropped.save(OUTPUT / f"{name}.webp", lossless=True, method=5)


def main():
    OUTPUT.mkdir(parents=True, exist_ok=True)
    for sheet, (xs, ys, names) in SHEETS.items():
        with Image.open(SOURCE / f"{sheet}.png") as plate:
            if plate.mode != "RGBA" or plate.size != (xs[-1], ys[-1]):
                raise ValueError(f"Unexpected source format: {sheet}")
            for index, name in enumerate(names):
                row, col = divmod(index, 3)
                solo = SOURCE / f"{name}.png"
                if solo.exists():
                    with Image.open(solo) as figure:
                        pack(figure.convert("RGBA"), name)
                else:
                    pack(plate.crop((xs[col], ys[row], xs[col+1], ys[row+1])), name)


if __name__ == "__main__":
    main()
