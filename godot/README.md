# 龙胆：逆命三国 · Godot 电脑版

0.5.0（2026-10-23）把可追溯的绘画环境原图接入十二个区域：原图由内置 `image_gen` 生成，提示词和源像素保留，材质/景物离线烘焙后进入正常运行贴图。四件旧地标保留尺寸、脚底与碰撞元数据，门楼/井使用独立四帧图集。完整流程见 [PAINTED-ENVIRONMENT.md](../docs/PAINTED-ENVIRONMENT.md)，当前画面见 [0.5.0 六区原生实机图](../docs/images/map-materials-0.5.0.jpg)。本轮二十二组源码回归 **42,815 项断言、0 失败**（`.qa/painted-full-checks.log`），旧地图基线 **1,107 项、0 失败**（`.qa/painted-map-identity.log`），正常镜头 **17 张原生截图、0 捕获失败**（`.qa/painted-release-preview.log`）；Windows/Web 导出及 PCK 验证已通过，本地网页已验证两章入口与基本操作；线上发布结果见开发记录。
历史 0.4.0（2026-10-22）确立十二个区域的道路、土质、树种和建筑身份，二十一组回归 42,697 项、地图基线 1,107 项及十七张镜头检查是该版结果。不要沿用为 0.5.0 成绩；各轮图形、性能、导出与发布结果见 [开发记录](../CLOUD-POLISH.md)。
0.3.1 的首玩提示、营火引导、敌人状态反馈和黄忠援射，以及此前的枪势、战法和护车玩法继续保留。地图逐区构图、制作约束与重建方式见 [地图美术规范](../docs/MAP-ART-DIRECTION.md)；玩法设计见 [PLAYABILITY-PLAN.md](../docs/PLAYABILITY-PLAN.md)。
可编辑布局见 `data/map_details.json` 与 `data/chapter2.json`，双章巡游入口为 `../Map-Tour.cmd`。正式构建沿用原有 Godot 存档目录；此前单独交付的本地地图预览包使用 `LongdanMapPolishPreview`。

宣传副标题：**重生之我在三国当赵子龙**。Godot 4.7.2 / GDScript 的原生 2D 动作冒险，含第一章「长坂逆命」与第二章「汉水孤营」，各有六个区域。仓库只保留这一套 Godot 游戏，在线版与 Windows 本地版共用游戏内容与开发源。

## 直接试玩

- 默认在线首页 <https://cy642.github.io/longdan-game/> 会进入 <https://cy642.github.io/longdan-game/godot-play/>，跳转保留参数/片段。在线版与 Windows 版从同一 Godot 工程导出；加载页点击「开始游戏」，使用电脑 Chrome、Edge 或 Firefox，首次需要下载引擎与素材。
- 本地导出后可双击 `../builds/windows/Longdan.exe`，运行此程序无需安装 Godot、Python 或联网；Windows 构建包不纳入源码仓库。
- 打开工程：在 Godot 4.7.2 中导入本目录的 `project.godot`，按 F5 运行。
- 标题可选择任一章、普通/剧情难度，开始或继续所选章节；另一章进度会保留。查看战报也按当前选择的章节读取。
- 快速巡览：打开 `tests/map_tour.tscn` 后按 F6，或在 Windows 使用根目录 `Map-Tour.cmd`；Tab 切章、F1–F6 切换该章六区，WASD / 方向键移动，M 打开军图。巡览不读取或写入玩家存档。
- Windows 版和浏览器版分别保存进度，不跨设备或浏览器自动同步。

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
| 黄忠援射 | 北山接应战靠近黄忠按 3；与冲阵军令同时请求，冷却 6 秒 |
| 军图 / 暂停 / 全屏 | M / Esc / F11 |

键盘出枪优先锁住近处敌人，鼠标出枪跟随指向。攻击只有实际命中时段产生伤害，同一次动作对同一目标只命中一次。动作尾段支持 0.14 秒短按缓冲；普攻与技能收招可用闪避取消，实际出枪时段不能提前取消。

