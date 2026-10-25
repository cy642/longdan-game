# 敌兵与将领原画生成记录（2026-10-25）

本轮只制作原画，不在源 PNG 上重绘、拼接或修边。使用内置 `image_gen`，参数 `transparent_background: true`；输入 `godot/assets/zhaoyun-reference.png` 仅作赵云 Q 版的画法参考，人物本身不得复用。四张交付图均为 **1536×1024 RGBA**，保留在 `godot/assets/enemies/`；内置工具的原始输出也留在 `C:/Users/36799/.codex/generated_images/01a11927-59c6-75c3-86f0-18b10b620a0c/`。

| 项目原画 | 原始输出文件 | 顺序 |
| --- | --- | --- |
| `godot/assets/enemies/changban-v1.png` | `exec-0119be44-aae6-4217-a787-cbe99593f460.png` | 3×2：短刀追兵、长矛征卒、猎弓手；藤圆盾短刀兵、盾阵校尉、荒村斩刀兵 |
| `godot/assets/enemies/hanshui-v1.png` | `exec-74470f62-3c5c-45f1-b256-bb35da9fadee.png` | 3×2：`sword`、`spear`、`scout`；`crossbow`、`ironshield`、`beacon_crossbow` |
| `godot/assets/enemies/jigu-v1.png` | `exec-1cbb6fc0-fa98-4dc9-9a34-a35e173bbd63.png` | 3×2：`sword`、`spear`、`scout`；`crossbow`、`ironshield`、`signal_crossbow` |
| `godot/assets/enemies/commanders-v1.png` | `exec-dce321d3-2d0a-4c3e-9b81-37bac06bc78c.png` | 2×2：夏侯恩、张郃；铁面督军、玄甲先锋 |

项目中四份源 PNG 的 SHA-256：

| 文件 | SHA-256 |
| --- | --- |
| `changban-v1.png` | `691495feabfa73428bf74e1d1689f93d15056d3c48042a6b856a0ff218c26fcb` |
| `hanshui-v1.png` | `f531327a6dd148431a7482fc1fd0f4d36d6a1371517cd519901ee397f7ad264c` |
| `jigu-v1.png` | `7232aead7810315e0d13ced59dd2ff0f1676b85fbf3e5c94902cc27dd4dfc9f9` |
| `commanders-v1.png` | `cfc72ac2b3d4727291a46dfccfd9cb7cfe3b4dc0759b32f7997e76da501d5b91` |

## 抽帧实测

四张图的四角 alpha 均为 0。以 alpha ≥ 16、八邻域连通得到的主体数依次为 6、6、6、4；每个人物及完整武器连在自己的主分量中。**生成器未严格遵守虚拟格边距**：个别披风、刀、盾和长武器跨过 512 或 768 像素的列界数十像素，第一排足部也贴近 512 像素行界。因此不可用等格矩形硬裁；须以本表的内部种子选出对应 alpha 连通分量，再保留其完整 bbox 和透明外边距。这里的 `bbox` 为 `[x0,y0,x1,y1)`，坐标在原图上；这是定位数据，不改变原画。

