"""Real graphical desktop comparison; fail closed on renderer fallback or missing data."""
import argparse,json,pathlib,subprocess,os,hashlib
p=argparse.ArgumentParser()
p.add_argument('--godot',required=True)
p.add_argument('--fixture',required=True,type=pathlib.Path)
p.add_argument('--output',required=True,type=pathlib.Path)
p.add_argument('--seconds',type=float,default=4.0)
args=p.parse_args()
out=args.output.resolve();out.mkdir(parents=True,exist_ok=True)
reports=[]
for method,driver in [('gl_compatibility','opengl3'),('mobile','vulkan')]:
    target=out/method;target.mkdir(exist_ok=True)
    cmd=[args.godot,'--path',str(args.fixture.resolve()),'--rendering-method',method,'--rendering-driver',driver,'--resolution','1280x720','--disable-vsync','--','--renderer='+method,'--seconds='+str(args.seconds),'--out='+str(target)]
    with (target/'run.log').open('w') as log:
        subprocess.run(cmd,stdout=log,stderr=subprocess.STDOUT,check=True,timeout=max(180,int(args.seconds*6+180)))
    report=json.loads((target/'report.json').read_text())
    assert report['status']=='rendered' and report['renderer']==method and report['driver']==driver
    assert len(report['shots'])==5 and all(s['frames']>=2 and s['image_size']==[1280,720] for s in report['shots'])
    for row in report['shots']:
        image=target/(row['shot']+'.png')
        assert hashlib.sha256(image.read_bytes()).hexdigest()==row['png_sha256']
    reports.append(report)
a,b=reports
assert a['sources']==b['sources'] and [s['shot'] for s in a['shots']]==[s['shot'] for s in b['shots']]
assert a['character_material_overrides']==b['character_material_overrides']
comparison={'status':'desktop_render_comparison_complete','scope':'actual desktop rendering, software adapters are NOT phone measurements','visual_review_required':True,'thermal_device_test':None,'adapters':[a['adapter'],b['adapter']],'shots':[]}
for x,y in zip(a['shots'],b['shots']):
    comparison['shots'].append({'shot':x['shot'],'gl_fps':x['mean_fps'],'vulkan_fps':y['mean_fps'],'gl_p95_ms':x['p95_ms'],'vulkan_p95_ms':y['p95_ms']})
(out/'comparison.json').write_text(json.dumps(comparison,indent=2))
print(json.dumps(comparison,indent=2))
