"""Original scores for the four chapters added in the ten-chapter campaign.
Same offline, deterministic synthesis as compose_audio.py (no AI audio service);
each chapter keeps the shared pad / bell / pulse language with its own colour:
  music_6  outer solar system   - wide, slow, low brass-like pads
  music_7  Oort cloud           - sparse, cold, high glassy bells with long gaps
  music_8  stellar neighbourhood - brighter, a rising arpeggio between stars
  music_9  the brane            - a drone and a melody built from the harmonic series
"""
from pathlib import Path
import numpy as np
import wave, subprocess

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / 'assets/audio'
WORK = ROOT / 'tools/audio_work'
WORK.mkdir(parents=True, exist_ok=True)
RATE = 22050

def hz(note): return 440 * 2 ** ((note - 69) / 12)

def save(name, a):
    a = np.tanh(a * 1.1) * .85
    pcm = (np.clip(a, -1, 1) * 32767).astype('<i2')
    file = WORK / (name + '.wav')
    with wave.open(str(file), 'wb') as f:
        f.setnchannels(2); f.setsampwidth(2); f.setframerate(RATE); f.writeframes(pcm.tobytes())
    subprocess.run(['ffmpeg', '-hide_banner', '-loglevel', 'error', '-y', '-i', str(file), '-c:a', 'libvorbis', '-q:a', '5', str(OUT / (name + '.ogg'))], check=True)

def add(a, start, sound, pan=0):
    indices = (np.arange(len(sound)) + int(start * RATE)) % len(a)
    a[indices, 0] += sound * np.sqrt((1 - pan) / 2)
    a[indices, 1] += sound * np.sqrt((1 + pan) / 2)

def bell(freq, length=3.2, decay=1.35):
    t = np.arange(int(RATE * length)) / RATE
    return (np.sin(2 * np.pi * freq * t) * np.exp(-t * decay) + .28 * np.sin(2 * np.pi * freq * 2.003 * t) * np.exp(-t * decay * 2.5) + .1 * np.sin(2 * np.pi * freq * 3.98 * t) * np.exp(-t * decay * 3.7)) * np.minimum(t / .016, 1) * .055

def pads(a, root, chords, gain=.027, bright=.32):
    for j, chord in enumerate(chords):
        t = np.arange(int(RATE * 15)) / RATE
        env = np.minimum(t / 2.7, 1) * np.minimum((15 - t) / 3.8, 1)
        for k, note in enumerate(chord):
            f = hz(root + note)
            pad = np.sin(2 * np.pi * f * t) + bright * np.sin(2 * np.pi * (f * 2 + .09) * t) + .14 * np.sin(2 * np.pi * (f * 3 - .1) * t)
            pad *= env * (gain + .007 * np.sin(t * .45 + k))
            pan = (-.52 if k % 2 else .52)
            add(a, j * 12, pad, pan)
            add(a, j * 12 + .13, pad * .18, -pan)

def pulse(a, root, every=2.0, gain=.045):
    for j in range(int(96 / every)):
        t = np.arange(int(RATE * .7)) / RATE
        p = np.sin(2 * np.pi * hz(root - 12) * t) * np.exp(-t * 7) * np.minimum(t / .018, 1) * gain
        add(a, j * every, p)

def outer():
    a = np.zeros((RATE * 96, 2))
    root = 44
    pads(a, root, [[0, 7, 12, 16], [-3, 4, 9, 16], [-5, 2, 7, 14], [-7, 0, 5, 12], [0, 7, 12, 19], [-3, 4, 9, 14], [-8, -1, 4, 11], [-5, 2, 7, 12]], .031, .22)
    melody = [0, 4, 7, 11, 9, 7, 4, 2, 0, -1, 2, 7, 4, 2, -1, -3]
    for j in range(32):
        if j % 4 == 3: continue
        tone = bell(hz(root + 24 + melody[j % 16]), 4.0, 1.0) * .6
        start = j * 3 + .4
        pan = np.sin(j * .9) * .6
        add(a, start, tone, pan); add(a, start + .5, tone * .3, -pan)
    pulse(a, root, 3.0, .05)
    return a

def oort():
    a = np.zeros((RATE * 96, 2))
    root = 39
    pads(a, root, [[0, 7, 14, 19], [0, 5, 12, 17], [-2, 5, 12, 19], [-5, 2, 9, 14], [0, 7, 14, 21], [-4, 3, 10, 15], [-2, 5, 10, 17], [-5, 2, 7, 14]], .022, .45)
    rng = np.random.default_rng(1601)
    # Ice: high glassy bells, few and far between, ringing a long time.
    scale = [0, 2, 7, 9, 14, 19, 21, 26]
    for j in range(26):
        tone = bell(hz(root + 36 + scale[int(rng.integers(0, len(scale)))]), 5.5, .7) * .5
        start = j * 3.6 + rng.uniform(0, 1.2)
        pan = rng.uniform(-.8, .8)
        add(a, start, tone, pan); add(a, start + .9, tone * .25, -pan); add(a, start + 1.8, tone * .1, pan)
    pulse(a, root, 4.0, .035)
    return a

def neighbourhood():
    a = np.zeros((RATE * 96, 2))
    root = 47
    pads(a, root, [[0, 4, 7, 14], [-5, 2, 7, 11], [-3, 4, 9, 12], [-8, -1, 4, 11], [0, 4, 9, 14], [-5, 2, 7, 14], [-3, 0, 7, 12], [-7, 0, 5, 9]], .027, .32)
    arp = [0, 4, 7, 11, 14, 11, 7, 4]
    for j in range(96):
        if j % 16 in [14, 15]: continue
        tone = bell(hz(root + 24 + arp[j % 8] + (0 if (j // 8) % 2 == 0 else -5)), 2.4, 1.8) * .42
        pan = np.sin(j * .7) * .7
        add(a, j * 1.0 + .3, tone, pan)
    pulse(a, root, 2.0, .04)
    return a

def brane():
    a = np.zeros((RATE * 96, 2))
    root = 38
    t = np.arange(RATE * 96) / RATE
    # A breathing drone on the fundamental, slowly beating against a fifth.
    f0 = hz(root - 12)
    drone = (np.sin(2 * np.pi * f0 * t) + .5 * np.sin(2 * np.pi * (f0 * 1.5 + .07) * t) + .25 * np.sin(2 * np.pi * f0 * 2 * t)) * (.022 + .01 * np.sin(t * .21))
    a[:, 0] += drone; a[:, 1] += drone * .96
    pads(a, root, [[0, 7, 12, 19], [0, 7, 14, 19], [-2, 5, 12, 17], [0, 7, 12, 16], [0, 7, 12, 19], [-5, 2, 9, 14], [-2, 5, 10, 17], [0, 7, 12, 24]], .02, .4)
    # Melody from the harmonic series of the drone: a vibrating string's own notes.
    harmonics = [3, 4, 5, 6, 7, 8, 9, 10, 12, 8, 6, 5]
    for j in range(40):
        if j % 5 == 4: continue
        n = harmonics[j % len(harmonics)]
        tone = bell(f0 * n, 3.6, 1.1) * .55
        start = j * 2.4 + .5
        pan = np.sin(j * 1.1) * .6
        add(a, start, tone, pan); add(a, start + .6, tone * .3, -pan)
    pulse(a, root, 2.4, .05)
    return a

for name, fn in [('music_6', outer), ('music_7', oort), ('music_8', neighbourhood), ('music_9', brane)]:
    save(name, fn())
    print('composed', name)
