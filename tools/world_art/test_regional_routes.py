import copy
import json
from pathlib import Path
import unittest
from regional_routes import validate_atlas, shortest_route

class RegionalRoutesTest(unittest.TestCase):
    def setUp(self):
        self.manifest=json.loads((Path(__file__).resolve().parents[2]/"prototype/assets/world_expansion/manifest.json").read_text())
    def test_expected_connected_sites(self):
        graph,routes=validate_atlas(self.manifest)
        self.assertEqual((len(graph),len(routes)),(5,5))
        for a in graph:
            for b in graph:
                self.assertTrue(shortest_route(self.manifest,a,b)["reachable"])
    def test_reroutes_after_eastern_closure(self):
        route=shortest_route(self.manifest,"capital_west","capital_east",["eastern_road"])
        self.assertTrue(route["reachable"])
        self.assertEqual(route["routes"],["western_road","valley_river","river_coast","coastal_road"])
    def test_no_route_without_mutating_world(self):
        before=copy.deepcopy(self.manifest)
        result=shortest_route(self.manifest,"capital_west","capital_east",["eastern_road","coastal_road"])
        self.assertFalse(result["reachable"])
        self.assertIsNone(result["length_m"])
        self.assertEqual(self.manifest,before)
    def test_endpoint_drift_rejected(self):
        self.manifest["trade_routes"][0]["waypoints"][-1][0]+=1
        with self.assertRaisesRegex(ValueError,"anchors"):validate_atlas(self.manifest)
    def test_nonfinite_coordinate_rejected(self):
        self.manifest["trade_routes"][0]["waypoints"][1][0]=float("nan")
        with self.assertRaisesRegex(ValueError,"geometry"):validate_atlas(self.manifest)
    def test_disconnected_graph_rejected(self):
        self.manifest["trade_routes"]=[r for r in self.manifest["trade_routes"] if r["id"]!="western_road"]
        with self.assertRaisesRegex(ValueError,"disconnected"):validate_atlas(self.manifest)
    def test_duplicate_route_rejected(self):
        self.manifest["trade_routes"].append(copy.deepcopy(self.manifest["trade_routes"][0]))
        with self.assertRaisesRegex(ValueError,"duplicate"):validate_atlas(self.manifest)

if __name__=="__main__":unittest.main()
