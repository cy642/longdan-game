# 开发交接 · 四章与 0.8.0 陈仓夜袭

## 最新进度 · 2026-10-26

0.8.0 已完成第四章「陈仓夜袭」的代码接入：四章 24 区、24 种独立兵卒与 5 位将领，共 29 档案、六张敌军图集。前三章战报依次续入下一章，第四章为当前终章。完整规划见 [陈仓设计稿](CHAPTER-4-CHENCANG.md)，当前参数见 [难度曲线](DIFFICULTY-CURVE.md)。陈仓夜袭、调令/工匠事件与镇关都尉为本作架空演绎，不能写成赵云参与该战事的史实复现。

**当前处于发布验收阶段。** 34 组源码回归已通过，地图收尾后完成最终 16 张截图、原生短样本、Windows 启动/ZIP 完整性、实际 Web PCK 验证和浏览器基本操作。可见预览采样仍有约一秒长间隔，未获得有效前台帧率基准；线上包指纹待补。下方 0.7.0/0.6.0 已上线记录属于历史，不可据此宣称 0.8.0 已部署或完整人工通关。

### 后续开发先读

| 领域 | 当前权威文件与合同 |
|---|---|
| 四章进度 | `godot/scripts/campaign.gd` / `world.gd` / `interface.gd`；仍用 v2，每章记录独立。三到四章首次承接难度、战法、回澜；已有第四章检查点或战报原样恢复，重玩第四章不改前三章。旧 v1/两章与三章 v2 缺少新章字段时保守补全。 |
| 难度递进 | `godot/scripts/combat_pacing.gd`；24 区普通敌人整套起手共用间隔 0.90→0.26 秒，剧情额外 +0.20；整套结束休息剧情 +0.12。Boss 不占普通起手名额；连段内部不加等待。旧敌兵/首领 HP、伤害、招式窗口、锁向、闪避与原攻击人数限制未提高。 |
| 陈仓关卡 | `godot/data/chapter4.json`；`cc_outer → cc_beacon → cc_street → cc_store → cc_bastion → cc_final`。共 15 个固定敌群，未选进路不出兵，不以未生成判清场。 |
| 队列与军令 | `godot/scripts/chencang_director.gd` 继承 JiguDirector 的有限队列，独立处理陈仓任务/路线/支线；上限 8 活敌，来向预警至少 1.2 秒。`cart=null`、隐藏援射，不启用汉水护车。 |
| 两线与两支线 | 正门一战 3 人，侧巷两战各 2 人；分别减瓮城一名重盾/弩兵。调令只取消未到援军，实际到场后 `cc_reserve_called` 留档，补支线不能抹兵。工匠侧门还需仓院主路完成，安全落脚 `(1360,890)`；正常出口 `(220,900)` 仍可用，两波主战斗不跳过。 |
| 烽台箭阵 | 最多 3 轮、每轮至多 2 条真实箭路，至少 1.25 秒锁向预警，与普通弩兵互斥。熄烽清未发射，已发箭保留实际碰撞；暂停、对白、军图、营火、死亡冻结，重试清瞬时队列。 |
| 决战 | `boss_id=warden`，普通 HP 1500、破势 145，双手长柄重锤。落锤/横扫/圆形重落/半血两段回锤，圆形红区对应圆形命中。E 挑战可取消；仅 `warden:commit` 确认后写 `cc_committed` 并锁回访。击败写 `cc_boss`，再真实 E 收旗才出战报。 |
| 新敌军 | `enemy_roster.gd`、`data/enemy_atlas.json` 和 `art_source/characters/enemy-calibration.json`；新增 `enemy_chencang` 六帧和 `enemy_warden` 一帧。原图见 `assets/enemies/chencang-v1.png` / `warden-v1.png`。完整兵器绘入原画，旧装备附件为空；保持既有脚锚/刚性/连续性阈值。 |
| 夜城地图 | `chencang_layout.gd`、`terrain_materials.gd`、`painted_ground.gd` 与 `chapter4.json`；六张独立地表、`chencang_props.png/json` 六种建筑原画。源图/标定在 `art_source/painted/chencang-*`，只在离线烘焙时读取。 |

