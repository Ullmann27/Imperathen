import unittest
import numpy as np
from youth_armour_local_weights import (REST, EXPECTED, NAMES, locate, topology,
                                       candidate_weights, no_edge_regression)


class LocalWeightTests(unittest.TestCase):
    def setUp(self):
        self.pos = np.vstack([REST, [0., .6, .2]])
        self.names = ["Pelvis", NAMES[2], NAMES[0], NAMES[3], NAMES[1]]
        self.joints = np.array([[4, 2, 3, 1], [1, 3, 4, 2], [1, 3, 4, 2]])
        indices = [self.names.index(n) for n in NAMES]
        self.weights = np.array([[dict(zip(indices, row))[j] for j in joint]
                                 for row, joint in zip([*EXPECTED, EXPECTED[1]], self.joints)])
        self.edges = topology(np.array([0, 1, 2]), 3)

    def test_named_reordered_influences_and_unchanged_neighbor(self):
        pair, named = locate(self.pos, self.joints, self.weights, self.names, self.edges)
        self.assertEqual(pair, (0, 1))
        revised, changed, seams = candidate_weights(self.pos, self.joints, self.weights, pair, named)
        self.assertEqual(changed, [0, 1])
        self.assertEqual(seams, [])
        np.testing.assert_array_equal(revised[2], self.weights[2])
        for v in pair:
            np.testing.assert_allclose([dict(zip(self.joints[v], revised[v]))[j] for j in named],
                                       EXPECTED.mean(axis=0) / EXPECTED.mean(axis=0).sum())

    def test_no_topological_edge_rejects(self):
        with self.assertRaises(ValueError):
            locate(self.pos, self.joints, self.weights, self.names, np.array([[0, 2], [1, 2]]))

    def test_mismatched_coincident_seam_rejects(self):
        self.pos[2] = self.pos[0]
        with self.assertRaises(ValueError):
            candidate_weights(self.pos, self.joints, self.weights, (0, 1), [2, 4, 1, 3])

    def test_regression_guard(self):
        limit = np.array([.05, .05])
        self.assertTrue(no_edge_regression(np.array([.06, .04]), np.array([.04, .04]), limit))
        self.assertFalse(no_edge_regression(np.array([.06, .04]), np.array([.04, .051]), limit))
        self.assertFalse(no_edge_regression(np.array([.06, .04]), np.array([.061, .04]), limit))


if __name__ == "__main__":
    unittest.main()
