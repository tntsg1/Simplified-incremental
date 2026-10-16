"""Capture Steam trading-card art: one fresh Godot process per shot (tests/steam_cards_capture.gd).

Never touches the OS pointer; the window sits off-screen. Retries a shot once if the process dies.
Usage: python tools/steam_cards.py [out_dir] [stages e.g. 0,3,7]
"""
import os
import subprocess
import sys

GODOT = "E:/godot/godot47/Godot_v4.7-stable_win64_console.exe"
ROOT = os.path.join(os.path.dirname(__file__), "..")
out = sys.argv[1] if len(sys.argv) > 1 and sys.argv[1] else os.path.abspath(os.path.join(ROOT, "build", "steam_cards"))
stages = [int(x) for x in sys.argv[2].split(",")] if len(sys.argv) > 2 else list(range(10))
os.makedirs(out, exist_ok=True)
for st in stages:
    for which in ("scene", "card"):
        for attempt in range(2):
            run = subprocess.run([GODOT, "--path", ROOT, "--resolution", "1920x1080", "--position", "5000,5000",
                                  "--script", "res://tests/steam_cards_capture.gd", "--", out, str(st), which],
                                 capture_output=True, text=True, encoding="utf-8", errors="replace", timeout=120)
            if "CARD_SHOT" in run.stdout:
                print("OK", which, st)
                break
            log = os.path.join(out, "fail_%s_%d_%d.log" % (which, st, attempt))
            open(log, "w", encoding="utf-8").write(run.stdout + "\n----- stderr -----\n" + run.stderr)
            print("RETRY" if attempt == 0 else "FAILED", which, st, "exit", run.returncode, "log", log)
