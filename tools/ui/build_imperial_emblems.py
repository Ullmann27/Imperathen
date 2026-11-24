"""Generate the original vector emblems used by the IMPERATHEN intro and main menu.

The legion eagle (aquila) and the gladius are composed procedurally from simple
geometric rules in this file. No external artwork, tracing or reference image is
embedded. Output: two SVG files with gold/steel gradients that Godot imports as
textures. Usage: python3 tools/ui/build_imperial_emblems.py prototype/assets/ui
"""

import argparse
import math
from pathlib import Path

OUTLINE = "#2b1906"


def _fmt(points):
    return " ".join(f"{x:.1f},{y:.1f}" for x, y in points)


def _rotate(point, angle):
    x, y = point
    c, s = math.cos(angle), math.sin(angle)
    return (x * c - y * s, x * s + y * c)


def _feather(base, angle, length, width, curl=0.0, steps=14):
    """Closed outline of a feather with a rounded tip, plus its quill line."""
    left, right, quill = [], [], []
    for index in range(steps + 1):
        t = index / steps
        rise = min(1.0, t / 0.18)
        tip = math.sqrt(max(0.0, 1.0 - ((t - 0.78) / 0.22) ** 2)) if t > 0.78 else 1.0
        half = width * 0.5 * (0.55 + 0.45 * rise) * tip
        bend = curl * t * t * length
        for side, collection in ((-1, left), (1, right)):
            x, y = _rotate((t * length, side * half + bend), angle)
            collection.append((base[0] + x, base[1] + y))
        if t <= 0.86:
            x, y = _rotate((t * length, bend), angle)
            quill.append((base[0] + x, base[1] + y))
    return left + list(reversed(right)), quill


def _mirror(points, axis=500.0):
    return [(2 * axis - x, y) for x, y in points]


def _bezier(p0, p1, p2, p3, t):
    u = 1.0 - t
    return (u ** 3 * p0[0] + 3 * u * u * t * p1[0] + 3 * u * t * t * p2[0] + t ** 3 * p3[0],
            u ** 3 * p0[1] + 3 * u * u * t * p1[1] + 3 * u * t * t * p2[1] + t ** 3 * p3[1])


ARM = ((556.0, 452.0), (640.0, 330.0), (700.0, 170.0), (858.0, 96.0))


def _wing():
    """Raised wing (right side): a fringe of feathers hanging from a lifted arm."""
    shapes = []
    rows = (
        # (count, u_from, length_inner, length_outer, width, offset along normal, fill)
        (12, 0.12, 150, 330, 54, 0.0, "primary"),
        (11, 0.10, 104, 200, 50, -6.0, "covert"),
        (10, 0.08, 66, 116, 44, -10.0, "covert2"),
    )
    for count, u_from, inner, outer, width, _, fill in rows:
        for index in range(count - 1, -1, -1):
            t = index / (count - 1)
            u = u_from + (0.98 - u_from) * t
            base = _bezier(*ARM, u)
            # Inner feathers fall nearly straight down; the outer ones flare out.
            angle = math.radians(104 - 82 * t ** 1.15)
            length = inner + (outer - inner) * math.sin(math.pi * 0.5 * t) ** 0.9
            outline, quill = _feather(base, angle, length, width, 0.06)
            shapes.append((fill, outline, quill))
    band = [_bezier(*ARM, index / 30) for index in range(31)]
    lower = []
    for index in range(30, -1, -1):
        u = index / 30
        x, y = _bezier(*ARM, u)
        thickness = 34 * (1.0 - u) + 12
        lower.append((x - thickness * 0.25, y + thickness))
    shapes.append(("arm", band + lower, []))
    return shapes


def _tail():
    shapes = []
    for index in range(9):
        t = index / 8
        angle = math.radians(90 + (t - 0.5) * 70)
        base = (500 + (t - 0.5) * 50, 650)
        length = 170 - 40 * abs(t - 0.5) * 2
        outline, quill = _feather(base, angle, length, 46)
        shapes.append(("tail", outline, quill))
    return shapes


def _body():
    left = []
    for index in range(25):
        t = index / 24
        y = 400 + 300 * t
        width = 92 * math.sin(math.pi * (0.10 + 0.80 * t)) ** 0.7
        left.append((500 - width, y))
    right = [(1000 - x, y) for x, y in reversed(left)]
    return left + right


HEAD = ("M452,452 C446,404 456,352 480,318 C504,286 548,276 584,292 C604,300 616,312 624,322 "
        "C648,320 672,336 680,362 C686,384 680,404 670,414 C668,398 660,386 646,382 "
        "C632,384 616,384 604,380 C596,396 584,410 568,420 C560,440 552,458 548,470 "
        "L536,452 L524,474 L510,454 L496,478 L484,456 L470,478 Z")
