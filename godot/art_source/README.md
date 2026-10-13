# Modeled landmark sprites

Four original, editable Blender props replace the small vector-drawn altar,
memorial stela, grain rack and hanging lantern. They use the game's existing
muted jade, sage, weathered stone and straw palette. No external models,
textures, text generation, or image-generation service was used.

## Editable source

Open `map_landmarks.blend` in Blender 4.3.2 or newer. Its four scenes are named
`altar`, `stela`, `grain_rack`, and `lantern`. Each contains a separate editable
model collection, contact-shadow collection, orthographic camera, and lights.
The saved starting scene is the altar. Materials and geometric details remain
editable rather than being flattened into a mesh or texture atlas.

The `.gdignore` in this folder deliberately prevents Godot from importing or
exporting this authoring source as a 3D game asset. The game remains 2D and does
not require Blender to run.

## Regenerate

From the repository root:

```sh
blender --background --factory-startup --python godot/art_source/regenerate_landmarks.py
```

The script recreates the editable source, all four RGBA PNGs, the per-prop JSON,
and `assets/props/landmarks.json`. Blender's bundled Python is sufficient. No
package install is needed. Fixed-seed Cycles CPU rendering uses 256 samples and
no denoiser, so it also works with headless builds without OpenImageDenoise or
a usable GPU. The final image checksums were unchanged on a repeated full run
with Blender 4.3.2 in this workspace.

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
