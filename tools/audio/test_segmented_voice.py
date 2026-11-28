"""Offline regression for exact phrase splitting and conservative audio joins."""
import importlib.util
import unittest
from pathlib import Path
import numpy as np

SPEC=importlib.util.spec_from_file_location("voice_gen",Path(__file__).with_name("generate_voices.py"))
GEN=importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(GEN)

class SegmentedVoiceTest(unittest.TestCase):
    def test_exact_words(self):
        line="Dann nimm dieses Wachstäfelchen. Fabius ist der Holzfäller. Sag ihm, ich brauche bis zum Markttag zwei Körbe Kohle."
        chunks=GEN.split_exact_phrases(line)
        self.assertEqual(len(chunks),3)
        self.assertEqual(GEN.norm_words(" ".join(chunks)),GEN.norm_words(line))
    def test_join_retains_all_audible_samples(self):
        sr=1000
        wave=np.r_[np.zeros(200),np.ones(100)*.3,np.zeros(200)]
        joined=GEN.join_generated_phrases([wave,wave],sr)
        self.assertEqual(np.count_nonzero(joined==.3),200)
        self.assertTrue(np.isfinite(joined).all())
        self.assertLess(joined.size,2*wave.size)
    def test_silent_phrase_rejected(self):
        with self.assertRaises(ValueError):
            GEN.join_generated_phrases([np.zeros(100)],1000)
if __name__=="__main__":
    unittest.main()
