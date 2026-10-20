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
	# Everything below is captured into the six ground textures by the bake.
	# No extra terrain nodes, collision shapes or per-frame painting are added.
	_surface_materials()
	_wet_ground_details()
	for bounds in definition.get("layout", {}).get("water", []): _water(bounds)
	match definition.get("layout", {}).get("motif", ""):
		"bamboo_path": _bamboo_floor()
		"grain_tracks":
			_cart_tracks()
			_grain_floor()
		"rock_pass":
			_cart_tracks()
			_rock_seams()
		"open_camp":
			_camp_floor()
			# Painted guard marks are traversable. They make the flag's useful area visible.
			for at in [Vector2(560,320),Vector2(640,340),Vector2(700,400)]:
				draw_arc(at,23,0,TAU,20,Color(.69,.81,.72,.42),2,true)
			for y in [440,680]: draw_line(Vector2(935,y),Vector2(1065,y),Color(.71,.67,.47,.45),3,true)
		"river_docks": _river_floor()
		"iron_arena":
			_iron_floor()
			var center = Vector2(1000,460)
			for radius in [180,195]:
				draw_set_transform(center,0,Vector2(1,.68))
				draw_arc(Vector2.ZERO,radius,0,TAU,60,Color(.21,.33,.36,.26),2,true)
			draw_set_transform(Vector2.ZERO)

func _rng(salt: int) -> RandomNumberGenerator:
	var rng=RandomNumberGenerator.new()
	rng.seed=int(definition.get("seed",21900))+salt
	return rng

func _road_distance(at: Vector2) -> float:
	var distance=INF
	for road in definition.get("roads",[]):
		for i in range(1,road.size()):
			var a=Vector2(road[i-1][0],road[i-1][1]); var b=Vector2(road[i][0],road[i][1])
			distance=minf(distance,at.distance_to(Geometry2D.get_closest_point_to_segment(at,a,b)))
	return distance

func _in_solid(at: Vector2, margin=0.0) -> bool:
	for value in definition.get("layout",{}).get("solids",[]):
		if value.has("rect"):
			var r=value.rect
			if Rect2(r[0],r[1],r[2],r[3]).grow(margin).has_point(at): return true
	return false

func _all_inside(values: PackedVector2Array, polygon: PackedVector2Array) -> bool:
	for at in values:
		if not Geometry2D.is_point_in_polygon(at,polygon): return false
	return true

func _on_surface(at: Vector2) -> bool:
	for surface in definition.get("layout",{}).get("surfaces",[]):
		if Geometry2D.is_point_in_polygon(at,_points(surface.polygon)): return true
	return false

