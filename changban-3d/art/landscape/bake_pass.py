"""Bake the original 3D Changban scenery. Run from any directory with Python, Pillow and NumPy."""
from pathlib import Path
import io
import json
import math
import random
import struct

import numpy as np
from PIL import Image, ImageDraw

HERE = Path(__file__).resolve().parent
R = random.Random(185)
sin, cos, pi = math.sin, math.cos, math.pi
X0, X1, Z0, Z1 = -46, 46, -54, 43


def road_center(z):
    bank_join = np.clip((np.abs(z+19) - 5) / 5, 0, 1)
    northern_turn = 5.0 * np.clip((-z-29) / 15, 0, 1)
    return (2.03 * np.sin(z * .147) + .77 * np.sin(z * .293) + northern_turn) * bank_join


def river_center(x):
    return -19.0 + .30 * np.sin(x * .16) + 1.8 * np.sin(x * .07) * np.clip((np.abs(x)-7)/12, 0, 1)


def ground_height(x, z):
    side = max(0, min(1, (abs(x) - 8) / 17))
    hills = side * (1.6 + 1.35 * sin(z*.149 + x*.19) + .65 * cos(x*.45 + z*.093))
    hills += min(1, max(0, (-z-29)/16)) * (1.72 + 1.12*cos(x*.23-z*.12) + .63*sin(x*.41+z*.21))
    bank = abs(z - float(river_center(x)))
    if bank >= 5.2:
        return hills * min(1, (bank - 5.2)/3)
    return -3.1 * min(1, (5.2-bank)/1.9)


def painted_ground():
    # The same world-to-image map supplies both terrain UVs and the art brush coordinates.
    size = 2048
    x = np.linspace(X0, X1, size, dtype=np.float32)[None, :]
    z = np.linspace(Z0, Z1, size, dtype=np.float32)[:, None]
    nr = np.random.default_rng(170)
    def noise(nx, ny):
        raw = nr.integers(0, 256, (ny, nx), dtype=np.uint8)
        return (np.asarray(Image.fromarray(raw).resize((size, size), Image.Resampling.BICUBIC), dtype=np.float32) / 255. - .5)
    broad, mid, fine = noise(24, 28), noise(92, 104), noise(680, 680)
    distance = abs(x - road_center(z))
    width = 2.67 + .51*np.sin(z*.21) + .76*np.exp(-(z/6)**2)
    path = np.clip((width-distance+.89*broad+.51*mid+.19*fine)/.55 + .55, 0, 1)
    d = abs(z - river_center(x))
    bank = np.clip((5.88-d+.33*broad+.15*mid)/1.6,0,1)
    field = np.clip((x-4.5)/5,0,1)*np.clip((17-z)/3,0,1)*np.clip((z-5)/2,0,1)
    stripes = np.sin(x*3.8+np.sin(z*.5)*.35) * field
    wagon = np.exp(-((distance-1.16-.085*np.sin(z*.83)-.15*broad)/.11)**2) * path
    wagon *= np.clip(.65 + 1.1*mid + .32*np.sin(z*1.7+x*2.6), .18, 1)
    wheel_lip = np.exp(-((distance-1.34-.085*np.sin(z*.83)-.15*broad)/.085)**2) * wagon
    colors = []
    for i in range(3):
        grassy = (99,115,81)[i]+(41,42,26)[i]*broad+25*mid+12*fine+stripes*(16,17,8)[i]
        dusty = (155,128,93)[i]+39*broad+23*mid+13*fine-31*wagon+13*wheel_lip
        shore = (121,123,103)[i]+35*broad+23*mid+11*fine
        colors.append((grassy*(1-path)+dusty*path)*(1-bank)+bank*shore)
    surface = Image.fromarray(np.uint8(np.clip(np.stack(colors,axis=-1),0,255)))
    pen = ImageDraw.Draw(surface, "RGBA")
    def pt(x,z):
        return ((x-X0)/(X1-X0)*size, (z-Z0)/(Z1-Z0)*size)
    for _ in range(28000):
        gx,gz = R.uniform(X0,X1), R.uniform(Z0,Z1)
        px,pz = pt(gx,gz)
        if abs(gx - float(road_center(gz))) < 2.8:
            if R.random()<.48:
                pen.line((px,pz,px+R.uniform(-2,2),pz+R.uniform(2,13)),fill=(96,79,56,R.randint(24,84)),width=R.choice([1,1,2]))
            else:
                length=R.uniform(1,4)
                pen.ellipse((px,pz,px+length,pz+length*.51),fill=(236,213,153,90))
        else:
            color=R.choice([(185,181,126,67),(64,83,61,78),(149,152,97,87)])
            for j in range(R.randint(2,5)):
                bx, bz = px + R.uniform(-5,5), pz+R.uniform(-4,4)
                pen.line((bx,bz,bx+R.uniform(-2,1),bz-R.uniform(2,8)),fill=color,width=1)
    stream=io.BytesIO()
    surface.save(stream, 'JPEG', quality=87, optimize=True)
    return stream.getvalue()


def lin(code):
    rgb=tuple(int(code[i:i+2],16)/255 for i in (0,2,4))
    return tuple(c/12.92 if c<=.04045 else ((c+.055)/1.055)**2.4 for c in rgb)


def tone(color, shift=0):
    return tuple(max(0., min(1.,v*(1+shift))) for v in color)


def vec(a): return np.array(a, dtype=np.float64)
def unit(a): return a/max(float(np.linalg.norm(a)), 1e-9)


