import hashlib
import json
from pathlib import Path
import tempfile
import unittest
from reanchor_imported_voice_onsets import reanchor
from voice_contract import VISEMES

def sha(data):
    return hashlib.sha256(data).hexdigest()

class EncodedOnsetContract(unittest.TestCase):
    def fixture(self,root):
        (root/"lines").mkdir()
        (root/"visemes").mkdir()
        audio=b"original Ogg fixture"
        row={"line_id":"A","speaker_id":"julia","text_key":"id","duration_s":1.0,
             "file":"lines/A.ogg","sha256":sha(audio),"visemes":"visemes/A.json",
             "alignment":{"audio_onset_s":.07,"first_phoneme_s":.07,"onset_delta_ms":0}}
        track={"line_id":"A","speaker_id":"julia","text_key":"id","schema_version":1,
               "duration_s":1.0,"audio_onset_s":.07,"first_phoneme_s":.07,
               "visemes":VISEMES,"segments":[[.07,.2,4],[.2,.4,10]],"phonemes":[[.07,.2,"d"],[.2,.4,"a"]]}
        raw=json.dumps(track).encode()
        row["visemes_sha256"]=sha(raw)
        (root/row["file"]).write_bytes(audio)
        (root/row["visemes"]).write_bytes(raw)
        (root/"manifest.json").write_text(json.dumps({"lines":[row]}))
        receipt={k:row[k] for k in ("line_id","speaker_id","sha256","visemes_sha256")}
        staged={"staged":1,"rows":[receipt]}
        measured={"engine":"4.7.2.stable","mix_rate":44100,"method":"Godot imported playback; 10 ms RMS, 5 ms hop, -40 dB",
                  "rows":[{**receipt,"decoded_onset_s":.0648526077,"stream_length_s":1.0}]}
        return staged,measured,raw

    def test_exact_imported_onset_preserves_waveform_and_later_boundaries(self):
        with tempfile.TemporaryDirectory() as work:
            root=Path(work)
            staged,measured,raw=self.fixture(root)
            result=reanchor(root,staged,measured)
            new=json.loads((root/"visemes/A.json").read_bytes())
            self.assertEqual(new["segments"][0][0],measured["rows"][0]["decoded_onset_s"])
            self.assertEqual(new["segments"][1],json.loads(raw)["segments"][1])
            self.assertEqual(new["phonemes"][1],json.loads(raw)["phonemes"][1])
            self.assertEqual(result["reanchored"],1)
            self.assertEqual(sha((root/"lines/A.ogg").read_bytes()),staged["rows"][0]["sha256"])

    def test_large_shift_requires_full_realignment(self):
        with tempfile.TemporaryDirectory() as work:
            root=Path(work)
            staged,measured,raw=self.fixture(root)
            measured["rows"][0]["decoded_onset_s"]=.02
            with self.assertRaises(ValueError):
                reanchor(root,staged,measured)
            self.assertEqual((root/"visemes/A.json").read_bytes(),raw)

    def test_wrong_receipt_cannot_mutate(self):
        with tempfile.TemporaryDirectory() as work:
            root=Path(work)
            staged,measured,raw=self.fixture(root)
            measured["rows"][0]["sha256"]="wrong"
            with self.assertRaises(ValueError):
                reanchor(root,staged,measured)
            self.assertEqual((root/"visemes/A.json").read_bytes(),raw)

if __name__=="__main__":
    unittest.main()
