"""Deterministic Blender 4.3+ models and orthographic RGBA landmark sprites.

From the repository root:
    blender --background --factory-startup --python godot/art_source/regenerate_landmarks.py
Optional: -- --samples 128 --only altar

All meshes, materials, lights and cameras are original procedural work. The
models are authored in metres with 32 world pixels/metre and rendered at 2x.
Nothing in this script changes gameplay, map placement or collision geometry.
"""
from pathlib import Path
import argparse
import json
import math
import random
import struct
import sys

import bpy
from mathutils import Vector

ROOT = Path(__file__).resolve().parent.parent
OUTPUT = ROOT / "assets" / "props"
SOURCE = ROOT / "art_source"
SCALE = 32.0
ELEVATION = math.radians(30)
ARGS = argparse.ArgumentParser()
ARGS.add_argument("--samples", type=int, default=256)
ARGS.add_argument("--only", choices=["altar", "stela", "grain_rack", "lantern"])
OPTS = ARGS.parse_args(sys.argv[sys.argv.index("--")+1:] if "--" in sys.argv else [])
random.seed(4312)

PROPS = {
    "altar": {"image_size": [280, 280], "anchor_px": [140, 238],
              "colliders": [{"rect": [-52, -22, 104, 36]}]},
    "stela": {"image_size": [152, 200], "anchor_px": [76, 172],
              "colliders": [{"rect": [-19, -13, 38, 24]}]},
    "grain_rack": {"image_size": [288, 272], "anchor_px": [144, 234],
                   "colliders": [{"rect": [-46, -20, 92, 32]}]},
    "lantern": {"image_size": [160, 244], "anchor_px": [52, 218],
                "colliders": [{"circle": [0, 0, 7]}]},
}


def linear(channel):
    return channel / 12.92 if channel <= .04045 else ((channel + .055) / 1.055) ** 2.4


def color(hex_string):
    return tuple(linear(int(hex_string[i:i+2], 16)/255) for i in (0, 2, 4)) + (1,)


def material(name, hex_string, roughness=1, emission=0):
    mat = bpy.data.materials.new(name)
    mat.diffuse_color = color(hex_string)
    mat.use_nodes = True
    shader = mat.node_tree.nodes.get("Principled BSDF")
    shader.inputs["Base Color"].default_value = color(hex_string)
    shader.inputs["Roughness"].default_value = roughness
    shader.inputs["Specular IOR Level"].default_value = .15
    if emission:
        shader.inputs["Emission Color"].default_value = color(hex_string)
        shader.inputs["Emission Strength"].default_value = emission
    return mat


def assign(obj, mat):
    obj.data.materials.append(mat)
    return obj


def bevel(obj, width=.035, segments=1):
    modifier = obj.modifiers.new("Soft hand-cut edge", "BEVEL")
    modifier.width = width
    modifier.segments = segments
    modifier.affect = "EDGES"
    modifier.profile = .5
    modifier = obj.modifiers.new("Weighted face normals", "WEIGHTED_NORMAL")
    modifier.keep_sharp = True
    modifier.weight = 30
    return obj


def box(name, loc, size, mat, edge=.025):
    bpy.ops.mesh.primitive_cube_add(size=1, location=loc)
    obj = bpy.context.object
    obj.name = name
    obj.dimensions = size
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    assign(obj, mat)
    if edge:
        bevel(obj, edge)
    return obj


def mesh(name, vertices, faces, mat, edge=0):
    data = bpy.data.meshes.new(name + " mesh")
    data.from_pydata(vertices, [], faces)
    data.update()
    obj = bpy.data.objects.new(name, data)
    bpy.context.collection.objects.link(obj)
    assign(obj, mat)
    if edge:
        bevel(obj, edge)
    return obj


def beam(name, a, b, radius, mat, vertices=8):
    a, b = Vector(a), Vector(b)
    bpy.ops.mesh.primitive_cylinder_add(vertices=vertices, radius=radius, depth=(b-a).length,
                                      end_fill_type="NGON", location=(a+b)/2)
    obj = bpy.context.object
    obj.name = name
    obj.rotation_euler = (b-a).to_track_quat("Z", "Y").to_euler()
    assign(obj, mat)
    bevel(obj, min(.01, radius*.25))
    return obj