| 原画 | 槽位 | 主体种子 `[x,y]` | 主体 bbox `[x0,y0,x1,y1)` |
| --- | --- | --- | --- |
| 长坂 | 短刀追兵 | `[296,192]` | `[55,71,542,495]` |
| 长坂 | 长矛征卒 | `[799,264]` | `[531,38,957,496]` |
| 长坂 | 猎弓手 | `[1305,197]` | `[1060,45,1492,496]` |
| 长坂 | 藤圆盾短刀兵 | `[337,767]` | `[41,546,541,963]` |
| 长坂 | 盾阵校尉 | `[865,790]` | `[560,507,1036,965]` |
| 长坂 | 荒村斩刀兵 | `[1301,643]` | `[1059,529,1504,965]` |
| 汉水 | 营刀手 | `[250,214]` | `[53,118,451,519]` |
| 汉水 | 营枪卒 | `[761,205]` | `[497,76,964,521]` |
| 汉水 | 双刀斥候 | `[1230,230]` | `[1082,94,1491,521]` |
| 汉水 | 横弩兵 | `[311,790]` | `[30,579,479,971]` |
| 汉水 | 铁塔盾步 | `[843,794]` | `[515,532,1001,975]` |
| 汉水 | 辎重强弩手 | `[1334,818]` | `[1006,535,1515,972]` |
| 箕谷 | 山刀手 | `[285,229]` | `[38,72,501,510]` |
| 箕谷 | 山矛卒 | `[800,231]` | `[512,40,1005,510]` |
| 箕谷 | 双刃斥候 | `[1265,239]` | `[1089,134,1500,510]` |
| 箕谷 | 谷道劲弩手 | `[293,671]` | `[35,557,487,963]` |
| 箕谷 | 山地塔盾兵 | `[857,786]` | `[534,519,1009,963]` |
| 箕谷 | 号旗弩手 | `[1293,773]` | `[1049,551,1506,963]` |
| 将领 | 夏侯恩 | `[410,162]` | `[188,12,723,502]` |
| 将领 | 张郃 | `[1184,343]` | `[835,9,1498,507]` |
| 将领 | 铁面督军 | `[436,746]` | `[27,529,778,1005]` |
| 将领 | 玄甲先锋 | `[1188,799]` | `[812,513,1520,1007]` |

上述阈值只用于定位；抽取时可从种子保留原 RGBA 像素和必要的柔和轮廓。透明区像素的 RGB 可能仍含生成器预览底色，不应把 RGB 误认为不透明背景。实际脚点和武器刚性区域请按可见轮廓另行标定，不要用 bbox 底边自动代替两脚接触点。

## 本轮最终提示词

以下保存所选图对应的实际文字。长坂使用独立完整提示词；汉水与箕谷的实际提示词分别由「兵种共同前缀」直接拼接对应章的后缀；四将使用独立提示词。每次调用均附同一张赵云风格参考图，并设 `transparent_background: true`。

### 长坂（所选版本）

```text
Use case: style-transfer / stylized-concept. Image 1 is STYLE REFERENCE ONLY: adopt its adorable high-finish Q-version Chinese fantasy game character rendering, expressive LARGE eyes, oversized head, crisp dark ink edges, softly painted cel-shaded hair, cloth and armor. DO NOT include or recolor the blue-scarfed hero in Image 1. Create an entirely new production transparent sprite atlas with six DISTINCT enemy designs.
Format: landscape 1536x1024 RGBA, ACTUAL ZERO-ALPHA TRANSPARENT background (no gradients, vignette, aura, checkerboard, or ground), exact 3-column × 2-row equal grid, one full-body chibi enemy centered in EACH 512×512 cell. Each figure occupies x=roughly 90 to 420 within its cell and y=roughly 70 to 445 within its cell. At least 55 px empty transparent margin on every cell edge, including weapon tips and feet. Strictly no crossing or touching cell borders. Each has a SINGLE clearly readable oversized head approximately 38% of their own height, compact torso, short but visible two legs and two feet, overall about 2.4 heads tall. Every character in upright standing battle-ready pose, facing SCREEN LEFT three-quarter; all feet land around 85% of cell height, all weapons remain higher than the feet. Friendly adventurous action-game tone, non-horror. Distinct face shapes, headgear, physiques, armor construction and weapon silhouettes—not one body recolored. Polished bright hand-painted highlights as reference, but faction palette weathered earth brown, olive, ochre and muted maroon, no blue scarf or bright blue armor.
EXACT ORDER by cell:
Top-left: skinny pursuit SHORT SABER footman, soft cloth headwrap, light leather-and-cloth chest, short curved dao fully inside cell.
Top-middle: drafted LONG SPEAR conscript, narrow tall rounded helmet, long worried face, quilted ochre tunic, ONE complete upright spear with entire spearhead inside cell; shaft angled safely inward.
Top-right: slender hunter ARCHER, tied-up hair no helmet, leather forearm guards, clearly complete wooden longbow, arrow and back quiver, no spear.
Bottom-left: short stocky rattan ROUND SHIELD and short dao soldier, very wide round face, woven circular shield in left hand, short dao in other.
Bottom-middle: broad heavily armored shield-formation officer, square stern face, bulky iron pauldrons, BIG RECTANGULAR ironwood shield and short straight sword; not like the rattan soldier.
Bottom-right: wiry war-damaged village marauder, jagged broken HALF helmet, ragged leather shoulder drape, ONE broad chopping saber, angular face; distinct from top-left.
No text, title, letters, panels, dividers, arrows, labels, logos, scenery, floor, shadows, extra props or extra characters. No severed or missing feet/hands/weapons.
```

