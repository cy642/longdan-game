# 龙胆：逆命三国 · Godot 电脑版

地图打磨版：可编辑布局见 `data/map_details.json`，六区巡游入口为 `../Map-Tour.cmd`，地图设计与测试说明见 [MAP-POLISH.md](../MAP-POLISH.md)。仓库正式构建沿用原有 Godot 存档目录；此前单独交付的本地预览包使用 `LongdanMapPolishPreview`，两者存档互不迁移。

宣传副标题：**重生之我在三国当赵子龙**。Godot 4.7.2 / GDScript 的原生 2D 动作冒险，第一章「长坂逆命」包含六个区域、两位敌将和三条可选命运。原来的 Canvas 网页版继续保留在仓库根目录。

## 直接试玩

- Godot 在线试玩：<https://cy642.github.io/longdan-game/godot-play/>，使用电脑 Chrome、Edge 或 Firefox；首次需要下载引擎与素材。
- 本地导出后可双击 `../builds/windows/Longdan.exe`，运行此程序无需安装 Godot、Python 或联网；Windows 构建包不纳入源码仓库。
- 打开工程：在 Godot 4.7.2 中导入本目录的 `project.godot`，按 F5 运行。
- 快速巡览：打开 `tests/map_tour.tscn` 后按 F6，或在 Windows 使用根目录 `Map-Tour.cmd`；F1–F6 切换六区，WASD / 方向键移动，M 打开军图。巡览不读取或写入玩家存档。
- Windows 版和浏览器版分别保存进度；旧 Canvas 版存档不会自动迁移。

## 操作与战斗

| 行动 | 按键 |
|---|---|
| 移动 | WASD / 方向键 |
| 龙枪三式 | J / 左键，可按住连续出枪 |
| 闪避 | 空格 / K，16 气力 |
| 横扫破阵 | Q / 右键，30 气力，可破盾 |
| 青釭断势 | R，夺剑后满战意发动 |
| 行军药 | F；服药可被打断，营火补满三份 |
| 救援 / 休整 / 前进 | E |
| 集合 / 守点 / 冲阵 | 1 / 2 / 3 |
| 军图 / 暂停 / 全屏 | M / Esc / F11 |

键盘出枪优先锁住近处敌人，鼠标出枪跟随指向。攻击只有实际命中时段产生伤害，同一次动作对同一目标只命中一次。动作尾段支持 0.14 秒短按缓冲；普攻与技能收招可用闪避取消，实际出枪时段不能提前取消。

敌人起手红区与真实命中范围一致，前段跟踪、后段锁定。弓箭和冲枪以线段 / 连续位移判定，避免跨帧穿过障碍。完整盾防的正面普通攻击保留盾兵反击，横扫、绕后或破势可创造开口。夏侯恩双剑与张郃三连突需等整套连招收完；张郃半血变招。

随军只在井畔营救和桥头突围参与战斗，单人 3.5 伤害 / 1.8 秒，最多将敌人体力压到 22%，赵云需要亲自完成击杀。正式单挑中随军负责护送。

脚步声使用独立的轻声通道，音量比原音效通道低 12 dB，并削弱尖锐噪声；落脚与步行姿势每 56 个世界像素同步一次。攻击移动时优先播放武器声音，扬尘也更轻。暂停中可单独关闭「脚步声」，仍能听到战斗反馈；「静音」立即停止当前声音。开关在本次游戏会话中生效。

## 第一章

1. 溃军山道：三组教学遭遇、可引爆油车、营火。
2. 荒村小巷：清开主路；可选择去西巷救出医者与三名百姓。
3. 破庙夺剑：夏侯恩单挑，夺得青釭，打开返回荒村的侧门。
4. 井畔旧宅：抱起阿斗；请医者施救并击退两波追兵，或先撤离。入北桥前仍可回头救人。
5. 粮道岔口：可挑战盾阵校尉，再次互动焚粮，撤走北桥弓阵并打开侧道。
6. 北桥决战：随军掩护桥头，赵云单挑张郃；渡桥重逢，保存长坂战报。

营火、区域入口、敌将和营救入口记录落脚点。失败后重置当前战斗，保留已完成的遭遇、救援与夺剑。通关战报可以回标题重看。保存采用临时文件写入后替换，损坏存档不阻止新游戏；保存失败时保留当前会话进度并显示提示。

## Godot 的结构

- `scenes/main.tscn`：游戏入口。
- `scenes/hero.tscn`、`scenes/enemy.tscn`：原生 `CharacterBody2D` 与地面碰撞形状。
- `scripts/hero.gd`、`enemy.gd`、`companion.gd`：动作阶段、闪避、敌人连招、盾防与军令。
- `scripts/actor_visual.gd`、`frame_texture.gd`：八方向动作、统一头部比例与脚底锚点；重叠图集以原生绘制几何排除邻帧枪尖和衣角。
- `scripts/terrain.gd`、`scenery.gd`：原生地形碰撞、Godot AStarGrid2D 绕障碍路径、烘焙地表与共用景物图集。
- `assets/maps/`：六张 1600 × 1100 地表、33 种景物及脚底坐标；树木、岩石和建筑仍按原位置遮挡人物。剧情会改变的路障和油车单独绘制。
- `scripts/effects.gd`、`sound.gd`：战斗预警、枪芒、受击火花、残影、局部音效。
- `scripts/world.gd`、`campaign.gd`：第一章剧情、任务条件、进度与战报。
- `scripts/interface.gd`、`map_view.gd`：原生中文界面、暂停、军图和战斗状态。
- `data/chapter1.json`：从现有 `stages.js` 复用的关卡及招式参数。
- `export_presets.cfg`：Windows 单文件与单线程 Web 导出设置。