def line(name, points, radius, mat, cyclic=False):
    curve = bpy.data.curves.new(name, "CURVE")
    curve.dimensions = "3D"
    curve.resolution_u = 1
    curve.bevel_depth = radius
    curve.bevel_resolution = 0
    spline = curve.splines.new("POLY")
    spline.points.add(len(points)-1)
    for dest, p in zip(spline.points, points):
        dest.co = (*p, 1)
    spline.use_cyclic_u = cyclic
    obj = bpy.data.objects.new(name, curve)
    bpy.context.collection.objects.link(obj)
    assign(obj, mat)
    return obj


def front_profile(name, polygon_xz, y, depth, mat, edge=.025):
    n = len(polygon_xz)
    verts = [(x, y-depth/2, z) for x,z in polygon_xz]
    verts += [(x, y+depth/2, z) for x,z in polygon_xz]
    faces = [tuple(range(n-1,-1,-1)), tuple(range(n,2*n))]
    faces += [(i,(i+1)%n,(i+1)%n+n,i+n) for i in range(n)]
    return mesh(name, verts, faces, mat, edge)


def ring(name, center, radius, mat, tube=.017, axis="Z", squash=1):
    pts=[]
    for i in range(16):
        angle=2*math.pi*i/16
        if axis == "Z":
            pts.append((center[0]+math.cos(angle)*radius, center[1]+math.sin(angle)*radius*squash,center[2]))
        else:
            pts.append((center[0]+math.cos(angle)*radius,center[1],center[2]+math.sin(angle)*radius*squash))
    return line(name,pts,tube,mat,True)


def shadow(rx, ry, offset=.17):
    # Rendered geometry, not a post-processing paint pass. Nested translucent
    # ellipses give a compact contact shadow consistent with scenery.png.
    mat = bpy.data.materials.get("Transparent jade contact shadow")
    if not mat:
        mat=bpy.data.materials.new("Transparent jade contact shadow")
        mat.use_nodes=True
        nt=mat.node_tree
        nt.nodes.clear()
        out=nt.nodes.new("ShaderNodeOutputMaterial")
        mix=nt.nodes.new("ShaderNodeMixShader")
        trans=nt.nodes.new("ShaderNodeBsdfTransparent")
        shade=nt.nodes.new("ShaderNodeEmission")
        shade.inputs["Color"].default_value=color("294b3d")
        mix.inputs[0].default_value=.038
        nt.links.new(trans.outputs[0],mix.inputs[1])
        nt.links.new(shade.outputs[0],mix.inputs[2])
        nt.links.new(mix.outputs[0],out.inputs[0])
    for j in range(7):
        factor=1-j*.075
        pts=[(offset+rx*factor*math.cos(t*math.tau/64),
              -.02+ry*factor*math.sin(t*math.tau/64), -.035+j*.003) for t in range(64)]
        mesh("Soft contact shadow %02d" % j,pts,[tuple(range(64))],mat)


def chips(front_y, positions):
    for i,(x,z,s) in enumerate(positions):
        front_profile("Worn stone chip %02d" % i,[(x-s,z),(x+s,z+.009),(x+s*.4,z+s*.6),(x-s*.7,z+s*.45)],
                      front_y,.006,M["stone_light"],0)


def moss(x,y,z,scale=1):
    for i in range(3):
        xx=x+i*.085*scale
        box("Lichen patch",(xx,y,z+(i%2)*.018*scale),(.16*scale,.01,.055*scale),M["moss"],.015*scale)