陈仓存档旗标为 `cc_breach, cc_beacon_out, cc_orders, cc_route_front, cc_route_flank, cc_street_done, cc_reserve_called, cc_warehouse, cc_workers, cc_courtyard, cc_committed, cc_boss`。路线互斥、主路顺序、决战确认与完成条件由 `Campaign.valid` 验证；不要用直接补旗标替代实际流程验收。

### 本轮证据与待完成项

| 验收项 | 当前证据 / 状态 |
|---|---|
| 34 组源码完整检查 | **89,667 项断言，0 失败、0 ERROR 行**；`.qa/chencang-full-first.log`。大量姿态/几何采样不是同数量独立场景。 |
| 新章流程/存档 | `chencang_flow_verify` 1574/0、`chencang_campaign_verify` 141/0；真实两线到战报、早晚调令、侧门、暂停/死亡、三到四章与旧档。 |
| 难度/地图/首领 | `combat_pacing_verify` 1369/0，`chencang_layout_verify` 完整回归 443/0、最终烘焙检查 487/0，`warden_enemy_verify` 282/0，`warden_visual_verify` 16939/0。 |
| 素材与实包 smoke | 源码和实际 PCK 均通过 29 档案 6571/0、24 区绘画资产 290/0、export_smoke；最终 33 个陈仓建筑，运行原图加载器未触发。 |
| 受控截图 | 最终 `.qa/chencang-release-manifest.json` 16 张、0 自动失败，覆盖六区/两路线/烽台/侧门/重锤；首轮构图问题及原截图保留。 |
| 原生短样本 | `.qa/chencang-performance-release.json` 三场有效，P95 帧间隔 1.502/1.679/1.090 ms；烽台实际发箭 2、都尉真实二阶段动作。first 报告作为改图前历史保留。监视器为每秒峰值口径，不能等同逐帧 P95，详见 [开发记录](../CLOUD-POLISH.md)。 |
| Windows/Web 正式构建 | EXE 165,925,296 字节，启动 90 帧退出 0；ZIP 94,207,889 字节、完整性通过；PCK 56,756,640 字节，187 资源/17 JSON，SHA-256 `B3EB4803C4C9258C76EDF1C73454E1B29043CD329A11E1AE292C6C90D951C4A4`。实包流程 1574/0；外部父测试路径修正前的解析失败保留。 |
| 浏览器与线上 | 实际加载四章菜单、选第四章进入剧情/入关/新敌兵，WASD/J 和 M 军图可见，控制台 warn/error 为 0。隐藏 IAB 的约 1 FPS 后台节流样本保留，不据此评价正常前台性能；可见预览也只取得 15 帧、含约一秒长间隔，日志保留，尚无有效长时前台性能结论；提交部署和线上 PCK 指纹待补。 |

### 改动后如何验证

- 源码：根目录 `Run-Checks.ps1` / `Run-Checks.sh` 已有 34 组；使用隔离 `.qa/runtime/`，保留首次失败与新前缀复核日志，不覆盖历史证据。
- 新章资源：先改 JSON/原图标定/绘制代码，再运行 `godot --path godot --script res://tools/bake_chencang.gd`，随后 `--headless --editor --import --quit`。不重跑最初数据生成脚本覆盖当前 JSON。
- 画面：`tests/chencang_preview.gd -- --label=新标签`，16 张受控场景，1280×720 / 1.15；根目录命令见 [Godot 说明](../godot/README.md)。GPU 任务串行，后台窗口隐藏。
- 性能：`tests/chencang_performance.gd -- --label=新标签`，`.8` 秒热身、`3.2` 秒采样，校验真实活敌/发箭/阶段。报告不覆盖旧标签，失败不能作为性能通过。
- 发布：修改代码或 Web shell 后重导出；新中文重建字体。`godot-play/` 必须与源码一起更新，Pages 不执行 Godot 构建。包验证要求 24 地表、四套景物、六敌军图集及真实导入载荷。导出版本与加载页当前文案为 0.8.0。
- Windows ZIP 指南生成脚本为本机忽略文件 `.qa/package_windows.py`，已更新为四章 0.8.0；它不属于跨机器构建前提，源码开发入口始终是导出预设。

