# 天穹防线 / SKYGUARD

Godot 4.7 原生 GDScript 太空防御增量游戏。六阶段主线：城市、地球、太阳系、银河、星系团、宇宙；每阶段十波与一个 Boss，最后进入结局。

## 开始游戏

- 双击 `run_game.cmd`：使用本机 `E:\godot\godot47` 的 Godot 4.7 启动源项目。
- 独立版：双击 `build\Skyguard.exe`。资源已内嵌，不需要 Godot 或网络；也可解压 `build\Skyguard-Windows.zip` 后启动。
- 编辑项目：用 Godot 4.7 打开 `project.godot`。

默认 1600×900；窗口缩放适配 1280×720。Windows 系统中文字体通过 SystemFont 使用，不打包商业字体。

## 操作与成长

- 城市初期点击来袭目标发射一次；按住目标持续发射。目标毁灭后，再选择下一个目标。
- 第六波开放自动化购买：战场左下角常驻 $200 按钮，不足时显示还差多少；点击购买后所有武器自主拦截，点击目标仅指定全体系优先目标。升级面板也保留购买入口。
- `U` 打开/关闭升级，`Esc` 暂停/继续，`F11` 全屏。
- 击毁敌人取得资金，升级全局弹头、速度、装填，再逐步开放暴击、范围、贯穿和锁定。
- 新阶段的武器在升级面板花钱部署。旧武器继续作战、继承全部全局升级与里程碑。
- 伤害 Lv.10、25、50、75、100、125、150 有翻倍突破；装填每十级翻倍发射器；范围 Lv.10 额外 +30%、Lv.25 额外 +25% 覆盖。
- 城市建议先拿伤害和装填突破，保留 $200 购买自动化。
- 成长曲线是锯齿形：成员血量随章节和波次指数增长（城市起步 100 HP，精英 ×3），每成员奖励按血量的 0.4 次方增长。每章开头敌人能逼近防线，升级后在射程圈边缘就被击碎；章末与 Boss 是需要攒钱突破的墙。伤害是主要瓶颈，覆盖限制一次攻击消灭的成员，贯穿把剩余伤害送到邻近群落。
- 炮台只攻击进入射程圈（虚线）的威胁，Boss 除外；“拦截射程”升级每级弹速 +8%、半径 +3%（上限 +35%）。命中时浮出伤害数字。
- 悬停炮台查看实际齐射伤害、间隔与成员覆盖；悬停威胁查看放大图和在途伤害。暂停菜单提供音乐/音效独立音量、静音与柔和特效。

普通波结束恢复满血；Boss 碰撞前未击毁会失败。失败从本阶段第一波重试，资金、升级、已购武器保留。可先在失败面板升级再重试。

## 存档

自动保存波次切换、购买、阶段变化，以及每十秒的战斗状态。暂停菜单可保存并返回标题。启动后选择“继续战役”。恢复敌群、弹道、冷却、波次、随机状态和资金，不结算任何离线收入。

新标识：`skyguard` / version 1。位置：`%APPDATA%\Godot\app_userdata\天穹防线\skyguard_save_v1.json`，配有 `.bak` 备份；不会读取旧殖民游戏存档。启动新战役会提示覆盖确认。

## 工程与数据

- `scripts/combat.gd`：60 Hz 确定性战斗与可序列化状态；完全独立于画面，支持加速测试。
- `scripts/campaign.gd`：战役状态机、波次、Boss、阶段与失败继承。
- `scripts/growth.gd`：资金、升级、自动化、武器购买与里程碑公式。
- `scripts/save_store.gd`：校验、临时写入、备份与恢复。
- `scripts/battlefield.gd`：程序几何、SVG 敌人、Shader 背景、星系 MultiMesh 批量绘制与连续拉远。
- `scripts/main.gd`：中文界面、输入、暂停、声音和固定步进驱动。
- `scripts/audio_director.gd`：24 个普通声道、8 个关键提示声道、六阶段音乐交叉渐变与 Boss 节奏层。
- `data/*.tres`：六阶段与波次预算；`data/weapons`、`data/upgrades`：可编辑 Resource 配置。

敌群、弹道、特效使用字典池；成员不创建节点。极高速装填将不足一帧的多次发射合并为齐射，保留理论伤害/覆盖增长。为减少密集场景文字遮挡，只显示部分群落数字；鼠标悬停与集火目标始终显示详细成员、生命与撞击时间。

所有发布关卡固定，不随玩家购买即时增强。每波约 25–90 秒，敌群更密、飞行更快；三种购买策略、三个种子的模拟活动时间约 1.2–1.4 小时，不能替代真人完整试玩。`tests/growth_probe.gd` 逐波输出敌人被击毁时的飞行深度、同屏数量与伤害/覆盖余量，调数值后复跑。齐射覆盖计算空间重叠，单体伤害保留完整增幅。

## 画面与声音

六套原创 SVG 舰船、危险物与炮台，行星昼夜与大气，连续尺度拉远。命中闪光、弹道、后坐、暴击、部分群落碎裂和 Boss 爆炸均由战斗事件触发，特效不改变战斗计时。高密度场景减少重复细粒子和文字，悬停/集火始终可查看目标。

六首原创 96 秒立体声配乐与 Boss 脉冲、购买/突破/胜负提示由 `tools/compose_audio.py` 生成。正式武器、命中和击毁使用 `tools/clean_audio.py` 生成的 11 个原创干净音效，平滑包络、线性留余量、低通噪声；不使用旧版粗糙爆炸音。普通声部同时最多五个，主武器优先发声，Boss/警报独立保留声道。静音覆盖全部声音，音乐和音效可分别调至零。

素材说明见 `assets/audio/CREDITS.md`。原型阶段的 Kenney CC0 音效留作源文件参考，已不在运行中播放；其许可保留。

## 验证与再导出

在项目目录用控制台版 Godot：

```powershell
& 'E:\godot\godot47\Godot_v4.7-stable_win64_console.exe' --headless --path . --script res://tests/logic_check.gd
& 'E:\godot\godot47\Godot_v4.7-stable_win64_console.exe' --headless --path . --script res://tests/balance_matrix.gd
& 'E:\godot\godot47\Godot_v4.7-stable_win64_console.exe' --headless --path . --script res://tests/coverage_check.gd
& 'E:\godot\godot47\Godot_v4.7-stable_win64_console.exe' --path . --resolution 1600x900 --script res://tests/presentation_check.gd
& 'E:\godot\godot47\Godot_v4.7-stable_win64_console.exe' --headless --path . --export-release 'Windows Desktop' build/Skyguard.exe
```

回归使用独立测试存档或禁用保存。`proofs` 保存实机画面与日志，不进入独立版。`--capture` 开发参数提供代表性场景，不代表玩家进度；城市到地球流程检查则使用真实收益、升级和输入。详见 `VERIFICATION.md`。
