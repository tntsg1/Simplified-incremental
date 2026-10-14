"""Sound recipes for batch 1: weapons, hits, destruction, rewards, interface.

Layer keys: src (file name fragment), slice, off/len (seconds), pitch
(semitones), gain (dB after peak-normalising the layer), delay, hp/lp (Hz),
fade. Recipe keys: layers, len, variants, pitches, swap (per-variant layer
overrides), room/wet (short space), comp, peak.
Material: Sonniss GDC Game Audio Bundles (royalty free, no attribution).
"""

W = "weapon"
R = "reward"
U = "ui"
K = "kill"

RECIPES = {
    # ---------------------------------------------------------------- weapons
    "w0_fire": {"group": W, "title": "01 城市 · 导弹发射井 · 发射", "len": .6, "pitches": [0, -1, 1], "room": .2,
        "layers": [
            {"src": "Rocket Launcher - Shot - 04", "len": .6, "gain": 0},
            {"src": "PM_FSSF2_WEAPONS_C3_SHOT", "len": .4, "gain": -5, "pitch": -4, "lp": 2500},
            {"src": "bullet_flyby_fast_06", "len": .4, "gain": -12, "delay": .04},
        ]},
    "w0_hit": {"group": W, "title": "01 城市 · 导弹发射井 · 命中", "len": .55, "pitches": [0, 1, -1], "room": .25,
        "layers": [
            {"src": "explosion_large_no_tail_03", "len": .55, "gain": 0, "pitch": 2},
            {"src": "Bullet rock Impact 4", "len": .25, "gain": -6},
            {"src": "invader_debris_impact_011", "len": .45, "gain": -9, "delay": .03},
        ]},
    "w1_fire": {"group": W, "title": "02 地球 · 轨道动能棒 · 发射", "len": .8, "pitches": [0, -1, 1],
        "layers": [
            {"src": "sci_fi_weapon_cannon_shot_002", "len": .8, "gain": 0},
            {"src": "Impact 059", "len": .7, "gain": -4, "lp": 900},
            {"src": "Shot Pulse YR 05", "len": .3, "gain": -9, "hp": 2500},
        ]},
    "w1_hit": {"group": W, "title": "02 地球 · 轨道动能棒 · 命中", "len": .9, "pitches": [0, -1, 1], "room": .3,
        "layers": [
            {"src": "Impact 038", "len": .9, "gain": 0},
            {"src": "rock impact medium 26", "len": .5, "gain": -5},
            {"src": "Low Boom 3", "len": .9, "gain": -7},
        ]},
    "w2_fire": {"group": W, "title": "03 内太阳系 · 日冕斩 · 发射", "len": .5, "pitches": [0, 2, -1],
        "layers": [
            {"src": "Mecha Energy Sword Cut", "len": .5, "gain": 0},
            {"src": "Fast Action Swish_HW 05", "len": .35, "gain": -5},
            {"src": "Beam Transient_04", "len": .3, "gain": -8, "hp": 1500},
        ]},
    "w2_hit": {"group": W, "title": "03 内太阳系 · 日冕斩 · 命中", "len": .4, "pitches": [0, 1, 2],
        "layers": [
            {"src": "FMW_Weapon_Hit10C", "len": .4, "gain": 0},
            {"src": "ELECZap_Bug zapper", "len": .25, "gain": -12, "lp": 9000},
        ]},
    "w3_fire": {"group": W, "title": "04 外太阳系 · 引力井 · 投放", "len": .9, "pitches": [0, -1, -2],
        "layers": [
            {"src": "Bass Drop & Downer Fast 12", "len": .9, "gain": 0},
            {"src": "Interface Sci-Fi Ping Down", "len": .6, "gain": -10},
        ]},
    "w3_hit": {"group": W, "title": "04 外太阳系 · 引力井 · 坍缩", "len": 1.0, "pitches": [0, -1, 1], "room": .35,
        "layers": [
            {"src": "Impact 021", "len": 1.0, "gain": 0},
            {"src": "Whoosh,Sound Design,Blast,Watery,Crash", "len": .8, "gain": -7, "lp": 3000},
        ]},
    "w4_fire": {"group": W, "title": "05 奥尔特云 · 冰晶霰弹 · 发射", "len": .6, "pitches": [0, 1, -1],
        "layers": [
            {"src": "Sci Fi Shotgun Burst_04", "len": .6, "gain": 0},
            {"src": "PM_FSSF_GUN_SHOTGUN_2", "len": .5, "gain": -4},
            {"src": "debris_ice_001", "len": .5, "gain": -9, "delay": .03},
        ]},
    "w4_hit": {"group": W, "title": "05 奥尔特云 · 冰晶霰弹 · 命中", "len": .55, "pitches": [0, 2, 1],
        "layers": [
            {"src": "glass_impact_break_small_014", "len": .55, "gain": 0},
            {"src": "Magic_Spells_Impact_Ice13", "off": .2, "len": .5, "gain": -5},
            {"src": "Wine Glass Hit Higher Pitch", "len": .4, "gain": -12},
        ]},
    "w5_fire": {"group": W, "title": "06 恒星邻域 · 光矛 · 发射", "len": .7, "pitches": [0, -1, 1], "room": .2,
        "layers": [
            {"src": "Blast Laser 2", "len": .7, "gain": 0},
            {"src": "Beam Transient_04", "len": .4, "gain": -3},
            {"src": "CANNON Plasma Shot Tonal High 10", "len": .6, "gain": -7},
        ]},
    "w5_hit": {"group": W, "title": "06 恒星邻域 · 光矛 · 灼烧", "len": .5, "pitches": [0, 1, -1],
        "layers": [
            {"src": "Zap Short 14", "off": .1, "len": .5, "gain": 0},
            {"src": "Bluezone_BC0235_impact_003", "len": .5, "gain": -5},
        ]},
    "w6_fire": {"group": W, "title": "07 银河 · 脉冲星灯塔 · 单拍（连发四次）", "len": .25, "pitches": [0, 2, 4, 5], "variants": 4, "comp": -14,
        "layers": [
            {"src": "GUNAuto_RPU1 Fire_02", "len": .25, "gain": 0, "pitch": 3},
            {"src": "BlipsandClicks_Synth_Click_26", "len": .15, "gain": -7},
        ]},
    "w6_hit": {"group": W, "title": "07 银河 · 脉冲星灯塔 · 命中", "len": .3, "pitches": [0, 2, 4],
        "layers": [
            {"src": "/hitsound 2.wav", "len": .3, "gain": 0},
            {"src": "PM_GC_SPARKLY_SHORT_GLITCH_51", "len": .25, "gain": -9},
        ]},
    "w7_fire": {"group": W, "title": "08 超星系团 · 相对论喷流 · 发射", "len": .9, "pitches": [0, -1, 1], "room": .25,
        "layers": [
            {"src": "annihilation_mech_weapon_scifi_shot_004", "len": .9, "gain": 0},
            {"src": "Flyby Plasma J 01", "off": .45, "len": .8, "gain": -5},
            {"src": "Recoil Blast 2", "len": .6, "gain": -6},
        ]},
    "w7_hit": {"group": W, "title": "08 超星系团 · 相对论喷流 · 命中", "len": .9, "pitches": [0, -1, 1], "room": .3,
        "layers": [
            {"src": "Weapon Bomb Explosion Sci-Fi Plasma-04", "len": .9, "gain": 0},
            {"src": "Heavy Magical Explosion_SI 03", "len": .9, "gain": -5, "lp": 4000},
        ]},
    "w8_fire": {"group": W, "title": "09 可观测宇宙 · 宇宙网 · 发射", "len": .7, "pitches": [0, 1, -1],
        "layers": [
            {"src": "electric_surge_blast_04", "off": .2, "len": .7, "gain": 0},
            {"src": "Heavy Glitches_RogueWaves_GlitchGrains_26", "len": .5, "gain": -6},
            {"src": "PM_GC_SPARKLY_SHORT_GLITCH_51", "len": .4, "gain": -10},
        ]},
    "w8_hit": {"group": W, "title": "09 可观测宇宙 · 宇宙网 · 命中", "len": .6, "pitches": [0, 1, 2],
        "layers": [
            {"src": "Glitch_Factory_01_Boom_Crackle_04", "len": .6, "gain": 0},
            {"src": "AeroratedIce,crackle", "len": .5, "gain": -9},
        ]},
    "w9_fire": {"group": W, "title": "10 宇宙膜 · 驻波 · 发射", "len": 1.0, "pitches": [0, -2, 2], "room": .4, "wet": .16,
        "layers": [
            {"src": "Stinger-String5", "len": 1.0, "gain": 0},
            {"src": "Impact 045", "len": .9, "gain": -4},
            {"src": "Laser-Like_Synth_Basic_Laser4_08", "len": .6, "gain": -9},
        ]},
    "w9_hit": {"group": W, "title": "10 宇宙膜 · 驻波 · 共振", "len": .9, "pitches": [0, -1, 1], "room": .35,
        "layers": [
            {"src": "ResonantRustyDoor_impact_hard_11", "len": .9, "gain": 0},
            {"src": "Impact 045", "len": .8, "gain": -6},
        ]},
    "turret": {"group": W, "title": "炮塔 · 细短发射", "len": .14, "pitches": [0, 2, -2, 4], "variants": 4, "comp": -12,
        "layers": [
            {"src": "GUNAuto_RPU1 Fire_02", "len": .14, "gain": 0, "pitch": 6, "hp": 600},
            {"src": "Micro UI Readout Sound Mechanical 10", "len": .1, "gain": -9},
        ]},
    # ---------------------------------------------------------------- hits and kills
    "hit_rock": {"group": K, "title": "受击 · 岩石天体", "len": .2, "pitches": [0, 2, -2, 3], "variants": 4,
        "layers": [
            {"src": "stone_impact_hammer_015", "len": .2, "gain": 0},
            {"src": "Bullet rock Impact 4", "len": .15, "gain": -5},
        ]},
    "hit_ship": {"group": K, "title": "受击 · 外星舰船", "len": .22, "pitches": [0, 2, -2, 3], "variants": 4,
        "swap": {"0": [{"slice": 0}, {"slice": 1}, {"slice": 2}, {"slice": 3}]},
        "layers": [
            {"src": "Hit Impact Hard Metal Scrap Debris_UC 01", "len": .22, "gain": 0},
            {"src": "IMPACT METAL Scratchy Short Punch_03", "len": .2, "gain": -7},
        ]},
    "kill": {"group": K, "title": "击毁 · 普通目标", "len": .5, "pitches": [3, 4, 2, 5], "variants": 4, "room": .2,
        "layers": [
            {"src": "explosion_large_no_tail_03", "len": .5, "gain": 0},
            {"src": "invader_debris_impact_011", "len": .4, "gain": -5, "pitch": -3},
            {"src": "Explosion Small Blast Enemy Death Crunchy", "len": .4, "gain": -8},
        ]},
    "kill_big": {"group": K, "title": "击毁 · 精英 / 大型目标", "len": 1.2, "pitches": [0, -1, 1], "room": .35,
        "layers": [
            {"src": "Medium Realistic Explosion 15", "len": 1.2, "gain": 0},
            {"src": "Impact 038", "len": 1.0, "gain": -3},
            {"src": "building_collapse_debris_impact_glass_short_009", "len": .6, "gain": -9, "delay": .05},
        ]},
    # ---------------------------------------------------------------- rewards
    "coin": {"group": R, "title": "金币到账", "len": .45, "lp": 8500, "lufs": -18, "pitches": [0, 2, 4, -1], "variants": 4, "comp": -12, "room": .15,
        "layers": [
            {"src": "Ting Coins", "len": .45, "gain": 0},
            {"src": "Drop Couple of Gold Coins on Coins 03", "len": .35, "gain": -8},
        ]},
    "purchase": {"group": R, "title": "购买", "len": .55, "pitches": [0, 1, -1], "room": .15,
        "layers": [
            {"src": "Interface Accept Glassy Snap", "len": .4, "gain": 0},
            {"src": "/Coins_05.wav", "len": .55, "gain": -5, "delay": .02, "snap": True},
        ]},
    "upgrade": {"group": R, "title": "升级", "len": 1.0, "pitches": [0, 2, -2], "room": .25,
        "layers": [
            {"src": "Button Arp Twinkle", "len": 1.0, "gain": 0},
            {"src": "Interface Accept Glassy Snap", "len": .35, "gain": -6},
        ]},
    "milestone": {"group": R, "title": "里程碑 / 解锁", "len": 1.6, "variants": 2, "pitches": [0, -2], "room": .4, "wet": .18,
        "layers": [
            {"src": "Computer Device Power Up Activation Conformation", "len": 1.6, "gain": 0},
            {"src": "Impact 059", "len": .9, "gain": -10, "lp": 1200},
        ]},
    "wave_clear": {"group": R, "title": "波次完成", "len": .9, "variants": 2, "pitches": [0, 2], "room": .3,
        "layers": [
            {"src": "Interface Plucks Happy", "len": .9, "gain": 0},
            {"src": "Woosh Sweep Slide Infographics Basic", "len": .35, "gain": -9},
        ]},
    # ---------------------------------------------------------------- interface
    "ui_click": {"group": U, "title": "界面 · 点击", "len": .16, "variants": 3, "pitches": [0, 1, -1], "comp": None,
        "layers": [{"src": "UI_SoundPack11_Select_v14", "len": .16, "gain": 0}]},
    "ui_hover": {"group": U, "title": "界面 · 悬停", "len": .1, "variants": 3, "pitches": [0, 2, -2], "comp": None, "peak": -6,
        "layers": [{"src": "Micro UI Readout Sound Mechanical 10", "len": .1, "gain": 0}]},
    "ui_open": {"group": U, "title": "界面 · 打开面板", "len": .6, "variants": 1, "comp": None,
        "layers": [{"src": "futuristic_user_interface_transition_006", "len": .6, "gain": 0}]},
    "ui_close": {"group": U, "title": "界面 · 关闭面板", "len": .5, "variants": 1, "comp": None,
        "layers": [{"src": "UI_Window_MEDIUM_SlideMetal_02_CLOSED", "len": .5, "gain": 0}]},
    "ui_deny": {"group": U, "title": "界面 · 钱不够 / 不可用", "len": .5, "variants": 1, "comp": None,
        "layers": [{"src": "Interface Deny Low Fat Dark", "len": .5, "gain": 0}]},
}

