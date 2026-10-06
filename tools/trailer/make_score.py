# Original ambient score for the SKYGUARD trailer (deterministic, numpy only).
import numpy as np, wave
SR = 48000; DUR = 58.0; N = int(SR * DUR)
t = np.arange(N) / SR
rng = np.random.default_rng(7)
L = np.zeros(N); R = np.zeros(N)
def env(a, b, attack, release):
    e = np.zeros(N); i0, i1 = int(a * SR), min(N, int(b * SR))
    seg = np.arange(i1 - i0) / SR; ln = (i1 - i0) / SR
    e[i0:i1] = np.minimum(1, seg / attack) * np.clip((ln - seg) / release, 0, 1)
    return e
def add(sig, pan=0.0, gain=1.0):
    global L, R
    L += sig * gain * np.sqrt(0.5 * (1 - pan)); R += sig * gain * np.sqrt(0.5 * (1 + pan))
hz = lambda n: 440 * 2 ** ((n - 69) / 12)
# Drone pads: A minor add9 colours, slow detuned sines, chord moves with the story.
chords = [(0, 17, [33, 45, 52, 59, 64]), (16, 31, [29, 41, 48, 55, 64]), (30, 45, [36, 43, 50, 55, 62, 67]), (44, 58, [33, 45, 52, 57, 64, 71, 76])]
for a, b, notes in chords:
    e = env(a, b, 5.0, 4.0)
    for k, n in enumerate(notes):
        f = hz(n)
        for d in (-0.12, 0.0, 0.13):
            ph = rng.uniform(0, 6.28)
            vib = 1 + 0.002 * np.sin(2 * np.pi * (0.07 + 0.03 * k) * t)
            s = np.sin(2 * np.pi * (f + d) * vib * t + ph) + 0.18 * np.sin(4 * np.pi * (f + d) * t + ph)
            add(s * e, pan=((k % 3) - 1) * 0.5, gain=0.045 / (1 + 0.25 * k))
# Sub swell rising into the title.
sub = np.sin(2 * np.pi * hz(21) * t) * env(36, 47.2, 9.0, 0.6) * 0.32
add(sub)
# Shimmering bells (glass partials), sparse then denser as the defense grows.
def bell(at, n, g=0.12, pan=0.0):
    i0 = int(at * SR); ln = int(4.5 * SR); i1 = min(N, i0 + ln)
    tt = np.arange(i1 - i0) / SR; f = hz(n)
    s = sum(np.sin(2 * np.pi * f * m * tt) * np.exp(-tt * (1.2 + m * 0.9)) / m for m in (1, 2.76, 5.4))
    s *= np.minimum(1, tt / 0.004)
    sig = np.zeros(N); sig[i0:i1] = s; add(sig, pan, g)
    # echo
    for k, dl in enumerate((0.37, 0.74, 1.11)):
        j0 = i0 + int(dl * SR); j1 = min(N, j0 + (i1 - i0))
        if j0 < N:
            sig = np.zeros(N); sig[j0:j1] = s[: j1 - j0]; add(sig, -pan if k % 2 == 0 else pan, g * 0.45 ** (k + 1))
scale = [69, 72, 76, 79, 81, 84, 88]
for at in (2.0, 6.5, 11.2):
    bell(at, scale[int(at) % 3 + 2], 0.1, 0.3)
k = 0
for at in np.arange(17.0, 23.0, 0.75):
    bell(at, scale[k % len(scale)], 0.07, 0.6 if k % 2 else -0.6); k += 1
for at in np.arange(31.0, 38.0, 0.5):
    bell(at, scale[(k * 3) % len(scale)] + 12 * (k % 2), 0.05, 0.7 if k % 2 else -0.7); k += 1
# Soft "impacts" — filtered noise thumps on the cuts.
def thump(at, g=0.5):
    i0 = int(at * SR); ln = int(2.5 * SR); i1 = min(N, i0 + ln); tt = np.arange(i1 - i0) / SR
    s = np.sin(2 * np.pi * (48 * np.exp(-tt * 3) + 28) * tt) * np.exp(-tt * 2.2)
    sig = np.zeros(N); sig[i0:i1] = s; add(sig, 0, g)
for at in (11.0, 23.0, 25.0, 27.0, 29.0, 31.0, 47.2): thump(at, 0.55 if at != 47.2 else 0.9)
# Air: a slow breathing noise bed.
noise = rng.standard_normal(N)
kern = np.ones(400) / 400
air = np.convolve(noise, kern, mode="same") * 6
air *= (0.5 + 0.5 * np.sin(2 * np.pi * t / 9.0)) * env(0, DUR, 4, 4)
add(air, 0.2, 0.035)
# Reverb-ish smear: a few long feedback delays.
for dl, g in ((0.093, 0.32), (0.141, 0.28), (0.197, 0.24), (0.263, 0.2)):
    d = int(dl * SR)
    for ch in (L, R):
        ch[d:] += ch[:-d] * g
mx = max(np.abs(L).max(), np.abs(R).max())
L, R = L / mx * 0.89, R / mx * 0.89
fade = np.minimum(1, (DUR - t) / 3.0); L *= fade; R *= fade
out = (np.stack([L, R], 1) * 32767).astype("<i2")
w = wave.open("skyguard-trailer/assets/score.wav", "wb"); w.setnchannels(2); w.setsampwidth(2); w.setframerate(SR); w.writeframes(out.tobytes()); w.close()
print("score ok")