角色原 PNG 未修改。赵云各方向仍使用现有两帧步行和蓄势 / 出枪素材，敌军主要使用单帧配合动作位移；迁移不会自动生成更多连续动作。后续画面打磨应优先补敌军逐帧动作、赵云更丰富的步行帧、建筑素材与音乐。

## 构建和验证

安装 Godot 4.7.2 与同版本官方导出模板（编辑器「编辑器 → 管理导出模板」）。以下命令从仓库根目录执行，假定 `godot` 已在 PATH 中；也可把 `godot` 换成本机引擎的完整路径，在 PowerShell 中用 `& "引擎路径"` 调用。

```powershell
godot --headless --path godot --editor --import --quit
godot --headless --path godot --script res://tests/verify.gd
godot --headless --path godot --script res://tests/audio_verify.gd
godot --headless --path godot --script res://tests/map_verify.gd
godot --headless --path godot --script res://tests/map_view_verify.gd
New-Item -ItemType Directory -Force builds/windows, godot-play | Out-Null
godot --headless --path godot --export-release "Windows Desktop"
godot --headless --path godot --export-release "Web"
```

Windows 可用根目录 `Run-Checks.ps1` 一次执行导入与四组回归：`./Run-Checks.ps1 -Engine "引擎可执行文件路径"`。`-Engine` 省略时先读取环境变量 `GODOT_EXE`，再寻找 PATH 中的 `godot` / `godot4`。检查输出写入 `.qa/`，缓存与存档使用 `.qa/runtime/`，仅修改当前进程的环境变量。两个 `.cmd` 启动器也支持把引擎路径作为第一个参数，或使用 `GODOT_EXE` / PATH。

输出目录为仓库的 `builds/windows/` 与 `godot-play/`。`builds/`、`.godot/`、`.qa/`、日志和本机引擎不入库。`godot-play/` 是已跟踪的 Web 导出，修改 Godot 游戏后须重新导出并与源码一起提交。现有 GitHub Pages 从 `main` 分支的仓库根目录自动发布，Pages 流程不会替你运行测试或导出 Godot；根目录的 Canvas 入口继续保留，Godot 入口为 `/godot-play/`。

检查 Web 导出时，在仓库根目录执行 `python -m http.server 8767 --bind 127.0.0.1`，然后用浏览器打开 `http://127.0.0.1:8767/godot-play/`；不要直接双击 Web 导出的 HTML 文件。

自动检查运行真实 Godot 节点与物理空间，覆盖：八方向动作 / 脚底与比例、邻帧枪尖排除且保留真实枪头、蓄势 / 出枪 / 收招期间脚底与阴影不分离、真实命中时段、跨帧服药、服药打断、动作缓冲与闪避取消、精准闪避、鼠标释放与暂停清理、盾防反击、随军输出上限、绕建筑路径、两波营救、两位敌将、焚粮部署、木桥通路、三种命运、战报回读、无效存档和保存失败回退。测试使用独立存档，不会替换玩家进度。在仓库根目录用 `godot --path godot res://tests/pose_preview.tscn` 可核对八方向的站立、行走、蓄势和出枪，预览不读取或写入存档。

关卡和参数同步工具为 `tools/sync_data.mjs`；原始图集元数据读取工具为 `tools/prepare_assets.py`（Pillow / NumPy）。提交内已包含可直接运行的图集与元数据，平时开发无需运行这些工具。

中文字体为 Noto Sans SC 的游戏字符子集，已按 OFL 更名为 Longdan Game Sans；许可见 `assets/fonts/LICENSE.txt`。新增中文对白后需运行 `tools/subset_font.py` 重建字符子集（fonttools，首次从官方来源下载原字体并缓存）。Godot 与第三方组件许可见 `assets/licenses/`。

## 地图与性能

静态草叶、路边碎石、树荫、屋基和河面已离线烘焙；树木、岩石、房屋共用一张 1920 × 1920 图集。运行时无需重画数千个细碎图形。图集裁掉透明边距并保留脚底锚点，碰撞与寻路仍使用原始地形。更改矢量地图绘制后，可用带图形渲染的 Godot 重建：

```powershell
# 在仓库根目录运行。
godot --path godot --script res://tools/bake_maps.gd
godot --headless --path godot --editor --import --quit
godot --path godot --script res://tests/performance.gd -- --label=my-computer
```

性能检查使用 1280 × 720、关闭垂直同步的真实图形渲染，分别采样山道、荒村和北桥战斗。不会写入玩家存档；每台电脑应以自己的测试结果为准。Web 版将渲染倍率限制为最多 1.5，最长边最多 1920 像素，降低高分屏负担；窗口和全屏大小改变后保持鼠标位置对应。开发者可用 `?profile=1` 试玩，开战六秒后在浏览器控制台读取一次实际帧耗时报告，普通游玩不启用监测。

## 第二章设计

用户已选定「汉水孤营」，核心是接应黄忠、发布军令、大开营门与擂鼓反击。完整地图、敌人与督军招式、支线、存档兼容和开发顺序见 [第二章设计稿](../docs/CHAPTER-2-HANSHUI.md)。当前正式试玩仍为第一章，第二章尚未加入游戏。
