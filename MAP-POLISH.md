# 长坂地图打磨

本轮在 `cy642/longdan-game` 的 Godot 工程上完成，基线提交为 `faf0f4f`（收尾第一章脚步声并设计汉水孤营）。实现与首轮验证在独立工作副本中进行，以下路径均相对于仓库根目录。构建与发布方法见 [godot/README.md](godot/README.md)。

## 打开

- 正常游玩：在 Godot 4.7.2 导入 `godot/project.godot` 后按 F5；本地导出后也可双击 `builds/windows/Longdan.exe`。
- 快速检查六区：双击 `Map-Tour.cmd`。WASD / 方向键移动，F1–F6 切换区域，M 军图。巡游使用真实游戏节点与碰撞，移除战斗门槛，不读取或写入玩家进度。
- 编辑：双击 `Open-Godot.cmd`，或在 Godot 4.7.2 导入 `godot/project.godot`；F5 运行完整第一章。
- 两个 `.cmd` 的第一个参数可指定 Godot 可执行文件路径；未指定时读取 `GODOT_EXE`，再查找 PATH 中的 `godot.exe` / `godot4.exe`。也可直接在编辑器中打开 `godot/tests/map_tour.tscn`，按 F6 巡览。

仓库正式构建沿用原有 Godot 存档目录，不迁移或删除玩家进度。此前单独交付的本地预览包使用独立存档目录 `LongdanMapPolishPreview`。Canvas 网页版及其存档机制没有改动。

## 地图设计

沿用现有低饱和青绿与土金配色、Q 版角色和长坂剧情。把路线、庭院、地标作为一套系统打磨：

- 溃军山道：连接营火与荒村出口，增加石阶、山脊营地和望乡石。
- 荒村小巷：救援庭院、主街门楼与西巷路标，补上医者支路及街巷回环。
- 破庙夺剑：石板庭院、祭坛与旧碑，接通侧门小径和主庭院。
- 井畔旧宅：围绕旧井组织院落铺地、灯柱和绕行小路。
- 粮道岔口：主路与粮营间形成回环，路牌、粮架和营旗明确支路方向。
- 北桥决战：桥头门楼、河岸、石桩和营地平台；东侧通路仍受原焚粮剧情条件控制。

军图使用当前区域实际烘焙地面，主路与支路采用不同线型；出口、营火、救援点、守将与粮营采用不同符号。编号图例标记通行/完成状态，视野框在地图边缘按真实摄像机裁切。

新地标的实体碰撞与寻路使用同一份数据。地表离线烘焙，地标按脚底位置参与现有 Y 排序。战斗数值、敌群、章节条件和原始 `chapter1.json` 没有改动。

## 编辑与重建

- `godot/data/map_details.json`：新增道路、支路、庭院、地标及局部碰撞体。
- `godot/scripts/map_details.gd`：确定性合并布局与绘制地面/地标。
- `godot/scripts/world.gd`、`terrain.gd`：载入布局、植被留白、碰撞与导航。
- `godot/scripts/map_view.gd`：大小军图与图例。
- `godot/assets/maps/*.png`：Godot 从源码重新烘焙的六区地表。

修改地图美术后，先在 Godot 工程目录运行图形烘焙，再导入：

```powershell
godot --path . --script res://tools/bake_maps.gd
godot --headless --path . --editor --import --quit
```

增加中文内容后，在仓库根目录运行 `python godot/tools/subset_font.py` 重建字体。项目保留原有开源字体及素材许可证。

## 验证与证据

在仓库根目录运行 `./Run-Checks.ps1 -Engine "Godot可执行文件路径"` 可执行导入和游戏、音频、地图及军图验证。省略 `-Engine` 时读取 `GODOT_EXE` 或 PATH。日志在 `.qa/`，临时配置、缓存和存档在 `.qa/runtime/`；脚本只修改当前测试进程的环境变量，结束后恢复。

```powershell
godot --headless --path godot --script res://tests/map_view_verify.gd
godot --path godot --script res://tests/map_capture.gd -- --label=after
godot --path godot --script res://tests/performance.gd -- --label=after-map-polish
```

首轮本地验证保存了 `.qa/before-*.png`、`.qa/after-*.png` 同机位截图，其中改后截图共九张，均由 Godot 实际渲染。`.qa/performance-*.json` 是真实图形后端的短时采样，不能等同于完整章节平均帧率。这些截图和日志属于本地交付证据，不纳入源码仓库；可用上述命令重新生成改后截图和采样。

首轮本地检查结果见 [VALIDATION.md](VALIDATION.md)：776 项自动检查通过，Windows 导出及启动通过。该阶段的浏览器自动化组件未能启动，因此未完成线上网页的人工玩法与交互回归；新截图均来自本机 Godot，不能视为浏览器验证。
