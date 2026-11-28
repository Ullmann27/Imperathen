#!/usr/bin/env python3
"""Anchor staged visemes to the actual imported Ogg playback onset.

Only the first phone boundary is corrected, at most the established 16.7 ms
alignment tolerance. The original waveform, subsequent phoneme boundaries,
speaker, exact text and the candidate receipts are not replaced. Every derived
track is independently tested by the existing unmodified 60 Hz lip-sync gate.
"""
import argparse
import hashlib
import json
import math
from pathlib import Path
from stage_verified_dialogue import AUDIO, safe_path
from voice_contract import track_errors

MAX_CORRECTION = .0167

def digest(data):
    return hashlib.sha256(data).hexdigest()

def load(path):
    return json.loads(path.read_text(encoding="utf-8"))

def encode(value):
    return (json.dumps(value,ensure_ascii=False,indent=2)+"\n").encode("utf-8")

def rows_by_id(rows):
    by_id={row["line_id"]:row for row in rows}
    if len(by_id)!=len(rows):
        raise ValueError("Duplicate receipt identity")
    return by_id

def reanchor(audio, staged, measured):
    original=load(audio/"manifest.json")
    catalogue=rows_by_id(original["lines"])
    receipts=rows_by_id(staged["rows"])
    samples=rows_by_id(measured["rows"])
    if staged["staged"]!=len(receipts) or receipts.keys()!=samples.keys():
        raise ValueError("Incomplete imported audio measurement")
    if measured.get("method")!="Godot imported playback; 10 ms RMS, 5 ms hop, -40 dB" or not str(measured.get("engine","")).startswith("4.7.2") or measured.get("mix_rate",0)<=0:
        raise ValueError("Unaccepted engine measurement")
    changes=[]
    outputs={}
    for lid,receipt in receipts.items():
        row=catalogue[lid]
        sample=samples[lid]
        for field in ("speaker_id","sha256","visemes_sha256"):
            if row[field]!=receipt[field] or row[field]!=sample[field]:
                raise ValueError("Mismatched audio or viseme receipt: "+lid)
        ogg=safe_path(audio,row["file"],"lines",".ogg")
        path=safe_path(audio,row["visemes"],"visemes",".json")
        old=path.read_bytes()
        if digest(ogg.read_bytes())!=row["sha256"] or digest(old)!=row["visemes_sha256"]:
            raise ValueError("Staged source changed: "+lid)
        track=json.loads(old)
        if track_errors(track,row):
            raise ValueError("Original candidate track invalid: "+lid)
        start=track["segments"][0][0]
        onset=sample["decoded_onset_s"]
        if not isinstance(onset,(int,float)) or not math.isfinite(onset) or not 0<=onset<track["segments"][0][1] or track["segments"][0][2]==0:
            raise ValueError("Cannot safely anchor first audible phone: "+lid)
        if abs(start-track["first_phoneme_s"])>.000001 or abs(start-onset)>MAX_CORRECTION or abs(track["audio_onset_s"]-onset)>MAX_CORRECTION:
            raise ValueError("Requires actual phoneme realignment (not an onset correction): "+lid)
        duration=sample["stream_length_s"]
        if not isinstance(duration,(int,float)) or not math.isfinite(duration) or abs(duration-row["duration_s"])>.08:
            raise ValueError("Decoded stream duration mismatch: "+lid)
        if abs(start-onset)<1e-8:
            continue
        track["segments"][0][0]=onset
        if isinstance(track.get("phonemes"),list) and track["phonemes"]:
            if abs(track["phonemes"][0][0]-start)>.000001:
                raise ValueError("Original phoneme/viseme starts disagree: "+lid)
            track["phonemes"][0][0]=onset
        track["audio_onset_s"]=onset
        track["first_phoneme_s"]=onset
        if track_errors(track,row):
            raise ValueError("Derived track invalid: "+lid)
        data=encode(track)
        old_hash=row["visemes_sha256"]
        row["visemes_sha256"]=digest(data)
        row["alignment"].update(audio_onset_s=onset,first_phoneme_s=onset,onset_delta_ms=0.0)
        changes.append({"line_id":lid,"audio_sha256":row["sha256"],"original_visemes_sha256":old_hash,
                        "derived_visemes_sha256":row["visemes_sha256"],"original_onset_s":start,
                        "decoded_onset_s":onset,"correction_ms":(onset-start)*1000})
        outputs[path]=data
    # Validate the entire batch before changing any staged track.
    for path,data in outputs.items():
        tmp=path.with_suffix(".json.tmp")
        tmp.write_bytes(data)
        tmp.replace(path)
    path=audio/"manifest.json"
    tmp=path.with_suffix(".json.tmp")
    tmp.write_bytes(encode(original))
    tmp.replace(path)
    return {"measured":len(receipts),"reanchored":len(changes),"method":measured["method"],
            "mix_rate":measured["mix_rate"],"engine":measured["engine"],"rows":changes,
            "original_recordings_preserved":True}

def main():
    parser=argparse.ArgumentParser()
    parser.add_argument("--staged",type=Path,required=True)
    parser.add_argument("--measured",type=Path,required=True)
    parser.add_argument("--report",type=Path,required=True)
    parser.add_argument("--audio",type=Path,default=AUDIO)
    args=parser.parse_args()
    result=reanchor(args.audio,load(args.staged),load(args.measured))
    args.report.parent.mkdir(parents=True,exist_ok=True)
    args.report.write_bytes(encode(result))
    print("IMPORTED_VOICE_REANCHOR_PASS measured=%d reanchored=%d"%(result["measured"],result["reanchored"]))

if __name__=="__main__":
    main()
