# 开发暂停交接 · 2026-10-23

状态：用户要求重启电脑，已暂停。以下为未完成开发快照，不能当作可发布版本。恢复时先阅读本页和 `CHAPTER-3-JIGU.md`，检查 Git 状态，再继续；不要重新从零设计。

## 本次目标与基线

用户要求先打磨收尾第一、二章，然后先规划第三章，再实现第三章，最终测试、更新 README 和 GitHub。当前唯一游戏为 Godot；网页按钮为“开始游戏”，旧 Canvas 已删除，不恢复旧入口或移动端。

本轮开始于干净且与远端同步的 `main`：`fb20b92`（Godot-only 发布记录）。线上最后发布功能为 `d65f004`。本轮尚未导出、打包或推送，线上仍是双章节稳定版；不要将本暂停快照直接推送 main。

## 第一、二章收尾：已实现、已专项验证

- `world.gd` 的井畔营救：两波全部清完后，若治疗尚不足 20 秒，也可在 1.2 秒短收尾后完成，免去快速清场后的空等；两波仍必须打完。
- `tactic_director.gd`：汉水退军名单在实际出兵前建好并持久保存；等待入口出兵不消耗退军窗口，预警期间直接出营不会吞掉追兵，延迟出现者遵守已执行的反击/齐射结果。
- 更新 `first_minutes_verify.gd`、`hanshui_pacing_verify.gd`。真实回归先复现 308 项中 8 个失败，修复后 308/0。第一关主流程 140/0，引导与救母 61/0，汉水完整流程 1625/0。
- 证据保留在 `.qa/chapters-finish-{before,pacing,first-minutes,hanshui-flow,base-flow}.log`；使用 `.qa/runtime/chapters-finish` 隔离存档。这是专项验证，尚未重新跑整个发行检查，且第三章后续代码会影响集成。

## 第三章：设计先完成，代码部分实现

设计稿：`docs/CHAPTER-3-JIGU.md`。主题《箕谷断后》，剧情演绎，六区：`jg_fog`、`jg_signal`、`jg_pass`、`jg_rearguard`、`jg_bridge`、`jg_final`。夺旗停止箭阵，两次主动撤军，石门两波断后，断索/留桥二选一，原创长戟敌将“玄甲先锋”。军报、辎重和末队接应有实际收益。

已写盘：

- `godot/data/chapter3.json`：六区及对象/敌群/路线/碰撞/场景数据，约 38 KB。生成辅助脚本 `.qa/write_jigu_data.py` 也已保存。尚未验证可达性。
- `campaign.gd`：新增第三章阶段、名称与 flags；独立三章 v2 存档验证、相邻通关章承接战法、第三章战报，回澜装备标记可承接第三章。现有 v1/v2 路径不变。仅已写代码，未验证集成。
- `enemy.gd`、`actor_visual.gd`、`effects.gd`：`kind="boss"`、`boss_id="vanguard"`，HP 1450、破势 140；点戟、锁向冲锋、延迟横扫，半血冲锋接回戟；枪将底图配暗铁甲/月牙戟和专属特效。尚未运行解析/战斗/视觉验证。

尚未写盘或接入：

- `jigu_director.gd`、`jigu_flow_verify.gd` 尚未创建。
- 世界层 `world.gd` 本轮仅改了井畔快清逻辑；尚未加载 chapter3、接入第三章交互/首领/失败恢复/第二章战报续入。
- `interface.gd`、`interactable.gd`、`hero.gd` 尚未改；标题、报告、任务形象、第三章回澜使用均待接入。
- 地图渲染/材质/气氛、六张地表、烘焙脚本、地图测试、巡游支持均未实现；不要把 JSON 中的 cliffs/chasms/bridges/jigu_props 当成已渲染或已有碰撞演出。
- `vanguard_enemy_verify.gd`、`vanguard_visual_verify.gd` 尚未创建。

## 已固定的数据与接口合同

