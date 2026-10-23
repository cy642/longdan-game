# 开发交接 · 三章收尾与 0.6.0 验收

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
