"""Summarize actual, non-ROI simulations. No game-state mutations."""
import csv
import json
import statistics as stats
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
PROOFS = ROOT / "proofs"
data = json.loads((PROOFS / "boss_player_audit.json").read_text(encoding="utf-8"))

def sci(value):
    return f"{value:,.0f}" if abs(value) < 1e6 else f"{value:.3g}"

def span(values, fmt=str):
    return "—" if not values else fmt(min(values)) + "–" + fmt(max(values))

def ledger_total(row):
    l = row["ledger"]
    return l["automation"] + l["weapons"] + l["bodies"] + sum(l["upgrades"].values())

records = []
mob_rows = []
for run in data["runs"]:
    prior_grind = False
    for row in run["records"]:
        row = dict(row, profile=run["profile"], seed=run["seed"])
        row["clean_prefix"] = not prior_grind and row["attempt"] == 0
        if row["attempt"] > 0:
            prior_grind = True
        row["money_error"] = abs(row["start_cash"] + row["mob_income"] - ledger_total(row) - row["cash"]) / max(1, row["start_cash"] + row["mob_income"])
        records.append(row)
    for stage in range(6):
        waves = [w for w in run["waves"] if w["stage"] == stage and w["attempt"] == 0]
        if not waves:
            continue
        spawned = sum(w["asteroid_spawned"] for w in waves)
        killed = sum(w["asteroid_killed"] for w in waves)
        leaked = sum(w["asteroid_leaked"] for w in waves)
        boss0 = [r for r in run["records"] if r["stage"] == stage and r["attempt"] == 0]
        mob_rows.append(dict(profile=run["profile"], seed=run["seed"], stage=stage, spawned=spawned, killed=killed, leaked=leaked, cleared=killed/max(1, spawned), max_wave=max(w["wave"] for w in waves), reached_boss=bool(boss0)))

lines = ["# 当前 Boss 与小行星经济评估", "", "仅评估，没有修改敌人血量、奖励、升级价格或玩家存档。", "", "## 方法与边界", "", f"完成 {len(data['runs'])} 组真实固定 60 Hz 模拟：5 种非最优购买习惯 × 3 个战斗/行为种子。购买选择是固定权重随机点击，不读取 DPS 增益或性价比；20–40 个游戏秒访问一次商店，城市逐级买，后续除逐级型外使用界面已有的 ×10。包括自动化、新章主炮、可选天体改造、留钱与目标切换延迟。每章最多重试两次，重试保留资源并增加小怪收益。", "", "表中的失败/成功数量是这组行为情景的模拟结果，不是现实玩家群体的胜率。未到达 Boss 的情景不能作为 Boss 胜利。该章首战可能继承前章重试所得，另列全程无重试前缀结果；后章存在幸存者偏差。Boss 警报时允许一次相同购买习惯的商店访问，战斗期间不再买，不是资金/DPS 最优解。", "", "Jev：选择真实战役模拟，条件概率真实模拟 100%、仅理论估算 0%，置信度 100%。实施判断：漏怪与延迟购物会影响实际收入；必须分开首轮与重试所得。", "", "## Boss 实际血量与前置收入", "", "实际 Boss HP = 配置 boss_hp × hp_base_scale × hp_growth^9。收入参考是假定十波普通成员全部击毁；精英比例、漏怪以及跨波结算会造成实际差异。前章携带资金和前章 Boss 奖励另列，当前 Boss 尚未击毁的奖励不计入可用预算。", "", "| 阶段 | 实际 Boss HP | 窗口秒 | 最低平均 DPS | 本章十波普通成员全掉落参考 |", "|---|---:|---:|---:|---:|"]
for b in data["bosses"]:
    lines.append(f"| {b['name']} | {sci(b['hp'])} | {b['window']:g} | {sci(b['required_dps'])} | {sci(b['full_regular_income_reference'])} |")
lines += ["", "## 该章首轮表现", "", "小行星统计按成员而非群落计数，只含 rock/heavy；不把外星舰群混作小行星。百分比针对首轮实际已生成成员，失败时尚未生成的后续波不算已清除。", "", "| 阶段 | 进入本章情景数 | 首轮见到 Boss / 首战击败 | 无前章重试且见到 Boss / 击败 | 小行星击毁比例范围 | 伤害等级范围 | 装填等级范围 |", "|---|---:|---:|---:|---:|---:|---:|"]
summary = []
for b in data["bosses"]:
    s = b["stage"]
    rr = [r for r in records if r["stage"] == s and r["attempt"] == 0]
    clean = [r for r in rr if r["clean_prefix"]]
    mm = [m for m in mob_rows if m["stage"] == s]
    entry = dict(stage=s, name=b["name"], entered=len(mm), first_bosses=len(rr), first_wins=sum(r["won"] for r in rr), clean_bosses=len(clean), clean_wins=sum(r["won"] for r in clean), asteroid_clear_min=min((m["cleared"] for m in mm), default=None), asteroid_clear_max=max((m["cleared"] for m in mm), default=None))
    summary.append(entry)
    lines.append(f"| {b['name']} | {len(mm)} | {len(rr)} / {entry['first_wins']} | {len(clean)} / {entry['clean_wins']} | {span([m['cleared'] for m in mm], lambda x:f'{x:.1%}')} | {span([r['levels']['damage'] for r in rr])} | {span([r['levels']['reload'] for r in rr])} |")
