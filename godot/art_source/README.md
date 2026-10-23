# Environment art sources · 0.5.0

2026-10-23：当前环境使用内置 `image_gen` 生成的绘画风格原图，
源文件在 `painted/`，最终提示词保存在 `painted/PROMPTS.json`。
建筑、自然物、地表材质、功能道具四张 `*-source.png` 保留生成后的
原始像素；`painted/props-manifest.json` 记录物件候选框、alpha 连通
种子点、脚底和占地宽。切图与材质处理在 Godot 烘焙阶段完成，
不直接修饰发布 PNG 作为唯一源。

完整使用范围、原画尺寸、接入/未接入物件与重建步骤见
[绘画环境管线](../../docs/PAINTED-ENVIRONMENT.md)。当前原画可追溯到
内置图像生成工具和所保存的最终提示词；不要将其描述成纯 Blender
模型渲染或人工绘制逐帧动画。

## 当前重建流程

从仓库根目录运行，三个烘焙步骤需要 Godot 图形渲染器；地标生成后先导入，再烘焙地图：

```powershell
godot --path godot --script res://tools/bake_painted_landmarks.gd
godot --headless --path godot --editor --import --quit
godot --path godot --script res://tools/bake_maps.gd
godot --path godot --script res://tests/hanshui_layout_verify.gd -- --bake
godot --headless --path godot --editor --import --quit
godot --headless --path godot --script res://tests/painted_assets_verify.gd
```

四件旧地标沿用下面的尺寸、脚底与碰撞契约；三种跨度的门楼和井
生成在 `assets/props/painted_markers.png/json`。
`.gdignore` 与导出排除项将整个制作目录留在源工程，
游戏只依赖 `assets/maps/` 和 `assets/props/` 的正式烘焙资源。
本轮源码回归与原生截图结果见 [Godot 开发说明](../README.md)，导出包和发布验证仍待完成；不能复用下方旧阶段的结果。

## 历史 0.4.0 及以前：Blender landmark sprites

The following records the earlier Blender pipeline, retained as editable
history and a fallback. Its regeneration command overwrites the same four
runtime PNGs and manifests. After using it, rerun the current painted-landmark
bake above before shipping 0.5.0.

Four original, editable Blender props replaced the small vector-drawn altar,
memorial stela, grain rack and hanging lantern. They use the game's existing
muted jade, sage, weathered stone and straw palette. No external models,
textures, text generation, or image-generation service was used in that earlier
Blender-only stage. This statement does not describe the 0.5.0 painted sources.

## Editable source

Open `map_landmarks.blend` in Blender 4.3.2 or newer. Its four scenes are named
`altar`, `stela`, `grain_rack`, and `lantern`. Each contains a separate editable
model collection, contact-shadow collection, orthographic camera, and lights.
The saved starting scene is the altar. Materials and geometric details remain
editable rather than being flattened into a mesh or texture atlas.

The `.gdignore` in this folder deliberately prevents Godot from importing or
exporting this authoring source as a 3D game asset. The game remains 2D and does
not require Blender to run.

## Regenerate the historical Blender version

From the repository root:

```sh
blender --background --factory-startup --python godot/art_source/regenerate_landmarks.py
```

The script recreates the editable source, all four RGBA PNGs, the per-prop JSON,
and `assets/props/landmarks.json`. Blender's bundled Python is sufficient. No
package install is needed. Fixed-seed Cycles CPU rendering uses 256 samples and
no denoiser, so it also works with headless builds without OpenImageDenoise or
a usable GPU. The final image checksums were unchanged on a repeated full run
with Blender 4.3.2 in that historical workspace run; it is not a 0.5.0 validation.

For a quick model iteration, append `-- --samples 64 --only grain_rack`. A full
default run should follow before shipping, so every sprite has matching quality.

## Coordinate contract

- The camera is front-facing with no horizontal yaw and 30 degrees elevation.
- Blender's ground origin `(0, 0, 0)` is the existing landmark foot/Y-sort anchor.
- Models use 32 Godot world pixels per Blender unit and render at 2 source pixels
  per world pixel. Runtime draw scale is exactly `0.5`.
- In each JSON, `image_size` and `anchor_px` are source-image pixels.
- `logical_size`, `logical_anchor`, and `draw_offset` are Godot world pixels.
- Draw `image` at the landmark node using `Rect2(draw_offset, logical_size)`.
  Keep the node itself at the existing landmark position so its Y-sort remains
  correct. The lantern has an intentionally asymmetric image/anchor because
  its light hangs to the right of the post.
- A small translucent contact shadow is already rendered into each PNG. Do not
  add the former vector shadow on top of these four sprites.
- `colliders` only documents the existing footprints. `data/map_details.json`
  remains their gameplay authority. The upright stone, roof, lantern arm and
  contact shadow are not additional collision surfaces.

| Prop | Source PNG | Logical size | Source anchor | Logical offset |
|---|---:|---:|---:|---:|
| altar | 280 × 280 | 140 × 140 | 140, 238 | -70, -119 |
| stela | 152 × 200 | 76 × 100 | 76, 172 | -38, -86 |
| grain rack | 288 × 272 | 144 × 136 | 144, 234 | -72, -117 |
| lantern | 160 × 244 | 80 × 122 | 52, 218 | -26, -109 |

The regeneration script verifies the projected origin against every manifest
anchor to within 0.01 source pixels. Sprite margins, alpha and unchanged collider
correspondence are also checked in the saved modeling QA evidence.
