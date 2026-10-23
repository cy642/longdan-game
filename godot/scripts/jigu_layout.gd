extends Node2D
## Jigu's cliffs, chasms and timber crossings are baked once. Upright pieces
## share one compact atlas; the existing chapter atlases remain unchanged.
const Painted=preload("res://scripts/painted_ground.gd")
const PaintedProps=preload("res://scripts/painted_props.gd")
const Hanshui=preload("res://scripts/hanshui_layout.gd")
static var baking=false
static var prop_atlas: Texture2D
static var prop_frames: Dictionary={}
var definition: Dictionary={}
var stage=""
var layer="ground"
var item: Dictionary={}
var rendered_prop: Sprite2D
var world
var cut_variant=false

static func apply_layout(source: Dictionary, stage_id: String="") -> Dictionary:
	return Hanshui.apply_layout(source,stage_id)

static func frame_key(value: Dictionary) -> String:
	if value.has("rect"): return str(value.kind)+"_"+str(int(value.rect[2]))+"_"+str(int(value.rect[3]))+("_cut" if value.get("cut",false) else "")
	return str(value.kind)

static func attach_landmarks(parent: Node2D,data: Dictionary,region: String) -> Array:
	var result: Array=[]
	var script=load("res://scripts/jigu_layout.gd")
	for entry in data.get("layout",{}).get("jigu_props",[]):
		var node=script.new(); node.definition=data; node.stage=region; node.layer="landmark"; node.item=entry
		node.world=parent.get_parent()
		if entry.has("rect"):
			var r=entry.rect; node.position=Vector2(r[0]+r[2]*.5,r[1]+r[3])
		else: node.position=Vector2(entry.position[0],entry.position[1])
		node.name="Jigu_"+str(entry.kind); parent.add_child(node); result.append(node)
	return result

func _ready() -> void:
	set_process(false)
	if baking or layer!="landmark": return
	if prop_frames.is_empty() and ResourceLoader.exists("res://assets/maps/jigu_props.png") and FileAccess.file_exists("res://assets/maps/jigu_props.json"):
		prop_atlas=load("res://assets/maps/jigu_props.png")
		prop_frames=JSON.parse_string(FileAccess.get_file_as_string("res://assets/maps/jigu_props.json"))
	if stage=="jg_bridge" and item.kind=="rope_posts":
		cut_variant=is_instance_valid(world) and world.state.flags.get("jg_bridge_cut",false)
		set_process(true)
	attach_frame()

func attach_frame() -> void:
	var variant=item.duplicate()
	if cut_variant: variant.cut=true
	var key=frame_key(variant)
	if not prop_frames.has(key): return
	var frame: Dictionary=prop_frames[key]
	var texture=AtlasTexture.new(); texture.atlas=prop_atlas
	texture.region=Rect2(frame.region[0],frame.region[1],frame.region[2],frame.region[3]); texture.filter_clip=true
	if rendered_prop==null:
		rendered_prop=Sprite2D.new(); rendered_prop.centered=false; add_child(rendered_prop)
	rendered_prop.texture=texture
	rendered_prop.position=-Vector2(frame.anchor[0],frame.anchor[1])

func _process(_delta: float) -> void:
	if not is_instance_valid(world): return
	var requested=bool(world.state.flags.get("jg_bridge_cut",false))
	if requested==cut_variant: return
	cut_variant=requested; attach_frame(); queue_redraw()

func points(values: Array) -> PackedVector2Array:
	var result=PackedVector2Array()
	for p in values: result.append(Vector2(p[0],p[1]))
	return result

func polygon(values: Array,tone: Color) -> void:
	draw_colored_polygon(points(values),tone)

func _draw() -> void:
	if layer=="landmark":
		if rendered_prop==null: draw_prop()
		return
	var layout: Dictionary=definition.get("layout",{})
	for surface in layout.get("surfaces",[]):
		var tone=Color(surface.get("tone","a19e91")); var poly=points(surface.polygon)
		if not Painted.paint(self,poly,Painted.PAVING if surface.kind=="flagstone" else Painted.SLATE,tone,stage,18,.37): draw_colored_polygon(poly,tone)
	for bounds in layout.get("cliffs",[]): cliff(bounds)
	for bounds in layout.get("chasms",[]): chasm(bounds)
	for bounds in layout.get("bridges",[]): deck(bounds)
	# Authored quiet accents stay at the edges of the walking path.
	if stage=="jg_signal":
		for i in range(6):
			var y=485-i*10; draw_line(Vector2(1005+i*2,y),Vector2(1110+i*2,y),Color("6b7068",.28),3,true)
	elif stage=="jg_rearguard":
		for i in range(8):
			var y=445+i*22
			draw_line(Vector2(764,y),Vector2(798,y-2),Color("d2c9ad",.33),7,true)
	elif stage=="jg_final":
		for i in range(24):
			var a=i*TAU/24; var p=Vector2(1000,460)+Vector2(cos(a)*355,sin(a)*255)
			draw_line(p,p+Vector2(12+sin(i)*8,-3),Color("645e54",.22),1.6,true)