左下角三格「枪势」：第三枪真实命中或精准闪避各积一格，满三格的下一次 Q 自动消耗，攻击范围 ×1.18、破势 ×1.6，基本伤害不增加。受击掉一格，休整/死亡/切图清空。营火 E 可选「连锋」（第三枪积两格）或「游龙」（精准闪避积两格，回马枪首次命中回 12 气），免费更换且按章保存。选择期间暂停战斗，Esc 可退出。普兵轻击被打断后 0.65 秒防重复轻击打断，仍受伤且继续原有预警；Q/R/破势仍可打断。

入区提示只在正常游玩时计时，读对白、打开暂停/军图/营火不会把它耗尽。第一次清开山道后，未选战法且未休整过的玩家会被金标引向营火；访问过或已有战法后改指出口，主线出口始终可自由选择。营火首次把键盘焦点放在「连锋」，已有战法时优先「继续前行」；保持基础枪法同样能继续。

闪避和横扫按钮显示冷却或缺气；满枪势时若 Q 仍缺气/冷却，会提示保留枪势。过早或资源不足的技能输入给出原因，0.75 秒内限流，正常 0.14 秒缓冲仍可接招，不会提前扣气。敌人头顶细势条显示破势积累，「稳势」表示轻击仍伤血但不能反复中断；「破势」和整套连招后的收招提示对应真实窗口，连招中途不会提前叫玩家反击。

敌人起手红区与真实命中范围一致，前段跟踪、后段锁定。弓箭和冲枪以线段 / 连续位移判定，避免跨帧穿过障碍。完整盾防的正面普通攻击保留盾兵反击，横扫、绕后或破势可创造开口。夏侯恩双剑与张郃三连突需等整套连招收完；张郃半血变招。

第一章随军只在井畔营救和桥头突围参与战斗，第二章跟随护车并可在青旗守点藏兵。单人 3.5 伤害 / 1.8 秒，最多将敌人体力压到 22%，赵云需要亲自完成击杀。正式单挑中随军负责护送。

脚步声使用独立的轻声通道，音量比原音效通道低 12 dB，并削弱尖锐噪声；落脚与步行姿势每 56 个世界像素同步一次。攻击移动时优先播放武器声音，扬尘也更轻。暂停中可单独关闭「脚步声」，仍能听到战斗反馈；「静音」立即停止当前声音。开关在本次游戏会话中生效。

## 第一章

1. 溃军山道：三组教学遭遇、可引爆油车、营火。
2. 荒村小巷：清开主路；可选择去西巷救出医者与三名百姓。
3. 破庙夺剑：夏侯恩单挑，夺得青釭，打开返回荒村的侧门。
4. 井畔旧宅：抱起阿斗；请医者施救并击退两波追兵，或先撤离。入北桥前仍可回头救人。
5. 粮道岔口：可挑战盾阵校尉，再次互动焚粮，撤走北桥弓阵并打开侧道。
6. 北桥决战：随军掩护桥头，赵云单挑张郃；渡桥重逢，保存长坂战报。

营火、区域入口、敌将和营救入口记录落脚点。失败后重置当前战斗，保留已完成的遭遇、救援、夺剑与战法。第一章战报首按钮「继续征程 · 汉水孤营」直接续入第二章；首次进入继承难度和战法，已有进度恢复原检查点，已完成则打开汉水战报。长坂战报仍可从标题重看。保存采用临时文件写入后替换；保存失败时保留当前会话进度并显示提示。

## 第二章：汉水孤营