class Batch:
    def __init__(self,name, material=0):
        self.name=name
        self.material=material
        self.pos,self.norm,self.color,self.uv=[],[],[],[]
    def triangle(self,a,b,c,color,uvs=None):
        a,b,c=vec(a),vec(b),vec(c)
        n=unit(np.cross(b-a,c-a))
        if np.dot(n,n)<.5:
            return
        self.pos.extend((a,b,c))
        self.norm.extend((n,n,n))
        self.color.extend((color,color,color))
        if uvs is not None: self.uv.extend(uvs)
    def quad(self,a,b,c,d,color):
        self.triangle(a,b,c,color)
        self.triangle(a,c,d,color)
    def beam(self,a,b,r1,r2,col,sides=7, twist=0):
        a,b=vec(a),vec(b)
        w=unit(b-a)
        helper=vec((0,1,0)) if abs(w[1])<.92 else vec((1,0,0))
        u=unit(np.cross(helper,w))
        v=np.cross(w,u)
        dirs=[cos(2*pi*i/sides+twist)*u+sin(2*pi*i/sides+twist)*v for i in range(sides)]
        for i,p in enumerate(dirs):
            q=dirs[(i+1)%sides]
            c=tone(col, .045*sin(i*4.73+twist))
            self.quad(a+r1*p,a+r1*q,b+r2*q,b+r2*p,c)
            self.triangle(a,a+r1*q,a+r1*p,c)
            self.triangle(b,b+r2*p,b+r2*q,c)
    def block(self,center,sizes,c,yaw=0):
        cx,cy,cz=center
        hx,hy,hz=[v*.5 for v in sizes]
        def p(x,y,z):
            return (cx+x*cos(yaw)+z*sin(yaw),cy+y,cz-x*sin(yaw)+z*cos(yaw))
        bot=[p(-hx,-hy,-hz),p(-hx,-hy,hz),p(hx,-hy,hz),p(hx,-hy,-hz)]
        top=[p(-hx,hy,-hz),p(-hx,hy,hz),p(hx,hy,hz),p(hx,hy,-hz)]
        self.quad(*top,c)
        for i in range(4):
            j=(i+1)%4
            self.quad(bot[i],bot[j],top[j],top[i],tone(c,-.075+.035*sin(i*6)))
    def lump(self,center,radii,col,rings=3,segs=8,jag=.19):
        cx,cy,cz=center
        rx,ry,rz=radii
        contour=[]
        phase=R.random()*pi
        for ri in range(1,rings+1):
            h=pi*ri/(rings+1)
            ring=[]
            for j in range(segs):
                q=2*pi*j/segs+phase+.13*sin(ri*1.7)
                off=1+R.uniform(-jag,jag)
                ring.append((cx+rx*sin(h)*cos(q)*off,cy+ry*(cos(h)+R.uniform(-.07,.07)),cz+rz*sin(h)*sin(q)*off))
            contour.append(ring)
        for i in range(segs):
            j=(i+1)%segs
            self.triangle((cx,cy+ry,cz),contour[0][j],contour[0][i],tone(col,R.uniform(-.06,.13)))
            self.triangle((cx,cy-ry,cz),contour[-1][i],contour[-1][j],tone(col,-.16))
            for k in range(rings-1):
                self.quad(contour[k][i],contour[k][j],contour[k+1][j],contour[k+1][i],tone(col,R.uniform(-.12,.12)))


class Gltf:
    def __init__(self,image):
        self.data=bytearray()
        self.g={'asset':{'version':'2.0','generator':'Longdan / Changban scenery bake'},'scene':0,
                'scenes':[{'name':'Changban Landscape','nodes':[]}],'nodes':[],'meshes':[],
                'buffers':[{}],'bufferViews':[],'accessors':[], 'materials':[], 'textures':[], 'images':[]}
        self.g['materials']=[{'name':name, 'doubleSided':True,'pbrMetallicRoughness':{'metallicFactor':0,'roughnessFactor':.94}} for name in
                             ['Hand-painted forms','Painted terrain','Eastern river cloth','Lacquered water','Silhouette mountains','Banner writing']]
        self.g['materials'][4]['extensions']={'KHR_materials_unlit':{}}
        self.g['extensionsUsed']=['KHR_materials_unlit']
        self.g['samplers']=[{'wrapS':33071,'wrapT':33071,'minFilter':9987,'magFilter':9729}]
        self.add_image(image,'image/jpeg','Road and riverside')
        self.g['materials'][1]['pbrMetallicRoughness']['baseColorTexture']={'index':0}
    def view(self,raw):
        while len(self.data)%4: self.data.append(0)
        v={'buffer':0,'byteOffset':len(self.data),'byteLength':len(raw)}
        self.data.extend(raw)
        self.g['bufferViews'].append(v)
        return len(self.g['bufferViews'])-1
    def add_image(self,data,mime,name):
        self.g['images'].append({'name':name,'bufferView':self.view(data),'mimeType':mime})
        self.g['textures'].append({'sampler':0,'source':len(self.g['images'])-1})
    def attr(self,a,width,data_type='f4',bounds=False):
        arr=np.array(a,dtype=data_type)
        typ={2:'VEC2',3:'VEC3',4:'VEC4'}[width]
        entry={'bufferView':self.view(arr.tobytes()),'componentType':5126 if data_type=='f4' else 5121,'count':len(arr),'type':typ}
        if data_type=='u1': entry['normalized']=True
        if bounds:
            entry['min']=arr.min(axis=0).tolist()
            entry['max']=arr.max(axis=0).tolist()
        self.g['accessors'].append(entry)
        return len(self.g['accessors'])-1
    def add(self,b):
        if not b.pos: return
        attrs={'POSITION':self.attr(b.pos,3,bounds=True),'NORMAL':self.attr(b.norm,3)}
        if b.material not in (1,5):
            attrs['COLOR_0']=self.attr([[round(v*255) for v in color]+[255] for color in b.color],4,'u1')
        if b.uv: attrs['TEXCOORD_0']=self.attr(b.uv,2)
        self.g['scenes'][0]['nodes'].append(len(self.g['nodes']))
        self.g['nodes'].append({'name':b.name,'mesh':len(self.g['meshes'])})
        self.g['meshes'].append({'name':b.name,'primitives':[{'attributes':attrs,'material':b.material}]})
    def save(self):
        while len(self.data)%4: self.data.append(0)
        self.g['buffers'][0]['byteLength']=len(self.data)
        doc=json.dumps(self.g,separators=(',',':')).encode()
        doc+=b' ' *((-len(doc))%4)
        binary=b'glTF'+struct.pack('<II',2,28+len(doc)+len(self.data))+struct.pack('<I4s',len(doc),b'JSON')+doc+struct.pack('<I4s',len(self.data),b'BIN\0')+self.data
        (HERE/'ChangbanPass.glb').write_bytes(binary)
        print(len(self.g['nodes']), 'batches;',f'{len(binary)/1e6:.2f} MB')


