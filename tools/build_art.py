#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""zengliang · 自制美术生成器 v2 —— 《星际拓荒者》重做版的贴图全部从这里出。

风格定位: 冷峻工程图 —— 深蓝灰金属 + 青色/琥珀光带，统一左上光源，2x 超采样。
v2 修订（对照自评）:
  1. 功能语义优先：矿机=钻头+矿坑+传送带+矿仓；商店=多层+窗口+招牌+货柜+吊臂；
     科研=穹顶+望远镜；殖民=多穹顶居住群；每个图标一个一眼可辨的核心符号。
  2. 统一规范：建筑全部站在同一"地面线"(y≈214)，光源统一左上，主轮廓线 ≥2.5px，
     消化不了的细线全部删掉或加粗（缩小后不糊）。
  3. 星球与建筑风格对齐：硬边清晰、明确明暗面、加强大气边光。

输出: assets/*.png （透明底）+ assets/_preview.png（自检拼图）
用法: python3 tools/build_art.py
"""
import math
import os
import random

from PIL import Image, ImageDraw, ImageFilter

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "assets")
SS = 2  # 超采样倍数

# ---------- 调色板 ----------
INK = (14, 18, 28, 255)
SLATE_D = (40, 48, 64, 255)
SLATE_M = (62, 75, 99, 255)
SLATE_L = (150, 170, 206, 255)
STEEL = (108, 124, 154, 255)
CYAN = (95, 215, 232, 255)
CYAN_DIM = (52, 130, 150, 255)
AMBER = (255, 179, 71, 255)
AMBER_D = (172, 110, 32, 255)
MAGENTA = (232, 121, 206, 255)
DARKHOLE = (8, 11, 18, 255)
OCEAN_HI = (44, 92, 132, 255)
OCEAN_LO = (14, 38, 68, 255)
LAND_A = (92, 128, 106, 255)
LAND_B = (108, 138, 98, 255)


class Pen:
    """把 0..256 的设计坐标按超采样倍数放大后绘制的画笔。"""

    def __init__(self, img):
        self.img = img
        self.d = ImageDraw.Draw(img)
        self.s = SS

    def _p(self, xy):
        return [(x * self.s, y * self.s) for x, y in xy]

    def _box(self, box):
        x0, y0, x1, y1 = box
        return [x0 * self.s, y0 * self.s, x1 * self.s, y1 * self.s]

    def poly(self, pts, fill=None, outline=None, width=2):
        w = max(1, int(round(width * self.s)))
        self.d.polygon(self._p(pts), fill=fill, outline=outline, width=w if outline else 0)

    def oval(self, box, fill=None, outline=None, width=2):
        self.d.ellipse(self._box(box), fill=fill, outline=outline,
                       width=max(1, int(round(width * self.s))))

    def rrect(self, box, r, fill=None, outline=None, width=2):
        self.d.rounded_rectangle(self._box(box), radius=r * self.s, fill=fill,
                                 outline=outline, width=max(1, int(round(width * self.s))))

    def line(self, pts, fill, width=3):
        self.d.line(self._p(pts), fill=fill, width=max(1, int(round(width * self.s))), joint="curve")

    def outlined_line(self, pts, color, width=3):
        self.line(pts, INK, width + 2.5)
        self.line(pts, color, width)


def canvas(w=256, h=256):
    return Image.new("RGBA", (w * SS, h * SS), (0, 0, 0, 0))


def glow(img, layer, radius=8, times=2):
    g = layer.filter(ImageFilter.GaussianBlur(radius * SS))
    for _ in range(times):
        img.alpha_composite(g)
    return img


def soft_shadow(img, cx, cy, rx, ry, alpha=110):
    sh = Image.new("RGBA", img.size, (0, 0, 0, 0))
    Pen(sh).oval([cx - rx, cy - ry, cx + rx, cy + ry], fill=(0, 0, 0, alpha))
    glow(img, sh, radius=6, times=1)


def finish(img, w=256, h=256):
    return img.resize((w, h), Image.LANCZOS)


def hexagon(cx, cy, r, squash=0.55):
    pts = []
    for i in range(6):
        a = math.radians(60 * i - 30)
        pts.append((cx + r * math.cos(a), cy + r * squash * math.sin(a)))
    return pts


def ore_chunk(pen, cx, cy, r=6):
    pen.poly([(cx - r, cy + r * 0.4), (cx - r * 0.4, cy - r * 0.8),
              (cx + r * 0.7, cy - r * 0.5), (cx + r, cy + r * 0.5), (cx, cy + r)],
             fill=AMBER, outline=INK, width=2)


def window_rows(pen, x0, y0, cols, rows, ww, wh, gx, gy, color=AMBER, glow_layer=None):
    for j in range(rows):
        for i in range(cols):
            x = x0 + i * (ww + gx)
            y = y0 + j * (wh + gy)
            pen.rrect([x, y, x + ww, y + wh], 2, fill=color)
            if glow_layer is not None:
                Pen(glow_layer).rrect([x, y, x + ww, y + wh], 2, fill=color)


# =====================================================================
#  建筑（每个都围绕一个"一眼可辨"的核心符号）
# =====================================================================

def make_miner():
    """核心符号: 井架 + 钻头钻入矿坑 + 传送带 + 矿石堆。"""
    img = canvas()
    soft_shadow(img, 128, 218, 80, 19)
    pen = Pen(img)
    pen.poly(hexagon(128, 208, 78), fill=SLATE_M, outline=INK, width=2.5)
    pen.poly(hexagon(128, 206, 60), fill=None, outline=SLATE_D, width=1.6)
    # 矿坑
    pen.oval([100, 188, 156, 214], fill=DARKHOLE, outline=INK, width=2.2)
    pen.oval([108, 192, 148, 208], fill=(20, 24, 36, 255))
    # 井架：粗腿 + 交叉支撑
    pen.outlined_line([(90, 202), (128, 92)], SLATE_L, 6)
    pen.outlined_line([(166, 202), (128, 92)], SLATE_L, 6)
    pen.outlined_line([(103, 174), (153, 150)], STEEL, 3)
    pen.outlined_line([(153, 174), (103, 150)], STEEL, 3)
    pen.outlined_line([(110, 142), (146, 142)], STEEL, 3)
    # 顶部机匣
    pen.rrect([116, 82, 140, 100], 4, fill=SLATE_M, outline=INK, width=2.2)
    # 钻杆
    pen.line([(128, 98), (128, 184)], INK, 9)
    pen.line([(128, 98), (128, 184)], STEEL, 5)
    # 钻头锥（进入矿坑）
    cone = [(112, 174), (144, 174), (128, 206)]
    pen.poly(cone, fill=SLATE_L, outline=INK, width=2.5)
    for yy in (180, 187, 194):
        half = (yy - 174) * 0.55
        pen.line([(128 - half, yy), (128 + half, yy)], INK, 1.8)
    # 传送带 → 矿仓
    pen.outlined_line([(172, 198), (216, 178)], SLATE_L, 5)
    ore_chunk(pen, 184, 191, 6)
    ore_chunk(pen, 197, 185, 6)
    ore_chunk(pen, 209, 180, 5)
    pen.rrect([204, 160, 232, 194], 4, fill=SLATE_D, outline=INK, width=2.4)
    pen.line([(208, 168), (228, 168)], AMBER_D, 2.5)
    pen.line([(208, 176), (228, 176)], AMBER, 2)
    # 警示灯
    lamp = Image.new("RGBA", img.size, (0, 0, 0, 0))
    Pen(lamp).oval([119, 70, 137, 88], fill=AMBER)
    img.alpha_composite(lamp)
    glow(img, lamp, radius=7, times=2)
    # 钻头/坑口辉光
    dl = Image.new("RGBA", img.size, (0, 0, 0, 0))
    Pen(dl).poly(cone, fill=(95, 215, 232, 120))
    glow(img, dl, radius=8, times=2)
    return finish(img)


def make_solar():
    """核心符号: 三面同角度光伏板 + 电池格纹理 + 变压器。"""
    img = canvas()
    soft_shadow(img, 128, 218, 84, 16)
    pen = Pen(img)
    pen.rrect([40, 200, 214, 218], 6, fill=SLATE_D, outline=INK, width=2.2)
    pen.line([(48, 202), (206, 202)], SLATE_L, 2)
    for cx in [76, 128, 180]:
        tl = (cx - 24, 122)
        tr = (cx + 22, 130)
        br = (cx + 24, 166)
        bl = (cx - 22, 158)
        pen.poly([tl, tr, br, bl], fill=SLATE_M, outline=INK, width=2.6)
        pen.line([tl, tr], SLATE_L, 2.6)
        for k in range(1, 3):
            t = k / 3.0
            pen.line([(tl[0] + (bl[0] - tl[0]) * t, tl[1] + (bl[1] - tl[1]) * t),
                      (tr[0] + (br[0] - tr[0]) * t, tr[1] + (br[1] - tr[1]) * t)], SLATE_D, 1.6)
        mid = ((tl[0] + tr[0]) / 2, (tl[1] + tr[1]) / 2 + 20)
        pen.outlined_line([mid, (cx, 198)], SLATE_L, 4)
    pen.rrect([216, 184, 242, 212], 4, fill=SLATE_M, outline=INK, width=2.2)
    pen.line([(220, 190), (238, 190)], CYAN_DIM, 2)
    pen.line([(220, 196), (238, 196)], CYAN_DIM, 2)
    sheet = Image.new("RGBA", img.size, (0, 0, 0, 0))
    sp = Pen(sheet)
    for cx in [76, 128, 180]:
        sp.line([(cx - 24, 122), (cx + 22, 130)], (95, 215, 232, 110), 3)
    glow(img, sheet, radius=5, times=1)
    return finish(img)


def make_fusion():
    """核心符号: 磁约束环 + 等离子核心（不规则辉光）。"""
    img = canvas()
    soft_shadow(img, 128, 218, 78, 18)
    pen = Pen(img)
    pen.rrect([56, 192, 200, 218], 7, fill=SLATE_D, outline=INK, width=2.2)
    for x in [64, 192]:
        pen.outlined_line([(x, 190), (x, 100)], SLATE_L, 6)
        pen.rrect([x - 9, 92, x + 9, 106], 3, fill=STEEL, outline=INK, width=2.2)
    # 柱体
    pen.oval([86, 74, 170, 104], fill=SLATE_M, outline=INK, width=2.5)
    pen.rrect([86, 89, 170, 176], 2, fill=SLATE_M, outline=INK, width=2.5)
    pen.oval([86, 162, 170, 192], fill=SLATE_D, outline=INK, width=2.5)
    pen.line([(90, 96), (90, 170)], SLATE_L, 2.5)
    # 磁约束环（围绕上部）
    pen.oval([74, 96, 182, 130], outline=SLATE_L, width=3)
    pen.oval([74, 96, 182, 130], outline=(95, 215, 232, 70), width=6)
    # 核心窗
    pen.oval([102, 108, 154, 152], fill=(12, 16, 26, 255), outline=INK, width=2.8)
    plasma = [(128, 114), (140, 122), (146, 136), (138, 146), (126, 148),
              (114, 142), (108, 132), (112, 120)]
    pen.poly(plasma, fill=CYAN, outline=(214, 248, 255, 255), width=2)
    core = Image.new("RGBA", img.size, (0, 0, 0, 0))
    cp = Pen(core)
    cp.poly(plasma, fill=(95, 215, 232, 160))
    core = core.filter(ImageFilter.GaussianBlur(10 * SS))
    img.alpha_composite(core)
    img.alpha_composite(core)
    for x in [64, 192]:
        glow(img, _dot_layer(img.size, x, 92, 6, AMBER), radius=6, times=2)
    return finish(img)


def _dot_layer(size, cx, cy, r, color):
    lay = Image.new("RGBA", size, (0, 0, 0, 0))
    Pen(lay).oval([cx - r, cy - r, cx + r, cy + r], fill=color)
    return lay


def make_lab():
    """核心符号: 穹顶实验室 + 大口径望远镜筒。"""
    img = canvas()
    soft_shadow(img, 128, 218, 80, 18)
    pen = Pen(img)
    pen.rrect([50, 194, 206, 218], 7, fill=SLATE_D, outline=INK, width=2.4)
    pen.line([(58, 198), (198, 198)], SLATE_L, 2)
    pen.rrect([62, 182, 194, 200], 4, fill=SLATE_M, outline=INK, width=2.4)
    # 主穹顶
    pen.d.pieslice([74 * SS, 108 * SS, 182 * SS, 204 * SS], 180, 360,
                   fill=SLATE_M, outline=INK, width=int(2.6 * SS))
    pen.d.arc([80 * SS, 114 * SS, 176 * SS, 198 * SS], 195, 340,
              fill=SLATE_L, width=int(2.2 * SS))
    # 望远镜筒（从穹顶左上斜出）
    tube = [(98, 128), (152, 96), (162, 112), (108, 144)]
    pen.poly(tube, fill=STEEL, outline=INK, width=2.6)
    pen.oval([146, 90, 172, 118], fill=SLATE_L, outline=INK, width=2.4)
    pen.oval([150, 95, 166, 111], fill=CYAN_DIM)
    lens = Image.new("RGBA", img.size, (0, 0, 0, 0))
    Pen(lens).oval([150, 95, 166, 111], fill=(95, 215, 232, 140))
    glow(img, lens, radius=6, times=2)
    pen.outlined_line([(120, 150), (128, 176)], SLATE_L, 4)
    # 窗与门
    wins = Image.new("RGBA", img.size, (0, 0, 0, 0))
    wp = Pen(wins)
    for x in [96, 116, 136, 156]:
        wp.rrect([x, 172, x + 10, 183], 3, fill=CYAN)
    wp.rrect([120, 190, 136, 202], 3, fill=DARKHOLE)
    img.alpha_composite(wins)
    glow(img, wins, radius=6, times=1)
    # 侧面样本罐 x2
    pen.rrect([192, 168, 208, 204], 4, fill=SLATE_M, outline=INK, width=2.2)
    pen.oval([192, 164, 208, 176], fill=SLATE_L, outline=INK, width=1.8)
    pen.rrect([212, 176, 226, 204], 4, fill=SLATE_M, outline=INK, width=2.2)
    # 顶部信标
    beacon = _dot_layer(img.size, 128, 100, 7, AMBER)
    pen.outlined_line([(128, 106), (128, 84)], SLATE_L, 3)
    img.alpha_composite(beacon)
    glow(img, beacon, radius=6, times=2)
    return finish(img)


def make_commerce():
    """核心符号: 多层塔楼 + 发光招牌（环形徽记）+ 货柜 + 吊臂。"""
    img = canvas()
    soft_shadow(img, 128, 220, 80, 17)
    pen = Pen(img)
    # 三层塔楼
    pen.rrect([64, 158, 180, 206], 7, fill=SLATE_M, outline=INK, width=2.6)
    pen.rrect([76, 118, 168, 162], 7, fill=SLATE_D, outline=INK, width=2.6)
    pen.rrect([90, 80, 154, 122], 7, fill=SLATE_M, outline=INK, width=2.6)
    pen.line([(70, 162), (174, 162)], SLATE_L, 2.4)
    pen.line([(82, 122), (162, 122)], SLATE_L, 2.4)
    pen.line([(96, 84), (148, 84)], SLATE_L, 2.4)
    wins = Image.new("RGBA", img.size, (0, 0, 0, 0))
    wp = Pen(wins)
    window_rows(wp, 74, 174, 4, 2, 14, 10, 12, 8, AMBER, wins)
    window_rows(wp, 86, 132, 3, 2, 14, 9, 14, 7, AMBER, wins)
    window_rows(wp, 100, 94, 2, 2, 14, 8, 16, 6, CYAN, wins)
    img.alpha_composite(wins)
    glow(img, wins, radius=6, times=1)
    # 底层亮橱窗（商铺门面）
    shop = Image.new("RGBA", img.size, (0, 0, 0, 0))
    spp = Pen(shop)
    spp.rrect([72, 184, 172, 204], 5, fill=(95, 215, 232, 130))
    img.alpha_composite(shop)
    glow(img, shop, radius=8, times=2)
    # 招牌：青色圆环徽记
    sign = Image.new("RGBA", img.size, (0, 0, 0, 0))
    sp = Pen(sign)
    sp.oval([100, 36, 156, 92], outline=CYAN, width=6)
    sp.oval([118, 54, 138, 74], fill=CYAN)
    sp.poly([(86, 62), (110, 56), (110, 90)], fill=AMBER, outline=INK, width=2)
    sp.poly([(170, 56), (146, 62), (146, 90)], fill=MAGENTA, outline=INK, width=2)
    img.alpha_composite(sign)
    glow(img, sign, radius=8, times=2)
    pen.outlined_line([(128, 84), (128, 66)], SLATE_L, 3)
    # 货柜与吊臂
    pen.rrect([184, 176, 214, 206], 4, fill=AMBER_D, outline=INK, width=2.4)
    pen.rrect([216, 186, 242, 208], 4, fill=MAGENTA, outline=INK, width=2.4)
    pen.outlined_line([(150, 96), (214, 96)], SLATE_L, 4)
    pen.outlined_line([(214, 96), (214, 130)], SLATE_L, 4)
    pen.outlined_line([(214, 130), (198, 130)], SLATE_L, 3)
    pen.rrect([188, 124, 212, 150], 4, fill=STEEL, outline=INK, width=2.4)
    return finish(img)


def make_colony():
    """核心符号: 中央主穹顶 + 两侧居住舱群 + 连廊。"""
    img = canvas()
    soft_shadow(img, 128, 220, 86, 19)
    pen = Pen(img)
    pen.rrect([38, 188, 218, 218], 8, fill=SLATE_D, outline=INK, width=2.4)
    pen.line([(46, 192), (210, 192)], SLATE_L, 2)
    # 两侧穹顶居住舱
    pen.d.pieslice([48 * SS, 148 * SS, 106 * SS, 204 * SS], 180, 360,
                   fill=SLATE_M, outline=INK, width=int(2.4 * SS))
    pen.d.pieslice([150 * SS, 148 * SS, 208 * SS, 204 * SS], 180, 360,
                   fill=SLATE_M, outline=INK, width=int(2.4 * SS))
    # 连廊
    pen.rrect([96, 170, 118, 192], 4, fill=STEEL, outline=INK, width=2.2)
    pen.rrect([138, 170, 160, 192], 4, fill=STEEL, outline=INK, width=2.2)
    # 主穹顶
    pen.d.pieslice([76 * SS, 104 * SS, 180 * SS, 208 * SS], 180, 360,
                   fill=SLATE_M, outline=INK, width=int(2.6 * SS))
    pen.d.arc([82 * SS, 110 * SS, 174 * SS, 202 * SS], 200, 345,
              fill=SLATE_L, width=int(2.2 * SS))
    pen.rrect([74, 194, 182, 206], 4, fill=STEEL, outline=INK, width=2.2)
    # 窗（暖光）
    wins = Image.new("RGBA", img.size, (0, 0, 0, 0))
    wp = Pen(wins)
    for x in [92, 112, 132, 152]:
        wp.rrect([x, 176, x + 10, 188], 3, fill=AMBER)
    for x in [62, 80]:
        wp.rrect([x, 168, x + 9, 180], 3, fill=AMBER)
    for x in [166, 184]:
        wp.rrect([x, 168, x + 9, 180], 3, fill=AMBER)
    wp.rrect([118, 190, 138, 206], 3, fill=DARKHOLE)
    img.alpha_composite(wins)
    glow(img, wins, radius=6, times=1)
    # 塔尖信标
    pen.outlined_line([(128, 106), (128, 60)], SLATE_L, 4)
    beacon = _dot_layer(img.size, 128, 50, 8, CYAN)
    pen.oval([119, 41, 137, 59], outline=CYAN_DIM, width=3)
    img.alpha_composite(beacon)
    glow(img, beacon, radius=8, times=2)
    return finish(img)


# =====================================================================
#  星球
# =====================================================================

def make_planet(size=512):
    R = 230
    W = size
    img = Image.new("RGBA", (W * SS, W * SS), (0, 0, 0, 0))
    cx = cy = W / 2.0
    # 海洋（垂直渐变：上亮下暗）
    grad = Image.new("RGBA", img.size, (0, 0, 0, 0))
    gd = ImageDraw.Draw(grad)
    steps = 96
    for i in range(steps):
        t = i / (steps - 1.0)
        col = tuple(int(OCEAN_HI[c] + (OCEAN_LO[c] - OCEAN_HI[c]) * t) for c in range(3)) + (255,)
        y0 = int(W * SS * i / steps)
        y1 = int(W * SS * (i + 1) / steps) + 1
        gd.rectangle([0, y0, W * SS, y1], fill=col)
    rnd = random.Random(11)
    land = Image.new("RGBA", img.size, (0, 0, 0, 0))
    lp = Pen(land)
    centers = [(170, 160, 55, 105), (330, 245, 60, 115), (215, 380, 50, 100), (300, 115, 22, 40)]
    for idx, (lcx, lcy, rmin, rmax) in enumerate(centers):
        n = rnd.randint(9, 13)
        pts = []
        for i in range(n):
            a = 2 * math.pi * i / n + rnd.uniform(-0.15, 0.15)
            r = rnd.uniform(rmin, rmax)
            pts.append((lcx + r * math.cos(a), lcy + r * math.sin(a) * 0.78))
        col = LAND_A if idx % 2 == 0 else LAND_B
        lp.poly(pts, fill=col, outline=(140, 175, 150, 90), width=2)
    land = land.filter(ImageFilter.GaussianBlur(1.0 * SS))
    # 云带（沿纬度方向的长条）
    clouds = Image.new("RGBA", img.size, (0, 0, 0, 0))
    cp = Pen(clouds)
    for i in range(9):
        ccx = rnd.uniform(90, W - 90)
        ccy = rnd.uniform(70, W - 70)
        rx = rnd.uniform(46, 90)
        ry = rnd.uniform(13, 24)
        cp.oval([ccx - rx, ccy - ry, ccx + rx, ccy + ry], fill=(240, 248, 255, 52))
    clouds = clouds.filter(ImageFilter.GaussianBlur(7 * SS))
    mask = Image.new("L", img.size, 0)
    ImageDraw.Draw(mask).ellipse([(cx - R) * SS, (cy - R) * SS, (cx + R) * SS, (cy + R) * SS], fill=255)
    out = Image.new("RGBA", img.size, (0, 0, 0, 0))
    sphere = Image.new("RGBA", img.size, (0, 0, 0, 0))
    sphere.paste(grad, (0, 0), mask)
    sphere.alpha_composite(Image.composite(land, Image.new("RGBA", img.size, (0, 0, 0, 0)), mask))
    # 极冠
    ice = Image.new("RGBA", img.size, (0, 0, 0, 0))
    ip = Pen(ice)
    ip.oval([150, 20, 362, 92], fill=(226, 240, 246, 170))
    ip.oval([168, 424, 344, 492], fill=(226, 240, 246, 170))
    ice = ice.filter(ImageFilter.GaussianBlur(4 * SS))
    sphere.alpha_composite(Image.composite(ice, Image.new("RGBA", img.size, (0, 0, 0, 0)), mask))
    sphere.alpha_composite(Image.composite(clouds, Image.new("RGBA", img.size, (0, 0, 0, 0)), mask))
    out.alpha_composite(sphere)
    # 明暗：左上亮 → 右下暗
    shade = Image.new("RGBA", img.size, (0, 0, 0, 0))
    Pen(shade).oval([cx - R * 1.2, cy - R * 1.2, cx + R * 1.2, cy + R * 1.2], fill=(8, 12, 22, 120))
    shade = shade.filter(ImageFilter.GaussianBlur(24 * SS))
    shifted = Image.new("RGBA", img.size, (0, 0, 0, 0))
    shifted.paste(shade, (int(R * 0.55 * SS), int(R * 0.62 * SS)))
    out.alpha_composite(Image.composite(shifted, Image.new("RGBA", img.size, (0, 0, 0, 0)), mask))
    # 左上边缘高光
    hi = Image.new("RGBA", img.size, (0, 0, 0, 0))
    hd = ImageDraw.Draw(hi)
    hd.arc([(cx - R + 2) * SS, (cy - R + 2) * SS, (cx + R - 2) * SS, (cy + R - 2) * SS],
           150, 300, fill=(200, 235, 245, 110), width=3 * SS)
    hi = hi.filter(ImageFilter.GaussianBlur(2 * SS))
    out.alpha_composite(Image.composite(hi, Image.new("RGBA", img.size, (0, 0, 0, 0)), mask))
    # 大气边光
    atm = Image.new("RGBA", img.size, (0, 0, 0, 0))
    Pen(atm).oval([cx - R - 7, cy - R - 7, cx + R + 7, cy + R + 7],
                  outline=(95, 215, 232, 135), width=5)
    atm = atm.filter(ImageFilter.GaussianBlur(5 * SS))
    out.alpha_composite(atm)
    out.alpha_composite(atm)
    return out.resize((size, size), Image.LANCZOS)


# =====================================================================
#  输出
# =====================================================================

def montage(sprites, path, cols=4):
    cell = 220
    rows = (len(sprites) + cols - 1) // cols
    bg = Image.new("RGBA", (cols * cell, rows * cell), (24, 28, 38, 255))
    for i, (name, im) in enumerate(sprites):
        x = (i % cols) * cell + (cell - im.width) // 2
        y = (i // cols) * cell + (cell - im.height) // 2
        bg.alpha_composite(im, (x, y))
    bg.save(path)


def main():
    os.makedirs(OUT, exist_ok=True)
    items = [
        ("miner", make_miner()),
        ("solar", make_solar()),
        ("fusion", make_fusion()),
        ("lab", make_lab()),
        ("commerce", make_commerce()),
        ("colony", make_colony()),
    ]
    for name, im in items:
        im.save(os.path.join(OUT, name + ".png"))
        print("saved", name + ".png", im.size)
    planet = make_planet()
    planet.save(os.path.join(OUT, "planet.png"))
    print("saved planet.png", planet.size)
    montage(items + [("planet", planet.resize((220, 220)))], os.path.join(OUT, "_preview.png"))
    print("saved _preview.png")


if __name__ == "__main__":
    main()