下一轮需要完整普通难度实玩，尤其检查新手首战、后段攻击叠压、陈仓两线的选择价值和首领反击节奏；自动流程加速击杀、可控截图、短帧耗时样本均不能代替这些体验验证。

## 历史记录 · 0.7.0（2026-10-25）

0.7.0 已接入18种独立兵卒、4位独立将领，以及每帧人体、靴底和头/兵器刚性校准；旧代码装备附件删除。画像由 `enemy_roster.gd` 解析，元数据由 `tools/prepare_enemy_assets.py` 从4张新原图及 `art_source/characters/enemy-calibration.json` 重建。改原图后必须重新校准，不要简单等格裁切或用武器包围盒自动缩小身体。章节数据、伤害和存档规则没有改动。

功能 `3d1d05b` 已发布；2026-10-25 13:09:31 线上44,260,412字节PCK与本地SHA-256完全一致，见CLOUD-POLISH及 `.qa/enemy-redesign-live-20261025-050912.json`。工作收尾，后续从最新main继续；此前失败与图像证据保留在.qa。

本轮28组回归67077/0，最终弓弩姿态专项再验证通过；原生5张图鉴及29张实景采样、实际PCK的18区/22画像检查、Windows启动/ZIP和网页基本操作均已完成。范围及原始失败依据见 [最新发布记录](../CLOUD-POLISH.md)。敌军设计见 [规范](ENEMY-ART-DIRECTION.md)，后续更改须保留动作连续性阈值与实际脚底像素校验。下方0.6.0记录作为关卡逻辑的历史交接保留，不能当作0.7.0线上发布证据。

## 0.6.0 关卡实现交接

更新：2026-10-23。用户重启电脑后已恢复开发，第三章已完成实现、验收和发布，功能提交 `93f1db6`。本页说明当前代码、固定合同与验收入口；详细证据及验证范围见 [开发记录](../CLOUD-POLISH.md)。

## 目标与版本边界

用户要求先收尾第一、二章，再先规划、后实现第三章，并更新 README 与 GitHub。当前仅维护 Godot 4.7.2，一套工程导出 Windows 与 Web；网页入口为「开始游戏」，不恢复 Canvas 旧版或移动端。

本轮最初基线为 fb20b92，当时已发布功能为 d65f004。重启前后均以现有工作区继续开发，不从基线重新生成或覆盖文件。最终发布提交、线上包指纹须以本轮验收表为准，不能据上述历史 SHA 推断当前远端状态。

## 第一、二章收尾

- world.gd：井畔营救必须清完两波；快速清完后以 1.2 秒短收尾结束，避免治疗计时不足 20 秒时站着空等。
- tactic_director.gd：汉水退兵名单在实际出兵前建立并保存；等待安全入口不消耗退军窗口，预警期间出营不会吞掉追兵，延后出现者遵守已执行的反击/齐射结果。
- 新增或完善 first_minutes_verify.gd、hanshui_pacing_verify.gd。收尾专项先复现 308 项中的 8 个失败，修复后 308/0；第一关主流程 140/0，引导与救母 61/0，汉水流程 1625/0。这些是重启前专项结果，不能替代第三章集成后的全套发行检查。
- 原始证据位于 .qa/chapters-finish-{before,pacing,first-minutes,hanshui-flow,base-flow}.log，隔离存档为 .qa/runtime/chapters-finish。保留首轮失败证据。

## 第三章当前实现

[箕谷断后设计稿](CHAPTER-3-JIGU.md) 先于代码完成。第三章六区：jg_fog、jg_signal、jg_pass、jg_rearguard、jg_bridge、jg_final。具体撤军事件、桥头选择与「玄甲先锋」均为剧情演绎。

