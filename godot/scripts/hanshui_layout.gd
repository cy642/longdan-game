extends Node2D
## Chapter-two source art: immutable terrain and colliders share the JSON layout.
## Ground is baked to one texture; upright props retain their ground Y-sort anchor.
static var baking=false
static var prop_atlas: Texture2D
static var prop_frames: Dictionary={}
var definition: Dictionary = {}
var stage = ""
var layer = "ground"
var item: Dictionary = {}
var rendered_prop: Sprite2D

static func frame_key(value: Dictionary) -> String:
	if value.has("rect"): return str(value.kind)+"_"+str(int(value.rect[2]))+"_"+str(int(value.rect[3]))
	return str(value.kind)+"_"+str(int(value.get("size",0)))

func _ready() -> void:
	if baking or layer!="landmark": return
	var manifest_path="res://assets/maps/hanshui_props.json"
	if prop_frames.is_empty() and ResourceLoader.exists("res://assets/maps/hanshui_props.png") and FileAccess.file_exists(manifest_path):
		prop_atlas=load("res://assets/maps/hanshui_props.png")
		prop_frames=JSON.parse_string(FileAccess.get_file_as_string(manifest_path))
	var key=frame_key(item)
	if not prop_frames.has(key): return
	var frame: Dictionary=prop_frames[key]
	var texture=AtlasTexture.new(); texture.atlas=prop_atlas
	texture.region=Rect2(frame.region[0],frame.region[1],frame.region[2],frame.region[3]); texture.filter_clip=true
	rendered_prop=Sprite2D.new(); rendered_prop.centered=false; rendered_prop.texture=texture
	rendered_prop.position=-Vector2(frame.anchor[0],frame.anchor[1]); add_child(rendered_prop)

static func apply_layout(source: Dictionary, _stage_id: String = "") -> Dictionary:
	var result = source.duplicate(true)
	if not result.has("layout"): return result
	var details: Dictionary = result.layout.duplicate(true)
	details["steps"] = details.get("steps", [])
	details["secondary_roads"] = []
	result["map_details"] = details
	result["secondary_roads"] = []
	return result

static func attach_landmarks(parent: Node2D, data: Dictionary, region: String) -> Array:
	var created: Array = []
	var script = load("res://scripts/hanshui_layout.gd")
	for entry in data.get("layout", {}).get("decor", []):
		var node = script.new()
		node.definition = data; node.stage = region; node.layer = "landmark"; node.item = entry
		if entry.has("rect"):
			var r = entry.rect
			node.position = Vector2(r[0]+r[2]*.5,r[1]+r[3])
		else: node.position = Vector2(entry.position[0],entry.position[1])
		node.name = "Hanshui_"+str(entry.kind)
		parent.add_child(node); created.append(node)
	return created

static func in_water(point: Vector2, data: Dictionary, margin = 0.0) -> bool:
	for bounds in data.get("layout", {}).get("water", []):
		if Rect2(bounds[0],bounds[1],bounds[2],bounds[3]).grow(margin).has_point(point): return true
	return false

func _points(values: Array) -> PackedVector2Array:
	var output = PackedVector2Array()
	for point in values: output.append(Vector2(point[0],point[1]))
	return output

func _poly(values: Array, color: Color) -> void:
	draw_colored_polygon(_points(values),color)

func _oval(at: Vector2, radius: float, squash: float, color: Color) -> void:
	draw_set_transform(at,0,Vector2(1,squash)); draw_circle(Vector2.ZERO,radius,color); draw_set_transform(Vector2.ZERO)

func _draw() -> void:
	if layer == "landmark":
		if rendered_prop==null: _draw_prop()
		return
	for bounds in definition.get("layout", {}).get("water", []): _water(bounds)
	match definition.get("layout", {}).get("motif", ""):
		"grain_tracks":
			for offset in [-14,14]:
				draw_polyline(_points([[940,735+offset],[1140,780+offset],[1330,810+offset]]),Color(.31,.29,.19,.22),3,true)
		"open_camp":
			# Painted guard marks are traversable. They make the flag's useful area visible.
			for at in [Vector2(560,320),Vector2(640,340),Vector2(700,400)]:
				draw_arc(at,23,0,TAU,20,Color(.78,.77,.53,.38),2,true)
			for y in [440,680]: draw_line(Vector2(935,y),Vector2(1065,y),Color(.71,.67,.47,.45),3,true)
		"iron_arena":
			var center = Vector2(1000,460)
			for radius in [180,195]:
				draw_set_transform(center,0,Vector2(1,.68))
				draw_arc(Vector2.ZERO,radius,0,TAU,60,Color(.27,.36,.32,.19),2,true)
			draw_set_transform(Vector2.ZERO)
			for i in range(7):
				var x=785+i*65
				draw_line(Vector2(x,605),Vector2(x+24,596),Color(.32,.35,.29,.17),3,true)