func _surface_materials() -> void:
	var rng=_rng(610)
	for surface in definition.get("layout",{}).get("surfaces",[]):
		var polygon=_points(surface.polygon)
		var kind=str(surface.kind)
		var base=Color("87968a") if kind=="earth" else Color("91a29b")
		if stage=="hs_grain": base=Color("949d8e") if kind=="earth" else Color("9ba79d")
		if stage=="hs_camp": base=Color("8e9888") if kind=="earth" else Color("8d9d95")
		if stage=="hs_river": base=Color("8d9e91") if kind=="earth" else Color("9bac9f")
		if kind=="stone" or kind=="flagstone": base=Color("7a9190")
		draw_colored_polygon(polygon,base)
		var bounds=Rect2(polygon[0],Vector2.ZERO)
		for at in polygon: bounds=bounds.expand(at)
		# Low-contrast irregular patchwork replaces the old flat tan clearings.
		for i in range(330):
			var at=Vector2(rng.randf_range(bounds.position.x,bounds.end.x),rng.randf_range(bounds.position.y,bounds.end.y))
			var r=rng.randf_range(4,18)
			var chip=PackedVector2Array([at+Vector2(-r,-r*.32),at+Vector2(-r*.34,-r*.62),at+Vector2(r*.67,-r*.43),at+Vector2(r,0),at+Vector2(r*.37,r*.53),at+Vector2(-r*.68,r*.43)])
			if not _all_inside(chip,polygon): continue
			if kind=="earth":
				draw_colored_polygon(chip,base.lightened(.035) if i%2 else base.darkened(.045))
				if i%4==0: draw_line(at+Vector2(-7,0),at+Vector2(9,-1),Color(base.darkened(.15),.34),1,true)
			elif kind!="flagstone":
				draw_colored_polygon(chip,base.lightened(rng.randf_range(.025,.075)) if i%3 else base.darkened(.07))
				draw_line(chip[0]+Vector2(1,1),chip[1]+Vector2(1,1),base.darkened(.10),1.1,true)
		if kind=="stone" or kind=="flagstone":
			for y in range(120,1050,42):
				for x in range(120,1510,65):
					var at=Vector2(x+(int(y/42)%2)*32,y)
					var tile=PackedVector2Array([at+Vector2(2,2),at+Vector2(61,3),at+Vector2(60,38),at+Vector2(3,39)])
					if not _all_inside(tile,polygon): continue
					var color=base.lightened(rng.randf_range(.03,.12))
					draw_colored_polygon(tile,color)
					draw_line(tile[0],tile[1],color.lightened(.11),1.3,true)
					draw_line(tile[2],tile[3],base.darkened(.14),1.6,true)
					if rng.randf()<.20:
						draw_polyline(PackedVector2Array([at+Vector2(15,2),at+Vector2(25,15),at+Vector2(21,25)]),base.darkened(.13),1,true)
		for i in range(polygon.size()):
			var a=polygon[i]; var b=polygon[(i+1)%polygon.size()]
			draw_line(a,b,Color(base.darkened(.16),.22),3,true)
			for j in range(int(a.distance_to(b)/24.0)):
				var at=a.lerp(b,(j+.3)/maxf(1,int(a.distance_to(b)/24.0)))
				_oval(at,rng.randf_range(3,7),.42,Color("748e80"))

func _wet_ground_details() -> void:
	var rng=_rng(620)
	for i in range(310):
		var at=Vector2(rng.randf_range(25,1570),rng.randf_range(35,1060))
		if in_water(at,definition,16) or _in_solid(at,12) or _on_surface(at): continue
		var distance=_road_distance(at)
		if distance<47: continue
		var tint=Color(.20,.35,.32,.055) if i%2 else Color(.72,.79,.64,.055)
		_oval(at,rng.randf_range(10,29),.35,tint)
		# Flat fern rosettes are painted into the floor, never false obstacles.
		if i%5==0 and distance>84:
			for blade in range(5):
				var angle=-PI*.80+blade*.35
				var tip=at+Vector2(cos(angle)*17,sin(angle)*9)
				draw_line(at,tip,Color(.24,.40,.33,.30),1.5,true)
				draw_line(tip,tip+Vector2(-3,4),Color(.54,.66,.48,.25),1,true)
		if i%9==0 and distance>85:
			_oval(at,8,.27,Color(.64,.73,.67,.30))
			draw_line(at+Vector2(-4,-1),at+Vector2(4,-1),Color(.77,.82,.72,.33),1,true)

func _bamboo_floor() -> void:
	var rng=_rng(630)
	for cluster in [Vector2(280,680),Vector2(520,245),Vector2(900,280),Vector2(1110,810),Vector2(180,410),Vector2(1390,550)]:
		# Soft slanting cane shadows distinguish the opening from Changban's grass.
		for branch in range(7):
			var start=cluster+Vector2(branch*11-35,branch%3*9)
			var end=start+Vector2(72,-44-branch*5)
			draw_line(start,end,Color(.12,.30,.26,.12),4,true)
			for node in range(3):
				var p=start.lerp(end,.25+node*.22)
				draw_line(p,p+Vector2(22,-2),Color(.13,.31,.26,.11),3,true)
		for i in range(36):
			var at=cluster+Vector2(rng.randf_range(-85,95),rng.randf_range(-45,75))
			var side=1 if i%2 else -1
			_poly([[at.x,at.y],[at.x+side*9,at.y-4],[at.x+side*19,at.y-3],[at.x+side*8,at.y+1]],Color(.71,.72,.47,.32) if i%3 else Color(.26,.42,.33,.35))
	# Small, flush wet stepping stones: readable path without a raised obstacle.
	for road in definition.roads:
		for i in range(1,road.size()):
			var a=Vector2(road[i-1][0],road[i-1][1]); var b=Vector2(road[i][0],road[i][1])
			for n in range(int(a.distance_to(b)/42.0)):
				var at=a.lerp(b,(n+.5)/maxf(1,int(a.distance_to(b)/42.0)))+Vector2(rng.randf_range(-20,20),rng.randf_range(-10,10))
				_oval(at,11+int(n%3),.40,Color(.68,.75,.68,.60))
				draw_line(at+Vector2(-6,-2),at+Vector2(4,-3),Color(.83,.86,.76,.43),1.3,true)

