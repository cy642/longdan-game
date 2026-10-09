"""Copy original PNGs and read atlas anchors; no PNG pixels are modified."""
from pathlib import Path
import json
import shutil
import numpy as np
from PIL import Image

def connected_labels(mask):
    # Row runs and union-find avoid a platform-specific image-processing dependency.
    parents = [0]
    runs = []
    previous = []
    def root(i):
        while parents[i] != i:
            parents[i] = parents[parents[i]]
            i = parents[i]
        return i
    for y, row in enumerate(mask):
        edges = np.flatnonzero(np.diff(np.r_[False, row, False]))
        current = []
        for start, end in zip(edges[::2], edges[1::2]):
            label = len(parents); parents.append(label)
            for a, b, other in previous:
                if b >= start and a <= end:
                    parents[root(label)] = root(other)
            current.append((int(start), int(end), label))
            runs.append((y, int(start), int(end), label))
        previous = current
    labels = np.zeros(mask.shape, dtype=np.int32)
    for y, start, end, label in runs:
        labels[y, start:end] = root(label)
    return labels

project = Path(__file__).resolve().parents[1]
source = project.parent / 'assets'
destination = project / 'assets'
destination.mkdir(exist_ok=True)
atlases = {}
specs = {'hero': ('zhaoyun-actions-v1.png', 8, 2),
         'walk': ('zhaoyun-walk-v2.png', 16, 4),
         'attack': ('zhaoyun-attack-v3.png', 16, 4),
         'units': ('chibi-units-v1.png', 8, 2),
         'chapter': ('chapter1-units-v2.png', 8, 2)}
for key, (filename, count, rows) in specs.items():
    shutil.copy2(source / filename, destination / filename)
    pixels = np.asarray(Image.open(source / filename).convert('RGBA'))
    height, width = pixels.shape[:2]
    labels = connected_labels(pixels[:, :, 3] >= 28)
    sizes = np.bincount(labels.ravel()); sizes[0] = 0
    selected = np.argsort(sizes)[-count:]
    components = []
    for label in selected:
        ys, xs = np.nonzero(labels == label)
        assert sizes[label] > 1000
        x0, x1, y0, y1 = int(xs.min()), int(xs.max()), int(ys.min()), int(ys.max())
        components.append((min(rows - 1, int((y0 + y1) / 2 / (height / rows))), x0, x1, y0, y1, int(label)))
    components.sort()
    assert all(sum(c[0] == row for c in components) == 4 for row in range(rows))
    frames = []
    for _, x0, x1, y0, y1, label in components:
        sx, sy = max(0, x0 - 2), max(0, y0 - 2)
        sw, sh = min(width - sx, x1 - sx + 3), min(height - sy, y1 - sy + 3)
        area = pixels[sy:sy+sh, sx:sx+sw].astype(float)
        membership = labels[sy:sy+sh, sx:sx+sw] == label
        alpha = area[:, :, 3] * membership
        head = alpha.copy(); head[int(sh * .38):] = 0
        hair = alpha * ((area[:, :, 0] > 65) & (area[:, :, 0] > area[:, :, 1] * 1.18) & (area[:, :, 2] < area[:, :, 1] * .72))
        has_hair = hair.sum() > head.sum() * .04
        anchor = hair if has_hair else head
        anchor_x = float((anchor.sum(axis=0) * np.arange(sw)).sum() / max(1, anchor.sum()))
        cumulative = hair.sum(axis=1).cumsum()
        hair_top = int(np.searchsorted(cumulative, hair.sum() * .02))
        hair_bottom = int(np.searchsorted(cumulative, hair.sum() * .96))
        head_height = max(1, hair_bottom - hair_top) if hair.sum() > 0 else sh * .4
        frames.append({'region': [sx, sy, sw, sh], 'anchor': [round(anchor_x, 3), y1 - sy + 1], 'head_height': head_height})
    atlases[key] = {'file': 'res://assets/' + filename, 'frames': frames}
atlases['attack']['frames'][1]['anchor'][1] -= 35
atlases['attack']['frames'][3]['anchor'][1] -= 22
shutil.copy2(source / 'zhaoyun-reference.png', destination / 'zhaoyun-reference.png')
(project / 'data' / 'atlas.json').write_text(json.dumps(atlases, indent=2) + '\n', encoding='utf-8')
print('Original character atlases copied. Feet and head anchors indexed:', sum(len(a['frames']) for a in atlases.values()))
