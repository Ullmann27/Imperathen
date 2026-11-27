import io
import json
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch
from urllib.error import HTTPError
import deepseek_bridge as d
import team_work_register as ledger

class Response(io.BytesIO):
    def __init__(self, value):
        super().__init__(json.dumps(value).encode())
        self.status=200
        self.headers={"Content-Type":"application/json"}

def completion(text,finish="stop"):
    return {"model":d.MODEL,"choices":[{"message":{"content":text,"reasoning_content":"not retained"},"finish_reason":finish}]}

class DeepSeekTests(unittest.TestCase):
    def setUp(self):
        self.task={"schema":1,"id":"D001","phase":"probe_then_review","revision":"a"*40,
                   "task":"Review one real source","files":["prototype/scripts/ui/regional_map.gd"],
                   "images":[],"max_tokens":8192}
        self.register={"schema":1,"version":1,"tasks":[{"id":"D001","owner":"DeepSeek",
             "status":"reserved","revision":"a"*40,"run_id":None,"scope":self.task["files"],
             "access":"read","note":"Independent offline fixture; no real invocation"}]}
    def test_pinned_scope(self):
        d.validate_task(self.task,self.register)
        bad=dict(self.task,files=["prototype/scripts/main.gd"])
        with self.assertRaises(d.common.BridgeError):
            d.validate_task(bad,self.register)
    def test_parallel_read_and_single_submission(self):
        second=dict(next(x for x in self.register["tasks"] if x["id"]==self.task["id"]),id="D999")
        with self.assertRaises(ValueError):
            ledger.validate(dict(self.register,tasks=self.register["tasks"]+[second]))
    def test_model_and_documented_parameters(self):
        value=d.build_payload("task",[],8192,True)
        self.assertEqual(value["model"],"deepseek-ai/deepseek-v4.1-flash")
        self.assertTrue(value["stream"])
        self.assertNotIn("reasoning_effort",value)
    def test_json_and_truncation(self):
        answer,meta=d.parse_json(json.dumps(completion("patch","length")).encode())
        self.assertEqual(answer,"patch")
        self.assertFalse(meta["complete"])
        self.assertNotIn("reasoning_content",meta)
    def test_probe_then_review_and_no_reasoning_archive(self):
        class Opener:
            def __init__(self):self.calls=[]
            def open(self,req,timeout):
                self.calls.append((req.get_method(),json.loads(req.data)["model"]))
                return Response(completion(d.PROBE_TOKEN if len(self.calls)==1 else "patch"))
        o=Opener()
        with tempfile.TemporaryDirectory() as tmp, patch.object(d.common,"collect",return_value=("code",{})), patch.object(d.image_input,"collect_images",return_value=([],{})):
            path=Path(tmp)
            self.assertEqual(d.run(self.task,self.register,"fake-key",o,path),0)
            self.assertEqual(len(o.calls),2)
            receipt=json.loads((path/"receipt.json").read_text())
            self.assertTrue(receipt["complete"])
            self.assertEqual(receipt["probe_status"],"passed")
            self.assertNotIn("reasoning_content",receipt)
    def test_402_does_not_retry_or_enter_review(self):
        class Opener:
            calls=0
            def open(self,req,timeout):
                self.calls+=1
                raise HTTPError(req.full_url,402,"payment",{},None)
        o=Opener()
        with tempfile.TemporaryDirectory() as tmp:
            path=Path(tmp)
            self.assertEqual(d.run(self.task,self.register,"fake-key",o,path),1)
            receipt=json.loads((path/"receipt.json").read_text())
            self.assertEqual(receipt["error_kind"],"http_402")
            self.assertEqual(o.calls,1)
            self.assertFalse(receipt["automatic_post_retry"])
            self.assertFalse((path/"answer.md").exists())
if __name__=="__main__":unittest.main()