六区按「汉水林道 → 北山粮道 → 乱石归途 → 孤营大门 → 河湾反击 → 铁营决战」推进。林道对付斥候与弩兵，粮道接应黄忠，归途护送耐久 160 的粮车；可提前靠近下一路障清敌，车沿已清路段跟上。车速 112，赵云在前方时渐进追至 164，护送范围 520；附近有敌或离队仍停。目标提示解释停止原因。车毁可从最近通过的路障重试；停滞时可用 E 按提示复位到安全路点。

北山主线围军未清、黄忠尚未接应时，赵云在黄忠 520 范围内按 3 可请求援射。目标须在赵云 360、黄忠 560 范围内且箭路通畅；黄忠拉弓 0.28 秒后发出一箭，6 秒冷却，锁定方向后不追踪敌人。援箭沿实际路径碰撞，基础伤害 10、破势 24，遵守友军的 22% 体力下限；非正面盾挡的有效命中可留下 0.32 秒切入机会。HUD 会说明冷却、距离、遮挡和围军已退。主路清开后靠近按 E 接应，援射结束；正式 Boss 战、支线和其他地图不提供此技能。它是玩家指令下的局部协作机制，尚非完整自主伙伴 AI。

孤营青旗旁按 2，把三名随军送至藏兵守点，然后 E 开营门；赵云击退两次试探，敌军才会撤退。退军到位后的金色战机为 4 秒，鼓台 E 触发一次齐射；迟到也可普通齐射或直接追击。突破营门只追加一次有限补救队，不会无限刷兵；暂停、军图与对白不会消耗擂鼓时机。进入河湾的退军保留原有生命和伤亡，不会复制一队满血敌人。

北山可焚毁火箭辎重，乱石归途西侧可救回张著与伤兵；支线改变后续压力、补给和战报。进入督军决战前会提示仍可回头整备。铁面督军有窄线钩拉、迟势回斧、扇区砸地及半血冲斩；新弩兵两发后才装填，第二箭使用原先锁定的方向。

完成空营计并通关解锁「龙胆·回澜」，重玩第二章后可在暂停页切换 Q 招式；奖励写入跨章节存档，第一章数值不随之变化。第二章默认拥有青釭，仍须积满战意使用 R。

### 双章存档

`user://longdan-godot-v2.json` 保存两章独立检查点、已清遭遇、支线、计策、退军名册、战法与战报，以及已解锁奖励。`battle_art` 是可选新字段，缺失时使用基础枪法，未知值拒绝读入。瞬时枪势不入档。重开所选章节保留另一章记录。有效旧 `user://longdan-godot-v1.json` 只作为第一章旧进度读入，新保存写入 v2；旧文件保留，不删除、不覆盖。Windows 与 Web 存档互不自动同步。

本轮不提升存档版本；营火访问标记追加到原有 `seen` 数组（例如 `camp:mountain`），保留旧剧情记录。玩家选择保留基础枪法后，读档不会再次被引导回已访问的营火。黄忠援射的拉弓、飞箭和冷却属于本次遭遇运行状态，不添加永久奖励或新章节存档字段。

## Godot 的结构

