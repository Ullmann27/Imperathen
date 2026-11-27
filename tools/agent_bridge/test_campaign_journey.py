import copy
import unittest
from pathlib import Path
import campaign_journey as journey

ROOT = Path(__file__).resolve().parent

def evidence(source="a"*40, run="10", passed=True):
    return {"source_revision": source, "published_revision":"b"*40, "run_id":run,
            "engine_pass":passed, "images":[{"path":"art/review/campaign-start/menu.png","sha256":"d"*64,"bytes":4096}]}

class JourneyTests(unittest.TestCase):
    def setUp(self):
        self.catalog=journey.load(ROOT/"campaign_journey_catalog.json")
        self.state=journey.initial(self.catalog)
    def event(self, action, **kwargs):
        return journey.record(self.catalog,self.state,{"milestone":"MENU","action":action,**kwargs})
    def test_order_and_all_missions(self):
        entries=journey.validate_catalog(self.catalog)
        self.assertEqual(entries[0]["id"],"MENU")
        self.assertEqual(entries[1]["id"],"I-00")
        self.assertEqual(len([e for e in entries if e["kind"]=="mission"]),113)
        self.assertEqual(journey.plan(self.catalog,self.state)["action"],"capture_actual_game")
    def test_real_evidence_required(self):
        with self.assertRaises(ValueError):
            self.event("baseline",evidence={"engine_pass":True})
        self.event("baseline",evidence=evidence())
        task=next(iter(journey.plan(self.catalog,self.state)["manifest"].values()))
        self.assertEqual(task["reasoning_effort"],"max")
        self.assertEqual(task["revision"],"b"*40)
        self.assertEqual(len(task["evidence_images"]),1)
        self.assertEqual(task["evidence_images"][0]["sha256"],"d"*64)
    def test_cannot_skip_or_accept_failed_run(self):
        with self.assertRaises(ValueError):
            self.event("compare",verdict="engine_reviewed",findings="looks good")
        self.event("baseline",evidence=evidence())
        self.event("critique",findings="Lighting defect")
        self.event("patch",revision="c"*40)
        with self.assertRaises(ValueError):
            self.event("render",evidence=evidence(source="a"*40,run="11"))
        self.event("render",evidence=dict(evidence(source="c"*40,run="11",passed=False),published_revision="f"*40))
        task=next(iter(journey.plan(self.catalog,self.state)["manifest"].values()))
        self.assertEqual([x["label"] for x in task["evidence_images"]],["V1","V2"])
        self.assertEqual([x["revision"] for x in task["evidence_images"]],["b"*40,"f"*40])
        with self.assertRaises(ValueError):
            self.event("compare",verdict="engine_reviewed",findings="no")
        self.event("compare",verdict="improve",findings="Remaining defect")
        self.assertEqual(self.state["work"]["MENU"]["iteration"],2)
        self.assertEqual(journey.plan(self.catalog,self.state)["phase"],"patch")
    def test_device_pending_is_not_release_acceptance(self):
        self.event("baseline",evidence=evidence())
        self.event("critique",findings="Lighting")
        self.event("patch",revision="c"*40)
        self.event("render",evidence=evidence(source="c"*40,run="11"))
        self.event("compare",verdict="engine_reviewed",findings="Independent comparison passed")
        self.assertEqual(self.state["work"]["MENU"]["phase"],"device_pending")
        self.assertEqual(journey.plan(self.catalog,self.state)["milestone"],"I-00")
        with self.assertRaises(ValueError):
            self.event("device_accept",physical_fold7_pass=True,visual_review_pass=False)
        self.event("device_accept",physical_fold7_pass=True,visual_review_pass=True,receipt_sha256="e"*64,source_revision="c"*40,run_id="12")
        self.assertEqual(self.state["work"]["MENU"]["phase"],"accepted")
    def test_reject_out_of_order(self):
        with self.assertRaises(ValueError):
            journey.record(self.catalog,self.state,{"milestone":"I-01","action":"baseline","evidence":evidence()})

if __name__ == "__main__":
    unittest.main()
