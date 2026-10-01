# Q 版角色素材

使用内置图像生成工具，以用户提供的第一张角色图为形象和画风参考。原图保持不变，复制到本目录并用于首页展示。人物的新画法覆盖此前的白袍头盔造型。

## 素材

- `zhaoyun-reference.png`：用户提供的透明原图，首页使用。
- `zhaoyun-actions-v1.png`：赵云八个姿势的透明动作图集。
- `chibi-units-v1.png`：随军、刀兵、枪兵、弓兵、夏侯恩和三种百姓的透明角色图集。

图片在构建时内嵌到 `index.html`，不需要联网加载。运行时按透明轮廓提取图集中的角色，避免裁掉长枪和飘带，亦避免出现相邻角色的碎片。

当前赵云有待机、两个走动姿势、蓄势、刺击、横扫、闪避和受击姿势，左右朝向使用镜像。随军与敌兵当前用单姿势配合摆动，后续可补充连续动作和八方向素材。

## 赵云图集的最终生成提示词

Use case: stylized-concept. Asset type: a transparent PNG character animation sprite atlas for an actual 2D game. Input image 1 is the character identity and illustration style reference. Recreate this same handsome, friendly chibi Zhao Yun: chestnut brown spiky hair, expressive bright cyan eyes, blue forehead headband with long flowing blue scarf tails, ornate polished silver-blue armor over dark blue clothing, silver greaves and boots, and a long silver spear. No helmet, no white cape, no realistic adult proportions. Match the reference's refined anime game illustration, crisp clean outlines, rich cel shading, soft highlights, and appealing 2.5-head-tall proportions. Deliver ONE landscape atlas with exactly FOUR equal columns and TWO equal rows, eight distinct full-body poses, no text or grid lines, fully transparent alpha background. All eight are this exact same character, same costume, same scale, all facing left in three-quarter view, looking heroic and cute rather than angry or grotesque. Arrange with exact equal cell spacing and ample transparent padding; no character, spear or scarf crosses its cell. The boots touch the same baseline at 87% of each cell height. Character torso centered at 50% of each cell width. Row 1 left to right: neutral standing idle with spear held diagonally; jogging stride with left leg forward; jogging opposite stride with right leg forward; spear attack windup drawn back. Row 2 left to right: low forward spear thrust to the left; wide spear sweep toward the left; agile evasive dash leaning left with scarf trailing; hurt reaction leaning back. Keep each full body and full spear fully visible in its cell. No scenery, no floor, no baked shadows, no UI, no labels, no watermark. Maintain consistent head shape and face across every cell; recognizable hands with natural spear grips.

## 其他角色图集的最终生成提示词

Use case: stylized-concept. Asset type: transparent PNG NPC sprite atlas for the 2D Three Kingdoms game whose player uses image 1. Image 1 is ONLY the anime chibi illustration STYLE reference, NOT the NPC identities. Make exactly EIGHT DIFFERENT full body chibi Three Kingdoms characters, same refined high-quality clean anime linework, cel-shaded silver armor, cute expressive eyes, approximately 2.5 heads tall, natural appealing anatomy. Friendly human faces, never grotesque, no realistic adult anatomy. Layout: exact 4 equal columns by 2 equal rows on a landscape canvas, no visible grid. EACH character must fit comfortably within its own equal-size cell with LARGE transparent margins of at least 8% on every side, including its entire weapon. No overlap between neighbors. Faces and bodies all looking left in 3/4 view, same character scale, same foot baseline at 85% cell height. Row 1 left to right: (1) friendly Shu foot soldier with blue-green headcloth, teal tunic, plain silver breastplate, a short spear, no elaborate hero scarf, dark brown hair; (2) Cao sword soldier with dark red headcloth, red tunic, grey lamellar armor, curved short dao sword; (3) Cao spear soldier with simple grey helmet, dark red tunic, bronze-grey lamellar cuirass and spear; (4) Cao archer with red headband, grey short tunic and leather guards, brown recurved bow. Row 2 left to right: (5) enemy general Xiahou En, proud stern chibi adult with black eyebrows and short black beard, ornate gold-trimmed steel armor, crimson shoulder cloth, broad silver sword, slightly larger body; (6) civilian man wearing simple tan hemp robe with brown sash and brown headcloth, empty hands; (7) civilian woman with neatly tied dark hair wearing warm cream and muted peach simple Han-style clothes, empty hands; (8) civilian young man with dark short hair, light olive hemp robe and tan cloth bundle on back. Do not copy Zhao Yun's distinctive chestnut spiky hair, blue hero headband or long bright blue scarf onto these NPCs. Background must be truly transparent alpha; no floor, no shadows, no scenery, no UI, no text, no labels, no watermark. Keep all eight clearly separate and fully visible, with stable clean outlines suitable for scaling down to in-game sprites.

