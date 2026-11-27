import copy
import unittest
from pathlib import Path
from protocol import load_job, validate, inspect_glb

ROOT = Path(__file__).resolve().parents[2]

class RenderInboxTest(unittest.TestCase):
    def setUp(self):
        self.job = load_job(ROOT/"render_bridge/jobs/current.json")

    def test_existing_job_and_exact_original_meshes(self):
        for a in self.job["assets"]:
            _,raw,doc = inspect_glb(ROOT,a)
            self.assertTrue(doc["skins"])
            self.assertTrue(doc["animations"])
            self.assertGreater(len(raw),1000)

    def test_reject_cross_project(self):
        job = copy.deepcopy(self.job)
        job["project"] = "Continuum"
        with self.assertRaises(ValueError): validate(job)

    def test_reject_script_and_traversal(self):
        job=copy.deepcopy(self.job); job["python"]="arbitrary code"
        with self.assertRaises(ValueError): validate(job)
        job=copy.deepcopy(self.job); job["assets"][0]["path"]="../device-ai"
        with self.assertRaises(ValueError): validate(job)

    def test_reject_unverified_blob(self):
        asset=copy.deepcopy(self.job["assets"][0]); asset["git_blob"]="0"*40
        with self.assertRaises(ValueError): inspect_glb(ROOT,asset)

    def test_reject_duplicate_and_unbounded(self):
        job=copy.deepcopy(self.job);job["assets"]=[job["assets"][0]]*2
        with self.assertRaises(ValueError): validate(job)
        job=copy.deepcopy(self.job);job["assets"]*=3
        with self.assertRaises(ValueError): validate(job)