func _cart_tracks() -> void:
	for road in definition.roads:
		var route=_points(road)
		for side in [-1,1]:
			var track=PackedVector2Array()
			for i in range(route.size()):
				var direction=(route[mini(i+1,route.size()-1)]-route[maxi(0,i-1)]).normalized()
				track.append(route[i]+direction.orthogonal()*side*18)
			draw_polyline(track,Color(.24,.35,.32,.085),5,true)
			draw_polyline(track,Color(.31,.39,.33,.12),1.7,true)
			for i in range(1,track.size()):
				var a=track[i-1]; var b=track[i]
				var normal=(b-a).normalized().orthogonal()
				for n in range(int(a.distance_to(b)/20.0)):
					var at=a.lerp(b,(n+.4)/maxf(1,int(a.distance_to(b)/20.0)))
					draw_line(at-normal*3,at+normal*3,Color(.27,.36,.31,.14),1.4,true)

func _grain_floor() -> void:
	var rng=_rng(640)
	for center in [Vector2(1038,812),Vector2(1390,925),Vector2(1100,305)]:
		for i in range(65):
			var at=center+Vector2(rng.randf_range(-60,65),rng.randf_range(-20,40))
			if _in_solid(at,2): continue
			draw_line(at,at+Vector2(2,-3),Color(.80,.75,.49,.38),1.5,true)
	for center in [Vector2(350,740),Vector2(960,600),Vector2(1260,550)]:
		_oval(center,42,.23,Color(.28,.43,.42,.13))
		draw_arc(center,31,.2,2.4,15,Color(.70,.80,.73,.15),1.2,true)

func _rock_seams() -> void:
	for bounds in definition.get("layout",{}).get("solids",[]):
		if not bounds.has("rect"): continue
		var r=bounds.rect
		for i in range(3):
			var start=Vector2(r[0]+r[2]*.24+i*38,r[1]+r[3]+8)
			draw_polyline(PackedVector2Array([start,start+Vector2(12,9),start+Vector2(41,15),start+Vector2(53,29)]),Color(.26,.39,.37,.22),2,true)
			draw_line(start+Vector2(12,9),start+Vector2(-7,22),Color(.29,.42,.38,.16),1.5,true)

func _camp_floor() -> void:
	# Shallow drainage scores and compacted strips establish a built military camp.
	for a in [Vector2(210,1005),Vector2(465,210)]:
		var end=a+Vector2(430,-35) if a.y>500 else a+Vector2(300,0)
		draw_line(a,end,Color(.28,.37,.33,.25),5,true)
		draw_line(a+Vector2(0,3),end+Vector2(0,3),Color(.70,.74,.61,.34),2,true)
	for y in [268,309,350,391,432]:
		draw_line(Vector2(510,y),Vector2(750,y),Color(.28,.42,.38,.12),2,true)
		for x in [515,570,625,680,735]:
			draw_line(Vector2(x,y-4),Vector2(x+10,y+2),Color(.69,.77,.66,.26),2,true)
	# Gate approach carries old wheel grooves, not extra blocking barricades.
	for y in [536,580]:
		draw_line(Vector2(1055,y),Vector2(1510,y),Color(.30,.38,.32,.18),3,true)
	for x in range(1090,1510,36):
		_oval(Vector2(x,612+(x%3)*5),7,.36,Color(.26,.37,.34,.20))
		_oval(Vector2(x+13,596),6,.32,Color(.26,.37,.34,.15))

