"""Glorious ultimates (round 3): foil, Fourier, prime, lowered light speed.

The developer wants the ultimates to sound sacred and triumphant - a war turning
toward hope. Everything sits in D major: wordless choir, a supersaw glory pad,
Risset bells, timpani-like hits and a deep sub, with library recordings only for
cinematic texture (braam pitched into D, an angelic light spell, crystal sweeps).
"""
from sfx_designed import K, L, N

X = "ult"
D2, A2, D3, FS3, A3, D4, FS4, A4, B4, D5, E5, FS5, A5, D6, FS6 = (
    73.42, 110.0, 146.83, 185.0, 220.0, 293.66, 369.99, 440.0, 493.88, 587.33, 659.26, 739.99, 880.0, 1174.66, 1479.98)


def CH(notes, length, gain=0, attack=.5, hold=0.0, decay=1.0, delay=0.0, voices=5):
    return {"synth": "choir", "notes": notes, "len": length, "gain": gain, "attack": attack, "hold": hold, "decay": decay, "delay": delay, "voices": voices}


def P(notes, length, gain=0, attack=.5, hold=0.0, decay=1.0, lo=600.0, hi=4000.0, delay=0.0):
    return {"synth": "pad", "notes": notes, "len": length, "gain": gain, "attack": attack, "hold": hold, "decay": decay, "from": lo, "to": hi, "delay": delay}


def BL(freq, ring, length, gain=0, delay=0.0):
    return {"synth": "bell", "freq": freq, "ring": ring, "len": length, "gain": gain, "delay": delay}


def strum(freqs, ring, length, gain, spread, delay=0.0):
    return [BL(f, ring, length, gain - i * 1.5, delay + i * spread) for i, f in enumerate(freqs)]


def S(title, length, layers, variants=1, pitches=(0,), **kw):
    spec = {"title": title, "group": X, "len": length, "layers": layers, "variants": variants, "pitches": list(pitches), "comp": None, "prenorm": True}
    spec.update(kw)
    return spec


ANGEL = "MAGAngl_Magic Light Spell Enchantment"
CRYSTAL = "GLASMvmt_Whoosh Glass Crystal Fragments"

