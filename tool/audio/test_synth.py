"""Tests for the audio generator. Run from the repo root:

    tool/audio/.venv/Scripts/python -m unittest discover -s tool/audio -v
"""
import unittest

import numpy as np

import sfx
import synth as s


class SynthTest(unittest.TestCase):
    def test_wrap_add_folds_the_tail_onto_the_start(self):
        buf = np.zeros(1100)
        buf[1000:] = 1.0
        out = s.wrap_add(buf, 1000)
        self.assertEqual(len(out), 1000)
        self.assertTrue(np.all(out[:100] == 1.0))
        self.assertEqual(out[100], 0.0)

    def test_wrap_xfade_is_continuous_across_the_loop_point(self):
        x = np.sin(np.arange(3 * s.SR) * 0.01)
        n = 2 * s.SR
        out = s.wrap_xfade(x, n, 0.5)
        self.assertEqual(out.shape[-1], n)
        self.assertAlmostEqual(out[0], x[n])  # out[n-1] = x[n-1] → out[0] = x[n]
        self.assertAlmostEqual(out[-1], x[n - 1])

    def test_to_rms_respects_the_ceiling(self):
        x = np.zeros(1000)
        x[0] = 1.0  # all peak, tiny RMS
        self.assertAlmostEqual(s.peak_db(s.to_rms(x, -20, -6)), -6, places=6)

    def test_music_box_rings_decays_and_is_deterministic(self):
        x = s.music_box(s.midi_hz(74), 2.0)
        head, tail = x[:s.SR // 10], x[-s.SR // 10:]
        self.assertGreater(s.rms_db(head) - s.rms_db(tail), 30)
        np.testing.assert_array_equal(x, s.music_box(s.midi_hz(74), 2.0))

    def test_reverb_shapes(self):
        mono = s.reverb(np.ones(100), 0.5, stereo=False)
        st = s.reverb(np.ones(100), 0.5)
        self.assertEqual(mono.ndim, 1)
        self.assertEqual(st.shape[0], 2)
        self.assertGreater(len(mono), 100)

    def test_place_pans_mono_into_stereo(self):
        buf = np.zeros((2, 10))
        s.place(buf, np.ones(4), 0, pan=-1.0)
        self.assertAlmostEqual(buf[0, 0], np.sqrt(2))
        self.assertAlmostEqual(buf[1, 0], 0.0)
        self.assertEqual(buf[0, 4], 0.0)


class SfxTest(unittest.TestCase):
    def test_every_effect_renders_mono_finite_and_audible(self):
        for name, (render, _peak) in sfx.SFX.items():
            with self.subTest(name):
                x = render()
                self.assertEqual(x.ndim, 1)
                self.assertTrue(np.all(np.isfinite(x)))
                self.assertGreater(s.peak_db(x), -60)

    def test_there_are_28_effects(self):
        self.assertEqual(len(sfx.SFX), 28)


if __name__ == '__main__':
    unittest.main()