def altar():
    shadow(1.95,.88)
    box("Broad chipped foundation",(0,0,.13),(3.55,1.48,.26),M["stone_dark"],.065)
    box("Second step",(0,.03,.37),(3.05,1.21,.23),M["stone_light"],.035)
    box("Jade sandstone plinth",(0,.10,.83),(2.45,1.0,.69),M["stone"],.047)
    box("Upper carved cornice",(0,.10,1.24),(2.92,1.25,.17),M["stone_light"],.029)
    box("Cornice underside shadow course",(0,.10,1.12),(2.58,1.08,.075),M["jade_dark"],.015)
    for i,x in enumerate([-.86,0,.86]):
        # Recess-like front panels with a pale upper edge.
        box("Inset panel surround %d" % i,(x,-.411,.84),(.59,.055,.41),M["stone_light"],.025)
        box("Inset jade field %d" % i,(x,-.448,.83),(.47,.026,.30),M["jade"],.018)
        box("Inset inner relief %d" % i,(x,-.465,.83),(.28,.017,.15),M["stone"],.016)
    tablet=[(-.72,1.34),(-.72,2.55),(-.49,2.97),(.48,2.97),(.72,2.55),(.72,1.34)]
    front_profile("Ancestral stone tablet",tablet,.24,.28,M["jade_dark"],.035)
    inner=[(-.56,1.46),(-.56,2.52),(-.37,2.81),(.35,2.81),(.56,2.52),(.56,1.46)]
    front_profile("Raised inner tablet",inner,.070,.05,M["jade"],.024)
    # Simple geometric ornament, deliberately no generated or invented text.
    line("Lozenge relief",[(0,.027,2.52),(-.29,.027,2.15),(0,.027,1.78),(.29,.027,2.15)],.029,M["stone_light"],True)
    box("Tablet carved center",(0,.012,2.15),(.12,.048,.17),M["ochre"],.025)
    for x in [-1.08,1.08]:
        beam("Offering vessel foot",(x,-.11,1.32),(x,-.11,1.4),.17,M["bronze"])
        bpy.ops.mesh.primitive_cone_add(vertices=12,radius1=.15,radius2=.19,depth=.19,location=(x,-.11,1.49))
        assign(bpy.context.object,M["bronze"]); bpy.context.object.name="Bronze incense vessel"
        ring("Offering bowl rim",(x,-.11,1.585),.19,M["ochre"],.025)
        beam("Dark bowl interior",(x,-.11,1.591),(x,-.11,1.602),.155,M["wood_dark"],12)
        for k in [-1,1]:
            beam("Unlit incense stick",(x+k*.065,-.11,1.57),(x+k*.07,-.11,1.99+(k+1)*.06),.017,M["incense"])
    line("Tablet age fracture",[(-.71,.091,2.41),(-.45,.032,2.24),(-.35,.028,2.04)],.009,M["jade_dark"])
    chips(-.746,[(-1.34,.06,.12),(.99,.14,.095),(-.2,.05,.11)])
    chips(-.576,[(-.98,.33,.08),(.39,.31,.11)])
    moss(-1.55,-.75,.06,1.2)
    moss(1.23,-.75,.055,.7)
    moss(-.70,.09,1.53,.8)


def stela():
    shadow(.94,.58)
    box("Memorial foot",(0,0,.13),(1.42,.85,.26),M["stone_dark"],.05)
    box("Memorial upper foot",(0,.015,.28),(1.23,.70,.13),M["stone_light"],.028)
    body=[(-.50,.31),(-.53,1.81),(-.27,2.17),(.26,2.13),(.49,1.84),(.52,.31)]
    front_profile("Weathered upright stela",body,.03,.39,M["stone"],.045)
    # Highlight the side chamfer with a narrow light piece, as in the atlas.
    front_profile("Stela beveled left edge",[(-.50,.36),(-.52,1.79),(-.27,2.12),(-.35,1.77),(-.33,.36)],-.189,.025,M["stone_light"],.012)
    inset=[(-.31,.54),(-.32,1.69),(-.20,1.84),(.24,1.83),(.32,1.68),(.32,.54)]
    front_profile("Memorial sunken tablet",inset,-.179,.046,M["jade_dark"],.016)
    inner=[(-.255,.60),(-.267,1.67),(-.17,1.765),(.205,1.756),(.263,1.66),(.263,.60)]
    front_profile("Memorial panel",inner,-.210,.028,M["jade"],.014)
    line("Ancestral lozenge carving",[(0,-.232,1.57),(-.13,-.232,1.35),(0,-.232,1.12),(.13,-.232,1.35)],.014,M["stone_light"],True)
    # Decorative horizontal bas-relief, not writing.
    for z,w in [(.92,.34),(.79,.23)]:
        box("Low geometric tablet relief",(0,-.242,z),(w,.02,.028),M["stone_light"],.005)
    line("Hairline split",[(.23,-.18,2.13),(.10,-.18,1.95),(.18,-.237,1.82),(.12,-.237,1.71)],.009,M["jade_dark"])
    chips(-.434,[(-.49,.055,.10),(.18,.07,.075)])
    moss(-.58,-.435,.08,.85)
    moss(-.44,-.209,.35,.75)


