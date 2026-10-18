"""Turn locales/_tx/<code>.tsv (index<TAB>text, "\n" for line breaks) into locales/<code>.json.

Indices follow locales/_source.json order (the same numbering as locales/_tx/source.tsv).
Every entry is checked against the English text: format placeholders, $tokens and line breaks
must survive translation, or the build stops and names the entry.
"""
import json
import os
import re
import sys

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")
source = json.load(open(os.path.join(ROOT, "locales", "_source.json"), encoding="utf-8"))
keys = list(source)
TOKENS = re.compile(r"%[0-9.]*[dsf%]|\$[dlc]")


def tokens(text):
    return sorted(TOKENS.findall(text))


codes = sys.argv[1:] or [n[:-4] for n in os.listdir(os.path.join(ROOT, "locales", "_tx")) if n.endswith(".tsv") and n != "source.tsv"]
failed = False
for code in codes:
    table = {}
    for line in open(os.path.join(ROOT, "locales", "_tx", code + ".tsv"), encoding="utf-8"):
        line = line.rstrip("\r\n")
        if not line:
            continue
        index, text = line.split("\t", 1)
        table[int(index)] = text.replace("\\n", "\n")
    messages = {}
    for i, key in enumerate(keys):
        if i not in table:
            print(code, "MISSING", i, key.replace("\n", "\\n"))
            failed = True
            continue
        text = table[i]
        if tokens(text) != tokens(source[key]) or text.count("\n") != source[key].count("\n"):
            print(code, "MISMATCH", i, repr(source[key]), "->", repr(text))
            failed = True
        messages[key] = text
    extra = set(table) - set(range(len(keys)))
    if extra:
        print(code, "EXTRA", sorted(extra))
        failed = True
    json.dump(messages, open(os.path.join(ROOT, "locales", code + ".json"), "w", encoding="utf-8"), ensure_ascii=False, indent=1)
    print("LOCALE", code, len(messages))
sys.exit(1 if failed else 0)
