# 天穹防线 · 十章背景音乐设计（纯器乐版）

**这一份取代 `SUNO_PROMPTS.md` 里的十章部分。** 第 8–10 章原稿用的是无词合唱，Suno 经常自己往上加真词，所以全部改成管风琴和弦乐八度叠加——听感还是"巨大的人声感"，但没有一个人唱歌。

---

## 通用设置（每一条都照做）

1. **Instrumental 开关：打开。** 这是第一道保险。
2. **排除风格**：每条都填下面这行，第 8–10 章再补一句。

   ```
   vocals, lyrics, singing, choir words, spoken word, rap, humming, vocal chops, ad libs, EDM drop, dubstep, trap beat, distorted guitar, happy, upbeat dance, fade out ending
   ```

3. **Weirdness 35%，Style Influence 75%。**
4. 每条的「风格」行已锁 D 调，**不要删那句**。生成后先验主音是不是 D。
5. 每条的「结构」标签最后一行都是 `[Sustain: hold, no fade, no ending]`——Suno 默认给淡出，淡出会让循环接缝掉音。
6. 长度凑到 90–150 秒。多跑几版，挑"中途不换风格、没人声、结尾不淡出"的那版。
7. 十条风格行里都埋了同一句 `a recurring four note motif D F# A C`。**一个字都别改**——同一句话反复喂给模型，是让十章听起来像同一部作品最省力的办法。

## 设计骨架

- **母题**：D–F#–A–C 四音上行（主和弦加大七度），每一章都在，只是编制和速度不同。
- **尺度阶梯**：越往后 BPM 越慢、音域越宽、混响越长、低频越重，但**起音密度往下走**——后期屏幕上全是弹道，音乐再密就糊。
- **中心调**：全书 D。第 1–3 章 D 大调，第 4 章起转 D 混合利底亚（有 F# 又有 C 本位，暗而不甜），第 9–10 章可以再压暗，但 F# 必须留着。

---

## 第 1 章 · 城市 CITY / FIRST LIGHT

**设计**：玩家听到的第一分钟。夜间城市的稳态电力感，精密但不吵——像一台一直在运转、从来没出过错的机器。100 BPM，D 大调。

**文件名**：`ch01_city.wav` · 100 BPM · D 大调 · 90–120 秒

**风格**：
```
minimal electronic, IDM, precise glitch percussion, soft clicks and micro beats, warm analog synth pads, pulsing arpeggio carrying a recurring four note motif D F# A C, steady night city energy, 100 BPM, clean modern production, instrumental, in the key of D major
```

**结构**：
```
[Intro: soft pulses and clicks, no drums]
[Groove: glitch beat enters under warm pad]
[Variation: arpeggio states the four note motif]
[Groove: full texture, steady]
[Breakdown: pads only, no beat]
[Groove]
[Sustain: hold, no fade, no ending]
```

---

## 第 2 章 · 地球 EARTH / ORBITAL WATCH

**设计**：从轨道往下看的那种"空"。遥测的电子音不要做成提示音——全部落在 D 五声里，跟游戏里的金币和傅里叶钟声能融在一起，不抢。95 BPM，D 大调。

**文件名**：`ch02_earth.wav` · 95 BPM · D 大调 · 90–140 秒

**风格**：
```
minimal electronic ambient, orbital telemetry textures, gentle glitch rhythm, airy synth pads, slow melodic synth line carrying a recurring four note motif D F# A C, sense of looking down at earth from orbit, calm and focused, 95 BPM, clean spacious mix, subtle sub bass pulse, instrumental, in the key of D major
```

**结构**：
```
[Intro: telemetry air, no beat]
[Groove: soft glitch rhythm, airy pads]
[Variation: slow synth line states the motif]
[Groove: steady]
[Breakdown: pads and air only]
[Groove]
[Sustain: hold, no fade, no ending]
```

---

## 第 3 章 · 内太阳系 INNER SOL

**设计**：明亮但有威胁。太阳系的暖，加上小行星带的颗粒摩擦——音乐要"热"，但不能变成励志。90 BPM，D 大调偏混合利底亚。

**文件名**：`ch03_inner.wav` · 90 BPM · D 混合利底亚 · 90–140 秒

**风格**：
```
electronic and cinematic ambient hybrid, pulsing synth arpeggios, solar wind textures, warm swelling pads, light glitch percussion, a recurring four note motif D F# A C passed between arpeggio and pad, sun lit and tense, 90 BPM, instrumental, in the key of D mixolydian
```