def sack(x,y,z,height,index):
    radii=[(.0,.22),(.08,.28),(.28,.30),(.61,.28),(.82,.23),(.94,.105),(1,.11)]
    verts=[]
    sides=12
    for h,r in radii:
        for i in range(sides):
            a=2*math.pi*i/sides
            verts.append((x+r*math.cos(a),y+r*.75*math.sin(a),z+h*height))
    faces=[tuple(range(sides-1,-1,-1))]
    for j in range(len(radii)-1):
        for i in range(sides):
            faces.append((j*sides+i,j*sides+(i+1)%sides,(j+1)*sides+(i+1)%sides,(j+1)*sides+i))
    faces.append(tuple(range((len(radii)-1)*sides,len(radii)*sides)))
    obj=mesh("Tied millet sack %02d" % index,verts,faces,M["sack_light" if index%2 else "sack"],.012)
    ring("Sack neck binding",(x,y,z+.925*height),.113,M["rope"],.018,squash=.75)
    ring("Sack middle binding",(x,y,z+.42*height),.293,M["rope"],.018,squash=.75)
    line("Sack front seam",[(x-.02,y-.155,z+.88*height),(x-.035,y-.216,z+.64*height),
                             (x-.02,y-.235,z+.31*height),(x+.01,y-.186,z+.05*height)],.010,M["straw_light"])
    for k in range(4):
        hh=.23+k*.15
        line("Sack stitch",[(x-.053,y-.234,z+hh*height),(x+.017,y-.234,z+(hh+.02)*height)],.008,M["rope"])
    beam("Tied sack cord",(x+.075,y-.10,z+.92*height),(x+.16,y-.20,z+.78*height),.016,M["rope"])


def grain_rack():
    shadow(2.03,.8)
    # Front and rear feet maintain a shallow, walkable footprint under the roof.
    for y in [-.40,.40]:
        for x in [-1.42,1.42]:
            box("Square hardwood rack post",(x,y,1.07),(.14,.15,2.14),M["wood"],.019)
            box("Worn post foot",(x,y,.085),(.18,.19,.17),M["wood_dark"],.02)
            box("Sunlit post edge",(x-.041,y-.078,1.1),(.022,.011,1.88),M["wood_light"],.003)
    for a,b in [((-1.42,.43,.35),(1.42,.43,1.94)),((1.42,.44,.35),(-1.42,.44,1.94))]:
        beam("Rear cross brace",a,b,.049,M["wood_light"],4)
    for i in range(10):
        x=-1.40+i*.31
        box("Storage floor plank %02d" % i,(x,0,.28),(.285,1.02,.13),M["wood_light" if i%3==0 else "wood"],.017)
    box("Front shelf beam",(0,-.52,.24),(3.09,.14,.21),M["wood"],.023)
    box("Front shelf highlight",(0,-.596,.32),(2.95,.023,.022),M["wood_light"],.005)
    for i,x in enumerate([-1.03,-.34,.36,1.03]):
        sack(x,-.07,.35,1.03+(i%2)*.08,i)
    box("Upper eave crossbeam",(0,0,2.05),(3.12,1.03,.17),M["wood_dark"],.023)
    for side in [-1,1]:
        beam("Gable knee brace",(side*1.43,-.43,1.58),(side*1.06,-.43,2.08),.055,M["wood_light"],4)
    # Hipped thatch roof. A horizontal ridge and slightly raised hip corners
    # evoke an early Chinese rural granary without ornate later-period details.
    verts=[(-1.87,-.85,2.23),(1.87,-.85,2.23),(1.87,.85,2.23),(-1.87,.85,2.23),
           (-.70,0,3.00),(.70,0,3.00)]
    faces=[(0,1,5,4),(1,2,5),(2,3,4,5),(3,0,4)]
    obj=mesh("Hipped bundled-straw roof",verts,faces,M["straw"])
    obj.data.materials.append(M["straw_light"])
    obj.data.materials.append(M["straw_dark"])
    obj.data.polygons[0].material_index=0
    obj.data.polygons[1].material_index=2
    obj.data.polygons[2].material_index=0
    obj.data.polygons[3].material_index=1
    solid=obj.modifiers.new("Thick thatch eaves","SOLIDIFY"); solid.thickness=.14
    bevel(obj,.015)
    for side in [-1,1]:
        y=side*.864
        line("Layered thatch eave",[(-1.88,y,2.23),(-.92,y,2.19),(0,y,2.18),(.92,y,2.19),(1.88,y,2.23)],.050,M["straw_dark"])
        line("Bright lower straw fringe",[(-1.87,y-.008,2.255),(-.88,y-.008,2.225),(0,y-.008,2.215),(.89,y-.008,2.225),(1.87,y-.008,2.255)],.015,M["straw_light"])
        for i in range(33):
            x=-1.79+i*3.58/32
            rx=max(-.70,min(.70,x*.47))
            line("Individual thatch bundle",[(x,y,2.258),(x*.75+rx*.25,side*.60,2.43),(x*.36+rx*.64,side*.28,2.73),(rx,0,3.025)],
                 .012+(i%3)*.003,M["straw_light" if i%4 else "straw_dark"])
        # Two horizontal lash courses clarify the handmade roof at play scale.
        for fraction in [.30,.66]:
            pts=[]
            for i in range(13):
                x=-1.82+i*3.64/12
                rx=max(-.70,min(.70,x*.47))
                pts.append((x*(1-fraction)+rx*fraction,side*.87*(1-fraction),2.25+.775*fraction))
            line("Thatch binding course",pts,.017,M["rope"])
    beam("Bound straw ridge",(-.78,0,3.015),(.78,0,3.015),.070,M["straw_light"],8)
    for x in [-.63,-.32,0,.32,.63]:
        ring("Ridge binding",(x,0,3.02),.075,M["rope"],.014,axis="Y")
    for side in [-1,1]:
        for y in [-.4,.4]:
            for z in [1.84,1.91]:
                ring("Post binding",(side*1.42,y,z),.091,M["rope"],.014)