func _water(bounds: Array) -> void:
	var area = Rect2(bounds[0],bounds[1],bounds[2],bounds[3])
	draw_rect(area,Color("486f74"))
	for y in range(int(area.position.y),int(area.end.y),17):
		draw_line(Vector2(area.position.x,y),Vector2(area.end.x,y),Color(.43,.63,.62,.14),6,true)
	for i in range(34):
		var p = area.position+Vector2(fposmod(i*97.3,area.size.x),fposmod(i*41.7,area.size.y))
		draw_line(p,p+Vector2(minf(16+i%23,area.end.x-p.x),0),Color(.76,.83,.72,.25),1.4,true)
	# The first visible shore is precisely the collision edge, not a soft visual lie.
	if area.size.x > area.size.y:
		var shore_y = area.position.y if area.position.y>100 else area.end.y
		draw_line(Vector2(area.position.x,shore_y),Vector2(area.end.x,shore_y),Color("b9bca1"),6,true)
		for x in range(int(area.position.x)+15,int(area.end.x),43):
			_oval(Vector2(x,shore_y),12,.45,Color("728b7a"))
	else:
		draw_line(area.position,Vector2(area.position.x,area.end.y),Color("b9bca1"),6,true)
		for y in range(int(area.position.y)+17,int(area.end.y),43):
			_oval(Vector2(area.position.x,y),11,.50,Color("728b7a"))

func _draw_prop() -> void:
	if item.is_empty(): return
	match item.kind:
		"bamboo": _bamboo()
		"rockwall", "lowwall": _stone_wall()
		"palisade": _palisade()
		"grainstack": _grainstack()
		"boatframe": _boatframe()
		"timber": _timber()
		"drum_platform": _drum_platform()
		"hide_markers":
			for side in [-1,1]:
				draw_line(Vector2(side*105,0),Vector2(side*105,-48),Color("66775b"),4,true)
				_poly([[side*105,-45],[side*125,-38],[side*105,-29]],Color("8c9d7d"))
		"burnt_stakes":
			for i in range(5):
				var x=-33+i*17
				draw_line(Vector2(x,0),Vector2(x-4,-22-i%3*11),Color("5f5d4d"),6,true)

func _bamboo() -> void:
	var size = float(item.get("size",90))
	_oval(Vector2(7,4),size*.48,.30,Color(.09,.22,.19,.13))
	for stalk in range(5):
		var x=(stalk-2)*12.0; var height=size*(.80+stalk%3*.13)
		var bottom=Vector2(x,0); var top=Vector2(x+(stalk-2)*4,-height)
		draw_line(bottom,top,Color("41654f"),6,true)
		draw_line(bottom+Vector2(-1,0),top+Vector2(-1,0),Color("8eaa76"),2,true)
		for joint in range(1,5):
			var p=bottom.lerp(top,joint/5.0)
			draw_line(p+Vector2(-3,0),p+Vector2(3,0),Color("b0bb85"),1.5,true)
			var side=-1 if (joint+stalk)%2 else 1
			for leaf in range(3):
				var tip=p+Vector2(side*(17+leaf*10),-12+leaf*5)
				draw_line(p,tip,Color("496d50"),1.8,true)
				_poly([[tip.x,tip.y],[tip.x+side*16,tip.y-12],[tip.x+side*8,tip.y+1]],Color("648456"))

func _rect_size() -> Vector2:
	return Vector2(item.rect[2],item.rect[3])

func _stone_wall() -> void:
	var size = _rect_size(); var height=11.0 if item.kind=="lowwall" else 22.0
	var area=Rect2(-size.x*.5,-size.y,size.x,size.y)
	draw_rect(area.grow(4),Color(.16,.27,.23,.15))
	if item.kind=="rockwall":
		var left=-size.x*.5; var right=size.x*.5
		_poly([[left,0],[left,-size.y+10],[left+23,-size.y-height],[right-32,-size.y-height+3],[right,-size.y+8],[right,0]],Color("6b8175"))
		_poly([[left,-size.y+10],[left+23,-size.y-height],[right-32,-size.y-height+3],[right,-size.y+8],[right-21,-size.y*.38],[right-72,-size.y*.48],[left+size.x*.38,-size.y*.34],[left+18,-size.y*.45]],Color("a0ac96"))
		for band in range(3):
			var ridge=PackedVector2Array()
			for i in range(8):
				var x=left+8+i*(size.x-16)/7
				var y=-size.y*.32+band*12+sin(i*1.7+band)*5
				ridge.append(Vector2(x,y))
			draw_polyline(ridge,Color("7e9380") if band%2 else Color("536f61"),2,true)
		for i in range(5):
			var x=left+26+i*(size.x-50)/5
			draw_polyline(PackedVector2Array([Vector2(x,-size.y-height+9),Vector2(x+12,-size.y*.75),Vector2(x+2,-size.y*.54)]),Color("718878"),2,true)
		for i in range(12):
			var x=left+6+i*(size.x-12)/11
			_oval(Vector2(x,-2-i%3*2),7+i%4,.48,Color("617d59"))
		return
	draw_rect(area,Color("687e72"))
	draw_rect(Rect2(area.position-Vector2(0,height),area.size),Color("9aa58e"))
	for row in range(maxi(1,int(size.y/30))):
		var y=-size.y-height+row*30
		draw_line(Vector2(-size.x*.5,y),Vector2(size.x*.5,y),Color("657e6e"),2,true)
		for x in range(int(-size.x*.5)+18+row%2*20,int(size.x*.5),43):
			draw_line(Vector2(x,y),Vector2(x+3,minf(y+29,-height)),Color("657e6e"),2,true)
	draw_line(Vector2(-size.x*.5,-size.y-height),Vector2(size.x*.5,-size.y-height),Color("c4c7ac"),3,true)