func cliff(values: Array) -> void:
	var r=Rect2(values[0],values[1],values[2],values[3])
	# The exact rect is solid. Shadows sit inside it, so a dash cannot land on
	# an apparently clear strip behind the cliff silhouette.
	var base=Color("6d756f")
	var poly=PackedVector2Array([r.position,Vector2(r.end.x,r.position.y),r.end,Vector2(r.position.x,r.end.y)])
	if not Painted.paint(self,poly,Painted.SLATE,base,stage,0,.66): draw_rect(r,base)
	for band in range(5):
		var y=r.position.y+r.size.y*(.18+band*.16)
		var seam=PackedVector2Array()
		for i in range(13):
			var x=r.position.x+i*r.size.x/12.0
			seam.append(Vector2(x,y+sin(i*1.1+band)*9+sin(i*.41)*14))
		draw_polyline(seam,Color("3e4d4d",.21),3.5,true)
		draw_polyline(seam+PackedVector2Array(),Color("bac0b1",.10),1,true)
	for i in range(int(r.size.x/45)):
		var x=r.position.x+18+i*45
		draw_polyline(PackedVector2Array([Vector2(x,r.end.y-4),Vector2(x-7,r.end.y-25),Vector2(x+4,r.end.y-48)]),Color("364449",.28),2.2,true)
	draw_line(Vector2(r.position.x,r.end.y-3),r.end-Vector2(0,3),Color("c0bdab",.32),3,true)

func chasm(values: Array) -> void:
	var r=Rect2(values[0],values[1],values[2],values[3])
	var center=r.get_center()
	# A top-down ravine has a shaded floor and eroded rock lips. Avoid distant
	# triangular mountains inside a rectangular slot: that looked like a flat
	# landscape panel set into the map instead of depth beneath the crossing.
	draw_rect(r,Color("283e46"))
	for i in range(28):
		var t=float(i)/28; var tone=Color("31494f").lerp(Color("526b71"),t*.65)
		draw_rect(Rect2(r.position+Vector2(0,t*r.size.y),Vector2(r.size.x,r.size.y/28+1)),tone)
	var floor_poly=PackedVector2Array([r.position,Vector2(r.end.x,r.position.y),r.end,Vector2(r.position.x,r.end.y)])
	Painted.paint(self,floor_poly,Painted.SLATE,Color("3c565c"),stage,0,.18)
	# The physical rim remains unchanged. A thin irregular lip (at most 13 px
	# outside it, narrower than the actor radius) hides the ruler-straight seam.
	for side in [-1,1]:
		var x=center.x+side*r.size.x*.5
		var outer=PackedVector2Array(); var inner=PackedVector2Array(); var dark=PackedVector2Array()
		var count=maxi(14,int(r.size.y/22))
		for i in range(count+1):
			var y=r.position.y+i*r.size.y/count
			var wear=5+sin(y*.033+side)*4+cos(y*.071)*3
			var depth=28+sin(y*.017+side)*13+cos(y*.041)*7
			outer.append(Vector2(x+side*wear,y)); inner.append(Vector2(x-side*depth,y))
			dark.append(Vector2(x-side*(depth+14),y))
		var face=outer.duplicate(); var reversed=dark.duplicate(); reversed.reverse(); face.append_array(reversed)
		Painted.paint(self,face,Painted.SLATE,Color("596964"),stage,3,.48)
		draw_polyline(inner,Color("233f47",.45),5,true)
		draw_polyline(outer,Color("a5aa98",.36),2,true)
	# Broad, faint layers are baked and cost no runtime transparency passes.
	for i in range(5):
		var y=r.position.y+r.size.y*(.42+i*.075)
		draw_line(Vector2(r.position.x+35,y),Vector2(r.end.x-35,y+sin(i)*4),Color("a3b3b2",.025),18,true)