GLORY = {
    # ---------------------------------------------------------------- foil: a dimensional strike from above
    "ult_foil": S("大招 · 一向箔 · 展开（神圣的升起）", 1.8, [
        CH([D3, A3, D4], 1.8, 0, attack=1.3, hold=.5, decay=2.0),
        P([D2, A2], 1.8, -6, attack=1.5, lo=300, hi=1500),
        L(ANGEL, 1.6, -6, snap=False),
        L(CRYSTAL, .85, -10, off=.29, delay=.95, snap=False, lp=8000),
        BL(D6, 1.0, 1.0, -12, .2), BL(A5, 1.0, 1.0, -13, .6)], lufs=-17, tail=.02),
    "ult_foil_boom": S("大招 · 一向箔 · 降维（辉煌的落下）", 3.2, [
        L("Braam 035", 3.0, -2, pitch=-6), K(55, 22, .9, 2.8, 0, drive=2.6),
        CH([D3, FS3, A3, D4, FS4], 3.0, -2, attack=.08, hold=.5, decay=1.4),
        P([D2, D3, A3, D4], 3.0, -6, attack=.05, hold=.3, decay=1.2, lo=3000, hi=900),
        *strum([D5, A5, D6], 1.6, 2.8, -6, .06),
        L("Bass Drop & Downer Medium 15", 3.0, -8)], room=.7, wet=.22, lufs=-11, tail=1.2),
    "foil_flatten": S("一向箔 · 目标被压平（一声清亮的钟）", .32, [
        BL(D6, .25, .3, 0), K(150, 70, .04, .1, -8, sweep=.02)], variants=4, pitches=(0, 2, 4, 7), lufs=-16),
    # ---------------------------------------------------------------- Fourier: the universe written as music
    "ult_fourier": S("大招 · 傅里叶 · 采样（钟声与渐起的和声）", 1.2, [
        BL(D5, 1.2, 1.2, 0), BL(A5, 1.0, .65, -4, .55),
        P([D3, A3], 1.2, -10, attack=.8, lo=400, hi=1200),
        L("Computation_Light_20", .7, -14, snap=False)], lufs=-18, tail=.05),
    "fourier_note": S("傅里叶 · 笔尖击中（钟琴音，沿 D 大调五声音阶上升）", .6, [
        BL(D5, .5, .6, 0), N(8000, 4000, .01, .03, -14), K(160, 80, .03, .08, -12, sweep=.01)], room=.35, wet=.15, lufs=-14),
    "ult_fourier_boom": S("大招 · 傅里叶 · 频谱绽放（D 大调合唱）", 2.8, [
        CH([D3, A3, D4, FS4, A4], 2.6, 0, attack=.12, hold=.6, decay=1.2),
        P([D2, D3, A3, D4, FS4], 2.6, -4, attack=.1, hold=.4, decay=1.2, lo=800, hi=5000),
        *strum([D5, FS5, A5, D6], 1.4, 2.4, -4, .07), K(80, 32, .5, 1.2, -4),
        L(ANGEL, 2.0, -10, snap=False)], room=.7, wet=.24, lufs=-12, tail=1.0),
    # ---------------------------------------------------------------- prime: ten war-drum beats climbing to a crown
    "ult_prime": S("大招 · 质数 · 战鼓滚奏（启动）", .5, [
        *[K(120, 55, .06, .15, -12 + i * 2, sweep=.02, delay=i * .09) for i in range(5)],
        P([D3, A3], .5, -8, attack=.45, lo=400, hi=1500)], lufs=-18, tail=.02),
    "prime_beat": S("质数 · 每一拍（定音鼓 + 钟，音高逐拍上升）", .9, [
        K(95, 48, .35, .6, 0, sweep=.03, drive=1.6), N(1200, 300, .08, .25, -10, q=.8),
        BL(D4, .9, .9, -4)], room=.45, wet=.16, lufs=-13),
    "prime_finale": S("质数 · 第十拍后的加冕（全奏和弦）", 3.0, [
        L("Braam 035", 2.8, -4, pitch=-6), K(60, 24, .8, 2.4, 0, drive=2.4),
        CH([D3, FS3, A3, D4, A4], 2.8, -1, attack=.06, hold=.6, decay=1.3),
        P([D2, D3, A3, D4, FS4], 2.8, -4, attack=.05, hold=.4, decay=1.3, lo=4000, hi=1200),
        *strum([A4, D5, FS5, A5, D6], 1.5, 2.6, -5, .05)], room=.7, wet=.22, lufs=-11, tail=1.1),
    # ---------------------------------------------------------------- lowered light speed: time stills, then light floods back
    "ult_lightspeed": S("大招 · 降低光速 · 时间凝滞（深沉合唱升起，光帆掠过）", 6.0, [
        CH([D2, A2, D3], 4.6, 0, attack=2.5, hold=1.0, decay=.5),
        P([D3, A3, D4], 4.6, -6, attack=3.0, hold=.8, decay=.4, lo=300, hi=2500),
        *[N(300, 2600, .35, 1.0, -12, attack=.45, delay=d, lp=3500) for d in (0.3, 1.0, 1.7, 2.4, 3.1)],
        BL(D6, 1.5, 1.6, -14, 1.0), BL(A5, 1.5, 1.6, -15, 2.4), BL(FS6, 1.2, 1.4, -16, 3.6),
        N(2000, 200, 1.0, 1.4, -16, reverse=True, delay=4.6)], lufs=-18, tail=.02),
    "ult_lightspeed_boom": S("大招 · 降低光速 · 光速恢复（光芒万丈）", 3.0, [
        N(200, 12000, .4, 1.0, -6, attack=.002), K(60, 22, .7, 2.2, 0, drive=2.5),
        CH([D4, FS4, A4, D5], 2.8, -1, attack=.05, hold=.6, decay=1.2),
        P([D3, A3, D4, A4], 2.8, -4, attack=.04, hold=.4, decay=1.2, lo=5000, hi=1500),
        *strum([A5, D6, FS6], 1.4, 2.4, -8, .06)], room=.65, wet=.2, lufs=-11, tail=1.1),
}


def apply(recipes):
    recipes.update(GLORY)