**结构**：
```
[Intro: solar wind texture, no beat]
[Pulse: synth arpeggio and light glitch beat]
[Build: pads swell warmer, motif stated]
[Pulse: steady, focused]
[Atmosphere: beat thins, wide pads]
[Pulse]
[Sustain: hold, no fade, no ending]
```

---

## 第 4 章 · 外太阳系 OUTER SOL / GIANT'S REACH

**设计**：巨行星的重力。这里开始"变冷变宽"，打击退到很远，只剩金属共振和缓慢的深脉冲。80 BPM，D 混合利底亚。

**文件名**：`ch04_outer.wav` · 80 BPM · D 混合利底亚 · 100–150 秒

**风格**：
```
dark cinematic ambient, slow deep synth pulses, gas giant sub rumble, cold wide pads, distant metallic resonance, sparse electronic ticks, a recurring four note motif D F# A C played slowly in the pad, heavy and majestic, lots of space in the mix, 80 BPM, instrumental, in the key of D mixolydian
```

**结构**：
```
[Intro: low rumble and cold pads]
[Pulse: slow deep synth pulse, motif slowly]
[Rise: metallic resonance, wider pads]
[Pulse: steady, heavier]
[Atmosphere: sparse ticks and drone]
[Pulse]
[Sustain: hold, no fade, no ending]
```

---

## 第 5 章 · 奥尔特云 OORT CLOUD / COMET SHELL

**设计**：全书第一次真正的"静"。几乎没有打击，只有冰的嘶声、弓弦金属、管风琴长和弦，和一个像心跳一样的低频。70 BPM，D 混合利底亚。

**文件名**：`ch05_oort.wav` · 70 BPM · D 混合利底亚 · 100–150 秒

**风格**：
```
dark cinematic ambient, icy and sparse, bowed metal textures, glassy high harmonics, soft pipe organ chords, slow heartbeat sub pulse, a recurring four note motif D F# A C in the organ, frozen emptiness, very spacious reverb, minimal percussion, 70 BPM, instrumental, in the key of D mixolydian
```

**结构**：
```
[Intro: icy harmonics, no beat]
[Theme: soft organ chords state the motif over sub pulse]
[Texture: bowed metal and glass]
[Theme: organ a little fuller]
[Stillness: harmonics and sub only]
[Theme]
[Sustain: hold, no fade, no ending]
```

---

## 第 6 章 · 恒星邻域 STELLAR NEIGHBORHOOD

**设计**：穿过死寂之后遇到恒星，BPM 反而回升到 75——这是全书唯一一次"热起来"，别改成更慢。管风琴重复动机加钟表一样的脉冲，敬畏在增长，但不煽情。

**文件名**：`ch06_neighbor.wav` · 75 BPM · D 混合利底亚 · 100–150 秒

**风格**：
```
cinematic ambient, repeating minimalist pipe organ motif on a recurring four note figure D F# A C, warm star glow pads, ticking clock like pulse, growing awe, restrained emotion, 75 BPM, no drums, instrumental, in the key of D mixolydian
```

**结构**：
```
[Intro: ticking pulse and pads]
[Motif: repeating organ figure enters]
[Build: organ layers stack, pads glow]
[Motif: full and warm]
[Release: ticking and pads only]
[Motif]
[Sustain: hold, no fade, no ending]
```

---

## 第 7 章 · 银河 MILKY WAY / PULSAR BEACON

**设计**：这一章**必须有节拍**。磁星和脉冲星本来就该像灯塔一样规律地扫——音乐里的脉冲要跟游戏里脉冲星武器的四连发对上（武器射速在 `audio_director.gd:179` 单独放宽过，就是为了让这个节拍活下来）。80 BPM，D 混合利底亚。

**文件名**：`ch07_galaxy.wav` · 80 BPM · D 混合利底亚 · 100–150 秒

**风格**：
```
epic cinematic ambient, vast pipe organ, rhythmic pulsar ticks as the backbone, deep sub swells, shimmering high string texture, a recurring four note motif D F# A C in the organ, an entire galaxy turning, majestic and mysterious, 80 BPM, wide stereo, instrumental, in the key of D mixolydian
```

**结构**：
```
[Intro: pulsar ticks in the dark]
[Theme: vast organ chords, motif]
[Build: sub swells and shimmering strings]
[Theme: full organ and pulse]
[Drift: ticks and shimmer]
[Theme]
[Sustain: hold, no fade, no ending]
```

---

