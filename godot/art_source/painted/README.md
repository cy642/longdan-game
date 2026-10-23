# 手绘环境原画（0.5.0，2026-10-23）

此目录保存内置 `image_gen` 模式生成的原始素材与最终提示词。`PROMPTS.json` 是四张原图的提示词集合；`architecture-source.png`、`nature-source.png`、`materials-source.png`、`utility-source.png` 保持生成输出原样，尚未手工修改源 PNG。这里是制作源，不是运行时贴图；上级目录的 `.gdignore` 阻止 Godot 将其导入或导出。

`props-manifest.json` 登记三张透明图中已使用的 23 个物件（建筑 8、自然 8、道具 7）。每项以 `source_rect` 给出候选区域，以 `source_seed` 定位该物体的 alpha 连通分量；`source_foot` 是相对候选区域的脚底接触点，`source_footprint_width` 与 `target_footprint_width` 控制等比缩放。透明图实际为 1774×887，不能按规则网格粗裁；相邻物件的边界甚至可能交叠。`materials-source.png` 实际为 1536×1024，按 3×2、每格 512×512 读取六种俯视地表。道具图中的桥板暂未使用。

烘焙辅助脚本 `godot/scripts/painted_props.gd` 会在内存中隔离所需连通分量，不修改原图。公共接口为 `PaintedProps.draw_named(canvas: Node2D, id: String, target_foot: Vector2, footprint_width: float, tint: Color = Color.WHITE) -> bool`；坐标是目标节点的本地脚点，宽度是游戏世界像素。`draw_scenery` 和 `draw_hanshui` 由两套场景图集的烘焙分支调用。`painted_ground.gd` 对六格纹理使用离线 shader、按旧地表轮廓生成边缘渐隐蒙版；发行游戏只读取已烘焙的地表、场景和道具贴图。

从仓库根目录依次重建：

```powershell
godot --path godot --script res://tools/bake_painted_landmarks.gd
godot --headless --path godot --editor --import --quit
godot --path godot --script res://tools/bake_maps.gd
godot --path godot --script res://tests/hanshui_layout_verify.gd -- --bake
godot --headless --path godot --editor --import --quit
```

第一步替换四张旧地标 PNG，但沿用 `assets/props/landmarks.json` 的原锚点与尺寸，并写入 `painted_markers.png/.json`（门楼三种跨度与井）。现有碰撞、导航与剧情坐标由 `data/` 和 Godot 场景逻辑掌管，修改绘画源不得暗改它们。`godot/art_source/map_landmarks.blend` 与旧 Blender 再生脚本继续保留作回退；如果重跑 Blender 再生，须重新运行上述第一步并按完整顺序烘焙，避免把旧 PNG 混入发行版。

完整美术说明见 `docs/PAINTED-ENVIRONMENT.md`。完成重建后仍需逐关图形检查、游戏回归、导出和线上试玩；本文件不记录验收结论。
