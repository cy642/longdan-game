# 龙胆：逆命三国 · Godot 电脑版

当前试玩版 0.9.0（2026-10-27）聚焦「第一章品质样板」，保留四章二十四区、24 种独立兵卒与 5 位将领。本轮新增赵云连续网格动作、接触音色与火花、可靠晚输入，以及长坂站位、六区地面痕迹和剧情演出。第四章「陈仓夜袭」的两路线、两支线与重锤首领继续保留；陈仓剧情为架空逆命演绎。

0.9.0 已完成最终38组完整回归（109,421/0、无脚本错误），包含全部收尾改动、17张地图／11张品质场景、动作前后各140帧、三场原生有效短样本，以及Windows启动／ZIP和最终实际PCK验证；浏览器基本操作已通过，线上PCK与本地字节数及SHA-256一致，功能提交7e22b4c。首章 10–15 分钟是体验目标；连续网格动作不等于新绘独立八方向逐帧素材，完整人工通关和长时前台帧率仍待实玩校准。最新状态见 [开发记录](../CLOUD-POLISH.md)，后续开发从 [当前交接](../docs/DEVELOPMENT-HANDOFF.md) 和 [首章制作标准](../docs/CHAPTER-1-QUALITY-SLICE.md) 开始。

枪势、战法、首玩提示、营火引导、敌人状态反馈、黄忠援射与护车玩法继续保留。制作规范见 [地图美术规范](../docs/MAP-ART-DIRECTION.md)，已有绘画重建约定见 [环境管线](../docs/PAINTED-ENVIRONMENT.md)，新章合同见 [陈仓设计稿](../docs/CHAPTER-4-CHENCANG.md)。可编辑关卡为 `data/chapter1.json` 至 `chapter4.json`，第一章局部地标补充为 `data/map_details.json`；四章巡游入口为 `../Map-Tour.cmd`。正式构建沿用原有 Godot 存档目录。

宣传副标题：**重生之我在三国当赵子龙**。Godot 4.7.2 / GDScript 的原生 2D 动作冒险，包含「长坂逆命」「汉水孤营」「箕谷断后」「陈仓夜袭」，各六区。仓库只保留这一套 Godot 游戏，在线版与 Windows 本地版共用游戏内容与开发源。

## 直接试玩

- 默认在线首页 <https://cy642.github.io/longdan-game/> 会进入 <https://cy642.github.io/longdan-game/godot-play/>，跳转保留参数/片段。在线版与 Windows 版从同一 Godot 工程导出；加载页点击「开始游戏」，使用电脑 Chrome、Edge 或 Firefox，首次需要下载引擎与素材。
- 本地导出后可双击 `../builds/windows/Longdan.exe`，运行此程序无需安装 Godot、Python 或联网；Windows 构建包不纳入源码仓库。
- 打开工程：在 Godot 4.7.2 中导入本目录的 `project.godot`，按 F5 运行。
- 标题可选择四章中的任一章、普通/剧情难度，开始或继续所选章节；其他章节进度会保留。查看战报也按当前选择的章节读取。前三章战报可续入下一章；第四章为当前终章。
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

第一章随军只在井畔营救和桥头突围参与战斗，第二章跟随护车并可在青旗守点藏兵，第三、四章沿用集合/守点/冲阵协助清路。单人 3.5 伤害 / 1.8 秒，最多将敌人体力压到 22%，赵云需要亲自完成击杀。正式单挑中随军负责护送。

0.8.0 的难度递进由 `scripts/combat_pacing.gd` 统一配置：普通敌人的整套起手共享间隔从山道 0.90 秒逐区降至鼓楼 0.26 秒，整套结束后再留额外休息；剧情难度分别增加 0.20 / 0.12 秒。Boss 绕过普通敌人起手名额，使用各自整套结束间隔。已有敌兵/将领的生命、伤害、招式前摇、生效、收招定义、锁向、闪避和同屏 2 近战/1 远程限制不变；连段内部不插等待。表格与调用约定见 [难度曲线](../docs/DIFFICULTY-CURVE.md)。

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