func _palisade() -> void:
	var size=_rect_size()
	draw_rect(Rect2(-size.x*.5,-size.y,size.x,size.y),Color("676c51"))
	if size.x>size.y:
		for x in range(int(-size.x*.5)+6,int(size.x*.5),15):
			_poly([[x-5,0],[x-5,-size.y-30],[x,-size.y-43],[x+6,-size.y-30],[x+6,0]],Color("837957"))
			draw_line(Vector2(x-2,-4),Vector2(x-2,-size.y-30),Color("b2a176"),1.5,true)
		draw_line(Vector2(-size.x*.5,-24),Vector2(size.x*.5,-24),Color("544f39"),7,true)
	else:
		for x in range(int(-size.x*.5)+4,int(size.x*.5),13):
			_poly([[x-5,0],[x-5,-size.y-22],[x,-size.y-34],[x+6,-size.y-22],[x+6,0]],Color("82795a"))
			draw_line(Vector2(x-2,-5),Vector2(x-2,-size.y-20),Color("a89c71"),2,true)
		for y in range(int(-size.y)+20,1,44):
			draw_line(Vector2(-size.x*.5,y),Vector2(size.x*.5,y),Color("55553f"),6,true)
			draw_line(Vector2(-size.x*.5,y-2),Vector2(size.x*.5,y-2),Color("b0a079"),1.5,true)

func _grainstack() -> void:
	var size=_rect_size()
	draw_rect(Rect2(-size.x*.5,-size.y,size.x,size.y),Color("8d825a"))
	for i in range(maxi(2,int(size.x/24))):
		var x=-size.x*.5+14+i*24
		_poly([[x-10,-5],[x-12,-size.y-15],[x-7,-size.y-23],[x+9,-size.y-21],[x+12,-size.y-13],[x+10,-5]],Color("b5a778"))
		draw_line(Vector2(x-9,-size.y*.5-10),Vector2(x+10,-size.y*.5-10),Color("87764e"),2,true)

func _boatframe() -> void:
	var size=_rect_size()
	_poly([[-size.x*.5,-size.y*.5],[-size.x*.40,-size.y], [size.x*.38,-size.y],[size.x*.5,-size.y*.5],[size.x*.38,0],[-size.x*.40,0]],Color("7a7f69"))
	for i in range(8):
		var x=-size.x*.36+i*size.x*.105
		draw_polyline(PackedVector2Array([Vector2(x,-size.y+10),Vector2(x-8,-size.y*.52),Vector2(x,-8)]),Color("b2a17a"),7,true)
	draw_line(Vector2(-size.x*.44,-size.y*.5),Vector2(size.x*.44,-size.y*.5),Color("5d654f"),9,true)

func _timber() -> void:
	var size=_rect_size()
	for i in range(5):
		var y=-size.y+i*14
		draw_line(Vector2(-size.x*.5+8,y),Vector2(size.x*.5-8,y),Color("968562"),13,true)
		draw_line(Vector2(-size.x*.5+8,y-3),Vector2(size.x*.5-8,y-3),Color("c0ad7d"),2,true)
		draw_circle(Vector2(size.x*.5-8,y),6,Color("bda879"))

func _drum_platform() -> void:
	# The interactive drum is drawn by its own object. This low plinth seats it.
	draw_rect(Rect2(-42,-7,84,19),Color("7d8069"))
	draw_rect(Rect2(-46,-15,92,15),Color("b0b194"))
	for x in [-35,-12,12,35]: draw_line(Vector2(x,-14),Vector2(x,0),Color("818e74"),1.5,true)
