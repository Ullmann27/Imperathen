#!/usr/bin/env python3
"""Stage the already-authored original youth runtime derivatives without credentials."""
from __future__ import annotations
import argparse,hashlib,json,struct,sys,urllib.request,zipfile,tempfile
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
sys.path.insert(0,str(ROOT/'tools/art'))
from inspect_meshy_glb import inspect_glb

def sha(data):return hashlib.sha256(data).hexdigest()

def stage(archive,manifest):
    cfg=json.loads(manifest.read_text(encoding='utf8'))
    expected=[f'prototype/assets/characters/hero_meshy_italia_{i}.glb' for i in range(4)]
    report_path='docs/28_city_sandbox/youth-build.json'
    raw=archive.read_bytes()
    if len(raw)!=cfg['bytes'] or sha(raw)!=cfg['sha256']:
        raise ValueError('Original youth runtime archive checksum/size mismatch')
    with zipfile.ZipFile(archive) as z:
        if len(z.infolist())!=5 or set(z.namelist())!=set(expected+[report_path]):
            raise ValueError('Unexpected original youth archive entries')
        if sum(i.file_size for i in z.infolist())>15_000_000 or z.testzip() is not None:
            raise ValueError('Unsafe or damaged youth archive')
        report=json.loads(z.read(report_path))
        if report['task_id']!=cfg['task_id'] or report['source_sha256']!=cfg['source_sha256'] or report['rig']['bones']!=35 or report.get('sword_mesh_name')!='PracticeBlade':
            raise ValueError('Wrong original Meshy source, rig, or sword contract')
        with tempfile.TemporaryDirectory(prefix='imperathen-youth-validation-') as td:
            payload={}
            for i,entry in enumerate(expected):
                data=z.read(entry)
                if sha(data)!=cfg['lod_sha256'][i] or report['lods'][i]['sha256']!=sha(data):
                    raise ValueError('Original youth LOD hash mismatch '+entry)
                p=Path(td)/Path(entry).name;p.write_bytes(data)
                audit=inspect_glb(p)
                if not audit['static_binary_gate'] or not audit['character_rig_gate']:
                    raise ValueError('Original youth LOD failed GLB gates '+entry)
                n,t=struct.unpack_from('<II',data,12)
                doc=json.loads(data[20:20+n])
                if len(doc['skins'][0]['joints'])!=35 or set(a.get('name') for a in doc['animations'])!=set(cfg['clips']):
                    raise ValueError('Wrong rig/animation inventory '+entry)
                talk=next(a for a in doc['animations'] if a['name']=='talk')
                animated={doc['nodes'][c['target']['node']].get('name') for c in talk['channels']}
                if not {'Jaw','Brow_L','Brow_R','FingerCurl_L','FingerCurl_R','Chest'}.issubset(animated):
                    raise ValueError('Secondary deformation animation missing '+entry)
                payload[entry]=data
            for entry,data in payload.items():
                p=ROOT/entry;p.parent.mkdir(parents=True,exist_ok=True);p.write_bytes(data)
        (ROOT/report_path).write_bytes(z.read(report_path))
    return {'status':'STAGED_VERIFIED_RUNTIME','task_id':cfg['task_id'],'source_sha256':cfg['source_sha256'],'bones':35,'clips':cfg['clips'],'lods':report['lods'],'original_youth_active_in_source':True,'original_private_source_included':False}

def main():
    parser=argparse.ArgumentParser()
    parser.add_argument('--manifest',type=Path,default=ROOT/'docs/28_city_sandbox/original-youth-runtime.json')
    parser.add_argument('--archive',type=Path,required=True)
    parser.add_argument('--report',type=Path,required=True)
    args=parser.parse_args()
    cfg=json.loads(args.manifest.read_text(encoding='utf8'))
    if not args.archive.exists():
        args.archive.parent.mkdir(parents=True,exist_ok=True)
        with urllib.request.urlopen(cfg['url'],timeout=60) as src:
            data=src.read(cfg['bytes']+1)
        if len(data)!=cfg['bytes'] or sha(data)!=cfg['sha256']:
            raise ValueError('Downloaded original runtime archive mismatch')
        args.archive.write_bytes(data)
    result=stage(args.archive,args.manifest)
    args.report.parent.mkdir(parents=True,exist_ok=True)
    args.report.write_text(json.dumps(result,indent=2)+'\n')
    print('IMPERATHEN_ORIGINAL_YOUTH_STAGED bones=35 clips=11 lods=4')

if __name__=='__main__':main()