BARK, BARK_LIGHT, TIMBER = lin('534434'),lin('82684a'),lin('71503a')
TILE, RIDGE = lin('4d5b59'),lin('747d6d')
WALL, BASE = lin('d1bd95'),lin('888977')
FOLIAGE=[lin(c) for c in ('a6a04e','bb984c','b68042','aa7944','7b8652','938f51')]
ROCKS=[lin(c) for c in ('878b74','9e997e','777f76','b1a386','6d7970')]


def terrain(g):
    for xi in range(4):
        for zi in range(4):
            b=Batch('Terrain %d %d'%(xi,zi),1)
            xs=np.linspace(X0+23*xi,X0+23*(xi+1),17)
            zs=np.linspace(Z0+(Z1-Z0)*zi/4,Z0+(Z1-Z0)*(zi+1)/4,23)
            for i in range(len(xs)-1):
                for j in range(len(zs)-1):
                    corners=[(xs[i],zs[j]),(xs[i],zs[j+1]),(xs[i+1],zs[j+1]),(xs[i+1],zs[j])]
                    corners3=[(x,ground_height(x,z),z) for x,z in corners]
                    uv=[((x-X0)/(X1-X0),(z-Z0)/(Z1-Z0)) for x,z in corners]
                    for ids in ((0,1,2),(0,2,3)):
                        b.triangle(*[corners3[k] for k in ids],(1,1,1),[uv[k] for k in ids])
            g.add(b)


def mountains(g):
    # A low diagonal saddle behind the crossing allows real sky between the flanks.
    # Each receding ridge has different ravines, crest heights and ink-wash colours.
    for layer,(radius,pal,amp) in enumerate([(108,'a8b5ad',15.0),(80,'8eaaa0',13.5),(53,'728e7e',14.8)]):
        b=Batch('Painted distant ridge %d'%radius,4)
        basecol=lin(pal)
        count=205
        sector=.83+layer*1.86
        rows=[[] for _ in range(5)]
        heights=[-.12,.12,.37,.63,1.]
        levels=[-.52,-.29,-.12,-.035,.05]
        for i in range(count+1):
            angle=(i%count)*2*pi/count
            # Look north through a descending side valley. Its notches are offset
            # between layers; there is no continuous vertical curtain at the end.
            q=abs(math.atan2(sin(angle+pi/2-.065*layer),cos(angle+pi/2-.065*layer)))
            notch=min(1.,max(0.,q/(.44+.10*layer)))
            notch=notch*notch*(3-2*notch)
            ridge=.51+.23*sin(4*angle+sector)+.19*cos(7*angle-sector)+.13*sin(13*angle+sector)+.055*cos(25*angle)+.036*sin(43*angle+sector)
            h=(2.7+max(.12,ridge)*amp)*(0.14+.86*notch)+(2-layer)*1.9
            ravine=sin(i*.21+sector)*1.5 + cos(i*.47-sector)*1.1 + sin(i*1.13)*.41
            for k,hfrac in enumerate(heights):
                r=radius + (k-2)*2.25 + ravine*(.24+.22*k)
                hrow=-1.9 + h*hfrac + (.2+k*.095)*sin(i*.28+sector+k*.36)
                rows[k].append((r*cos(angle),hrow,-4+r*sin(angle)))
        for i in range(count):
            ravine=.10*sin(i*.37+sector)+.055*cos(i*.91+sector)
            for k in range(4):
                shade=1.+levels[k]+ravine
                # Stagger diagonal facets with uneven values like rock planes.
                a,d=rows[k][i],rows[k][i+1]
                bb,c=rows[k+1][i],rows[k+1][i+1]
                b.triangle(a,bb,c,tone(basecol,shade-1))
                b.triangle(a,c,d,tone(basecol,shade-1.05+.035*sin(i+k)))
        g.add(b)

def boulder(b,x,z,s):
    y=ground_height(x,z)
    b.lump((x,y+s*.21,z),(s*1.35,s*.64,s*.85),R.choice(ROCKS),rings=2,segs=7,jag=.26)
    if s>.7:
        b.lump((x+s*.24,y+s*.55,z+.04),(s*.71,s*.29,s*.60),lin('899054'),rings=2,segs=7,jag=.19)


