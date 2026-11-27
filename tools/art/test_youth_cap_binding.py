import unittest
import numpy as np
from youth_cap_binding import match_vertices, pose_subset, weight_signature, weight_delta


class CapBindingTests(unittest.TestCase):
    def setUp(self):
        self.shell_pos = np.array([[0.,0.,0.],[0.,0.,0.],[1.,0.,0.]])
        self.shell_j = np.array([[0,1,0,0],[1,0,0,0],[0,1,0,0]])
        self.shell_w = np.array([[.75,.25,0,0],[.25,.75,0,0],[1.,0,0,0]])
        self.cap_pos = np.array([[0.,0.,0.],[.05,0.,0.]])
        self.cap_j = np.array([[1,0,0,0],[0,1,0,0]])
        self.cap_w = np.array([[1.,0,0,0],[1.,0,0,0]])

    def match(self, shell_used=(0,1,2), cap_used=(0,1)):
        return match_vertices(self.shell_pos,self.shell_j,self.shell_w,
                              self.cap_pos,self.cap_j,self.cap_w,shell_used,cap_used)

    def test_reordered_influences_are_same_binding(self):
        a = weight_signature(self.shell_j[0],self.shell_w[0])
        b = weight_signature(self.shell_j[1],self.shell_w[1])
        self.assertAlmostEqual(weight_delta(a,b),0.)
        pairs,ambiguous,unmatched = self.match()
        self.assertEqual(pairs,[(0,0,1.5)])
        self.assertEqual(ambiguous,[])
        self.assertEqual(unmatched,[1])

    def test_ambiguous_nearby_skin_is_not_rebound(self):
        self.shell_w[1] = [1.,0,0,0]
        pairs,ambiguous,unmatched = self.match()
        self.assertEqual(pairs,[])
        self.assertEqual(ambiguous,[0])
        self.assertEqual(unmatched,[1])

    def test_unused_vertices_do_not_create_false_seam(self):
        pairs,ambiguous,unmatched = self.match(shell_used=(2,),cap_used=(0,))
        self.assertEqual(pairs,[])
        self.assertEqual(ambiguous,[])
        self.assertEqual(unmatched,[0])

    def test_deforming_split_vertices_and_weight_only_correction(self):
        def primitive(j,w):
            return {"position":np.zeros((1,3)), "joints":[0,1],
                    "ibm":np.stack([np.eye(4),np.eye(4)]),
                    "joint_index":np.array([j]),"weight":np.array([w])}
        shell = primitive([0,1,0,0],[.75,.25,0.,0.])
        cap = primitive([1,0,0,0],[1.,0.,0.,0.])
        pose = [np.eye(4),np.eye(4)]
        pose[1][0,3] = .08
        a = pose_subset(shell,[0],pose)
        b = pose_subset(cap,[0],pose)
        self.assertAlmostEqual(float(np.linalg.norm(a-b)),.06)
        cap["joint_index"][:] = shell["joint_index"]
        cap["weight"][:] = shell["weight"]
        self.assertAlmostEqual(float(np.linalg.norm(a-pose_subset(cap,[0],pose))),0.)
        self.assertTrue(np.array_equal(cap["position"],shell["position"]))

    def test_rest_position_close_does_not_match_distant_vertex(self):
        self.cap_pos[0,0] = .001
        self.assertEqual(self.match(cap_used=(0,)),([],[],[0]))


if __name__ == "__main__":
    unittest.main()