主敌群：fog `[jg_f1,jg_f2]`；signal `[jg_s1,jg_s2]`；pass `[jg_p1,jg_p2]`（p2.need=`jg_front`）；rearguard `[jg_r1,jg_r2]`；bridge `[jg_b1]`；final `[jg_v1]`。

支线：`jg_dispatch_guard`、`jg_supply_guard`。留桥追加组 `jg_bridge_extra` 为 `manual=true`、need=`jg_bridge_held`，不能当作自动可选组生成。`jg_r2.reduce_if=jg_dispatch`、`reduce_kind=crossbow`；`jg_v1.reduce_if=jg_bridge_cut`，各减少一个指定弩兵。

交互 kind=`jigu`，task 为旗标：`jg_banner`、`jg_dispatch`、`jg_front`、`jg_rear`、`jg_rearguard`、`jg_supplies`、`jg_last_guard`。桥柱对象 `jg_bridge_choice` 的 task=`bridge_choice`。首领对象 `jg_vanguard` 为 kind=`boss`、boss=`vanguard`、group=`jg_v1`；收军 `jg_finish` 需要 `jg_boss`。

跨区要求：signal出口需 `jg_banner`，pass需 `jg_rear`，rearguard需 `jg_rearguard`，bridge需虚拟条件 `bridge_resolved`：断索已选，或留桥且末队已接回。桥决定前允许回访支线，决定后不允许回头刷收益；对话明确说明。

Campaign.JIGU_FLAGS 已含：`jg_banner,jg_dispatch,jg_front,jg_rear,jg_rearguard,jg_supplies,jg_bridge_cut,jg_bridge_held,jg_last_guard,jg_boss,jg_supply_claimed`。断索与留桥互斥；后队须前队完成，石门须后队完成，桥决定须石门完成，Boss须桥已解决，一次补给须先完成辎重。

JiguDirector 拟独立 Node2D，复用 `world.tactics` 插槽。提供 `setup/spawn_pending/advance/check_groups/main_clear/mission/command_changed`、`object_blocked/interaction_text/interact_object`、`choose_bridge(cut: bool)`、`claim_supplies()`。桥对话 route=`jigu:cut` / `jigu:hold`，由世界选择分支转调。最终营火先正常整备，再 claim 一次 +1 药，上限 4，写 `jg_supply_claimed`。

为适配现有调用还需 `cart=null`、`capture_roster()` 空操作、`support_status()` 返回 `{visible:false}`、`request_support()` false，或在世界层明确限定汉水调用。箭阵使用真实带预警的锁向箭，夺旗清掉未发射队列；暂停/死亡不推进；上限 8 活敌；未生成敌群不能被误记清场。

## 恢复顺序

1. 审查保存的差异和第三章设计，不动现有玩家存档与旧验证证据。
2. 完成地图/Director/Boss专项并接入 world/interface/interactable/hero；第二章战报自然进入第三章，有旧第三章记录时继续而非重开。
3. 新增真实流程、双桥分支、存档兼容/非法组合、Boss 与地图通行验证。旧 map_identity 基线只对原两章比较，不能覆盖旧基线来接纳新章；第三章单独验收。
4. 补齐中文字体，依次烘焙/导入第三章地图，真实镜头检查角色脚点、崖边、遮挡、箭阵与 Boss；一次只跑一个 GPU 任务。
5. 跑旧两章和新第三章回归，更新包验证/导出 smoke 到 18 区。Windows/Web 导出、网页键鼠、线上资源指纹分别验证。
6. 更新设计稿实现对照、README、CLOUD-POLISH；工作真正完成后再发布 main。

工具：引擎 `D:/gpt/.tools/godot-4.7.2/Godot_v4.7.2-stable_win64_console.exe`；Python `C:/Users/36799/.cache/codex-runtimes/codex-primary-runtime/dependencies/python/python.exe`。字体依赖可用 `$env:PYTHONPATH='D:/gpt/longdan-game/.qa/font-deps'`。验证输出保存 `.qa/`，Windows 后台启动用 Hidden；勿把未执行的第三章代码说成可玩或已通过。