完成空营计并通关解锁「龙胆·回澜」，第二至第四章可在暂停页切换 Q 招式；奖励写入跨章节存档，第一章数值不随之变化。第二章默认拥有青釭，仍须积满战意使用 R。汉水战报首按钮进入「箕谷断后」；新第三章承接难度、战法与已解锁回澜，已有进度恢复原检查点或战报，不覆盖其独立选择。

## 第三章：箕谷断后

六区按「雾锁箕谷 → 崖台军报 → 断崖栈道 → 石门拒敌 → 断索危桥 → 谷口决战」推进。清开崖台后 E 夺号旗，停止本区追加箭阵并取消待发预警；两段栈道分别清路后到军旗按 E 下撤令，短暂旗帜离场提示后继续推进。石门有两波有限追兵，军报支线真实减少第二波一名弩兵。

桥柱交互在条件完成后给出两个结果：断索减少谷口一名弩兵；留桥追加两名追兵，击退后 E 接回末队。两条均能到最终战，战报分别记录。决定前可回访支线，确认后前区关闭，界面提前说明。辎重支线在谷口营火提供一次额外行军药，领取上限四份，已领取标记入档；重复交互不重复发放。

玄甲先锋普通体力 1450、破势 140，使用长戟点阵、锁向直冲和迟势横扫；半血停手变招 1.20 秒，加入冲锋后回扫，等整套收完再反击。动作使用自带完整月牙戟的独立原画、连续网格姿态与左右镜像，没有旧代码兵器附件。第三章具体任务与敌将为游戏演绎；18–25 分钟是设计目标，未作为普通难度人工通关实测。箕谷战报现在可以继续进入陈仓，已有第四章记录不会被覆盖。

## 第四章：陈仓夜袭

六区按「灰砖城关 → 烽火台 → 城门内街 → 仓院 → 瓮城 → 鼓楼决战」推进。每批 2–4 人，主路和支线共用最多 8 名活敌与至少 1.2 秒来向预警。烽台交战最多三轮箭阵、每轮至多两条箭路，锁向预警至少 1.25 秒；箭阵与普通弩兵轮流占用远程攻击机会。E 熄烽后清除尚未发射的预警，已飞出的箭仍按碰撞处理。

内街 E 选择正门或侧巷，可先取消观察；确认后本次路线保存，重玩本章才重选。正门一战三人并减少瓮城一名重盾；侧巷两战各两人并减少瓮城一名弩手。未选路线不出兵，不能凭空判清场。两线均需清完后在对应军旗或巷闸 E 完成军令。

烽台西厢的调令阻止尚未到场的仓院援军。实际到场时写入 `cc_reserve_called`；后来补取调令仍须击退这批敌人。仓院西侧救工匠后，主目标完成才开启侧门，落脚瓮城 `(1360,890)`，正常出口仍到 `(220,900)`；两种进入方式都要完成瓮城主战斗。

鼓楼先清亲卫，E 挑战会给确认与回头整备选项；仅确认 `warden:commit` 后设置 `cc_committed`，关闭回访。镇关都尉普通体力 1500、破势 145，使用落锤、横锤、圆形重落与半血扣步接迟势回锤。圆形预警使用真实圆形命中，半血过渡 1.20 秒无伤害。击败后仍须 E 收军旗才形成战报。具体城关、事件和敌将均为架空逆命剧情；18–24 分钟是设计预算。

### 四章存档

`user://longdan-godot-v2.json` 保存四章独立检查点、已清遭遇、支线、章内计策、战法与战报，以及跨章奖励；汉水另保留退军名册。`JIGU_FLAGS` 保留桥头、撤军与补给前提验证；`CHENCANG_FLAGS` 验证主路顺序、路线互斥、援军到场、确认决战与首领/通关条件。`battle_art` 缺失时使用基础枪法，未知值拒绝读入。瞬时枪势、攻击调度计时和箭阵队列不入档。重开所选章节保留其他章节记录。有效旧第一章 v1、没有 JIGU 字段的旧两章 v2，以及没有 CC 字段的旧三章 v2 均继续可读；新增字段保守补为未完成，新保存仍写 v2，旧 v1 文件保留。Windows 与 Web 存档互不自动同步。

