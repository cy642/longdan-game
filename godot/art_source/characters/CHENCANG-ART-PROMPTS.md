# 陈仓夜袭原画生成记录（2026-10-26）

本轮只交付三张原画，未修改关卡代码、碰撞、剧情或烘焙图集。使用内置 `image_gen`，每次设 `transparent_background: true`，不使用 CLI/API 付费后备。赵云与旧敌兵/建筑原画均只作画风参照；以下 PNG 是生成后直接复制到项目的原始输出，**没有修边、重绘或拼接**。

| 目标源图 | 内置工具原始输出路径 | 实际尺寸 | SHA-256 |
| --- | --- | --- | --- |
| `godot/assets/enemies/chencang-v1.png` | `C:/Users/36799/.codex/generated_images/01a11927-59c6-75c3-86f0-18b10b620a0c/exec-d7fd53ae-1f1d-4f2d-a98c-d9d405cc0ce9.png` | 1536×1024 RGBA | `f357641073f0eaf4fa557016fb11e7cbaa4c1e9fc219a4845753e9281cb5f9df` |
| `godot/assets/enemies/warden-v1.png` | `C:/Users/36799/.codex/generated_images/01a11927-59c6-75c3-86f0-18b10b620a0c/exec-cae8b475-b545-4667-83ff-70a80674fe59.png` | 1254×1254 RGBA | `4b63e4dfe30a6f1aa947640503e6fd2508248548276a352bc81e2d6897b3d7c5` |
| `godot/art_source/painted/chencang-source.png` | `C:/Users/36799/.codex/generated_images/01a11927-59c6-75c3-86f0-18b10b620a0c/exec-7e8f003f-d79a-4aea-a788-e7ce9602fee0.png` | 1536×1024 RGBA | `95d39344c8d1ee0132c16ec0750958d5ca005845f79082f52598eb33ea0f0a60` |

参照输入：`godot/assets/zhaoyun-reference.png`；守军与都尉还参照 `godot/assets/enemies/hanshui-v1.png` 的画风质量，环境参照 `godot/art_source/painted/architecture-source.png`。内置工具把正方形 Boss 请求的 1024×1024 实际输出为 1254×1254，使用实际尺寸制作元数据。

## 抽帧实测与脚点

三张图均有真实 alpha，完全透明像素比例分别约 52.91%、51.04%、47.18%。以 **alpha ≥ 16、八邻域连通**读取，守军为 6 个独立主体，都尉为 1 个主体，城景为 6 个独立主体；无面积 ≥100 像素的其他离散分量。生成器未完全遵守虚拟格安全边距：部分枪、披风、盾和建筑檐角跨到相邻虚拟格，但各主体不相连。**不要按 512×512 等格硬裁**；按下表的种子提取主连通分量并保留完整包围框。原图底色的 RGB 即使非零，也不等于背景不透明。所有 `bbox` 为原图全局坐标 `[x0,y0,x1,y1)`，右/下界不包含在内；`seed` 在对应主体内部。

| 来源 | 顺序 / ID | seed | bbox |
| --- | --- | --- | --- |
| 守军 | `sword` 城关陌刀手 | `[294,304]` | `[46,106,534,530]` |
| 守军 | `spear` 门楼槊卫 | `[805,381]` | `[469,12,1001,529]` |
| 守军 | `scout` 夜巡双刃 | `[1253,249]` | `[1075,138,1527,529]` |
| 守军 | `crossbow` 楼台弩手 | `[329,727]` | `[16,558,481,992]` |
| 守军 | `ironshield` 城砖重盾卫 | `[865,788]` | `[529,515,1029,993]` |
| 守军 | `orders_crossbow` 关印弩卫 | `[1351,823]` | `[1056,542,1523,992]` |
| 都尉 | `warden` 镇关都尉 | `[470,718]` | `[75,112,1238,1173]` |
| 环境 | `city_gate` | `[184,279]` | `[34,65,571,517]` |
| 环境 | `beacon_tower` | `[785,367]` | `[587,56,989,534]` |
| 环境 | `warehouse` | `[1226,303]` | `[997,82,1521,505]` |
| 环境 | `drum_tower` | `[248,823]` | `[72,492,524,984]` |
| 环境 | `wall_segment` | `[878,841]` | `[560,620,995,972]` |
| 环境 | `supply_crates` | `[1262,801]` | `[1037,621,1494,962]` |

