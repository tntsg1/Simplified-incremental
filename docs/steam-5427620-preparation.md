# SKYGUARD — Steam 上架准备草稿

App ID：5427620。此文件是本地准备资料，尚未填入 Steamworks、提交审核或公开发布。

## 用户已确定的信息与定价依据

- Steam 版为付费产品。
- 开发者名称：tntsg；发行商名称：tntsg。
- 用户指定的公开客服邮箱：cantarellahus@gmail.com。对应 Steamworks 基本信息页的“客服电子邮件”字段；后台是否保存尚未核对。
- 用户已确认美元区基础售价 $4.99、中国大陆区人民币基础售价 ¥22；后台定价尚未设置。¥22 是已获用户同意的自定区域价格，尚未确认是否等于当前 Steam 自动推荐值。其他地区价格待在 Steamworks 中按区域建议逐项核对。
- 定价参照：Nodebuster Steam 页面显示 $2.99（https://store.steampowered.com/app/3107330/Nodebuster/）；Planetary Defense Force Steam 社区页显示 $5.99（https://steamcommunity.com/app/2332030/）。价格查询于 2026-10-10 用户当地日期。
- 判断：SKYGUARD 有六阶段成长主线，但真人时长、重玩价值与平台功能仍需验证，且存在免费网页版；$4.99 是暂定中间价，不是销量或收益预测。
- Jev 选择 $4.99；条件概率 $2.99 为 17%、$4.99 为 83%、$7.99 为 0%；置信度 74%。这些是模型给定条件下的选择分布，不是市场销售概率。

## 已核对的项目资料

- 源项目：E:/godot/zengliang；Godot 原生项目，Windows x86_64 导出预设，入口 scenes/main.tscn。
- 当前配置中的内部名称为“天穹防线”，Steam 产品名为 SKYGUARD。
- 已存在 build/Skyguard.exe 以及 build/skyguard_trailer_en.mp4；两者尚未在本轮运行或审阅，不能据此声明为最终发布版本。
- README 描述六阶段防御增量战役：城市、地球、太阳系、银河、星系团、宇宙。具体文案以最终可运行版本为准。
- 源代码包含中文 / English 切换与英语翻译资源，完整翻译覆盖和导出包表现仍需验证。
- 项目有大量现有未提交改动。此次准备只新增本文件，不改动现有游戏代码。

## 简体中文短描述草稿

从第一枚导弹，到守护宇宙最后的光。SKYGUARD 是一款科幻防御增量游戏：拦截来袭敌群，升级火力，将天体改造成武器，让防线从城市逐步扩展至宇宙。

## English short description draft

From your first missile to the last light of civilization. SKYGUARD is a sci-fi defense incremental game: intercept incoming threats, upgrade your firepower, turn celestial bodies into weapons, and expand your defense from a city to the cosmos.

## 简体中文详细描述草稿

[h2]最后的光，留给文明。[/h2]
从城市上空的第一场拦截开始，建立不断成长的防御体系。击毁来袭目标获得资金，升级火力与覆盖能力，在越来越广阔的尺度中守住防线。

[h2]从城市到宇宙[/h2]
战役跨越城市、地球、太阳系、银河、星系团与宇宙六个阶段。迎接各阶段的敌潮与 Boss，带着已有的升级继续向外推进。

[h2]让天体成为武器[/h2]
部署新武器，将可改造的天体纳入火力网络。此前建立的力量继续参与战斗，让每一次成长都成为下一阶段的基础。

[h2]从手动拦截到自动防御[/h2]
开始时亲自选定目标开火，随后解锁并购买自动化，让武器自主拦截；点击目标可指定优先攻击对象。选择升级与部署时机，突破不断增强的威胁。

[h2]几何战场[/h2]
几何形体、轨迹与逐步拉远的尺度构成科幻战场。游戏提供暂停、速度调整与自动保存，方便分段继续战役。

## English full description draft

[h2]Keep the last light of civilization alive.[/h2]
Begin with an interception above a city and build a growing defense network. Destroy incoming threats to earn funds, improve your firepower and coverage, and hold the line as the battlefield expands.

[h2]From a city to the cosmos[/h2]
Advance through six campaign stages: city, Earth, solar system, galaxy, galaxy cluster, and cosmos. Face waves and bosses while carrying your upgrades into each new scale.

[h2]Turn celestial bodies into weapons[/h2]
Deploy new weapons and convert available celestial bodies into part of your defense. Earlier investments continue fighting alongside your expanding arsenal.

[h2]Build an automated defense[/h2]
Start by selecting targets and firing manually. Unlock and purchase automation to let your weapons intercept independently, then select priority targets and choose when to upgrade or deploy more firepower.

[h2]A geometric battlefield[/h2]
Geometric forms, projectile trails, and expanding scales shape the battlefield. Pause, adjust game speed, and return to your campaign with automatic saving.

## 素材与版本待办

- 审阅 build/promo、build/shots 中的现有画面，重新采集最终版本的真实游戏截图；不要把测试注入场景标为真人游玩证据。
- 审阅既有英语预告片，核对它与当前实际游戏是否一致。
- 制作并核对 Steam 商店胶囊、库图及图标；尚未确认现有素材满足 Steam 尺寸和规则。
- 从当前代码重新导出到独立发布目录，核对导入错误、启动、中文/英语、存档/继续、阶段推进、设置及退出重启。
- 后台读取实际 Depot ID 后再生成 SteamPipe 上传配置。不能用 App ID 或软件包 ID 猜测 Depot ID。
- 确认 Steamworks 启动项与上传包中的实际可执行文件路径一致。
- 最低系统要求需要实测依据；暂不编造 CPU、内存和显卡指标。
- 成就、Steam Cloud、控制器支持及其他商店功能须经实现与测试确认后才能勾选。

## 必须由开发者提供的事实

- 计划发行日期，以及正式版或抢先体验意向。
- 内容调查与 AI 披露：是否有随游戏提供给玩家的 AI 生成美术、音乐、文本或其他内容，是否运行时生成；须按实际制作过程回答，不能仅凭游戏截图推断。
- 第三方素材、字体、音频与其他资源的实际授权情况。

## 本轮操作能力检查

后续检查更新：已通过 System.Drawing 成功读取当前桌面截图，可自行核对可见页面。尝试构建自动点击组件时被 Bitdefender 拦截，未完成官网字段填写或保存；已删除此次临时点击脚本。不要继续使用被拦截组件或关闭安全防护。当前网页外部链接段的准备值为：游戏网站 URL https://stellarascensiongame.com/skyguard/；论坛、统计、在线手册、健康警告、隐私政策、Metacritic、社交媒体及 Steam Deck 说明链接，待有真实且适用的页面时再填写。

Remote Desktop Commander 可访问已连接电脑的终端和文件，没有专用浏览器点击工具。本轮只读查询本机及连接设备的 9222、9223、9333 监听端口，未发现可连接的调试端口。这不是对其他所有连接方式的穷尽检查。

尚未读取登录中的 Steamworks 页面 DOM，尚未保存任何后台字段。下一步可由用户打开“编辑商店页面”并提供字段截图，使用本草稿逐项核对填写。

## 官方参考

- 商店与构建审核：https://partner.steamgames.com/doc/store/Review_Process
- 商店图形素材：https://partner.steamgames.com/doc/store/assets/standard
- 图形素材总览：https://partner.steamgames.com/doc/store/assets

提交审核与公开发布前，需审阅实际后台预览和构建验证结果，并取得用户最终确认。
