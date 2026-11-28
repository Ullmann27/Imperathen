import unittest
import numpy as np
from youth_armour_local_weights import (REST, EXPECTED, EXPECTED_CODES, NAMES, locate, topology,
                                       candidate_weights, no_edge_regression, godot_import_weight_codes,
                                       solve_affine_weights)


class LocalWeightTests(unittest.TestCase):
    def setUp(self):
        self.pos = np.vstack([REST, [0., .6, .2]])
        self.names = ["Pelvis", NAMES[2], NAMES[0], NAMES[3], NAMES[1]]
        self.joints = np.array([[4, 2, 3, 1], [1, 3, 4, 2], [1, 3, 4, 2]])
        indices = [self.names.index(n) for n in NAMES]
        # Simulate normalized float32 GLB weights whose stored UINT16
        # codes are exactly the measured engine readback, not decoded
        # quantized values masquerading as source weights.
        self.raw_expected = ((EXPECTED_CODES + (65535 - EXPECTED_CODES.sum(axis=1))[:, None] / 4) / 65535).astype(np.float32)
        self.weights = np.array([[dict(zip(indices, row))[j] for j in joint]
                                 for row, joint in zip([*self.raw_expected, self.raw_expected[1]], self.joints)], dtype=float)
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
                                       self.raw_expected.astype(float).mean(axis=0) / self.raw_expected.astype(float).mean(axis=0).sum())

    def test_exact_engine_encoding_and_non_normalized_readback(self):
        codes = godot_import_weight_codes(self.raw_expected)
        np.testing.assert_array_equal(codes, EXPECTED_CODES)
        self.assertEqual(list(codes.sum(axis=1)), [65534, 65533])
        self.assertTrue(np.all(np.abs(self.raw_expected - EXPECTED).sum(axis=1) > 2e-6))
        pair, _ = locate(self.pos, self.joints, self.weights, self.names, self.edges)
        self.assertEqual(pair, (0, 1))

    def test_one_import_code_difference_rejected(self):
        changed = self.weights.copy()
        changed[0, 0] += 1.0 / 65535
        changed[0, 1] -= 1.0 / 65535
        with self.assertRaises(ValueError):
            locate(self.pos, self.joints, changed, self.names, self.edges)

    def test_signed_axis_permutation_preserves_unique_binding_identity(self):
        for axes, signs in [((0, 1, 2), (-1, 1, -1)),
                            ((2, 1, 0), (1, -1, 1)),
                            ((1, 2, 0), (-1, -1, 1))]:
            transformed = self.pos[:, axes] * np.array(signs)
            pair, named = locate(transformed, self.joints, self.weights, self.names, self.edges)
            self.assertEqual(pair, (0, 1))
            self.assertEqual(named, [2, 4, 1, 3])

    def test_translation_is_not_guessed(self):
        with self.assertRaises(ValueError):
            locate(self.pos + np.array([.01, 0, 0]), self.joints, self.weights, self.names, self.edges)

    def test_scaled_edge_is_not_guessed(self):
        with self.assertRaises(ValueError):
            locate(self.pos * 1.01, self.joints, self.weights, self.names, self.edges)

    def test_duplicate_connected_matches_fail_closed(self):
        pos = np.concatenate([self.pos, self.pos])
        joints = np.concatenate([self.joints, self.joints])
        weights = np.concatenate([self.weights, self.weights])
        edges = topology(np.array([0, 1, 2, 3, 4, 5]), 6)
        with self.assertRaises(ValueError):
            locate(pos, joints, weights, self.names, edges)

    def test_weight_tolerance_not_relaxed(self):
        changed = self.weights.copy()
        changed[0, 0] += 1e-4
        changed[0, 1] -= 1e-4
        with self.assertRaises(ValueError):
            locate(self.pos, self.joints, changed, self.names, self.edges)

    def test_no_topological_edge_rejects(self):
        with self.assertRaises(ValueError):
            locate(self.pos, self.joints, self.weights, self.names, np.array([[0, 2], [1, 2]]))

    def test_mismatched_coincident_seam_rejects(self):
        self.pos[2] = self.pos[0]
        with self.assertRaises(ValueError):
            candidate_weights(self.pos, self.joints, self.weights, (0, 1), [2, 4, 1, 3])

    def test_constrained_solver_keeps_both_normalized_bindings(self):
        original = np.array([[.8, .1, .05, .05], [.2, .4, .2, .2]])
        offsets = np.zeros((2, 3))
        coefficients = np.zeros((2, 3, 8))
        coefficients[0, 0, 0] = 1
        coefficients[0, 0, 4] = -1
        # A neighboring edge limits the first binding's displacement.
        offsets[1, 0] = -.8
        coefficients[1, 0, 0] = 1
        solved, report = solve_affine_weights(original, offsets, coefficients, [.1, .15])
        np.testing.assert_allclose(solved.sum(axis=1), [1, 1], atol=1e-8)
        self.assertTrue(np.all(solved >= 0))
        self.assertLessEqual(abs(solved[0, 0]-solved[1, 0]), .100000001)
        self.assertLessEqual(abs(solved[0, 0]-.8), .150000001)
        self.assertEqual(report["constraints"], 2)

    def test_constrained_solver_rejects_infeasible_geometry(self):
        original = np.full((2, 4), .25)
        offsets = np.array([[2., 0., 0.]])
        coefficients = np.zeros((1, 3, 8))
        with self.assertRaises(ValueError):
            solve_affine_weights(original, offsets, coefficients, [1.])

    def test_constrained_solver_leaves_already_feasible_source_unchanged(self):
        original = np.full((2, 4), .25)
        offsets = np.zeros((1, 3))
        coefficients = np.zeros((1, 3, 8))
        solved, report = solve_affine_weights(original, offsets, coefficients, [1.])
        np.testing.assert_array_equal(solved, original)
        self.assertEqual(report["active_constraints"], 0)

    def test_regression_guard(self):
        limit = np.array([.05, .05])
        self.assertTrue(no_edge_regression(np.array([.06, .04]), np.array([.04, .04]), limit))
        self.assertFalse(no_edge_regression(np.array([.06, .04]), np.array([.04, .051]), limit))
        self.assertFalse(no_edge_regression(np.array([.06, .04]), np.array([.061, .04]), limit))


if __name__ == "__main__":
    unittest.main()
