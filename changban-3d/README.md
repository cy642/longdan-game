# 长坂坡 · 第三人称 3D 试玩

[在线试玩](https://cy642.github.io/longdan-game/changban-3d-play/) · [动作同机位前后对比](../docs/images/changban-3d-motion-02.webp) · [关卡实机动图](../docs/images/changban-3d-action.webp)

**0.2.0 · 长坂枪术**是《龙胆：逆命三国》第一关的独立三维试玩，面向电脑键盘和鼠标。从山道经村井到北桥可以连续步行，一次出战结束后可重新开始。

## 路线与操作

1. **山道**。枪兵会绕侧逼近。盾兵能格挡正面的轻枪，可用重枪破盾，或绕到侧后方出手。
2. **残村**。找到抱着阿斗的乡民，在近处按 E。襁褓会移到赵云身上，乡民一路跟随。
3. **北桥**。守将交替使用大范围横扫与直刺。观察脚下预警和抬手动作，等他出招落空再贴身还击。
4. **北岸**。带阿斗过桥，并等乡民也走下桥面。

| 操作 | 按键 |
| --- | --- |
| 移动 | WASD，方向随镜头变化 |
| 转镜头 / 调整远近 | 右键拖动或左右方向键 / 滚轮 |
| 出枪 / 重枪 | J 或鼠标左键 / K 或 Q |
| 游龙回锋 | R，横扫破盾后向前直刺，冷却 7.5 秒 |
| 回马枪 | 敌人出手前一瞬按空格闪身，出现提示后 1 秒内按 J |
| 闪身 / 接应 | 空格 / E |
| 暂停、重试、声音开关 | Esc 打开暂停菜单 |

## 运行与导出

用 Godot 4.7.2 打开本目录的 `project.godot`，按 F5。兼容渲染器同时用于 Windows 和 WebGL 2。模型、贴图和字体均随包提供，Windows 包可以离线运行。网页首次打开需要下载引擎与关卡。

从仓库根目录运行以下命令，`godot` 指本机 Godot 4.7.2 可执行文件。导出前安装该版本的导出模板，并创建 `builds/Changban3D` 和 `changban-3d-play` 两个目录。

```sh
godot --headless --path changban-3d --editor --import
godot --headless --path changban-3d --fixed-fps 60 --script res://tests/motion_verify.gd
godot --headless --path changban-3d --fixed-fps 60 --script res://tests/battle_verify.gd
godot --headless --path changban-3d --fixed-fps 60 --script res://tests/ride.gd
godot --headless --path changban-3d --export-release "Windows Desktop"
godot --headless --path changban-3d --export-release Web
```

Windows 导出目标为 `builds/Changban3D/Longdan-Changban-3D.exe`，网页导出目标为 `changban-3d-play/index.html`。网页导出目录需要通过 HTTP 服务访问。2D 正篇使用独立的 `godot-play/` 发布目录和存档。

0.2.0 的正式关卡包通过了 861 项动作断言和 46 项战斗断言。完整输入回归从标题启动，在山道和北桥使用枪技，接回阿斗，等乡民踏上北岸后结算，并验证失败重试。上面的动作对比用同一取景和时间线演示两版步态与出枪，关卡动图取自实际输入回归。动作、战斗与通关流程均可按上面的命令复查。

## 后续开发

| 文件 | 职责 |
| --- | --- |
| `longdan.tscn`、`expedition.gd`、`field_hud.gd` | 场景、光照、镜头避障、键鼠输入与界面 |
| `battle.gd`、`battle_fx.gd`、`battle_audio.gd`、`battle_traveller.gd` | 战斗、预警、音效、抱婴与护送 |
| `hero_visual.gd`、`art/characters/` | 赵云与三种敌人的分节模型、眼部贴画、双手持枪和步态 |
| `pass_landscape.gd`、`art/landscape/`、`wind.gd` | 村镇、树林、石井、木桥、河水、军旗、烟尘和三层远山 |
| `tests/motion_verify.gd`、`tests/battle_verify.gd`、`tests/ride.gd` | 检查脚底接触、双手与枪杆的距离、技能命中与冷却，并经正常输入完成护送、结算和重试 |

角色有独立的脚踝、双手和披巾。前脚落地后按世界坐标稳住脚掌，转腰时两只手始终沿同一根枪杆求解。R 的横扫和直刺分别判定范围和命中，刺中敌人会在受击处扬起枪芒。普通出枪的短残影取自模型枪尖的真实轨迹。

村屋、树冠和土路从仓库内 `godot/art_source/painted/` 的 2D 原画取材，重新贴到弯瓦、破墙、枝叶和路面上。模型生成器是 `art/landscape/bake_pass.py`。重建 GLB 需要 Python、Pillow、NumPy、上述原画以及仓库中的军旗用字字体。日常运行直接读取已烘焙的文件。

赵云的[材质图集](art/characters/zhaoyun-pigment.png)按头发、银甲、衣料、蓝绸分成四区，参考原项目的 2D 赵云形象，用内置 imagegen 生成，模型曲面和 UV 布局在工程中制作。界面字体来自 Noto，授权见 `art/ui/OFL.txt` 和 `art/ui/NOTICE.txt`。

<details>
<summary>角色图集生成提示词</summary>

Create a square production UV texture atlas, edge-to-edge four exact equal square material swatches, arranged strictly in a 2 by 2 grid with boundaries at x50% y50%, no gutters, typography, labels, margin, exterior outlines, isolated objects or background. Use the supplied illustration only as colour/material reference. Stylized cel-painted anime Chinese hero costume with sophisticated drawn highlights and painterly shadow of a premium hand-painted adventure RPG. TOP LEFT: the surface of a single chestnut hair lock flat painted unwrapped texture, rich dark auburn, sweeping vertical fine-to-coarse tapered grouped strands running TOP to BOTTOM, warm honey highlights crossing some strands near upper third, darker side edges. TOP RIGHT: flat metallic silver-blue pauldron surface with an elegant clearly legible embossed bilateral Han cloud-scroll swirl pattern, navy engraved strokes in satin silver, softly luminous cool ivory ridges, brushed blue shadow; fill entire square with metal. BOTTOM LEFT: flat indigo blue silk armor skirt textile with restrained pale silver-blue Han geometric wave embroidery along bottom edge, broad painted folds running vertically, dark blue shadow warmer lifted highlights. BOTTOM RIGHT: flat cerulean scarf silk texture, broad and graceful billowing swooshes flowing from TOP to BOTTOM, deep lapis along left edge and sky-cyan highlights, darker shadows; entire square is fabric. Each square is a single flat surface, no perspective, no full character, no examples of finished item, perfectly aligned quadrants, digital hand painting, controlled broad values still readable at a tiny in-game size.

</details>
