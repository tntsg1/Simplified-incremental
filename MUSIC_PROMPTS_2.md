# 天穹防线 · Suno 作曲提示词（第二批）

本文件补 `SUNO_PROMPTS.md` 里没有的部分：环境层 10 条、Boss 签名层 10 条、跃迁 9 条、压力层 3 条。
另外开头有一段是对第一批那 15 条的修正，**先看第 0 节再生成任何东西**。

通用操作沿用 `SUNO_PROMPTS.md`：Custom 模式、最新模型、Instrumental 开关按标注、Weirdness 35%、Style Influence 75%、多跑几次挑最稳的一版、下载 WAV。

---

## 0. 对第一批 15 条的修正（重要）

### 0.1 全部锁 D 调

金币连响、傅里叶每一声钟、质数十拍、四个大招，全是 D 大调五声（D E F# A B）。章节曲必须是 D 系，否则 F 本位会和这些提示音打架。

**做法**：在 `SUNO_PROMPTS.md` 每一条「风格」行的**末尾**加下面这半句（英文，直接跟在原有内容后面）：

```
, in the key of D, D mixolydian mode, no F natural
```

第 1–3 章可以换成 `, in the key of D major`（那三章本来就该亮）。

Suno 对调性的服从度大概六成。生成后一定要验：**主音是不是 D**。不是的话，章节曲别变调（会把音色搞坏），换一版重生；只有环境层和压力层允许用 ffmpeg 变调。

### 0.2 结尾不准淡出

Suno 默认给淡出结尾。游戏里要无缝循环，淡出等于接缝处掉音。

**做法**：每条的「结构」标签最后一行都写 `[Sustain: hold the last chord, no fade, no ending]`。生成后如果有人声收尾感或明显打点收束，弃用。

### 0.3 三层方案改掉：AI 生不出分轨

`MUSIC_BRIEF_ZH.md` 里写的 bed / pressure / drive 三条对齐分轨，Suno 做不到——三次生成不会同步到同一时间轴、同一相位，叠在一起会相位抵消。

改成 AI 能落地的做法，二选一：

**方案 A（推荐，省事）**：每章只做一条完整曲，另外做 **3 条通用压力层**（见第 4 节），Boss 战和防线残血时叠上去。压力层故意**不含三度音**，只有 D 和 A 的持续音与气声，所以不管哪章是 D 大调还是混合利底亚，都能和声安全地铺在底下。游戏里用 1.2 秒交叉淡入进、淡出退。

**方案 B（累，但动态更真）**：每章生成两个版本，同一风格行、同一 BPM、同一调，只在结构标签上区分——`_calm` 版完全没有鼓，`_drive` 版加打击。游戏按战况在两个版本之间交叉淡入。缺点是生两次，且接缝偶尔会露出节奏差；只对第 6–10 章这种要打十分钟的做。

**默认走 A**。B 只用在你觉得某章的音乐在 Boss 战里太软的时候。

### 0.4 时长

章节曲 90–150 秒，环境层 30–60 秒，签名层和跃迁生成 30–40 秒后自己剪出 8–16 秒。Suno 给多长就用多长，超了由 `tools/prepare_music_trial.py` 那套 ffmpeg 管线切。

---

## 1. 环境层（10 条）

规格：30–60 秒无缝循环，-28 ~ -32 dB 混入，**没有节拍、没有旋律、没有和声进行**，只有"这个地方是什么地方"。生成时务必让结构标签全是持续段，不要出现任何 groove 类标签，否则 Suno 会自动加鼓。

命名：`amb01_city.wav` … `amb10_brane.wav`，全部纯器乐。

---

### amb01_city · 城市地表防线

**风格**：`field recording style ambient, night city from above, distant low traffic rumble, electrical substation hum, faint metal creaking, very sparse air, no rhythm, no melody, 40 seconds of continuous texture, extremely quiet, wide stereo`
**结构**：
```
[Texture: distant traffic rumble, no rhythm]
[Sustain: electrical hum holds]
[Texture: faint metal creaking far away]
[Sustain: hold, no fade, no ending]
```

