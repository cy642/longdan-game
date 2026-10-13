# 地图打磨本地验证记录 · 2026-10-13

## 仓库发布准备复核

在独立 Git 检出中再次完成资源导入及四组检查：136 + 9 + 491 + 140，共 **776 项通过**。Windows 检查入口 `Run-Checks.ps1` 已用指定 Godot 引擎实际执行通过。正式工程的 `project.godot` 保持原有存档路径，前次 Library 预览包的独立存档设置未带入正式发布。

重新导出的 Web `index.pck` 已通过 Godot 原生加载 smoke（6 区域、5 图集），Windows 正式导出也通过无窗口和图形启动 smoke。Web 包的原生加载检查不等同于浏览器 WebAssembly 运行；本次浏览器自动化仍因平台目录错误未能启动。日志保留于本地 `.qa/release-*.log`，不入库。现有 Pages 仅发布已提交文件，推送后的部署状态应另行核对。

## 首轮地图实现验证

本文记录地图打磨完成后的首轮本地验证，不作为后续 GitHub Pages 发布成功的证明。环境：Windows；Godot 4.7.2.stable.official.ed1daf0bf；Intel Arc B370；Compatibility / OpenGL。工作副本与原目录隔离，测试使用工作区内的临时配置与存档。表中的 `.qa/` 日志和截图保留在本地交付中，不纳入源码仓库；可按 [MAP-POLISH.md](MAP-POLISH.md) 重跑检查。

| 检查 | 实际结果 | 证据 |
|---|---|---|
| Godot 资源导入 | 完成，最终日志无 ERROR | `.qa/import.log` |
| 既有战斗/章节回归 | 136 项，0 失败 | `.qa/verify.log` |
| 既有音频回归 | 9 项，0 失败 | `.qa/audio_verify.log` |
| 地图原生物理回归 | 491 项，0 失败 | `.qa/map_verify.log` |
| 军图回归 | 140 项，0 失败 | `.qa/map_view_verify.log` |
| 地图烘焙 | 六张 1600×1100 地表与33帧景物图集完成 | `.qa/bake.log` |
| 图形截图 | 六区场景 + 三幅军图，9张改后实渲染截图 | `.qa/capture.log`、`.qa/after-*.png` |
| 巡游场景 | 启动30帧，无报错，exit 0 | `.qa/map-tour-smoke.log` |
| Windows 导出 | 最终导出成功，无 ERROR | `.qa/export-windows.log` |
| Windows 包运行 | headless 启动 exit 0，`GODOT_SMOKE_OK regions=6 atlases=5` | `.qa/export-smoke.log` |
| Windows 包图形启动 | Intel Arc 图形后端实际启动并完成 smoke，exit 0 | `.qa/export-graphics-smoke.log` |

共 **776 项自动检查通过**。地图专项验证19个互动点真实移动往返、16次实际交互触发的场景切换、约48,643世界像素移动、35个敌军/6个玩家/18个随军初始点、22个新碰撞体与导航一致性、河岸阻挡与桥面双向通行、焚粮前后侧路、连续三轮重复进入，以及布局合并幂等性。测试不是仅比较配置文本，使用了实际 Godot 节点、物理空间与角色碰撞形状。

视觉检查查看了六区实渲染截图、三幅军图，修正了破庙旧铺砖露边与庭院路芯重复接缝；图例无明显重叠、裁切或缺字。最终源文件和截图相符。

## 渲染采样

1280×720，关闭垂直同步，真实图形后端，各场景预热0.7秒、采样2秒。数据在 `.qa/performance-after-map-polish.json`：

| 场景 | 帧间隔中位数 | p95 | 绘制调用中位数 |
|---|---:|---:|---:|
| 山道 | 0.791 ms | 1.222 ms | 162 |
| 荒村 | 1.022 ms | 1.567 ms | 238 |
| 北桥 | 0.884 ms | 1.358 ms | 199 |

这些是本机短时采样，不能代表其他机器、网页导出或全章平均表现。改前同机数据也保留，但运行时负载和窗口状态并非严格控制，所以不据此宣称相对性能提升。新增立体地标提高了绘制调用数量，细碎地表仍通过烘焙控制开销。

## 限制与已处理问题

- 首轮本地验证时，用户电脑浏览器自动化未能启动：`MXC launcher: cannot locate required Windows platform directory: HRESULT 0x80070003`。该阶段未完成线上网页人工玩法、实际交互、浏览器兼容性或 Web 导出测试；所有新截图均来自本机 Godot。
- 首次导出使用沙箱默认临时目录时失败；改用本任务内 `runtime/Temp` 后重新导出成功。仅设置导出进程的 TEMP/TMP，没有读取受限目录或更改系统设置。
- 首轮本地验证时，原仓库 Git 状态最初在沙箱内无法读取，经只读权限复核确认对应 remote 与干净工作区；实现使用独立工作副本。
- 没有完整人工通玩第一章，也没有做持续数小时的稳定性测试。自动回归覆盖原有战斗与章节分支，地图侧重点另有真实移动/碰撞回归。

首轮源码修改清单与 SHA256 保存在本地 `.qa/changed-files.json`。正常试玩和编辑方法见 [MAP-POLISH.md](MAP-POLISH.md)，可复现的导出命令与现有 Pages 发布方式见 [godot/README.md](godot/README.md)。
