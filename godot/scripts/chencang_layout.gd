extends Node2D
## Authored night-city ground and independent cached architecture. Original
## paintings are read only by the offline bake; no global tint touches actors.
const Painted=preload("res://scripts/painted_ground.gd")
const SourceProps=preload("res://scripts/painted_props.gd")
const Hanshui=preload("res://scripts/hanshui_layout.gd")
const SOURCE_MANIFEST="res://art_source/painted/chencang-props-source.json"
static var baking=false
static var sources_loaded=false
static var source_ready=false
static var prop_atlas: Texture2D
static var prop_frames: Dictionary={}
static var source_frames: Dictionary={}
var world
var definition: Dictionary={}
var stage=""
var layer="ground"
var item: Dictionary={}
var rendered_prop: Sprite2D
var body_bounds=Rect2()
var beacon_on=false
var fire_clock=0.0
var redraw_left=0.0

class BeaconControl extends Node2D:
	## Ground-level feedback remains in the hero's normal follow-camera view.
	var world
	var extinguished=false
	var settling=0.0
	var redraw_left=0.0
	func _ready() -> void:
		extinguished=bool(world.state.flags.get("cc_beacon_out",false))
	func _process(dt: float) -> void:
		if not is_instance_valid(world): return
		var next=bool(world.state.flags.get("cc_beacon_out",false))
		if next!=extinguished:
			extinguished=next; settling=1.2 if next else 0.0; queue_redraw()
			if next and world.mode=="playing" and is_instance_valid(world.get("fx")):
				world.fx.floater(global_position+Vector2(0,-35),"烽索已落",Color("c0d0cd"))
		if world.mode!="playing" or settling<=0: return
		settling=maxf(0,settling-dt); redraw_left-=dt
		if redraw_left<=0: redraw_left=.05; queue_redraw()
	func _draw() -> void:
		# A small rope cleat and lever, not a new blocker or interactable.
		draw_line(Vector2(-8,3),Vector2(8,3),Color("424e4b"),6,true)
		draw_line(Vector2(0,0),Vector2(0,-23),Color("7b715b"),5,true)
		var tip=Vector2(-13,-5) if extinguished else Vector2(13,-34)
		draw_line(Vector2(0,-19),tip,Color("c0a878"),3,true)
		draw_line(tip,tip+Vector2(3,16 if extinguished else 23),Color("8d8b76"),1.5,true)
		if settling<=0: return
		var fade=settling/1.2; var rise=(1-fade)*24
		for i in range(3):
			var p=Vector2((i-1)*8,-26-rise-i*4)
			draw_polyline(PackedVector2Array([p+Vector2(-5,5),p,p+Vector2(5,-5)]),Color("a4b4b4",fade*.55),2.5,true)
		for i in range(4):
			var p=Vector2((i-1.5)*9,-14-rise*.4-i%2*8)
			draw_circle(p,1.4,Color("e2b779",fade*.75))

static func apply_layout(source: Dictionary,stage_id: String="") -> Dictionary:
	var result=Hanshui.apply_layout(source,stage_id)
	# CC step rectangles belong to this renderer; MapDetails' historical
	# authored stair dictionaries use a different shape.
	result.map_details.steps=[]
	return result

static func frame_key(value: Dictionary) -> String:
	return str(value.kind)

static func load_sources() -> bool:
	if sources_loaded: return source_ready
	sources_loaded=true
	if not FileAccess.file_exists(SOURCE_MANIFEST):
		push_error("Chencang original component manifest is missing."); return false
	var manifest=JSON.parse_string(FileAccess.get_file_as_string(SOURCE_MANIFEST))
	if not manifest is Dictionary or not manifest.get("frames") is Dictionary: return false
	var image=Image.new()
	if image.load(ProjectSettings.globalize_path(str(manifest.get("image",""))))!=OK:
		push_error("Chencang original image is missing."); return false
	var dimensions=manifest.get("source_size",[0,0])
	if image.get_size()!=Vector2i(dimensions[0],dimensions[1]):
		push_error("Chencang original dimensions changed; re-inspect component boxes and feet."); return false
	image.convert(Image.FORMAT_RGBA8)
	# Ignore faint source-sheet glow in the bake-only copy. Keep component
	# edges at alpha >= 16; the preserved original file remains unmodified.
	for y in range(image.get_height()):
		for x in range(image.get_width()):
			if image.get_pixel(x,y).a<16.0/255.0: image.set_pixel(x,y,Color.TRANSPARENT)
	# Reuse the reviewed alpha-component isolation routine, with namespaced
	# frames. This never alters the original image or the old cached atlases.
	if not SourceProps._load_sources(): return false
	SourceProps.sheets["chencang"]=image
	for id in manifest.frames:
		var frame: Dictionary=manifest.frames[id].duplicate(true)
		frame.sheet="chencang"; SourceProps.frames["cc_"+id]=frame
		source_frames[id]=frame
	source_ready=source_frames.size()==6
	return source_ready