- `scenes/main.tscn`：游戏入口。
- `scenes/hero.tscn`、`scenes/enemy.tscn`：原生 `CharacterBody2D` 与地面碰撞形状。
- `scripts/hero.gd`、`enemy.gd`、`companion.gd`：动作阶段、闪避、敌人连招、盾防与军令。
- `scripts/actor_visual.gd`、`frame_texture.gd`：赵云八方向动作、固定模型比例与脚底锚点；`data/atlas.json` 的 `model_scale` 为整套原画的像素密度校准，walk/attack 共用 0.34，旧 hero 倒地原画为 0.29。不要再用逐帧头发色块高度或含长枪的包围盒自动归一化。原画网格保持敌人脸和武器刚性，重叠图集通过绘制几何排除邻帧碎片。
- `scripts/terrain.gd`、`scenery.gd`：原生地形碰撞、Godot AStarGrid2D 绕障碍路径、烘焙地表与共用景物图集。
- `scripts/hanshui_layout.gd`：第二章六区共用的美术、地形与碰撞布局；动态营门开合与路径更新由 `terrain.gd` 提供。
- `scripts/painted_ground.gd`、`painted_props.gd`：仅在制作阶段读取环境原图并绘制材质/连通区域抽帧；正式运行使用烘焙结果。
- `assets/maps/`：两章各六张 1600 × 1100 地表，以及共用景物图集、第二章景物图集和脚底坐标。树木、岩石和建筑仍按原位置遮挡人物，动态路障单独绘制。
- `assets/props/`：四件旧地标的新绘画像素及原契约清单，另含 `painted_markers.png/json` 的三种门楼跨度与井架。
- `scripts/effects.gd`、`sound.gd`：战斗预警、枪芒、受击火花、残影、局部音效。
- `scripts/world.gd`、`campaign.gd`：章节入口、剧情、目标、v2 独立进度、旧 v1 兼容、战报和奖励。
- `scripts/tactic_director.gd`：第二章有限波次/存活上限、藏兵与门前试探、退军名册、擂鼓结果及稳定恢复阶段。
- `scripts/huangzhong_support.gd`：北山玩家军令援射、候选目标、锁向单箭、碰撞和冷却；由战术调度创建、推进与取消。
- `scripts/grain_cart.gd`：粮车原生碰撞、耐久与受击；路线和停靠由战术调度控制。
- `scripts/interactable.gd`：营火、出入口、黄忠/伤兵、火箭辎重、藏兵旗、门扇和鼓台实物；粮车提示跟随车移动。
- `scripts/interface.gd`、`map_view.gd`：原生中文界面、暂停、军图和战斗状态。
- `data/chapter1.json`：第一章关卡与招式参数的唯一数据源，直接编辑；不再从外部 JavaScript 同步。
- `data/chapter2.json`：汉水六区的路网、实体、支线、波次、计策坐标与初始调参。
- `export_presets.cfg`：Windows 单文件与单线程 Web 导出设置。

角色原 PNG 未修改。赵云沿用每方向两帧步行和蓄势/出枪，敌军使用现有原画与连续网格姿态；第二章装备是刚性代码配件，不是新手绘逐帧图集。弩手底图没有旧弓，独立弩身、弦和弩箭随上身瞄准；两次可见后坐对应两次发射，装填不会再次出箭。头脸与武器不做拉伸。后续仍需补敌人独立动作素材、赵云步行帧、黄忠战斗/剧情演出和完整音乐。

## 构建和验证

安装 Godot 4.7.2 与同版本官方导出模板（编辑器「编辑器 → 管理导出模板」）。以下命令从仓库根目录执行，假定 `godot` 已在 PATH 中；也可把 `godot` 换成本机引擎的完整路径，在 PowerShell 中用 `& "引擎路径"` 调用。

```powershell
godot --headless --path godot --editor --import --quit
godot --headless --path godot --script res://tests/verify.gd
godot --headless --path godot --script res://tests/hero_scale_verify.gd
godot --headless --path godot --script res://tests/audio_verify.gd
godot --headless --path godot --script res://tests/map_verify.gd
godot --headless --path godot --script res://tests/map_view_verify.gd
godot --headless --path godot --script res://tests/atmosphere_verify.gd
godot --headless --path godot --script res://tests/theme_atmosphere_verify.gd
godot --headless --path godot --script res://tests/enemy_animation_verify.gd
godot --headless --path godot --script res://tests/hanshui_layout_verify.gd
godot --headless --path godot --script res://tests/hanshui_world_layout_verify.gd
godot --headless --path godot --script res://tests/hanshui_enemy_verify.gd
godot --headless --path godot --script res://tests/hanshui_visual_verify.gd
godot --headless --path godot --script res://tests/hanshui_flow_verify.gd
godot --headless --path godot --script res://tests/combat_loop_verify.gd
godot --headless --path godot --script res://tests/battle_art_verify.gd
godot --headless --path godot --script res://tests/hanshui_pacing_verify.gd
godot --headless --path godot --script res://tests/chapter_progression_verify.gd
godot --headless --path godot --script res://tests/first_minutes_verify.gd
godot --headless --path godot --script res://tests/combat_clarity_verify.gd
godot --headless --path godot --script res://tests/huangzhong_support_verify.gd
godot --headless --path godot --script res://tests/scenery_occlusion_verify.gd
godot --headless --path godot --script res://tests/painted_assets_verify.gd
New-Item -ItemType Directory -Force builds/windows, godot-play | Out-Null
godot --headless --path godot --export-release "Windows Desktop"
godot --headless --path godot --export-release "Web"
```