| 领域 | 当前代码与行为 |
|---|---|
| 主路与支线 | chapter3.json + jigu_director.gd：夺旗停箭阵、两次清路后主动撤军、石门两波、桥头双路线、最终单挑与战报。军报减少石门一名弩兵；辎重在最终营火提供一次额外行军药；留桥接回末队。 |
| 世界和界面 | world.gd、interface.gd、interactable.gd：加载第三章、标题选择、任务标识、交互、失败恢复与第二章战报续入；已有第三章进度时恢复，第三章战报不指向不存在的第四章。 |
| 存档和战法 | campaign.gd：三章独立记录，沿用 v2 格式并兼容旧 v1/两章 v2；章节转换保留原章战报、难度、战法及回澜解锁。hero.gd 支持第三章装备回澜。 |
| 玄甲先锋 | enemy.gd、actor_visual.gd、effects.gd：boss_id=vanguard，普通难度 HP 1450、破势 140；点戟、锁向冲锋、迟势横扫与半血冲锋接回戟，使用现有枪将图像配暗铁甲/月牙戟附件和专属效果。 |
| 地图与气氛 | jigu_layout.gd、terrain.gd、材质与气氛分支：冷灰崖面、枯松、横向栈道、旧石门、危桥与岩台；六张独立烘焙地表及 9 帧独立 jigu_props 图集，少量冷雾细雨。原 scenery 47 帧、汉水 20 帧图集不改。 |
| 断索表现 | 危桥使用 rope_posts_680_220_cut 静态帧表现断口和垂绳，实时选择及读档均由旗标决定贴图；桥面和碰撞保留。应称「断索截敌」，不能宣称可坠落的断桥物理。 |
| 开发巡游 | map_tour.gd 支持 Tab 循环三章、F1–F6 切区，不读写玩家存档。 |

这是可供集成验收的实现范围。独立逐帧敌将素材、完整过场和完整音乐没有在本轮制作；第三章 18–25 分钟仍是设计目标，尚不能写成人工完整通关实测时长。

## 固定的数据与接口合同

主敌群：fog [jg_f1,jg_f2]；signal [jg_s1,jg_s2]；pass [jg_p1,jg_p2]（p2.need=jg_front）；rearguard [jg_r1,jg_r2]；bridge [jg_b1]；final [jg_v1]。全章共 13 个固定敌群，不无限补兵，同屏上限 8。

支线组为 jg_dispatch_guard 和 jg_supply_guard。桥头追加组 jg_bridge_extra 为 manual=true、need=jg_bridge_held，不能被自动可选组扫描提前生成。jg_r2.reduce_if=jg_dispatch、jg_v1.reduce_if=jg_bridge_cut，reduce_kind=crossbow，各真实减少一名指定弩兵。

交互 kind=jigu，task 为 jg_banner、jg_dispatch、jg_front、jg_rear、jg_rearguard、jg_supplies、jg_last_guard。桥柱对象 jg_bridge_choice 的 task=bridge_choice。jg_vanguard 为 kind=boss、boss=vanguard、group=jg_v1；jg_finish 为 kind=finish、need=jg_boss。

出口要求：signal 需 jg_banner，pass 需 jg_rear，rearguard 需 jg_rearguard，bridge 需虚拟条件 bridge_resolved（已断索，或已留桥且接回末队）。决定退路前允许回访；确认后不返回前区补支线，桥头对话明确提示。

Campaign.JIGU_FLAGS：jg_banner,jg_dispatch,jg_front,jg_rear,jg_rearguard,jg_supplies,jg_bridge_cut,jg_bridge_held,jg_last_guard,jg_boss,jg_supply_claimed。断索与留桥互斥；后队以前队完成为前提，石门以后队完成为前提，桥头决定以石门完成为前提，Boss 以桥头完成为前提；领取补给须先救回辎重。

JiguDirector 复用 world.tactics 插槽，提供 setup/spawn_pending/advance/check_groups/main_clear/mission/command_changed、交互判定、choose_bridge(cut)、claim_supplies()。兼容字段 cart=null；capture_roster() 不复制汉水退军系统，援射状态返回隐藏。箭阵使用实际射线遮挡与锁向箭，夺旗清除未发射队列；暂停、死亡和对话不推进。不得把「还没生成敌人」当作清场。

## 地图重建与专项证据

