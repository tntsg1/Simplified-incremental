"""Design Skyguard's sound effects from the Sonniss pool.

Every sound is a stack of layers cut from professional library recordings:
a transient that says what it is, a body that gives it weight, a tail that
places it in space. Each layer is peak-normalised before its gain, so gains
are true mix ratios. The stack goes through a shared master chain and is
written as several variants (different pitch / material) so repeats never
sound mechanical.

Run with the G: venv:
  G:/audio_library/venv/Scripts/python.exe tools/sfx_design.py [id ...]
Writes assets/audio/sfx/<id>_<n>.ogg and build/sfx_preview/manifest.json.
"""
import json
import os
import sys
from fractions import Fraction

import numpy as np
import pyloudnorm as pyln
import soundfile as sf
from pedalboard import Compressor, Distortion, HighpassFilter, Limiter, LowpassFilter, Pedalboard, PeakFilter, Reverb
from scipy.signal import resample_poly

POOL = "G:/audio_library/sonniss"
OUT = os.path.join(os.path.dirname(__file__), "..", "assets", "audio", "sfx")
PREVIEW = os.path.join(os.path.dirname(__file__), "..", "build", "sfx_preview")
SR = 48000
METER = pyln.Meter(SR, block_size=0.1)
TARGET_LUFS = {"weapon": -13.0, "kill": -14.0, "reward": -15.0, "ui": -18.0, "ult": -11.0, "boss": -13.0, "flow": -14.0, "body": -16.0}
SLICES = json.load(open(os.path.join(POOL, "slices.json"), encoding="utf-8"))


def find(key, index=0):
    hits = [s for s in SLICES if key.lower() in s["file"].lower()]
    if not hits:
        raise KeyError(f"no slice for {key!r}")
    return hits[min(index, len(hits) - 1)]


def tone(layer):
    # A clean synthetic blip: sine with a touch of FM shimmer and an exponential decay.
    n = int(SR * layer.get("len", 0.12))
    t = np.arange(n) / SR
    f0 = layer["tone"] * 2 ** (layer.get("pitch", 0) / 12)
    glide = f0 * 2 ** (layer.get("glide", 0) * t / max(t[-1], 1e-6) / 12)
    phase = 2 * np.pi * np.cumsum(glide) / SR
    mod = layer.get("fm", 0.0) * np.sin(phase * layer.get("ratio", 2.0))
    wave = np.sin(phase + mod) * np.exp(-t / layer.get("decay", 0.05))
    attack = int(SR * layer.get("attack", 0.003))
    wave[:attack] *= np.linspace(0, 1, attack)
    data = np.stack([wave, wave], axis=1).astype(np.float32)
    return data / (np.max(np.abs(data)) + 1e-9) * 10 ** (layer.get("gain", 0) / 20)


def env(n, attack, decay, hold=0.0):
    t = np.arange(n) / SR
    e = np.exp(-np.maximum(0, t - hold) / max(decay, 1e-4))
    a = int(SR * attack)
    if a > 0:
        e[:a] *= np.linspace(0, 1, a) ** 2
    return e


def kick(layer):
    # Sub thump: a sine whose pitch falls fast, lightly saturated so it reads on small speakers.
    n = int(SR * layer.get("len", 0.3))
    t = np.arange(n) / SR
    f0, f1 = layer.get("from", 120.0), layer.get("to", 45.0)
    sweep = layer.get("sweep", 0.06)
    f = f1 + (f0 - f1) * np.exp(-t / sweep)
    phase = 2 * np.pi * np.cumsum(f) / SR
    wave = np.sin(phase) * env(n, layer.get("attack", 0.001), layer.get("decay", 0.12), layer.get("hold", 0.0))
    drive = layer.get("drive", 1.5)
    wave = np.tanh(wave * drive) / np.tanh(drive)
    return np.stack([wave, wave], 1)