def broadleaf(b,x,z,s,autumn):
    y=ground_height(x,z)
    angle=R.uniform(0,2*pi)
    tilt=vec((cos(angle)*s*.49,0,sin(angle)*s*.49))
    base=vec((x,y-.06,z))
    mid=base+vec((0,s*1.68,0))+tilt*.25
    crown=base+vec((0,s*3.2,0))+tilt
    b.beam(base,mid,.31*s,.16*s,BARK,8)
    b.beam(mid,crown,.18*s,.077*s,BARK_LIGHT,7)
    for i in range(4):
        ang=angle+i*1.55
        b.beam(base+vec((0,s*.38,0)),base+vec((s*.65*cos(ang),.05,s*.65*sin(ang))),.22*s,.045*s,BARK,6)
    leaf=FOLIAGE[autumn]
    for i in range(6):
        ang=angle+i*2.399
        length=(1.35+.30*cos(i*2.7))*s
        elbow=mid+tilt*.53+vec((cos(ang)*length*.47,s*(.46+i*.105),sin(ang)*length*.47))
        tip=mid+tilt*.84+vec((cos(ang)*length,s*(.95+i*.17),sin(ang)*length))
        b.beam(mid,elbow,.125*s,.077*s,BARK,6)
        b.beam(elbow,tip,.082*s,.042*s,BARK_LIGHT,6)
        shade=tone(leaf,R.uniform(-.14,.20))
        b.lump(tip+vec((0,s*.34,0)),(1.25*s,.71*s,1.17*s),shade,rings=2,segs=8,jag=.20)
        # Irregular canopy edges and small leaf fans give broad crowns a brush-like edge.
        for j in range(4):
            az=ang+j*1.81
            edge=tip+vec((s*cos(az)*.99,s*(.32+.17*sin(j)),s*sin(az)*.94))
            b.lump(edge,(.46*s,.31*s,.46*s),tone(shade,.10),rings=1,segs=5,jag=.18)
    b.lump(crown+vec((0,s*.53,0)),(1.35*s,.80*s,1.31*s),tone(leaf,.12),rings=2,segs=8)


def conifer(b,x,z,s):
    y=ground_height(x,z)
    sign=R.choice([-1,1])
    last=vec((x,y,z))
    for k in range(4):
        tip=vec((x+sign*.17*k*s,y+(k+1)*1.02*s,z+.09*k*s))
        b.beam(last,tip,s*(.22-.042*k),s*(.17-.04*k),BARK,7)
        last=tip
        for j in range(3):
            angle=j*2*pi/3+k*1.29
            length=s*(1.78-.34*k)
            elbow=tip+vec((cos(angle)*length*.62,.19*s,sin(angle)*length*.62))
            end=tip+vec((cos(angle)*length,.37*s,sin(angle)*length))
            b.beam(tip,elbow,.09*s,.050*s,BARK,5)
            b.beam(elbow,end,.053*s,.022*s,BARK_LIGHT,5)
            b.lump(end,(length*.86,.38*s,length*.72),lin(['4b6556','526f5b','647c61','728466'][k]),rings=2,segs=7,jag=.24)
    b.lump(last+vec((0,s*.40,0)),(.86*s,.48*s,.77*s),lin('728467'),rings=2,segs=7)


def flora(g):
    # Deliberate foreground silhouettes and openings frame the road, hamlet and bridge.
    near=[(-9.6,17,1.32,0),(11.3,23,1.22,2),(-13,26,1.70,4),(11.4,10,1.18,1),
          (-15,6,1.14,0),(15,1,1.08,3),(-13,-7,1.36,0),(11,-9,1.17,2),
          (-11,-29,1.39,0),(13,-31,1.45,1),(-16,-37,1.65,4),(13,36,1.72,5)]
    for i in range(40):
        x=R.choice([-1,1])*R.uniform(17,42)
        z=R.uniform(-46,37)
        if abs(z-float(river_center(x)))>6:
            near.append((x,z,R.uniform(.84,1.53),R.randrange(6)))
    for index in range(0,len(near),6):
        b=Batch('Autumn canopy %02d'%index)
        for ti,(x,z,s,palette) in enumerate(near[index:index+6]):
            if (ti+index)%4==0: conifer(b,x,z,s*1.24)
            else: broadleaf(b,x,z,s,palette)
        g.add(b)
    for sign in (-1,1):
        for band in range(4):
            b=Batch('Grass and scree %d %d'%(sign,band))
            for i in range(34):
                x=sign*R.uniform(7.4,38);z=R.uniform(-48+band*21,-27+band*21)
                size=R.uniform(.26,1.05)*(1.75 if abs(x)>13 else 1.)
                boulder(b,x,z,size)
            for i in range(280):
                x=sign*R.uniform(2.9,22);z=R.uniform(-48+band*21,-27+band*21)
                if abs(x-float(road_center(z)))<3.1 or abs(z-float(river_center(x)))<5.2: continue
                h=ground_height(x,z); col=lin(R.choice(['a9a260','a99a57','929450','c2ac67']))
                for j in range(R.randint(3,6)):
                    t=R.uniform(-pi,pi);p=vec((x+R.uniform(-.13,.13),h-.035,z+R.uniform(-.13,.13)))
                    w=vec((cos(t)*.040,0,sin(t)*.040))
                    b.triangle(p-w,p+w,p+vec((R.uniform(-.12,.12),R.uniform(.18,.42),R.uniform(-.11,.11))),col)
            g.add(b)


def ripple(b,x,z,length,wide):
    y=-2.02+R.uniform(.005,.035);start=vec((x,y,z))
    a=start+vec((length*.45,0,-wide*.49))
    c=start+vec((length*.68,0,wide*.64))
    end=start+vec((length,0,wide*.27))
    col=lin(R.choice(['b9c8a0','a6ba9c','cbd1a7','8eae95']))
    b.quad(start,a,end,c,col)
    if length>1.1:
        b.triangle(end,end+vec((length*.19,0,wide*.20)),c,col)