Windows 可用根目录 `Run-Checks.ps1` 一次执行导入与二十二组回归：`./Run-Checks.ps1 -Engine "引擎可执行文件路径"`；Linux/macOS 可运行 `./Run-Checks.sh /path/to/godot`。0.5.0 新增可独立对导出包运行的 `painted_assets_verify`；0.4.0 的 `scenery_occlusion_verify` 和此前首玩/战斗/护车/章节衔接专项继续保留。`-Engine` 省略时先读取环境变量 `GODOT_EXE`，再寻找 PATH 中的 `godot` / `godot4`。检查输出写入 `.qa/`，缓存与存档使用 `.qa/runtime/`，仅修改当前进程的环境变量。两个 `.cmd` 启动器也支持把引擎路径作为第一个参数，或使用 `GODOT_EXE` / PATH。

输出目录为仓库的 `builds/windows/` 与 `godot-play/`。`builds/`、`.godot/`、`.qa/`、日志和本机引擎不入库。`godot-play/` 是已跟踪的 Web 导出，修改 Godot 游戏后须重新导出并与源码一起提交。现有 GitHub Pages 从 `main` 分支的仓库根目录自动发布，Pages 流程不会替你运行测试或导出 Godot。根 `index.html` 跳转至 `./godot-play/`，加载页统一显示「开始游戏」。仓库已移除旧 Canvas 页面、脚本和构建工具，只保留 Godot 游戏。

`painted_assets_verify.gd` 不读取原画或本机基线，可从项目外针对实际 PCK 检查所有运行资产。导出完成后执行（脚本路径须为本机绝对路径）：

```powershell
godot --headless --main-pack godot-play/index.pck --script "D:/gpt/longdan-game/godot/tests/painted_assets_verify.gd"
python godot/tools/verify_export_pack.py
```

专项验证十二个真实区域均使用缓存贴图、四件旧地标契约和四帧门楼/井图集；制作侧加载标志始终未触发。PCK 检查还要求 marker 图集、JSON 及其实际导入载荷存在，并继续禁止导出原画、工具与测试。资产检查不判断画面美感，地图坐标仍需单独基线比对。

检查 Web 导出时，在仓库根目录执行 `python -m http.server 8767 --bind 127.0.0.1`，然后用浏览器打开 `http://127.0.0.1:8767/godot-play/`；不要直接双击 Web 导出的 HTML 文件。

自动检查运行真实 Godot 节点与物理空间，覆盖：八方向动作 / 脚底与比例、邻帧枪尖排除且保留真实枪头、蓄势 / 出枪 / 收招期间脚底与阴影不分离、真实命中时段、跨帧服药、服药打断、动作缓冲与闪避取消、精准闪避、鼠标释放与暂停清理、盾防反击、随军输出上限、绕建筑路径、两波营救、两位敌将、焚粮部署、木桥通路、三种命运、战报回读、无效存档和保存失败回退。测试使用独立存档，不会替换玩家进度。在仓库根目录用 `godot --path godot res://tests/pose_preview.tscn` 可核对八方向的站立、行走、蓄势和出枪，预览不读取或写入存档。

