"""Check the Legio campaign data and imported figures in a built Android APK."""

import argparse
import hashlib
import json
from pathlib import Path
from zipfile import ZipFile

from test_city_qa_payload import outfit_payload
from validate_android_apk import resolve_resource


ROOT = Path(__file__).resolve().parents[1]
SCENES = {
    'assets/legio': 16,
    'assets/germanic_warriors': 9,
    'assets/world/waystation': 8,
}
CORE = (
    'scripts/domain/travel_party.gd', 'scripts/domain/campaign_allegiance.gd',
    'scripts/domain/party_conversations.gd', 'scripts/domain/regional_freight.gd',
    'scripts/domain/city_watch.gd', 'scripts/world/city_watch_patrol.gd',
    'scripts/strategy/atlas_data.gd', 'scripts/story/mission_documents.gd',
    'scripts/ui/party_panel.gd', 'scripts/ui/party_portrait.gd', 'scripts/visuals/party_gear.gd',
    'scripts/world/companion_world.gd', 'scripts/world/city_party_visit.gd',
    'scripts/world/regional_footpath.gd', 'scripts/world/regional_waystation.gd',
    'scripts/world/village/mission_route.gd', 'scripts/battle/valley_muster.gd',
    'assets/viva_roma/props/helmet_lod1.glb', 'assets/world/roman_city_manifest.json',
    'assets/world/roman_city_test.glb', 'assets/world/roman_city_collision.glb',
    'assets/world/waystation/valdora_walk_grid.json', 'assets/troops/troops.json',
    'assets/troops/people.json', 'assets/story/mission_timeline.json',
)


def check(apk: Path, source: Path) -> dict:
    resources = list(CORE)
    missions = ['index', *(f'I-{n:02}' for n in range(1, 15))]
    resources.extend(f'assets/story/missions/band1/{name}.json' for name in missions)
    for folder, minimum in SCENES.items():
        scenes = sorted((source / folder).glob('*.glb'))
        if len(scenes) < minimum:
            raise ValueError(f'Incomplete source geometry in {folder}: {len(scenes)}')
        resources.extend(path.relative_to(source).as_posix() for path in scenes)
    entries = {}
    json_digests = {}
    with ZipFile(apk) as archive:
        names = set(archive.namelist())
        if 'assets/project.binary' not in names or any(p.startswith('assets/tests/') for p in names):
            raise ValueError('The package must contain the runtime project and exclude test fixtures.')
        outfits = [item['source'] for item in outfit_payload(archive)]
        for relative in resources:
            resource = resolve_resource(archive, names, relative)
            target = resource['entry']
            if not target:
                raise ValueError(f'Missing game content: {relative}')
            if relative.endswith('.glb') and (resource['mode'] != 'remapped' or not target.endswith('.scn')):
                raise ValueError(f'Missing imported 3D scene: {relative}')
            if relative.endswith('.json'):
                data = archive.read(target)
                json.loads(data)
                if data != (source / relative).read_bytes():
                    raise ValueError(f'Changed campaign data in package: {relative}')
                json_digests[relative] = hashlib.sha256(data).hexdigest()
            entries[relative] = target
    return {'resources': entries, 'json_sha256': json_digests, 'outfits': outfits}


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('apk', type=Path)
    parser.add_argument('--source', type=Path, default=ROOT / 'prototype', help='Project used for the exported package')
    args = parser.parse_args()
    print(json.dumps(check(args.apk, args.source), ensure_ascii=False, indent=2))