环境图原图全局的**视觉脚点候选**依序约为 `(302,510)`、`(790,528)`、`(1260,500)`、`(300,978)`、`(777,966)`、`(1265,956)`；这些是观图估计，需在实际 atlas 缩放与碰撞矩形下校准。烽台**空火盆开口中心**约为原图全局 `(770,91)`，熄灭态源图未画火焰；程序若加火焰，按烽台的原图裁切与缩放变换该点，别把原图直接当世界坐标。都尉双手握一根完整长柄、矩形锤头清楚；三张源图均未出现恐怖元素或额外地面。

## 实际最终提示词

### 六名陈仓守军

参数：`transparent_background: true`；参照图依次为 `zhaoyun-reference.png`、`hanshui-v1.png`。

```text
Use case: stylized-concept. Asset type: ONE professional 2D character sprite atlas for the fourth chapter of a Chinese Three Kingdoms chibi action RPG. Image 1 (blue-scarf Zhao Yun) is a STYLE REFERENCE ONLY for expressive 2.5-head proportions, elegant fine dark outlines, crisp cel shading, painterly highlights and polished face/armor details. Image 2 (previous Hanshui enemy roster) is a STYLE/QUALITY REFERENCE ONLY; these six Chencang city-defenders must be genuinely DIFFERENT faces, physiques, helmets, clothing shapes and weapons, not recolors or copies of that roster. No Zhao Yun himself.
Create ONE landscape 1536x1024 image with ACTUAL TRUE TRANSPARENT RGBA alpha background. An imaginary precise 3-column × 2-row layout, exactly one full-body character in each cell, in this row-major order. IMPORTANT safe spacing: each complete character including helmet, cloak, sword, spear point, shield and crossbow must stay near the CENTER of its own cell with at least 65px transparent space to all four cell edges; no character or weapon touches or crosses into the next cell. No lines, grids, text, labels, symbols, ground, cast shadows, night sky, haze, aura, checkerboard or gradient. Feet near 84% height of each cell; two feet clearly planted, torso upright in a ready battle stance facing SCREEN LEFT at three-quarter view. Long weapons diagonally up and INSIDE their own cell, no blade below foot level. Cute but credible 2.5-head proportions with large expressive heads. Night city garrison color story: readable cool steel blue-grey and slate over charcoal, restrained dark cinnabar cloth and warm copper edges; lit faces and weapons remain visible, never all-black or horror.
TOP LEFT: CHENCANG broad-backed short-DAO guard, adult muscular build, CLOSE-CROPPED hair not a headscarf, square face, thick-backed SHORT dao gripped with BOTH hands, city patrol split coat.
TOP MIDDLE: gatehouse long-SHUO spear guard, notably tall narrow neck-guard helmet, long thin face, one COMPLETE long Chinese lance with visible whole straight shaft and spear tip held diagonally upward, no other weapon.
TOP RIGHT: low-standing night-patrol DOUBLE-BLADE scout, small snug hood and short jacket, quick lean young body, TWO complete short knives, one each hand, neither knife below feet; no helmet plume.
BOTTOM LEFT: tower crossbowman, flat-topped crenellation-like helmet, focused long-eyed face, both hands holding ONE COMPLETE HORIZONTAL CROSSBOW with full left/right bow limbs, long stock, trigger and bolt, compact shoulder ammunition case; no ordinary bow.
BOTTOM MIDDLE: city-brick heavy TOWER-SHIELD soldier, WIDE heavy body, thick layered plate armor, severe rectangular face, giant SQUARE rectangular shield braced forward, ONE short dao clearly visible in free hand. Much heavier than the other five.
BOTTOM RIGHT: ORDER-SEAL crossbow warden, older MIDDLE-AGED face with short WHITE STUBBLE, small SHORT COURT CROWN and narrow shoulders, robe-like armor and a rolled order scroll at belt, one complete horizontal crossbow held differently from bottom-left. NOT a recolored ordinary crossbowman, no huge shield.
Each figure one head, two hands, two visible legs and two feet. Complete correct weapons with clear uninterrupted silhouettes. No extra characters.
```

### 镇关都尉

参数：`transparent_background: true`；参照图依次为 `zhaoyun-reference.png`、`hanshui-v1.png`。

