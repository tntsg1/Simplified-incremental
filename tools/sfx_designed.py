"""House-designed weapons, kills and nuke (round 2, 2026-10-13).

The developer asked for the cannons, missiles and nuke to be designed rather than
picked from a library. The core of every sound is synthesised for one coherent
house style: a pitch-swept sub thump for weight, a signature energy layer per
weapon, and an air/pressure layer. A single library recording adds real-world
texture underneath. apply(RECIPES) replaces the library-only versions.
"""


def K(f0, f1, decay, length, gain=0, sweep=.04, drive=1.8, delay=0):
    return {"synth": "kick", "from": f0, "to": f1, "decay": decay, "len": length, "gain": gain, "sweep": sweep, "drive": drive, "delay": delay}


def N(f0, f1, decay, length, gain=0, q=1.0, attack=.003, hold=0.0, delay=0, **kw):
    return dict({"synth": "noise", "from": f0, "to": f1, "decay": decay, "len": length, "gain": gain, "q": q, "attack": attack, "hold": hold, "delay": delay}, **kw)


def Z(f0, f1, decay, length, gain=0, glide=.06, delay=0, **kw):
    return dict({"synth": "zap", "from": f0, "to": f1, "decay": decay, "len": length, "gain": gain, "glide": glide, "delay": delay}, **kw)


def C(count, length, decay, gain, hp, seed=3):
    return {"synth": "crackle", "count": count, "len": length, "decay": decay, "gain": gain, "hp": hp, "seed": seed}


def L(src, length, gain, delay=0, **kw):
    return dict({"src": src, "len": length, "gain": gain, "delay": delay, "snap": True}, **kw)


def T(freq, decay, length, gain, delay=0, **kw):
    return dict({"tone": freq, "decay": decay, "len": length, "gain": gain, "delay": delay}, **kw)