def lantern():
    shadow(.67,.46,.10)
    box("Lantern stone foot",(0,0,.14),(.61,.52,.28),M["stone_dark"],.045)
    box("Lantern foot bevel cap",(0,0,.29),(.51,.44,.10),M["stone_light"],.027)
    box("Weathered lantern post",(0,0,1.62),(.16,.17,2.70),M["wood_dark"],.023)
    box("Lantern post lit edge",(-.049,-.089,1.60),(.037,.012,2.63),M["wood_light"],.005)
    box("Lantern projecting arm",(.41,0,2.82),(1.01,.15,.14),M["wood"],.024)
    beam("Lantern arm diagonal brace",(.065,0,2.47),(.43,0,2.80),.042,M["wood_light"],4)
    box("Post ornamental top",(0,0,3.02),(.22,.22,.12),M["ochre"],.025)
    beam("Suspension cord",(.78,0,2.80),(.78,0,2.58),.018,M["rope"])
    cx=.78
    # Faceted paper sides: brighter central panels, dark structural ribs.
    radii=[(1.60,.21),(1.67,.30),(2.19,.33),(2.40,.25)]
    n=8
    verts=[]
    for z,r in radii:
        for i in range(n):
            a=2*math.pi*i/n+math.pi/8
            verts.append((cx+r*math.cos(a),r*.77*math.sin(a),z))
    faces=[]
    for row in range(3):
        for i in range(n):
            faces.append((row*n+i,row*n+(i+1)%n,(row+1)*n+(i+1)%n,(row+1)*n+i))
    faces += [tuple(range(n-1,-1,-1)), tuple(range(3*n,4*n))]
    obj=mesh("Warm octagonal paper lantern",verts,faces,M["paper"])
    obj.data.materials.append(M["paper_light"])
    for face in obj.data.polygons:
        face.material_index=1 if face.index%8 in [5,6] else 0
    for i in range(n):
        a=2*math.pi*i/n+math.pi/8
        pts=[(cx+(r+.005)*math.cos(a),(r+.005)*.77*math.sin(a),z) for z,r in radii]
        line("Slender bamboo lantern rib",pts,.010,M["bronze"])
    for z,r in [(1.615,.23),(1.70,.305),(2.38,.263)]:
        ring("Bamboo lantern hoop",(cx,0,z),r,M["bronze"],.026,squash=.77)
    box("Small lantern top cap",(cx,0,2.465),(.58,.43,.13),M["jade_dark"],.024)
    box("Lantern lid top inset",(cx,0,2.54),(.40,.31,.04),M["jade"],.014)
    beam("Lantern suspension eye",(cx,0,2.54),(cx,0,2.61),.039,M["ochre"])
    beam("Tassel binding",(cx,0,1.61),(cx,0,1.47),.037,M["rope"])
    for i in range(5):
        beam("Muted ochre tassel strand",(cx+(i-2)*.01,-.005,1.49),(cx+(i-2)*.02,-.005,1.31+abs(i-2)*.015),.010,M["ochre"])
    for z in [2.74,2.80,2.86]:
        ring("Arm joint rope",(0,0,z),.119,M["rope"],.015)
    moss(-.19,-.264,.07,.55)


