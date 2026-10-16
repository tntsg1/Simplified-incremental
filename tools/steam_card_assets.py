"""Steam trading-card set for SKYGUARD: cards (10 bosses), emoticons (10 ultimates),
profile backgrounds (10 scales) and the 5+1 badges, in Steam's sizes.

Card and background art comes from tools/steam_cards.py (live game renders). Emoticons and
badges are drawn here in the game's language: dark plate, white geometry, one amber accent.
Usage: python tools/steam_card_assets.py   ->  steam-release/SKYGUARD-5427620/trading-cards/
"""
import io
import json
import math
import os

from PIL import Image, ImageDraw, ImageFilter

HERE = os.path.dirname(os.path.abspath(__file__))
SRC = os.path.join(HERE, "..", "build", "steam_cards")
OUT = "E:/godot/steam-release/SKYGUARD-5427620/trading-cards"
INK = (237, 237, 237, 255)
AMBER = (255, 201, 77, 255)
PLATE = (20, 20, 20, 255)
EDGE = (60, 60, 60, 255)

CHAPTERS = [  # (scale zh, scale en, boss zh, boss en)
    ("城市", "City", "毁城小行星", "CHIRON"), ("地球", "Earth", "流浪天体", "NOMAD"),
    ("内太阳系", "Inner Solar System", "被劫持的矮行星", "CERES"), ("外太阳系", "Outer Solar System", "外星攻城母舰", "LEVIATHAN"),
    ("奥尔特云", "Oort Cloud", "星际来客", "'OUMUAMUA"), ("恒星邻域", "Stellar Neighbourhood", "失控恒星", "VESPER"),
    ("银河", "Milky Way", "磁星", "MAGNETAR"), ("超星系团", "Supercluster", "外星巨构战舰", "CATHEDRAL"),
    ("可观测宇宙", "Observable Universe", "宇宙灾变核心", "THE SILENCE"), ("宇宙膜", "The Brane", "对撞之膜", "THE OTHER BRANE"),
]
ULTS = [  # (code, zh, en)
    ("nuke", "核弹", "Nuke"), ("photoid", "光粒打击", "Photoid"), ("droplet", "水滴", "Droplet"), ("foil", "一向箔", "Foil"),
    ("fourier", "傅里叶分解", "Fourier"), ("prime", "质数打击", "Prime"), ("mandelbrot", "曼德博分形", "Mandelbrot"),
    ("lightspeed", "降低光速", "Lightspeed"), ("pi", "改写 π", "Rewrite Pi"), ("strings", "维度震荡", "Strings"),
]


def jpeg_under(img, limit, start=92):
    q = start
    while q > 40:
        buf = io.BytesIO()
        img.save(buf, "JPEG", quality=q, optimize=True, progressive=True)
        if buf.tell() <= limit:
            return buf.getvalue(), q
        q -= 4
    return buf.getvalue(), q