本轮不提升存档版本；营火访问标记追加到原有 `seen` 数组（例如 `camp:mountain`），保留旧剧情记录。玩家选择保留基础枪法后，读档不会再次被引导回已访问的营火。黄忠援射的拉弓、飞箭和冷却属于本次遭遇运行状态，不添加永久奖励或新章节存档字段。

[第一章六区实景](../docs/images/changban-0.9.0.jpg) · [赵云动作动态对照](../docs/images/zhaoyun-motion-0.9.0.gif)。后者为7秒／20FPS的归格动作采样，不是实战或新绘逐帧素材。

## Godot 的结构

- `scripts/hero_motion.gd`、`actor_visual.gd`：赵云方向帧的脚锚、上半身刚性变换、交替腿步和连续出枪；不改人物密度或攻击判定。`hero_snapshot()` 为闪避后像提供独立 Mesh，之后的动作不修改既有后像。
- `scripts/hero.gd`、`combat_feedback.gd`：0.14 秒输入缓冲按实际合法边界消费，最多分割一次当前物理步；无效输入不覆盖已接受动作。接触分类只控制表现，不修改原伤害／气力／精准窗口。`enemy.gd` 在实际伤害后、击败事件之前调用 `Hero.contact_feedback`，随军／环境保留独立路径。
- `scripts/changban_combat.gd`：仅第一章普通兵的肩侧、枪距、弓手遮挡与移位；原目标选择、进攻人数和共享起手间隔继续生效，不新增存档字段。
- `scripts/changban_direction.gd`、`interface.gd`：首次入区地名、接近遭遇提示和剧情结果字幕；不阻断操控、不改变缩放或主路任务，运行提示不写进度。
- `scripts/changban_presentation.gd`、`data/map_details.json`：首章六区静态地面痕迹及限量动态烟尘／落叶／水光／暖灯；随既有旗标更新，暂停、死亡和顿帧冻结。`tools/bake_changban.gd` 只重烘焙第一章六地表，保留其他章节与共享图集。