def river(g):
    b=Batch('Han tributary',3)
    color=lin('658b85')
    for i in range(48):
        x=X0+(X1-X0)*i/48;xx=X0+(X1-X0)*(i+1)/48
        for j in range(6):
            z=float(river_center(x))-4.8+j*1.6;zz=float(river_center(xx))-4.8+j*1.6
            b.quad((x,-2.04,z),(x,-2.04,z+1.6),(xx,-2.04,zz+1.6),(xx,-2.04,zz),tone(color,.07*sin(i*.82+j*.73)))
    for i in range(410):
        x=R.uniform(X0,X1); z=float(river_center(x))+R.uniform(-3.75,3.75)
        ripple(b,x,z,R.uniform(.29,2.25),R.uniform(.026,.092))
    g.add(b)


def bridge(g):
    b=Batch('River bridge • joined timber deck')
    for z in np.linspace(-24.65,-13.35,34):
        c=lin(R.choice(['946e4c','9c7753','a37c53','906b4c','a78059','89684d']))
        b.block((R.uniform(-.045,.045),-.115,z),(9.16+R.uniform(-.13,.13),.23,.324),c)
        # split line and cut-end pegs appear along individual planks
        for _ in range(2):
            x=R.uniform(-4.25,2.80);l=R.uniform(.4,1.8)
            bz=z+R.uniform(-.11,.11)
            b.triangle((x,.002,bz),(x+l*.45,.002,bz+.016),(x+l,.002,bz+.011),tone(c,-.22))
    for x in (-3.83,-1.4,1.4,3.83):
        b.block((x,-.44,-19),( .30,.54,11.85),lin('644f3c'))
    for side in (-1,1):
        x=side*4.59
        b.beam((x,.84,-24.7),(x,.84,-13.24),.086,.086,TIMBER,9)
        b.beam((x,.41,-24.7),(x,.41,-13.24),.057,.057,BARK_LIGHT,8)
        for j in range(7):
            z=-24.68+j*1.9
            b.beam((x,-.69,z),(x,1.035,z),.15,.13,TIMBER,8)
            b.beam((x,.91,z),(x,1.11,z),.151,.07,lin('806246'),8)
            for at in (.41,.82):
                for delta in (-.057,.05):
                    b.beam((x,at+delta,z),(x,at+delta+.033,z),.158,.158,lin('c3a675'),9)
            if j<6:
                b.beam((x,-.03,z),(x,.69,z+1.9),.043,.043,TIMBER,6)
        for z in (-22.15,-16.05):
            b.beam((x*.81,-3.1,z),(x*.81,-.20,z),.23,.18,BARK,8)
            b.beam((x*.81,-2.2,z),(x,-.29,z-1.20),.111,.094,BARK_LIGHT,7)
        for end in (-25.05,-12.93):
            for i in range(3):
                b.block((side*(4.52+.22*i),-.14*i-.18,end),(1.08,.58,1.52-i*.20),tone(BASE,-.08*i))
    g.add(b)


def roof_y(x,z,h,hw,hl):
    xx=abs(x)/hw
    return h+1.20*(1-xx)**1.48+.25*xx**4*(.2+.8*(abs(z)/hl)**3)


