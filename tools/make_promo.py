"""Cut the promo from Movie Maker clips in build/promo (see tests/promo_record.gd)."""
import subprocess

FONT = "C\\:/Windows/Fonts/msyh.ttc"
BOLD = "C\\:/Windows/Fonts/msyhbd.ttc"
FADE = 0.5
CLIPS = [  # (file, seconds, start, caption)
    ("city", 6, 0.0, "从第一枚导弹开始"),
    ("solar", 8, 0.0, "把行星改造成武器"),
    ("galaxy", 6, 0.0, "满屏弹幕  ·  数字膨胀"),
    ("cluster", 6, 0.0, "击碎巨型威胁  ·  尺度跃迁"),
    ("cosmos", 6, 0.0, "一直打到宇宙尽头"),
]
INTRO, OUTRO = 3.2, 4.0


def text(t, size, y, font=FONT, color="0xEDEDED", start=0.0, length=None):
    fade_in = f"min(1,(t-{start})/0.5)"
    alpha = fade_in if length is None else f"min({fade_in},({start + length}-t)/0.5)"
    return (f"drawtext=fontfile='{font}':text='{t}':fontsize={size}:fontcolor={color}:"
            f"x=(w-text_w)/2:y={y}:alpha='max(0,{alpha})':enable='gte(t,{start})'")


inputs, chains, labels = [], [], []
inputs += ["-f", "lavfi", "-t", str(INTRO), "-i", "color=c=0x141414:s=1920x1080:r=60"]
chains.append("[0:v]" + ",".join([
    text("天穹防线", 150, "(h-text_h)/2-60", BOLD, start=0.2, length=INTRO - 0.4),
    text("SKYGUARD  ·  从城市到宇宙的极简增量防御", 34, "(h)/2+70", FONT, "0xB4B4B4", 0.6, INTRO - 0.8),
]) + ",format=yuv420p,setsar=1[v0]")
labels.append(("v0", INTRO))
for i, (name, secs, start, caption) in enumerate(CLIPS, start=1):
    inputs += ["-ss", str(start), "-t", str(secs), "-i", f"build/promo/{name}.avi"]
    chains.append(f"[{i}:v]scale=1920:1080:flags=lanczos,fps=60,setsar=1,format=yuv420p,"
                  "drawbox=x=0:y=ih-190:w=iw:h=190:color=0x141414@0.55:t=fill,"
                  + text(caption, 54, "h-140", BOLD, start=0.3, length=secs - 0.6) + f"[v{i}]")
    labels.append((f"v{i}", secs))
n = len(CLIPS) + 1
inputs += ["-f", "lavfi", "-t", str(OUTRO), "-i", "color=c=0x141414:s=1920x1080:r=60"]
chains.append(f"[{n}:v]" + ",".join([
    text("守住天穹", 110, "(h-text_h)/2-80", BOLD, start=0.2),
    text("github.com/tntsg1/Simplified-incremental", 36, "(h)/2+60", FONT, "0xFFC94D", 0.7),
]) + ",format=yuv420p,setsar=1[vout]")
labels.append(("vout", OUTRO))

# Cross-fade every segment into the next.
current, total = labels[0][0], labels[0][1]
for k, (label, secs) in enumerate(labels[1:], start=1):
    out = f"x{k}"
    chains.append(f"[{current}][{label}]xfade=transition=fade:duration={FADE}:offset={total - FADE:.3f}[{out}]")
    current, total = out, total + secs - FADE
music = n + 1
inputs += ["-i", "assets/audio/music_5.ogg"]
chains.append(f"[{music}:a]aloop=loop=-1:size=2e9,atrim=0:{total:.3f},afade=t=in:d=1.5,"
              f"afade=t=out:st={total - 2:.3f}:d=2,volume=1.6[aout]")
cmd = ["ffmpeg", "-y", "-loglevel", "error", *inputs, "-filter_complex", ";".join(chains),
       "-map", f"[{current}]", "-map", "[aout]", "-c:v", "libx264", "-preset", "slow", "-crf", "18",
       "-pix_fmt", "yuv420p", "-r", "60", "-c:a", "aac", "-b:a", "192k", "-movflags", "+faststart",
       "build/promo/skyguard_promo.mp4"]
subprocess.run(cmd, check=True)
print(f"promo written: {total:.1f}s")