- `scripts/enemy_roster.gd`、`data/enemy_atlas.json`、`assets/enemies/`：四章 24 种兵卒与 5 位将领，共 29 档案、六张原画图集。章节、行为类型及少量支线身份决定画像，行为和存档仍使用原 `kind/boss_id`。`tools/prepare_enemy_assets.py` 读取 `art_source/characters/enemy-calibration.json`，按人体尺寸、靴底、头部及刚性武器区域生成清单，不改写原 PNG；`--check` 只校验。邻帧裁框可重叠，但排除后的可见像素不得重复，制作工具不能删除自身像素。
- `tests/enemy_roster_verify.gd`：遍历 29 种实际画像并检查比例、真实靴底像素、刚性脸/武器与缓存独立性；旧 NPC 保留原素材。`tests/enemy_roster_preview.gd` 保留前三章联系表入口，陈仓实景由 `chencang_preview.gd` 检查。预览使用新 `--label`，拒绝覆盖旧证据。新原画仍采用连续网格动作与左右镜像，不是八方向逐帧动画。
- `scenes/main.tscn`：游戏入口。
- `scenes/hero.tscn`、`scenes/enemy.tscn`：原生 `CharacterBody2D` 与地面碰撞形状。
- `scripts/hero.gd`、`enemy.gd`、`companion.gd`：动作阶段、闪避、敌人连招、盾防与军令。
- `scripts/actor_visual.gd`、`frame_texture.gd`：赵云八方向动作、固定模型比例与脚底锚点；`data/atlas.json` 的 `model_scale` 为整套原画的像素密度校准，walk/attack 共用 0.34，旧 hero 倒地原画为 0.29。不要再用逐帧头发色块高度或含长枪的包围盒自动归一化。原画网格保持敌人脸和武器刚性，重叠图集通过绘制几何排除邻帧碎片。
- `scripts/terrain.gd`、`scenery.gd`：原生地形碰撞、Godot AStarGrid2D 绕障碍路径、烘焙地表与共用景物图集。
- `scripts/hanshui_layout.gd`：第二章六区共用的美术、地形与碰撞布局；动态营门开合与路径更新由 `terrain.gd` 提供。
- `scripts/jigu_layout.gd`、`tools/bake_jigu.gd`：第三章崖谷、横向栈道、石门、桥柱的可编辑绘制与六区离线烘焙，运行时使用独立景物图集。
- `scripts/chencang_layout.gd`、`tools/bake_chencang.gd`：陈仓灰砖城街、瓦顶仓房、烽台、城门与鼓楼；六张地表及专用建筑图集。原图清单为 `art_source/painted/chencang-props-source.json`，仅烘焙阶段读取。
- `scripts/painted_ground.gd`、`painted_props.gd`：仅在制作阶段读取环境原图并绘制材质/连通区域抽帧；正式运行使用烘焙结果。
- `assets/maps/`：四章各六张 1600 × 1100 地表，以及共享景物、汉水、箕谷和陈仓景物图集与脚底清单。树木、岩石和建筑按落脚位置排序，动态路障、桥柱和烽火状态单独更新。
- `assets/props/`：四件旧地标的新绘画像素及原契约清单，另含 `painted_markers.png/json` 的三种门楼跨度与井架。
- `scripts/effects.gd`、`sound.gd`：战斗预警、枪芒、受击火花、残影、局部音效。
- `scripts/world.gd`、`campaign.gd`：章节入口、剧情、目标、v2 独立进度、旧 v1 兼容、战报和奖励。
- `scripts/tactic_director.gd`：第二章有限波次/存活上限、藏兵与门前试探、退军名册、擂鼓结果及稳定恢复阶段。
- `scripts/jigu_director.gd`：第三章有限波次、锁向箭阵、两次撤军、军报减员、桥头双分支、一次补给与目标提示；不复用汉水粮车和黄忠援射状态。
- `scripts/chencang_director.gd`：继承箕谷有限队列，重写陈仓目标、两条进路、调令/工匠、条件援军、瓮城减员与有限箭阵。
- `scripts/combat_pacing.gd`：四章逐区普通敌人起手间隔及整套动作结束后的休息；世界只在正常游玩、非停帧时推进一次，不保存运行计时。
- `scripts/huangzhong_support.gd`：北山玩家军令援射、候选目标、锁向单箭、碰撞和冷却；由战术调度创建、推进与取消。
- `scripts/grain_cart.gd`：粮车原生碰撞、耐久与受击；路线和停靠由战术调度控制。
- `scripts/interactable.gd`：营火、出入口、黄忠/伤兵、火箭辎重、藏兵旗、门扇和鼓台实物；粮车提示跟随车移动。
- `scripts/interface.gd`、`map_view.gd`：原生中文界面、暂停、军图和战斗状态。
- `data/chapter1.json`：第一章关卡与招式参数的唯一数据源，直接编辑；不再从外部 JavaScript 同步。
- `data/chapter2.json`：汉水六区的路网、实体、支线、波次、计策坐标与初始调参。
- `data/chapter3.json`：箕谷六区的通路、峡谷、固定敌群、交互与支线减员条件。
- `data/chapter4.json`：陈仓六区的路网、建筑脚点、双进路、主支线敌群、侧门落脚与烽台箭阵预算。
- `export_presets.cfg`：Windows 单文件与单线程 Web 导出设置。

