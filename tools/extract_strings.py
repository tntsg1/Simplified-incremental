"""Collect every translatable string into locales/_source.json (Chinese key -> English text).

Sources: locales/en.json (the catalogue the engine translates), inline bilingual pairs written as
words("中文", "English") in scripts, and the achievement catalogue. Translators work from this file;
each language file locales/<code>.json maps the same Chinese keys to its own text.
"""
import json
import os
import re

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")
source = json.load(open(os.path.join(ROOT, "locales", "en.json"), encoding="utf-8"))
PAIR = re.compile(r'words\(\s*"((?:[^"\\]|\\.)*)"\s*,\s*"((?:[^"\\]|\\.)*)"\s*\)')


def unescape(text):
    return text.replace("\\n", "\n").replace('\\"', '"').replace("\\\\", "\\")


for name in sorted(os.listdir(os.path.join(ROOT, "scripts"))):
    if name.endswith(".gd"):
        code = open(os.path.join(ROOT, "scripts", name), encoding="utf-8").read()
        for zh, en in PAIR.findall(code):
            source.setdefault(unescape(zh), unescape(en))
for item in json.load(open(os.path.join(ROOT, "assets", "achievements", "catalog.json"), encoding="utf-8")):
    source.setdefault(item["name_zh"], item["name_en"])
    source.setdefault(item["description_zh"], item["description_en"])
# Conditional pairs the pattern above cannot read (title_screen.gd chooses between two of each).
source.setdefault("战役已保存 · 本机进度", "Campaign saved · On this computer")
source.setdefault("准备开始你的第一道防线。", "Your first line of defense awaits.")
# Keep earlier strings at their old positions: locales/_tx/<code>.tsv files are numbered by them.
path = os.path.join(ROOT, "locales", "_source.json")
previous = json.load(open(path, encoding="utf-8")) if os.path.exists(path) else {}
ordered = {key: source[key] for key in previous if key in source}
ordered.update({key: text for key, text in source.items() if key not in ordered})
dropped = [key for key in previous if key not in source]
if dropped:
    print("DROPPED", len(dropped), "- renumber the .tsv files before building")
source = ordered
json.dump(source, open(os.path.join(ROOT, "locales", "_source.json"), "w", encoding="utf-8"), ensure_ascii=False, indent=1)
print("SOURCE_STRINGS", len(source))
