"""Erfasst die räumliche Tagesverteilung direkt aus dem Godot-Simulationskern."""
import argparse
import subprocess
import json
from pathlib import Path

import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
import numpy as np
from matplotlib.collections import LineCollection
from matplotlib.colors import PowerNorm

root = Path(__file__).resolve().parents[2]
parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument("--out", type=Path, required=True)
parser.add_argument("--godot", default="godot")
args = parser.parse_args()
out = args.out.resolve()
out.mkdir(parents=True, exist_ok=True)
revision = subprocess.check_output(["git", "rev-parse", "HEAD"], cwd=root, text=True).strip()
sampler = Path(__file__).with_name("sample_city_distribution.gd").resolve()
subprocess.run([args.godot, "--headless", "--path", str(root / "prototype"), "--script",
                str(sampler), "--", str(out / "Stadtleben.json"), revision], check=True)
world = json.loads((out / "Stadtleben.json").read_text())
graph = json.loads((root / "prototype/assets/city/street_graph.json").read_text())
nodes = np.asarray(graph["nodes"])[:, [0, 2]]
roads = nodes[np.asarray(graph["edges"])]
def cell_boundaries(values, width=40):
    return np.arange(np.floor(values.min()/width)*width,
                     (np.ceil(values.max()/width)+1)*width, width)

east = cell_boundaries(nodes[:, 0])
south = cell_boundaries(nodes[:, 1])
grids = []
for moment in world["samples"]:
    positions = np.asarray(moment["outdoors"]).reshape(-1, 3)
    counts, _, _ = np.histogram2d(positions[:, 1], positions[:, 2], (east, south))
    assert int(counts.sum()) == moment["summary"]["outdoors"]
    grids.append(np.ma.masked_equal(counts.T, 0))
peak = max([1] + [int(grid.max()) for grid in grids if grid.count()])
fig, axes = plt.subplots(1, 3, figsize=(15.4, 5.8), sharey=True)
fig.subplots_adjust(left=.055, right=.91, top=.80, bottom=.20, wspace=.075)
fig.text(.055, .94, "Wo sich die Stadtbewohner aufhalten", weight="bold", fontsize=21, color="#153a3c")
fig.text(.055, .878, f"Erster Kampagnentag · {world['samples'][0]['summary']['residents']:,} persistente Personen · Straßen in Weltkoordinaten".replace(",", "."), fontsize=12, color="#314c50")
for ax, grid, moment in zip(axes, grids, world["samples"]):
    info = moment["summary"]
    ax.set_facecolor("#fbfaf6")
    ax.add_collection(LineCollection(roads, color="#8b9897", linewidth=.17, alpha=.4))
    field = ax.pcolormesh(east, south, grid, cmap="YlOrRd", norm=PowerNorm(.55, vmin=0, vmax=peak), alpha=.82)
    ax.set(xlim=(east[0],east[-1]), ylim=(south[-1],south[0]), aspect="equal", xticks=[-400,-200,0,200,400],yticks=[-300,-150,0,150,300])
    ax.set_title(f'{moment["hour"]:02d}:00 Uhr · {info["outdoors"]} im Freien', fontsize=12, loc="left")
    ax.tick_params(labelsize=8, colors="#46575a")
    ax.set_xlabel("X (m)", fontsize=9)
    for spine in ax.spines.values():
        spine.set_color("#bcc7c5")
axes[0].set_ylabel("Z (m)", fontsize=9)
bar = fig.colorbar(field,cax=fig.add_axes([.930,.291,.009,.42]))
bar.set_label("Personen je 40 × 40 m",fontsize=10)
fig.text(.055,.095,"Godot-Domänensimulation · drei Stichproben derselben Stadt · auch Personen außerhalb des Sichtbereichs der Kamera sind erfasst.",fontsize=10)
fig.text(.055,.05,f"CityLife.position_of und is_indoors · Seed {world['seed']} · Git {world['source_commit'][:10]}",fontsize=9,color="#41565a")
fig.savefig(out/"Stadtleben-im-Tagesverlauf.png",dpi=150,facecolor="white")