角色原 PNG 保留。赵云沿用每方向两帧步行和蓄势/出枪，敌军完整兵器已绘入独立原画，没有旧代码装备附件；连续姿态保持头脸和长兵器刚性。两次弩后坐对应两次发射，装填不再出箭。后续仍需补敌人独立动作素材、赵云步行帧、黄忠战斗/剧情演出和完整音乐。

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
godot --headless --path godot --script res://tests/jigu_layout_verify.gd
godot --headless --path godot --script res://tests/jigu_flow_verify.gd
godot --headless --path godot --script res://tests/jigu_campaign_verify.gd
godot --headless --path godot --script res://tests/vanguard_enemy_verify.gd
godot --headless --path godot --script res://tests/vanguard_visual_verify.gd
godot --headless --path godot --script res://tests/enemy_roster_verify.gd
godot --headless --path godot --script res://tests/combat_pacing_verify.gd
godot --headless --path godot --script res://tests/chencang_layout_verify.gd
godot --headless --path godot --script res://tests/chencang_flow_verify.gd
godot --headless --path godot --script res://tests/chencang_campaign_verify.gd
godot --headless --path godot --script res://tests/warden_enemy_verify.gd
godot --headless --path godot --script res://tests/warden_visual_verify.gd
godot --headless --path godot --script res://tests/hero_motion_verify.gd
godot --headless --path godot --script res://tests/combat_feedback_verify.gd
godot --headless --path godot --script res://tests/changban_direction_verify.gd
godot --headless --path godot --script res://tests/changban_presentation_verify.gd
New-Item -ItemType Directory -Force builds/windows, godot-play | Out-Null
godot --headless --path godot --export-release "Windows Desktop"
godot --headless --path godot --export-release "Web"
```

Windows 可用根目录 `Run-Checks.ps1` 一次执行导入与38组回归套件：`./Run-Checks.ps1 -Engine "引擎可执行文件路径"`；Linux/macOS 可运行 `./Run-Checks.sh /path/to/godot`。涵盖四章流程、存档、角色、地图、难度调度及第一章品质样板。`-Engine` 省略时先读取环境变量 `GODOT_EXE`，再寻找 PATH 中的 `godot` / `godot4`。输出写入 `.qa/`，缓存与存档使用 `.qa/runtime/`，仅修改当前进程环境；保留发行日志时另用新的日志前缀。两个 `.cmd` 启动器也接受引擎路径作为首参数，或使用 `GODOT_EXE` / PATH。检查脚本在退出码为0但日志含SCRIPT ERROR／ERROR时仍判失败。

输出目录为仓库的 `builds/windows/` 与 `godot-play/`。`builds/`、`.godot/`、`.qa/`、日志和本机引擎不入库。`godot-play/` 是已跟踪的 Web 导出，修改 Godot 游戏后须重新导出并与源码一起提交。现有 GitHub Pages 从 `main` 分支的仓库根目录自动发布，Pages 流程不会替你运行测试或导出 Godot。根 `index.html` 跳转至 `./godot-play/`，加载页统一显示「开始游戏」。仓库已移除旧 Canvas 页面、脚本和构建工具，只保留 Godot 游戏。

`painted_assets_verify.gd` 不读取原画或本机基线，可从项目外针对实际 PCK 检查所有运行资产。导出完成后执行（脚本路径须为本机绝对路径）：

```powershell
godot --headless --main-pack godot-play/index.pck --script "D:/gpt/longdan-game/godot/tests/painted_assets_verify.gd"
godot --headless --main-pack godot-play/index.pck --script "D:/gpt/longdan-game/godot/tests/export_smoke.gd"
godot --headless --main-pack godot-play/index.pck --script "D:/gpt/longdan-game/godot/tests/enemy_roster_verify.gd"
python godot/tools/verify_export_pack.py
```

专项覆盖二十四个真实区域的缓存地表、四件旧地标契约、门楼/井图集、箕谷断索状态和陈仓建筑脚锚/烽火状态，确认不触发制作侧原图加载。PCK 检查要求四章 JSON、24 张地表、四套景物图集及六张敌军图集的实际导入载荷，禁止导出制作原图、工具与测试。源码通过不代表导出包通过，必须针对新包再检查；资产检查也不判断美感。

检查 Web 导出时，在仓库根目录执行 `python -m http.server 8767 --bind 127.0.0.1`，然后用浏览器打开 `http://127.0.0.1:8767/godot-play/`；不要直接双击 Web 导出的 HTML 文件。