func deck(values: Array) -> void:
	var r=Rect2(values[0],values[1],values[2],values[3])
	draw_rect(r.grow(4),Color("3b403b"))
	var count=int(ceil(r.size.x/23.0))
	for i in range(count):
		var x=r.position.x+i*r.size.x/count+sin(i*2.7)*2
		var width=r.size.x/count-1.5+sin((i+1)*2.7)*2-sin(i*2.7)*2
		var y=r.position.y+3+sin(i*2.3)*3.5
		var base=Color("827864").lightened((sin(i*1.71)+1)*.07)
		var bottom=r.end.y-4-sin(i*2.9)*4
		var poly=PackedVector2Array([Vector2(x+1,y),Vector2(x+width,y+2.5),Vector2(x+width-1,bottom),Vector2(x,bottom-2)])
		if not Painted.paint(self,poly,Painted.DRY,base,stage,0,.22): draw_colored_polygon(poly,base)
		draw_line(Vector2(x+2,y+4),Vector2(x+2,r.end.y-5),Color("c2b08c",.25),1.2,true)
		for line in range(3):
			var gx=x+5+line*5.0
			var gy=y+12+fposmod(i*29+line*17,r.size.y*.45)
			draw_polyline(PackedVector2Array([Vector2(gx,gy),Vector2(gx-1,gy+35),Vector2(gx+1,gy+71)]),Color("514d43",.28),.85,true)
		if i%5==0: draw_arc(Vector2(x+width*.5,y+r.size.y*.63),3,0,TAU,12,Color("574d40",.5),1.2,true)
	# Lower rail is subtle and does not pretend to be a tall impassable wall.
	for y in [r.position.y+7,r.end.y-7]:
		draw_line(Vector2(r.position.x-14,y),Vector2(r.end.x+14,y),Color("484b40"),7,true)
		draw_line(Vector2(r.position.x-14,y-2),Vector2(r.end.x+14,y-2),Color("b3a17d",.65),1.8,true)

func draw_prop() -> void:
	match item.kind:
		"tent","supply_awning":
			if PaintedProps.draw_named(self,"tent_blue",Vector2.ZERO,126,Color("d5d3c3")): return
			polygon([[-63,0],[-45,-58],[0,-94],[64,0]],Color("888f84"))
		"rope_posts": rope_posts()
		"gate_pillars":
			# These two low carved stones are a traversable threshold, while the
			# large illustrated rockwalls beside them carry the real collision.
			for side in [-1,1]:
				PaintedProps.draw_named(self,"small_rock",Vector2(side*90,0),39,Color("a8aaa0"))
		"signal_platform":
			PaintedProps.draw_named(self,"altar",Vector2(0,14),92,Color("aaa99a"))
		"fallen_banner":
			draw_line(Vector2(-39,1),Vector2(32,-25),Color("554c3f"),4,true)
			polygon([[-22,-10],[-6,-20],[16,-9],[3,-3],[15,4],[-11,6]],Color("78695a"))
			for i in range(3): draw_line(Vector2(-13+i*7,-11),Vector2(-8+i*6,3),Color("b39a70",.34),1.3,true)
		"war_banner": banner()

func rope_posts() -> void:
	var r=item.rect; var width=float(r[2]); var depth=float(r[3])
	for y in [-depth+6.0,-6.0]:
		var segments: Array=[]
		if item.get("cut",false):
			var left=PackedVector2Array(); var right=PackedVector2Array()
			for i in range(19):
				var t=float(i)/24; left.append(Vector2(-width*.5+t*width,y-38+sin(t*PI)*13+pow(t/.75,8)*39))
			for i in range(21,25):
				var t=float(i)/24; right.append(Vector2(-width*.5+t*width,y-38+sin(t*PI)*13+pow((1-t)/.125,3)*40))
			segments=[left,right]
		else:
			var sag=PackedVector2Array()
			for i in range(25):
				var t=float(i)/24; sag.append(Vector2(-width*.5+t*width,y-38+sin(t*PI)*13))
			segments=[sag]
		for segment in segments:
			draw_polyline(segment,Color("494a40"),3.5,true)
			draw_polyline(segment,Color("b3a68c",.64),1.3,true)
		for side in [-1,1]:
			var x=side*(width*.5-6)
			draw_line(Vector2(x+2,y+2),Vector2(x+2,y-49),Color("494b42"),9,true)
			draw_line(Vector2(x-1,y),Vector2(x-1,y-48),Color("9a8f72"),3,true)
			for band in range(3): draw_line(Vector2(x-5,y-31+band*4),Vector2(x+6,y-33+band*4),Color("c2b18f"),1.5,true)

func banner() -> void:
	draw_line(Vector2(5,4),Vector2(0,-146),Color("3d403b"),7,true)
	draw_line(Vector2(2,1),Vector2(-2,-145),Color("938a70"),2,true)
	polygon([[-3,-142],[65,-131],[58,-107],[68,-76],[32,-87],[0,-80]],Color("713e3d"))
	polygon([[0,-135],[16,-132],[14,-86],[0,-82]],Color("a17155"))
	polygon([[18,-131],[50,-125],[45,-105],[57,-84],[20,-91]],Color("85504a"))
	for x in [7,31,49]: draw_line(Vector2(x,-128+x*.12),Vector2(x-4,-91),Color("c19d6b",.18),1.5,true)
	draw_polyline(PackedVector2Array([Vector2(-3,-142),Vector2(65,-131),Vector2(58,-107),Vector2(68,-76)]),Color("b89c70",.64),1.6,true)
