"""Remote index and selective extraction for the Sonniss GDC bundles.

The bundles are huge zip parts, but the server honours HTTP Range, so we read
only each zip's central directory (index) and later pull just the members we
need. Usage:
  python tools/sonniss_fetch.py index            -> G:/audio_library/sonniss/index.json
  python tools/sonniss_fetch.py fetch picks.txt  -> extracts the listed members
picks.txt holds one "part_url<TAB>member_name" per line.
"""
import json
import os
import re
import struct
import sys
import zlib
import urllib.request
from concurrent.futures import ThreadPoolExecutor

ROOT = "G:/audio_library/sonniss"
HEADERS = {
    "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/126 Safari/537.36",
    "Referer": "https://sonniss.com/gameaudiogdc/",
}
PARTS_FILE = os.path.join(os.path.dirname(__file__), "sonniss_parts.txt")


def get_range(url, start, end):
    req = urllib.request.Request(url, headers=dict(HEADERS, Range=f"bytes={start}-{end}"))
    for attempt in range(5):
        try:
            with urllib.request.urlopen(req, timeout=120) as r:
                total = int(r.headers["Content-Range"].split("/")[1])
                return r.read(), total
        except Exception as error:
            last = error
    raise last


def read_index(url):
    tail, total = get_range(url, 0, 0)
    tail_len = min(total, 1 << 20)
    tail, _ = get_range(url, total - tail_len, total - 1)
    at = tail.rfind(b"PK\x05\x06")
    if at < 0:
        raise ValueError("no end of central directory")
    count, cd_size, cd_offset = struct.unpack("<HII", tail[at + 10:at + 20])
    loc = tail.rfind(b"PK\x06\x07")
    if loc >= 0:
        # ZIP64: real values live in the zip64 end record.
        z64_offset = struct.unpack("<Q", tail[loc + 8:loc + 16])[0]
        rec, _ = get_range(url, z64_offset, z64_offset + 55)
        count, cd_size, cd_offset = struct.unpack("<QQQ", rec[32:56])
    cd, _ = get_range(url, cd_offset, cd_offset + cd_size - 1)
    entries = []
    p = 0
    while p + 46 <= len(cd) and cd[p:p + 4] == b"PK\x01\x02":
        method = struct.unpack("<H", cd[p + 10:p + 12])[0]
        csize, usize = struct.unpack("<II", cd[p + 20:p + 28])
        nlen, elen, clen = struct.unpack("<HHH", cd[p + 28:p + 34])
        offset = struct.unpack("<I", cd[p + 42:p + 46])[0]
        name = cd[p + 46:p + 46 + nlen].decode("utf-8", "replace")
        extra = cd[p + 46 + nlen:p + 46 + nlen + elen]
        # Pick up 64-bit sizes/offset from the zip64 extra field when present.
        e = 0
        while e + 4 <= len(extra):
            tag, size = struct.unpack("<HH", extra[e:e + 4])
            if tag == 1:
                vals = extra[e + 4:e + 4 + size]
                k = 0
                if usize == 0xFFFFFFFF:
                    usize = struct.unpack("<Q", vals[k:k + 8])[0]; k += 8
                if csize == 0xFFFFFFFF:
                    csize = struct.unpack("<Q", vals[k:k + 8])[0]; k += 8
                if offset == 0xFFFFFFFF:
                    offset = struct.unpack("<Q", vals[k:k + 8])[0]; k += 8
            e += 4 + size
        if not name.endswith("/"):
            entries.append({"name": name, "method": method, "csize": csize, "usize": usize, "offset": offset})
        p += 46 + nlen + elen + clen
    return {"url": url, "total": total, "entries": entries}


def index():
    os.makedirs(ROOT, exist_ok=True)
    urls = [u.strip() for u in open(PARTS_FILE, encoding="utf-8") if u.strip()]
    with ThreadPoolExecutor(8) as pool:
        results = list(pool.map(safe_index, urls))
    json.dump(results, open(os.path.join(ROOT, "index.json"), "w", encoding="utf-8"), ensure_ascii=False)
    files = sum(len(r.get("entries", [])) for r in results)
    print(f"INDEXED parts={len(results)} failed={sum(1 for r in results if 'error' in r)} files={files}")


def safe_index(url):
    try:
        return read_index(url)
    except Exception as error:
        return {"url": url, "error": str(error), "entries": []}


def local_path(name):
    # Windows forbids some characters that appear in a few member names.
    clean = "/".join(re.sub(r'[<>:"|?*]', "_", part).rstrip(" .") for part in name.split("/"))
    return os.path.join(ROOT, "files", clean)


def extract(url, entry):
    try:
        return extract_one(url, entry)
    except Exception as error:
        print("SKIP", entry["name"], error)
        return 0


def extract_one(url, entry):
    out = local_path(entry["name"])
    if os.path.exists(out) and os.path.getsize(out) == entry["usize"]:
        return 0
    head, _ = get_range(url, entry["offset"], entry["offset"] + 29)
    nlen, elen = struct.unpack("<HH", head[26:30])
    start = entry["offset"] + 30 + nlen + elen
    data, _ = get_range(url, start, start + entry["csize"] - 1)
    if entry["method"] == 8:
        data = zlib.decompress(data, -15)
    elif entry["method"] != 0:
        raise ValueError(f"unsupported method {entry['method']}")
    os.makedirs(os.path.dirname(out), exist_ok=True)
    with open(out, "wb") as f:
        f.write(data)
    return entry["csize"]


def fetch(picks_path):
    idx = {r["url"]: {e["name"]: e for e in r["entries"]} for r in json.load(open(os.path.join(ROOT, "index.json"), encoding="utf-8"))}
    jobs = []
    for line in open(picks_path, encoding="utf-8"):
        if "\t" in line:
            url, name = line.rstrip("\n").split("\t", 1)
            jobs.append((url, idx[url][name]))
    with ThreadPoolExecutor(8) as pool:
        got = sum(pool.map(lambda j: extract(*j), jobs))
    print(f"FETCHED files={len(jobs)} bytes={got}")


if __name__ == "__main__":
    {"index": lambda: index(), "fetch": lambda: fetch(sys.argv[2])}[sys.argv[1]]()