### amb02_earth · 地球轨道

**风格**：`space ambient, orbital station interior, radio static and telemetry hiss, very low cabin air pressure tone, occasional soft digital blip far in the distance, no rhythm, no melody, weightless and empty, extremely quiet`
**结构**：
```
[Texture: radio static and air]
[Sustain: cabin pressure drone]
[Texture: one distant blip]
[Sustain: hold, no fade, no ending]
```

### amb03_inner · 内太阳系

**风格**：`space ambient, solar wind white noise, wide dusty atmosphere, tiny particles striking a shield with faint ticks, warm low solar rumble underneath, no rhythm, no melody, bright but empty, extremely quiet`
**结构**：
```
[Texture: solar wind noise, wide]
[Sustain: low solar rumble]
[Texture: sparse particle ticks]
[Sustain: hold, no fade, no ending]
```

### amb04_outer · 外太阳系

**风格**：`deep space ambient, gas giant low frequency rumble, magnetospheric hum, cold wide reverb, distant metallic resonance singing quietly, no rhythm, no melody, heavy and vast, extremely quiet`
**结构**：
```
[Sustain: gas giant sub rumble]
[Texture: magnetospheric hum]
[Texture: distant metal resonance]
[Sustain: hold, no fade, no ending]
```

### amb05_oort · 奥尔特云

**风格**：`icy space ambient, almost silence, very high glassy ice sublimation hiss, faint bowing metal harmonics, occasional distant low thunder of a comet passing, no rhythm, no melody, frozen emptiness, extremely quiet`
**结构**：
```
[Sustain: near silence with ice hiss]
[Texture: bowed metal harmonics]
[Texture: one distant low thunder]
[Sustain: hold, no fade, no ending]
```

### amb06_neighbor · 恒星邻域

**风格**：`stellar ambient, boiling plasma texture, continuous low magnetic field drone, faint crackle of stellar wind against a shield, wide and warm but immense, no rhythm, no melody, extremely quiet`
**结构**：
```
[Texture: plasma boil]
[Sustain: magnetic field drone]
[Texture: faint crackle]
[Sustain: hold, no fade, no ending]
```

### amb07_galaxy · 银河

**风格**：`galactic ambient, deep space floor, one slow pulsar sweep repeating every few seconds far away, shimmering high string texture barely present, no rhythm, no melody, turning and endless, extremely quiet`
**结构**：
```
[Sustain: deep space floor]
[Texture: one distant pulsar sweep]
[Texture: bare shimmer]
[Sustain: hold, no fade, no ending]
```

### amb08_cluster · 超星系团

**风格**：`cosmic ambient, gravitational flow direction, wide hot gas halo noise, sub bass pressure that never resolves, faint deep choir air without any words, no rhythm, no melody, cathedral scale emptiness, extremely quiet`
**结构**：
```
[Sustain: hot gas halo, wide]
[Sustain: unresolved sub pressure]
[Texture: wordless air far away]
[Sustain: hold, no fade, no ending]
```

### amb09_cosmos · 可观测宇宙

**风格**：`cosmic ambient, cosmic web low frequency resonance, pressure of time and distance, vast void breathing slowly, a single thin high tone that holds without wavering, no rhythm, no melody, the edge of everything, extremely quiet`
**结构**：
```
[Sustain: cosmic web resonance]
[Sustain: void breathing]
[Texture: one thin high tone holds]
[Sustain: hold, no fade, no ending]
```

### amb10_brane · 宇宙膜

**风格**：`higher dimensional ambient, tension of a membrane under strain, sub bass vibration below hearing, glassy harmonic shimmer at the edge of a tear, air that sounds like it is being stretched, no rhythm, no melody, wrong and enormous, extremely quiet`
**结构**：
```
[Sustain: membrane sub vibration]
[Texture: glassy shimmer at the tear]
[Sustain: stretched air]
[Sustain: hold, no fade, no ending]
```

