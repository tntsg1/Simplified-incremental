# Writes the ten-chapter stage and weapon Resources (data/*.tres, data/weapons/*.tres).
# Balance numbers here are the starting point; tests/growth_probe.gd tunes them.
import json, os, sys

ROOT = os.path.join(os.path.dirname(__file__), "..")

STAGES = [
    dict(file="city", title="城市", subtitle="CITY / FIRST LIGHT", scale_label="地表防线 · 10 km",
         accent="0.35,0.88,0.76,1", count_multiplier=1, reward_multiplier=1.0, boss_hp=32500.0, hp_base_scale=1.0, hp_growth=1.12,
         boss_window=45.0, boss_title="毁城小行星 · CHIRON", boss_kind="asteroid", weapon_price=0.0, boss_reward=400.0,
         briefing="点击来袭目标发射导弹。第六波起可购买自动防御。"),
    dict(file="earth", title="地球", subtitle="EARTH / ORBITAL WATCH", scale_label="行星防线 · 12,742 km",
         accent="0.35,0.72,1,1", count_multiplier=32, reward_multiplier=1.0, boss_hp=24927500.0, hp_base_scale=19.5, hp_growth=1.56,
         boss_window=48.0, boss_title="流浪天体 · NOMAD", boss_kind="planet", weapon_price=700.0, boss_reward=12800.0,
         wave_density=[1,1,1,2,2,3,3,4,4,6], briefing="来袭天体从四面八方逼近。部署轨道炮，点击月球与卫星改造成武器。"),
    dict(file="solar", title="内太阳系", subtitle="INNER SOL / TERRESTRIAL ARRAY", scale_label="类地行星防线 · 3 AU",
         accent="1,0.72,0.32,1", count_multiplier=1024, reward_multiplier=0.75, boss_hp=9041500000.0, hp_base_scale=84000.0, hp_growth=1.62,
         boss_window=51.0, boss_title="被劫持的矮行星 · CERES", boss_kind="dwarf", weapon_price=150000.0, boss_reward=307200.0,
         wave_density=[1,1,1,2,2,4,4,8,12,16], briefing="小行星带被外星推进器搅动。行星炮的范围攻击可以清除密集群落。"),
    dict(file="outer", title="外太阳系", subtitle="OUTER SOL / GIANT'S REACH", scale_label="巨行星防线 · 50 AU",
         accent="0.93,0.82,0.55,1", count_multiplier=4096, reward_multiplier=0.55, boss_hp=1.6e11, hp_base_scale=1.0e6, hp_growth=1.6,
         boss_window=54.0, boss_title="外星攻城母舰 · LEVIATHAN", boss_kind="mothership", weapon_price=1.6e6, boss_reward=1.2e6,
         briefing="外星舰队从木星背后现身。引力炮借巨行星之力投出重弹。"),
    dict(file="oort", title="奥尔特云", subtitle="OORT CLOUD / COMET SHELL", scale_label="彗星云防线 · 1.6 ly",
         accent="0.72,0.9,1,1", count_multiplier=16384, reward_multiplier=0.42, boss_hp=2.4e11, hp_base_scale=1.2e7, hp_growth=1.6,
         boss_window=57.0, boss_title="星际来客 · 'OUMUAMUA", boss_kind="cigar", weapon_price=2.0e7, boss_reward=2.6e6,
         briefing="冰冷的彗核从太阳系的最外壳层涌入。彗核投射器把冰核撒成一片弹雨。"),
    dict(file="neighborhood", title="恒星邻域", subtitle="STELLAR NEIGHBORHOOD / NEAR STARS", scale_label="近邻恒星防线 · 50 ly",
         accent="0.85,0.75,1,1", count_multiplier=65536, reward_multiplier=0.34, boss_hp=4.0e11, hp_base_scale=1.5e8, hp_growth=1.6,
         boss_window=60.0, boss_title="失控恒星 · VESPER", boss_kind="star", weapon_price=1.0e8, boss_reward=5.0e6,
         briefing="近邻恒星之间的空间开始沸腾。恒星炮的光矛可以穿透长列。"),
    dict(file="galaxy", title="银河", subtitle="MILKY WAY / PULSAR BEACON", scale_label="银河防线 · 100,000 ly",
         accent="0.7,0.53,1,1", count_multiplier=262144, reward_multiplier=0.28125, boss_hp=2.4505e12, hp_base_scale=1.8e9, hp_growth=1.6,
         boss_window=63.0, boss_title="磁星 · MAGNETAR", boss_kind="magnetar", weapon_price=3.0e9, boss_reward=7372800.0,
         briefing="银河旋臂中的威胁成群结队。脉冲星灯塔以极快的节拍扫射。"),
    dict(file="cluster", title="超星系团", subtitle="SUPERCLUSTER / LANIAKEA", scale_label="超星系团防线 · 520 Mly",
         accent="0.95,0.48,0.73,1", count_multiplier=4194304, reward_multiplier=0.10546875, boss_hp=7.8585e13, hp_base_scale=9.0e13, hp_growth=2.5,
         boss_window=66.0, boss_title="外星巨构战舰 · CATHEDRAL", boss_kind="cathedral", weapon_price=1.2e11, boss_reward=176947200.0,
         briefing="星系沿着拉尼亚凯亚的引力流奔向巨引源。类星体炮覆盖多个星系群。"),
    dict(file="cosmos", title="可观测宇宙", subtitle="OBSERVABLE UNIVERSE / LAST HORIZON", scale_label="宇宙防线 · 93 Gly",
         accent="0.65,0.87,1,1", count_multiplier=1073741824, reward_multiplier=0.0098876953125, boss_hp=4.901e15, hp_base_scale=7.8e18, hp_growth=1.2,
         boss_window=70.0, boss_title="宇宙灾变核心 · THE SILENCE", boss_kind="rift", weapon_price=6.0e13, boss_reward=4246732800.0,
         briefing="整个宇宙网正在燃烧。宇宙炮扫过全部纤维。"),
    dict(file="brane", title="宇宙膜", subtitle="THE BRANE / BEYOND THE HORIZON", scale_label="膜宇宙防线 · 第 11 维",
         accent="1,0.79,0.3,1", count_multiplier=8589934592, reward_multiplier=0.004, boss_hp=6.0e16, hp_base_scale=2.0e23, hp_growth=1.2,
         boss_window=75.0, boss_title="对撞之膜 · THE OTHER BRANE", boss_kind="brane", weapon_price=4.0e18, boss_reward=1.2e11,
         briefing="我们的宇宙只是高维空间中的一张膜。另一张膜正在靠近。"),
]