第二章五套检查分别覆盖真实地图可达/碰撞与营门开合、原生世界转场，新敌兵和督军的跨帧命中/双发锁向，新造型的四方向姿态/脸部刚性/装备握点，以及主线/支线/粮车/计策/存档恢复。流程回归会加速击败遭遇以验证状态推进，不代表人工通关、难度合适或达到目标游玩时长。

原生图形验收单独运行，不能加 `--headless`：

```powershell
godot --path godot --script res://tests/hanshui_visual_verify.gd -- --capture
godot --path godot --script res://tests/hero_pose_capture.gd
godot --path godot --script res://tests/map_identity_preview.gd -- --label=review-001
godot --path godot --script res://tests/playability_preview.gd
godot --path godot res://tests/hanshui_playtest.tscn -- --qa-stage=hs_camp
godot --path godot --script res://tests/hanshui_performance.gd
```

截图入口保存 `.qa/hanshui-visuals.png`，实际渲染新敌人动作与交互实体；`hero_pose_capture.gd` 输出八方向六状态联系表。地图正常镜头优先使用 `map_identity_preview.gd`：它输出十二个区域和五个实战状态共十七张 1280 × 720、镜头倍率 1.15 的 `.qa/map-identity-标签-场景.png`，并写入同标签的 manifest。五个状态包含北山黄忠援射可用、孤营关门、乱石护车，以及夏侯恩与督军蓄势。预览采用内存进度，不读取或写入玩家存档；同名标签存在时拒绝覆盖，复拍须使用新标签。旧 `theme_preview.gd` 保留供历史截图复核，不作为 0.4.0 的主要巡图证据。开发试玩使用隔离测试进度打开指定汉水区域；性能入口采样 8 敌/3 随军、营门、退军河湾和督军二阶段，输出 `.qa/hanshui-performance.json`。人工检查要记录设备、分辨率、难度和耗时；无界面检查不能代替画面、声音或性能验收。

第一章关卡与招式参数直接维护 `data/chapter1.json`，第二章直接维护 `data/chapter2.json`，不再保留旧 JavaScript 同步管线。角色原图只保存在 `assets/`；`tools/prepare_assets.py`（Pillow / NumPy）直接读取这些 PNG，重建 `data/atlas.json` 的锚点、裁切和固定比例，不复制或修改原图。提交内已包含可直接运行的图集与元数据，日常开发无需重建。运行 `python godot/tools/prepare_assets.py --check` 可只核对清单是否与原图一致；不加 `--check` 时重建清单。原图来源和完整提示词见 [角色素材说明](art_source/characters/ART-NOTES.md) 与 [八方向出枪说明](art_source/characters/ATTACK-V3-NOTES.md)。

中文字体为 Noto Sans SC 的游戏字符子集，已按 OFL 更名为 Longdan Game Sans；许可见 `assets/fonts/LICENSE.txt`。新增中文对白后需运行 `tools/subset_font.py` 重建字符子集（fonttools，首次从官方来源下载原字体并缓存）。Godot 与第三方组件许可见 `assets/licenses/`。

## 地图与性能

`terrain_materials.gd` 保留十二个区域的土色、路宽、树种和植被密度。0.5.0 的 `painted_ground.gd` 在离线烘焙时将六种原画材质混入这些既有地表；`painted_props.gd` 从透明原图的指定种子点抽取连通物件，按脚底和占地宽重绘景物图集。`scenery_styles.gd` 留作旧轮廓和未覆盖物件的后备。第一章叙事笔触在 `map_details.gd`，第二章在 `hanshui_layout.gd`。制作要求见 [MAP-ART-DIRECTION.md](../docs/MAP-ART-DIRECTION.md)，原图及重建步骤见 [PAINTED-ENVIRONMENT.md](../docs/PAINTED-ENVIRONMENT.md)。`map_atmosphere.gd` 的有限水光与叶片在游玩时以 24 Hz 更新；正常镜头保持 1.15。

