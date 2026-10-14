"""Build the listening page for the designed sound effects.

Reads build/sfx_preview/manifest.json (written by sfx_design.py) and writes
build/sfx_preview/index.html, which plays the files in build/sfx_preview/sfx/.
"""
import json
import os

ROOT = os.path.join(os.path.dirname(__file__), "..", "build", "sfx_preview")
manifest = json.load(open(os.path.join(ROOT, "manifest.json"), encoding="utf-8"))
import sys
sys.path.insert(0, os.path.dirname(__file__))
from sfx_recipes import RECIPES  # noqa: E402
from sfx_specs import SPECS  # noqa: E402

SLICES = json.load(open("G:/audio_library/sonniss/slices.json", encoding="utf-8"))
SYNTH_NAMES = {"kick": "次低频冲击", "noise": "气流/噪声", "zap": "能量音", "beat": "驻波拍频", "crackle": "电弧噼啪"}


def describe(spec):
    # Plain-language summary of how a recipe builds its sound, layer by layer.
    synth, recorded = [], []
    for layer in spec["layers"]:
        extra = []
        if layer.get("delay"):
            extra.append(f"{layer['delay']:.2f}s 起")
        if layer.get("reverse"):
            extra.append("倒放")
        tail = f"（{'，'.join(extra)}）" if extra else ""
        if "synth" in layer:
            kind = layer["synth"]
            if kind in ("kick", "noise", "zap"):
                synth.append(f"{SYNTH_NAMES[kind]} {int(layer['from'])}→{int(layer['to'])}Hz{tail}")
            elif kind == "beat":
                synth.append(f"驻波拍频 {int(layer['freq'])}Hz{tail}")
            else:
                synth.append(f"电弧噼啪{tail}")
        elif "tone" in layer:
            synth.append(f"纯音 {int(layer['tone'])}Hz{'（滑音）' if layer.get('glide') else ''}{tail}")
        else:
            hit = next((x["file"] for x in SLICES if layer["src"].lower() in x["file"].lower()), layer["src"])
            parts = hit.split("/")
            library = parts[-2] if len(parts) > 1 else ""
            # A few archive folder names carry broken characters (e.g. Fern�ndez).
            library = library.replace("Fern�ndez", "Fernández").replace("�", "-")
            name = parts[-1].rsplit(".", 1)[0]
            recorded.append(f"{name[:48]} · {library[:40]}{tail}")
    out = []
    if synth:
        out.append("合成：" + "；".join(synth))
    if recorded:
        out.append("录音：" + "；".join(recorded))
    return chr(10).join(out)

# Game cadence for the "burst" button: seconds between repeats, like the in-game limiter.
CADENCE = {"turret": .12, "hit_rock": .14, "hit_ship": .14, "kill": .12, "coin": .06, "ui_hover": .08}
GROUPS = [("ult", "大招", "每个大招分「蓄力/发射」和「命中」两段，游戏里由真实的命中事件衔接，任何加速倍率下都和画面同步。另有大招过程中的逐个事件音：水滴碎裂、一向箔压平、傅里叶音符（游戏里沿五声音阶逐个升高）、质数节拍。"),
          ("boss", "Boss", "登场警报、倒计时、技能蓄力、七种技能、技能被打断、狂暴、被摧毁、放出护卫、磁星偏转子弹。"),
          ("flow", "流程", "通关、失守、跃迁到下一章。"),
          ("weapon", "武器", "每章一把，开火和命中各一组。点「连发」按游戏里的节奏重复播放。"),
          ("body", "天体攻击", "十二种天体攻击方式，频繁出现，所以刻意做得短而克制。"),
          ("kill", "受击与击毁", "炮塔命中目标时的材质声，以及目标被摧毁。"),
          ("reward", "奖励与进度", "金币到账（连续到账时音调逐步升高）、购买、升级、解锁、过波。"),
          ("ui", "界面", "按钮、面板与提示。")]