```text
Use case: stylized-concept. Asset type: ONE complete transparent 2D BOSS sprite for a Chinese Three Kingdoms Q-version action RPG. Image 1 (blue-scarf Zhao Yun) is STYLE REFERENCE ONLY for expressive oversized head, refined dark ink contours, crisp cel shading and softly hand-painted gleam. Image 2 (prior enemy roster) is a production quality reference only. Invent an entirely DISTINCT new commander, not a recolor or copy of either image or of a prior axe/halberd boss.
Subject: 镇关都尉, the Chencang city-gate warden. A mature middle-aged man with a sturdy SQUAT massive body, extra broad shoulders, short dark stubble but no long beard, stern human face still appealing and not terrifying, a distinctive crenellated BATTLEMENT-SHAPED short helmet crown, short heavy shoulder cape, blackened copper and dark iron lamellar with warm bronze joins, dusty dark red waist cloth. About 2.5 heads tall, oversized head approx 36% of figure, short sturdy legs and TWO completely visible planted boots.
MOST IMPORTANT SILHOUETTE: he wields exactly ONE two-handed LONG-HANDLED HEAVY WAR HAMMER; BOTH hands visibly grip the SAME shaft. The complete straight pole is visible from grip to a HUGE clearly RECTANGULAR solid iron hammer head with broad flat striking faces, limited small short BLUNT studs. This is a blocky forging hammer, NOT an axe, halberd, mace ball, spear, skull, hook blade, double weapon, or a shield. The head and pole form one clean uninterrupted object, held diagonally upward so all metal stays ABOVE the boots. He faces SCREEN LEFT in an upright grounded 3/4 battle-ready stance.
Composition: one single full figure centered on a square 1024x1024 RGBA canvas, with the entire cape, crown, both boots and whole hammer at least 90px inside every image edge. Real true transparent alpha everywhere outside the person and gear. No ground, shadow, background, night sky, glow, vignette, text, label, grid, panel, duplicate figure, severed limb or weapon fragments. Muted city night colors remain readable under warm torch light; fine Chinese fantasy illustrated game finish matching Zhao Yun, adventurous not scary.
```

### 六件陈仓环境物

参数：`transparent_background: true`；参照图为 `architecture-source.png`。环境源位于上级 `.gdignore` 的制作侧目录，运行时只应读取另外烘焙的场景图集。

```text
Use case: stylized-concept. Asset type: ONE production transparent prop atlas for a polished 2D top-down Chinese chibi action RPG's Chencang night-city chapter. Image 1 is STYLE REFERENCE ONLY: match its richly hand-painted illustrated building quality, crisp dark contours, carefully shaped grey tiles, layered stone/wood materials, warm highlights and restrained cool shadows. Create six NEW city-fortress props, NOT recolored copies of the reference. No characters.
One LANDSCAPE 1536x1024 RGBA image, true ZERO-ALPHA transparent background; exact 3 columns by 2 rows, one complete isolated prop in each imaginary 512x512 cell in row-major order. Each prop must fit comfortably centered INSIDE its own cell with at least 45px totally empty transparent gutter at every cell boundary; no touching other objects. Fixed consistent 45-degree gentle oblique top-down game camera, orthographic, front facade and a little roof visible, level horizontal foot contact at bottom center. Standalone cutout props, no painted ground/floor plane, no cast shadow, no night sky, no backdrop gradient, no labels/text/symbols/gridlines/borders/glow. Clean complete bases with ground-contact foot points. Similar small-scale visual density to Image 1. Night-fortress palette: weathered slate blue-grey brick and grey clay roofs, muted copper wood and metal, TINY restrained warm lamp windows; keep silhouettes well lit and readable, not black/dark.
EXACT SIX OBJECTS:
TOP LEFT city_gate: compact GREY-BRICK ARCH GATE with a real OPEN PASSAGE, two MODEST side gatehouse towers, small grey roof eaves; front clearly reads as city gate. Balanced width within one cell, NOT an enormous spanning wall, no banner/flag, no door blocking the passage.
TOP MIDDLE beacon_tower: square grey-brick BEACON WATCH TOWER with visible stepped base and accessible upper rim, a completely EMPTY / UNLIT metal BRAZIER at the top; absolutely NO flame, ember, smoke, glow or fire, because gameplay controls ignition later.
TOP RIGHT warehouse: LOW broad city grain-and-armaments WAREHOUSE, weathered grey tile roof, short wooden loading doors, robust low walls, one small warm slit window; distinct from a cottage/tent.
BOTTOM LEFT drum_tower: compact TWO-STOREY grey-tiled military DRUM TOWER with timber supports and exactly ONE visible large hanging war drum, detailed but not skyscraper-tall; the drum must be identifiable after downscaling.
BOTTOM MIDDLE wall_segment: one SHORT freestanding section of weathered grey-brick CRENELLATED PARAPET wall, 3-4 distinct battlements, modest width, square feet and chipped masonry; not a full-screen unbroken fortification.
BOTTOM RIGHT supply_crates: one coherent stockpile cluster of wooden supply boxes, shallow arrow cases and a short shield rack with TWO readable shields, tied ropes and weathered timber grain; all in one joined compact object.
All six are dimensionally grounded with shared camera, charming but plausible Han-era military craft, detailed hand-painted illustration not low-poly cuboids, flat vector, photorealism or overgrown ruins. No extra objects or fragments.
```
