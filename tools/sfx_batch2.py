"""Batch 2: every ultimate, the bosses, chapter flow and celestial-body attacks.

Same house style as sfx_designed.py: a synthesised core (sub, signature energy,
air) with at most one or two library recordings for texture. Timings follow the
sequences in combat.gd (ULT_DURATION, *_IMPACT) so the launch file runs up to the
impact event, where the game cuts it and plays the matching *_boom.
"""
from sfx_designed import C, K, L, N, T, Z

X = "ult"
B = "boss"
F = "flow"
O = "body"


def chord(freqs, decay, length, gain, delay=0.0, spread=0.0, **kw):
    # A soft tonal chord; `spread` staggers the notes like a strum.
    return [T(f, decay, length, gain - i * 1.5, delay + i * spread, **kw) for i, f in enumerate(freqs)]


def S(title, group, length, layers, variants=1, pitches=(0,), **kw):
    spec = {"title": title, "group": group, "len": length, "layers": layers, "variants": variants, "pitches": list(pitches)}
    spec.update(kw)
    return spec


BIG = {"comp": None, "prenorm": True}

BATCH2 = {
    # ---------------------------------------------------------------- ultimates
    # Photoid: a lone particle at light speed. Thin high whine, then a doppler rush into the strike (2.2 s).
    "ult_photoid": S("大招 · 光粒 · 显形与逼近", X, 2.2, [
        T(1760, 3.0, 2.1, -10, glide=7, fm=.15, ratio=2.0), T(1766, 3.0, 2.1, -12, glide=7),
        Z(300, 2400, 4.0, 1.0, -8, glide=.35, voices=3, harm=3, lp=6000, delay=1.2),
        N(400, 9000, .35, .9, -6, q=.7, attack=.6, delay=1.3, lp=9000),
        L("bullet_flyby_fast_06", .5, -10, delay=1.72)], lufs=-20, tail=.02, **BIG),
    "ult_photoid_boom": S("大招 · 光粒 · 命中", X, 2.6, [
        N(12000, 2000, .05, .2, -2), K(70, 24, .6, 2.0, 0, sweep=.05, drive=3.0),
        T(1568, .9, 2.2, -10), T(2093, .8, 2.0, -12), T(3136, .6, 1.8, -14),
        L("Explosive Hit 10 Filtered, Low End", 1.5, -5), N(5000, 300, .6, 2.2, -10, hold=.05)], room=.6, wet=.18, lufs=-11, tail=1.0, **BIG),
    # Droplet: condensing crystal (1.15 s) -> instant pass -> arrival -> shatters.
    # Droplet charge: matter condensing - a growing charge recording, crystal grains drawn in
    # faster and faster, a crystal sweep and a swelling sub, all peaking just before the pass.
    "ult_droplet": S("大招 · 水滴 · 凝聚", X, 1.15, [
        L("casting_charge_matter_grow_04", 1.15, 0, snap=False, lp=7500),
        L("GLASMvmt_Whoosh Glass Crystal Fragments", .85, -6, snap=False, off=.29, lp=8000, delay=.27),
        *[T(f, .025, .06, -16 + i * .5, round(1.1 * (i / 12) ** .6, 3)) for i, f in enumerate(
            (2093, 2637, 2349, 3136, 2793, 2093, 3520, 2637, 3136, 2349, 2793, 3520))],
        dict(K(48, 40, 3.0, 1.12, -14, sweep=1.0, drive=1.3), attack=.85)], lufs=-19, tail=.02, **BIG),
    # The pass: no pitched tone (a falling tone read as a croak) - a hypersonic streak, a crack, a thump.
    "ult_droplet_boom": S("大招 · 水滴 · 瞬间贯穿", X, .5, [
        N(800, 14000, .05, .18, -2, q=.6, attack=.002, lp=11000), L("bullet_flyby_fast_05", .4, -3, pitch=5),
        N(10000, 4000, .01, .04, 0), K(160, 50, .1, .3, -3, sweep=.02, drive=2.0)], lufs=-13, **BIG),
    "drop_arrive": S("水滴 · 抵达定格", X, 1.4, [
        N(10000, 3000, .02, .1, 0), K(80, 26, .5, 1.3, 0, sweep=.04, drive=3.0),
        L("glass_impact_break_002", .8, -6, lp=8000), T(3951, .5, 1.2, -12)], room=.5, wet=.15, lufs=-12, **BIG),
    "drop_shatter": S("水滴 · 目标碎裂", X, .35, [
        L("glass_impact_break_small_014", .35, 0, lp=7500), K(140, 60, .05, .12, -4, sweep=.02), T(3300, .06, .12, -12)],
        variants=4, pitches=(0, 2, -2, 4)),
    # Foil: dimensions folding (opens at 1.8 s), then everything pressed flat.
    "ult_foil": S("大招 · 一向箔 · 展开", X, 1.8, [
        T(6000, 4.0, 1.75, -10, glide=-2), T(6037, 4.0, 1.75, -11, glide=-2), T(3000, 4.0, 1.75, -14),
        N(9000, 2000, 1.2, 1.75, -16, attack=.5), N(6000, 300, .3, .5, -8, reverse=True, delay=1.3)], lufs=-21, tail=.02, **BIG),
    "ult_foil_boom": S("大招 · 一向箔 · 降维压平", X, 3.0, [
        K(60, 22, .9, 2.8, 0, sweep=.2, drive=2.2), Z(400, 30, 1.2, 2.8, -6, glide=.9, voices=3, harm=4, lp=1200),
        L("Pile of Scrap Metal - Metal Scrap Pile", 1.6, -10, lp=6000), N(3000, 120, .9, 2.8, -10)], room=.55, lufs=-12, tail=1.0, **BIG),
    "foil_flatten": S("一向箔 · 目标被压平", X, .2, [
        N(5000, 1500, .05, .18, 0, q=.8, lp=7000), K(140, 70, .04, .1, -6, sweep=.02)], variants=4, pitches=(0, 2, -2, 3)),
    # Fourier: radar sampling, a note per target along a scale, then the spectrum chord.
    "ult_fourier": S("大招 · 傅里叶 · 采样", X, 1.2, [
        T(1760, .25, .5, -2), T(1760, .25, .5, -6, delay=.55), N(600, 3000, 1.0, 1.2, -16, attack=.2, lp=4000),
        Z(220, 440, 2.0, 1.2, -14, glide=.8, voices=2, harm=2, lp=2000)], lufs=-20, tail=.05, **BIG),
    "fourier_note": S("傅里叶 · 笔尖击中（音高随序号沿音阶上升）", X, .4, [
        T(880, .18, .4, 0, fm=.3, ratio=3.0), T(1760, .08, .2, -10), K(150, 70, .04, .1, -8, sweep=.02)], room=.3, wet=.12),
    "ult_fourier_boom": S("大招 · 傅里叶 · 频谱绽放", X, 2.4, [
        *chord([220, 330, 440, 554, 659, 880, 1109], 1.2, 2.3, -2, spread=.03), K(90, 35, .3, .8, -6),
        N(400, 6000, .8, 2.0, -16, attack=.1)], room=.6, wet=.2, lufs=-13, tail=1.0, **BIG),
    # Prime: a matrix boot, then ten beats - the game plays prime_beat rising up a scale.
    "ult_prime": S("大招 · 质数 · 矩阵启动", X, .5, [
        T(1320, .03, .06, -4), T(1760, .03, .06, -4, .08), T(2217, .03, .06, -4, .16), T(2637, .03, .06, -4, .24),
        L("Glitch_Error_Malfunction_018", .4, -12), K(120, 60, .1, .3, -8)], lufs=-18, **BIG),
    "prime_beat": S("质数 · 每一拍打击（音高随质数上升）", X, .5, [
        K(110, 38, .15, .45, 0, drive=2.4), T(440, .18, .4, -6, fm=.5, ratio=2.0), N(4000, 800, .06, .2, -10)], room=.25),
    # Mandelbrot: a fractal bloom that keeps rising until it covers everything (3.5 s).
    "ult_mandelbrot": S("大招 · 曼德博 · 分形展开", X, 3.5, [
        Z(110, 880, 6.0, 3.4, -6, glide=1.6, voices=6, detune=.012, harm=4, lp=5000, delay=.6),
        Z(165, 1320, 6.0, 3.4, -10, glide=1.6, voices=4, detune=.015, harm=3, lp=6000, delay=.8),
        N(300, 5000, 3.0, 3.4, -14, attack=2.5, lp=6000), K(55, 40, 3.0, 3.4, -12, sweep=1.0, drive=1.2)], lufs=-17, tail=.05, **BIG),
    "ult_mandelbrot_boom": S("大招 · 曼德博 · 吞没", X, 2.2, [
        *chord([110, 165, 220, 330, 440], 1.0, 2.1, -3), K(70, 26, .6, 1.8, 0, drive=2.0), N(5000, 200, .6, 2.0, -10)],
        room=.6, wet=.18, lufs=-12, tail=1.0, **BIG),
    # Lowered light speed: time dilates for six seconds, five sails sweep, the seal, then light returns.
    "ult_lightspeed": S("大招 · 降低光速 · 时间变慢", X, 6.0, [
        Z(220, 40, 4.0, 5.9, -8, glide=2.0, voices=4, harm=4, lp=900),
        *[N(300, 2600, .35, 1.0, -9, attack=.45, delay=d, lp=3500) for d in (0.3, 1.0, 1.7, 2.4, 3.1)],
        N(2000, 200, 1.0, 1.4, -14, reverse=True, delay=4.6)], lufs=-19, tail=.02, **BIG),
    "ult_lightspeed_boom": S("大招 · 降低光速 · 光速恢复", X, 2.6, [
        N(200, 12000, .4, 1.0, -3, attack=.002), K(60, 22, .7, 2.2, 0, drive=2.5),
        *chord([1319, 1976, 2637], .8, 2.2, -10), N(6000, 400, .8, 2.4, -10)], room=.55, lufs=-11, tail=1.0, **BIG),
    # Rewriting pi: reality stutters, pitch wobbles, then the geometry crashes (2.0 s).
    "ult_pi": S("大招 · 改写 π · 现实卡顿", X, 2.0, [
        L("Glitch_Factory_01_Decimated_01", 1.9, -6), Z(440, 330, 3.0, 1.9, -8, glide=1.0, voices=3, fm=2.5, ratio=.5, harm=3, lp=4000),
        L("Malfunction Glitch Short", 1.5, -10, delay=.4), N(1000, 8000, .6, 1.0, -12, attack=.7, delay=1.0)], lufs=-19, tail=.02, **BIG),
    "ult_pi_boom": S("大招 · 改写 π · 几何崩塌", X, 2.2, [
        L("PM_GC_DISTORTED_GLITCH_2", 1.5, -3), K(65, 24, .6, 1.8, 0, drive=3.0),
        C(80, 1.2, .5, -8, 1500, seed=11), N(4000, 150, .7, 2.0, -9)], room=.4, lufs=-11, tail=.8, **BIG),
    # Dimensional resonance: the strings appear (1.3 s), ring harder, and snap at 4.4 s.
    "ult_strings": S("大招 · 维度震荡 · 弦的共鸣", X, 4.4, [
        {"synth": "beat", "freq": 55, "beat": 1.5, "decay": 8.0, "len": 4.3, "gain": -8, "attack": 1.5},
        *[T(f, 1.2, 1.8, -8, d, fm=.2, ratio=2.0) for f, d in ((330, 1.3), (550, 1.9), (880, 2.6), (660, 3.2), (1100, 3.7))],
        N(400, 4000, 3.0, 4.3, -16, attack=3.5, lp=5000)], room=.5, wet=.18, lufs=-18, tail=.02, **BIG),
    "ult_strings_boom": S("大招 · 维度震荡 · 弦断", X, 2.8, [
        N(9000, 3000, .02, .08, 0), K(70, 24, .7, 2.4, 0, drive=2.8),
        {"synth": "beat", "freq": 110, "beat": 6, "decay": 1.2, "len": 2.6, "gain": -4},
        T(880, .9, 2.0, -10), L("Impact 045", 1.5, -6)], room=.55, lufs=-11, tail=1.0, **BIG),
    # ---------------------------------------------------------------- bosses
    "boss_alarm": S("Boss · 登场警报", B, 3.0, [
        L("Braam 035", 2.8, 0), K(50, 30, 1.5, 2.6, -4, sweep=.4, drive=1.5),
        T(392, .25, .45, -10, fm=.6, ratio=2.0), T(392, .25, .45, -11, .7, fm=.6, ratio=2.0)], room=.5, lufs=-11, tail=1.0, **BIG),
    "boss_tick": S("Boss · 倒计时滴答", B, .25, [L("Clock 070", .2, 0), K(160, 80, .03, .08, -8, sweep=.01)],
        variants=3, swap={"0": [{"slice": 0}, {"slice": 2}, {"slice": 4}]}),
    "boss_windup": S("Boss · 技能蓄力", B, 1.4, [
        L("Riser 088", 1.35, -4, off=2.2, snap=False), Z(120, 900, 6.0, 1.35, -8, glide=.9, voices=3, harm=4, lp=3000),
        K(50, 40, 2.0, 1.35, -14, sweep=.6)], lufs=-17, tail=.05, **BIG),
    "boss_meteor_rain": S("Boss 技能 · 流星雨", B, 2.0, [
        *[N(500, 3500, .2, .6, -4 - i, attack=.25, delay=i * .22, lp=5000) for i in range(5)],
        *[K(90, 35, .2, .5, -6 - i, delay=.3 + i * .25, drive=2.0) for i in range(5)],
        L("Distant Blast 17", 1.4, -8, delay=.6)], room=.4, lufs=-13, **BIG),
    "boss_tidal_shield": S("Boss 技能 · 潮汐护盾", B, 1.6, [
        {"synth": "beat", "freq": 82, "beat": 3, "decay": 1.0, "len": 1.5, "gain": 0, "attack": .1},
        Z(300, 1200, 1.0, 1.0, -8, glide=.3, voices=4, harm=3, lp=4000), L("Water, Liquid Impact, Bubble, Sci Fi", 1.0, -10)], room=.4, lufs=-14, **BIG),
    "boss_summon": S("Boss 技能 · 召唤", B, 1.6, [
        N(4000, 300, .3, .6, -4, reverse=True), K(70, 30, .4, 1.0, 0, drive=2.0, delay=.58),
        Z(200, 50, .6, 1.0, -8, glide=.4, voices=3, harm=4, lp=1500, delay=.58), T(523, .5, .9, -12, .6)], room=.45, lufs=-13, **BIG),
    "boss_siege_beam": S("Boss 技能 · 攻城光束", B, 2.0, [
        Z(160, 90, 1.2, 1.9, 0, glide=.6, voices=6, detune=.01, harm=6, lp=2500), N(1500, 400, 1.0, 1.9, -5, q=1.2, hold=.6),
        K(60, 28, .5, 1.2, -3, drive=2.5), L("Laser Source_3", 1.2, -10)], lufs=-12, **BIG),
    "boss_corona": S("Boss 技能 · 日冕爆发", B, 2.0, [
        N(900, 150, .9, 1.9, 0, q=1.4, attack=.08, hold=.2), K(55, 24, .7, 1.8, -2, drive=2.5),
        L("Heavy Magical Explosion_SI 03", 1.5, -7, lp=4000)], room=.45, lufs=-12, **BIG),
    "boss_magnetic_field": S("Boss 技能 · 磁场展开", B, 1.8, [
        {"synth": "beat", "freq": 60, "beat": 10, "decay": 1.2, "len": 1.7, "gain": 0},
        C(70, 1.5, .8, -6, 2000, seed=21), L("DEFECT_Electro_Magnetic_29", 1.5, -8), K(80, 35, .3, .8, -6)], room=.35, lufs=-13, **BIG),
    "boss_devour": S("Boss 技能 · 吞噬", B, 2.2, [
        N(6000, 120, .9, 1.4, -2, reverse=True), Z(400, 25, 1.4, 2.0, -4, glide=1.0, voices=4, harm=4, lp=900),
        K(45, 20, .9, 2.0, 0, sweep=.4, drive=2.8, delay=1.35)], room=.5, lufs=-12, **BIG),
    "boss_broken": S("Boss · 技能被打断", B, 1.4, [
        L("glass_impact_break_falling_debris_004", 1.0, 0, lp=8000), L("PowerDown_DDM40", .8, -5), K(110, 40, .2, .5, -4)], room=.35, lufs=-13, **BIG),
    "boss_enrage": S("Boss · 狂暴", B, 2.4, [
        L("Braams_07", 2.3, 0), K(45, 22, 1.0, 2.2, -2, sweep=.3, drive=3.0), N(1200, 200, 1.0, 2.0, -8, q=1.2)], room=.5, lufs=-11, tail=.8, **BIG),
    "boss_death": S("Boss · 被摧毁", B, 3.6, [
        N(11000, 2000, .04, .15, -2), K(50, 18, 1.2, 3.4, 0, sweep=.15, drive=3.2),
        L("explosion_large_08", 3.4, -2), L("Medium Realistic Explosion 15", 1.6, -5, delay=.12),
        L("building_collapse_debris_falling_rock_rubble_glass_010", 2.6, -10, delay=.6), N(3500, 100, 1.2, 3.4, -8, hold=.1)],
        room=.6, wet=.16, lufs=-10, tail=1.4, **BIG),
    "boss_escort": S("Boss · 放出护卫", B, .6, [
        N(600, 3000, .2, .55, -2, attack=.15, lp=4500), K(110, 50, .08, .25, -6)], variants=2, pitches=(0, 2)),
    "deflect": S("磁星 · 子弹被磁场偏转", B, .3, [
        Z(1300, 2100, .12, .3, 0, glide=.06, voices=2, harm=2, lp=4500), L("Hit Impact Metal Scrap Debris_UC 06", .2, -8)],
        variants=3, pitches=(0, 2, -2)),
    # ---------------------------------------------------------------- chapter flow
    "victory": S("通关", F, 4.0, [
        K(60, 30, .8, 2.0, -2, drive=2.0), *chord([262, 330, 392, 523, 659, 784], 2.5, 3.8, 0, spread=.06),
        N(300, 6000, 1.5, 3.5, -16, attack=.4)], room=.6, wet=.22, lufs=-13, tail=1.5, **BIG),
    "failed": S("防线失守", F, 3.0, [
        L("Downer 111", 2.9, 0), Z(440, 110, 1.6, 2.6, -8, glide=1.2, voices=3, harm=3, lp=2000),
        L("PowerDown_DDM40", .8, -8, delay=.3)], room=.5, lufs=-14, tail=1.0, **BIG),
    "jump": S("跃迁到下一章", F, 3.4, [
        N(200, 8000, 1.6, 1.6, -6, attack=1.4, lp=9000), Z(110, 1760, 6.0, 1.6, -8, glide=.9, voices=4, harm=3, lp=5000),
        N(9000, 400, .5, 1.6, 0, delay=1.6), K(55, 24, .6, 1.6, 0, drive=2.5, delay=1.6),
        *chord([220, 330, 440], 1.0, 1.6, -10, delay=1.65)], room=.55, lufs=-12, tail=.9, **BIG),
    # ---------------------------------------------------------------- celestial body attacks (kept modest: they are frequent)
    "body_shell": S("天体 · 重炮弹爆炸", O, .45, [K(90, 34, .15, .4, 0, drive=2.2), L("explosion_large_no_tail_03", .4, -5, pitch=-1), N(3000, 500, .12, .35, -10)],
        variants=3, pitches=(0, -1, 1)),
    "body_swarm": S("天体 · 微型导弹群", O, .5, [*[N(2500, 900, .08, .2, -3 - i, delay=i * .07, lp=5000) for i in range(4)],
        *[K(150, 70, .04, .1, -8, delay=i * .07, sweep=.015) for i in range(4)]], variants=2, pitches=(0, 2)),
    "body_beam": S("天体 · 光束", O, .35, [Z(3000, 1600, .12, .3, 0, glide=.05, voices=3, harm=3, lp=7000), K(130, 60, .05, .15, -6)],
        variants=3, pitches=(0, 2, -2)),
    "body_rail": S("天体 · 磁轨贯穿", O, .4, [Z(5200, 900, .05, .25, -4, glide=.04, voices=2, harm=4, lp=7000), K(100, 40, .1, .3, 0, drive=2.0), N(8000, 3000, .01, .04, -6)],
        variants=3, pitches=(0, -1, 1)),
    "body_chain": S("天体 · 连锁闪电", O, .45, [C(40, .4, .2, 0, 1800, seed=31), *[Z(4000 - i * 400, 1500, .02, .06, -6 - i, glide=.015, delay=i * .06) for i in range(4)]],
        variants=3, pitches=(0, 2, -2)),
    "body_cluster": S("天体 · 集束弹", O, .55, [K(100, 40, .12, .35, 0, drive=2.0), *[N(3500, 700, .07, .2, -6 - i, delay=.08 + i * .07) for i in range(4)]],
        variants=2, pitches=(0, -1)),
    "body_gravity": S("天体 · 引力井", O, .7, [K(65, 26, .3, .65, 0, sweep=.12), Z(500, 70, .3, .6, -6, glide=.2, voices=2, harm=3, lp=1200)],
        variants=2, pitches=(0, -1)),
    "body_ring": S("天体 · 冲击环", O, .5, [N(300, 3000, .2, .45, -2, attack=.03, lp=5000), K(100, 40, .12, .35, 0)], variants=2, pitches=(0, 2)),
    "body_wave": S("天体 · 波阵面", O, .55, [N(200, 2200, .25, .5, 0, attack=.08, q=1.4, lp=4000), {"synth": "beat", "freq": 98, "beat": 4, "decay": .3, "len": .5, "gain": -6}],
        variants=2, pitches=(0, 2)),
    "body_quake": S("天体 · 震荡", O, .7, [K(55, 25, .3, .65, 0, sweep=.1, drive=2.4), N(400, 90, .3, .6, -4, q=1.2), L("rock impact medium 26", .4, -10)],
        variants=2, pitches=(0, -1)),
    "body_meteor": S("天体 · 流星雨", O, .7, [N(800, 3000, .15, .4, -4, attack=.2, lp=5000), K(95, 36, .12, .35, 0, delay=.25, drive=2.0), K(110, 40, .1, .3, -5, delay=.42, drive=2.0)],
        variants=2, pitches=(0, 1)),
    "body_prism": S("天体 · 棱镜折射", O, .45, [Z(1200, 1000, .15, .35, 0, glide=.05, voices=2, harm=2, lp=4500),
        *chord([1319, 1661, 1976], .1, .3, -6, spread=.03), K(130, 60, .05, .15, -6)], variants=2, pitches=(0, 2)),
}


def apply(recipes):
    recipes.update(BATCH2)
