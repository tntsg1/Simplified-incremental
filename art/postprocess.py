#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""zengliang · 后期处理：Blender 渲染 → 游戏成品贴图。

流程: art/renders/<name>.png (768, RGBA)
      → 辉光(加法泛光) → 软阴影垫 → 缩到 512 → assets/<name>.png
      → 同时输出 art/renders/_check.png 自检拼图

用法: python3 art/postprocess.py
"""
import os

import numpy as np
from PIL import Image, ImageDraw, ImageFilter

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC = os.path.join(ROOT, "art", "renders")
OUT = os.path.join(ROOT, "assets")

NAMES = ["miner", "solar", "fusion", "lab", "commerce", "colony"]


def bloom(im, radius=16, threshold=165, gain=0.9):
    arr = np.asarray(im).astype(np.float32)
    lum = arr[..., :3].max(axis=2)
    mask = np.clip((lum - threshold) / (255.0 - threshold), 0, 1) * (arr[..., 3] / 255.0)
    glow = arr[..., :3] * mask[..., None] * gain
    gimg = Image.fromarray(
        np.dstack([glow, mask * 255]).astype(np.uint8), "RGBA"
    ).filter(ImageFilter.GaussianBlur(radius))
    out = im.copy()
    out.alpha_composite(gimg)
    out.alpha_composite(gimg)
    return out


def ground(im, alpha=90):
    """根据不透明区域的底部生成软阴影，垫在建筑后面。"""
    bbox = im.getbbox()
    if not bbox:
        return im
    cx = (bbox[0] + bbox[2]) / 2.0
    by = bbox[3]
    rx = (bbox[2] - bbox[0]) * 0.46
    ry = rx * 0.20
    lay = Image.new("RGBA", im.size, (0, 0, 0, 0))
    d = ImageDraw.Draw(lay)
    d.ellipse([cx - rx, by - ry, cx + rx, by + ry * 1.1], fill=(0, 0, 0, alpha))
    lay = lay.filter(ImageFilter.GaussianBlur(8))
    out = Image.new("RGBA", im.size, (0, 0, 0, 0))
    out.alpha_composite(lay)
    out.alpha_composite(im)
    return out


def main():
    os.makedirs(OUT, exist_ok=True)
    results = []
    for name in NAMES:
        p = os.path.join(SRC, name + ".png")
        if not os.path.exists(p):
            print("MISSING", p)
            continue
        im = Image.open(p).convert("RGBA")
        im = bloom(im)
        im = ground(im)
        im = im.resize((512, 512), Image.LANCZOS)
        im.save(os.path.join(OUT, name + ".png"))
        bbox = im.getbbox()
        results.append((name, im, bbox))
        print("OUT", name, "bbox=", bbox)
    # 自检拼图
    if results:
        cell = 300
        cols = 3
        rows = (len(results) + cols - 1) // cols
        bg = Image.new("RGBA", (cols * cell, rows * cell), (24, 28, 38, 255))
        for i, (name, im, _) in enumerate(results):
            th = im.resize((cell - 20, cell - 20), Image.LANCZOS)
            x = (i % cols) * cell + 10
            y = (i // cols) * cell + 10
            bg.alpha_composite(th, (x, y))
        bg.convert("RGB").save(os.path.join(SRC, "_check.png"))
        print("CHECK ->", os.path.join(SRC, "_check.png"))


if __name__ == "__main__":
    main()