def zap(layer):
    # Energy tone: a stack of slightly detuned saw-ish voices gliding from -> to, low-passed.
    n = int(SR * layer.get("len", 0.3))
    t = np.arange(n) / SR
    f0, f1 = layer.get("from", 2400.0), layer.get("to", 400.0)
    glide = layer.get("glide", 0.08)
    f = f1 + (f0 - f1) * np.exp(-t / glide)
    out = np.zeros((n, 2))
    voices = layer.get("voices", 3)
    for v in range(voices):
        det = 1 + (v - (voices - 1) / 2) * layer.get("detune", 0.012)
        ph = 2 * np.pi * np.cumsum(f * det) / SR + v * 1.3
        mod = layer.get("fm", 0.0) * np.sin(ph * layer.get("ratio", 2.0))
        # Band-limited "saw": a few harmonics with 1/k fall-off.
        w = sum(np.sin(k * (ph + mod)) / k for k in range(1, layer.get("harm", 5) + 1))
        pan = (v / max(1, voices - 1) - .5) * layer.get("spread", .6)
        out[:, 0] += w * (1 - pan)
        out[:, 1] += w * (1 + pan)
    out *= env(n, layer.get("attack", 0.002), layer.get("decay", 0.08))[:, None]
    return out


def noise(layer):
    # Air: filtered noise whose band sweeps from -> to (pressure, hiss, whoosh, crack).
    n = int(SR * layer.get("len", 0.3))
    rng = np.random.default_rng(layer.get("seed", 7))
    raw = rng.standard_normal((n, 2)).astype(np.float32)
    f0, f1 = layer.get("from", 4000.0), layer.get("to", 800.0)
    out = np.zeros_like(raw)
    block = 256
    for i in range(0, n, block):
        u = i / max(1, n)
        fc = f0 * (f1 / f0) ** u
        bw = layer.get("q", 1.0)
        lo, hi = max(30.0, fc / (1 + bw)), min(SR / 2 - 100, fc * (1 + bw))
        seg = raw[max(0, i - 2048):i + block]
        spec = np.fft.rfft(seg, axis=0)
        fr = np.fft.rfftfreq(len(seg), 1 / SR)
        spec[(fr < lo) | (fr > hi)] = 0
        out[i:i + block] = np.fft.irfft(spec, len(seg), axis=0)[-min(block, n - i):]
    out *= env(n, layer.get("attack", 0.003), layer.get("decay", 0.1), layer.get("hold", 0.0))[:, None]
    if layer.get("swell"):
        out *= (np.linspace(0, 1, n) ** 2)[:, None]
    return out


def beat(layer):
    # Standing wave: two close sines beating, plus soft upper partials.
    n = int(SR * layer.get("len", 0.6))
    t = np.arange(n) / SR
    f = layer.get("freq", 110.0)
    d = layer.get("beat", 6.0)
    w = np.sin(2 * np.pi * f * t) + np.sin(2 * np.pi * (f + d) * t)
    w += .35 * np.sin(2 * np.pi * 2 * f * t + 1) + .18 * np.sin(2 * np.pi * 3 * (f + d / 2) * t)
    w *= env(n, layer.get("attack", 0.004), layer.get("decay", 0.25))
    return np.stack([w, np.roll(w, int(SR * 0.0007))], 1)


def crackle(layer):
    # Electric arcs: sparse random clicks and short bursts.
    n = int(SR * layer.get("len", 0.4))
    rng = np.random.default_rng(layer.get("seed", 3))
    out = np.zeros((n, 2))
    for _ in range(layer.get("count", 40)):
        at = int(rng.uniform(0, 1) ** 1.6 * (n - 400))
        ln = int(rng.uniform(20, 300))
        burst = rng.standard_normal(ln) * np.exp(-np.arange(ln) / (ln / 4))
        side = rng.uniform(.3, 1)
        out[at:at + ln, 0] += burst * side
        out[at:at + ln, 1] += burst * (1.3 - side)
    out *= env(n, 0.001, layer.get("decay", 0.15))[:, None]
    return out


SYNTHS = {"kick": kick, "zap": zap, "noise": noise, "beat": beat, "crackle": crackle}


def synth(layer):
    data = SYNTHS[layer["synth"]](layer).astype(np.float32)
    chain = []
    if layer.get("hp"):
        chain.append(HighpassFilter(layer["hp"]))
    if layer.get("lp"):
        chain.append(LowpassFilter(layer["lp"]))
    if chain:
        data = Pedalboard(chain)(data.T, SR).T
    data = data / (np.max(np.abs(data)) + 1e-9) * 10 ** (layer.get("gain", 0) / 20)
    fade = int(SR * layer.get("fade", 0.01))
    if len(data) > fade > 0:
        data[-fade:] *= np.linspace(1, 0, fade)[:, None] ** 2
    if layer.get("reverse"):
        data = data[::-1].copy()
    return data


