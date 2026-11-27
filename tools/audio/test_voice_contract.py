import unittest
from voice_contract import track_errors

class Contract(unittest.TestCase):
    def setUp(self):
        self.line = {"line_id":"A", "speaker_id":"julia", "text_key":"abc", "duration_s":2.0}
        self.track = {**self.line, "schema_version":1, "visemes":[str(i) for i in range(15)], "segments":[[0.1,0.2,4],[1.9,2.06,0]], "audio_onset_s":.1,"first_phoneme_s":.1}
    def test_actual_segments(self):
        self.assertEqual(track_errors(self.track,self.line), [])
    def test_wrong_identity(self):
        self.track["speaker_id"]="silvanus"
        self.assertIn("viseme_identity_mismatch",track_errors(self.track,self.line))
    def test_invalid_index(self):
        self.track["segments"][0][2]=15
        self.assertIn("viseme_segment_invalid",track_errors(self.track,self.line))
    def test_missing_segments(self):
        self.track["keys"]=[[0,1,1]]
        del self.track["segments"]
        self.assertIn("viseme_segments_missing",track_errors(self.track,self.line))
    def test_wrong_onset(self):
        self.track["first_phoneme_s"]=.2
        self.assertIn("viseme_onset_mismatch",track_errors(self.track,self.line))

if __name__ == "__main__":
    unittest.main()