static func attach_landmarks(parent: Node2D,data: Dictionary,region: String) -> Array:
	var created: Array=[]; var script=load("res://scripts/chencang_layout.gd")
	for entry in data.get("layout",{}).get("cc_props",[]):
		var node=script.new(); node.world=parent.get_parent(); node.definition=data
		node.stage=region; node.layer="landmark"; node.item=entry
		node.position=Vector2(entry.position[0],entry.position[1])
		node.name="Chencang_"+str(entry.kind); parent.add_child(node); created.append(node)
	if region=="cc_beacon":
		for object in data.get("objects",[]):
			if object.id!="cc_beacon": continue
			var control=BeaconControl.new(); control.name="Chencang_BeaconControl"; control.world=parent.get_parent()
			control.position=Vector2(object.x+34,object.y+4); parent.add_child(control)
	return created

func _ready() -> void:
	set_process(false)
	if baking or layer!="landmark": return
	if prop_frames.is_empty() and ResourceLoader.exists("res://assets/maps/chencang_props.png") and FileAccess.file_exists("res://assets/maps/chencang_props.json"):
		prop_atlas=load("res://assets/maps/chencang_props.png")
		prop_frames=JSON.parse_string(FileAccess.get_file_as_string("res://assets/maps/chencang_props.json"))
	var key=frame_key(item)
	if not prop_frames.has(key): return
	var frame: Dictionary=prop_frames[key]
	var factor=float(item.width)/float(frame.baked_width)
	var texture=AtlasTexture.new(); texture.atlas=prop_atlas
	texture.region=Rect2(frame.region[0],frame.region[1],frame.region[2],frame.region[3]); texture.filter_clip=true
	rendered_prop=Sprite2D.new(); rendered_prop.centered=false; rendered_prop.texture=texture; rendered_prop.show_behind_parent=true
	rendered_prop.scale=Vector2.ONE*factor
	rendered_prop.position=-Vector2(frame.anchor[0],frame.anchor[1])*factor; add_child(rendered_prop)
	body_bounds=Rect2(rendered_prop.position,texture.get_size()*factor)
	beacon_on=item.get("beacon",false) and is_instance_valid(world) and not world.state.flags.get("cc_beacon_out",false)
	set_process(true)

func _process(dt: float) -> void:
	if not is_instance_valid(world): return
	# State changes can happen at the end of an interaction frame. Update the
	# flame immediately on the next render frame, even if dialog just opened.
	var burning=bool(item.get("beacon",false)) and not world.state.flags.get("cc_beacon_out",false)
	if beacon_on!=burning: beacon_on=burning; queue_redraw()
	if world.mode!="playing": return
	if rendered_prop!=null and is_instance_valid(world.get("hero")):
		var hero=world.hero; var target=1.0
		if hero.global_position.y<global_position.y-6:
			var body=Rect2(hero.global_position+Vector2(-24,-82),Vector2(48,65))
			var overlap=Rect2(global_position+body_bounds.position,body_bounds.size).intersection(body)
			if overlap.size.x>=6 and overlap.size.y>=12: target=.28
		rendered_prop.modulate.a=move_toward(rendered_prop.modulate.a,target,dt*4.5)
	if beacon_on:
		fire_clock+=dt; redraw_left-=dt
		if redraw_left<=0: redraw_left=1.0/20; queue_redraw()

func points(values: Array) -> PackedVector2Array:
	var out=PackedVector2Array()
	for p in values: out.append(Vector2(p[0],p[1]))
	return out