# ---------------------------------------------------------------- picks from the A/B/C round (2026-10-13)
from sfx_candidates import CANDIDATES  # noqa: E402

CHOSEN = {"w1_fire": "c", "w2_fire": "c", "w9_fire": "c", "milestone": "a", "wave_clear": "b",
          "ui_open": "a", "ui_close": "c", "ui_deny": "c"}
for _key, _letter in CHOSEN.items():
    _old = RECIPES[_key]
    _new = dict(CANDIDATES[_key][_letter])
    _new.update({"group": _old["group"], "title": _old["title"], "variants": _old.get("variants", 3)})
    if _new["variants"] == 3:
        _new["pitches"] = [0, -1, 1]
    RECIPES[_key] = _new
# The user wants no hover sound at all.
del RECIPES["ui_hover"]

# ---------------------------------------------------------------- ultimates (batch 2)
# Timed to the on-screen sequence: ULT_DURATION / NUKE_IMPACT in combat.gd.
X = "ult"
# Launch and detonation are separate files: the blast is triggered by the game's
# own impact event, so sound and picture stay locked at any game speed.
RECIPES["ult_nuke"] = {"group": X, "title": "大招 · 核弹 · 发射与飞行（起爆时被切断）", "len": 1.5, "variants": 1,
    "pitches": [0], "room": .4, "wet": .12, "tail": .02, "comp": None, "lufs": -19, "prenorm": True,
    "layers": [
        {"src": "Rocket Launcher - Shot - 04", "len": .9, "gain": 0, "snap": True},
        {"src": "Vehicle5_BlastOff1", "len": 1.3, "gain": -5, "lp": 6000},
        # the warhead's climb: a riser whose peak lands right before detonation
        {"src": "Riser 078", "off": 2.25, "len": 1.27, "gain": -2, "delay": .15, "fade": .04},
        # the air pulled away: a reversed boom swelling into the blast
        {"src": "Boom 040", "len": .44, "gain": 1, "reverse": True, "fade_in": .3, "delay": .98, "fade": .005},
    ]}
