"""Cut a Suno track into a seamless, beat-aligned game loop.

Usage (G: venv):
  G:/audio_library/venv/Scripts/python.exe tools/music_loop.py <in.wav> <out_name> [start_s] [bars]
Finds the tempo, takes `bars` whole bars from near `start_s`, picks the end point
whose sound best matches the start, bakes a crossfade with the audio that follows
the end into the head (so end -> start continues naturally), dips 2-5 kHz a little
to leave room for effects, normalises to -16 LUFS and writes assets/audio/<out>.ogg.
"""
import os
import subprocess
import sys

import numpy as np
import pyloudnorm as pyln
import soundfile as sf
from pedalboard import Pedalboard, PeakFilter, HighpassFilter

SR = 48000


def onset_env(mono, hop=512):
    e = np.sqrt(np.convolve(mono ** 2, np.ones(hop) / hop, "same")[::hop])
    return np.maximum(0, np.diff(e, prepend=e[0])), hop


def beat_period(mono):
    on, hop = onset_env(mono[: SR * 60])
    on = on - on.mean()
    ac = np.correlate(on, on, "full")[len(on) - 1:]
    lags = np.arange(len(ac)) * hop / SR
    ok = (lags > 60 / 160) & (lags < 60 / 70)
    return lags[ok][np.argmax(ac[ok])]


def main():
    src, name = sys.argv[1], sys.argv[2]
    start_s = float(sys.argv[3]) if len(sys.argv) > 3 else 50.0
    bars = int(sys.argv[4]) if len(sys.argv) > 4 else 64
    x, sr = sf.read(src, always_2d=True, dtype="float32")
    assert sr == SR, sr
    mono = x.mean(1)
    beat = beat_period(mono)
    # Snap the start onto the strongest nearby onset (a downbeat-ish hit).
    on, hop = onset_env(mono)
    i0 = int(start_s * SR / hop)
    win = int(beat * SR / hop)
    s = (i0 + int(np.argmax(on[i0:i0 + win]))) * hop
    length = int(round(bars * 4 * beat * SR))
    # Search a little around the nominal end for the best match to the head.
    probe = int(0.5 * SR)
    head = mono[s:s + probe]
    best, best_e = -1e9, s + length
    for d in range(-int(0.03 * SR), int(0.03 * SR), 16):
        e = s + length + d
        tail = mono[e:e + probe]
        if len(tail) < probe:
            break
        c = float(np.dot(head, tail) / (np.linalg.norm(head) * np.linalg.norm(tail) + 1e-9))
        if c > best:
            best, best_e = c, e
    e = best_e
    out = x[s:e].copy()
    xf = int(0.35 * SR)
    fade = np.linspace(0, 1, xf)[:, None]
    # Equal-power blend: the head fades in under the audio that naturally follows the end.
    out[:xf] = x[s:s + xf] * np.sin(fade * np.pi / 2) + x[e:e + xf] * np.cos(fade * np.pi / 2)
    out = Pedalboard([HighpassFilter(28), PeakFilter(cutoff_frequency_hz=3200, gain_db=-3.0, q=0.7)])(out.T, SR).T
    meter = pyln.Meter(SR)
    out = out * 10 ** ((-16.0 - meter.integrated_loudness(out)) / 20)
    out = out / max(1.0, np.max(np.abs(out)) / 0.95)
    tmp = os.path.join("G:/audio_library/work/music", name + "_loop.wav")
    sf.write(tmp, out, SR, subtype="PCM_24")
    dst = os.path.join(os.path.dirname(__file__), "..", "assets", "audio", name + ".ogg")
    subprocess.run(["ffmpeg", "-loglevel", "error", "-y", "-i", tmp, "-c:a", "libvorbis", "-q:a", "6", dst], check=True)
    print(f"LOOP {name}: tempo {60 / beat:.1f} BPM, {s / SR:.2f}s -> {e / SR:.2f}s ({(e - s) / SR:.1f}s, {bars} bars), seam match {best:.3f}")


if __name__ == "__main__":
    main()
