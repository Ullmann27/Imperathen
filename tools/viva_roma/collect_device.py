"""Collect only physical-device benchmark thermal/memory evidence, no install or settings changes."""
import argparse,datetime,json,pathlib,subprocess,time
p=argparse.ArgumentParser()
p.add_argument('--serial',required=True)
p.add_argument('--package',default='at.heinz.imperathen.vivaqa')
p.add_argument('--output',required=True,type=pathlib.Path)
p.add_argument('--seconds',type=int,default=1200)
p.add_argument('--interval',type=int,default=30)
a=p.parse_args()
if a.seconds<60 or a.interval<10 or a.interval>a.seconds: raise SystemExit('Invalid interval/duration')
def adb(*args):
    result=subprocess.run(['adb','-s',a.serial,*args],capture_output=True,text=True,timeout=20)
    return {'ok':result.returncode==0,'text':result.stdout.strip(),'error':result.stderr.strip()}
if adb('shell','getprop','ro.kernel.qemu')['text']=='1': raise SystemExit('Emulator rejected: physical device required')
if not adb('shell','pm','path',a.package)['text'].startswith('package:'): raise SystemExit('Dedicated QA package not installed')
a.output.parent.mkdir(parents=True,exist_ok=True)
start=time.monotonic()
with a.output.open('x') as f:
    f.write(json.dumps({'event':'device','model':adb('shell','getprop','ro.product.model')['text'],'android':adb('shell','getprop','ro.build.version.release')['text'],'scope':'physical device evidence; battery temperature is not SoC temperature'})+'\n')
    while time.monotonic()-start<a.seconds:
        pid=adb('shell','pidof',a.package)
        if not pid['ok'] or not pid['text']: raise SystemExit('QA process not running; incomplete trace')
        batt=adb('shell','dumpsys','battery')
        temp=next((line.strip() for line in batt['text'].splitlines() if line.strip().startswith('temperature:')),None)
        row={'event':'sample','utc':datetime.datetime.now(datetime.timezone.utc).isoformat(),'elapsed_s':round(time.monotonic()-start,3),'battery_temp_decic':int(temp.split(':')[1]) if temp else None,
            'thermalservice':adb('shell','dumpsys','thermalservice'),'memory':adb('shell','dumpsys','meminfo',a.package)}
        f.write(json.dumps(row)+'\n');f.flush()
        time.sleep(min(a.interval,max(0,a.seconds-(time.monotonic()-start))))
    f.write(json.dumps({'event':'complete','elapsed_s':round(time.monotonic()-start,3)})+'\n')