- chapter3.json 是第三章当前权威数据。.qa/write_jigu_data.py 是最初生成辅助脚本，后续已做通路和美术调整，**不要直接重跑它覆盖当前 JSON**。
- tools/bake_jigu.gd 不启动完整世界、不碰玩家存档；一次生成六张 1600×1100 地表与 9 帧景物图集。之后必须重新导入资源，再作实机检查。
- 第三轮烘焙记录 .qa/jigu-bake-reviewed.log：六张地表、9 帧图集、0 失败。该结果只证明烘焙完成，不代表后续 Web 导出与线上部署通过。
- 最新地图专项 .qa/jigu-layout-after-preview.log：422/0，覆盖六区出生、随军、敌兵、交互、回访落脚、Boss 起点/战后位置、24 个环绕点，以及横桥三条通路和真实物理冲刺不能越崖。此前 426/0，减少四项是删去四块重复装饰岩后的帧检查数量变化，碰撞与可达性没有放宽。
- tests/jigu_preview.gd 使用真实 World、1280×720、固定 1.15 镜头和 MemoryCampaign，每次新 --label，拒绝覆盖已有图像/清单。12 张场景覆盖六区、箭阵预警、桥头对话、留桥追兵、永久断索效果、Boss 两阶段招式。
- 首轮 12 张图出现 1 项预览时序失败，保留 .qa/jigu-preview-first-error.log 与 .qa/jigu-first-manifest.json。.qa/jigu-rope-frame-order.log 证实生产贴图在第二帧更新；预览现等待两帧，并额外核对实际 AtlasTexture 区域，未删除或放宽原断言。最新复验由主线程填写下表。

命令从仓库根目录执行，图形任务必须串行：

1. 地图检查：godot --headless --path godot --script tests/jigu_layout_verify.gd
2. 地图烘焙：godot --path godot --script tools/bake_jigu.gd
3. 资源导入：godot --headless --path godot --editor --import --quit
4. 实机预览：godot --path godot --script tests/jigu_preview.gd -- --label=新的未用标签

## 本轮最终验收与发布记录

以下为本轮实际结果，不沿用 0.5.0 成绩；详细边界与首次失败记录见 CLOUD-POLISH。

| 验收项 | 本轮最终结果 / 证据 |
|---|---|
| 27 组完整回归 | 60,405/0，.qa/jigu-release-full-checks.log；后续营火修复加测第三章998/0，基础140/0、战法35/0、汉水1625/0；最终提示修改后第三章再次998/0。 |
| 最新 12 张图形场景 | release 标签12/0，逐张审查并修正文案；.qa/jigu-release-manifest.json，六区概览 docs/images/jigu-0.6.0.jpg。 |
| 原两章视觉与物理回归 | 原基线1107/0，.qa/jigu-original-map-baseline.log；旧基线未覆盖。动作/尺度/环境/两章流程包含于完整27组。 |
| 性能采样 | Arc B370 原生三个3.2秒样本P95 1.787/1.623/1.266 ms；.qa/jigu-performance-release.json。没有浏览器FPS结论。 |
| Windows 导出与 ZIP | EXE146,155,632字节，启动退出0；builds/Longdan-Godot-Windows.zip 为74,647,215字节、ZIP完整性通过，含三章说明。 |
| Web 导出与 PCK | 36,986,980字节；150资源/14JSON/18地表校验、实际PCK十八区smoke与资产187/0。SHA-256和日志见CLOUD-POLISH。 |
| 真实浏览器键鼠检查 | 三章选择、开场、移动、Q耗气、暂停恢复、军图正常，warn/error0；.qa/jigu-web-check.json。短测不等于人工通关。 |
| Git 与 GitHub Pages | 功能93f1db6已推送main，Pages部署成功；21:45:39线上PCK大小及SHA-256与本地一致，.qa/jigu-live-20261023-134520.json；实际浏览器加载并选第三章，无warn/error。 |

本轮已收尾。后续继续开发时先读本表与最新 Git 状态，不重复生成已完成素材。新增中文需重建字体，修改地图需重烘焙，改游戏或网页加载页需重新导出并核对实际包。尚未进行三章完整人工通关、目标时长实测和跨设备长时稳定性验收；不能把自动回归或短样本代替这些体验工作。

工具：引擎 D:/gpt/.tools/godot-4.7.2/Godot_v4.7.2-stable_win64_console.exe；Python C:/Users/36799/.cache/codex-runtimes/codex-primary-runtime/dependencies/python/python.exe。字体依赖目录 .qa/font-deps。完整回归由 Run-Checks.ps1 使用隔离测试存档；后台图形进程使用 Hidden，任一时刻只运行一个 GPU 任务。