def setup_scene(name, spec):
    scene = bpy.data.scenes.new(name)
    bpy.context.window.scene = scene
    scene.render.engine = "CYCLES"
    scene.cycles.device = "CPU"
    scene.cycles.samples = OPTS.samples
    scene.cycles.use_denoising = False  # Debian headless build has no OpenImageDenoise.
    scene.cycles.use_adaptive_sampling = False
    scene.cycles.seed = 4312
    scene.cycles.use_animated_seed = False
    scene.cycles.max_bounces = 5
    scene.cycles.transparent_max_bounces = 16
    scene.render.film_transparent = True
    scene.render.image_settings.file_format = "PNG"
    scene.render.image_settings.color_mode = "RGBA"
    scene.render.image_settings.color_depth = "8"
    scene.render.resolution_x, scene.render.resolution_y = spec["image_size"]
    scene.render.resolution_percentage = 100
    scene.render.use_file_extension = True
    scene.view_settings.view_transform = "Standard"
    scene.view_settings.look = "None"
    scene.view_settings.exposure = 0
    scene.view_settings.gamma = 1
    scene.world = bpy.data.worlds.new(name + " soft ambient")
    scene.world.use_nodes = True
    scene.world.node_tree.nodes["Background"].inputs["Color"].default_value = (.73,.79,.70,1)
    scene.world.node_tree.nodes["Background"].inputs["Strength"].default_value = .72
    # Front-left softbox gives clear, broad highlights instead of plastic gloss.
    for lname,loc,power,size,tint in [
        ("Large warm northwest key",(-3.8,-5,8),650,5,(1,.94,.80)),
        ("Cool soft fill",(4,1,5),180,4,(.80,.93,1))]:
        data=bpy.data.lights.new(lname,"AREA")
        data.energy=power; data.shape="DISK"; data.size=size; data.color=tint
        obj=bpy.data.objects.new(lname,data); scene.collection.objects.link(obj)
        obj.location=loc; obj.rotation_euler=(-obj.location).to_track_quat("-Z","Y").to_euler()
    w,h=spec["image_size"]; ax,ay=spec["anchor_px"]
    up=Vector((0,math.sin(ELEVATION),math.cos(ELEVATION)))
    facing=Vector((0,-math.cos(ELEVATION),math.sin(ELEVATION)))
    center=Vector(((w/2-ax)/(SCALE*2),0,0))+up*((ay-h/2)/(SCALE*2))
    data=bpy.data.cameras.new(name+" orthographic camera")
    data.type="ORTHO"
    # Blender's orthographic scale refers to the larger image dimension.
    data.ortho_scale=max(w,h)/(SCALE*2)
    obj=bpy.data.objects.new(name+" orthographic camera",data)
    scene.collection.objects.link(obj)
    obj.location=center+facing*15
    obj.rotation_euler=(center-obj.location).to_track_quat("-Z","Y").to_euler()
    scene.camera=obj
    scene.view_layers[0].update()
    from bpy_extras.object_utils import world_to_camera_view
    projected=world_to_camera_view(scene,obj,Vector((0,0,0)))
    actual_anchor=(projected.x*w,(1-projected.y)*h)
    if max(abs(actual_anchor[0]-ax),abs(actual_anchor[1]-ay)) > .01:
        raise RuntimeError("Foot anchor projection mismatch: " + repr(actual_anchor))
    scene.render.filepath=str(OUTPUT/(name+".png"))
    scene["world_pixels_per_metre"]=SCALE
    scene["source_pixels_per_world_pixel"]=2
    scene["foot_anchor_source_px"]=spec["anchor_px"]
    return scene