十二个区域各有一张 1600 × 1100 静态地表；景物、汉水道具、门楼/井分别使用正式图集与脚底清单。当前图集尺寸和帧坐标以 `assets/maps/`、`assets/props/painted_markers.json` 为准。原图和最终生成提示词保留在 `art_source/painted/`，源 PNG 保持原始生成像素；正式游戏不加载该目录。美术绘画与实体、交互和剧情坐标分离，通路及旧存档格式沿用，仍须用下方的本地基线对照验证。修改原画、抽帧清单或绘画代码后，按以下顺序重建：

```powershell
# 在仓库根目录运行。
godot --path godot --script res://tools/bake_painted_landmarks.gd
godot --headless --path godot --editor --import --quit
godot --path godot --script res://tools/bake_maps.gd
godot --path godot --script res://tests/hanshui_layout_verify.gd -- --bake
godot --headless --path godot --editor --import --quit
godot --path godot --script res://tests/performance.gd -- --label=my-computer
```

先生成四件地标和四帧 marker，立即导入新地标贴图，再生成第一章地表/共享景物，接着生成第二章地表/汉水图集，最后再次导入。中间导入确保后续地图烘焙读取新地标。不要只修补导出的 PNG；也不要把旧 Blender 再生脚本的输出当作当前绘画资产。`.qa/` 是本机忽略目录，**基线不随 Git 提交**；在干净克隆中，准备下一次地图美术修改时，先在修改前运行下列第一、第二条，保留源状态与正常镜头截图；修改并重烘焙后再运行后两条作对照。基线文件已存在时脚本拒绝覆盖，若开始另一轮对比，应保留旧证据并另建独立本地工作目录。

```powershell
godot --headless --path godot --script res://tests/map_identity_verify.gd -- --write-baseline
godot --path godot --script res://tests/map_identity_preview.gd -- --label=before
# 完成可编辑源修改、双章重烘焙和导入后：
godot --headless --path godot --script res://tests/map_identity_verify.gd
godot --path godot --script res://tests/map_identity_preview.gd -- --label=after
```

`map_identity_verify.gd` 对照原坐标、物理形状、寻路网格、交互物、真实移动路径和贴图契约；它不能判断美术是否好看。`map_identity_preview.gd` 的十七张图需要人工逐张确认区域辨识、关键角色遮挡、任务提示与战斗预警。旧存档通行和性能、导出、线上画面仍需独立验收。

性能检查使用 1280 × 720、关闭垂直同步的真实图形渲染，分别采样山道、荒村和北桥战斗。不会写入玩家存档；每台电脑应以自己的测试结果为准。Web 版将渲染倍率限制为最多 1.5，最长边最多 1920 像素，降低高分屏负担；窗口和全屏大小改变后保持鼠标位置对应。开发者可用 `?profile=1` 试玩，开战六秒后在浏览器控制台读取一次实际帧耗时报告，普通游玩不启用监测。

## 后续开发与已知待打磨

完整设计与本轮实现对照见 [第二章设计稿](../docs/CHAPTER-2-HANSHUI.md)，坐标与状态机交接见 [实施方案](../docs/CHAPTER-2-PLAYABLE-PLAN.md)。下一轮先在普通难度完整实玩，校准等车、绕路、藏兵到鼓台的节奏与督军反击窗口；25–35 分钟仍是设计目标，不是实测结果。

黄忠已有北山军令援射与拉弓表现，但自主移动/持续战斗 AI、三幕正式过场尚未制作；角色配件与剧情镜头仍需美术统一，完整环境音/音乐未完成。修改地图后重烘焙，新增中文后补齐字体，再导入和导出。浏览器实际帧耗时、长时间稳定性和音频听感需要独立实测；第一章过去的 WebGL 警告和软件渲染数据不得当作本轮已解决或已达标。
