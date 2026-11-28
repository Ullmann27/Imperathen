"""Check actual APK payload wiring for the recovered voice and workshop systems."""
import hashlib
import importlib.util
import json
from pathlib import Path
import tempfile
import unittest
import zipfile

ROOT = Path(__file__).resolve().parents[1]
SPEC = importlib.util.spec_from_file_location("integrated_payload_validator", ROOT / "tools/validate_android_apk.py")
V = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(V)


class IntegratedPayloadTest(unittest.TestCase):
    def voice(self, change=None):
        with tempfile.TemporaryDirectory() as work:
            root = Path(work)
            source = root / "prototype"
            audio = b"OggS original source"
            track = b'{"segments":[[0,0.2,1]]}'
            text = "Guten Morgen."
            row = {"line_id":"line.A","speaker_id":"julia","text":text,
                   "text_key":hashlib.sha256(text.encode()).hexdigest()[:16],
                   "file":"lines/line.A.ogg","sha256":hashlib.sha256(audio).hexdigest(),
                   "visemes":"visemes/line.A.json","visemes_sha256":hashlib.sha256(track).hexdigest()}
            raw = json.dumps({"language":"de","lines":[row]}).encode()
            manifest = V.VOICE_MANIFEST
            ogg = "assets/audio/voice/lines/line.A.ogg"
            viseme = "assets/audio/voice/visemes/line.A.json"
            target = "assets/.godot/imported/line.A.ogg-test.oggvorbisstr"
            for name,data in ((manifest,raw),(ogg,audio),(viseme,track)):
                dest=source/name
                dest.parent.mkdir(parents=True,exist_ok=True)
                dest.write_bytes(data)
            entries = {"assets/"+manifest:raw, "assets/"+viseme:track,
                       "assets/"+ogg+".import":b'path="res://.godot/imported/line.A.ogg-test.oggvorbisstr"\n',
                       target:b"RSRC imported audio"}
            entries.update({"assets/"+path:b"compiled runtime" for path in V.VOICE_RUNTIME})
            if change:
                change(entries,row,manifest,ogg,viseme,target)
            apk=root/"test.apk"
            with zipfile.ZipFile(apk,"w") as archive:
                for path,data in entries.items():
                    archive.writestr(path,data)
            report={"checks":[]}
            with zipfile.ZipFile(apk) as archive:
                V.inspect_voice_payload(archive,set(archive.namelist()),report,source)
            return report["checks"][0]

    def test_imported_ogg_and_exact_raw_viseme(self):
        row=self.voice()
        self.assertEqual(row["status"],"pass")
        self.assertEqual(row["evidence"]["line_count"],1)
        self.assertEqual(len(row["evidence"]["resources"]),5)
        self.assertTrue(all(x.get("sha256") for x in row["evidence"]["resources"]))

    def test_missing_imported_audio_fails(self):
        self.assertEqual(self.voice(lambda e,r,m,o,v,t:e.pop(t))["status"],"fail")

    def test_changed_viseme_fails(self):
        self.assertEqual(self.voice(lambda e,r,m,o,v,t:e.update({"assets/"+v:b"altered"}))["status"],"fail")

    def test_manifest_not_same_source_fails(self):
        self.assertEqual(self.voice(lambda e,r,m,o,v,t:e.update({"assets/"+m:json.dumps({"language":"de","lines":[r,r]}).encode()}))["status"],"fail")

    def test_missing_runtime_fails(self):
        self.assertEqual(self.voice(lambda e,r,m,o,v,t:e.pop("assets/"+V.VOICE_RUNTIME[0]))["status"],"fail")

    def test_unrelated_old_project_not_activated(self):
        with tempfile.TemporaryDirectory() as work:
            root=Path(work)
            p=root/"old.apk"
            with zipfile.ZipFile(p,"w") as z:
                z.writestr("assets/project.binary",b"ECFG")
            report={"checks":[]}
            with zipfile.ZipFile(p) as z:
                V.inspect_voice_payload(z,set(z.namelist()),report,root/"old")
            self.assertEqual(report["checks"],[])

    def test_workshop_and_native_core_every_resource_required(self):
        for identifier,group in (("world_workshop_content",V.WORLD_WORKSHOP_RESOURCES),
                                 ("native_character_core_content",V.CHARACTER_CORE_RESOURCES)):
            for missing in (None,*group):
                with self.subTest(group=identifier,missing=missing), tempfile.TemporaryDirectory() as work:
                    root=Path(work)
                    source=root/"source"
                    for name in group:
                        path=source/name
                        path.parent.mkdir(parents=True,exist_ok=True)
                        path.write_bytes(b"fixture")
                    p=root/"test.apk"
                    with zipfile.ZipFile(p,"w") as z:
                        z.writestr("assets/project.binary",b"ECFG")
                        for path in set(V.EXPECTED_RESOURCES)|set(group):
                            if path!=missing:
                                z.writestr("assets/"+path,b"fixture")
                    report={"checks":[]}
                    V.inspect_zip(p,report,"arm64-v8a",source)
                    check=next(c for c in report["checks"] if c["id"]==identifier)
                    self.assertEqual(check["status"],"fail" if missing else "pass")
                    if missing:
                        self.assertIn(missing,check["evidence"]["missing_resources"])


if __name__=="__main__":
    unittest.main()