items = []
for key, info in manifest.items():
    cadence = CADENCE.get(key, .11 if key.startswith("w6") else .34 if key.endswith("_fire") or key.endswith("_hit") else .5)
    items.append({"key": key, "title": info["title"], "group": info["group"], "files": info["files"], "cadence": cadence,
                  "spec": SPECS.get(key, ""), "now": describe(RECIPES[key]) if key in RECIPES else ""})
items.sort(key=lambda x: x["key"])
cand_path = os.path.join(ROOT, "candidates.json")
cands = []
if os.path.exists(cand_path):
    for key, options in json.load(open(cand_path, encoding="utf-8")).items():
        base = manifest.get(key, {})
        cad = next((i["cadence"] for i in items if i["key"] == key), .5)
        cands.append({"key": key, "title": base.get("title", key), "cadence": cad,
                      "options": [{"letter": L.upper(), "note": o["note"], "files": ["../cand/" + f for f in o["files"]]} for L, o in options.items()]})

html = """<title>天穹防线音效试听</title>
<link rel="preconnect" href="https://fonts.googleapis.com">
<link rel="stylesheet" href="https://fonts.googleapis.com/css2?family=Noto+Sans+SC:wght@400;500;700&family=JetBrains+Mono:wght@400;600&display=swap">
<style>
/* Layout: one narrow console column; each sound is a row of variant pads, grouped by role. */
:root{
  --ink:#ededed; --dim:#8d8a84; --line:#2a2826; --panel:#181716; --bg:#0f0e0d; --amber:#e8b44c; --amber-dim:#5a4a2a;
  --sans:"Noto Sans SC","Microsoft YaHei",system-ui,sans-serif; --mono:"JetBrains Mono",Consolas,monospace;
  color-scheme:dark;
}
body{background:var(--bg);color:var(--ink);font-family:var(--sans);font-size:15px;line-height:1.6}
main{max-width:880px;margin:0 auto;padding-inline:16px;padding-block:40px 80px;display:grid;gap:36px}
header{display:grid;gap:10px}
.eyebrow{font-family:var(--mono);font-size:12px;letter-spacing:.18em;color:var(--amber);text-transform:uppercase}
h1{font-size:clamp(26px,5vw,38px);font-weight:700;margin:0;text-wrap:balance}
.lede{color:var(--dim);max-width:62ch;margin:0}
.bar{display:flex;flex-wrap:wrap;gap:10px;align-items:center}
.vol{display:flex;gap:8px;align-items:center;font-family:var(--mono);font-size:12px;color:var(--dim)}
input[type=range]{accent-color:var(--amber)}
section{display:grid;gap:12px}
h2{font-size:18px;margin:0;display:flex;gap:12px;align-items:baseline}
h2 small{font-weight:400;font-size:13px;color:var(--dim)}
.row{display:grid;grid-template-columns:minmax(0,1fr) auto;gap:12px;align-items:center;padding:12px 14px;border:1px solid var(--line);background:var(--panel);border-radius:4px}
.row .name{min-width:0;display:grid;gap:2px}
.row .name b{font-weight:500}
.row .name code{font-family:var(--mono);font-size:11px;color:var(--dim)}
.row .info{grid-column:1/-1;display:grid;gap:6px;font-size:13px;line-height:1.55}
.row .info p{margin:0;max-width:78ch}
.row .info .tag{font:600 11px var(--mono);letter-spacing:.08em;color:var(--amber);margin-right:8px}
.row .info .now{color:var(--dim);white-space:pre-line}
.pads{display:flex;flex-wrap:wrap;gap:6px;justify-content:flex-end}
button{font:600 12px var(--mono);color:var(--ink);background:transparent;border:1px solid var(--line);border-radius:3px;padding:7px 11px;cursor:pointer;min-width:40px}
button:hover{border-color:var(--dim)}
button:focus-visible{outline:2px solid var(--amber);outline-offset:2px}
button.burst{border-color:var(--amber-dim);color:var(--amber)}
button.on{background:var(--amber);color:var(--bg);border-color:var(--amber)}
.pick{display:grid;gap:12px;padding:18px;border:1px solid var(--amber-dim);border-radius:4px}
.pick h2{color:var(--amber)}
.opt{display:grid;grid-template-columns:28px minmax(0,1fr) auto;gap:10px;align-items:center;padding:6px 0;border-top:1px dashed var(--line)}
.opt .L{font:700 15px var(--mono);color:var(--amber)}
.opt .d{font-size:13px;color:var(--dim);min-width:0}
.note{font-size:13px;color:var(--dim);border-left:2px solid var(--amber-dim);padding-left:12px;max-width:66ch}
@media (max-width:560px){.row{grid-template-columns:1fr}.pads{justify-content:flex-start}}
@media (prefers-reduced-motion:reduce){*{transition:none!important}}
</style>
<main>
<header>
  <div class="eyebrow">Skyguard · SFX list</div>
  <h1>天穹防线 · 天穹防线 · 音效清单</h1>
  <p class="lede">武器、击毁和核弹改为自主设计：核心层（次低频冲击、每把武器的标志性能量音色、空气与气压）由程序合成，统一音色风格；只叠一层专业录音提供真实质感。数字按钮是同一个声音的不同变体；「连发」按游戏里的实际节奏、带随机音高重复播放，用来听重复久了烦不烦。</p>
  <div class="bar">
    <div class="vol"><label for="vol">音量</label><input id="vol" type="range" min="0" max="100" value="70"></div>
    <button id="stop" type="button">全部停止</button>
  </div>
  <p class="note">听完把不满意的写下来就行，比如「w3 的投放太闷」「金币太尖」，用每行下面的编号就能对上。</p>
</header>
<section id="pick" class="pick"></section>
<div id="list"></div>
</main>
<script>
const ITEMS = __ITEMS__;
const CANDS = __CANDS__;
const GROUPS = __GROUPS__;
let ctx = null, master = null;
const buffers = new Map();
const live = new Set();
let bursts = new Map();
function audio(){
  if(!ctx){ctx = new (window.AudioContext||window.webkitAudioContext)();master = ctx.createGain();master.connect(ctx.destination);setVol();}
  return ctx;
}
function setVol(){ if(master) master.gain.value = Math.pow(document.getElementById('vol').value/100, 2); }
document.getElementById('vol').addEventListener('input', setVol);
async function load(file){
  if(buffers.has(file)) return buffers.get(file);
  const p = fetch('sfx/'+file).then(r=>r.arrayBuffer()).then(b=>audio().decodeAudioData(b));
  buffers.set(file, p);
  return p;
}
async function play(file, rate=1){
  const buf = await load(file);
  const src = audio().createBufferSource();
  src.buffer = buf; src.playbackRate.value = rate; src.connect(master); src.start();
  live.add(src); src.onended = ()=>live.delete(src);
}
function stopAll(){ for(const s of live){try{s.stop()}catch(e){}} live.clear(); for(const [k,t] of bursts){clearInterval(t); document.querySelector(`[data-burst="${k}"]`)?.classList.remove('on');} bursts.clear(); }
document.getElementById('stop').addEventListener('click', stopAll);
function burst(item, btn){
  if(bursts.has(item.key)){clearInterval(bursts.get(item.key)); bursts.delete(item.key); btn.classList.remove('on'); return;}
  btn.classList.add('on');
  let n = 0, last = -1, streak = 0;
  const tick = ()=>{
    let i = Math.floor(Math.random()*item.files.length);
    if(item.files.length>1 && i===last) i=(i+1)%item.files.length;
    last = i;
    let rate = 0.97 + Math.random()*0.06;
    if(item.key==='coin'){ streak++; rate *= 1 + Math.min(.3, streak*.012); }
    play(item.files[i], rate);
    if(++n >= 24){clearInterval(bursts.get(item.key)); bursts.delete(item.key); btn.classList.remove('on');}
  };
  tick();
  bursts.set(item.key, setInterval(tick, item.cadence*1000));
}
const pick = document.getElementById('pick');
if(!CANDS.length){ pick.hidden = true; }
else{
  pick.innerHTML = '<h2>重新挑选<small>你上次说不行的 9 个，每个做了 A / B / C 三版，回复字母就行，例如「w1 选 B」。三版都不行也直接说。</small></h2>';
  for(const c of CANDS){
    const box = document.createElement('div'); box.className='row'; box.style.gridTemplateColumns='1fr';
    const name = document.createElement('div'); name.className='name';
    name.innerHTML = '<b></b><code></code>'; name.querySelector('b').textContent=c.title; name.querySelector('code').textContent=c.key;
    box.appendChild(name);
    for(const o of c.options){
      const line = document.createElement('div'); line.className='opt';
      line.innerHTML = '<span class="L"></span><span class="d"></span><div class="pads"></div>';
      line.querySelector('.L').textContent=o.letter; line.querySelector('.d').textContent=o.note;
      const pads = line.querySelector('.pads');
      o.files.forEach((f,i)=>{const b=document.createElement('button');b.type='button';b.textContent=i+1;b.addEventListener('click',()=>play(f));pads.appendChild(b);});
      const item={key:c.key+o.letter,files:o.files,cadence:c.cadence};
      const bb=document.createElement('button');bb.type='button';bb.className='burst';bb.textContent='连发';bb.dataset.burst=item.key;
      bb.addEventListener('click',()=>burst(item,bb));pads.appendChild(bb);
      box.appendChild(line);
    }
    pick.appendChild(box);
  }
}
const list = document.getElementById('list');
list.style.display='grid'; list.style.gap='36px';
for(const [gid, gname, gnote] of GROUPS){
  const sec = document.createElement('section');
  sec.innerHTML = `<h2>${gname}<small>${gnote}</small></h2>`;
  for(const item of ITEMS.filter(i=>i.group===gid)){
    const row = document.createElement('div'); row.className='row';
    const name = document.createElement('div'); name.className='name';
    name.innerHTML = `<b></b><code></code>`;
    name.querySelector('b').textContent = item.title;
    name.querySelector('code').textContent = item.key;
    const pads = document.createElement('div'); pads.className='pads';
    item.files.forEach((f,i)=>{
      const b = document.createElement('button'); b.type='button'; b.textContent = i+1;
      b.setAttribute('aria-label', item.title+' 变体 '+(i+1));
      b.addEventListener('click', ()=>play(f)); pads.appendChild(b);
    });
    const bb = document.createElement('button'); bb.type='button'; bb.className='burst'; bb.textContent='连发'; bb.dataset.burst=item.key;
    bb.addEventListener('click', ()=>burst(item, bb)); pads.appendChild(bb);
    row.append(name, pads);
    if(item.spec || item.now){
      const info = document.createElement('div'); info.className='info';
      if(item.spec){ const p=document.createElement('p'); p.innerHTML='<span class="tag">应有效果</span>'; p.append(item.spec); info.appendChild(p); }
      if(item.now){ const p=document.createElement('p'); p.className='now'; p.innerHTML='<span class="tag">当前做法</span>'; p.append(item.now); info.appendChild(p); }
      row.appendChild(info);
    }
    sec.appendChild(row);
  }
  list.appendChild(sec);
}
</script>
"""
html = html.replace("__CANDS__", json.dumps(cands, ensure_ascii=False)).replace("__ITEMS__", json.dumps(items, ensure_ascii=False)).replace("__GROUPS__", json.dumps(GROUPS, ensure_ascii=False))
open(os.path.join(ROOT, "index.html"), "w", encoding="utf-8").write(html)
print("PREVIEW", len(items))