### 汉水、箕谷兵种共同前缀

```text
Use case: stylized-concept. Create ONE professional 2D game sprite atlas as a landscape 1536x1024 PNG with TRUE fully transparent RGBA background, no gradient, glow, vignette, ground, cast shadow, scenery, title, letters, labels, panels, dividers, grid lines or extra characters. EXACT 3 equal columns x 2 equal rows, six separate full-body standing enemies, one per imaginary 512x512 cell in precise row-major order. MAKE THEM SMALL ENOUGH: for each cell, the complete head, hair, garments, weapon and both feet must fit in its central 330px wide x 350px high area with at least 80px empty transparent space to every cell border. Nothing crosses or touches cell boundaries. All face SCREEN LEFT in an upright three-quarter combat-ready stance, with two short but distinct legs and BOTH feet on a common baseline near local y=425; any long weapon points diagonally upward, entirely ABOVE the feet. Style reference image is visual style only: match its cute polished Chinese fantasy Q-version proportions (oversized head approx 40% of figure height, approximately 2.4 heads tall), expressive eyes, crisp dark ink contour, detailed cel-shaded cloth/wood/leather/metal and small hand-painted highlights. Do not copy Zhao Yun's face, blue scarf, silver-blue armor or hairband. Every enemy has a distinctly different face shape, headgear, body build, clothes construction and complete weapon; no single body template recolored. Tone adventurous and appealing, not scary, bloody or realistic.
```

### 汉水后缀

```text
CHAPTER 2 HANSHUI: marsh-river military campaign, navy olive, damp brown, blue-green cloth accents, reed rope and dark iron. SIX EXACT roles:
TOP LEFT: river-camp short-saber fighter, narrow keen face, dark tied cloth kerchief, waterproof oiled vest and split hem, a complete single short saber.
TOP MIDDLE: leg-wrapped camp spearman, high slim silhouette, small riveted cap, long drooping face, ochre wraps on calves and shoulders, one COMPLETE spear with visible long shaft and pointed tip.
TOP RIGHT: agile helmetless scout with TWO short daggers, one in each hand, wiry slim physique, asymmetric headwrap and no shield, no bow, no crossbow.
BOTTOM LEFT: ordinary Han River crossbow infantry, youthful oval face and short hood, two-handed clearly complete horizontal CROSSBOW with a transverse bow limb, stock, trigger, and quarrel. NOT a hand bow, not missing bow limbs.
BOTTOM MIDDLE: heavy IRON TOWER SHIELD foot soldier, broad chest and squared jaw, riveted dark iron lamellar, tall rectangular iron shield covering much torso and a complete short dao visible in other hand; clearly unlike a normal shield soldier.
BOTTOM RIGHT: North Mountain supply BEACON CROSSBOW officer, strong build, half-sized face guard and leather ammo box, distinctly wider crossbow limb with reinforced bow tips, full bow stock and quarrel, mustard mantle; different head and stance from bottom-left crossbow soldier.
All equipment inside its cell. No other archer, shield captain or mounted figure.
```