def load(layer):
    if "synth" in layer:
        return synth(layer)
    if "tone" in layer:
        return tone(layer)
    s = find(layer["src"], layer.get("slice", 0))
    path = os.path.join(POOL, "files", s["file"])
    info = sf.info(path)
    start = int((s["start"] + layer.get("off", 0.0)) * info.samplerate)
    stop = int(s["end"] * info.samplerate)
    if "len" in layer:
        stop = min(stop, start + int(layer["len"] * info.samplerate * 2 ** (layer.get("pitch", 0) / 12)))
    data, sr = sf.read(path, start=start, stop=stop, always_2d=True, dtype="float32")
    if data.shape[1] == 1:
        data = np.repeat(data, 2, axis=1)
    data = data[:, :2]
    # Resampling to 48 kHz and the pitch shift are one step: a varispeed, like tape.
    ratio = Fraction(sr * 2 ** (layer.get("pitch", 0) / 12) / SR).limit_denominator(400)
    if ratio != 1:
        data = resample_poly(data, ratio.denominator, ratio.numerator, axis=0).astype(np.float32)
    if layer.get("snap"):
        # Start each layer a hair before its loudest moment: all transients land together.
        env = np.abs(data).max(axis=1)
        top = int(np.argmax(env[: int(SR * 0.6)]))
        data = data[max(0, top - int(SR * 0.004)):]
    if layer.get("reverse"):
        data = data[::-1].copy()
    chain = []
    if layer.get("hp"):
        chain.append(HighpassFilter(layer["hp"]))
    if layer.get("lp"):
        chain.append(LowpassFilter(layer["lp"]))
    if chain:
        data = Pedalboard(chain)(data.T, SR).T
    peak = np.max(np.abs(data)) + 1e-9
    data = data / peak * 10 ** (layer.get("gain", 0) / 20)
    fade_in = int(SR * layer.get("fade_in", 0.002))
    if fade_in:
        data[:fade_in] *= np.linspace(0, 1, fade_in)[:, None]
    fade = int(SR * layer.get("fade", 0.03))
    if fade and len(data) > fade:
        data[-fade:] *= np.linspace(1, 0, fade)[:, None] ** 2
    return data


