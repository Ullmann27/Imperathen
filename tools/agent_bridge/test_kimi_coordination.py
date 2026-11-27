import json
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch
import kimi_editor as editor
import team_work_register as register
import kimi_production_context as context

class CoordinationTests(unittest.TestCase):
    def task(self,ident="A",owner="A1",path="prototype/scripts/main.gd",status="reserved",access="edit"):
        return {"id":ident,"owner":owner,"status":status,"revision":"a"*40,"run_id":None,
                "scope":[path],"access":access,"note":""}
    def data(self): return {"schema":1,"version":1,"tasks":[]}
    def test_overlap_and_version(self):
        d=register.update(self.data(),{"expected_version":1,"task":self.task()})
        with self.assertRaises(ValueError):
            register.update(d,{"expected_version":1,"task":self.task("B","A2")})
        with self.assertRaises(ValueError):
            register.update(d,{"expected_version":2,"task":self.task("B","A2","prototype/scripts")})
        d=register.update(d,{"expected_version":2,"task":self.task("B","A2","prototype/scripts",access="read")})
        self.assertEqual(d["version"],3)
    def test_one_kimi_and_real_run(self):
        d=register.update(self.data(),{"expected_version":1,"task":self.task("K1","Kimi",access="read")})
        with self.assertRaises(ValueError):
            register.update(d,{"expected_version":2,"task":self.task("K2","Kimi",access="read")})
        t=dict(d["tasks"][0],status="submitted")
        with self.assertRaises(ValueError):
            register.update(d,{"expected_version":2,"task":t})
        d=register.update(d,{"expected_version":2,"task":dict(t,run_id="123")})
        self.assertEqual(d["tasks"][0]["run_id"],"123")
    def test_repository_register(self):
        path=Path(register.__file__).with_name("team_work_register.json")
        self.assertTrue(register.validate(json.loads(path.read_text()))["tasks"])
        self.assertIn("A1 Motion",context.production_context())
    def test_editor_checkpoint(self):
        w=editor.Workspace({"prototype/scripts/x.gd":"old\n"},[])
        w.perform("replace_text",{"path":"prototype/scripts/x.gd","old":"old","new":"new"})
        with tempfile.TemporaryDirectory() as d:
            editor.write_checkpoint(Path(d),{"revision":"a"*40},w,1,"fake-key")
            receipt=json.loads((Path(d)/"checkpoint.json").read_text())
            self.assertEqual(receipt["status"],"incomplete_unreviewed")
            self.assertEqual(receipt["changes"][0]["content"],"new\n")
            self.assertNotIn("reasoning_content",receipt)
if __name__=="__main__": unittest.main()
