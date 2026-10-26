"""Index new enemy art without repainting/resizing any source pixels.

Authored calibration is relative to each isolated opaque bounding rectangle.
The body ruler excludes tall weapons/crests. Re-run after changing source art;
--check is read-only and rejects stale or missing metadata.
"""
from pathlib import Path
import argparse
import hashlib
import json
import numpy as np
from PIL import Image

def connected_labels(mask):
    parents = [0]
    runs, previous = [], []
    def root(i):
        while parents[i] != i:
            parents[i] = parents[parents[i]]
            i = parents[i]
        return i
    for y,row in enumerate(mask):
        edges = np.flatnonzero(np.diff(np.r_[False,row,False]))
        current = []
        for start,end in zip(edges[::2],edges[1::2]):
            label = len(parents); parents.append(label)
            for a,b,other in previous:
                if b >= start and a <= end: parents[root(label)] = root(other)
            current.append((int(start),int(end),label))
            runs.append((y,int(start),int(end),label))
        previous = current
    labels = np.zeros(mask.shape,dtype=np.int32)
    for y,start,end,label in runs: labels[y,start:end] = root(label)
    return labels

def safe_exclusion_rectangles(other, own, rectangle):
    """Partition a neighbour's box, never clipping this sprite's opaque pixels.

    Curved plume/weapon edges can interleave inside overlapping bounds even
    though the actual alpha components never touch. Empty pieces are omitted.
    """
    result, pending = [], [rectangle]
    while pending:
        left, top, right, bottom = pending.pop()
        if not other[top:bottom,left:right].any(): continue
        if not own[top:bottom,left:right].any():
            result.append([left,top,right-left,bottom-top]); continue
        if right-left >= bottom-top and right-left > 1:
            mid=(left+right)//2
            pending.extend([(left,top,mid,bottom),(mid,top,right,bottom)])
        elif bottom-top > 1:
            mid=(top+bottom)//2
            pending.extend([(left,top,right,mid),(left,mid,right,bottom)])
        else:
            raise ValueError('Two character components own the same opaque pixel')
    return result

project = Path(__file__).resolve().parents[1]
parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('--check', action='store_true')
args = parser.parse_args()
calibrations = json.loads((project/'art_source/characters/enemy-calibration.json').read_text(encoding='utf-8'))
result = {}
for key, spec in calibrations.items():
    path = project/spec['file']
    with Image.open(path) as image:
        if image.mode != 'RGBA': raise ValueError(f'{path}: RGBA alpha required')
        pixels = np.asarray(image)
    height, width = pixels.shape[:2]
    if (pixels[:,:,3] == 0).mean() < .2: raise ValueError(f'{path}: missing transparent background')
    columns, rows = spec['grid']
    assert len(spec['frames']) == columns*rows
    labels = connected_labels(pixels[:,:,3] >= 24)
    sizes = np.bincount(labels.ravel()); sizes[0] = 0
    main = np.argsort(sizes)[-columns*rows:]
    components = []
    for component in main:
        ys,xs = np.nonzero(labels == component)
        assert sizes[component] >= 500
        center_y = (int(ys.min())+int(ys.max()))/2
        components.append((min(rows-1,int(center_y/height*rows)),int(xs.min()),int(xs.max()),int(ys.min()),int(ys.max()),int(component)))
    components.sort()
    assert all(sum(c[0] == row for c in components) == columns for row in range(rows))
    frames = []
    for index, calibration in enumerate(spec['frames']):
        _,x0,x1,y0,y1,component = components[index]
        left,top,right,bottom = max(0,x0-2),max(0,y0-2),min(width,x1+3),min(height,y1+3)
        fw,fh = right-left,bottom-top
        frame_labels = labels[top:bottom,left:right]
        membership = frame_labels == component
        other_sizes = np.bincount(frame_labels.ravel())
        exclusions = []
        for other in np.flatnonzero(other_sizes >= 4):
            if other in (0,component): continue
            oy,ox = np.nonzero(frame_labels == other)
            hx0,hy0 = max(0,int(ox.min())-1),max(0,int(oy.min())-1)
            hx1,hy1 = min(fw,int(ox.max())+2),min(fh,int(oy.max())+2)
            exclusions.extend(safe_exclusion_rectangles(frame_labels == other,membership,(hx0,hy0,hx1,hy1)))
        feet = calibration['feet']
        frame = {'region':[left,top,fw,fh],
                 'anchor':[round(fw*feet[0],3),round(fh*feet[1],3)],
                 'body_height':round(fh*(feet[1]-calibration['body_top']),3),
                 'head_rect':calibration['head_rect'], 'hip':calibration['hip'],
                 'boot_regions':calibration['boot_regions'],
                 'leg_start':calibration['leg_start'], 'leg_end':.99,
                 'rigid_weapon_regions':calibration['rigid_weapon_regions'], 'exclude':exclusions}
        assert frame['body_height'] > 20
        assert 0 < calibration['leg_start'] < feet[1] <= 1
        frames.append(frame)
    result[key] = {'file':'res://'+spec['file'],
                   'source_sha256':hashlib.sha256(path.read_bytes()).hexdigest(), 'frames':frames}
target = project/'data/enemy_atlas.json'
if args.check:
    if not target.exists() or json.loads(target.read_text(encoding='utf-8')) != result:
        raise SystemExit('Enemy atlas differs from source/calibration; no files changed.')
else:
    target.write_text(json.dumps(result,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
print(f'ENEMY_ATLAS_CHECK_OK {sum(len(a["frames"]) for a in result.values())} frames; original pixels retained')
