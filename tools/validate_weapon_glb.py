#!/usr/bin/env python3
"""Inspect real weapon GLB bytes and attachment markers; no engine/FPS claim."""
import argparse
import hashlib
import json
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent / "art"))
from validate_visual_assets import Inspection, read_glb

def inspect(path):
    data = path.read_bytes()
    doc, binary, warnings = read_glb(data)
    result = Inspection(doc, binary, warnings).run()
    markers = [node for node in doc['nodes'] if node.get('name', '').startswith('SOCKET_')]
    if len(markers) != 1 or 'mesh' in markers[0]:
        raise ValueError('Exactly one mesh-free attachment marker is required')
    marker = markers[0]
    hand = marker.get('extras', {}).get('attachment_role')
    expected = {'gladius_lod0': 'right_hand', 'scutum_lod0': 'left_hand'}.get(path.stem)
    if expected is None or hand != expected or marker['name'] != 'SOCKET_' + expected.upper():
        raise ValueError('Weapon attachment marker is missing or has the wrong hand')
    if result['triangles_unique_meshes'] > 12000:
        raise ValueError('Weapon exceeds the explicit 12000-triangle review budget')
    return {'file': path.name, 'status': 'passed', 'bytes': len(data),
            'sha256': hashlib.sha256(data).hexdigest(), 'socket': marker['name'],
            'warnings': warnings, 'pivot_policy': 'hand grip, not ground', **result}

def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("paths", nargs="+", type=Path)
    parser.add_argument("--report", type=Path)
    args = parser.parse_args()
    records = []
    for path in args.paths:
        records.append(inspect(path))
        print(json.dumps(records[-1], ensure_ascii=False))
    if args.report:
        args.report.parent.mkdir(parents=True, exist_ok=True)
        args.report.write_text(json.dumps({'status':'passed', 'assets':records,
            'not_verified':['Godot attachment behavior','Android performance','historical equipment accuracy']},
            ensure_ascii=False,indent=2)+'\n',encoding='utf-8')

if __name__ == "__main__":
    main()