自动检查运行真实 Godot 节点与物理空间，覆盖：八方向动作 / 脚底与比例、邻帧枪尖排除且保留真实枪头、蓄势 / 出枪 / 收招期间脚底与阴影不分离、真实命中时段、跨帧服药、服药打断、动作缓冲与闪避取消、精准闪避、鼠标释放与暂停清理、盾防反击、随军输出上限、绕建筑路径、两波营救、两位敌将、焚粮部署、木桥通路、三种命运、战报回读、无效存档和保存失败回退。测试使用独立存档，不会替换玩家进度。在仓库根目录用 `godot --path godot res://tests/pose_preview.tscn` 可核对八方向的站立、行走、蓄势和出枪，预览不读取或写入存档。

第二章五套检查分别覆盖真实地图可达/碰撞与营门开合、原生世界转场，新敌兵和督军的跨帧命中/双发锁向，新造型的四方向姿态/脸部刚性/装备握点，以及主线/支线/粮车/计策/存档恢复。流程回归会加速击败遭遇以验证状态推进，不代表人工通关、难度合适或达到目标游玩时长。

第三章新增五套检查：`jigu_layout_verify` 检查六区碰撞/通路，`jigu_flow_verify` 检查有限波次、停箭、两次撤令、桥头双路线、支线减员和补给，`jigu_campaign_verify` 操作真实 UI 并读写隔离磁盘验证三章档案与旧档，`vanguard_enemy_verify` 检查四向命中、锁向、冲锋墙碰撞、掉帧、破势及一次半血变招，`vanguard_visual_verify` 检查固定比例、脚锚和刚性戟杆。具体已运行成绩见第三章实施对照，完整发布验收另见开发记录。

第四章五套检查为 `chencang_layout_verify`、`chencang_flow_verify`、`chencang_campaign_verify`、`warden_enemy_verify`、`warden_visual_verify`。它们覆盖主/侧出口通路、未选路线不出兵、真实两路线到战报、调令到场前后、工匠侧门、至少 1.25 秒的有限箭阵及弩互斥、暂停/死亡恢复、Boss 确认后才锁回访、真实 E 收旗、三到四章衔接与旧存档，以及重锤圆形/扇形真实命中和连续姿态。`combat_pacing_verify` 另验证 24 区正常/剧情难度、同帧起手互斥、连段连续性、Boss 绕过普通名额与冻结/重配。保持原视觉阈值，不用减少断言来换通过。

原生图形验收单独运行，不能加 `--headless`：

```powershell
godot --path godot --script res://tests/hanshui_visual_verify.gd -- --capture
godot --path godot --script res://tests/hero_pose_capture.gd
godot --path godot --script res://tests/map_identity_preview.gd -- --label=review-001
godot --path godot --script res://tests/jigu_preview.gd -- --label=review-jigu-001
godot --path godot --script res://tests/chencang_preview.gd -- --label=review-chencang-001
godot --path godot --script res://tests/chencang_performance.gd -- --label=perf-chencang-001
godot --path godot --script res://tests/playability_preview.gd
godot --path godot res://tests/hanshui_playtest.tscn -- --qa-stage=hs_camp
godot --path godot --script res://tests/hanshui_performance.gd
```

截图入口保存 `.qa/hanshui-visuals.png`，实际渲染汉水敌人动作与交互实体；`hero_pose_capture.gd` 输出八方向六状态联系表。原两章正常镜头使用 `map_identity_preview.gd`：它输出十二个区域和五个实战状态共十七张 1280 × 720、镜头倍率 1.15 的 `.qa/map-identity-标签-场景.png`，并写入同标签 manifest。五个状态包含北山黄忠援射可用、孤营关门、乱石护车，以及夏侯恩与督军蓄势。预览采用内存进度，不读写玩家存档；同名标签拒绝覆盖，复拍须用新标签。旧 `theme_preview.gd` 保留供历史复核。开发试玩使用隔离进度打开指定汉水区域；性能入口采样 8 敌/3 随军、营门、退军河湾与督军二阶段，输出 `.qa/hanshui-performance.json`。人工检查须记录设备、分辨率、难度和耗时；无界面检查不能代替画面、声音或性能验收。