WEAPONS = [
    dict(title="导弹发射井", role="高频拦截 / 蜂群弹头", interval=1.2, damage_multiplier=1.0, coverage=1, color="0.35,0.88,0.76,1", beam=False),
    dict(title="轨道炮", role="重弹贯穿 / 轨道齐射", interval=3.6, damage_multiplier=1.65, coverage=2, color="0.35,0.72,1,1", beam=False),
    dict(title="行星炮阵列", role="区域清除 / 行星阵列", interval=1.8, damage_multiplier=1.275, coverage=5, color="1,0.75,0.35,1", beam=True),
    dict(title="巨行星引力炮", role="引力弹弓 / 重型轨道弹", interval=3.0, damage_multiplier=2.6, coverage=7, color="0.93,0.82,0.55,1", beam=False),
    dict(title="彗核投射器", role="冰核散射 / 长尾弹雨", interval=2.4, damage_multiplier=2.4, coverage=9, color="0.72,0.9,1,1", beam=False),
    dict(title="恒星炮", role="长程穿透 / 恒星光矛", interval=4.8, damage_multiplier=5.28, coverage=10, color="0.72,0.5,1,1", beam=True),
    dict(title="脉冲星灯塔", role="高频脉冲 / 节拍连射", interval=1.4, damage_multiplier=2.0, coverage=16, color="0.8,0.7,1,1", beam=True),
    dict(title="类星体炮", role="多域覆盖 / 类星体网络", interval=6.0, damage_multiplier=10.25, coverage=24, color="0.95,0.48,0.7,1", beam=True),
    dict(title="宇宙炮", role="全域扫掠 / 宇宙共振", interval=8.0, damage_multiplier=21.2, coverage=60, color="0.7,0.88,1,1", beam=True),
    dict(title="膜共振炮", role="弦振动 / 高维共振", interval=9.0, damage_multiplier=38.0, coverage=120, color="1,0.79,0.3,1", beam=True),
]

def fmt(v):
    if isinstance(v, bool):
        return "true" if v else "false"
    if isinstance(v, str):
        return json.dumps(v, ensure_ascii=False)
    if isinstance(v, float):
        return repr(v) if abs(v) < 1e15 else "%e" % v
    return str(v)

def write(path, script, fields):
    lines = ['[gd_resource type="Resource" script_class="" load_steps=2 format=3]',
             '[ext_resource type="Script" path="%s" id="1"]' % script, '[resource]', 'script=ExtResource("1")']
    for key, value in fields.items():
        if key == "file":
            continue
        if key in ("accent", "color"):
            lines.append("%s=Color(%s)" % (key, value))
        elif key == "wave_density":
            lines.append("wave_density=PackedInt32Array(%s)" % ",".join(str(x) for x in value))
        else:
            lines.append("%s=%s" % (key, fmt(value)))
    with open(path, "w", encoding="utf-8", newline="\n") as f:
        f.write("\n".join(lines) + "\n")

def main():
    overrides = {}
    if len(sys.argv) > 1:
        with open(sys.argv[1], encoding="utf-8") as f:
            overrides = json.load(f)
    for i, s in enumerate(STAGES):
        s = dict(s)
        s.update(overrides.get(str(i), {}))
        write(os.path.join(ROOT, "data", s["file"] + ".tres"), "res://data/stage_spec.gd", s)
    for i, w in enumerate(WEAPONS):
        write(os.path.join(ROOT, "data", "weapons", "%d.tres" % i), "res://data/weapon_spec.gd", w)
    print("wrote", len(STAGES), "stages and", len(WEAPONS), "weapons")

if __name__ == "__main__":
    main()
