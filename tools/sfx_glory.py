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
    # ---------------------------------------------------------------- chapter jump, timed to the 7 s cinematic (ui_fx "jump")
    # 0-1.6 stamp: sub swells, engines spool up, a reversed breath pulls in. 1.6 ignition. 1.6-5.8
    # hyperspace wind with streaks whooshing past ever faster. 2.6 the chapter card blooms in D major,
    # one bell per title glyph (.09 s apart). 3.85 the scale readout flips. 5.8-7.0 deceleration and arrival.
    "jump": S("跃迁到下一章（与 7 秒过场同步）", 7.4, [
        P([D2, A2], 1.8, -14, attack=1.5, hold=.1, decay=.4, lo=200, hi=1400, delay=.1),
        N(300, 7000, .08, 1.5, -8, attack=1.45, hold=1.45, lp=8000, delay=.1),
        {"synth": "zap", "from": 110, "to": 880, "attack": 1.4, "decay": 30.0, "len": 1.5, "gain": -16, "glide": 1.4, "delay": .1, "voices": 4, "harm": 3, "lp": 3000},
        N(2500, 300, .5, .5, -10, reverse=True, delay=1.1),
        K(50, 22, .55, 1.4, 0, drive=2.6, delay=1.6), N(9000, 500, .45, 1.2, -6, delay=1.6),
        L("Braam 035", 1.3, -10, pitch=-6, delay=1.6),
        N(200, 2400, 1.0, 4.4, -17, attack=.4, hold=3.2, lp=3500, delay=1.6),
        *[N(500, 4500, .14, .4, -17 + i * .4, attack=.12, delay=d) for i, d in enumerate((1.85, 2.2, 2.5, 2.75, 2.97, 3.17, 3.35, 3.55, 3.75, 3.95, 4.2, 4.5, 4.85, 5.25))],
        K(72, 30, .55, 1.4, -1, drive=2.2, delay=2.6),
        CH([D3, A3, D4, FS4, A4], 3.8, -1, attack=.12, hold=1.6, decay=1.8, delay=2.6),
        P([D2, D3, A3, D4], 4.0, -6, attack=.15, hold=1.6, decay=2.0, lo=600, hi=4500, delay=2.6),
        *strum([D5, E5, FS5, A5, B4 * 2, D6], 1.0, 1.2, -9, .09, delay=2.75),
        K(1900, 950, .015, .05, -15, sweep=.004, delay=3.72), K(1500, 750, .015, .05, -15, sweep=.004, delay=3.98),
        N(3200, 220, .9, 1.3, -12, attack=.35, lp=5000, delay=5.6),
        K(70, 34, .45, 1.0, -9, delay=6.35), BL(D5, 1.0, 1.0, -15, 6.4)], group="flow", room=.6, wet=.2, lufs=-14, tail=1.0),
    # ---------------------------------------------------------------- loot: crisp coins and a jackpot when a big stream lands
    # The game pitches each coin up a pentatonic step (audio_director.coins), so one variant only.
    "coin": S("金币到账（清脆的金属叮）", .5, [
        BL(2093.0, .2, .45, 0), {"tone": 3135.96, "decay": .05, "len": .18, "gain": -7, "delay": .035},
        {"tone": 1567.98, "decay": .035, "len": .12, "gain": -9}, N(8000, 15000, .01, .04, -12, q=.5),
        L("Ting Coins", .45, -14)], group="reward", room=.12, wet=.08, lufs=-14, tail=.02),
    "coin_jackpot": S("大招结算 · 全部到账（叮——当！）", 1.8, [
        *strum([D6, FS6, 1760.0, 2349.32], 1.2, 1.6, 0, .05), K(140, 70, .04, .12, -8, sweep=.01),
        N(6000, 14000, .25, 1.0, -14, attack=.01), L("Drop Couple of Gold Coins on Coins 03", .7, -6, delay=.05),
        L("Ting Coins", .5, -10, delay=.18)], group="reward", room=.45, wet=.16, lufs=-12, tail=.6),
    # ---------------------------------------------------------------- rewriting pi: the constant played as a melody, then six seams of light
    # 0-2.0 s: the digits of pi ring out as D-major bells, accelerating like a counter, over a rising choir.
    # 2.0 s (PI_IMPACT): six spatial seams rupture - a full D-major bloom and a cascade of six crystal bells.
    "ult_pi": S("大招 · 改写 π · 圆周率奏成旋律（越来越快）", 2.05, [
        *[BL([D5, E5, FS5, 783.99, A5, B4 * 2, 1108.73, D6, 1318.51, FS6][dg], .45, .6, -9 + 5 * i / 23,
              .05 + 1.85 * (1 - (1 - i / 24) ** 1.8))
          for i, dg in enumerate([3, 1, 4, 1, 5, 9, 2, 6, 5, 3, 5, 8, 9, 7, 9, 3, 2, 3, 8, 4, 6, 2, 6, 4])],
        P([D3, A3, D4], 2.05, -10, attack=1.8, hold=.15, decay=.3, lo=400, hi=3200),
        CH([D3, A3], 2.05, -12, attack=1.7, hold=.2, decay=.3),
        N(3000, 300, .5, .5, -10, reverse=True, delay=1.55)], lufs=-16, tail=.02),
    "ult_pi_boom": S("大招 · 改写 π · 六道空间裂缝（辉煌的绽放）", 2.8, [
        K(55, 22, .7, 2.4, 0, drive=2.6), N(200, 9000, .3, .8, -8, attack=.002),
        CH([D3, FS3, A3, D4, FS4], 2.6, -2, attack=.06, hold=.5, decay=1.3),
        P([D2, D3, A3, D4], 2.6, -5, attack=.05, hold=.4, decay=1.2, lo=4500, hi=1200),
        *strum([FS6, D6, A5, FS5, D5, A4], 1.2, 2.0, -6, .05),
        L(CRYSTAL, .9, -9, snap=False, lp=9000)], room=.7, wet=.22, lufs=-11, tail=1.0),
}


def apply(recipes):
    recipes.update(GLORY)