### 箕谷后缀

```text
CHAPTER 3 JIGU MOUNTAIN PASS: rough highland frontier clothing, layered slate grey, dusty burgundy, ochre, pine accents. SIX EXACT roles, each new design versus other chapters:
TOP LEFT: highland single-saber raider, rugged russet leather coat, asymmetric fur collar, angular narrow face and bare ponytail, one complete mountain dao.
TOP MIDDLE: mountain long-spear soldier, tall narrow felt helmet and crimson spear tassel, thick ankle bindings, long gaunt face; one complete angled spear with entire blade visible.
TOP RIGHT: cliff-climbing scout, deep hood, lightweight rope harness and two distinct short climbing blades in BOTH hands, slim compact silhouette, no shield or bow.
BOTTOM LEFT: crouch-ready but still UPRIGHT standing valley-path crossbowman, quilted hood, narrow intelligent face, one complete reinforced horizontal crossbow in both hands, stock and both crossbow limbs clearly present.
BOTTOM MIDDLE: thick-set mountain TOWER SHIELD soldier, broad plated mountain-iron armor and rugged boots, huge tall slab shield and a short knife visible, distinct helmet with no faceguard.
BOTTOM RIGHT: cliff signal-crossbow ranger, one SMALL signal pennant carried on back fully within cell, patched eye leather guard, a SHORT horizontal crossbow with complete limbs and trigger, different shape and palette from bottom-left crossbowman.
No side weapons drawn below the feet.
```

### 四将

```text
Use case: stylized-concept. Image 1 is STYLE REFERENCE ONLY for a polished Q-version Chinese fantasy action RPG hero. Create ONE landscape 1536x1024 TRUE TRANSPARENT RGBA production sprite atlas of exactly FOUR distinct FULL-BODY enemy commanders in an imaginary 2x2 grid, one centered in each 768x512 cell. Each complete character including hairstyle, mantle, shield or polearm must stay well INSIDE its own cell, with at least 65px transparent gap to all cell edges; no touching/crossing middle lines. No background color, gradients, halo, vignette, shadow, ground, text, labels, borders, panels, extra characters. All face SCREEN LEFT three-quarter view, upright standing fight-ready, two visible feet planted at 85% of each cell's height; weapons entirely above their feet. Chibi 2.5 heads tall with big expressive heads about 37% of body height, richly detailed crisp ink lines, elegant cel shading and painterly highlights matching reference finish. Interesting but not scary or gore. Each has different face shape, physique, armor cut, headgear AND completely distinct weapon silhouette.
TOP LEFT: XIAHOU EN, thin arrogant young noble, narrow sharp face, small short court crown, fine cream and dark red noble lamellar over agile body, TWO COMPLETE SHORT SWORDS held separately, no spear.
TOP RIGHT: ZHANG HE, visibly taller and more elegant proportions, LONG black beard, tall helmet with long pheasant plume, dark jade armor, ONE WHOLE LONG SPEAR with full shaft and spearhead rising diagonally inward, no halberd or second spear.
BOTTOM LEFT: IRON-MASK COMMANDANT, squat massive body and broad shoulders, ONE HALF-face iron mask revealing part of tough face, heavy oxblood iron plates, ONE COMPLETE DOUBLE-BLADED HOOK AXE held above feet with distinct two hooked blades; a SHORT chain attached at wrist, fully visible and not dangling below feet. No shield, no spear.
BOTTOM RIGHT: BLACK-ARMOR VANGUARD, medium-tall and wide-shouldered, severe square face with NO BEARD, distinctive single-horn helmet, complete almost-black layered armor with restrained gold edges, ONE DISTINCT COMPLETE CRESCENT-BLADED LONG HALBERD with full long shaft and curved crescent blade held diagonally above feet. Must NOT resemble Zhang He's plume helmet, beard, green armor, spear or pose.
Weapon counts exact. Distinct silhouettes readable at thumbnail size. No duplication or palette swaps.
```
