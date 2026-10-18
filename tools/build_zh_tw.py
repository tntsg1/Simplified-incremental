"""Traditional Chinese (Taiwan) catalogue: OpenCC s2twp over locales/_source.json, then term fixes.

Run with the G: venv that has opencc: G:/audio_library/venv/Scripts/python.exe tools/build_zh_tw.py
"""
import json
import os

import opencc

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")
FIXES = [("全屏", "全螢幕"), ("分形", "碎形"), ("導彈", "飛彈"), ("本地備份", "本機備份"), ("奧爾特", "歐特"), ("炮臺", "砲臺")]
convert = opencc.OpenCC("s2twp")
source = json.load(open(os.path.join(ROOT, "locales", "_source.json"), encoding="utf-8"))
messages = {}
for key in source:
    text = convert.convert(key)
    for old, new in FIXES:
        text = text.replace(old, new)
    messages[key] = text
json.dump(messages, open(os.path.join(ROOT, "locales", "zh_TW.json"), "w", encoding="utf-8"), ensure_ascii=False, indent=1)
print("LOCALE zh_TW", len(messages))
