#!/usr/bin/env python3
"""Bundle the repository preview into one offline HTML, without dependencies."""
import base64
from pathlib import Path
import re

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "preview"
OUTPUT = ROOT / "dist/IMPERATHEN_Spielstart.html"


def build():
    html = (SOURCE / "index.html").read_text(encoding="utf-8")
    css = (SOURCE / "styles.css").read_text(encoding="utf-8")
    core = (SOURCE / "core/game.mjs").read_text(encoding="utf-8")
    app = (SOURCE / "app.mjs").read_text(encoding="utf-8")
    import_line = "import { createGameStore } from './core/game.mjs';"
    assert app.count(import_line) == 1, "Preview imports changed: update the explicit bundler."
    core = re.sub(r"^export (?=const |function )", "", core, flags=re.M)
    assert not re.search(r"^\s*(import|export)\s", core, flags=re.M), "Unsupported core module form."
    app = app.replace(import_line, "const { createGameStore } = (() => {\n" + core + "\nreturn { createGameStore };\n})();")
    assert not re.search(r"^\s*(import|export)\s", app, flags=re.M), "Unbundled module import."
    assert "</style" not in css.lower() and "</script" not in app.lower(), "Unsafe inline terminator."
    stylesheet = '<link rel="stylesheet" href="./styles.css">'
    script = '<script type="module" src="./app.mjs"></script>'
    assert html.count(stylesheet) == 1 and html.count(script) == 1, "HTML entry points changed."
    html = html.replace(stylesheet, "<style>\n" + css + "\n</style>")
    html = html.replace(script, '<script>\n"use strict";\n(() => {\n' + app + "\n})();\n</script>")

    def inline_asset(match):
        path = (SOURCE / match.group(2)).resolve()
        assert path.is_relative_to(SOURCE.resolve()) and path.suffix == ".svg", "Unexpected asset path."
        encoded = base64.b64encode(path.read_bytes()).decode("ascii")
        return match.group(1) + '="data:image/svg+xml;base64,' + encoded + '"'

    html = re.sub(r'(src|href)="(\./assets/[^"]+)"', inline_asset, html)
    assert not re.search(r'(?:src|href)="\./', html), "Local dependency remains."
    OUTPUT.parent.mkdir(parents=True, exist_ok=True)
    OUTPUT.write_text(html, encoding="utf-8")
    print(f"Built {OUTPUT.relative_to(ROOT)} ({OUTPUT.stat().st_size:,} bytes), all scripts, styles and SVG assets embedded.")


if __name__ == "__main__":
    build()
