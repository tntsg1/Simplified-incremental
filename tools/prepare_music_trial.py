"""Prepare the user-selected music for a local, reversible game trial.

Original downloads are read only. Loop joins use a one-second crossfade;
musical phrasing still needs human listening approval.
"""
from pathlib import Path
import hashlib
import json
import subprocess
import re

ROOT = Path(__file__).resolve().parents[1]
SOURCE = Path("C:/Users/tntsg/Downloads")
DEST = ROOT / "assets/audio/music"
WORK = ROOT / "build/music-trial"
TRACKS = [
    ("orbital", "Orbital Defense Ostinato.mp3", 12.0, 198.0, True),
    ("dockside", "Dockside Star Map.mp3", 8.0, 376.0, True),
    ("glass", "Glass Tide.mp3", 0.0, 147.0, True),
    ("boss_tactical", "Tactical Interference.mp3", 20.0, 101.0, True),
    ("boss_fury", "Tactical Interference (1).mp3", 140.0, 48.0, True),
    ("scale_jump", "Expanding Scale.mp3", 0.0, 9.8, False),
]

def run(args):
    result = subprocess.run(["ffmpeg", "-hide_banner", "-nostats", "-y", *args],
                            capture_output=True, text=True)
    if result.returncode:
        raise RuntimeError(result.stderr)
    return result.stderr

def main():
    DEST.mkdir(parents=True, exist_ok=True)
    WORK.mkdir(parents=True, exist_ok=True)
    manifest = []
    for key, name, start, duration, loop in TRACKS:
        source = SOURCE / name
        trimmed = WORK / (key + ".wav")
        inputs = ["-ss", str(start), "-t", str(duration), "-i", str(source)]
        filters = "highpass=f=28"
        if loop:
            # Body [1,end-1] followed by a tail/head join; wrap resumes at second 1.
            filters = "[0:a:0]" + filters + (",asplit=3[body][tail][head];"
                        f"[body]atrim=start=1:end={duration-1},asetpts=PTS-STARTPTS[b];"
                        f"[tail]atrim=start={duration-1}:end={duration},asetpts=PTS-STARTPTS[t];"
                        "[head]atrim=start=0:end=1,asetpts=PTS-STARTPTS[h];"
                        "[t][h]acrossfade=d=1:c1=tri:c2=tri[j];[b][j]concat=n=2:v=0:a=1[out]")
            run([*inputs, "-filter_complex", filters, "-map", "[out]", "-ar", "48000", "-ac", "2", str(trimmed)])
        else:
            run([*inputs, "-map", "0:a:0", "-af", filters + ",afade=t=in:d=0.03,afade=t=out:st=9.35:d=0.45", "-ar", "48000", "-ac", "2", str(trimmed)])
        scan = run(["-i", str(trimmed), "-af", "loudnorm=I=-16:TP=-3:LRA=11:print_format=json", "-f", "null", "-"])
        measured = json.loads(re.findall(r"\{[^{}]*\}", scan)[-1])
        norm = ("loudnorm=I=-16:TP=-3:LRA=11:linear=true:"
                f"measured_I={measured['input_i']}:measured_TP={measured['input_tp']}:"
                f"measured_LRA={measured['input_lra']}:measured_thresh={measured['input_thresh']}:"
                f"offset={measured['target_offset']}")
        dest = DEST / (key + ".ogg")
        run(["-i", str(trimmed), "-af", norm, "-ar", "48000", "-ac", "2", "-c:a", "libvorbis", "-q:a", "5", str(dest)])
        manifest.append(dict(key=key, source=name, source_sha256=hashlib.sha256(source.read_bytes()).hexdigest(),
                             start=start, source_duration=duration, loop=loop,
                             prepared_duration=duration-1 if loop else duration,
                             file="res://assets/audio/music/" + key + ".ogg"))
        print("PREPARED", key, dest.stat().st_size, flush=True)
    (DEST / "trial_manifest.json").write_text(json.dumps(manifest, indent=2), encoding="utf-8")

if __name__ == "__main__":
    main()