def house(g,x,z,w,l,broken=False):
    b=Batch(('Fire-struck house' if broken else 'Village tile house')+' %.1f'%x)
    y=ground_height(x,z)
    hw,hl=w*.5,l*.5
    h=2.19
    def p(xx,yy,zz): return (x+xx,y+yy,z+zz)
    b.block(p(0,.17,0),(w+.48,.34,l+.46),BASE)
    for k in range(3):
        uz=-hl+(k+.5)*l/3
        b.block(p(-hw,.29,uz),(.28,.27,l/3-.045),tone(BASE,-.09+.07*k))
        b.block(p(hw,.29,uz),(.28,.27,l/3-.045),tone(BASE,.08-.05*k))
    for sx in (-1,1):
        for j in range(4):
            zz=-hl+j*(l/3)
            b.beam(p(sx*hw,.24,zz),p(sx*hw,h+(R.uniform(-.68,.0) if broken else .035),zz),.105,.090,BARK if broken else TIMBER,7)
        for j in range(3):
            zz=-hl+(j+.5)*l/3
            if (sx* x<0 and j==1) or (broken and (j+sx)%3): continue
            wh=1.73 if not broken else .72+.64*(j%2)
            b.block(p(sx*hw,.33+wh*.5,zz),(.16,wh,l/3-.085),tone(WALL, R.uniform(-.10,.08)))
            # Clay plaster patches and exposed daub under the eaves.
            for _ in range(6):
                hh=R.uniform(.32,.67)
                along=zz+R.uniform(-l/8,l/8);dw=R.uniform(.07,.26)
                xx=sx*(hw+.087)
                b.triangle(p(xx,hh,along-dw),p(xx,hh+R.uniform(.04,.21),along),p(xx,hh,along+dw),lin('a39576'))
            if not broken and j!=1:
                b.block(p(sx*(hw+.094),1.47,zz),(.025,.48,.67),lin('564e40'))
                for jj in range(4):
                    b.block(p(sx*(hw+.117),1.47,zz-.28+jj*.185),(.042,.50,.027),TIMBER)
        b.beam(p(sx*hw,h,-hl),p(sx*hw,h,hl),.105,.10,TIMBER,7)
    for sz in (-1,1):
        if not broken or sz<0:
            b.block(p(0,1.11,sz*hl),(w-.16,1.55,.17),tone(WALL,-.04))
            b.triangle(p(-hw,h-.05,sz*hl),p(0,h+1.15,sz*hl),p(hw,h-.05,sz*hl),WALL)
        b.beam(p(-hw,h,sz*hl),p(hw,h,sz*hl),.12,.11,TIMBER,7)
        b.beam(p(0,h-.2,sz*hl),p(0,h+1.11,sz*hl),.09,.075,TIMBER,6)
    rw,rl=hw+.48,hl+.52
    for sx in (-1,1):
        for k in range(5):
            inn=k/5;out=(k+1)/5
            for j in range(12):
                n0=-rl+j*(2*rl)/12;n1=-rl+(j+1)*(2*rl)/12
                if broken and ((sx>0 and j>=4) or (sx<0 and j>=7 and k<3)): continue
                def tile(fr,n,off=0):
                    return p(sx*rw*fr,roof_y(rw*fr,n,h,rw,rl)+off,n)
                swatch=tone(TILE,R.uniform(-.13,.16))
                b.quad(tile(inn,n0),tile(inn,n1),tile(out,n1),tile(out,n0),swatch)
                if j%2==0:
                    b.beam(tile(inn,n0,.025),tile(out,n0,.025),.042,.052,tone(RIDGE,-.03),5)
                if k>0:
                    b.beam(tile(out,n0,.016),tile(out,n1,.016),.014,.014,tone(TILE,-.22),4)
        for zz in (-rl,rl):
            for k in range(5):
                inn=k/5;out=(k+1)/5
                b.beam(p(sx*rw*inn,roof_y(rw*inn,zz,h,rw,rl),zz),p(sx*rw*out,roof_y(rw*out,zz,h,rw,rl),zz),.055,.066,RIDGE,6)
        if broken:
            for zz in np.linspace(-hl,hl,8):
                b.beam(p(0,h+1.12,zz),p(sx*rw,h-.08+R.uniform(-.25,.15),zz+.12),.060,.039,lin('4e4338'),6)
    for j in range(12):
        n0=-rl+j*(2*rl)/12;n1=-rl+(j+1)*(2*rl)/12
        if broken and j>=7: continue
        b.beam(p(0,h+1.20,n0),p(0,h+1.20,n1),.105,.113,RIDGE,8)
    for side in (-1,1):
        b.beam(p(0,h+1.20,side*rl),p(0,h+1.45,side*(rl+.18)),.12,.056,RIDGE,8)
    if not broken:
        # Ceramic storage vessels and a bundled bamboo trellis by the doorway.
        sx=-1 if x>0 else 1
        for i in range(3):
            xx=sx*(hw+.41);zz=-hl+.52+i*.46;col=lin(['925e44','a67754','7e674c'][i])
            b.lump(p(xx,.33,zz),(.28,.33,.275),col,rings=3,segs=9,jag=.04)
            b.beam(p(xx,.56,zz),p(xx,.66,zz),.15,.12,col,10)
            b.beam(p(xx,.657,zz),p(xx,.663,zz),.10,.10,lin('544b3b'),10)
    g.add(b)


def well(g):
    b=Batch('Old stone well and windlass')
    x,z=-5.35,1.2
    def p(xx,yy,zz): return vec((x+xx,yy,z+zz))
    for layer in range(3):
        for i in range(12):
            a=(i+layer*.45)*pi/6;d=pi/6-.026;h=.22*layer-.035
            ro,ri=1.04,.69
            def v(r,hh,t): return p(r*cos(t),hh,r*sin(t))
            c=tone(BASE,R.uniform(-.17,.16))
            b.quad(v(ro,h,a),v(ro,h+.214,a),v(ro,h+.214,a+d),v(ro,h,a+d),c)
            b.quad(v(ro,h+.214,a),v(ri,h+.214,a),v(ri,h+.214,a+d),v(ro,h+.214,a+d),tone(c,.11))
            b.quad(v(ri,h,a+d),v(ri,h+.214,a+d),v(ri,h+.214,a),v(ri,h,a),tone(c,-.22))
    b.beam(p(0,.115,0),p(0,.12,0),.68,.68,lin('536e66'),16)
    for sign in (-1,1):
        b.beam(p(sign*1.03,0,-.16),p(sign*.92,1.72,-.16),.09,.074,TIMBER,7)
    b.beam(p(-1.19,1.51,-.16),p(1.21,1.51,-.16),.11,.12,BARK_LIGHT,10)
    for i in range(8):
        xx=-.31+i*.08
        b.beam(p(xx,1.51,-.16),p(xx+.054,1.51,-.16),.14,.14,lin('baa272'),8)
    b.beam(p(.2,.15,-.16),p(.2,1.48,-.16),.022,.022,lin('b49b68'),5)
    b.beam(p(1.2,1.51,-.16),p(1.2,1.18,-.13),.049,.045,TIMBER,7)
    b.beam(p(1.2,1.18,-.13),p(1.48,1.18,-.13),.039,.039,TIMBER,7)
    g.add(b)


def cart(g):
    b=Batch('Overturned handcart at the hamlet')
    x,z=6.65,4.3
    def p(xx,yy,zz): return vec((x+xx+.15*zz,yy+.12*xx,z+zz-.15*xx))
    for sx in (-1,1):
        for j in range(15):
            a=2*pi*j/15;d=2*pi*(j+1)/15
            def spoke(t): return p(sx*.64,.61+.56*sin(t),.56*cos(t))
            b.beam(spoke(a),spoke(d),.043,.044,BARK,6)
            if j%2==0:b.beam(p(sx*.64,.61,0),spoke(a),.036,.023,TIMBER,5)
        b.beam(p(sx*.48,.67,.5),p(sx*.48,.40,1.65),.057,.035,TIMBER,6)
        for j in range(3):
            b.beam(p(sx*.52,.70+j*.13,-.78),p(sx*.52,.70+j*.13,.55),.055,.046,BARK_LIGHT,5)
    for j in range(7):
        zz=-.72+j*.20
        b.beam(p(-.53,.60,zz),p(.53,.60,zz),.09,.095,TIMBER,5)
    for i in range(3):
        b.lump(p(-.20+.19*i,.82,-.45+.26*i),(.33,.25,.38),tone(lin('b6a272'),-.075*i),rings=2,segs=7)
    g.add(b)