def cards():
    os.makedirs(os.path.join(OUT, "cards"), exist_ok=True)
    report = []
    for i in range(10):
        im = Image.open(os.path.join(SRC, "card_%d.png" % i)).convert("RGB")
        data, q = jpeg_under(im, 345_000)
        open(os.path.join(OUT, "cards", "card_%02d_large.jpg" % (i + 1)), "wb").write(data)
        # Small card: a tight frame round the centred boss, Steam's 206x184.
        w = 760
        h = round(w * 184 / 206)
        box = (960 - w // 2, 520 - h // 2, 960 + w // 2, 520 + h // 2)
        small = im.crop(box).resize((206, 184), Image.LANCZOS).filter(ImageFilter.UnsharpMask(1.2, 60, 2))
        small.save(os.path.join(OUT, "cards", "card_%02d_small.png" % (i + 1)), optimize=True)
        report.append((i, len(data), q))
    return report


def backgrounds():
    os.makedirs(os.path.join(OUT, "backgrounds"), exist_ok=True)
    for i in range(10):
        im = Image.open(os.path.join(SRC, "scene_%d.png" % i)).convert("RGB")
        im.save(os.path.join(OUT, "backgrounds", "background_%02d.jpg" % (i + 1)), "JPEG", quality=90, optimize=True, progressive=True)


# ---------------------------------------------------------------- vector helpers at 8x
SS = 8


def canvas(size):
    return Image.new("RGBA", (size * SS, size * SS), (0, 0, 0, 0))


def P(c, x, y, r):
    """Unit coords (-1..1) to pixels on a square canvas of side c."""
    return (c / 2 + x * r, c / 2 + y * r)


def plate(d, c, ring=AMBER):
    r = c * .48
    d.ellipse([c / 2 - r, c / 2 - r, c / 2 + r, c / 2 + r], fill=PLATE, outline=ring, width=max(2, int(c * .035)))


def poly(d, pts, c, r, **kw):
    d.polygon([P(c, x, y, r) for x, y in pts], **kw)


def line(d, pts, c, r, color, w):
    d.line([P(c, x, y, r) for x, y in pts], fill=color, width=int(w), joint="curve")


def circle(d, c, x, y, rad, r, **kw):
    cx, cy = P(c, x, y, r)
    d.ellipse([cx - rad * r, cy - rad * r, cx + rad * r, cy + rad * r], **kw)


def emoticon(code, size):
    im = canvas(size)
    d = ImageDraw.Draw(im)
    c = size * SS
    plate(d, c)
    r = c * .34
    lw = c * .07
    if code == "nuke":
        for k in range(3):
            a0 = math.radians(-90 + k * 120 - 30)
            pts = [(math.cos(a0 + t / 10 * math.radians(60)) * .95, math.sin(a0 + t / 10 * math.radians(60)) * .95) for t in range(11)]
            pts += [(math.cos(a0 + t / 10 * math.radians(60)) * .32, math.sin(a0 + t / 10 * math.radians(60)) * .32) for t in range(10, -1, -1)]
            poly(d, pts, c, r, fill=AMBER)
        circle(d, c, 0, 0, .2, r, fill=INK)
    elif code == "photoid":
        poly(d, [(-.95, .95), (.55, -.7), (.75, -.45)], c, r, fill=(237, 237, 237, 150))
        poly(d, [(-.55, .55), (.6, -.62), (.68, -.52)], c, r, fill=INK)
        circle(d, c, .62, -.58, .32, r, fill=AMBER)
        circle(d, c, .62, -.58, .14, r, fill=INK)
    elif code == "droplet":
        # The Three-Body droplet: a round body drawn out to a needle tip, mirror-white.
        pts = []
        body_r, tip = .5, 1.0
        cxb = -.3
        half = math.acos(body_r / (tip - cxb))
        for t in range(41):
            a = half + (2 * math.pi - 2 * half) * t / 40
            pts.append((cxb + body_r * math.cos(a), body_r * math.sin(a)))
        pts.append((tip, 0.0))
        ang = math.radians(-40)
        pts = [(x * math.cos(ang) - y * math.sin(ang), x * math.sin(ang) + y * math.cos(ang)) for x, y in pts]
        poly(d, pts, c, r, fill=INK)
        circle(d, c, -.42, -.05, .17, r, fill=(255, 255, 255, 255))
        line(d, [(-.55, .3), (-.1, .38)], c, r, AMBER, lw * .55)
    elif code == "foil":
        sheet = [(-.95, .35), (.15, -.85), (.95, -.35), (-.15, .85)]
        poly(d, sheet, c, r, fill=(237, 237, 237, 60), outline=INK, width=int(lw * .7))
        line(d, [(-.4, -.25), (.4, .25)], c, r, AMBER, lw)
        poly(d, [(.15, -.85), (.95, -.35), (.55, -.1)], c, r, fill=AMBER)
    elif code == "fourier":
        # One epicycle riding a circle, drawing an amber wave.
        circle(d, c, -.3, -.2, .55, r, outline=INK, width=int(lw * .75))
        circle(d, c, .25, -.2, .2, r, fill=AMBER)
        wave = [(-.95 + t * .095, .6 + .25 * math.sin(t * .62)) for t in range(21)]
        line(d, wave, c, r, AMBER, lw * .85)
    elif code == "prime":
        primes = {(1, 0), (2, 0), (0, 1), (2, 2), (1, 2)}
        for gx in range(3):
            for gy in range(3):
                hot = (gx, gy) in primes
                circle(d, c, (gx - 1) * .62, (gy - 1) * .62, .24 if hot else .13, r, fill=AMBER if hot else INK)
    elif code == "mandelbrot":
        pts = []
        for t in range(73):
            th = t / 72 * 2 * math.pi
            x = .5 * math.cos(th) - .25 * math.cos(2 * th)
            y = .5 * math.sin(th) - .25 * math.sin(2 * th)
            pts.append((x * 1.25 + .25, y * 1.25))
        poly(d, pts, c, r, fill=INK, outline=AMBER, width=int(lw * .5))
        circle(d, c, -1.0 * 1.25 + .25 + .02, 0, .26 * 1.25, r, fill=INK, outline=AMBER, width=int(lw * .5))
        circle(d, c, -.38 * 1.25 + .25 - .02, -.62, .1, r, fill=INK)
        circle(d, c, -.38 * 1.25 + .25 - .02, .62, .1, r, fill=INK)
    elif code == "lightspeed":
        for k, col in enumerate([(111, 184, 255, 255), (237, 237, 237, 255), (255, 107, 85, 255)]):
            rad = .35 + k * .3
            circle(d, c, -.25 + k * .17, 0, rad, r, outline=col, width=int(lw * .55))
        circle(d, c, -.45, 0, .14, r, fill=AMBER)
    elif code == "pi":
        poly(d, [(-.9, -.72), (.9, -.72), (.9, -.42), (-.9, -.42)], c, r, fill=INK)
        poly(d, [(-.45, -.45), (-.15, -.45), (-.28, .45), (-.55, .85), (-.75, .7), (-.52, .4)], c, r, fill=INK)
        poly(d, [(.2, -.45), (.48, -.45), (.48, .55), (.7, .65), (.62, .88), (.3, .78), (.2, .55)], c, r, fill=AMBER)
    elif code == "strings":
        # Two ringing strings: a five-lobed white loop round a three-lobed amber one.
        for n, rad, amp, col in [(5, .78, .14, INK), (3, .38, .12, AMBER)]:
            pts = [(math.cos(t / 120 * 2 * math.pi) * (rad + amp * math.sin(n * t / 120 * 2 * math.pi)),
                    math.sin(t / 120 * 2 * math.pi) * (rad + amp * math.sin(n * t / 120 * 2 * math.pi))) for t in range(121)]
            line(d, pts, c, r, col, lw * .75)
    return im.resize((size, size), Image.LANCZOS)


def emoticons():
    os.makedirs(os.path.join(OUT, "emoticons"), exist_ok=True)
    for code, _, _ in ULTS:
        for size in (54, 18):
            emoticon(code, size).save(os.path.join(OUT, "emoticons", "skyguard_%s_%d.png" % (code, size)), optimize=True)


def hexagon(cx, cy, rad, rot=-90):
    return [(cx + rad * math.cos(math.radians(rot + k * 60)), cy + rad * math.sin(math.radians(rot + k * 60))) for k in range(6)]


def badge(level, foil=False):
    size = 80
    im = canvas(size)
    d = ImageDraw.Draw(im)
    c = size * SS
    ring = AMBER if level >= 5 or foil else (110, 110, 110, 255)
    if foil:
        # Foil: a gold plate with a soft sheen across it.
        r0 = c * .48
        for k in range(40):
            t = k / 39
            col = tuple(int(a + (b - a) * t) for a, b in zip((120, 86, 20), (255, 214, 120))) + (255,)
            d.ellipse([c / 2 - r0 * (1 - t * .5), c / 2 - r0 * (1 - t * .5), c / 2 + r0 * (1 - t * .5), c / 2 + r0 * (1 - t * .5)], fill=col)
    else:
        plate(d, c, ring)
    cx = cy = c / 2
    core_col = PLATE if foil else INK
    accent = (255, 255, 255, 255) if foil else AMBER
    d.polygon(hexagon(cx, cy, c * .2), outline=core_col, width=int(c * .03))
    if level >= 2 or foil:
        d.polygon(hexagon(cx, cy, c * .1), fill=accent)
    if level >= 3 or foil:
        rr = c * .31
        d.ellipse([cx - rr, cy - rr, cx + rr, cy + rr], outline=core_col, width=int(c * .018))
    if level >= 4 or foil:
        for k in range(6):
            a = math.radians(-90 + k * 60)
            x, y = cx + math.cos(a) * c * .31, cy + math.sin(a) * c * .31
            d.ellipse([x - c * .03, y - c * .03, x + c * .03, y + c * .03], fill=accent)
    if level >= 5 or foil:
        for k in range(12):
            a = math.radians(-75 + k * 30)
            d.line([(cx + math.cos(a) * c * .37, cy + math.sin(a) * c * .37), (cx + math.cos(a) * c * .43, cy + math.sin(a) * c * .43)],
                   fill=accent, width=int(c * .02))
    return im.resize((size, size), Image.LANCZOS)


def badges():
    os.makedirs(os.path.join(OUT, "badges"), exist_ok=True)
    for level in range(1, 6):
        badge(level).save(os.path.join(OUT, "badges", "badge_level_%d.png" % level), optimize=True)
    badge(5, foil=True).save(os.path.join(OUT, "badges", "badge_foil.png"), optimize=True)


def manifest():
    data = {
        "cards": [{"file_large": "cards/card_%02d_large.jpg" % (i + 1), "file_small": "cards/card_%02d_small.png" % (i + 1),
                   "name_zh": ch[2], "name_en": ch[3], "description_zh": "第 %d 章 · %s 的巨型威胁" % (i + 1, ch[0]),
                   "description_en": "Chapter %d · the giant threat of the %s" % (i + 1, ch[1])} for i, ch in enumerate(CHAPTERS)],
        "emoticons": [{"code": ":skyguard_%s:" % code, "file_54": "emoticons/skyguard_%s_54.png" % code,
                       "file_18": "emoticons/skyguard_%s_18.png" % code, "name_zh": zh, "name_en": en} for code, zh, en in ULTS],
        "backgrounds": [{"file": "backgrounds/background_%02d.jpg" % (i + 1), "name_zh": ch[0], "name_en": ch[1]} for i, ch in enumerate(CHAPTERS)],
        "badges": [{"level": lv, "file": "badges/badge_level_%d.png" % lv, "name_zh": n_zh, "name_en": n_en}
                   for lv, n_zh, n_en in [(1, "城市守卫", "City Guard"), (2, "行星哨兵", "Planetary Sentinel"),
                                          (3, "星系守望", "Galactic Watch"), (4, "宇宙防线", "Cosmic Line"), (5, "天穹", "Skyguard")]]
        + [{"level": "foil", "file": "badges/badge_foil.png", "name_zh": "最后的光", "name_en": "The Last Light"}],
    }
    json.dump(data, open(os.path.join(OUT, "trading_cards.json"), "w", encoding="utf-8"), ensure_ascii=False, indent=1)
    return data


if __name__ == "__main__":
    os.makedirs(OUT, exist_ok=True)
    for i, size, q in cards():
        print("CARD", i + 1, "large %d KB (q%d)" % (size // 1024, q))
    backgrounds()
    emoticons()
    badges()
    manifest()
    print("TRADING_CARDS", OUT)
