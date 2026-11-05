"""Build UV atlases from Longdan's original, project-owned 2D environment paintings."""
from pathlib import Path
import io
import math
import random
import numpy as np
from PIL import Image, ImageDraw


HERE = Path(__file__).resolve().parent
PAINTINGS = HERE.parents[2] / 'godot' / 'art_source' / 'painted'
PATCHES = ('front', 'gable', 'ruin', 'tile', 'wood', 'stone', 'foundation', 'window')
CELL = 384
PAD = 5


def encoded(image, kind):
    stream = io.BytesIO()
    image.save(stream, kind, **({'quality': 91, 'optimize': True} if kind == 'JPEG' else {}))
    return stream.getvalue()


def unwrap(source, points):
    # Source coordinates follow the actual perspective corners of a painted plane.
    quad = tuple(value for point in points for value in point)
    return source.convert('RGB').transform((CELL, CELL), Image.Transform.QUAD, quad, Image.Resampling.BICUBIC)


def uv_patch(patch, u, v):
    idx = PATCHES.index(patch)
    inner = CELL - 2 * PAD
    return ((idx % 4 + (PAD + inner*u)/CELL)/4, (idx//4 + (PAD + inner*v)/CELL)/2)


def architecture_atlas():
    sheet = Image.open(PAINTINGS / 'architecture-source.png')
    intact = sheet.crop((18,79,455,431))
    ruin = sheet.crop((477,80,887,435))
    nature = Image.open(PAINTINGS / 'materials-source.png')
    patches = {
        'front': unwrap(intact, ((58,170),(57,269),(292,306),(296,196))),
        'gable': unwrap(intact, ((325,165),(324,248),(381,225),(380,135))),
        'ruin': unwrap(ruin, ((45,158),(45,263),(294,307),(285,202))),
        'tile': unwrap(intact, ((127,50),(34,135),(280,179),(316,69))),
        'wood': unwrap(intact, ((98,201),(98,257),(152,267),(153,209))),
        'stone': nature.crop((1024,0,1536,512)).resize((CELL,CELL), Image.Resampling.LANCZOS),
        'foundation': unwrap(intact, ((180,270),(180,300),(291,324),(291,291))),
        'window': unwrap(intact, ((172,192),(172,266),(292,296),(293,206))),
    }
    atlas = Image.new('RGB', (4*CELL,2*CELL))
    for idx, name in enumerate(PATCHES):
        # Repeat edge pixels into a gutter; mips on a roof ridge must not borrow a door colour.
        patch = patches[name].resize((CELL-2*PAD,CELL-2*PAD),Image.Resampling.LANCZOS)
        pixels = np.asarray(patch)
        padded = Image.fromarray(np.pad(pixels,((PAD,PAD),(PAD,PAD),(0,0)),mode='edge'))
        atlas.paste(padded, ((idx%4)*CELL,(idx//4)*CELL))
    return encoded(atlas, 'JPEG')


def feather_spray(source, crop, warm=0.0):
    # A clipped spray is draped over short curved mesh strips on the ends of real branches.
    im = source.crop(crop).convert('RGBA').resize((248,248),Image.Resampling.LANCZOS)
    a = np.array(im, dtype=np.float32)
    y,x = np.mgrid[-1:1:248j,-1:1:248j]
    theta = np.arctan2(y,x)
    radius = np.hypot(x,y)
    fringe = .83 + .095*np.sin(theta*5.0+.7) + .058*np.cos(theta*11.0-.4) + .045*np.sin(theta*23.0)
    r,g,b = (a[:,:,i] for i in range(3))
    # Isolate leaves from occasional brown ink at the edge of the source branch.
    leaf_weight = np.clip((g-r*.84+2)/8,0,1)
    alpha = np.minimum(a[:,:,3], np.clip((fringe-radius)/.045,0,1)*255)
    alpha *= .72 + .28*leaf_weight
    lum = (r*.26+g*.57+b*.17)/255
    a[:,:,0] = np.clip(r*(1.02+warm*.17)+warm*lum*26,0,255)
    a[:,:,1] = np.clip(g*(1.0-warm*.13)+4,0,255)
    a[:,:,2] = np.clip(b*(.99-warm*.12)+5,0,255)
    a[:,:,3] = alpha
    return Image.fromarray(a.astype('uint8'))


def foliage_atlas():
    nature = Image.open(PAINTINGS / 'nature-source.png')
    oak = nature.crop((0,0,460,430))
    pine = nature.crop((880,0,1342,430))
    varieties = [
        feather_spray(oak, (176,82,371,230), 0.0),
        feather_spray(oak, (59,135,249,276), .92),
        feather_spray(pine, (125,213,323,321)),
        feather_spray(oak, (204,122,421,256), .27),
    ]
    atlas = Image.new('RGBA',(512,512))
    for i,spray in enumerate(varieties):
        atlas.paste(spray,((i%2)*256+4,(i//2)*256+4))
    return encoded(atlas,'PNG')


def meadow_atlas():
    atlas=Image.new('RGBA',(512,512))
    for patch in range(4):
        rng=random.Random(5067+patch)
        tuft=Image.new('RGBA',(256,256));pen=ImageDraw.Draw(tuft)
        for i in range(36):
            x=rng.uniform(93,161); height=rng.uniform(68,211)
            lean=rng.uniform(-1.0,1.0)*(45+.33*height)
            wide=rng.uniform(3.2,8.1)
            shade=rng.uniform(.72,1.22)
            pigment=((123,132,72),(179,156,90),(103,137,82),(154,144,80))[patch]
            color=tuple(int(min(244,v*shade)) for v in pigment)+(255,)
            left=[];right=[];mid=[]
            for k in range(8):
                t=k/7; cx=x+lean*(t**1.4); yy=247-height*t+abs(lean)*.42*t*t
                w=wide*(1-t)**.7*math.sin(.39+t*1.9)
                left.append((cx-w,yy));right.append((cx+w,yy));mid.append((cx,yy))
            pen.polygon(left+right[::-1],fill=color)
            pen.line(mid[2:6],fill=tuple(min(249,c+22) for c in color[:3])+(255,),width=1)
            if patch==1 and i%4==0:
                px,py=mid[-1]
                for k in range(4):
                    pen.ellipse((px-2+k*.7,py-k*2-3,px+3+k*.7,py-k*2+1),fill=(189,164,94,255))
        atlas.paste(tuft,((patch%2)*256,(patch//2)*256))
    return encoded(atlas,'PNG')


def field_brush():
    sheet = Image.open(PAINTINGS / 'materials-source.png')
    # Ground high-frequency colour: dirt, moss, bank rocks and scorched earth.
    brush = Image.new('RGB',(1024,1024))
    for i,(sx,sy) in enumerate(((0,0),(1,1),(2,0),(2,1))):
        patch = sheet.crop((sx*512,sy*512,(sx+1)*512,(sy+1)*512))
        # Mirror the rim into itself to keep both derivative and colour continuous.
        half = patch.resize((256,256),Image.Resampling.LANCZOS)
        cell = Image.new('RGB',(512,512))
        cell.paste(half,(0,0)); cell.paste(half.transpose(Image.Transpose.FLIP_LEFT_RIGHT),(256,0))
        cell.paste(cell.crop((0,0,512,256)).transpose(Image.Transpose.FLIP_TOP_BOTTOM),(0,256))
        brush.paste(cell,((i%2)*512,(i//2)*512))
    brush.save(HERE/'FieldBrush.jpg',quality=92,optimize=True)