def remove_render_metadata(path):
    """Remove only run-specific PNG metadata; never decode or alter pixels.

    Blender emits Date, RenderTime and Cycles timing text even without a visible
    stamp. Dropping ancillary metadata makes identical renders byte-for-byte
    stable. IHDR, compressed IDAT, color information and transparency stay intact.
    """
    raw = path.read_bytes()
    assert raw[:8] == b"\x89PNG\r\n\x1a\n"
    out = bytearray(raw[:8])
    cursor = 8
    while cursor < len(raw):
        length = struct.unpack(">I", raw[cursor:cursor+4])[0]
        kind = raw[cursor+4:cursor+8]
        end = cursor+length+12
        if kind not in {b"tEXt", b"zTXt", b"iTXt", b"eXIf"}:
            out.extend(raw[cursor:end])
        cursor = end
    path.write_bytes(out)


bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.context.preferences.filepaths.save_version = 0
M={key: material("Palette / "+key,hx,emission=emission) for key,hx,emission in [
    ("stone","91a18a",0),("stone_dark","748b77",0),("stone_light","bec0a2",0),
    ("jade","86a08a",0),("jade_dark","567566",0),("moss","647f50",0),
    ("wood","847653",0),("wood_dark","54614b",0),("wood_light","aca174",0),
    ("ochre","b8a16a",0),("bronze","827d55",0),("rope","8e835a",0),
    ("incense","c9b481",0),("sack","b7a375",0),("sack_light","c8b680",0),
    ("straw","b6a474",0),("straw_light","d0bf87",0),("straw_dark","958756",0),
    ("paper","d5bb7d",.18),("paper_light","e4cd92",.25),
]}

OUTPUT.mkdir(parents=True,exist_ok=True)
for name,spec in PROPS.items():
    scene=setup_scene(name,spec)
    globals()[name]()
    # Separate edit-friendly collections by semantic family, with camera/lights
    # remaining directly under the scene root. All geometry stays editable.
    geometry=bpy.data.collections.new(name+" / editable model")
    scene.collection.children.link(geometry)
    shadows=bpy.data.collections.new(name+" / contact shadow")
    scene.collection.children.link(shadows)
    for obj in list(scene.collection.objects):
        if obj.type not in {"MESH","CURVE"}:
            continue
        dest=shadows if obj.name.startswith("Soft contact shadow") else geometry
        dest.objects.link(obj); scene.collection.objects.unlink(obj)
    if OPTS.only is None or OPTS.only==name:
        bpy.ops.render.render(write_still=True)
        remove_render_metadata(OUTPUT/(name+".png"))
    spec.update({
        "image": "res://assets/props/"+name+".png",
        "logical_size": [v/2 for v in spec["image_size"]],
        "scale": .5,
        "logical_anchor": [v/2 for v in spec["anchor_px"]],
        "draw_offset": [-v/2 for v in spec["anchor_px"]],
        "model_scene": name,
        "anchor_note": "The source-pixel anchor projects Blender ground origin (0,0,0). Draw at landmark.position with draw_offset, logical_size; keep node Y-sort at landmark.position.",
        "collider_note": "Existing world-pixel colliders copied for correspondence only. Use data/map_details.json as the gameplay authority; do not collide against the full upright sprite or contact shadow."
    })
    (OUTPUT/(name+".json")).write_text(json.dumps(spec,ensure_ascii=False,indent=2)+"\n")

for scene in list(bpy.data.scenes):
    if scene.name not in PROPS:
        bpy.data.scenes.remove(scene)
bpy.context.window.scene=bpy.data.scenes["altar"]
for obj in bpy.context.selected_objects:
    obj.select_set(False)
for screen in bpy.data.screens:
    for area in screen.areas:
        if area.type == "VIEW_3D":
            area.spaces.active.shading.type = "SOLID"
            area.spaces.active.shading.color_type = "MATERIAL"
            area.spaces.active.shading.show_cavity = True
            area.spaces.active.region_3d.view_perspective = "CAMERA"
bpy.ops.wm.save_as_mainfile(filepath=str(SOURCE/"map_landmarks.blend"),compress=True)
(OUTPUT/"landmarks.json").write_text(json.dumps({
    "version":1,"renderer":"Blender 4.3.2 / Cycles CPU","samples":OPTS.samples,
    "source":"res://art_source/map_landmarks.blend",
    "camera":"Orthographic, front-facing, 30 degree elevation, no yaw",
    "source_pixels_per_world_pixel":2,"props":PROPS
},ensure_ascii=False,indent=2)+"\n")
print("LANDMARKS_COMPLETE",json.dumps({k:v["image"] for k,v in PROPS.items()}))
