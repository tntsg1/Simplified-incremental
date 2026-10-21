"""Record store-page clips with Godot Movie Maker (tests/store_clip.gd) and encode MP4s.

Never touches the OS pointer (window off-screen, in-game pointer hidden). Retries once on a crash.
Usage: python tools/store_clips.py [--lang <code>] [scenario ...]
  ->  build/store_clips/<name>.mp4, or build/store_clips/<code>/skyguard_<name>.mp4 (store-ready) with --lang
"""
import os
import re
import subprocess
import sys

GODOT = "E:/godot/godot47/Godot_v4.7-stable_win64_console.exe"
ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
OUT = os.path.join(ROOT, "build", "store_clips")
CLIPS = {  # name: (scenario, seconds)
    "city": ("city", 8), "bodies": ("bodies", 8), "weapons": ("weapons", 8), "boss": ("boss", 9),
    "jump": ("jump", 10), "droplet": ("ult:droplet", 7), "fourier": ("ult:fourier", 9), "mandelbrot": ("ult:mandelbrot", 8),
}
args = sys.argv[1:]
lang = ""
size = "1280x720"
if args[:1] == ["--size"]:
    # Trailer footage renders at 1920x1080; store-page clips stay at 1280x720.
    size, args = args[1], args[2:]
if args[:1] == ["--lang"]:
    lang, args = args[1], args[2:]
    OUT = os.path.join(OUT, lang)
os.makedirs(OUT, exist_ok=True)
for name in (args or CLIPS):
    scenario, seconds = CLIPS[name]
    avi = os.path.join(OUT, name + ".avi")
    for attempt in range(2):
        run = subprocess.run([GODOT, "--path", ROOT, "--write-movie", avi, "--fixed-fps", "30", "--resolution", size,
                              "--position", "5000,5000", "--script", "res://tests/store_clip.gd", "--", scenario, str(seconds)] + ([lang] if lang else []),
                             capture_output=True, text=True, encoding="utf-8", errors="replace", timeout=600)
        m = re.search(r"CLIP_START (\d+)", run.stdout)
        if m and "CLIP_END" in run.stdout:
            start = int(m.group(1)) / 30.0
            mp4 = os.path.join(OUT, ("skyguard_" if lang else "") + name + ".mp4")
            subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-ss", "%.3f" % start, "-i", avi, "-t", str(seconds),
                            "-vf", "scale=%s:flags=lanczos" % size.replace("x", ":"), "-c:v", "libx264", "-pix_fmt", "yuv420p", "-crf", "25" if lang and size == "1280x720" else "19",
                            "-preset", "slow", "-an", "-movflags", "+faststart", mp4], check=True)
            os.remove(avi)
            print("CLIP", name, "%.0f KB" % (os.path.getsize(mp4) / 1024), run.stdout.strip().splitlines()[-1][:120])
            break
        print("RETRY" if attempt == 0 else "FAILED", name)