func _river_floor() -> void:
	var rng=_rng(650)
	# Pebble/mud shelves remain on the walkable bank; deep water begins exactly at collision.
	for i in range(180):
		var at=Vector2(rng.randf_range(120,1470),rng.randf_range(905,938)) if i<125 else Vector2(rng.randf_range(1446,1477),rng.randf_range(145,920))
		if _in_solid(at,1): continue
		_oval(at,rng.randf_range(3,10),.44,Color("849e95") if i%2 else Color("b0bcaa"))
		if i%5==0: draw_line(at+Vector2(-2,-1),at+Vector2(3,-2),Color("c0c9b8"),1,true)
	for center in [Vector2(400,510),Vector2(1090,830),Vector2(1310,650)]:
		_oval(center,35,.28,Color(.29,.45,.44,.16))
		for i in range(3):
			draw_line(center+Vector2(-23+i*7,-6+i*6),center+Vector2(17+i*5,-7+i*6),Color(.75,.83,.75,.23),1.3,true)
	# Rope impressions and worn sleepers connect the boat skeleton to its shore.
	for i in range(6):
		var at=Vector2(720+i*31,666)
		draw_line(at,at+Vector2(0,20),Color(.34,.40,.32,.26),5,true)
		draw_line(at+Vector2(-2,0),at+Vector2(-2,18),Color(.69,.71,.54,.34),1.3,true)

func _iron_floor() -> void:
	var center=Vector2(1000,460)
	# An inset octagonal command seal and strict parade scores distinguish the arena.
	for radius in [120,126]:
		var ring=PackedVector2Array()
		for i in range(9):
			var angle=i*TAU/8
			ring.append(center+Vector2(cos(angle)*radius,sin(angle)*radius*.68))
		draw_polyline(ring,Color(.22,.36,.38,.24),2,true)
	for side in [-1,1]:
		for i in range(3):
			var at=center+Vector2(side*(146+i*35),0)
			draw_line(at+Vector2(0,-22),at+Vector2(0,22),Color(.22,.35,.36,.24),3,true)
			draw_line(at+Vector2(-8,-22),at+Vector2(8,-22),Color(.73,.80,.73,.28),2,true)
	for i in range(5):
		var at=Vector2(820+i*78,682)
		draw_line(at,at+Vector2(20,-11),Color(.19,.31,.33,.23),3,true)
		draw_line(at+Vector2(3,4),at+Vector2(23,-7),Color(.70,.78,.71,.23),1.5,true)