---

## 2. Boss 签名层（10 条）

规格：目的是让十个 Boss 一听就分得开。**必须是没有调性的材质声**（噪声、金属、岩石、能量），不含旋律、不含和弦，这样能安全叠在三首 Boss 底座上。

生成 30–40 秒，剪出最有辨识度的 8–16 秒，Boss 入场时播一次，之后作为循环里的点缀。

命名：`sig_<boss_kind>.wav`，纯器乐。

---

### sig_asteroid · 毁城小行星 CHIRON

**风格**：`giant rock under stress, deep stone cracking and grinding, granular debris avalanche, low pressure wave, no pitch, no melody, no rhythm, massive and physical, monophonic weight`
**结构**：
```
[Impact: deep stone crack]
[Texture: grinding rock and debris]
[Sustain: low pressure]
[Sustain: hold, no fade]
```

### sig_planet · 流浪天体 NOMAD

**风格**：`rogue planet passing, immense gravitational groan, atmosphere tearing at the edges, deep tectonic shudders, no pitch, no melody, no rhythm, slow and unstoppable`
**结构**：
```
[Impact: gravitational groan]
[Texture: atmosphere tearing]
[Sustain: tectonic shudder]
[Sustain: hold, no fade]
```

### sig_dwarf · 被劫持的矮行星 CERES

**风格**：`hijacked dwarf planet, alien thrusters firing against rock, strained metal clamps on stone, high pressure venting, no pitch, no melody, no rhythm, mechanical violence on a natural body`
**结构**：
```
[Impact: thruster ignition]
[Texture: metal clamp strain on rock]
[Sustain: venting pressure]
[Sustain: hold, no fade]
```

### sig_mothership · 攻城母舰 LEVIATHAN

**风格**：`alien siege mothership, industrial metal ostinato without pitch, servos and hydraulics, hull groaning under its own mass, hangar doors opening, no melody, no rhythm, gigantic machine`
**结构**：
```
[Impact: hull groan]
[Texture: servos and hydraulics]
[Texture: hangar doors open]
[Sustain: hold, no fade]
```

### sig_cigar · 星际来客 'OUMUAMUA

**风格**：`interstellar visitor, icy elongated body sublimating, glassy ice fracture, thin high whistle of outgassing, unnatural silence around it, no pitch, no melody, no rhythm, cold and wrong`
**结构**：
```
[Impact: ice fracture]
[Texture: sublimation whistle, thin]
[Sustain: unnatural silence]
[Sustain: hold, no fade]
```

### sig_star · 失控恒星 VESPER

**风格**：`runaway star, coronal mass ejection, deep fusion roar far below, magnetic field snapping, heat shimmering in the air, no pitch, no melody, no rhythm, overwhelming energy`
**结构**：
```
[Impact: magnetic snap]
[Texture: fusion roar, distant]
[Sustain: heat shimmer]
[Sustain: hold, no fade]
```

### sig_magnetar · 磁星 MAGNETAR

**风格**：`magnetar, magnetar burst, enormous magnetic field flexing, sharp repeating electromagnetic tick, radiation pressure, no pitch, no melody, machine-like precision, terrifying regularity`
**结构**：
```
[Impact: magnetic field flex]
[Texture: repeating electromagnetic tick]
[Sustain: radiation pressure]
[Sustain: hold, no fade]
```

### sig_cathedral · 外星巨构战舰 CATHEDRAL

**风格**：`alien megastructure warship, cathedral sized metal structure, enormous low brass resonance without pitch, chains and counterweights moving, a choir of air through vaults, no melody, no rhythm, architectural scale`
**结构**：
```
[Impact: structure resonance, huge]
[Texture: counterweights moving]
[Texture: air through vaults]
[Sustain: hold, no fade]
```

