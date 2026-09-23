#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""阶段0 复核图: 现拟合结果 vs 设计目标检查点。

用法: python3 tools/plot_curve.py
输出: design/curve_v0.png （同时打印完整 report）
说明: 这是 v0（旧稿范围 0-5h）的复核图，作为数值心脏 v2 的工作起点。
"""
import json
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from simulate import simulate, report, TARGETS  # noqa: E402

import matplotlib  # noqa: E402
matplotlib.use("Agg")
import matplotlib.pyplot as plt  # noqa: E402
import matplotlib.font_manager as fm  # noqa: E402

for cand in ["Microsoft YaHei", "SimHei", "Noto Sans CJK SC"]:
    try:
        fm.findfont(fm.FontProperties(family=cand), fallback_to_default=False)
        plt.rcParams["font.sans-serif"] = [cand]
        break
    except Exception:
        continue
plt.rcParams["axes.unicode_minus"] = False

base = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
with open(os.path.join(base, "fitted_params.json"), encoding="utf-8") as f:
    data = json.load(f)
P = data["params"]

series = []
res = simulate(P, series=series)

hs = [t / 3600.0 for t, _, _ in series]
inc = [max(v, 1e-3) for _, v, _ in series]

fig, ax = plt.subplots(figsize=(10, 5.2), dpi=130)
ax.set_title("Stellar Ascension · 现拟合曲线 vs 目标检查点（旧范围 0–5h 复核）", fontsize=12)
ax.plot(hs, inc, color="#3fae9f", lw=2, label="模拟矿物收入 /s")
tx = [h for h, _ in TARGETS]
ty = [v for _, v in TARGETS]
ax.plot(tx, ty, "D--", color="#d9534f", ms=6, lw=1.2, label="设计目标检查点")

seen = set()
for k, v, _ in data.get("events", []):
    if k in seen:
        continue
    seen.add(k)
    ax.axvline(v, color="#888", ls=":", lw=1)
    ax.annotate(k + "@%sh" % v, xy=(v, 2.0), rotation=90, fontsize=8,
                color="#666", va="bottom")

ax.set_yscale("log")
ax.set_xlim(0, 5.4)
ax.set_ylim(1.0, max(inc) * 4)
ax.set_xlabel("小时")
ax.set_ylabel("收入 /s（log）")
ax.grid(alpha=0.25)
ax.legend(loc="upper left")
out = os.path.join(base, "design", "curve_v0.png")
plt.tight_layout()
plt.savefig(out)
print("saved:", out)
report(res)