# 电脑版八方向出枪（2026-10-02）

文件：`zhaoyun-attack-v3.png`，1254×1254，透明 RGBA。使用内置 image_gen，以原始角色和现有步行图集为参考生成，保留原始透明通道。

运行时用人物头部高度作为统一尺度，长枪和飘带不参与人物大小计算。向下与右下刺击的枪尖低于脚底，另校准脚底锚点；身体在蓄势、命中与收招间切换，命中阶段有小幅前探。

实际朝向与提示顺序有差异：右向蓄势使用第13格、刺击使用第6格；右上蓄势使用第11格、刺击使用第8格；右下蓄势将第3格镜像、刺击使用第4格。左向、左上、左下从相应右向动作镜像；正下使用第1/2格，正上使用第9/10格。每个方向均切换两张不同姿势，原有步行帧只用于站立和走动。

## 最终完整提示词

```text
Use case: stylized-concept
Asset type: transparent sprite atlas for a 2D top-down Chinese action game.
Input images: Image 1 is the original Zhao Yun character identity reference. Image 2 is the existing walking atlas, used as the EXACT art style, costume and character proportion reference.
Primary request: Create a SINGLE square transparent 4-column by 4-row sprite sheet with EXACTLY SIXTEEN separated full-body sprites of this SAME cute chibi Zhao Yun, two spear-attack poses for EACH of eight compass directions. Same chestnut spiky hair, cyan eyes, blue headband, long bright blue scarf, silver blue carved armor and boots. Match the reference walking sprites' youthful friendly face, silhouette and two-and-a-half-head body proportions.
Layout and order (read row by row, left to right):
Row 1: SOUTH windup (front view, face toward viewer, spear drawn back); SOUTH thrust (front view, arms extending spear toward bottom of image); SOUTHEAST windup (front-right three-quarter); SOUTHEAST thrust (spear tip toward lower-right).
Row 2: EAST windup (right side view); EAST thrust (spear tip clearly toward image right); NORTHEAST windup (back-right three-quarter); NORTHEAST thrust (spear tip upper-right).
Row 3: NORTH windup (full back view, NO visible face); NORTH thrust (full back view, hands and spear forward/up away from viewer); NORTHWEST windup (back-left three-quarter); NORTHWEST thrust (spear tip upper-left).
Row 4: WEST windup (left side view); WEST thrust (spear tip clearly image left); SOUTHWEST windup (front-left three-quarter); SOUTHWEST thrust (spear tip lower-left).
Animation: windup is a planted brace with bent elbows, twisted torso and spear retracted; thrust is a visibly DIFFERENT whole-body pose with both arms extending forward, hips lunging, one boot bracing and scarf trailing backward. Keep the feet on the ground, no jumping. Two poses of one direction must share identical head dimensions and body volume. All sixteen must have the SAME pixel head size and consistent costume detail. This is an actual animation atlas, not sixteen idle characters holding decorative spears.
Composition: orthographic slightly elevated game camera matching existing walking sheet. Four equal columns and four equal rows. Each sprite stays fully inside its own cell with generous TRANSPARENT gutters. Keep every hair, spear tip, scarf and boot complete. No objects touching between cells. No ground or cast shadows. No labels, grids, text, watermark or glowing attack effects; effects are separately rendered by the game.
Background: genuinely transparent alpha. Preserve identity and art style.
```