### sig_rift · 宇宙灾变核心 THE SILENCE

**风格**：`reality tear, air being pulled inward, reverse reverb tail, a moment of complete silence in the middle, glass shattering into nothing, no pitch, no melody, no rhythm, wrong and hollow`
**结构**：
```
[Texture: inward pull]
[Silence: one beat of nothing]
[Impact: glass shattering into void]
[Sustain: hollow air]
```

### sig_brane · 对撞之膜 THE OTHER BRANE

**风格**：`two membranes colliding, sub bass impact below hearing, glassy surface flexing under impossible pressure, a slow tearing that never completes, no pitch, no melody, no rhythm, the sound of scale itself breaking`
**结构**：
```
[Impact: sub bass collision]
[Texture: membrane surface flex]
[Sustain: incomplete tearing]
[Sustain: hold, no fade]
```

---

## 3. 跃迁（9 条）

现在的 `scale_jump` 一条 9.8 秒给九次跃迁共用。改成九条，**每条结束落在下一章的主音上**，音乐和章节切换才接得上。

结构都是三段：蓄力 → 掠过 → 到达。生成 30–40 秒，剪出最好的一段 6–8 秒；剪的时候务必让**到达那一下落在 D 音**上。

命名：`jump_to_02.wav` … `jump_to_10.wav`，纯器乐。第一条 `jump_to_01` 不存在（没有从第 0 章来的跃迁）。

---

### jump_to_02 · 城市 → 地球

**风格**：`short cinematic transition, low synth riser, atmosphere thinning, wide air pass, arriving in orbit, D tonal center, instrumental, no drums until the very end, 6 seconds, clean`
**结构**：
```
[Charge: low riser builds]
[Pass: wide air sweeps past]
[Arrival: single D tone, hold]
```

### jump_to_03 · 地球 → 内太阳系

**风格**：`short cinematic transition, rising warm synth swell, solar wind passing, bright arrival, D tonal center, instrumental, no drums until the very end, 6 seconds, clean`
**结构**：
```
[Charge: warm swell rises]
[Pass: solar wind sweeps]
[Arrival: single D tone, hold]
```

### jump_to_04 · 内太阳系 → 外太阳系

**风格**：`short cinematic transition, descending deep synth swell, cold air passing, heavy arrival, D tonal center, instrumental, no drums until the very end, 6 seconds, clean`
**结构**：
```
[Charge: deep swell descends]
[Pass: cold air sweeps]
[Arrival: single D tone, hold]
```

### jump_to_05 · 外太阳系 → 奥尔特云

**风格**：`short cinematic transition, icy high shimmer rising, air freezing, glassy arrival, D tonal center, instrumental, no drums, 6 seconds, clean, sparse`
**结构**：
```
[Charge: icy shimmer rises]
[Pass: freezing air]
[Arrival: single D tone, hold]
```

### jump_to_06 · 奥尔特云 → 恒星邻域

**风格**：`short cinematic transition, heat rising against cold, organ chord swelling into light, D tonal center, instrumental, no drums until the very end, 6 seconds, warm`
**结构**：
```
[Charge: heat rises against cold]
[Pass: light swells]
[Arrival: organ lands on D, hold]
```

### jump_to_07 · 恒星邻域 → 银河

**风格**：`short cinematic transition, vast organ swell, pulsar tick accelerating, D tonal center, instrumental, no heavy drums, 6 seconds, majestic`
**结构**：
```
[Charge: organ swell widens]
[Pass: pulsar ticks accelerate]
[Arrival: single D tone with organ, hold]
```

### jump_to_08 · 银河 → 超星系团

**风格**：`short cinematic transition, low string ostinato rising, distant choir swelling, D tonal center, instrumental, no heavy drums until the end, 6 seconds, cathedral scale`
**结构**：
```
[Charge: low strings rise]
[Pass: distant choir swells]
[Arrival: choir lands on D, hold]
```

### jump_to_09 · 超星系团 → 可观测宇宙