lines += ["", "## 行为类型与普通玩家等级", "", "| 行为类型 | 阶段 | 前置小怪实际收入范围 | 伤害 / 装填等级范围 | 该章首战击败 / 见到 Boss | 超时剩余血量范围 |", "|---|---|---:|---|---:|---:|"]
for p in data["profiles"]:
    for b in data["bosses"]:
        rr = [r for r in records if r["profile"] == p["id"] and r["stage"] == b["stage"] and r["attempt"] == 0]
        if not rr:
            continue
        failed = [r for r in rr if not r["won"]]
        lines.append(f"| {p['label']} | {b['name']} | {span([r['mob_income'] for r in rr], sci)} | {span([r['levels']['damage'] for r in rr])} / {span([r['levels']['reload'] for r in rr])} | {sum(r['won'] for r in rr)} / {len(rr)} | {span([r['remaining_hp_fraction'] for r in failed],lambda x:f'{x:.1%}')} |")
lines += ["", "## 第一条直觉路线的可复核例子", "", "| 阶段 | 是否重试过本章 | 进入本章携款 | 小怪实际收入 | 首战前总消费 | 剩余现金 | 伤害 / 装填 / 炮塔 / 天体 | Boss 结果 |", "|---|---:|---:|---:|---:|---:|---|---|"]
for r in records:
    if r["profile"] != "core" or r["seed"] != 4262026:
        continue
    l = r["levels"]
    outcome = f"{r['ttk']:.1f} 秒击败" if r["won"] else f"超时剩 {r['remaining_hp_fraction']:.1%}"
    lines.append(f"| {data['bosses'][r['stage']]['name']} | {r['attempt']} | {sci(r['start_cash'])} | {sci(r['mob_income'])} | {sci(ledger_total(r))} | {sci(r['cash'])} | {l['damage']} / {l['reload']} / {l['turrets']} / {r['bodies']} | {outcome} |")
probe_path = PROOFS / "player_dps_probe.json"
if probe_path.exists():
    q = json.loads(probe_path.read_text(encoding="utf-8"))
    x = q["unchanged_upgrades_probe"]
    lines += ["", "## 实际存档快照的 DPS", "", f"读取快照时为第 {q['snapshot_stage']+1} 章第 {q['snapshot_wave']} 波，伤害 {q['levels']['damage']}、装填 {q['levels']['reload']}、范围 {q['levels']['area']}、暴击 {q['levels']['crit']}、炮塔 {q['levels']['turrets']}、改造天体 {q['converted_bodies']}；现金 {sci(q['money'])}，名义 DPS {sci(q['nominal_dps'])}。玩家可能继续操作，这只是读取时状态。", "", f"不再购买任何升级的隔离副本在 {x['elapsed']:.1f} 个游戏秒后于第 {x['wave']} 波失败。这不表示玩家继续升级也必败。未改写存档。", "", "| 波次 | 常规成员总 HP 参考 | 常规波时长秒 | 当前 DPS / 总 HP ÷ 波时长 |", "|---|---:|---:|---:|"]
    for w in q["waves"]:
        lines.append(f"| {w['wave']} | {sci(w['regular_hp_reference'])} | {w['nominal_wave_seconds']:g} | {w['nominal_dps_ratio']:.4f} |")
    lines += ["", "该比值只是粗略需求参考：实际发射预留、离散齐射、精英、前后波重叠和 min_alive 加速生成都会改变清理表现。主要判定仍来自实际逐成员模拟。"]
lines += ["", "## 评估结论", "", "前置收益存在可打过 Boss 的非最优分配方式，但目前不能保证正常分散购买的玩家在限定时间内打过。城市尤为清楚：几乎全清小行星、拿到近乎相同收入，Boss 仍会因为错过伤害/装填突破而失败。", "", "银河和星系团存在已清完普通波却无法击败 Boss 的情景，属于 Boss 火力门槛与自然成长不匹配，不能归因于玩家没清小怪。地球另有普通波失败与收入流失风险；既要检查 Boss，也要检查跨章后的初期承接。", "", "逐级点击在后期难以跟上急剧增长的血量；×10 并不能自动解决这个问题，分散投向覆盖/贯穿等属性仍会使 Boss 单体火力不足。不能只保留主升伤害和装填的路线作为验收。", "", "## 可信度与后续调整边界", "", f"账目核验最大相对误差 {max((r['money_error'] for r in records),default=0):.3g}，验证进入本章资金 + 实得小怪收入 = 消费 + 剩余现金。", "", "不以全通重试路线证明首次掉落足够，不把继续重复刷钱后的升级等级当作普通首轮等级。逐级型与分散购买是必要边界情景；伤害/装填突破形成突变，不能用一组平均等级替代所有人。", "", "修改 Boss 血量时应先选明确的体验目标（例如非最优但有正常升级的多种路线能在窗口的约 70–85% 时间内击败），再验证实际低余量路线；不能直接按这 15 条样本宣称真实玩家通过率。当前报告只做评估，不改数值。", "", "来源：tests/boss_player_audit.gd、proofs/boss_player_audit.json、proofs/boss_player_audit.log、tests/player_dps_probe.gd。"]
(ROOT / "BOSS_BALANCE_AUDIT.md").write_text("\n".join(lines)+"\n",encoding="utf-8")
(PROOFS / "boss_audit_summary.json").write_text(json.dumps(dict(completed_runs=len(data["runs"]), stages=summary, max_money_relative_error=max((r['money_error'] for r in records),default=0)),ensure_ascii=False,indent=2),encoding="utf-8")
with (PROOFS / "boss_audit_rows.csv").open("w",encoding="utf-8-sig",newline="") as f:
    names=["profile","seed","stage","attempt","clean_prefix","mob_income","start_cash","cash","nominal_dps","measured_dps","boss_hp","window","ttk","won","remaining_hp_fraction"]
    writer=csv.DictWriter(f,fieldnames=names,extrasaction="ignore")
    writer.writeheader(); writer.writerows(records)
print(json.dumps(dict(completed_runs=len(data["runs"]),stages=summary),ensure_ascii=True))