func _water(bounds: Array) -> void:
	var area = Rect2(bounds[0],bounds[1],bounds[2],bounds[3])
	draw_rect(area,Color("2b555e"))
	var horizontal=area.size.x>area.size.y
	var shore_start=area.position if area.position.y>100 or not horizontal else Vector2(area.position.x,area.end.y)
	var shore_end=Vector2(area.end.x,shore_start.y) if horizontal else Vector2(area.position.x,area.end.y)
	var inward=Vector2(0,1 if area.position.y>100 else -1) if horizontal else Vector2(1,0)
	for width in range(0,48,4):
		var tone=Color("6a918a").lerp(Color("2b555e"),width/48.0)
		draw_line(shore_start+inward*(width+2),shore_end+inward*(width+2),tone,4,true)
	var rng=_rng(660+int(area.position.x))
	for i in range(100):
		var p=area.position+Vector2(rng.randf_range(0,area.size.x),rng.randf_range(0,area.size.y))
		var length=minf(rng.randf_range(9,48),area.end.x-p.x)
		draw_line(p,p+Vector2(length,0),Color(.59,.75,.72,.13),rng.randf_range(1,2.2),true)
	for i in range(int(shore_start.distance_to(shore_end)/13)):
		var at=shore_start.lerp(shore_end,float(i)/maxf(1,int(shore_start.distance_to(shore_end)/13)))
		# The darkest bank lip lies exactly at the collision edge.
		var next=at+(shore_end-shore_start).normalized()*14
		draw_line(at,next,Color("46675f"),3,true)
		if i%3==0:
			draw_line(at+inward*(8+i%5),next+inward*(9+i%5),Color(.71,.82,.75,.38),1.4,true)
		if i%4==0:
			var reed=at+inward*3
			for stalk in range(3):
				var tip=reed+Vector2(-5+stalk*7,-13-rng.randf_range(4,14))
				draw_line(reed,tip,Color("617e67"),1.6,true)
				draw_line(tip,tip+Vector2(1,-5),Color("b1b69b"),2,true)
		if i%5==0:
			_oval(at+inward*6,5+i%3,.42,Color("7d9481"))

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
	_oval(Vector2(8,3),size*.49,.29,Color(.07,.20,.18,.18))
	for stalk in range(5):
		var x=(stalk-2)*12.0; var height=size*(.80+stalk%3*.13)
		var bottom=Vector2(x,0); var top=Vector2(x+(stalk-2)*4,-height)
		draw_line(bottom,top,Color("284f46"),7,true)
		draw_line(bottom+Vector2(-1.5,0),top+Vector2(-1.5,0),Color("749980"),3.3,true)
		draw_line(bottom+Vector2(-2.6,0),top+Vector2(-2.6,0),Color("a4b595"),1.2,true)
		for joint in range(1,5):
			var p=bottom.lerp(top,joint/5.0)
			draw_line(p+Vector2(-4,-1),p+Vector2(4,-1),Color("b7c09c"),1.6,true)
			draw_line(p+Vector2(-3,1),p+Vector2(3,1),Color("35574b"),1.1,true)
			var side=-1 if (joint+stalk)%2 else 1
			var branch=p+Vector2(side*34,-17-joint*2)
			draw_line(p,branch,Color("30594c"),1.8,true)
			for leaf in range(4):
				var stem=p.lerp(branch,.30+leaf*.20)
				var tip=stem+Vector2(side*(15+leaf*4),-12+leaf%2*23)
				draw_colored_polygon(PackedVector2Array([stem,stem.lerp(tip,.45)+Vector2(0,-3),tip,stem.lerp(tip,.45)+Vector2(0,3)]),Color("466f58") if (leaf+joint)%2 else Color("769478"))
				draw_line(stem,tip,Color(.63,.73,.55,.29),.8,true)
		for leaf in range(5):
			var root=Vector2(x,1)
			var tip=root+Vector2(-15+leaf*7,-5-leaf%2*7)
			draw_line(root,tip,Color("52765c"),1.6,true)

func _rect_size() -> Vector2:
	return Vector2(item.rect[2],item.rect[3])

