"""Cut the downloaded Sonniss pool into one-shot slices and measure them.

Many library files hold several takes back to back; each take separated by
silence becomes a slice. Every slice gets duration, attack, brightness,
decay and loudness so recipes can pick material by name and by sound.
Run with the Windows Python (needs numpy/scipy/soundfile):
  py -3.13 tools/sfx_slices.py   -> G:/audio_library/sonniss/slices.json
"""
import json
import os
from concurrent.futures import ProcessPoolExecutor

import numpy as np
import soundfile as sf

ROOT = "G:/audio_library/sonniss"
FILES = os.path.join(ROOT, "files")


def envelope_db(mono, sr, win=0.01):
    hop = max(1, int(sr * win))
    frames = len(mono) // hop
    if frames == 0:
        return np.array([-120.0]), hop
    block = np.abs(mono[:frames * hop]).reshape(frames, hop).max(axis=1)
    return 20 * np.log10(block + 1e-9), hop


def measure(seg, sr):
    mono = seg.mean(axis=1) if seg.ndim > 1 else seg
    peak = float(np.max(np.abs(mono)) + 1e-9)
    env, hop = envelope_db(mono, sr, 0.005)
    top = int(np.argmax(env))
    attack = top * hop / sr
    # Decay: time from the peak until the envelope falls 30 dB below it.
    below = np.where(env[top:] < env[top] - 30)[0]
    decay = (below[0] if len(below) else len(env) - top) * hop / sr
    spec = np.abs(np.fft.rfft(mono[: min(len(mono), sr)] * np.hanning(min(len(mono), sr))))
    freqs = np.fft.rfftfreq(min(len(mono), sr), 1 / sr)
    centroid = float((spec * freqs).sum() / (spec.sum() + 1e-9))
    low = float(spec[freqs < 150].sum() / (spec.sum() + 1e-9))
    rms = float(np.sqrt(np.mean(mono ** 2)) + 1e-9)
    return {
        "dur": len(mono) / sr,
        "attack": attack,
        "decay": decay,
        "centroid": centroid,
        "low": low,
        "peak_db": 20 * np.log10(peak),
        "crest": 20 * np.log10(peak / rms),
    }


def slice_file(path):
    try:
        data, sr = sf.read(path, always_2d=True, dtype="float32")
    except Exception as error:
        return []
    mono = data.mean(axis=1)
    if len(mono) < sr * 0.03:
        return []
    env, hop = envelope_db(mono, sr)
    top = env.max()
    loud = env > top - 42
    quiet_run = int(0.12 / 0.01)
    slices = []
    i = 0
    n = len(env)
    while i < n:
        if not loud[i]:
            i += 1
            continue
        start = i
        silent = 0
        j = i
        while j < n and silent < quiet_run:
            silent = silent + 1 if env[j] < top - 52 else 0
            j += 1
        end = j - silent
        a = max(0, start * hop - int(sr * 0.004))
        b = min(len(mono), end * hop + int(sr * 0.05))
        if (b - a) > sr * 0.03:
            m = measure(data[a:b], sr)
            m.update({"file": os.path.relpath(path, FILES).replace("\\", "/"), "start": a / sr, "end": b / sr, "sr": sr, "ch": data.shape[1]})
            slices.append(m)
        i = j
    return slices[:40]


def main():
    paths = []
    for dirpath, _, names in os.walk(FILES):
        for name in names:
            if name.lower().endswith((".wav", ".flac", ".aif", ".aiff")):
                paths.append(os.path.join(dirpath, name))
    with ProcessPoolExecutor() as pool:
        results = list(pool.map(slice_file, paths, chunksize=4))
    slices = [s for group in results for s in group]
    json.dump(slices, open(os.path.join(ROOT, "slices.json"), "w", encoding="utf-8"), ensure_ascii=False)
    print(f"SLICED files={len(paths)} slices={len(slices)}")


if __name__ == "__main__":
    main()
