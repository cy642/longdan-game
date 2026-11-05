"""Bake the original 3D Changban scenery. Run from any directory with Python, Pillow and NumPy."""
from pathlib import Path
import io
import json
import math
import random
import struct

import numpy as np
from PIL import Image, ImageDraw
from painted_surfaces import architecture_atlas, foliage_atlas, meadow_atlas, field_brush, uv_patch

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
    # The battle lane stays level; its shoulders taper into eroded grassy hollows.
    shoulder = max(0, min(1, (abs(x)-7.3)/4.3))
    hills += shoulder * (.44*sin(x*.87+z*.23) + .22*cos(z*.81-x*.19) +
                        .25*math.exp(-((x-12)/4)**2)*sin(z*.47))
    hills += min(1, max(0, (-z-29)/16)) * (1.72 + 1.12*cos(x*.23-z*.12) + .63*sin(x*.41+z*.21))
    bank = abs(z - float(river_center(x)))
    if bank >= 5.2:
        return hills * min(1, (bank - 5.2)/3)
    slope = min(1, (5.2-bank)/2.4)
    return -3.1 * slope*slope*(3-2*slope)


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
    well_track = np.exp(-((z-1.4+.34*np.sin(x*.77))/.98)**2)*np.clip((-x-.6)/1.4,0,1)*np.clip((x+6.6)/1.5,0,1)
    path = np.maximum(path, (.78+.32*mid)*well_track)
    charred = np.exp(-((x+9.6)/3.2)**2-((z+1.7)/4.2)**2)
    damp = .24 * np.exp(-((x+5.35)/2.1)**2-((z-1.2)/2.1)**2)
    colors = []
    for i in range(3):
        grassy = (99,115,81)[i]+(41,42,26)[i]*broad+25*mid+12*fine+stripes*(16,17,8)[i]
        dusty = (151,125,91)[i]+39*broad+23*mid+13*fine-31*wagon+13*wheel_lip
        shore = (121,123,103)[i]+35*broad+23*mid+11*fine
        colors.append(((grassy*(1-path)+dusty*path)*(1-bank)+bank*shore)*(1-.46*charred-damp))
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
    def faced(self,points,uvs,color=(1,1,1)):
        for ids in ((0,1,2),(0,2,3)):
            self.triangle(*[points[k] for k in ids],color,[uvs[k] for k in ids])
    def patch(self,points,name,u0=0,v0=0,u1=1,v1=1):
        self.faced(points,[uv_patch(name,u,v) for u,v in ((u0,v0),(u0,v1),(u1,v1),(u1,v0))])
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
        start=len(self.norm)
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
        # Carry rounded volume through triangulation: hand-painted hollows
        # come from broad planes, rather than flashing triangular silhouettes.
        inverse=np.reciprocal(np.maximum(np.square(radii),1.e-5))
        positions=np.asarray(self.pos[start:])-np.asarray(center)
        gradients=positions*inverse
        gradients/=np.maximum(np.linalg.norm(gradients,axis=1)[:,None],1.e-7)
        mixed=gradients*.77+np.asarray(self.norm[start:])*.23
        self.norm[start:]=list(mixed/np.maximum(np.linalg.norm(mixed,axis=1)[:,None],1.e-7))