**风格**：`short cinematic transition, everything pulling away into void, thin high tone over sub pressure, D tonal center, instrumental, no drums, 6 seconds, empty`
**结构**：
```
[Charge: sound pulls away]
[Pass: thin high tone over sub]
[Arrival: single D tone, hold]
```

### jump_to_10 · 可观测宇宙 → 宇宙膜

**风格**：`short cinematic transition, membrane tearing open, sub bass impact, unresolved tension, D tonal center but deliberately not resolved, instrumental, 6 seconds, wrong and enormous`
**结构**：
```
[Charge: tearing builds]
[Pass: sub bass impact]
[Arrival: D tone that does NOT resolve, hold]
```

---

## 4. 压力层（3 条）

给 Boss 战和防线残血用。**关键：不含三度音。** 只有主音 D 和属音 A 的持续音、气声、低频脉冲——没有 F 也没有 F#，所以不管底下那章是 D 大调还是混合利底亚都能叠，永远不会打架。

60–90 秒无缝循环，混入时比章节曲低 6–8 dB。

命名：`layer_pressure_1.wav` / `_2` / `_3`。

---

### layer_pressure_1 · 低频脉冲型（早期章用）

**风格**：`tension bed, slow low synth pulse on D, no third, no melody, deep sub drone, subtle rhythmic pressure, no drums, no chord changes, 60 seconds seamless loop, restrained`
**结构**：
```
[Sustain: low D drone]
[Pulse: slow sub pulse on D and A]
[Sustain: hold, no fade, no ending]
```

### layer_pressure_2 · 合唱气声型（中期章用）

**风格**：`tension bed, wordless choir air on D and A only, no third, no melody, no drums, slow breath-like swells, distant and anxious, 60 seconds seamless loop`
**结构**：
```
[Sustain: choir air on D and A]
[Swell: breath rises and falls]
[Sustain: hold, no fade, no ending]
```

### layer_pressure_3 · 钟与反拍型（后期章用）

**风格**：`tension bed, distant bell strike on D, sparse off-beat metallic tick, deep sub drone underneath, no third, no melody, no drums, clock-like dread, 60 seconds seamless loop`
**结构**：
```
[Sustain: deep sub drone]
[Pulse: distant bell on D, off-beat ticks]
[Sustain: hold, no fade, no ending]
```

---

## 5. 还需要补的两条（第一批漏的）

`SUNO_PROMPTS.md` 里已经写好 prompt，但文件还没做，生成时记得套用第 0 节的修正：

- **结局曲 `ending.wav`**：必须引用标题曲的钢琴动机，让玩家最后认出"这是开头那段"。
- **标题曲 `title.wav`**：现有 `bgm_main` 125 秒可以先用着，不急。要重做的话按原 prompt 加 `in the key of D`。

---

## 6. 生成顺序

1. **十条环境层**（最快见效，填满波次之间的静音，成本最低）
2. **十条 Boss 签名层**（短素材，十个 Boss 立刻分得开）
3. **三条压力层**（Boss 战和残血的动态，一次做三条够用）
4. **九条跃迁**（最后做，因为要等十章主体曲的调性都定下来）
5. 结局曲

章主体曲（第 1 章正式版 + 6–10 章）照 `SUNO_PROMPTS.md` 那五条走，别在这里重复生成。

---

## 7. 生成之后怎么验

1. 时长、峰值、响度交给 `tools/prepare_music_trial.py` 那套 ffmpeg 管线（-16 LUFS / TP -3 / 48k / libvorbis q5）。
2. 环境层和压力层先测主音：不是 D 就用 ffmpeg 变调到 D，这两类只有持续音，变调不会毁音色。
3. 章节曲和 Boss 底座不测变调，只测循环接缝——接缝处鼓若糊一下，换个切点。
4. 全部落地后跑 `tests/music_trial_check.gd` 和 `tests/audio_settings_check.gd` 回归。
