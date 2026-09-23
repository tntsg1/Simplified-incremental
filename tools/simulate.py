#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Stellar Ascension 数值模拟 v2 — 阶段0: 拟合设计稿 §41 前5小时曲线。

v1 教训:
- ship_g 无边界 → 拟合压到1.08, 1h 瞬开16星系, 内容前置耗尽, 5h断粮
- 殖民阈值0.7 + 新星球补钻快 → 殖民连发
- 升级成本比(1.9) > 产出比(1.65) → 升级 ROI 指数衰减, 后期只剩扩张一个引擎

v2 核心:
- 升级引擎: upg_ratio ≈ UPG_MULT(1.65) → 升级成本与收入同步复利 →
  时间间隔恒定 → 指数增长 (拟合 upg_ratio ∈ [1.60, 2.00])
- 殖民节拍: 全局矿点占用 ≥85% 才造下一艘殖民船 (0.7→0.85)
- 殖民船: ship_g ∈ [1.30, 1.50], 保证船价始终≈几十秒-几分钟收入, 不瞬开
- 太空电梯: §26 里程碑(殖民3星球) + 固定大额成本, 落在 1-2h
- 星球数量时间线进节拍约束: 0.5h≤3, 2h≤12, 5h∈[10,45]
- MAX_PLANETS=60