BEAK = ("M624,322 C648,320 672,336 680,362 C686,384 680,404 670,414 C668,398 660,386 646,382 "
        "C632,384 616,384 604,380 C606,366 612,340 624,322 Z")
BROW = "M548,322 C566,306 596,308 616,326"
MOUTH = "M606,364 C622,368 640,368 660,378"


def _chest_scales():
    paths = []
    for row in range(8):
        y = 470 + row * 26
        half = 66 - abs(row - 3.0) * 7
        count = max(2, int(half * 2 / 24))
        shift = 12 if row % 2 else 0
        for index in range(count):
            x = 500 - half + (index + 0.5) * (2 * half / count) + shift * 0.5 - 3
            paths.append(f"M{x - 11:.1f},{y:.1f} Q{x:.1f},{y + 16:.1f} {x + 11:.1f},{y:.1f}")
    return paths


def _fulmen():
    """Stylised thunderbolt (fulmen) on which the eagle stands."""
    spindle = ("M330,786 C380,770 440,768 500,768 C560,768 620,770 670,786 "
               "C620,802 560,804 500,804 C440,804 380,802 330,786 Z")
    bolts = []
    for side in (-1, 1):
        for lift in (-1, 1):
            x0 = 500 + side * 40
            pts = [(x0, 786), (x0 + side * 46, 786 + lift * 26), (x0 + side * 70, 786 + lift * 8),
                   (x0 + side * 118, 786 + lift * 40), (x0 + side * 96, 786 + lift * 12),
                   (x0 + side * 74, 786 + lift * 26), (x0 + side * 50, 786 + lift * 6)]
            bolts.append(pts)
    return spindle, bolts


def _legs():
    paths = []
    for side in (-1, 1):
        x = 500 + side * 40
        paths.append(("url(#goldDeep)", f"M{x - 26},{640} C{x - 30},{690} {x - 20},{720} {x - 12},{744} "
                                        f"L{x + 12},{744} C{x + 20},{720} {x + 30},{690} {x + 26},{640} Z"))
        for claw in (-1.2, 0.0, 1.2):
            cx = x + claw * 13
            paths.append(("url(#goldBright)", f"M{cx - 6:.1f},740 C{cx - 8:.1f},756 {cx + claw * 6 - 2:.1f},770 "
                                              f"{cx + claw * 10:.1f},778 L{cx + claw * 10 + 6:.1f},774 "
                                              f"C{cx + 6:.1f},764 {cx + 7:.1f},752 {cx + 6:.1f},740 Z"))
    return paths


def aquila_svg():
    fills = {
        "primary": "url(#goldDeep)", "covert": "url(#gold)", "covert2": "url(#goldBright)",
        "arm": "url(#goldBright)", "tail": "url(#goldDeep)",
    }
    out = ['<svg xmlns="http://www.w3.org/2000/svg" width="1400" height="760" viewBox="-200 60 1400 760">',
           "<defs>",
           '<linearGradient id="gold" x1="0" y1="0" x2="0" y2="1">'
           '<stop offset="0" stop-color="#fff0b8"/><stop offset="0.45" stop-color="#e2b04f"/>'
           '<stop offset="1" stop-color="#8a5a17"/></linearGradient>',
           '<linearGradient id="goldBright" x1="0" y1="0" x2="1" y2="1">'
           '<stop offset="0" stop-color="#fff7d6"/><stop offset="0.5" stop-color="#f0c766"/>'
           '<stop offset="1" stop-color="#a8721f"/></linearGradient>',
           '<linearGradient id="goldDeep" x1="0" y1="0" x2="0" y2="1">'
           '<stop offset="0" stop-color="#f3d07a"/><stop offset="0.5" stop-color="#c08530"/>'
           '<stop offset="1" stop-color="#5a370b"/></linearGradient>',
           '<radialGradient id="chest" cx="0.42" cy="0.32" r="0.8">'
           '<stop offset="0" stop-color="#fff3c4"/><stop offset="0.55" stop-color="#dba545"/>'
           '<stop offset="1" stop-color="#734810"/></radialGradient>',
           "</defs>",
           f'<g stroke="{OUTLINE}" stroke-width="3.2" stroke-linejoin="round" stroke-linecap="round">']

    def emit(fill, outline, quill, mirror):
        pts = _mirror(outline) if mirror else outline
        out.append(f'<polygon points="{_fmt(pts)}" fill="{fill}"/>')
        if quill:
            q = _mirror(quill) if mirror else quill
            out.append(f'<polyline points="{_fmt(q)}" fill="none" stroke="#6b420c" stroke-width="2" stroke-opacity="0.75"/>')

    for shade, outline, quill in _tail():
        emit(fills[shade], outline, quill, False)
    wing = _wing()
    for mirror in (False, True):
        for shade, outline, quill in wing:
            emit(fills[shade], outline, quill, mirror)
    for fill, path in _legs():
        out.append(f'<path d="{path}" fill="{fill}"/>')
    spindle, bolts = _fulmen()
    for bolt in bolts:
        out.append(f'<polygon points="{_fmt(bolt)}" fill="url(#goldBright)"/>')
    out.append(f'<path d="{spindle}" fill="url(#gold)"/>')
    out.append(f'<polygon points="{_fmt(_body())}" fill="url(#chest)"/>')
    out.append('<g fill="none" stroke="#7a4b10" stroke-width="2.4">')
    out.extend(f'<path d="{path}"/>' for path in _chest_scales())
    out.append("</g>")
    out.append(f'<path d="{HEAD}" fill="url(#goldBright)"/>')
    out.append(f'<path d="{BEAK}" fill="url(#goldDeep)"/>')
    out.append(f'<path d="{MOUTH}" fill="none" stroke-width="2.6"/>')
    out.append(f'<path d="{BROW}" fill="none" stroke-width="5"/>')
    out.append('<ellipse cx="584" cy="338" rx="10" ry="8" fill="#2b1906" stroke="none"/>')
    out.append('<circle cx="587" cy="335" r="2.6" fill="#fff6d0" stroke="none"/>')
    out.append("</g></svg>")
    return "\n".join(out) + "\n"


