import unittest
from voice_contract import recording_errors, track_errors, VISEMES

class Contract(unittest.TestCase):
    def setUp(self):
        self.line = {"line_id":"A", "speaker_id":"julia", "text_key":"abc", "duration_s":2.0}
        self.track = {**self.line, "schema_version":1, "visemes":VISEMES.copy(), "segments":[[0.1,0.2,4],[1.9,2.06,0]], "audio_onset_s":.1,"first_phoneme_s":.1}
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
    def test_wrong_viseme_order(self):
        self.track["visemes"][1], self.track["visemes"][2] = self.track["visemes"][2], self.track["visemes"][1]
        self.assertIn("viseme_segments_missing",track_errors(self.track,self.line))
    def test_onset_outside_audio(self):
        for value in (-.01,2.1):
            with self.subTest(value=value):
                self.track["audio_onset_s"]=self.track["first_phoneme_s"]=value
                self.assertIn("viseme_onset_mismatch",track_errors(self.track,self.line))

class RecordingContract(unittest.TestCase):
    def test_only_registered_speaker_and_measured_transcription_pass(self):
        row = {"speaker_id": "julia", "asr_wer": 0.12, "asr_text": "Guten Morgen"}
        self.assertEqual(recording_errors(row, {"julia"}), [])
        self.assertIn("unregistered_speaker", recording_errors(row, {"cassia"}))
        for value in (float("nan"), float("inf"), -0.1, True, None, 0.12001):
            with self.subTest(value=value):
                self.assertIn("unaccepted_transcription", recording_errors({**row, "asr_wer": value}, {"julia"}))
        self.assertIn("unaccepted_transcription", recording_errors({**row, "asr_text": " "}, {"julia"}))


if __name__ == "__main__":
    unittest.main()