目标 (§41): 0.5h→380/s, 2h→28K/s, 5h→3.4M/s
节拍 (§45): 第二星球 0.5-1h, 太空电梯 1-2h, 跨恒星 2-4h
"""
import math
import json
import sys

TARGETS = [(0.5, 380.0), (2.0, 28e3), (5.0, 3.4e6)]

# 科技队列: (Science 费用, Minerals 全局倍率, 里程碑key, 里程碑值)
TECHS = [
    (4000.0,   1.8,  'labs',   3),
    (20000.0,  1.9,  'planets', 2),
    (250000.0, 2.2,  'port',    1),
    (3.0e6,    2.5,  'elev',    1),
    (3.0e7,    3.0,  'planets', 6),
]

BOUNDS = {
    'drill_base': (5.0, 60.0),
    'drill_g':    (1.05, 1.40),
    'upg_base':   (20.0, 1000.0),
    'upg_ratio':  (1.65, 2.00),
    'lab_base':   (100.0, 1200.0),
    'lab_g':      (1.05, 1.30),
    'tech_scale': (0.2, 5.0),
    'k_sci':      (3.0, 50.0),
    'ship_base':  (500.0, 30000.0),
    'ship_g':     (1.30, 1.60),
}

DEP_HOME = 8
SYS_MAX_PLANETS = 3
MAX_PLANETS = 60
GEN_OUT = 15.0
DRILL_OUT = 5.0
LAB_OUT = 4.0
HUB_OUT = 10.0
UPG_MULT = 1.65
K_CRED = 0.25

T_END = 5.2 * 3600
DT = 1.0

ELEV_MIN_COST = 200000.0
ELEV_MIN_CRED = 80000.0
COLONIZE_THRESH = 0.85
PORT_THRESH = 0.55


def dep_of(idx):
    if idx == 0:
        return DEP_HOME
    return 6 + (idx * 7 + 3) % 5


def simulate(p, verbose=False):
    minerals = 20.0
    credits = 0.0
    sci = 0.0
    planets = [{'d': 1, 'dl': 1, 'l': 0, 'll': 1, 'h': 0, 'hl': 1,
                'dep': DEP_HOME, 'sys': 0}]
    gens = 4
    mult = 1.0
    tech_i = 0
    port = False
    elev = False
    ship_n = 0
    events = []
    checkpoints = {}
    t = 0.0

    def n_sys():
        return max(x['sys'] for x in planets) + 1

    def sys_count(si):
        return sum(1 for x in planets if x['sys'] == si)

    def demand():
        return sum(2.0 * x['d'] + x['l'] + x['h'] for x in planets)

    def eff():
        d = demand()
        if d <= 0:
            return 1.0
        return min(1.0, gens * GEN_OUT / d)

    def min_income():
        s = 0.0
        for x in planets:
            s += x['d'] * DRILL_OUT * (UPG_MULT ** (x['dl'] - 1))
        return s * mult * eff()

    def sci_income():
        s = 0.0
        for x in planets:
            s += x['l'] * LAB_OUT * (UPG_MULT ** (x['ll'] - 1))
        return s * eff()

    def cred_income():
        s = 2.0 * len(planets)
        for x in planets:
            s += x['h'] * HUB_OUT * (UPG_MULT ** (x['hl'] - 1))
        return s * eff()

    def drill_cost(x):
        return p['drill_base'] * (p['drill_g'] ** x['d'])

    def lab_cost(x):
        return p['lab_base'] * (p['lab_g'] ** x['l'])

    def hub_costs(x):
        mc = 70.0 * (1.14 ** x['h'])
        cc = 40.0 * (1.14 ** x['h'])
        return mc, cc

    def try_pay(mc, cc=0.0):
        nonlocal minerals, credits
        if minerals >= mc and credits >= cc:
            minerals -= mc
            credits -= cc
            return True
        return False

    def tech_ready():
        if tech_i >= len(TECHS):
            return False
        _, _, req, val = TECHS[tech_i]
        if req == 'labs':
            return sum(x['l'] for x in planets) >= val
        if req == 'planets':
            return len(planets) >= val
        if req == 'port':
            return port and len(planets) >= val
        if req == 'elev':
            return elev
        return False

    target_hours = [h for h, _ in TARGETS]
    next_ti = 0

    while t < T_END:
        t += DT
        e = eff()
        while next_ti < len(target_hours) and t >= target_hours[next_ti] * 3600:
            checkpoints[target_hours[next_ti]] = (min_income(), len(planets))
            next_ti += 1

        minerals += min_income() * DT
        sci += sci_income() * DT
        credits += cred_income() * DT

        # --- 能源优先 ---
        if e < 0.95:
            gc = 18.0 * (1.12 ** gens)
            if minerals >= gc:
                minerals -= gc
                gens += 1
            continue

        used = sum(x['d'] for x in planets)
        tot = sum(x['dep'] for x in planets)

        # --- Spaceport ---
        if not port and used >= PORT_THRESH * tot and try_pay(3000.0, 1500.0):
            port = True
            events.append(('spaceport', round(t / 3600, 2), len(planets)))

        # --- 殖民: 矿点占用≥85%; 本系满3颗且已研究T3才开新系 ---
        if port and used >= COLONIZE_THRESH * tot and len(planets) < MAX_PLANETS:
            cur = n_sys() - 1
            if sys_count(cur) < SYS_MAX_PLANETS:
                target_sys, gate = cur, True
            elif tech_i >= 3:
                target_sys, gate = cur + 1, True
            else:
                gate = False
                target_sys = cur
            if gate:
                smc = p['ship_base'] * (p['ship_g'] ** ship_n)
                scc = smc * 0.5
                if try_pay(smc, scc):
                    ship_n += 1
                    idx = len(planets)
                    planets.append({'d': 0, 'dl': 1, 'l': 0, 'll': 1, 'h': 0, 'hl': 1,
                                    'dep': dep_of(idx), 'sys': target_sys})
                    first_in_sys = (sum(1 for q in planets if q['sys'] == target_sys) == 1)
                    ev = ('system%d' % target_sys) if first_in_sys else 'colonize'
                    events.append((ev, round(t / 3600, 2), len(planets)))

        # --- 太空电梯: 殖民3星球里程碑 + 固定大额 (§26) ---
        if not elev and len(planets) >= 3 \
                and try_pay(ELEV_MIN_COST * p.get('elev_scale', 1.0),
                            ELEV_MIN_CRED * p.get('elev_scale', 1.0)):
            elev = True
            events.append(('elevator', round(t / 3600, 2), 1))

        # --- 计分购买 ---
        best_score = -1.0
        best = None
        inc = min_income()
        for i, x in enumerate(planets):
            if x['d'] < x['dep']:
                c = drill_cost(x)
                gain = DRILL_OUT * (UPG_MULT ** (x['dl'] - 1)) * mult
                sc = gain / max(c, 1e-9)
                if sc > best_score:
                    best_score, best = sc, ('drill', i, c, 0.0)
            # 升级候选: 独立于空矿位 (v0-v2 bug: 嵌套导致满矿位星球永不升级)
            if x['d'] >= 1:
                c = drill_cost(x)
                uc = c * p['upg_base'] * (p['upg_ratio'] ** x['dl'])
                ug = x['d'] * DRILL_OUT * (UPG_MULT - 1) * (UPG_MULT ** (x['dl'] - 1)) * mult
                sc = ug / max(uc, 1e-9)
                if sc > best_score:
                    best_score, best = sc, ('dupg', i, uc, 0.0)
            if x['l'] < x['dep']:
                c = lab_cost(x)
                gain = LAB_OUT * (UPG_MULT ** (x['ll'] - 1)) * p['k_sci']
                sc = gain / max(c, 1e-9)
                if sc > best_score:
                    best_score, best = sc, ('lab', i, c, 0.0)
            if x['l'] >= 1:
                c = lab_cost(x)
                uc = c * p['upg_base'] * (p['upg_ratio'] ** x['ll'])
                ug = x['l'] * LAB_OUT * (UPG_MULT - 1) * (UPG_MULT ** (x['ll'] - 1)) * p['k_sci']
                sc = ug / max(uc, 1e-9)
                if sc > best_score:
                    best_score, best = sc, ('lupg', i, uc, 0.0)
            if x['h'] < 4:
                mc, cc = hub_costs(x)
                gain = HUB_OUT * K_CRED
                sc = gain / max(mc + cc * K_CRED, 1e-9)
                if sc > best_score:
                    best_score, best = sc, ('hub', i, mc, cc)

        # --- 科技 (里程碑就绪才进计分) ---
        if tech_ready():
            C = TECHS[tech_i][0] * p['tech_scale']
            m = TECHS[tech_i][1]
            if sci >= C:
                sc_tech = inc * (m - 1) / max(C * p['k_sci'], 1e-9)
                if sc_tech > best_score:
                    best = ('tech', 0, 0.0, 0.0)
                    best_score = sc_tech

        if best is None:
            continue
        kind, i, mc, cc = best
        if kind == 'tech':
            C = TECHS[tech_i][0] * p['tech_scale']
            if sci >= C:
                sci -= C
                mult *= TECHS[tech_i][1]
                tech_i += 1
                events.append(('tech%d' % tech_i, round(t / 3600, 2), round(mult, 2)))
            continue
        if not try_pay(mc, cc):
            continue
        x = planets[i]
        if kind == 'drill':
            x['d'] += 1
        elif kind == 'dupg':
            x['dl'] += 1
        elif kind == 'lab':
            x['l'] += 1
        elif kind == 'lupg':
            x['ll'] += 1
        elif kind == 'hub':
            x['h'] += 1

    for h in target_hours:
        if h not in checkpoints:
            checkpoints[h] = (min_income(), len(planets))
    return dict(
        checkpoints=checkpoints,
        events=events,
        income=min_income(),
        sci_rate=sci_income(),
        planets=len(planets),
        systems=n_sys(),
        gens=gens,
        tech=tech_i,
        eff=eff(),
        ship_n=ship_n,
    )


def error_of(res):
    err = 0.0
    for h, tgt in TARGETS:
        act = res['checkpoints'].get(h, (0.0, 0))[0]
        if act <= 0:
            err += 100.0
            continue
        err += math.log(act / tgt) ** 2
    # 星球数量时间线 (§45): 0.5h≤3, 2h≤12, 5h∈[10,45]
    pc = {h: res['checkpoints'].get(h, (0, 0))[1] for h, _ in TARGETS}
    for h, lo, hi in [(0.5, 0, 3), (2.0, 0, 12), (5.0, 10, 45)]:
        n = pc.get(h, 0)
        if n > hi:
            err += (math.log(n / hi) ** 2) * 0.6
        if n < lo:
            err += (math.log(lo / max(n, 1)) ** 2) * 0.6

    def ev_time(prefix):
        for k, v, _ in res['events']:
            if k.startswith(prefix):
                return v
        return None
    et = ev_time('elevator')
    if et is None:
        err += 4.0
    elif not (0.8 <= et <= 2.5):
        err += (math.log(et / 1.5) ** 2) * 0.5
    st = ev_time('system')
    if st is None:
        err += 4.0
    elif not (1.5 <= st <= 4.5):
        err += (math.log(st / 3.0) ** 2) * 0.5
    # 科技节拍: tech1 在 0.3-1h
    t1 = ev_time('tech1')
    if t1 is None:
        err += 2.0
    elif not (0.3 <= t1 <= 1.2):
        err += (math.log(t1 / 0.6) ** 2) * 0.3
    return err


def report(res):
    print('%-8s %-14s %-14s %-8s %s' % ('时间', '目标/s', '实际/s', '倍数', '星球数'))
    for h, tgt in TARGETS:
        act, np_ = res['checkpoints'].get(h, (0.0, 0))
        print('%-8.1fh %-14.4g %-14.4g %-8.3f %d' %
              (h, tgt, act, act / tgt if tgt else 0, np_))
    shown = ', '.join('%s@%sh' % (k, v) for k, v, _ in res['events'] if k != 'gen')
    print('事件时间线:', shown)
    print('5h 状态: 星球=%d 系=%d 船=%d 发电机=%d 科技=%d/5 效率=%.2f 科学=%.1f/s'
          % (res['planets'], res['systems'], res['ship_n'], res['gens'],
             res['tech'], res['eff'], res['sci_rate']))
    print('总误差: %.4f' % error_of(res))


def in_bounds(k, v):
    lo, hi = BOUNDS[k]
    return lo <= v <= hi


def fit(p0, passes=5, steps=(0.8, 1.25)):
    p = dict(p0)
    keys = list(BOUNDS.keys())
    best_err = error_of(simulate(p))
    print('初始误差: %.4f' % best_err)
    for pass_i in range(passes):
        improved = False
        for k in keys:
            for s in steps:
                q = dict(p)
                q[k] = q[k] * s
                if not in_bounds(k, q[k]):
                    continue
                err = error_of(simulate(q))
                if err < best_err - 1e-6:
                    best_err, p = err, q
                    improved = True
        print('pass %d: 误差=%.4f%s' % (pass_i + 1, best_err, ' (有改进)' if improved else ' (收敛)'))
        if not improved:
            break
    # 随机退火: 单参数坐标下降需要多参数联动时会卡局部最优
    import random
    random.seed(42)
    for it in range(250):
        q = dict(p)
        k = random.choice(keys)
        q[k] *= math.exp(random.gauss(0, 0.3))
        if not in_bounds(k, q[k]):
            continue
        err = error_of(simulate(q))
        if err < best_err - 1e-6:
            best_err, p = err, q
    print('退火后: 误差=%.4f' % best_err)
    return p, best_err


if __name__ == '__main__':
    P0 = dict(
        drill_base=12.0,
        drill_g=1.13,
        upg_base=100.0,
        upg_ratio=1.80,
        lab_base=300.0,
        lab_g=1.14,
        tech_scale=1.0,
        k_sci=8.0,
        ship_base=5000.0,
        ship_g=1.45,
    )
    if len(sys.argv) > 1 and sys.argv[1] == 'fit':
        # 'fit2': 从上次拟合结果继续精调 (细步长)
        if len(sys.argv) > 2 and sys.argv[2] == 'fit2':
            with open('fitted_params.json') as f:
                P0 = json.load(f)['params']
            p, err = fit(P0, passes=8, steps=(0.9, 1.111))
        else:
            p, err = fit(P0)
        print('\n=== 拟合结果 ===')
        print(json.dumps(p, indent=2))
        res = simulate(p)
        report(res)
        with open('fitted_params.json', 'w') as f:
            json.dump({'params': p, 'error': err,
                       'checkpoints': {str(k): v for k, v in res['checkpoints'].items()},
                       'events': res['events']}, f, indent=2)
    else:
        print('=== 初始参数 ===')
        report(simulate(P0))