def gladius_svg():
    """Horizontal gladius (Mainz-type silhouette), tip pointing right, 1200 x 200 canvas."""
    blade = ("M330,70 C560,64 820,76 960,72 C1040,72 1120,90 1190,100 "
             "C1120,110 1040,128 960,128 C820,124 560,136 330,130 Z")
    bevel = ("M330,70 C560,64 820,76 960,72 C1040,72 1120,90 1190,100 "
             "C1100,96 1030,90 960,90 C820,92 560,90 330,92 Z")
    fuller = "M350,97 C600,96 860,97 1040,99 L1040,101 C860,103 600,104 350,103 Z"
    guard = "M300,38 C332,36 346,54 346,72 L346,128 C346,146 332,164 300,162 C312,128 312,72 300,38 Z"
    plate = "M330,58 L346,58 L346,142 L330,142 Z"
    grip = "M160,78 C200,74 260,74 302,80 L302,120 C260,126 200,126 160,122 Z"
    ribs = " ".join(f"M{x},{78} C{x - 4},{92} {x - 4},{108} {x},{122}" for x in (196, 230, 264))
    pommel = "M64,100 C64,58 104,46 140,60 C168,72 172,128 140,140 C104,154 64,142 64,100 Z"
    return "\n".join([
        '<svg xmlns="http://www.w3.org/2000/svg" width="1200" height="200" viewBox="0 0 1200 200">',
        "<defs>",
        '<linearGradient id="steel" x1="0" y1="0" x2="0" y2="1">'
        '<stop offset="0" stop-color="#f7f9fa"/><stop offset="0.46" stop-color="#b4bcc1"/>'
        '<stop offset="0.54" stop-color="#5f686e"/><stop offset="1" stop-color="#c4cacd"/></linearGradient>',
        '<linearGradient id="bronze" x1="0" y1="0" x2="0" y2="1">'
        '<stop offset="0" stop-color="#f3d38c"/><stop offset="0.5" stop-color="#b07a32"/>'
        '<stop offset="1" stop-color="#5b3910"/></linearGradient>',
        '<linearGradient id="ivory" x1="0" y1="0" x2="0" y2="1">'
        '<stop offset="0" stop-color="#f4ead2"/><stop offset="0.55" stop-color="#c9b48a"/>'
        '<stop offset="1" stop-color="#7a6644"/></linearGradient>',
        "</defs>",
        f'<g stroke="{OUTLINE}" stroke-width="3" stroke-linejoin="round">',
        f'<path d="{blade}" fill="url(#steel)"/>',
        f'<path d="{bevel}" fill="#ffffff" fill-opacity="0.28" stroke="none"/>',
        f'<path d="{fuller}" fill="#4d555b" fill-opacity="0.6" stroke="none"/>',
        f'<path d="{grip}" fill="url(#ivory)"/>',
        f'<path d="{ribs}" fill="none" stroke="#5a4a30" stroke-width="2.4"/>',
        f'<path d="{guard}" fill="url(#ivory)"/>',
        f'<path d="{plate}" fill="url(#bronze)"/>',
        f'<path d="{pommel}" fill="url(#ivory)"/>',
        "</g></svg>",
    ]) + "\n"


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("output", type=Path)
    args = parser.parse_args()
    args.output.mkdir(parents=True, exist_ok=True)
    (args.output / "aquila.svg").write_text(aquila_svg(), encoding="utf-8")
    (args.output / "gladius.svg").write_text(gladius_svg(), encoding="utf-8")
    print(f"IMPERATHEN_EMBLEMS_OK: {args.output}")


if __name__ == "__main__":
    main()
