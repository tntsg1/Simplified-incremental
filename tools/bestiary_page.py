"""Build the bestiary page from tests/bestiary_capture.gd output (build/bestiary)."""
import json
import os

ROOT = os.path.join(os.path.dirname(__file__), "..", "build", "bestiary")
idx = json.load(open(os.path.join(ROOT, "bestiary.json"), encoding="utf-8"))


def animate(it):
    # 16 captured frames -> one looping animated WebP portrait (falls back to the still).
    from PIL import Image
    frames_dir = os.path.join(ROOT, "frames")
    stem = it["file"][:-4]
    paths = [os.path.join(frames_dir, "%s_%02d.png" % (stem, k)) for k in range(16)]
    if not all(os.path.exists(x) for x in paths):
        return it["file"]
    os.makedirs(os.path.join(ROOT, "anim"), exist_ok=True)
    frames = [Image.open(x).convert("RGB").resize((240, 240), Image.LANCZOS) for x in paths]
    out = "anim/%s.webp" % stem
    frames[0].save(os.path.join(ROOT, out), save_all=True, append_images=frames[1:], duration=70, loop=0, quality=82, method=4)
    return out


for it in idx:
    it["show"] = animate(it) if it["arch"] != "boss" else it["file"]

CHAPTERS = [("城市", "City · 10 km"), ("地球", "Earth orbit · 36,000 km"), ("内太阳系", "Inner Solar System · 3 AU"),
            ("外太阳系", "Outer Solar System · 30 AU"), ("奥尔特云", "Oort Cloud · 1.6 ly"), ("恒星邻域", "Stellar Neighbourhood · 50 ly"),
            ("银河", "Milky Way · 100,000 ly"), ("超星系团", "Supercluster · 520 Mly"), ("可观测宇宙", "Observable Universe · 93 Gly"),
            ("宇宙膜", "The Brane · beyond the horizon")]
ARCH = {
    "swarm": ("蜂群", "小而多，成群飞来，是每一波的主体。血量最低。"),
    "dart": ("飞镖", "速度最快，走大幅度的 S 形弧线，身后拖着长速度线。"),
    "armored": ("重甲", "又慢又厚，六块装甲片随受伤一块块剥落。"),
    "splitter": ("分裂者", "打碎后裂成两块继续前进，碎块不会再裂。"),
    "shielded": ("护盾者", "先要打破外层的六边形护盾，才能伤到本体。"),
    "mother": ("母舰", "最慢最大，途中每 3 秒放出一批蜂群（最多 4 次），机库亮起就要放了。"),
}
MAT = {"rock": "岩石 / 冰", "metal": "金属", "energy": "能量", "exotic": "奇异物质"}
SKILL = ["流星雨", "潮汐护盾", "召唤", "攻城光束", "流星雨", "日冕爆发", "磁场偏转", "召唤", "吞噬", "攻城光束"]

cards = {}
for it in idx:
    cards.setdefault(it["stage"], []).append(it)

legend = "".join(f'<li><b>{n}</b><span>{d}</span></li>' for n, d in ARCH.values())
sections = []
for st, (name, scale) in enumerate(CHAPTERS):
    items = cards.get(st, [])
    regular = [c for c in items if c["arch"] != "boss"]
    boss = next((c for c in items if c["arch"] == "boss"), None)
    debut = next((c for c in regular if c["new"]), None)
    debut_line = f'<p class="debut">本章新登场：<b>{ARCH[debut["arch"]][0]}</b>（{debut["title"]}）</p>' if debut else ""
    grid = []
    for c in regular:
        label, note = ARCH[c["arch"]]
        tag = '<span class="new">本章新登场</span>' if c["new"] else ""
        grid.append(f'''<figure class="card">
  <div class="shot"><img src="{c["show"]}" alt="{c["title"]}" loading="lazy">{tag}</div>
  <figcaption>
    <h4>{c["title"]}</h4>
    <p class="chips"><span class="chip arch">{label}</span><span class="chip">{MAT.get(c["mat"], c["mat"])}</span></p>
    <p class="note">{note}</p>
  </figcaption>
</figure>''')
    boss_html = ""
    if boss:
        boss_html = f'''<figure class="boss">
  <div class="shot"><img src="{boss["file"]}" alt="{boss["title"]}" loading="lazy"></div>
  <figcaption>
    <span class="eyebrow">第 {st + 1} 章 Boss</span>
    <h4>{boss["title"]}</h4>
    <p class="note">专属技能：<b>{SKILL[st]}</b>。第 10 波之后登场，限时击毁。</p>
  </figcaption>
</figure>'''
    sections.append(f'''<section class="chapter" id="ch{st + 1}">
  <header><span class="num">{st + 1:02d}</span><div><h3>{name}</h3><p class="scale">{scale}</p></div></header>
  {debut_line}
  <div class="grid">{"".join(grid)}</div>
  {boss_html}
</section>''')

