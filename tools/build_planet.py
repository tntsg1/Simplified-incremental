#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""星际拓荒者 · 星球贴图生成（纯 PIL，无需 numpy）v2
深紫矿物星：右上强方向光 + 陨石坑 + 矿脉光点 + 紫色边缘光 + 大气光晕。
输出: assets/planet.png (640x640 RGBA)  圆盘直径 560（半径 280）
游戏侧换算: PLANET_SCALE = 640/560
"""
import math
import os
import random
from PIL import Image, ImageDraw, ImageEnhance, ImageFilter, ImageChops

random.seed(20260923)

SS = 2
W = 640 * SS
R = 280 * SS
C = W // 2
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "assets", "planet.png")


def disc_mask(radius, blur=0.0):
    m = Image.new("L", (W, W), 0)
    d = ImageDraw.Draw(m)
    d.ellipse([C - radius, C - radius, C + radius, C + radius], fill=255)
    if blur > 0:
        m = m.filter(ImageFilter.GaussianBlur(blur))
    return m


def main():
    # ---------- 1. 地形噪声层 ----------
    terrain = Image.new("RGBA", (W, W), (0, 0, 0, 0))
    td = ImageDraw.Draw(terrain)
    for _ in range(10):  # 大块地貌
        x = random.randint(C - R, C + R)
        y = random.randint(C - R, C + R)
        s = random.randint(120, 250) * SS
        col = random.choice([(42, 34, 64), (56, 46, 80), (81, 65, 96), (62, 40, 96), (107, 74, 142)])
        td.ellipse([x - s, y - s // 2, x + s, y + s // 2], fill=col + (255,))
    for _ in range(430):  # 细碎斑驳
        x = random.randint(C - R, C + R)
        y = random.randint(C - R, C + R)
        s = random.randint(8, 42) * SS
        col = random.choice([(30, 24, 48), (42, 34, 64), (52, 48, 71), (81, 65, 96), (96, 72, 128)])
        td.ellipse([x - s, y - s // 2, x + s, y + s // 2], fill=col + (255,))
    terrain = terrain.filter(ImageFilter.GaussianBlur(7 * SS))

    # ---------- 2. 陨石坑（清晰层） ----------
    craters = Image.new("RGBA", (W, W), (0, 0, 0, 0))
    cd = ImageDraw.Draw(craters)
    for _ in range(60):
        ang = random.random() * math.tau
        rad = (random.random() ** 0.6) * R * 0.95
        x = C + math.cos(ang) * rad
        y = C + math.sin(ang) * rad
        r = random.randint(2, 10) * SS
        cd.ellipse([x - r, y - r, x + r, y + r], fill=(20, 15, 32, 160))
        cd.arc([x - r, y - r, x + r, y + r], start=-85, end=-5,
               fill=(128, 106, 160, 120), width=SS)
    craters = craters.filter(ImageFilter.GaussianBlur(0.9 * SS))

    # ---------- 3. 合成球体 ----------
    body = Image.new("RGBA", (W, W), (42, 34, 64, 255))
    body.alpha_composite(terrain)
    body.alpha_composite(craters)

    # 方向光照梯度：沿 (x - y) 轴，右上最亮
    light = Image.new("L", (W, W), 0)
    ld = ImageDraw.Draw(light)
    for k in range(-W, W + 1):
        v = int(255 * max(0.0, min(1.0, (k + W) / (2.0 * W))))
        ld.line([(k, 0), (k + W, W)], fill=v)

    disc = disc_mask(R, 1.0)
    hi_mask = ImageChops.multiply(light.point(lambda v: int(v * 0.40)), disc)
    lo_mask = ImageChops.multiply(light.point(lambda v: int((255 - v) * 0.52)), disc)
    hi = Image.new("RGBA", (W, W), (212, 140, 252, 255))
    lo = Image.new("RGBA", (W, W), (4, 2, 12, 255))
    body.alpha_composite(Image.composite(hi, Image.new("RGBA", (W, W), (0, 0, 0, 0)), hi_mask))
    body.alpha_composite(Image.composite(lo, Image.new("RGBA", (W, W), (0, 0, 0, 0)), lo_mask))

    fin = Image.new("RGBA", (W, W), (0, 0, 0, 0))
    fin.paste(body, (0, 0), disc)

    # ---------- 4. 矿脉光点 ----------
    veins = Image.new("RGBA", (W, W), (0, 0, 0, 0))
    vd = ImageDraw.Draw(veins)
    for _ in range(10):
        ang = random.random() * math.tau
        rad = (random.random() ** 0.7) * R * 0.88
        x = C + math.cos(ang) * rad
        y = C + math.sin(ang) * rad
        r = random.randint(2, 5) * SS
        vd.ellipse([x - r * 2, y - r * 2, x + r * 2, y + r * 2], fill=(150, 90, 220, 60))
        vd.ellipse([x - r, y - r, x + r, y + r], fill=(235, 175, 255, 180))
    veins = veins.filter(ImageFilter.GaussianBlur(2.0 * SS))
    veins.putalpha(ImageChops.multiply(veins.getchannel("A"), disc))
    fin.alpha_composite(veins)

    # ---------- 5. 边缘光 + 大气光晕（方向性：右上更强） ----------
    dir_m = light.point(lambda v: int(95 + v * 0.65))

    ring = ImageChops.subtract(disc, disc_mask(R - 8 * SS))
    ring = ring.filter(ImageFilter.GaussianBlur(4 * SS))
    ring = ImageChops.multiply(ring, dir_m)
    rim_col = Image.new("RGBA", (W, W), (206, 118, 250, 255))
    fin.alpha_composite(Image.composite(rim_col, Image.new("RGBA", (W, W), (0, 0, 0, 0)), ring))

    ring2 = ImageChops.subtract(disc, disc_mask(R - 3 * SS))
    ring2 = ring2.filter(ImageFilter.GaussianBlur(1.4 * SS))
    ring2 = ImageChops.multiply(ring2, light.point(lambda v: int(60 + v * 0.78)))
    rim2_col = Image.new("RGBA", (W, W), (240, 210, 255, 255))
    fin.alpha_composite(Image.composite(rim2_col, Image.new("RGBA", (W, W), (0, 0, 0, 0)), ring2))

    atmo = ImageChops.subtract(disc_mask(R + 22 * SS, 16 * SS), disc)
    atmo = ImageChops.multiply(atmo, light.point(lambda v: int(55 + v * 0.70)))
    atmo_col = Image.new("RGBA", (W, W), (132, 72, 212, 255))
    fin.alpha_composite(Image.composite(atmo_col, Image.new("RGBA", (W, W), (0, 0, 0, 0)), atmo))

    # ---------- 6. 对比度微调 + 收尾 ----------
    alpha = fin.getchannel("A")
    fin = ImageEnhance.Contrast(fin.convert("RGB")).enhance(1.12).convert("RGBA")
    fin.putalpha(alpha)
    fin = fin.resize((640, 640), Image.LANCZOS)
    fin.save(OUT)
    print("saved:", OUT, fin.size)


if __name__ == "__main__":
    main()