func _stone_wall() -> void:
	var size = _rect_size(); var height=11.0 if item.kind=="lowwall" else 22.0
	var area=Rect2(-size.x*.5,-size.y,size.x,size.y)
	draw_rect(area.grow(4),Color(.16,.27,.23,.15))
	if item.kind=="rockwall":
		var left=-size.x*.5; var right=size.x*.5
		_poly([[left,0],[left,-size.y+10],[left+23,-size.y-height],[right-32,-size.y-height+3],[right,-size.y+8],[right,0]],Color("4c6a65"))
		_poly([[left,-size.y+10],[left+23,-size.y-height],[right-32,-size.y-height+3],[right,-size.y+8],[right-21,-size.y*.38],[right-72,-size.y*.48],[left+size.x*.38,-size.y*.34],[left+18,-size.y*.45]],Color("91a59c"))
		_poly([[left+23,-size.y-height],[left+size.x*.46,-size.y-height+3],[left+size.x*.38,-size.y*.34],[left+18,-size.y*.45],[left,-size.y+10]],Color("a5b6aa"))
		var rng=RandomNumberGenerator.new(); rng.seed=int(size.x*31+size.y*19)
		for i in range(17):
			var at=Vector2(rng.randf_range(left+25,right-28),rng.randf_range(-size.y+8,-size.y*.54))
			var r=rng.randf_range(5,14)
			_poly([[at.x-r,at.y],[at.x-r*.3,at.y-r*.5],[at.x+r*.6,at.y-r*.35],[at.x+r,at.y+r*.2],[at.x-r*.2,at.y+r*.4]],Color(.41,.55,.49,.23) if i%2 else Color(.73,.79,.68,.25))
		for band in range(3):
			var ridge=PackedVector2Array()
			for i in range(8):
				var x=left+8+i*(size.x-16)/7
				var y=-size.y*.32+band*12+sin(i*1.7+band)*5
				ridge.append(Vector2(x,y))
			draw_polyline(ridge,Color("7e9990") if band%2 else Color("355952"),2,true)
		for i in range(5):
			var x=left+26+i*(size.x-50)/5+rng.randf_range(-9,9)
			var middle=Vector2(x+rng.randf_range(-6,13),-size.y*rng.randf_range(.68,.82))
			var end=middle+Vector2(rng.randf_range(-13,8),rng.randf_range(8,24))
			draw_polyline(PackedVector2Array([Vector2(x,-size.y-height+rng.randf_range(9,31)),middle,end]),Color("627f76"),1.7,true)
			draw_line(middle,middle+Vector2(7,-3),Color("b6c4b5"),1.2,true)
		for i in range(12):
			var x=left+6+i*(size.x-12)/11
			_oval(Vector2(x,-2-i%3*2),7+i%4,.48,Color("4d735b"))
			draw_line(Vector2(x,-4-i%3*2),Vector2(x+4,-5-i%3*2),Color("92a582"),1.3,true)
		return
	draw_rect(area,Color("4c6862"))
	draw_rect(Rect2(area.position-Vector2(0,height),area.size),Color("91a59b"))
	for row in range(maxi(1,int(size.y/30))):
		var y=-size.y-height+row*30
		draw_line(Vector2(-size.x*.5,y),Vector2(size.x*.5,y),Color("597b72"),2,true)
		for x in range(int(-size.x*.5)+18+row%2*20,int(size.x*.5),43):
			draw_line(Vector2(x,y),Vector2(x+3,minf(y+29,-height)),Color("597b72"),2,true)
	draw_line(Vector2(-size.x*.5,-size.y-height),Vector2(size.x*.5,-size.y-height),Color("c1d0bc"),3,true)

func _palisade() -> void:
	var size=_rect_size()
	draw_rect(Rect2(-size.x*.5,-size.y,size.x,size.y),Color("4f655e"))
	if size.x>size.y:
		for x in range(int(-size.x*.5)+6,int(size.x*.5),15):
			_poly([[x-5,0],[x-5,-size.y-30],[x,-size.y-43],[x+6,-size.y-30],[x+6,0]],Color("6d7a66") if x%2 else Color("788470"))
			draw_line(Vector2(x-2,-4),Vector2(x-2,-size.y-30),Color("a5b195"),1.5,true)
			draw_line(Vector2(x+3,-9),Vector2(x+2,-size.y-19),Color("4f645a"),1,true)
		draw_line(Vector2(-size.x*.5,-24),Vector2(size.x*.5,-24),Color("374e49"),7,true)
		draw_line(Vector2(-size.x*.5,-26),Vector2(size.x*.5,-26),Color("8d9c87"),1.5,true)
		for x in range(int(-size.x*.5)+22,int(size.x*.5),60):
			for offset in [-2,2]: draw_line(Vector2(x+offset,-31),Vector2(x+offset+2,-17),Color("a7a486"),1.5,true)
	else:
		for x in range(int(-size.x*.5)+4,int(size.x*.5),13):
			_poly([[x-5,0],[x-5,-size.y-22],[x,-size.y-34],[x+6,-size.y-22],[x+6,0]],Color("6d7a66"))
			draw_line(Vector2(x-2,-5),Vector2(x-2,-size.y-20),Color("a5b195"),2,true)
			draw_line(Vector2(x+2,-13),Vector2(x+3,-size.y+8),Color("4c6257"),1.2,true)
		for y in range(int(-size.y)+20,1,44):
			draw_line(Vector2(-size.x*.5,y),Vector2(size.x*.5,y),Color("3b514a"),6,true)
			draw_line(Vector2(-size.x*.5,y-2),Vector2(size.x*.5,y-2),Color("98a58c"),1.5,true)
			for x in [-size.x*.3,size.x*.3]:
				for offset in [-2,2]: draw_line(Vector2(x+offset,y-6),Vector2(x+offset+2,y+5),Color("b0b091"),1.4,true)