## 第一章与手机版新增素材（2026-10-01）

使用内置 image_gen，参考原始赵云形象，新生成透明 PNG，未修改原参考图。文件：`zhaoyun-walk-v2.png`（1254×1254）和 `chapter1-units-v2.png`（1536×1024）。两张均保留原始透明通道。运行时按独立人物轮廓提取，并按头部与脚底锚点绘制。

步行图：16格（8方向各两步）。生成图中部分方向朝向与指定格序相反，渲染端依据实际方向映射和镜像，完成八方向显示。步伐由实际移动距离推进，阴影固定在地面。

NPC图：盾兵、盾阵校尉、张郃、医者、担架上的糜夫人、随军两步、夏侯恩。普通弓兵、剑兵和枪兵继续使用第一版 NPC 图。

### 步行图完整提示词

```text
Use case: stylized-concept
Asset type: transparent 2D top-down action RPG character walking sprite atlas
Input Image 1 is the character identity and style reference. Keep the EXACT cute chestnut brown spiky hair, cyan eyes, blue headband, flowing blue scarf, silver-blue ornate armor, short 2.5-head chibi proportions and dragon spear.
Primary request: A production-ready walking animation atlas with EXACTLY SIXTEEN separate full body Zhao Yun sprites in an evenly spaced FOUR COLUMNS by FOUR ROWS grid, all on genuine transparent background. No boxes, no text, no shadows, no background.
Every pair is two alternating grounded WALK steps (left boot planted then right boot planted), NOT jumping, NOT floating, NOT running airborne. At least one sole firmly touches a common ground baseline within each cell. Spear held close to body upright or angled upward, never below the boots, modest flowing scarf. SAME head size and body scale and projection in every cell. Camera looks slightly down on an upright chibi, consistent with top-down RPG.
Read cells left to right:
row 1: facing south/front step A, south/front step B, southeast/front-right step A, southeast/front-right step B.
row 2: east/right-profile step A, east/right-profile step B, northeast/back-right step A, northeast/back-right step B.
row 3: north/back step A, north/back step B, northwest/back-left step A, northwest/back-left step B.
row 4: west/left-profile step A, west/left-profile step B, southwest/front-left step A, southwest/front-left step B.
All sixteen figures MUST be disconnected with clear transparent gutters; keep entirety of scarf, spear and boots inside its own cell. Confident friendly warrior expression on visible faces, soft anime line art and hand-painted highlights matching reference. No intimidating geometry, no changes to costume or face, no additional props, no labels, no watermark. High resolution square atlas.
```

### 第一章人物完整提示词

```text
Use case: stylized-concept
Asset type: transparent 2D top-down Three Kingdoms action RPG NPC atlas.
Input image 1 is visual style reference only. Match its cute 2.5-head chibi proportions, soft friendly anime art, painterly metal and cloth, clear silhouettes. Create EXACTLY EIGHT separated full-body character sprites, FOUR columns TWO rows, genuine transparent background, generous gutters, same apparent scale, upright characters grounded with soles at baseline. No shadows, no text, no boxes, no scenery, no effects or watermark. All face three-quarter to viewer's left, all weapon tips point upward and fit cells, none reach below feet.
Read left-to-right:
Row 1 column 1: Cao army shield infantry, crimson cloth, steel helmet, big round wood shield and short saber.
Row 1 column 2: shield captain elite, dark crimson and antique gold armor, plumed steel helmet, large rectangular shield and saber, clearly distinct heavier silhouette.
Row 1 column 3: general Zhang He, composed stern adult chibi face with neat black mustache, plum purple scarf, bronze and dark steel lamellar armor, ornate high helmet with narrow red tassel, long elegant silver spear with crimson tassel. Distinct from Zhao Yun.
Row 1 column 4: kind elderly male physician, sage green simple Han robe, gray hair tied in bun, little medical cloth bag and bandages in hands, no weapon.
Row 2 column 1: Lady Mi, gentle adult woman chibi with black tied hair, ivory robe with pale peach sash, sitting upright supported on a portable brown stretcher because injured, fully clothed, no blood or graphic injury.
Row 2 column 2: friendly Shu spear infantry in teal and muted silver armor, modest helmet, WALK step A with left sole planted.
Row 2 column 3: EXACT same friendly Shu spear infantry as previous cell, WALK step B with right sole planted, same head/armor size.
Row 2 column 4: Xiahou En, confident adult chibi enemy general, gold-red armor and a red plume helmet, neat small mustache, sword ready in right hand.
Consistent slightly elevated camera for overhead game, entire head, feet, scarf, weapons visible, strong alpha cutouts. Avoid harsh polygon faces and frightening expressions. Keep all EIGHT figures disconnected with transparent space.
```