class Gltf:
    def __init__(self,image):
        self.data=bytearray()
        self.g={'asset':{'version':'2.0','generator':'Longdan / Changban scenery bake'},'scene':0,
                'scenes':[{'name':'Changban Landscape','nodes':[]}],'nodes':[],'meshes':[],
                'buffers':[{}],'bufferViews':[],'accessors':[], 'materials':[], 'textures':[], 'images':[]}
        self.g['materials']=[{'name':name, 'doubleSided':True,'pbrMetallicRoughness':{'metallicFactor':0,'roughnessFactor':.94}} for name in
                             ['Hand-painted forms','Painted terrain','Eastern river cloth','Lacquered water','Silhouette mountains','Banner writing',
                              'Painted village surfaces','Painted leaf sprays','Painted grasses']]
        self.g['materials'][7].update({'alphaMode':'MASK','alphaCutoff':.42})
        self.g['materials'][8].update({'alphaMode':'MASK','alphaCutoff':.36})
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
        # Weld vertices only when normal, UV and paint agree. Batched foliage,
        # plaster walls and riverbanks can then share their edge vertices.
        arrays = [np.asarray(b.pos,'f4'),np.asarray(b.norm,'f4')]
        painted = b.material not in (1,5,6,7,8)
        if painted: arrays.append(np.rint(np.asarray(b.color)*255).clip(0,255))
        if b.uv:
            if len(b.uv)!=len(b.pos): raise ValueError('Incomplete UVs: '+b.name)
            arrays.append(np.asarray(b.uv,'f4'))
        points, inverse = np.unique(np.concatenate(arrays,axis=1).astype('f4'),return_inverse=True,axis=0)
        attrs={'POSITION':self.attr(points[:,:3],3,bounds=True),'NORMAL':self.attr(points[:,3:6],3)}
        if painted:
            colors=np.column_stack((points[:,6:9],np.full(len(points),255)))
            attrs['COLOR_0']=self.attr(colors,4,'u1')
        if b.uv: attrs['TEXCOORD_0']=self.attr(points[:,-2:],2)
        small = len(points)<65536
        index = len(self.g['accessors'])
        self.g['accessors'].append({'bufferView':self.view(inverse.astype('<u2' if small else '<u4').tobytes()),
                                    'componentType':5123 if small else 5125,'count':len(b.pos),'type':'SCALAR'})
        self.g['scenes'][0]['nodes'].append(len(self.g['nodes']))
        self.g['nodes'].append({'name':b.name,'mesh':len(self.g['meshes'])})
        self.g['meshes'].append({'name':b.name,'primitives':[{'attributes':attrs,'indices':index,'material':b.material}]})
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
    b.lump((x,y+s*.17,z),(s*1.25,s*.64,s*.87),R.choice(ROCKS),rings=4,segs=11,jag=.13)
    if s>.9:
        b.lump((x+s*.67,y+s*.075,z+.15*s),(s*.64,s*.32,s*.46),lin('868976'),rings=3,segs=9,jag=.13)