def draw_banner_texture():
    # The game project already distributes its subset of Noto Sans SC under the OFL.
    # Source generation can use the subset if the original full font is not installed.
    from PIL import ImageFont
    image=Image.new('RGB',(512,768),'#8e352e')
    pen=ImageDraw.Draw(image,'RGBA')
    for yy in range(768):
        shade=round(10*sin(yy*.051)+5*sin(yy*.21))
        pen.line((0,yy,512,yy),fill=(149+shade,58+shade//2,44+shade//2,255))
    for offset,width in [(14,9),(32,3)]:
        pen.rectangle((offset,offset,511-offset,767-offset),outline=(217,178,98,255),width=width)
    for j in range(12):
        y=52+j*58
        for edge in (17,479):pen.polygon([(edge,y),(edge+10,y+9),(edge,y+18)],fill=(222,182,111,255))
    for x in range(24,489,45):
        pen.polygon([(x,45),(x+16,72),(x+32,45)],fill=(215,174,106,240))
    font=ImageFont.truetype(str(HERE.parents[2]/'godot/assets/fonts/NotoSansSC-Regular.otf'),275)
    pen.text((256,344),'曹',font=font,fill=(243,215,143,255),stroke_width=1,stroke_fill=(239,203,131,255),anchor='mm')
    for y,w in ((518,105),(539,57),(559,22)):
        pen.polygon([(256-w,y),(256,y+19),(256+w,y),(256,y+32)],fill=(222,177,102,255))
    stream=io.BytesIO(); image.save(stream,'JPEG',quality=90)
    return stream.getvalue()


def standards(g):
    b=Batch('Crossing cinnabar standards')
    panels=Batch('Cao army field colours',5)
    for j,(x,z,h) in enumerate([(-4.85,-12.95,4.58),(4.85,-12.95,4.59),(-4.85,-24.8,4.43),(4.85,-24.8,4.45),(-7.50,10.9,3.64)]):
        sgn=1 if x>0 else -1
        b.beam((x,-.06,z),(x,h,z),.094,.047,TIMBER,9)
        b.beam((x,h,z),(x,h+.31,z),.090,.009,lin('d3b17a'),6)
        b.beam((x-.70,h-.18,z),(x+.70,h-.18,z),.049,.047,TIMBER,7)
        def panel(col,row):
            u,v=col/5,row/8
            xx=x+(u-.5)*1.19+sgn*v*.13
            yy=h-.21-v*1.88
            zz=z+.13*sin(u*6+v*1.8+j*.79)*(.45+.55*v)
            return (xx,yy,zz)
        for col in range(5):
            for row in range(8):
                ids=[(col,row),(col,row+1),(col+1,row+1),(col+1,row)]
                for tri in ((0,1,2),(0,2,3)):
                    ix=[ids[k] for k in tri]
                    panels.triangle(*[panel(c,r) for c,r in ix],(1,1,1),[(c/5,r/8) for c,r in ix])
        for k in range(7):
            c=k/7*5
            p0=vec(panel(c,8));p1=vec(panel(c+.46,8))
            panels.triangle(p0,p1,p0+vec((.051*sgn,-.19-.08*sin(k),.04)),(1,1,1),[(.15,.9),(.16,.9),(.19,.99)])
        if j<4:
            b.block((x,.15,z),(.48,.3,.49),BASE)
    g.add(b);g.add(panels)


def beacon(g):
    b=Batch('Northern watchtower beyond crossing')
    x,z=-8.3,-36
    y=ground_height(x,z)
    def p(xx,yy,zz):return(x+xx,y+yy,z+zz)
    for sx in (-1,1):
        for sz in (-1,1):
            b.beam(p(sx*1.56,0,sz*1.48),p(sx*1.04,6.53,sz*1.0),.20,.11,TIMBER,8)
        b.beam(p(sx*1.4,.6,-1.4),p(sx*1.19,3.90,1.2),.10,.095,BARK_LIGHT,6)
        b.beam(p(sx*1.4,.6,1.4),p(sx*1.19,3.90,-1.2),.10,.095,BARK_LIGHT,6)
        b.beam(p(-1.4,.6,sx*1.4),p(1.19,3.90,sx*1.2),.10,.095,BARK_LIGHT,6)
        b.beam(p(-1.35,5.05,sx*1.35),p(1.35,5.05,sx*1.35),.07,.07,TIMBER,6)
        b.beam(p(sx*1.35,5.05,-1.35),p(sx*1.35,5.05,1.35),.07,.07,TIMBER,6)
    b.block(p(0,3.96,0),(3.45,.24,3.45),TIMBER)
    rings=[]
    for half,hh,corner in [(2.17,6.23,.26),(1.36,6.52,.12),(.46,7.38,0)]:
        ring=[]
        for xx,zz in [(-1,-1),(-1,0),(-1,1),(0,1),(1,1),(1,0),(1,-1),(0,-1)]:
            ring.append(p(xx*half,hh+corner*abs(xx*zz),zz*half))
        rings.append(ring)
    for i in range(8):
        for j in range(2):
            b.quad(rings[j][i],rings[j+1][i],rings[j+1][(i+1)%8],rings[j][(i+1)%8],tone(TILE,-.13+.06*i))
            if i%2==0:b.beam(rings[j][i],rings[j+1][i],.071,.061,RIDGE,7)
        b.triangle(rings[-1][i],p(0,7.68,0),rings[-1][(i+1)%8],RIDGE)
    b.beam(p(0,7.58,0),p(0,8.05,0),.12,.024,lin('c3a173'),7)
    g.add(b)


def far_bank(g):
    foliage=Batch('Distant woods on the northern terraces')
    # Leave the bent road visible through two groves; stagger the last horizon.
    for i in range(45):
        z=R.uniform(-54,-30)
        x=R.uniform(-32,32)
        if abs(x-float(road_center(z)))<3.4 or abs(x+8.3)<2.3 and abs(z+36)<3.0:
            continue
        y=ground_height(x,z)
        sc=R.uniform(.65,1.24)
        col=lin(R.choice(['647f68','75886b','8a926c','6e8269']))
        foliage.beam((x,y-.02,z),(x,y+1.6*sc,z),.115*sc,.069*sc,BARK,6)
        for j in range(3):
            th=j*2.39+i*.37
            foliage.lump((x+.72*sc*cos(th),y+(1.5+j*.27)*sc,z+.72*sc*sin(th)),(.95*sc,.70*sc,.85*sc),tone(col,j*.065),rings=2,segs=7,jag=.25)
    for i in range(27):
        z=R.uniform(-51,-34);x=R.uniform(-25,23)
        if abs(x-float(road_center(z)))>3.9:
            boulder(foliage,x,z,R.uniform(.49,1.35))
    g.add(foliage)
    headland=Batch('Northern bank beyond the trail')
    for i in range(24):
        for j in range(6):
            corners=[]
            for ix,jz in [(i,j),(i,j+1),(i+1,j+1),(i+1,j)]:
                x=-46+ix*92/24;z=-54-jz*3.7
                y=ground_height(x,-54)-.10+jz*.19*sin(x*.24+jz*.4)
                corners.append((x,y,z))
            headland.quad(*reversed(corners),tone(lin('6d8068'),.12*sin(i*.64+j*.77)))
    g.add(headland)


def shoulders(g):
    for side in (-1,1):
        b=Batch('Worn grassy shoulder '+str(side))
        for i in range(148):
            z=R.uniform(-12,25)
            x=float(road_center(z))+side*R.uniform(2.9,4.75)
            # Flat stones partially buried in chalky soil, so cavalry can traverse.
            scale=R.uniform(.09,.34)
            col=lin(R.choice(('a59b83','928b74','afa389','877f69')))
            b.lump((x,.008,z),(scale*1.45,scale*.24,scale*.73),col,rings=1,segs=6,jag=.28)
        # Reed clumps placed along specific bends and erosion hollows. Bow the
        # blades and turn the stalks in different directions under the same wind.
        for cz in (-9.95,-6.0,3.9,7.2,12.1,15.3,19.8):
            for _ in range(4):
                z=cz+R.uniform(-.71,.71)
                x=float(road_center(z))+side*R.uniform(3.45,5.60)
                for blade in range(11):
                    a=R.uniform(0,2*pi);l=R.uniform(.21,.54)
                    base=vec((x+R.uniform(-.14,.14),.012,z+R.uniform(-.14,.14)))
                    width=vec((.032*cos(a),0,.032*sin(a)))
                    lean=vec((.22*sin(a)+.06,0,.22*cos(a)))
                    mid=base+vec((0,l*.63,0))+lean*.23
                    tip=base+vec((0,l*.89,0))+lean
                    c=lin(R.choice(('9e9c60','88925c','b3a763','b8aa6b')))
                    b.quad(base-width,base+width,mid+width*.66,mid-width*.66,c)
                    b.triangle(mid-width*.66,mid+width*.66,tip,tone(c,.15))
                    if blade%5==0:
                        b.lump(tip+vec((0,.025,0)),(.026,.056,.026),lin('bbae75'),rings=1,segs=4,jag=.02)
        g.add(b)


def wayside(g):
    b=Batch('Travelers fence and weathered stones')
    for x,za,zb in [(-7.60,3.2,8.7),(8.40,7.9,13.3),(9,-6.7,-3.9),(-9.3,-11.1,-6.1)]:
        count=max(3,int((zb-za)/1.2))
        base=ground_height(x,(za+zb)*.5)
        for i in range(count+1):
            z=za+(zb-za)*i/count
            b.beam((x-.04,base-.06,z),(x+R.uniform(-.12,.12),base+R.uniform(.74,1.06),z+.04),.090,.055,BARK,6)
        for hh in (.26,.69):
            b.beam((x,base+hh,za-.15),(x,base+hh-.07,zb+.21),.060,.050,BARK_LIGHT,6)
    for i in range(26):
        x=R.choice([-1,1])*R.uniform(3.8,7.6);z=R.uniform(-10.8,28)
        b.lump((x,.015,z),(R.uniform(.09,.26),R.uniform(.05,.11),R.uniform(.10,.24)),R.choice(ROCKS),rings=1,segs=6)
    g.add(b)


def main():
    g=Gltf(painted_ground())
    g.add_image(draw_banner_texture(),'image/jpeg','Cao army embroidered flag')
    g.g['materials'][5]['pbrMetallicRoughness']['baseColorTexture']={'index':1}
    R.seed(8720)
    terrain(g);mountains(g);river(g);bridge(g);standards(g)
    house(g,9.4,-.35,3.9,5.45);house(g,-10.55,-1.7,4.05,6.15,True)
    house(g,-16.5,4.8,3.2,4.7);house(g,16.4,-4.75,3.10,4.3,True)
    beacon(g);well(g);cart(g);wayside(g);flora(g);far_bank(g);shoulders(g)
    g.save()


if __name__=='__main__':main()