DESIGNED = {
    # 01 city - missile silo: ignition click, sub kick, rocket exhaust hiss.
    "w0_fire": {"len": .55, "slap": .09, "layers": [
        K(140, 55, .09, .35, -2, sweep=.03), N(2200, 700, .22, .5, -10, q=.8, attack=.006, lp=5000),
        L("Rocket Launcher - Shot - 04", .5, -5, lp=5500), N(6000, 4000, .006, .02, -12)]},
    "w0_hit": {"len": .5, "layers": [
        K(110, 40, .16, .45, 0, drive=2.2), L("explosion_large_no_tail_03", .5, -3, pitch=2), C(25, .35, .12, -12, 2000)]},
    # 02 earth - orbital kinetic rod: deep driven sub, electromagnetic snap, air crack, slap.
    "w1_fire": {"len": .8, "slap": .12, "layers": [
        K(90, 32, .22, .6, 0, sweep=.06, drive=2.5), Z(5200, 900, .07, .3, -8, glide=.05, voices=3, harm=4, lp=7000),
        N(9000, 3000, .012, .05, -6), L("DS_Heavy_03_NoReverb_Shot-2", .7, -5)]},
    "w1_hit": {"len": .9, "layers": [
        K(70, 26, .3, .8, 0, sweep=.07, drive=2.5), L("Impact 038", .9, -3), L("rock impact medium 26", .5, -9),
        N(400, 120, .35, .8, -8, q=.8)]},
    # 03 inner system - coronal slash: rising air sweep and a rising energy zing.
    "w2_fire": {"len": .4, "layers": [
        N(700, 4200, .12, .3, -2, q=.6, attack=.03), Z(1400, 2600, .1, .3, -5, glide=.1, voices=4, detune=.02, harm=3, lp=8000),
        K(160, 70, .05, .15, -6, sweep=.02), L("Energy Gun - shot_single_2", .4, -9)]},
    "w2_hit": {"len": .3, "layers": [
        N(3200, 1400, .08, .25, 0, q=.5, lp=6000), Z(2200, 700, .05, .2, -4, glide=.03, harm=2, lp=4000), K(130, 60, .05, .12, -3, sweep=.02)]},
    # 04 outer system - gravity well: a long falling sub and a pitch dive.
    "w3_fire": {"len": .9, "layers": [
        K(70, 28, .35, .8, 0, sweep=.15, drive=1.5), Z(600, 80, .3, .8, -4, glide=.25, voices=2, harm=3, lp=1500),
        L("Bass Drop & Downer Fast 12", .8, -7)]},
    # Collapse: air sucked inward (reversed sweep), then the implosion thump.
    "w3_hit": {"len": 1.0, "layers": [
        N(5000, 400, .2, .35, -4, reverse=True), K(70, 25, .3, .6, 0, drive=2.0, delay=.33),
        L("Impact 021", .6, -6, delay=.33)]},
    # 05 Oort cloud - ice shotgun: punch plus a glassy tone cluster.
    "w4_fire": {"len": .5, "layers": [
        K(120, 50, .1, .3, 0, sweep=.03), L("Sci Fi Shotgun Burst_04", .5, -3), N(7000, 4000, .012, .04, -6),
        T(3400, .06, .12, -10, .005), T(4300, .05, .1, -11, .015), T(5200, .04, .09, -12, .025)]},
    "w4_hit": {"len": .5, "layers": [
        L("glass_impact_break_small_014", .5, 0, lp=6000), T(2900, .05, .1, -9), T(3700, .04, .09, -10, .01),
        T(4600, .03, .08, -11, .02), K(150, 70, .05, .12, -6, sweep=.02)]},
    # 06 stellar neighbourhood - light lance: wide FM laser over a light thump.
    "w5_fire": {"len": .6, "room": .2, "layers": [
        Z(3600, 1400, .25, .55, 0, glide=.12, voices=5, detune=.008, fm=.4, ratio=2.0, harm=4, lp=9000),
        K(120, 50, .08, .25, -4, sweep=.03), N(8000, 2000, .1, .2, -10), L("Blast Laser 2", .5, -10)]},
    "w5_hit": {"len": .4, "layers": [
        N(2600, 1100, .1, .35, 0, q=.7, hold=.05, lp=6000), Z(1600, 900, .1, .3, -5, harm=2, lp=3500), C(15, .3, .1, -14, 2500), K(140, 60, .05, .12, -6, sweep=.02)]},
    # 07 Milky Way - pulsar lighthouse: a tight tonal beat fired in fours, tuned to a scale.
    "w6_fire": {"len": .14, "variants": 4, "pitches": [0, 2, 4, 5], "comp": -14, "layers": [
        T(880, .05, .1, 0, glide=-12, fm=.8, ratio=2.0), K(170, 70, .04, .1, -2, sweep=.015), N(9000, 7000, .004, .015, -9)]},
    "w6_hit": {"len": .12, "pitches": [0, 2, 4], "layers": [
        T(1320, .03, .06, -3), N(6000, 3000, .03, .08, 0), K(180, 80, .025, .06, -6, sweep=.01)]},
    # 08 supercluster - relativistic jets: roaring filtered plasma over a driven sub.
    "w7_fire": {"len": .8, "layers": [
        N(1800, 350, .25, .7, 0, q=1.2, attack=.01, hold=.1), K(80, 35, .2, .5, -1, drive=2.0),
        Z(900, 300, .3, .6, -8, glide=.2, voices=3, harm=6, lp=2500), L("annihilation_mech_weapon_scifi_shot_004", .7, -9)]},
    "w7_hit": {"len": .8, "layers": [
        K(80, 30, .25, .6, 0, drive=2.0), L("Weapon Bomb Explosion Sci-Fi Plasma-04", .7, -3), N(2500, 400, .25, .6, -8)]},
    # 09 observable universe - cosmic web: arcing crackle and three quick chirps hopping the net.
    "w8_fire": {"len": .55, "layers": [
        dict(C(60, .5, .25, 0, 1500, seed=5), lp=6500), Z(4000, 1500, .03, .08, -5, glide=.02), Z(3500, 1300, .03, .08, -6, glide=.02, delay=.06),
        Z(4500, 1700, .03, .08, -7, glide=.02, delay=.13), K(140, 60, .06, .15, -6, sweep=.02),
        L("electric_surge_blast_04", .5, -11, off=.2, lp=6000)]},
    "w8_hit": {"len": .35, "layers": [
        dict(C(30, .3, .12, 0, 2000, seed=9), lp=5000), K(150, 60, .05, .12, -5, sweep=.02), Z(3000, 1200, .03, .06, -6, glide=.02)]},
    # 10 brane - standing wave: two close tones beating against each other.
    "w9_fire": {"len": .9, "room": .3, "layers": [
        {"synth": "beat", "freq": 110, "beat": 5, "decay": .4, "len": .9, "gain": 0},
        K(90, 36, .2, .5, -2), Z(2200, 550, .2, .5, -9, glide=.15, voices=3, harm=3, lp=5000),
        L("Robo_LaserBlast_Medium_027", .6, -9)]},
    "w9_hit": {"len": .6, "layers": [
        {"synth": "beat", "freq": 220, "beat": 7, "decay": .25, "len": .6, "gain": 0},
        L("ResonantRustyDoor_impact_hard_11", .6, -7), K(100, 40, .12, .3, -4)]},
    # Turrets fire constantly: a tiny clean tick with a little weight.
    "turret": {"len": .07, "variants": 4, "pitches": [0, 2, -2, 4], "comp": -12, "layers": [
        K(200, 90, .025, .06, 0, sweep=.01), N(7000, 4000, .012, .04, -4), T(1800, .015, .03, -12)]},
    "hit_rock": {"len": .14, "variants": 4, "pitches": [0, 2, -2, 3], "layers": [
        L("stone_impact_hammer_015", .14, 0), K(180, 80, .03, .08, -5, sweep=.01)]},
    "hit_ship": {"len": .16, "variants": 4, "pitches": [0, 2, -2, 3], "swap": {"0": [{"slice": 0}, {"slice": 1}, {"slice": 2}, {"slice": 3}]},
        "layers": [L("Hit Impact Hard Metal Scrap Debris_UC 01", .16, 0), K(170, 75, .03, .08, -5, sweep=.01)]},
    "kill": {"len": .45, "variants": 4, "pitches": [0, 1, -1, 2], "layers": [
        K(120, 42, .12, .35, 0, drive=2.0), L("explosion_large_no_tail_03", .45, -3, pitch=3), C(20, .3, .1, -12, 2500)]},
    "kill_big": {"len": 1.1, "room": .3, "layers": [
        K(75, 28, .3, .8, 0, drive=2.5), L("Medium Realistic Explosion 15", 1.1, -2),
        L("building_collapse_debris_impact_glass_short_009", .6, -10, delay=.05), N(600, 120, .4, 1.0, -8)]},
}