def leaf_spray(leaves,center,width,height,angle,patch,droop):
    """Convex five-point leaf fans intersect around a volume, with no camera-facing substitution."""
    across=vec((cos(angle),0,sin(angle)))
    depth=vec((-sin(angle),0,cos(angle)))
    ahead=vec(center)
    def point(u,v):
        bulge=(1-(u*2-1)**2)*(.18+.24*(1-(v*2-1)**2))
        return ahead + across*(u-.5)*width + depth*(bulge*width+droop*(v-.5)) + vec((0,(.5-v)*height,0))
    def uv(u,v): return ((patch%2+.013+u*.974)/2,(patch//2+.013+v*.974)/2)
    for j in range(2):
        for k in range(2):
            u,v=j/2,k/2
            coords=[(u,v),(u,v+.5),(u+.5,v+.5),(u+.5,v)]
            start=len(leaves.norm)
            leaves.faced([point(a,b) for a,b in coords],[uv(a,b) for a,b in coords])
            # Crown facing stays upward at the top, bending outward around the side.
            for n in range(start,len(leaves.norm)):
                leaves.norm[n]=unit(depth*.39+vec((0,.91,0)))


def crown(leaves,at,spread,height,angle,patch):
    for j in range(4):
        turn=angle+j*pi*.5
        along=vec((cos(turn),0,sin(turn)))
        leaf_spray(leaves,vec(at)+along*.18*spread,spread,height,turn+pi*.5,patch,.19*spread)
    leaf_spray(leaves,vec(at)+vec((0,height*.17,0)),spread*.80,height*.85,angle+pi*.25,patch,.34*spread)


def tussock(blades,x,y,z,width,height,patch):
    angle=R.uniform(0,pi)
    for j in range(2):
        theta=angle+j*pi*.5
        across=vec((cos(theta),0,sin(theta)))*width*.5
        wind=vec((.062,0,.027))
        root=vec((x,y-.018,z))
        top=root+vec((0,height,0))+wind
        coords=[(0,0),(0,1),(1,1),(1,0)]
        uv=[((patch%2+.009+u*.982)/2,(patch//2+.009+v*.982)/2) for u,v in coords]
        begin=len(blades.norm)
        blades.faced([top-across,root-across,root+across,top+across],uv)
        blades.norm[begin:]=[vec((0,1,0))]*(len(blades.norm)-begin)


def broadleaf(b,leaves,x,z,s,autumn):
    y=ground_height(x,z)
    angle=R.uniform(0,2*pi)
    tilt=vec((cos(angle)*s*.57,0,sin(angle)*s*.57))
    root=vec((x,y-.08,z))
    lower=root+vec((0,s*.80,0))-tilt*.18
    mid=root+vec((0,s*1.73,0))+tilt*.31
    crown_center=mid+vec((0,s*1.32,0))+tilt*.76
    b.beam(root,lower,.34*s,.22*s,BARK,11)
    b.beam(lower,mid,.235*s,.15*s,BARK,10)
    b.beam(mid,crown_center,.17*s,.073*s,BARK_LIGHT,9)
    for j in range(6):
        th=angle+j*1.08
        offset=vec((cos(th),0,sin(th)))
        b.beam(root+offset*s*.15+vec((0,s*.63,0)),root+offset*s*.79+vec((0,.03,0)),.17*s,.033*s,BARK,7)
    patch=1 if autumn in (1,2,3) else (3 if autumn==4 else 0)
    for i in range(7):
        th=angle+i*2.399
        length=(1.34+.46*cos(i*2.7))*s
        out=vec((cos(th),0,sin(th)))
        elbow=mid+tilt*.53+out*length*.53+vec((0,s*(.31+i*.12),0))
        tip=mid+tilt*.78+out*length+vec((0,s*(.95+i*.15),0))
        b.beam(mid,elbow,.115*s,.077*s,BARK,8)
        b.beam(elbow,tip,.088*s,.033*s,BARK_LIGHT,7)
        twig=tip+out*.40*s+vec((0,.25*s,0))
        b.beam(tip,twig,.039*s,.013*s,BARK,6)
        crown(leaves,tip+vec((0,s*.30,0)),2.05*s,1.18*s,th,patch)
    crown(leaves,crown_center+vec((0,s*.51,0)),2.27*s,1.28*s,angle+.54,patch)


def conifer(b,leaves,x,z,s):
    y=ground_height(x,z)
    sign=R.choice([-1,1]);last=vec((x,y,z))
    for k in range(5):
        tip=vec((x+sign*.16*k*s,y+(k+1)*.87*s,z+.085*k*s))
        b.beam(last,tip,s*(.23-.038*k),s*(.18-.036*k),BARK,8)
        last=tip
        for j in range(4):
            th=j*pi*.5+k*1.29
            length=s*(1.64-.255*k)
            out=vec((cos(th),0,sin(th)))
            elbow=tip+out*length*.55+vec((0,.12*s,0))
            end=tip+out*length+vec((0,.34*s,0))
            b.beam(tip,elbow,.078*s,.041*s,BARK,7)
            b.beam(elbow,end,.045*s,.021*s,BARK_LIGHT,6)
            crown(leaves,end,1.8*length,1.04*s,th,2)
    crown(leaves,last+vec((0,s*.37,0)),1.30*s,1.32*s,.30,2)


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
        b=Batch('Elder wood trunk and boughs %02d'%index)
        leaves=Batch('Painted canopy %02d'%index,7)
        for ti,(x,z,s,palette) in enumerate(near[index:index+6]):
            if (ti+index)%4==0: conifer(b,leaves,x,z,s*1.24)
            else: broadleaf(b,leaves,x,z,s,palette)
        g.add(b);g.add(leaves)
    for sign in (-1,1):
        for band in range(4):
            b=Batch('Meadow blades %d %d'%(sign,band),8)
            stones=Batch('Weathered stone %d %d'%(sign,band))
            for i in range(34):
                x=sign*R.uniform(7.4,38);z=R.uniform(-48+band*21,-27+band*21)
                size=R.uniform(.26,1.05)*(1.75 if abs(x)>13 else 1.)
                boulder(stones,x,z,size)
            for i in range(280):
                x=sign*R.uniform(2.9,22);z=R.uniform(-48+band*21,-27+band*21)
                if abs(x-float(road_center(z)))<3.1 or abs(z-float(river_center(x)))<5.2: continue
                tussock(b,x,ground_height(x,z),z,R.uniform(.38,.69),R.uniform(.24,.51),R.randrange(4))
            g.add(b);g.add(stones)


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


def roof_y(xx,zz,h,hw,hl):
    # Sag at mid-slope, with a real overhanging fascia and swept-up gable tips.
    fr=abs(xx)/hw
    return h + 1.55*(1-fr)**1.72 + .34*fr**4*(.15+.85*(abs(zz)/hl)**3)


def tiled_roof(frame, painted, p, hw, hl, h, burnt):
    rw,rl=hw+.54,hl+.55
    courses, bays=6,15
    def roof(s,fr,n,off=0):
        return vec(p(s*rw*fr,roof_y(s*rw*fr,n,h,rw,rl)+off,n))
    for side in (-1,1):
        # Continuous rectified painted tile courses wrap both sloping surfaces.
        # Missing sections follow irregular stepped lines through the damaged roof.
        for row in range(courses):
            f0,f1=row/courses,(row+1)/courses
            for bay in range(bays):
                v0,v1=bay/bays,(bay+1)/bays
                z0,z1=(v0*2-1)*rl,(v1*2-1)*rl
                if burnt and ((side>0 and bay>3+(row*2)%4) or
                              (side<0 and bay>9+(row//2)%3 and row<5)): continue
                corners=[roof(side,f0,z0),roof(side,f1,z0),roof(side,f1,z1),roof(side,f0,z1)]
                painted.patch(corners,'tile',v0,f0,v1,f1)
                if row==courses-1:
                    # Dark bed of clay just inside the rounded ends.
                    frame.quad(corners[1],corners[2],corners[2]+vec((0,-.09,0)),corners[1]+vec((0,-.09,0)),lin('51483b'))
        for zz in (-rl,rl):
            for k in range(courses):
                a=roof(side,k/courses,zz); b=roof(side,(k+1)/courses,zz)
                frame.beam(a,b,.092,.088,lin('795339'),8)
                frame.beam(a+vec((0,.057,0)),b+vec((0,.055,0)),.036,.038,lin('bb8050'),6)
            end=roof(side,1,zz)
            frame.beam(end-vec((.02*side,0,0)),end+vec((side*.17,.10,.03)),.102,.068,lin('8b5e3e'),7)
        for i in range(17):
            z0=-rl+(i+.5)*2*rl/17
            if burnt and side>0 and z0>-.7: continue
            # Glazed tubular ridge-ends, with recessed dark circular centres.
            cap=roof(side,1,z0,0)
            frame.beam(cap-vec((side*.19,-.02,0)),cap+vec((side*.03,0,0)),.095,.119,lin('626d69'),11)
            frame.beam(cap+vec((side*.033,0,0)),cap+vec((side*.038,0,0)),.069,.069,lin('403c36'),10)
        if burnt:
            for i,zz in enumerate(np.linspace(-hl,hl,11)):
                end=roof(side,.70+.27*((i*3)%5)/4,zz)
                frame.beam(roof(side,0,zz,-.14),end+vec((0,-.14-.23*(i%3),.12*sin(i))),.071,.035,lin('5c4639'),7)
                if i%3==1:
                    frame.beam(end+vec((0,-.23,0)),end+vec((side*.18,-.05,.03)),.040,.009,lin('958264'),5)
    for j in range(12):
        a= (j/12*2-1)*rl
        b= ((j+1)/12*2-1)*rl
        if burnt and j in (7,8,9,10): continue
        frame.beam(p(0,h+1.59,a),p(0,h+1.59,b),.12,.119,lin('606963'),10)
    for sign in (-1,1):
        fin=vec(p(0,h+1.59,sign*rl))
        frame.beam(fin,fin+vec((0,.13,.15*sign)),.15,.102,lin('79523a'),9)
        frame.beam(fin+vec((0,.13,.15*sign)),fin+vec((0,.31,.21*sign)),.104,.037,lin('aa7950'),8)


def doorway(frame,painted,p,hw,hl,side,along_z):
    """Raised doorsill and rafters take real depth under the painted facade."""
    def d(u,y,out):
        if along_z: return vec(p(u-hw*.49,y,side*(hl+out)))
        return vec(p(side*(hw+out),y,u-hl*.49))
    for i in range(2):
        for j in range(3):
            left=-.81+j*.55+.012*(i%2)
            front=.28+(1-i)*.30
            top=.17+i*.15
            c=tone(lin('998e76'),.07*sin(j*2+i))
            painted.patch([d(left,top,.02),d(left,top,front),d(left+.535,top,front),d(left+.535,top,.02)],
                          'stone',j*.24,i*.20,j*.24+.22,i*.20+.21)
            frame.quad(d(left,top,front),d(left,top-.15,front),d(left+.535,top-.15,front),d(left+.535,top,front),tone(c,-.16))
    for u in (-.96,.96):
        frame.beam(d(u,.34,.07),d(u,1.96,.09),.080,.073,TIMBER,8)
        frame.beam(d(u,1.63,.08),d(u,1.88,.36),.045,.053,lin('8f6e49'),7)
    frame.beam(d(-1.08,1.97,.09),d(1.09,2.0,.09),.095,.086,lin('7a5438'),7)
    # Planked rain canopy above the double door, with feathered straw ends.
    for j in range(14):
        u=-1.05+j*.153
        painted.patch([d(u,2.05,.06),d(u,1.84,.69),d(u+.151,1.83+.026*sin(j),.68+.032*sin(j*3)),d(u+.151,2.055,.06)],
                      'wood',j/14,0,(j+1)/14,1)


def house(g,x,z,w,l,broken=False):
    frame=Batch(('Fire-struck timbers' if broken else 'Village timber joinery')+' %.1f'%x)
    painted=Batch(('Burnt plaster and salvaged tiles' if broken else 'Painted rammed earth and tiles')+' %.1f'%x,6)
    hw,hl=w*.5,l*.5;h=2.24
    y=ground_height(x,z)
    def p(xx,yy,zz): return (x+xx,y+yy,z+zz)
    # Raised stone plinth: uneven individual courses at its silhouette; the
    # photographed corners of the original painted foundation wrap its face.
    frame.block(p(0,.16,0),(w+.24,.32,l+.22),lin('797963'))
    for along_z,half,run in ((True,hl,hw),(False,hw,hl)):
        for side in (-1,1):
            def v(u,yy,off=.0):
                return p(u,yy,side*(half+off)) if along_z else p(side*(half+off),yy,u)
            ends=[v(u,0,.125) for u in (-run-.12,run+.12)]
            footing=[min(-.10,ground_height(xx,zz)-y-.12) for xx,_,zz in ends]
            foundation=[v(-run-.12,.38,.125),v(-run-.12,footing[0],.125),v(run+.12,footing[1],.125),v(run+.12,.38,.125)]
            painted.patch(foundation,'foundation')
            # A frontage and a gable can both be read as the player circles the
            # house; every face has textured masonry and an independent roof lip.
            visible_entrance=not along_z and side*x<0
            if broken:
                n=12
                for j in range(n):
                    u0,u1=j/n,(j+1)/n
                    t=(j+0.5)/n
                    height=h*(.77+.23*cos(t*pi*1.7)) if side*x<0 or (along_z and side==1) else h
                    if side*x<0 and .32<t<.59: continue
                    top0=height-.20*(j%3==0);top1=height-.17*(j%3==2)
                    corners=[v((u0*2-1)*run,top0,.01),v((u0*2-1)*run,.34,.01),
                             v((u1*2-1)*run,.34,.01),v((u1*2-1)*run,top1,.01)]
                    painted.patch(corners,'ruin',u0,min(.75,(h-min(top0,top1))/(h-.34)),u1,1)
                    if top0<h-.20:
                        frame.beam(corners[0],corners[3],.058,.035,lin('9b7255'),5)
            else:
                if along_z and side>0:
                    # One recessed lattice bay in the gable; its scale follows a
                    # room's window and the sill actually projects over the render.
                    for lo,hi,name in ((-run,-.84,'gable'),(-.84,.84,'window'),(.84,run,'gable')):
                        recess=-.055 if name=='window' else .012
                        painted.patch([v(lo,h,recess),v(lo,.34,recess),v(hi,.34,recess),v(hi,h,recess)],name)
                    for uu in (-.85,.85):
                        frame.beam(v(uu,.32,.05),v(uu,h,.05),.075,.068,TIMBER,8)
                    frame.beam(v(-.83,.77,.06),v(.84,.77,.06),.056,.056,TIMBER,8)
                else:
                    corners=[v(-run,h,.011),v(-run,.34,.011),v(run,.34,.011),v(run,h,.011)]
                    painted.patch(corners,'front' if visible_entrance else 'gable')
            for u in (-run,run):
                frame.beam(v(u,.26,.025),v(u,h+(.055 if not broken else -.26),.045),.115,.10,lin('674a37'),8)
            frame.beam(v(-run,h,.016),v(run,h,.016),.11,.10,lin('7c583d'),8)
            if along_z and (not broken or side<0):
                apices=[v(-run,h-.045,.018),v(run,h-.045,.018),v(0,h+1.55,.018)]
                painted.triangle(*apices,(1,1,1),[uv_patch('gable',0,1),uv_patch('gable',1,1),uv_patch('gable',.5,0)])
                frame.beam(v(0,h-.015,.055),v(0,h+1.55,.055),.082,.079,TIMBER,8)
                for q in (-1,1):
                    frame.beam(v(q*run*.63,h+.03,.05),v(q*run*.23,h+.88,.05),.047,.050,lin('765b41'),7)
    tiled_roof(frame,painted,p,hw,hl,h,broken)
    if not broken:
        doorway(frame,painted,p,hw,hl,-1 if x>0 else 1,False)
        for j in range(3):
            sx=-1 if x>0 else 1
            xx=sx*(hw+.46);zz=-hl+.40+j*.48
            c=lin(('9b6849','b78760','766042')[j])
            frame.lump(p(xx,.34,zz),(.28,.35,.29),c,4,12,.023)
            frame.beam(p(xx,.62,zz),p(xx,.69,zz),.146,.132,c,12)
            frame.beam(p(xx,.690,zz),p(xx,.695,zz),.098,.099,lin('54463b'),11)
    else:
        # Rubble rests beside the torn-out wall rather than floating in a single pile.
        for _ in range(22):
            zz=R.uniform(-hl+.18,hl)
            xx=(hw+R.uniform(.12,.90))*(1 if x<0 else -1)
            frame.lump(p(xx,.07,zz),(R.uniform(.12,.29),R.uniform(.06,.17),R.uniform(.15,.29)),
                       lin(R.choice(('967e67','9f8974','a07557'))),2,8,.16)
    g.add(frame);g.add(painted)


def well(g):
    b=Batch('Old windlass and wooden bucket')
    blocks=Batch('Weathered stone of the village well')
    x,z=-5.35,1.2
    def p(xx,yy,zz): return vec((x+xx,yy,z+zz))
    for layer in range(3):
        n=11+layer%2
        for i in range(n):
            a=(i+layer*.45)*2*pi/n;d=2*pi/n-.023;h=.225*layer-.035
            ro=R.uniform(1.0,1.045)+(.045 if layer==2 else 0);ri=R.uniform(.68,.715)
            thick=R.uniform(.201,.223); c=tone(BASE,R.uniform(-.15,.21))
            profile=((ro-.05,h),(ro,h+.035),(ro+.006,h+thick-.038),
                     (ro-.045,h+thick),(ri+.026,h+thick-.005),(ri,h+thick-.04),(ri,h))
            def v(r,hh,t): return p(r*cos(t),hh,r*sin(t))
            for k in range(len(profile)-1):
                r0,h0=profile[k];r1,h1=profile[k+1]
                for seg in range(2):
                    start=a+d*seg*.5;end=start+d*.5
                    blocks.quad(v(r0,h0,start),v(r1,h1,start),v(r1,h1,end),v(r0,h0,end),
                                tone(c,(.03,.0,.05,.13,-.06,-.14)[k]))
            for angle in (a,a+d):
                vertices=[v(rad,hh,angle) for rad,hh in profile]
                for j in range(1,len(vertices)-1):
                    blocks.triangle(vertices[0],vertices[j],vertices[j+1],tone(c,-.15))
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
    # A weathered wooden pail over the opening gives the lowered rope an endpoint.
    bx,bz=.19,-.16
    for i in range(12):
        a=i*pi/6;aa=(i+1)*pi/6-.015
        b.quad(p(bx+.14*cos(a),.14,bz+.14*sin(a)),p(bx+.188*cos(a),.40,bz+.188*sin(a)),
               p(bx+.188*cos(aa),.40,bz+.188*sin(aa)),p(bx+.14*cos(aa),.14,bz+.14*sin(aa)),
               tone(TIMBER,.16*sin(i*2.4)))
    for h in (.19,.34):
        for i in range(12):
            a=i*pi/6;aa=(i+1)*pi/6;rad=.156 if h<.3 else .181
            b.beam(p(bx+rad*cos(a),h,bz+rad*sin(a)),p(bx+rad*cos(aa),h,bz+rad*sin(aa)),
                   .014,.014,lin('9c946c'),5)
    g.add(blocks);g.add(b)


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
    foliage=Batch('Distant northern grove trunks')
    leaves=Batch('Painted canopy of the northern pass',7)
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
            crown(leaves,(x+.68*sc*cos(th),y+(1.7+j*.29)*sc,z+.68*sc*sin(th)),1.95*sc,1.35*sc,th,3)
    for i in range(27):
        z=R.uniform(-51,-34);x=R.uniform(-25,23)
        if abs(x-float(road_center(z)))>3.9:
            boulder(foliage,x,z,R.uniform(.49,1.35))
    g.add(foliage);g.add(leaves)
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
        b=Batch('Meadow blades on road shoulder '+str(side),8)
        stones=Batch('Weathered stone of road shoulder '+str(side))
        for i in range(92):
            z=R.uniform(-12,25)
            x=float(road_center(z))+side*R.uniform(2.9,4.75)
            # Flat stones partially buried in chalky soil, so cavalry can traverse.
            scale=R.uniform(.055,.17)
            col=lin(R.choice(('a59b83','928b74','afa389','877f69')))
            stones.lump((x,.023,z),(scale*1.19,scale*.52,scale*.83),col,rings=3,segs=11,jag=.10)
        # Slender foxtails and wider dusty blades gather around damp bends.
        for cz in (-9.95,-6.0,3.9,7.2,12.1,15.3,19.8):
            for _ in range(8):
                z=cz+R.uniform(-.76,.76)
                x=float(road_center(z))+side*R.uniform(3.4,5.6)
                tussock(b,x,ground_height(x,z),z,R.uniform(.35,.69),R.uniform(.24,.58),R.choice((1,2,3)))
        g.add(b);g.add(stones)


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
        b.lump((x,.016,z),(R.uniform(.09,.22),R.uniform(.05,.11),R.uniform(.10,.21)),R.choice(ROCKS),rings=3,segs=10,jag=.11)
    g.add(b)


def main():
    g=Gltf(painted_ground())
    g.add_image(draw_banner_texture(),'image/jpeg','Cao army embroidered flag')
    g.g['materials'][5]['pbrMetallicRoughness']['baseColorTexture']={'index':1}
    g.add_image(architecture_atlas(),'image/jpeg','Village painted atlas')
    g.g['materials'][6]['pbrMetallicRoughness']['baseColorTexture']={'index':2}
    g.add_image(foliage_atlas(),'image/png','Canopy painted sprays')
    g.g['materials'][7]['pbrMetallicRoughness']['baseColorTexture']={'index':3}
    g.add_image(meadow_atlas(),'image/png','Meadow painted tufts')
    g.g['materials'][8]['pbrMetallicRoughness']['baseColorTexture']={'index':4}
    field_brush()
    R.seed(8720)
    terrain(g);mountains(g);river(g);bridge(g);standards(g)
    house(g,9.4,-.35,3.9,5.45);house(g,-10.55,-1.7,4.05,6.15,True)
    house(g,-16.5,4.8,3.2,4.7);house(g,16.4,-4.75,3.10,4.3,True)
    beacon(g);well(g);cart(g);wayside(g);flora(g);far_bank(g);shoulders(g)
    g.save()


if __name__=='__main__':main()


