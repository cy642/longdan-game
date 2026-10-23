# 《龙胆：逆命三国》绘画环境资产与重建流程（0.6.0）

日期：2026-10-23。本页承接 [地图美术规范](MAP-ART-DIRECTION.md)，记录 0.5.0 环境原画与 0.6.0 箕谷独立构图如何进入三章十八个区域。关卡的道路、地标、碰撞和剧情坐标由章节数据及 Godot 脚本决定；原图与烘焙贴图是可见表现的来源。

## 原画与可编辑源

0.5.0 使用内置 `image_gen` 模式生成四张原图；0.6.0 箕谷沿用这些来源，并在可编辑 Godot 布局中新增崖谷、横向栈桥和石门构图。最终生成提示词逐项保存在 `godot/art_source/painted/PROMPTS.json`，四张 `*-source.png` 均保持生成后的原始像素，未在 PNG 上涂改。后续调整需更新提示词及源图，或明确记录新增的可编辑加工源，不能仅覆盖烘焙结果。

| 文件 | 实际内容 | 使用处 |
| --- | --- | --- |
| `architecture-source.png` | 村舍、残屋、庙堂、门楼、两类军帐、宽岩脊、粮架 | 长坂与汉水的建筑及道具图集 |
| `nature-source.png` | 风蚀树、枯树、柏树、柳树、竹、灌木、小石、短岩脊 | 分区树种、石块和岩壁图集 |
| `materials-source.png` | 干土、湿泥、页岩、旧院石、草土、竹林腐殖层六格俯视地表 | 离线地表烘焙 |
| `utility-source.png` | 祭坛、旧碑、井、灯柱、栅栏段、独立木桩、船架、桥板原画 | 地标与汉水营栅、船架；桥板本轮未接入 |

建筑、自然和道具三张透明图的实际尺寸均为 1774×887；地表图为 1536×1024。不要按生成提示词中请求的画布尺寸或等分网格直接裁切透明图：图上物件的实际边界并非整齐的 512 像素单元。

`godot/art_source/painted/props-manifest.json` 记录目前接入的 **23 帧**：建筑 8 帧、自然 8 帧、道具 7 帧。每帧指定所属原图、候选矩形、物体内部种子点、脚底接触点、原画占地宽及游戏目标宽。`godot/scripts/painted_props.gd` 在烘焙时从种子点按 alpha 连通区域临时抽帧，避免相邻图形的边角混入；源 PNG 不被切割或覆写。`utility-source.png` 的桥板因透视与当前竖向桥面不匹配，保留在原图但不列入这 23 帧。

脚底接触点是场景排序与落地感的基准。手绘房屋、帐篷、树木和岩石被画进 `scenery.png` 图集；汉水的竹、岩壁、粮架、栅栏、船架被画进 `hanshui_props.png`。营栅横段按原画短段连续摆放，竖段由单桩组合，不能将一整段原画任意拉长。未覆盖的旧形状继续使用 Godot 原生绘画作后备。

## 地表与地标

`godot/scripts/painted_ground.gd` 仅在离线烘焙中读取六格地表图。它把源纹理采样到道路、院落和局部地表的既有多边形：镜像采样与不同方向的第二层采样缓解接缝和重复；按区域底色混合并维持较低对比度；边缘由细分网格按距原多边形边界的距离渐隐。这是画面蒙版，不扩大道路、院落或碰撞区域，也不在正式游戏中逐帧执行材质 shader。运行时加载烘焙后的十八张 RGB 地表 PNG。

旧四件直立地标——祭坛、旧碑、粮架和灯柱——保留原来的 `assets/props/altar.png`、`stela.png`、`grain_rack.png`、`lantern.png` 路径与图像尺寸。`godot/tools/bake_painted_landmarks.gd` 用新原画重写像素，但沿用 `landmarks.json` 中的脚底锚点、绘制偏移和仅供对照的碰撞元数据；实际碰撞仍由 `data/map_details.json` 决定。门楼三种跨度和井另烘焙为 `assets/props/painted_markers.png` 与 `painted_markers.json`，在原地标脚点显示。高屋檐、灯臂和接触阴影不自动成为实体。

`godot/art_source/map_landmarks.blend` 及 `regenerate_landmarks.py` 仍保留为可编辑的旧 Blender 方案和回退来源。Blender 再生脚本会重写上述四张地标 PNG 与清单；若执行它，必须随后重跑手绘地标烘焙，才能恢复本版可见资产。

## 完整重建顺序

从仓库根目录运行下列命令。四个烘焙步骤需要可用的 Godot 图形渲染器，并应依次运行；`--headless` 仅用于贴图导入与不需要 GPU 的验证。

```powershell
godot --path godot --script res://tools/bake_painted_landmarks.gd
godot --headless --path godot --editor --import --quit
godot --path godot --script res://tools/bake_maps.gd
godot --path godot --script res://tests/hanshui_layout_verify.gd -- --bake
godot --path godot --script res://tools/bake_jigu.gd
godot --headless --path godot --editor --import --quit
```

顺序不能倒置：先生成四张地标 PNG 与 `painted_markers` 图集并导入，让后续世界节点能够加载新图集；再生成第一章地表及共享 `scenery` 图集、第二章地表及汉水道具图集、第三章地表及箕谷道具图集，最后再次导入更新的 PNG。井的原点仍是井圈中心，绘画脚点下移 25 像素对齐前沿，并隐藏旧几何井；糜夫人仅调整肖像位置以免被井架遮住，互动坐标不变。烘焙后仍需用正常镜头检查十八区的脚点、遮挡、通路、战斗预警和地标辨识，再进行 Web 导出与线上试玩。实际验收结果记录在 `CLOUD-POLISH.md`。

## 第三章独立重建入口

`godot/data/chapter3.json` 的 `layout` 包含箕谷的通路、峡谷、石门与景物落脚点；`godot/scripts/jigu_layout.gd` 负责崖面、木板连接、石门和桥柱等可编辑绘制。主地表使用冷灰石屑与枯草，并为横向栈道、危桥留下明确负空间；不复制汉水地表后仅更换颜色。

只修改第三章时，运行 `godot --path godot --script res://tools/bake_jigu.gd`，再运行一次 headless 编辑器导入即可。工具生成六张 `assets/maps/jg_*.png` 与 `assets/maps/jigu_props.png/json`，检查景物帧为空或被裁边时失败。图集的当前帧数、裁切与脚锚以生成的 JSON 为准；断索/完整桥柱通过同一清单中的不同帧切换，不把运行状态写回源图。

修改 `layout` 后还要执行 `tests/jigu_layout_verify.gd` 与 `tests/jigu_flow_verify.gd`，确认实体通路、交互可达和桥头决定不把玩家留在无路可走的位置。`Map-Tour.cmd` 的 Tab 可切到第三章，F1–F6 查看六区；空地图巡览不能替代箭阵、留桥追兵和玄甲先锋预警的实际战斗镜头。具体图形、性能和发布结果由开发记录单独记载。

`godot/art_source/.gdignore` 使原图、提示词和 Blender 文件留在制作侧。发行时使用 `godot/assets/maps` 与 `godot/assets/props` 的烘焙图及清单；不要让运行时依赖 `art_source`。