def render(spec, variant):
    layers = spec["layers"]
    pitch = spec.get("pitches", [0])[variant % len(spec.get("pitches", [0]))]
    swap = spec.get("swap", {})
    parts = []
    for i, layer in enumerate(layers):
        layer = dict(layer)
        if str(i) in swap:
            layer.update(swap[str(i)][variant % len(swap[str(i)])])
        layer["pitch"] = layer.get("pitch", 0) + pitch
        layer.setdefault("snap", spec.get("snap", spec.get("group") in ("weapon", "kill")))
        delay = int(SR * layer.get("delay", 0))
        parts.append((delay, load(layer)))
    total = max(d + len(p) for d, p in parts)
    mix = np.zeros((total, 2), np.float32)
    for d, p in parts:
        mix[d:d + len(p)] += p
    length = int(SR * spec.get("len", 1.0))
    mix = mix[:length]
    if spec.get("prenorm"):
        # Big set pieces: keep the mix's own dynamics, the limiter only trims tips.
        mix = mix / (np.max(np.abs(mix)) + 1e-9) * 10 ** (-0.5 / 20)
    if spec.get("slap"):
        # A short stereo slap: the shot bouncing off something far away.
        d = int(SR * spec["slap"])
        echo = np.zeros_like(mix)
        echo[d:, 0] = mix[:-d, 1] * .32
        echo[int(d * 1.3):, 1] = mix[:-int(d * 1.3), 0] * .26
        mix = mix + Pedalboard([LowpassFilter(3500)])(echo.T.astype(np.float32), SR).T
    chain = [HighpassFilter(spec.get("hp", 35))]
    if spec.get("drive"):
        chain.append(Distortion(drive_db=spec["drive"]))
    # Tame the 2.5-5 kHz band that makes rapid-fire sounds tiring.
    chain.append(PeakFilter(cutoff_frequency_hz=3600, gain_db=spec.get("harsh", -3.0 if spec.get("group") in ("weapon", "kill", "ult", "boss", "body") else 0.0), q=0.9))
    if spec.get("lp"):
        chain.append(LowpassFilter(spec["lp"]))
    comp = spec.get("comp", -16)
    if comp is not None:
        chain.append(Compressor(threshold_db=comp, ratio=3.0, attack_ms=3, release_ms=90))
    if spec.get("room"):
        chain.append(Reverb(room_size=spec["room"], wet_level=spec.get("wet", 0.12), dry_level=1.0, width=1.0, damping=0.6))
    chain.append(Limiter(threshold_db=-1.5, release_ms=60))
    mix = Pedalboard(chain)(mix.T, SR).T[:length]
    # Shape the end: everything is short and dies cleanly, no clicks, no ringing tails.
    tail = int(SR * spec.get("tail", min(0.35, spec.get("len", 1.0) * 0.4)))
    if tail and len(mix) > tail:
        mix[-tail:] *= (np.linspace(1, 0, tail) ** 2.2)[:, None]
    mix[: int(SR * 0.002)] *= np.linspace(0, 1, int(SR * 0.002))[:, None]
    # Loudness by role, so the game only needs a few volume levels; peaks stay under -1 dBFS.
    target = spec.get("lufs", TARGET_LUFS.get(spec.get("group"), -14))
    padded = np.pad(mix, ((0, max(0, int(SR * 0.5) - len(mix))), (0, 0)))
    loud = METER.integrated_loudness(padded)
    if np.isfinite(loud):
        mix = mix * 10 ** ((target - loud) / 20)
    peak = np.max(np.abs(mix)) + 1e-9
    ceiling = 10 ** (spec.get("peak", -1.0) / 20)
    if peak > ceiling:
        mix = mix / peak * ceiling
    return mix


from sfx_recipes import RECIPES  # noqa: E402


def main(ids):
    os.makedirs(OUT, exist_ok=True)
    os.makedirs(PREVIEW, exist_ok=True)
    manifest_path = os.path.join(PREVIEW, "manifest.json")
    manifest = json.load(open(manifest_path, encoding="utf-8")) if os.path.exists(manifest_path) else {}
    for key, spec in RECIPES.items():
        if ids and key not in ids:
            continue
        files = []
        for v in range(spec.get("variants", 3)):
            audio = render(spec, v)
            name = f"{key}_{v}.ogg"
            sf.write(os.path.join(OUT, name), audio, SR, format="OGG", subtype="VORBIS")
            files.append(name)
        manifest[key] = {"files": files, "group": spec.get("group", ""), "title": spec.get("title", key), "note": spec.get("note", "")}
        print("SFX", key, len(files))
    json.dump(manifest, open(manifest_path, "w", encoding="utf-8"), ensure_ascii=False, indent=1)
    # The game reads variant counts from here (assets/audio/sfx/sfx_manifest.json).
    counts = {k: len(v["files"]) for k, v in manifest.items()}
    json.dump(counts, open(os.path.join(OUT, "sfx_manifest.json"), "w", encoding="utf-8"), indent=1, sort_keys=True)


def candidates():
    from sfx_candidates import CANDIDATES
    out = os.path.join(PREVIEW, "cand")
    os.makedirs(out, exist_ok=True)
    listing = {}
    for key, options in CANDIDATES.items():
        listing[key] = {}
        for letter, spec in options.items():
            spec = dict(spec)
            spec.setdefault("group", RECIPES[key]["group"])
            files = []
            for v in range(spec.get("variants", 2)):
                name = f"{key}__{letter}_{v}.ogg"
                sf.write(os.path.join(out, name), render(spec, v), SR, format="OGG", subtype="VORBIS")
                files.append(name)
            listing[key][letter] = {"files": files, "note": spec.get("note", "")}
        print("CAND", key, len(options))
    json.dump(listing, open(os.path.join(PREVIEW, "candidates.json"), "w", encoding="utf-8"), ensure_ascii=False, indent=1)


if __name__ == "__main__":
    sys.path.insert(0, os.path.dirname(__file__))
    if sys.argv[1:2] == ["--candidates"]:
        candidates()
    else:
        main(set(sys.argv[1:]))