第三章正常镜头使用 `jigu_preview.gd -- --label=新的标签`，覆盖六区与真实箭阵预警、桥头选择、留桥追兵、断索状态、玄甲先锋两阶段预警。脚本采用内存存档与实际安全脚点，输出截图和独立清单；它是可控场景检查，不是人工从头打通。实际捕获结果与人工审阅结论由开发记录保存。

第四章正常镜头使用 `chencang_preview.gd -- --label=新的标签`，受控场景包括六区、烽火亮/灭与箭阵、内街选择和两路线、工匠侧门及重锤扇形/圆形/二阶段。`chencang_performance.gd` 同样拒绝覆盖旧标签，输出 `.qa/chencang-performance-标签.json`；三场为六敌烽台箭阵、四敌绕墙混战与都尉二阶段，每场 0.8 秒热身、3.2 秒采样，1280×720、镜头 1.15。普通兵只延长生命维持负载，技能和物理不改；实际活敌数、发箭、阶段或持续战斗条件不满足时报告失败。原生短样本不能代表网页帧率或人工难度。

性能 JSON 中的 `p95_ms/max_ms` 来自相邻 `process_frame` 的墙钟间隔；`process_p95_ms/physics_p95_ms` 是重复读取 Godot 内置监视器得到的分位数。Godot 4.7.2 每约一秒才公布此前累计的处理峰值，后者可能包含入区/热身阶段，并非逐帧处理耗时 P95。两类指标应分开呈现，保留原报告，不据其中任何一项保证 FPS。参见 [Godot 4.7.2 监视器更新源码](https://github.com/godotengine/godot/blob/4.7.2-stable/main/main.cpp#L4723-L4765)。

四章关卡直接维护 `data/chapter1.json` 至 `chapter4.json`，不再保留旧 JavaScript 同步管线。角色原图只保存在 `assets/`；`tools/prepare_assets.py`（Pillow / NumPy）直接读取这些 PNG，重建 `data/atlas.json` 的锚点、裁切和固定比例，不复制或修改原图。提交内已包含运行用图集与元数据，日常开发无需重建。运行 `python godot/tools/prepare_assets.py --check` 只核对清单；不加 `--check` 时重建。原图来源和完整提示词见 [角色素材说明](art_source/characters/ART-NOTES.md) 与 [八方向出枪说明](art_source/characters/ATTACK-V3-NOTES.md)。

中文字体为 Noto Sans SC 的游戏字符子集，已按 OFL 更名为 Longdan Game Sans；许可见 `assets/fonts/LICENSE.txt`。新增中文对白后需运行 `tools/subset_font.py` 重建字符子集（fonttools，首次从官方来源下载原字体并缓存）。Godot 与第三方组件许可见 `assets/licenses/`。

## 地图与性能

`terrain_materials.gd` 定义二十四区的土色、路宽、树种与植被密度。`painted_ground.gd` 离线混入六种原画材质；`painted_props.gd` 从透明图指定种子点抽取连通物件，按脚底和占地宽重绘景物图集。`scenery_styles.gd` 留作未覆盖物件后备。第一章局部笔触在 `map_details.gd`，第二章在 `hanshui_layout.gd`，第三章独立崖谷与木石结构在 `jigu_layout.gd`，第四章灰砖城关与夜间建筑在 `chencang_layout.gd`。制作要求见 [MAP-ART-DIRECTION.md](../docs/MAP-ART-DIRECTION.md)，来源及重建步骤见 [PAINTED-ENVIRONMENT.md](../docs/PAINTED-ENVIRONMENT.md)。`map_atmosphere.gd` 保持有限气氛装饰，正常镜头倍率为 1.15。

二十四区各有一张 1600 × 1100 静态地表；共享景物、汉水道具、箕谷道具、陈仓建筑和门楼/井分别使用图集与脚底清单。当前图集尺寸和帧数以 `assets/maps/*.json`、`assets/props/painted_markers.json` 为准。源 PNG 与提示词保留在 `art_source/painted/`，运行时不加载。地图外观与实体、交互、剧情坐标分离；第三、四章用各自独立布局检查，前两章继续对照原物理基线。修改原图、抽帧清单或绘画代码后依次重建：

```powershell
# 在仓库根目录运行。
godot --path godot --script res://tools/bake_painted_landmarks.gd
godot --headless --path godot --editor --import --quit
godot --path godot --script res://tools/bake_maps.gd
godot --path godot --script res://tests/hanshui_layout_verify.gd -- --bake
godot --path godot --script res://tools/bake_jigu.gd
godot --path godot --script res://tools/bake_chencang.gd
godot --headless --path godot --editor --import --quit
godot --path godot --script res://tests/performance.gd -- --label=my-computer
```

先生成四件地标和四帧 marker 并立即导入，再生成第一章地表/共享景物、第二章地表/汉水图集、第三章地表/箕谷图集、第四章地表/陈仓图集，最后再次导入。仅改某一章时可单独执行对应烘焙脚本后导入。不要只修补生成的 PNG，也不要把旧 Blender 输出当成当前绘画资产。`.qa/` 为本机忽略目录，**基线不随 Git 提交**；前两章修改前先保留源状态与正常镜头，修改后对照，不能覆盖既有证据。第三章另跑 `jigu_layout_verify` 和 `jigu_preview`，第四章另跑 `chencang_layout_verify` 和 `chencang_preview`；不向旧两章冻结基线追加伪造历史数据。

```powershell
godot --headless --path godot --script res://tests/map_identity_verify.gd -- --write-baseline
godot --path godot --script res://tests/map_identity_preview.gd -- --label=before
# 完成前两章可编辑源修改、重烘焙和导入后：
godot --headless --path godot --script res://tests/map_identity_verify.gd
godot --path godot --script res://tests/map_identity_preview.gd -- --label=after
```

`map_identity_verify.gd` 对照原坐标、物理形状、寻路网格、交互物、真实移动路径和贴图契约；它不能判断美术是否好看。`map_identity_preview.gd` 的十七张图需要人工逐张确认区域辨识、关键角色遮挡、任务提示与战斗预警。旧存档通行和性能、导出、线上画面仍需独立验收。

性能检查使用 1280 × 720、关闭垂直同步的真实图形渲染，分别采样山道、荒村和北桥战斗。不会写入玩家存档；每台电脑应以自己的测试结果为准。Web 版将渲染倍率限制为最多 1.5，最长边最多 1920 像素，降低高分屏负担；窗口和全屏大小改变后保持鼠标位置对应。开发者可用 `?profile=1` 试玩，开战六秒后在浏览器控制台读取一次实际帧耗时报告，普通游玩不启用监测。

## 后续开发与已知待打磨

设计与实施约定见 [第二章设计稿](../docs/CHAPTER-2-HANSHUI.md)、[第三章设计稿](../docs/CHAPTER-3-JIGU.md)、[第四章设计稿](../docs/CHAPTER-4-CHENCANG.md) 和 [难度曲线](../docs/DIFFICULTY-CURVE.md)。下一轮需普通难度完整实玩，校准护车、藏兵鼓点、箕谷撤令/桥头选择、陈仓两线与调令时机，以及各首领反击窗口。汉水 25–35 分钟、箕谷 18–25 分钟、陈仓 18–24 分钟均为设计目标，尚非实测通关时间。

黄忠已有北山军令援射与拉弓表现，但自主移动/持续战斗 AI、三幕正式过场尚未制作；角色配件与剧情镜头仍需美术统一，完整环境音/音乐未完成。修改地图后重烘焙，新增中文后补齐字体，再导入和导出。浏览器实际帧耗时、长时间稳定性和音频听感需要独立实测；第一章过去的 WebGL 警告和软件渲染数据不得当作本轮已解决或已达标。
