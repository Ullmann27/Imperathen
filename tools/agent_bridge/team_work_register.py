"""Trusted coordinator's task register. No automatic dispatch or model-written approval."""
import argparse
import json
from pathlib import Path, PurePosixPath
import re
import sys

OWNERS = {"Kimi","Nemotron","DeepSeek","Gemini","ERNIE","SuperVL","GPTOSS","Coordinator","A1","A2","A3","B1","B2","B3","C1","C2","C3"}
STATES = {"queued","reserved","submitted","review_pending","blocked","done"}
ACTIVE = {"reserved","submitted","review_pending"}
SHA = re.compile(r"[0-9a-f]{40}")
ID = re.compile(r"[A-Za-z0-9_-]{1,48}")
RUN = re.compile(r"[0-9]{1,24}")
ROOT = Path(__file__).resolve().parent

def require(x,msg):
    if not x: raise ValueError(msg)

def path_ok(path):
    if not isinstance(path,str) or not re.fullmatch(r"[A-Za-z0-9_/.-]{1,240}",path):
        return False
    p=PurePosixPath(path)
    return not p.is_absolute() and p.as_posix()==path and not any(x.startswith(".") for x in p.parts) and path.startswith(("prototype/","tools/art/","art/","docs/"))

def overlap(a,b):
    return a==b or a.startswith(b+"/") or b.startswith(a+"/")

def validate(data):
    require(data.get("schema")==1 and type(data.get("version")) is int and data["version"]>=1, "Invalid register")
    tasks=data.get("tasks")
    require(isinstance(tasks,list) and len(tasks)<=1000, "Invalid task list")
    ids=set()
    for task in tasks:
        require(isinstance(task,dict) and set(task)=={"id","owner","status","revision","run_id","scope","access","note"}, "Invalid task fields")
        require(isinstance(task["id"],str) and ID.fullmatch(task["id"]) and task["id"] not in ids, "Invalid/duplicate id")
        ids.add(task["id"])
        require(task["owner"] in OWNERS and task["status"] in STATES and task["access"] in ("read","edit"), "Invalid task state")
        require(isinstance(task["revision"],str) and SHA.fullmatch(task["revision"]), "Pinned revision required")
        require(isinstance(task["scope"],list) and 1<=len(task["scope"])<=12 and all(path_ok(p) for p in task["scope"]), "Invalid source scope")
        require(task["run_id"] is None or isinstance(task["run_id"],str) and RUN.fullmatch(task["run_id"]), "Invalid workflow run")
        require(task["status"]!="submitted" or task["run_id"] is not None, "Submitted requires actual run")
        require(isinstance(task["note"],str) and len(task["note"])<=1500, "Invalid note")
    edits=[t for t in tasks if t["status"] in ACTIVE and t["access"]=="edit"]
    for i,a in enumerate(edits):
        for b in edits[i+1:]:
            require(not any(overlap(x,y) for x in a["scope"] for y in b["scope"]), "Overlapping active edit leases")
    for owner in ("Kimi","DeepSeek","Gemini","ERNIE","SuperVL","GPTOSS"):
        require(sum(t["owner"]==owner and t["status"] in ("reserved","submitted") for t in tasks)<=1,"Only one active "+owner+" submission")
    return data

def update(data,event):
    validate(data)
    require(event.get("expected_version")==data["version"],"Stale register version")
    task=event.get("task")
    require(isinstance(task,dict),"Task required")
    old=next((x for x in data["tasks"] if x["id"]==task.get("id")),None)
    if old is None:
        require(task.get("status") in ("queued","reserved"),"New task must be queued or reserved")
        items=data["tasks"]+[task]
    else:
        transitions={"queued":{"reserved","blocked"},"reserved":{"submitted","blocked"},
          "submitted":{"review_pending","blocked"},"review_pending":{"done","blocked"},
          "blocked":{"queued"},"done":set()}
        require(task.get("status") in transitions[old["status"]],"Invalid status transition")
        require(all(task.get(k)==old[k] for k in ("id","owner","revision","scope","access")),"Immutable task ownership/scope")
        if old["run_id"] and task.get("status")!="queued":
            require(task.get("run_id")==old["run_id"],"Cannot replace actual run ID")
        items=[task if x["id"]==task["id"] else x for x in data["tasks"]]
    return validate({"schema":1,"version":data["version"]+1,"tasks":items})

def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument("command",choices=["show","record"])
    parser.add_argument("--register",type=Path,default=ROOT/"team_work_register.json")
    parser.add_argument("--event",type=Path)
    args=parser.parse_args()
    try:
        data=validate(json.loads(args.register.read_text(encoding="utf-8")))
        if args.command=="record":
            require(args.event is not None,"Trusted event required")
            data=update(data,json.loads(args.event.read_text(encoding="utf-8")))
            tmp=args.register.with_suffix(".tmp")
            tmp.write_text(json.dumps(data,ensure_ascii=False,indent=2)+"\n",encoding="utf-8")
            tmp.replace(args.register)
        print(json.dumps(data,ensure_ascii=False,indent=2))
        return 0
    except (OSError,ValueError,KeyError,TypeError,AttributeError) as e:
        print("REGISTER_BLOCKED",str(e),file=sys.stderr)
        return 1
if __name__=="__main__":
    raise SystemExit(main())
