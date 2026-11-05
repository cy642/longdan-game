# 长坂坡 · 第三人称 3D 试玩

[在线试玩](https://cy642.github.io/longdan-game/changban-3d-play/) · [标题实景](../docs/images/changban-3d-title.jpg) · [战斗动图](../docs/images/changban-3d-action.webp)

这是《龙胆：逆命三国》第一关的独立三维试做，面向电脑键盘和鼠标。这版把长坂坡浓缩成一条可连续步行的路线，从山道进残村，再到北桥。一次出战结束后可重新开始。

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
| 闪身 / 接应 | 空格 / E |
| 暂停、重试、声音开关 | Esc 打开暂停菜单 |

## 运行与导出

用 Godot 4.7.2 打开本目录的 `project.godot`，按 F5。兼容渲染器同时用于 Windows 和 WebGL 2。模型、贴图和字体均随包提供，Windows 包可以离线运行。网页首次打开需要下载引擎与关卡。

从仓库根目录运行以下命令，`godot` 指本机 Godot 4.7.2 可执行文件。导出前安装该版本的导出模板，并创建 `builds/Changban3D` 和 `changban-3d-play` 两个目录。

```sh
godot --headless --path changban-3d --editor --import
godot --headless --path changban-3d --fixed-fps 60 --script res://tests/battle_verify.gd
godot --headless --path changban-3d --fixed-fps 60 --script res://tests/ride.gd
godot --headless --path changban-3d --export-release "Windows Desktop"
godot --headless --path changban-3d --export-release Web
```

Windows 导出目标为 `builds/Changban3D/Longdan-Changban-3D.exe`，网页导出目标为 `changban-3d-play/index.html`。网页导出目录需要通过 HTTP 服务访问。2D 正篇使用独立的 `godot-play/` 发布目录和存档。

## 后续开发

| 文件 | 职责 |
| --- | --- |
| `longdan.tscn`、`expedition.gd`、`field_hud.gd` | 场景、光照、镜头避障、键鼠输入与界面 |
| `battle.gd`、`battle_fx.gd`、`battle_audio.gd`、`battle_traveller.gd` | 战斗、预警、音效、抱婴与护送 |
| `hero_visual.gd`、`art/characters/` | 赵云与三种敌人的分节模型、眼部贴画、双手持枪和步态 |
| `pass_landscape.gd`、`art/landscape/`、`wind.gd` | 村镇、树林、石井、木桥、河水、军旗、烟尘和三层远山 |
| `tests/battle_verify.gd`、`tests/ride.gd` | 战斗与护送边界，以及从标题启动到通关、失败重试的输入回归 |

角色、枪盾、乡民、襁褓、场景模型、地面与军旗贴图以及战斗声音均为本次制作。地形生成器是 `art/landscape/bake_pass.py`。需要重建 GLB 时使用 Python、Pillow、NumPy 和仓库中的军旗用字字体，日常开发可直接使用已烘焙的文件。界面字体来自 Noto，授权见 `art/ui/OFL.txt` 和 `art/ui/NOTICE.txt`。