RECIPES["ult_nuke_boom"] = {"group": X, "title": "大招 · 核弹 · 起爆与余波", "len": 3.1, "variants": 1,
    "pitches": [0], "room": .55, "wet": .14, "tail": 1.2, "comp": None, "lufs": -11, "prenorm": True,
    "layers": [
        {"src": "Boom 005", "len": 3.0, "gain": 0, "snap": True},
        {"src": "explosion_large_08", "len": 3.0, "gain": -2, "snap": True},
        {"src": "explosion_outdoors_large_005", "len": 3.0, "gain": -4, "snap": True},
        {"src": "Howitzer,M101", "len": 1.5, "gain": -5, "snap": True},
        {"src": "Impact 021", "len": 2.0, "gain": -4, "snap": True},
        {"src": "explosion_far_distant_02", "len": 2.9, "gain": -6, "delay": .15},
        {"src": "building_collapse_debris_falling_rock_rubble_glass_010", "len": 2.4, "gain": -12, "delay": .5},
    ]}

# Round 2: house-designed weapons, kills and nuke replace the library-only versions.
from sfx_designed import apply as _apply_designed  # noqa: E402

_apply_designed(RECIPES)

# Batch 2: ultimates, bosses, chapter flow, celestial-body attacks.
from sfx_batch2 import apply as _apply_batch2  # noqa: E402

_apply_batch2(RECIPES)