## 第 8 章 · 超星系团 SUPERCLUSTER / LANIAKEEA

**设计**：教堂一样的巨大。这一章原本是无词合唱，现在换成**管风琴、大提琴组和圆号的八度叠加**——同一个空腔共鸣，但没有人在唱。低音弦 ostinato 一直推，铜管只在远处渐强，不要重鼓。85 BPM，D 混合利底亚。

**文件名**：`ch08_cluster.wav` · 85 BPM · D 混合利底亚 · 110–150 秒

**风格**：
```
cinematic hybrid orchestral, low strings ostinato, soft brass swells, pipe organ, deep synth drones, cathedral like grandeur, a recurring four note motif D F# A C in organ and cellos in octaves, epic but controlled, no heavy drums, 85 BPM, instrumental, in the key of D mixolydian
```

**补充排除**：`choir, chorus, vocal pad`

**结构**：
```
[Intro: deep drone and organ]
[Ostinato: low strings enter]
[Build: brass swells from far away]
[Theme: strings, brass and organ together, motif in octaves]
[Release: drone and distant organ]
[Theme]
[Sustain: hold, no fade, no ending]
```

---

## 第 9 章 · 可观测宇宙 OBSERVABLE UNIVERSE / LAST HORIZON

**设计**：空与边缘。这一章要留一次**真正的静**——Boss 叫 THE SILENCE，音乐里必须有一次只剩 pad 的两秒，让玩家自己听见自己在打什么。全编制，扫弦 ostinato，重铜管，打击克制。85 BPM，D 混合利底亚偏暗。

**文件名**：`ch09_cosmos.wav` · 85 BPM · D 混合利底亚 · 110–150 秒

**风格**：
```
epic cinematic orchestral hybrid, sweeping string ostinato, heavy low brass, cosmic synth drones, massed strings and organ in octaves instead of voices, a recurring four note motif D F# A C across the whole orchestra, vast emptiness at the edge of the universe, restrained percussion, 85 BPM, instrumental, in the key of D mixolydian
```

**补充排除**：`choir, chorus, vocal pad`

**结构**：
```
[Intro: vast drone and void]
[Ostinato: sweeping strings]
[Build: brass rises, motif climbs]
[Silence: two seconds of pads only]
[Theme: full orchestra and drones]
[Release: strings and void]
[Theme]
[Sustain: hold, no fade, no ending]
```

---

## 第 10 章 · 宇宙膜 THE BRANE / BEYOND THE HORIZON

**设计**：终章，两张膜相撞。BPM 回到 90（全书最快），全交响加管风琴加电影打击。"暗而凯旋"——不是胜利，是"我们把它顶回去了"。人声部分全部用**弦乐组和管风琴的齐奏八度**堆出合唱的厚度。

**文件名**：`ch10_brane.wav` · 90 BPM · D · 120–150 秒

**风格**：
```
epic orchestral, full symphony orchestra, pipe organ, driving string ostinato, huge brass, cinematic percussion, massed strings in octaves where a choir would be, a recurring four note motif D F# A C stated by the full orchestra, two universes colliding, final chapter, dark and triumphant, 90 BPM, instrumental, in the key of D
```

**补充排除**：`choir, chorus, vocal pad, epic trailer vocals`

**结构**：
```
[Intro: organ and low strings]
[Ostinato: driving strings]
[Build: brass and organ stack]
[Theme: full orchestra states the motif]
[Bridge: organ alone over drones]
[Theme: everything]
[Sustain: hold, no fade, no ending]
```

---

## 生成之后

1. 全部丢进 `tools/music_in/`，跑现有的 ffmpeg 管线（-16 LUFS / TP -3 / 48k / libvorbis q5）。
2. **别变调**。章节曲变调会毁音色，主音不对就换一版重生。
3. 落地后改 `scripts/audio_director.gd:13` 的 `TRACKS` 十项，把 `music/orbital` 之类换成 `music/ch01_city`。`prepare_stage()` 会自动预载。
4. 跑 `tests/music_trial_check.gd`、`tests/audio_settings_check.gd` 回归。

## 验收

- 十条里都能听出那个四音动机，但没人会说出"这是同一首"——应该是"同一个世界"。
- 第 1 章和第 10 章放在一起听，前者的合成器脉冲和后者的全交响，应该是同一个人长大的两个阶段。
- 连续循环四遍不烦，接缝处鼓没有断口。
- 全程没有一个人声、没有一个词。
- 金币连响、傅里叶钟声进来时不脏（F 本位检查点）。