func _draw() -> void:
	if layer=="landmark":
		if baking: draw_original()
		elif beacon_on: draw_beacon()
		return
	var layout: Dictionary=definition.get("layout",{})
	# Quiet stone courtyards, brick shoulders and embedded drains belong to
	# the baked floor. They never add runtime polygons or collision changes.
	for solid in layout.get("solids",[]):
		if not solid.has("rect"): continue
		var r=solid.rect; var at=Vector2(r[0],r[1]); var end=at+Vector2(r[2],r[3])
		var shadow=PackedVector2Array([at+Vector2(-23,16),Vector2(end.x,at.y),end+Vector2(28,20),Vector2(at.x-24,end.y+26)])
		Painted.paint(self,shadow,Painted.PAVING,Color("344b54",.46),stage,14,.22)
	for steps in layout.get("steps",[]):
		var r=Rect2(steps[0],steps[1],steps[2],steps[3]); var count=maxi(3,int(r.size.y/15))
		for i in range(count):
			var y=r.position.y+float(i)/count*r.size.y
			draw_line(Vector2(r.position.x,y+2),Vector2(r.end.x,y+2),Color("283f48",.40),4,true)
			draw_line(Vector2(r.position.x+3,y),Vector2(r.end.x-4,y),Color("adb2a3",.35),2,true)
	for drain in layout.get("drains",[]):
		var path=points(drain)
		draw_polyline(path,Color("273f49",.45),5,true)
		draw_polyline(path,Color("9caba6",.16),1.2,true)
	for lamp in layout.get("lanterns",[]): glow(Vector2(lamp[0],lamp[1]))
	if stage=="cc_final":
		# Broad irregular paving, with a calm center for hammer telegraphs.
		var poly=points([[635,300],[825,195],[1170,195],[1370,305],[1400,530],[1290,735],[1080,800],[790,765],[625,610]])
		Painted.paint(self,poly,Painted.PAVING,Color("5d7075"),stage,35,.28)
		for x in [630,1410]:
			draw_line(Vector2(x,290),Vector2(x,720),Color("354b52",.22),5,true)
	elif stage=="cc_store":
		for i in range(22):
			var p=Vector2(520+i*19,820-i*12)
			draw_line(p,p+Vector2(14,-9),Color("b8a77d",.15),2,true)

func glow(at: Vector2) -> void:
	for i in range(10,0,-1):
		draw_set_transform(at,0,Vector2(1,.42))
		draw_circle(Vector2.ZERO,10+i*8,Color("d7a465",.014+float(10-i)*.002))
	draw_set_transform(Vector2.ZERO)
	for i in range(6):
		var p=at+Vector2(-40+i*14,18+sin(i)*3)
		draw_line(p,p+Vector2(9,-.5),Color("dbc391",.11),1.2,true)

func draw_original() -> void:
	if not load_sources() or not source_frames.has(str(item.kind)): return
	SourceProps.draw_named(self,"cc_"+str(item.kind),Vector2.ZERO,float(item.width),Color("dbe2e7"))

func draw_beacon() -> void:
	var frame: Dictionary=prop_frames.get(frame_key(item),{})
	var at_values=frame.get("fire_anchor",[0,-140])
	var factor=float(item.width)/float(frame.get("baked_width",item.width))
	var at=Vector2(at_values[0],at_values[1])*factor; var sway=sin(fire_clock*6)*3
	# A small local fire sits on the actual brazier anchor from the source
	# crop. It is decorative, never an extra hitbox or fullscreen light.
	for i in range(4,0,-1):
		draw_set_transform(at+Vector2(0,1),0,Vector2(1,.55))
		draw_circle(Vector2.ZERO,12+i*6,Color("f2a850",.025))
	draw_set_transform(Vector2.ZERO)
	draw_colored_polygon(PackedVector2Array([at+Vector2(-11,3),at+Vector2(-8,-11),at+Vector2(sway-5,-27),at+Vector2(sway+3,-16),at+Vector2(9,-8),at+Vector2(12,3)]),Color("df7739",.94))
	draw_colored_polygon(PackedVector2Array([at+Vector2(-5,1),at+Vector2(sway,-18),at+Vector2(5,-6),at+Vector2(6,1)]),Color("ffcf76",.92))
	for i in range(3):
		var phase=fposmod(fire_clock*.3+i*.33,1.0)
		var p=at+Vector2(sin(phase*4+i)*9,-24-phase*38)
		draw_circle(p,4+phase*7,Color("5a6c70",(1-phase)*.12))
