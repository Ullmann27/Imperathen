"""Offline regression for energy-onset correction retaining CTC phoneme order."""
import unittest
import numpy as np
from align_visemes import refine_phrase_onsets

class PhraseOnsetBoundsTest(unittest.TestCase):
    def test_late_energy_cannot_move_phone_past_next_phone(self):
        sr=1000
        wave=np.zeros(700)
        wave[285:340]=0.5
        phones=[[.05,.10,1,"p"],[.23,.25,2,"f"],[.27,.34,3,"a"]]
        refined=refine_phrase_onsets(phones,wave,sr)
        self.assertEqual(refined[1][:2],[.23,.25])
        self.assertLessEqual(refined[1][0],refined[2][0])
        self.assertLessEqual(refined[1][1],refined[2][0])
    def test_earlier_onset_inside_valid_interval_is_retained(self):
        sr=1000
        wave=np.zeros(700)
        wave[205:240]=0.5
        phones=[[.05,.10,1,"p"],[.23,.26,2,"f"],[.27,.34,3,"a"]]
        refined=refine_phrase_onsets(phones,wave,sr)
        self.assertGreaterEqual(refined[1][0],.10)
        self.assertLess(refined[1][0],.23)
        self.assertEqual(refined[1][1],.26)

if __name__=="__main__":
    unittest.main()
