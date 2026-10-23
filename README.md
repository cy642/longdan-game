# 龙胆：逆命三国

**重生之我在三国当赵子龙**。操控 Q 版赵云，长坂救主，汉水设伏。当前包含第一章「长坂逆命」和第二章「汉水孤营」，共十二个区域。

仓库只维护 **Godot 4.7.2 / GDScript** 这一套游戏。在线版与 Windows 本地版由同一工程导出，关卡、角色、地图与技能一致；进度分别保存，不跨浏览器或设备自动同步。

## 开始游戏

- 在线：[开始游戏](https://cy642.github.io/longdan-game/)。首页直接进入 Godot 游戏加载页，点击「开始游戏」；首次载入需要下载引擎与素材，使用电脑键盘与鼠标。
- Windows：导出后运行 `builds/windows/Longdan.exe`，无需安装 Godot 或联网。构建包保存在本地 `builds/`，不纳入源码仓库。
- 编辑器：在 Godot 4.7.2 中导入 `godot/project.godot`，按 F5 运行；也可使用 `Open-Godot.cmd` 指定本机引擎。
- 标题可选择章节、普通/剧情难度，继续、重玩或查看所选章节战报。**第一章通关后，在战报点击「继续征程 · 汉水孤营」进入第二章**；已有汉水进度会继续原检查点。

## 操作

| 行动 | 键盘 / 鼠标 |
|---|---|
| 移动 | WASD / 方向键 |
| 龙枪三式 | J / 鼠标左键，可按住连续出枪 |
| 闪避 | 空格 / K，消耗 16 气力 |
| 横扫破阵 | Q / 鼠标右键，消耗 30 气力，可破盾 |
| 青釭断势 | R，夺剑后满战意发动 |
| 行军药 | F；服药会被受击打断，营火补满三份 |
| 救援 / 休整 / 前进 | E |
| 集合 / 守点 / 冲阵 | 1 / 2 / 3 |
| 黄忠援射 | 北山接应战靠近黄忠按 3，冷却 6 秒 |
| 军图 / 暂停 / 全屏 | M / Esc / F11 |

键盘出枪优先锁住近处敌人，鼠标出枪跟随指向。第三枪真实命中或精准闪避积累「枪势」，满三格后强化下一次 Q。营火可选择连锋或游龙战法。随军负责牵制，赵云需要亲自完成击杀；敌人红区、破势和收招提示对应实际出手与反击窗口。暂停中可单独关闭脚步声。

## 两章内容

第一章沿「溃军山道 → 荒村小巷 → 破庙夺剑 → 井畔旧宅 → 粮道岔口 → 北桥决战」推进，包含夏侯恩与张郃单挑，以及救百姓、保糜夫人、截粮道三条可选命运。

第二章沿「汉水林道 → 北山粮道 → 乱石归途 → 孤营大门 → 河湾反击 → 铁营决战」推进：接应黄忠、护送粮车、藏兵开门、抓住擂鼓战机，再决战铁面督军。可焚毁火箭辎重、回救张著与伤兵；完成空营计并通关解锁「龙胆·回澜」。

两章分别保存检查点、战法、支线和战报。重玩所选章节保留另一章记录；旧 Godot v1 存档可读入第一章，后续写入 v2，原文件保留。保存失败时界面会提示本会话暂存。

## 当前画面与后续开发

**0.5.0 绘画环境（2026-10-23）**：建筑、植物、岩壁、营栅以及土路、湿泥、旧院石和竹林地表采用可追溯的生成原画，离线烘焙为游戏贴图。长坂的残村与汉水的竹林军营保持不同主题；角色使用固定模型比例及脚底锚点。实际画面见 [六区实机图](docs/images/map-materials-0.5.0.jpg)，素材与重建顺序见 [绘画环境管线](docs/PAINTED-ENVIRONMENT.md)。

第一章与第二章主路均可游玩。当前敌军动作以现有原画和代码姿态为主，独立逐帧图集、黄忠剧情演出与完整音乐仍待制作；完整普通难度节奏还需持续实玩校准。玩法、状态机与下一阶段方向见 [可玩性计划](docs/PLAYABILITY-PLAN.md)、[第二章设计稿](docs/CHAPTER-2-HANSHUI.md) 和 [开发交接](docs/CHAPTER-2-PLAYABLE-PLAN.md)。

## 开发、构建与验证

- 游戏入口：`godot/scenes/main.tscn`。第一章关卡与招式参数的唯一数据源是 `godot/data/chapter1.json`；第二章为 `godot/data/chapter2.json`，第一章局部地标与碰撞补充为 `godot/data/map_details.json`。直接维护这些文件。
- 角色原图保存在 `godot/assets/`；[角色素材说明](godot/art_source/characters/ART-NOTES.md) 和 [八方向出枪提示词](godot/art_source/characters/ATTACK-V3-NOTES.md) 保留生成来源。`prepare_assets.py` 直接读取这些原图重建锚点清单，`--check` 只检查现有清单是否一致。
- 双章地图巡览：编辑器打开 `godot/tests/map_tour.tscn` 按 F6，或运行 `Map-Tour.cmd`；Tab 切章、F1–F6 切区，不写入玩家存档。
- 工程职责、完整操作、测试和地图重建见 [Godot 开发说明](godot/README.md)；分区要求见 [地图美术规范](docs/MAP-ART-DIRECTION.md)。

在仓库根目录执行，使用 Godot 4.7.2 及匹配的导出模板：

```powershell
./Run-Checks.ps1 -Engine "Godot 可执行文件绝对路径"
python godot/tools/prepare_assets.py --check
godot --headless --path godot --export-release "Windows Desktop"
godot --headless --path godot --export-release "Web"
python godot/tools/verify_export_pack.py
```

二十二组源码检查使用隔离的测试存档。0.5.0 画面版记录为 **42,815 项采样/状态断言、0 失败**，地图基线对照 **1,107/0**，正常镜头 **17 张原生截图**；这些检查不等于完整人工通关或难度验收。各轮验证与发布结果见 [开发记录](CLOUD-POLISH.md)。

`godot-play/` 是提交到 Git 的 Web 导出，`index.html` 是统一入口。修改游戏或 Web 加载页后要重新导出、验证，并一同提交；GitHub Pages 只发布仓库文件，不会自动运行 Godot 构建。新增中文后重建字体子集，修改地图后重新烘焙。原 Canvas 程序已从当前仓库移除，后续开发只使用 Godot。