nav = "".join(f'<a href="#ch{i + 1}">{i + 1:02d} {n}</a>' for i, (n, _) in enumerate(CHAPTERS))
total = sum(1 for it in idx if it["arch"] != "boss")
html = f'''<title>天穹防线怪物图鉴</title>
<link rel="preconnect" href="https://fonts.googleapis.com">
<link rel="stylesheet" href="https://fonts.googleapis.com/css2?family=Noto+Sans+SC:wght@400;500;700&family=JetBrains+Mono:wght@400;600&display=swap">
<style>
/* Layout: a field log - a sticky chapter rail, then one section per scale: monster grid, boss plate. Single dark look, like the game. */
:root{{
  --bg:#0f0f0e; --panel:#171716; --line:#2b2a27; --ink:#ededed; --dim:#8e8b85; --amber:#f2c14e; --amber-dim:#5c4a22;
  --sans:"Noto Sans SC","Microsoft YaHei",system-ui,sans-serif; --mono:"JetBrains Mono",Consolas,monospace;
  color-scheme:dark;
}}
body{{background:var(--bg);color:var(--ink);font-family:var(--sans);font-size:15px;line-height:1.6}}
main{{max-width:1120px;margin:0 auto;padding-inline:16px;padding-block:36px 90px;display:grid;gap:44px}}
.top{{display:grid;gap:12px}}
.eyebrow{{font-family:var(--mono);font-size:12px;letter-spacing:.16em;color:var(--amber);text-transform:uppercase}}
h1{{font-size:clamp(28px,5vw,42px);margin:0;font-weight:700;text-wrap:balance}}
.lede{{color:var(--dim);max-width:64ch;margin:0}}
.legend{{list-style:none;margin:0;padding:0;display:grid;grid-template-columns:repeat(auto-fit,minmax(240px,1fr));gap:10px}}
.legend li{{display:grid;gap:2px;padding:12px 14px;border:1px solid var(--line);border-radius:4px;background:var(--panel)}}
.legend b{{color:var(--amber);font-weight:600}}
.legend span{{color:var(--dim);font-size:13px}}
nav.rail{{position:sticky;top:env(safe-area-inset-top,0px);z-index:5;display:flex;gap:6px;overflow-x:auto;padding-block:10px;background:var(--bg);border-bottom:1px solid var(--line)}}
nav.rail a{{flex:none;font:500 12px var(--mono);color:var(--dim);text-decoration:none;padding:6px 10px;border:1px solid var(--line);border-radius:3px}}
nav.rail a:hover,nav.rail a:focus-visible{{color:var(--ink);border-color:var(--amber-dim);outline:none}}
.chapter{{display:grid;gap:16px;scroll-margin-top:60px}}
.chapter header{{display:flex;gap:16px;align-items:baseline}}
.num{{font:600 28px var(--mono);color:var(--amber)}}
h3{{margin:0;font-size:24px}}
.scale{{margin:0;font:400 12px var(--mono);color:var(--dim);letter-spacing:.06em}}
.debut{{margin:0;color:var(--dim)}}
.debut b{{color:var(--amber);font-weight:600}}
.grid{{display:grid;grid-template-columns:repeat(auto-fill,minmax(200px,1fr));gap:12px}}
.card,.boss{{margin:0;border:1px solid var(--line);border-radius:4px;background:var(--panel);overflow:hidden;display:grid}}
.shot{{position:relative;background:#121212}}
.shot img{{display:block;width:100%;aspect-ratio:1/1;object-fit:cover}}
.new{{position:absolute;top:8px;left:8px;font:600 11px var(--mono);color:#121212;background:var(--amber);padding:2px 7px;border-radius:2px;letter-spacing:.04em}}
figcaption{{padding:12px 14px 14px;display:grid;gap:6px;min-width:0}}
h4{{margin:0;font-size:16px;font-weight:600}}
.chips{{margin:0;display:flex;flex-wrap:wrap;gap:6px}}
.chip{{font:500 11px var(--mono);color:var(--dim);border:1px solid var(--line);padding:1px 7px;border-radius:2px}}
.chip.arch{{color:var(--amber);border-color:var(--amber-dim)}}
.note{{margin:0;font-size:13px;color:var(--dim)}}
.note b{{color:var(--ink);font-weight:500}}
.boss{{grid-template-columns:minmax(0,320px) minmax(0,1fr);border-color:var(--amber-dim)}}
.boss h4{{font-size:20px}}
@media (max-width:620px){{.boss{{grid-template-columns:1fr}}.grid{{grid-template-columns:repeat(2,minmax(0,1fr))}}}}
</style>
<main>
  <section class="top">
    <span class="eyebrow">Skyguard · Bestiary</span>
    <h1>天穹防线 · 怪物图鉴</h1>
    <p class="lede">十章共 {total} 种怪物和 10 个 Boss，每只都是游戏里实时渲染的单体特写，怪物卡片是循环动画（游戏内连续截取 16 帧）。怪物按六种原型设计，每一章换成那个尺度的外观和名字；原型逐章登场，第 5 章起六种齐全。哪个不满意，直接告诉我名字。</p>
    <ul class="legend">{legend}</ul>
  </section>
  <nav class="rail" aria-label="章节">{nav}</nav>
  {"".join(sections)}
</main>
'''
open(os.path.join(ROOT, "index.html"), "w", encoding="utf-8").write(html)
print("BESTIARY_PAGE", total)
