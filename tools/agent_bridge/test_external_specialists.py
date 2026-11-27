import io
import json
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch
from urllib.error import HTTPError
import external_specialists as s
import team_work_register as ledger

class SpecialistTests(unittest.TestCase):
    def setUp(self):
        self.task={"id":"O001","owner":"GPTOSS","revision":"a"*40,"files":["prototype/tests/companion_turn_motion_test.gd"],"images":[],"evidence_images":[],"max_tokens":2048,"task":"Review one real source"}
        self.register={"schema":1,"version":1,"tasks":[{"id":"O001","owner":"GPTOSS","revision":"a"*40,"scope":self.task["files"],"status":"reserved","access":"read","run_id":None,"note":""}]}

    def test_scoped_reservation(self):
        s.validate_task(self.task,self.register)
        with self.assertRaises(s.common.BridgeError):
            s.validate_task(dict(self.task,files=["prototype/scripts/main.gd"]),self.register)
        with self.assertRaises(ValueError):
            ledger.validate(dict(self.register,tasks=self.register["tasks"]+[dict(self.register["tasks"][0],id="O002")]))

    def test_provider_payloads_and_no_paid_model(self):
        for owner in ("ERNIE","SuperVL"):
            p=s.build_payload(owner,"test",[],2048)
            self.assertTrue(p["model"].endswith(":free"))
            self.assertEqual(p["provider"]["max_price"],{"prompt":0,"completion":0,"request":0,"image":0})
            self.assertFalse(p["provider"]["allow_fallbacks"])
        g=s.build_payload("Gemini","test",[],8192)
        self.assertEqual(g["generationConfig"]["thinkingConfig"]["thinkingLevel"],"XHIGH")
        self.assertNotIn("tools",g)
        o=s.build_payload("GPTOSS","test",[],2048)
        self.assertEqual(o["reasoning_effort"],"high")
        self.assertFalse(o["include_reasoning"])
        self.assertEqual(o["max_completion_tokens"],2048)

    def test_inline_vision_and_hidden_thought(self):
        payload=s.build_payload("Gemini","review",[{"type":"image_url","image_url":{"url":"data:image/png;base64,AAAA"}}],8192)
        self.assertEqual(payload["contents"][0]["parts"][1]["inlineData"]["mimeType"],"image/png")
        raw=json.dumps({"candidates":[{"content":{"parts":[{"thought":True,"text":"not retained"},{"text":"answer"}]},"finishReason":"STOP"}]}).encode()
        self.assertEqual(s.parse_response("Gemini",raw)[0],"answer")

    def test_missing_key_means_no_network(self):
        class NoNetwork:
            def open(self,*args,**kwargs): raise AssertionError("Unexpected request")
        with tempfile.TemporaryDirectory() as d:
            self.assertEqual(s.run(self.task,self.register,"",NoNetwork(),Path(d)),2)
            v=json.loads((Path(d)/"receipt.json").read_text())
            self.assertEqual(v["error_kind"],"missing_authorized_free_key")
            self.assertEqual(v["invocation_state"],"not_submitted")

    def test_probe_failure_no_second_post(self):
        class Opener:
            calls=0
            def open(self,req,timeout):
                self.calls+=1
                raise HTTPError(req.full_url,429,"quota",{},None)
        o=Opener()
        with tempfile.TemporaryDirectory() as d:
            self.assertEqual(s.run(self.task,self.register,"fake-key",o,Path(d)),1)
            self.assertEqual(o.calls,1)
            v=json.loads((Path(d)/"receipt.json").read_text())
            self.assertEqual(v["error_kind"],"http_429")
            self.assertFalse(v["automatic_post_retry"])

    def test_probe_then_actual_review(self):
        class Response(io.BytesIO):
            status=200
            headers={"Content-Type":"application/json"}
        class Opener:
            calls=0
            def open(self,req,timeout):
                self.calls+=1
                text=s.PROBE if self.calls==1 else "reviewed candidate"
                return Response(json.dumps({"choices":[{"message":{"content":text,"reasoning":"not retained"},"finish_reason":"stop"}]}).encode())
        o=Opener()
        with tempfile.TemporaryDirectory() as d,patch.object(s.common,"collect",return_value=("source",{})),patch.object(s.visual,"collect_images",return_value=([],{})):
            self.assertEqual(s.run(self.task,self.register,"fake-key",o,Path(d)),0)
            self.assertEqual(o.calls,2)
            v=json.loads((Path(d)/"receipt.json").read_text())
            self.assertTrue(v["probe_pass"])
            self.assertTrue(v["complete"])
            self.assertNotIn("reasoning",v)

if __name__=="__main__": unittest.main()