func _grainstack() -> void:
	var size=_rect_size()
	draw_rect(Rect2(-size.x*.5,-size.y,size.x,size.y),Color("6c735c"))
	for i in range(maxi(2,int(size.x/24))):
		var x=-size.x*.5+14+i*24
		_poly([[x-10,-5],[x-12,-size.y-15],[x-7,-size.y-23],[x+9,-size.y-21],[x+12,-size.y-13],[x+10,-5]],Color("acaf87"))
		draw_line(Vector2(x-9,-size.y*.5-10),Vector2(x+10,-size.y*.5-10),Color("747958"),2,true)
		draw_line(Vector2(x-6,-size.y-16),Vector2(x-5,-8),Color("c4c39c"),1.4,true)
		for y in range(int(-size.y)-12,-7,7):
			draw_line(Vector2(x-9,y),Vector2(x+9,y-1),Color(.45,.48,.33,.23),.8,true)
		draw_line(Vector2(x-3,-size.y-21),Vector2(x+2,-size.y-14),Color("676e50"),2,true)

func _boatframe() -> void:
	var size=_rect_size()
	_poly([[-size.x*.5,-size.y*.5],[-size.x*.40,-size.y], [size.x*.38,-size.y],[size.x*.5,-size.y*.5],[size.x*.38,0],[-size.x*.40,0]],Color("3e5951"))
	_poly([[-size.x*.45,-size.y*.5],[-size.x*.36,-size.y+9], [size.x*.34,-size.y+9],[size.x*.45,-size.y*.5],[size.x*.34,-9],[-size.x*.36,-9]],Color("778d76"))
	for i in range(8):
		var x=-size.x*.36+i*size.x*.105
		draw_polyline(PackedVector2Array([Vector2(x,-size.y+10),Vector2(x-8,-size.y*.52),Vector2(x,-8)]),Color("b4b393"),7,true)
		draw_polyline(PackedVector2Array([Vector2(x+2,-size.y+10),Vector2(x-6,-size.y*.52),Vector2(x+2,-8)]),Color("6c7961"),1.5,true)
		for y in [-size.y+16,-size.y*.52,-16]: draw_circle(Vector2(x,y),1.7,Color("445b51"))
	draw_line(Vector2(-size.x*.44,-size.y*.5),Vector2(size.x*.44,-size.y*.5),Color("4a6354"),9,true)
	draw_line(Vector2(-size.x*.44,-size.y*.5-3),Vector2(size.x*.44,-size.y*.5-3),Color("94a286"),1.7,true)
	for side in [-1,1]:
		var rope=PackedVector2Array()
		for i in range(20):
			var angle=i*TAU/19
			rope.append(Vector2(side*size.x*.26+cos(angle)*14,-size.y*.50+sin(angle)*7))
		draw_polyline(rope,Color("b9b08b"),2,true)

func _timber() -> void:
	var size=_rect_size()
	for i in range(5):
		var y=-size.y+i*14
		draw_line(Vector2(-size.x*.5+8,y),Vector2(size.x*.5-8,y),Color("7d8a70"),13,true)
		draw_line(Vector2(-size.x*.5+8,y-3),Vector2(size.x*.5-8,y-3),Color("bac2a0"),2,true)
		draw_line(Vector2(-size.x*.5+15,y+3),Vector2(size.x*.5-15,y+2),Color("596f59"),1.5,true)
		draw_circle(Vector2(size.x*.5-8,y),6,Color("b8bd95"))
		draw_arc(Vector2(size.x*.5-8,y),3,0,TAU,12,Color("85906b"),1,true)

func _drum_platform() -> void:
	# The interactive drum is drawn by its own object. This low plinth seats it.
	draw_rect(Rect2(-42,-7,84,19),Color("7d8069"))
	draw_rect(Rect2(-46,-15,92,15),Color("b0b194"))
	for x in [-35,-12,12,35]: draw_line(Vector2(x,-14),Vector2(x,0),Color("818e74"),1.5,true)