NUKE_LAUNCH = [
    K(100, 40, .12, .4, -3, sweep=.04, drive=2.0),
    N(2000, 500, .6, 1.3, -10, q=.9, attack=.01, hold=.2, lp=4500),
    {"src": "Rocket Launcher - Shot - 04", "len": .9, "gain": -4, "snap": True, "lp": 5500},
    # The warhead's climb: a rising tone and a riser, both peaking right before detonation.
    Z(150, 1800, 6.0, 1.22, -12, glide=.6, voices=3, harm=3, lp=4000, delay=.2),
    {"src": "Riser 078", "off": 2.25, "len": 1.27, "gain": -6, "delay": .15, "fade": .04},
    # The air pulled away just before the flash.
    {"src": "Boom 040", "len": .44, "gain": -2, "reverse": True, "fade_in": .3, "delay": .98, "fade": .005},
]
NUKE_BOOM = [
    K(55, 22, .8, 2.6, 0, sweep=.12, drive=3.0),
    N(3000, 150, .7, 2.6, -5, q=1.4, hold=.15),
    {"src": "Boom 005", "len": 3.0, "gain": -3, "snap": True},
    {"src": "explosion_large_08", "len": 3.0, "gain": -4, "snap": True},
    {"src": "explosion_outdoors_large_005", "len": 3.0, "gain": -7, "snap": True},
    {"src": "Howitzer,M101", "len": 1.5, "gain": -6, "snap": True},
    {"src": "explosion_far_distant_02", "len": 2.9, "gain": -8, "delay": .15},
    {"src": "building_collapse_debris_falling_rock_rubble_glass_010", "len": 2.4, "gain": -14, "delay": .5},
]


def apply(recipes):
    for key, spec in DESIGNED.items():
        old = recipes[key]
        spec.setdefault("variants", old.get("variants", 3))
        spec.setdefault("pitches", [0, -1, 1])
        spec.update({"group": old["group"], "title": old["title"]})
        recipes[key] = spec
    recipes["ult_nuke"]["layers"] = NUKE_LAUNCH
    recipes["ult_nuke_boom"]["layers"] = NUKE_BOOM
