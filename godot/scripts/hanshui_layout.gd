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
var world
var occlusion_bounds=Rect2()

static func frame_key(value: Dictionary) -> String:
	if value.has("rect"): return str(value.kind)+"_"+str(int(value.rect[2]))+"_"+str(int(value.rect[3]))
	return str(value.kind)+"_"+str(int(value.get("size",0)))

func _ready() -> void:
	set_process(false)
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
	if item.kind in ["rockwall","palisade"]:
		occlusion_bounds=Rect2(rendered_prop.position,texture.get_size())
		set_process(true)

func _process(delta: float) -> void:
	if not is_instance_valid(world) or rendered_prop==null: return
	if world.mode!="playing": return
	var hero=world.get("hero")
	if not is_instance_valid(hero): return
	var target=1.0
	# Only fade the foreground piece that overlaps Zhao Yun's upper body.
	# Whole walls remain opaque at a distance, beside him and in front of him.
	if hero.global_position.y<global_position.y-6:
		var body=Rect2(hero.global_position+Vector2(-24,-82),Vector2(48,65))
		var prop=Rect2(global_position+occlusion_bounds.position,occlusion_bounds.size)
		var overlap=prop.intersection(body)
		if overlap.size.x>=6 and overlap.size.y>=12: target=.26
	rendered_prop.modulate.a=move_toward(rendered_prop.modulate.a,target,delta*4.5)

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
		node.world=parent.get_parent()
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
		"iron_arena": _iron_floor()

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
	# These are painted materials, not additions to layout.surfaces/clearings.
	# Navigation and the placement RNG never see the authored composition.
	if stage=="hs_camp":
		_packed_ground([[170,190],[485,170],[775,200],[930,325],[953,480],[946,970],[752,1030],[210,1040],[155,865],[236,670]],Color("a59b7e"),34)
		_packed_ground([[1042,300],[1415,310],[1575,400],[1570,795],[1380,842],[1042,785]],Color("8e8e76"),38)
		return
	if stage=="hs_final":
		# A broad compacted parade yard, deliberately without the old stone
		# octagon. Its irregular limits cover the earlier generic paving layer.
		_packed_ground([[580,180],[690,130],[1200,142],[1375,220],[1418,410],[1410,690],[1320,785],[1110,810],[720,790],[590,650]],Color("92917c"),82)
		_packed_ground([[135,815],[330,740],[440,840],[405,1000],[210,1040],[122,944]],Color("8b917c"),24)
		return
	for surface in definition.get("layout",{}).get("surfaces",[]):
		var polygon=_points(surface.polygon)
		var base={"hs_forest":Color("7e9079"),"hs_grain":Color("ac9e77"),"hs_return":Color("929a92"),"hs_river":Color("91a18f")}.get(stage,Color("8d9986"))
		if stage=="hs_river" and surface.kind=="earth": base=Color("899482")
		# Same walkable polygons, but no beveled flagstones or planted border.
		# A broad feather hides the previous renderer's uniformly outlined edge.
		var edge=polygon.duplicate(); edge.append(polygon[0])
		draw_polyline(edge,Color(base,.45),22,true)
		draw_colored_polygon(polygon,base)
		_soil_scuffs(polygon,base,52 if stage=="hs_return" else 28)

func _packed_ground(values: Array, tone: Color, marks: int) -> void:
	var polygon=_points(values)
	var edge=polygon.duplicate(); edge.append(polygon[0])
	draw_polyline(edge,Color(tone,.34),32,true)
	draw_colored_polygon(polygon,tone)
	_soil_scuffs(polygon,tone,marks)

func _soil_scuffs(polygon: PackedVector2Array, tone: Color, count: int) -> void:
	var bounds=Rect2(polygon[0],Vector2.ZERO)
	for at in polygon: bounds=bounds.expand(at)
	# Sparse low-contrast pressure marks. No repeated paving grid or carpet
	# of random props; the central battle area stays readable for telegraphs.
	for i in range(count):
		var p=bounds.position+Vector2(fposmod(i*131.7+51,bounds.size.x),fposmod(i*67.3+19,bounds.size.y))
		var length=8.0+float(i%4)*6.0
		var end=p+Vector2(length,-2)
		if not Geometry2D.is_point_in_polygon(p,polygon) or not Geometry2D.is_point_in_polygon(end,polygon): continue
		draw_line(p,end,Color(tone.darkened(.22),.20),1.3,true)
		if i%3==0: draw_line(p+Vector2(0,2),end+Vector2(0,1),Color(tone.lightened(.20),.22),1,true)

func _wet_ground_details() -> void:
	if stage!="hs_forest": return
	# Moisture follows the actual bamboo path edges instead of identical
	# random puddles on every military camp, loading yard and stone pass.
	for road in definition.roads:
		for i in range(1,road.size()):
			var a=Vector2(road[i-1][0],road[i-1][1]); var b=Vector2(road[i][0],road[i][1])
			var forward=(b-a).normalized(); var side=forward.orthogonal()
			var count=maxi(1,int(a.distance_to(b)/115))
			for n in range(count):
				var p=a.lerp(b,(n+.5)/count)+side*(44 if n%2 else -45)
				draw_line(p-forward*18,p+forward*26,Color(.22,.32,.26,.21),8,true)
				draw_line(p-forward*8+side*3,p+forward*17+side*3,Color(.67,.74,.59,.22),1.2,true)

func _bamboo_floor() -> void:
	var rng=_rng(630)
	for prop in definition.layout.decor:
		if prop.kind!="bamboo": continue
		var cluster=Vector2(prop.position[0],prop.position[1])
		# Humus and shed leaves gather under the four authored bamboo clumps.
		# The thin irregular skirt is ground paint, not another raised planter.
		var skirt=PackedVector2Array()
		for i in range(14):
			var a=i*TAU/14; var r=1.0+sin(i*2.1+cluster.x)*.14
			skirt.append(cluster+Vector2(cos(a)*102,sin(a)*45)*r)
		draw_colored_polygon(skirt,Color(.20,.32,.23,.24))
		for branch in range(5):
			var start=cluster+Vector2(branch*11-35,branch%3*9)
			var end=start+Vector2(72,-44-branch*5)
			draw_line(start,end,Color(.12,.30,.26,.12),4,true)
			for node in range(3):
				var p=start.lerp(end,.25+node*.22)
				draw_line(p,p+Vector2(22,-2),Color(.13,.31,.26,.11),3,true)
		for i in range(46):
			var at=cluster+Vector2(rng.randf_range(-88,90),rng.randf_range(-31,39))
			var side=1 if i%2 else -1
			_poly([[at.x,at.y],[at.x+side*9,at.y-4],[at.x+side*19,at.y-3],[at.x+side*8,at.y+1]],Color(.65,.66,.39,.48) if i%3 else Color(.21,.33,.24,.48))
	# A handful of flush stones, not an evenly dotted navigation line.
	for road in definition.roads:
		for i in range(1,road.size()):
			var a=Vector2(road[i-1][0],road[i-1][1]); var b=Vector2(road[i][0],road[i][1])
			for n in range(int(a.distance_to(b)/42.0)):
				if n%5 in [0,1,3]: continue
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
	# Canvas and spilled grain belong to the existing rack/stacks, with drag
	# marks leading toward the actual loading route. No decorative new crate.
	for loading in [[Vector2(1067,305),Vector2(1127,354)],[Vector2(1045,820),Vector2(1096,788)],[Vector2(1420,928),Vector2(1352,841)]]:
		var center: Vector2=loading[0]; var destination: Vector2=loading[1]
		_poly([[center.x-57,center.y-16],[center.x+49,center.y-22],[center.x+64,center.y+17],[center.x-50,center.y+23]],Color("9f956e"))
		for i in range(10):
			var x=center.x-45+i*10
			draw_line(Vector2(x,center.y-12),Vector2(x+6,center.y+14),Color(.76,.70,.44,.42),1,true)
		for i in range(7):
			var y=center.y-12+i*4
			draw_line(Vector2(center.x-44,y),Vector2(center.x+45,y-3),Color(.37,.34,.21,.21),1,true)
		for i in range(50):
			var at=center+Vector2(rng.randf_range(-62,61),rng.randf_range(-14,33))
			if _in_solid(at,1): continue
			draw_line(at,at+Vector2(2,-2),Color("d4bd7b") if i%3 else Color("7d734e"),1.6,true)
		var normal=(destination-center).normalized().orthogonal()
		for offset in [-15,15]:
			draw_line(center+normal*offset,destination+normal*offset,Color(.36,.33,.23,.22),3.5,true)
	# A compact threshing scar near the loading ground, shallow and traversable.
	for row in range(8):
		var a=Vector2(531+row*5,570+row*13)
		draw_line(a,a+Vector2(132,-15),Color(.47,.43,.29,.12),2,true)

func _rock_seams() -> void:
	for prop in definition.layout.decor:
		if prop.kind!="rockwall": continue
		var r=prop.rect
		# Layered bedrock continues from the actual rock face into a flat scree
		# apron; it does not invent additional cliff collision on the cart route.
		var apron=[[r[0]-16,r[1]+r[3]-4],[r[0]+r[2]+15,r[1]+r[3]-4],[r[0]+r[2]+35,r[1]+r[3]+19],[r[0]+r[2]*.60,r[1]+r[3]+31],[r[0]+38,r[1]+r[3]+24],[r[0]-29,r[1]+r[3]+11]]
		_poly(apron,Color(.42,.48,.45,.25))
		for band in range(3):
			var line=PackedVector2Array()
			for i in range(9):
				line.append(Vector2(r[0]-11+i*(r[2]+24)/8,r[1]+r[3]+6+band*7+sin(i*1.6+band)*3))
			draw_polyline(line,Color(.34,.40,.38,.24),1.4,true)
		for i in range(8):
			var at=Vector2(r[0]+18+i*(r[2]-36)/7,r[1]+r[3]+11+i%3*8)
			_poly([[at.x-7,at.y],[at.x+3,at.y-3],[at.x+14,at.y],[at.x+4,at.y+2]],Color("a2aaa0") if i%3 else Color("77847b"))

func _camp_floor() -> void:
	# The actual palisade defines the camp. Foot traffic is orderly inside,
	# churned outside; keep the open gate and the hero's dueling lane uncluttered.
	for prop in definition.layout.decor:
		if prop.kind!="palisade": continue
		var r=prop.rect
		var a=Vector2(r[0]-14,r[1]+10); var b=Vector2(r[0]-14,r[1]+r[3]-5)
		draw_line(a,b,Color(.34,.32,.25,.25),3,true)
		draw_line(a+Vector2(-3,0),b+Vector2(-3,0),Color(.76,.72,.55,.31),1.2,true)
	for y in [280,333,386,439]:
		for x in [520,575,630,685,740]:
			draw_line(Vector2(x,y),Vector2(x+5,y-3),Color(.39,.37,.28,.16),2,true)
			draw_line(Vector2(x+8,y+3),Vector2(x+13,y),Color(.39,.37,.28,.13),2,true)
	# Old wheel grooves lead exactly through the open gate span.
	for y in [536,580]:
		draw_line(Vector2(910,y),Vector2(1510,y),Color(.34,.33,.25,.18),3,true)
	for x in range(1090,1510,36):
		_oval(Vector2(x,640+(x%3)*5),5,.45,Color(.30,.33,.27,.20))
		_oval(Vector2(x+13,624),4,.44,Color(.30,.33,.27,.15))

func _river_floor() -> void:
	var rng=_rng(650)
	# Broad flat mud shelves follow the existing L-shaped shore. Their uneven
	# inland edge is a receding water stain; deep water still begins at y=940/x=1480.
	_poly([[110,940],[110,901],[310,887],[465,897],[665,878],[870,894],[1055,880],[1270,889],[1478,871],[1478,940]],Color("7c8c78"))
	_poly([[1480,132],[1440,132],[1414,300],[1438,472],[1418,650],[1433,807],[1404,940],[1480,940]],Color("7d8e7d"))
	for band in range(3):
		var shore=PackedVector2Array()
		for i in range(17): shore.append(Vector2(115+i*84,909+band*8+sin(i*1.9+band*.35)*5))
		draw_polyline(shore,Color(.29,.40,.32,.22),1.5,true)
		var bank=PackedVector2Array()
		for i in range(11): bank.append(Vector2(1445+band*9+sin(i*1.8)*4,140+i*77))
		draw_polyline(bank,Color(.29,.40,.32,.20),1.5,true)
	# Low pebble ridges sit at the high-water mark, not uniformly over the floor.
	for i in range(100):
		var at=Vector2(rng.randf_range(120,1470),rng.randf_range(905,938)) if i<70 else Vector2(rng.randf_range(1446,1477),rng.randf_range(145,920))
		if _in_solid(at,1): continue
		_oval(at,rng.randf_range(2,6),.35,Color("849685") if i%2 else Color("a8b29a"))
		if i%5==0: draw_line(at+Vector2(-2,-1),at+Vector2(3,-2),Color("c0c9b8"),1,true)
	# Dragged keel/sleeper impressions lead from the real beached boat to the
	# actual southern river edge. They are shallow scars, never new timber walls.
	for pair in [[Vector2(715,653),Vector2(885,935)],[Vector2(875,653),Vector2(1045,935)]]:
		draw_line(pair[0],pair[1],Color(.31,.36,.27,.16),11,true)
		draw_line(pair[0]+Vector2(4,0),pair[1]+Vector2(4,0),Color(.65,.69,.52,.23),2,true)
	for i in range(7):
		var p=Vector2(747+i*22,682+i*36)
		draw_line(p,p+Vector2(92,-4),Color(.36,.39,.28,.18),4,true)
	# Coiled-rope prints beside the existing mooring point.
	for r in [12,16,20]:
		draw_set_transform(Vector2(1355,728),0,Vector2(1,.45))
		draw_arc(Vector2.ZERO,r,.3,TAU-.3,28,Color(.63,.61,.42,.33),1.8,true)
	draw_set_transform(Vector2.ZERO)

func _iron_floor() -> void:
	# Foot ranks flank the arena and align to the real south/east stockades.
	# There is no shrine medallion, paving grid or ring under the boss.
	for row in range(3):
		var y=642+row*38
		for column in range(9):
			var x=752+column*53
			draw_line(Vector2(x,y),Vector2(x+7,y-2),Color(.33,.33,.27,.38),2.6,true)
			draw_line(Vector2(x+13,y+2),Vector2(x+20,y),Color(.33,.33,.27,.30),2.4,true)
	for row in range(6):
		var y=328+row*53
		for column in range(2):
			var x=1288+column*32
			draw_line(Vector2(x,y),Vector2(x+2,y+7),Color(.32,.34,.28,.34),2.5,true)
			draw_line(Vector2(x+9,y+11),Vector2(x+11,y+18),Color(.32,.34,.28,.27),2.3,true)
	# Packed pressure lines terminate before the active fight center.
	for y in [628,748]:
		draw_line(Vector2(723,y),Vector2(1245,y),Color(.40,.40,.32,.27),2,true)
		draw_line(Vector2(723,y+3),Vector2(1245,y+3),Color(.75,.73,.59,.25),1,true)
	for x in [1271,1367]: draw_line(Vector2(x,305),Vector2(x,666),Color(.39,.40,.32,.26),2,true)
	# Worn drill lanes sit along the west rim, with a clear gap at the boss entry.
	for y in [315,375,435,495]:
		draw_line(Vector2(662,y),Vector2(714,y-7),Color(.37,.38,.29,.19),7,true)
		draw_line(Vector2(663,y+4),Vector2(714,y-3),Color(.72,.70,.55,.21),1.3,true)
	# Two established banners cast low, painted cloth shadows onto the yard.
	for at in [Vector2(720,245),Vector2(1325,670)]:
		_poly([[at.x+5,at.y+3],[at.x+70,at.y+20],[at.x+91,at.y+36],[at.x+58,at.y+32],[at.x+52,at.y+24],[at.x+3,at.y+7]],Color(.22,.28,.23,.23))

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
	var size = _rect_size(); var height=11.0 if item.kind=="lowwall" else 12.0
	var area=Rect2(-size.x*.5,-size.y,size.x,size.y)
	if item.kind=="rockwall":
		var left=-size.x*.5; var right=size.x*.5
		# The physical footprint stays rectangular, but its exposed face is a
		# broken shale outcrop, not a masonry box with a flat rectangular lid.
		_poly([[left-2,1],[left-3,-size.y*.28],[left+1,-size.y*.65],[left,-size.y+8],[left+18,-size.y-height],[left+size.x*.33,-size.y-7],[left+size.x*.48,-size.y-16],[left+size.x*.67,-size.y-4],[right-12,-size.y-7],[right,-size.y+9],[right+2,-size.y*.45],[right-2,-16],[right,0],[right-18,3],[left+size.x*.53,-1],[left+18,3]],Color("728178"))
		# Only the final 18 pixels form a vertical face. Most of the footprint
		# is low, fractured rock seen from above, reducing the solid-block look.
		_poly([[left+2,-size.y+9],[left+20,-size.y-height],[left+size.x*.33,-size.y-7],[left+size.x*.48,-size.y-16],[left+size.x*.67,-size.y-4],[right-12,-size.y-7],[right-2,-size.y+9],[right-1,-22],[right-24,-16],[left+size.x*.66,-23],[left+size.x*.43,-17],[left+size.x*.26,-25],[left+3,-18]],Color("8d9e91"))
		# Unequal, offset plates leave dark discontinuous faults between them.
		_poly([[left+7,-size.y+9],[left+24,-size.y-7],[left+size.x*.30,-size.y+1],[left+size.x*.40,-size.y*.72],[left+size.x*.31,-size.y*.43],[left+12,-size.y*.45]],Color("a4afa0"))
		_poly([[left+size.x*.34,-size.y+5],[left+size.x*.49,-size.y-10],[left+size.x*.68,-size.y+1],[left+size.x*.66,-size.y*.55],[left+size.x*.54,-size.y*.40],[left+size.x*.41,-size.y*.63]],Color("9caa9c"))
		_poly([[left+size.x*.71,-size.y+7],[right-15,-size.y-1],[right-6,-size.y+18],[right-8,-35],[left+size.x*.78,-28],[left+size.x*.67,-size.y*.43]],Color("a8b1a0"))
		_poly([[left+16,-size.y*.38],[left+size.x*.30,-size.y*.36],[left+size.x*.43,-28],[left+size.x*.34,-23],[left+17,-26]],Color("9aa592"))
		_poly([[left+size.x*.46,-size.y*.34],[left+size.x*.63,-size.y*.45],[left+size.x*.77,-30],[left+size.x*.65,-27],[left+size.x*.49,-22]],Color("a4ad9b"))
		for seam in [[Vector2(left+10,-11),Vector2(left+47,-8)],[Vector2(left+size.x*.37,-7),Vector2(left+size.x*.59,-11)],[Vector2(right-49,-13),Vector2(right-7,-8)]]:
			draw_line(seam[0],seam[1],Color("596e61"),1.6,true)
		for seam in [[Vector2(left+24,-size.y-7),Vector2(left+size.x*.29,-size.y+1)],[Vector2(left+size.x*.49,-size.y-10),Vector2(left+size.x*.64,-size.y-1)],[Vector2(right-15,-size.y-1),Vector2(right-6,-size.y+18)]]:
			draw_line(seam[0],seam[1],Color("bdc4b1"),1.3,true)
		for i in range(7):
			var p=Vector2(left+9+i*(size.x-18)/6,-2-i%3*2)
			_poly([[p.x-6,p.y],[p.x+1,p.y-4],[p.x+9,p.y-2],[p.x+6,p.y+2]],Color("7c8c78"))
		return
	draw_rect(area.grow(3),Color(.16,.27,.23,.12))
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
	draw_rect(Rect2(-size.x*.5,-size.y,size.x,size.y),Color("665f4b"))
	if size.x>size.y:
		for x in range(int(-size.x*.5)+6,int(size.x*.5),15):
			_stockade_post(Vector2(x,0),size.y+35+posmod(x,7),Color("8e8263") if x%2 else Color("81785d"))
		draw_line(Vector2(-size.x*.5,-24),Vector2(size.x*.5,-24),Color("4c4e3e"),7,true)
		draw_line(Vector2(-size.x*.5,-26),Vector2(size.x*.5,-26),Color("a69a76"),1.5,true)
		for x in range(int(-size.x*.5)+22,int(size.x*.5),60):
			for offset in [-2,2]: draw_line(Vector2(x+offset,-31),Vector2(x+offset+2,-17),Color("b0a581"),1.5,true)
		for x in range(int(-size.x*.5)+70,int(size.x*.5)-35,150): _wall_pennant(Vector2(x,-size.y*.50),1)
	else:
		# A north-south wall consists of successive short upright logs, not
		# six implausibly tall stakes stretching over the entire map corridor.
		for y in range(int(-size.y)+8,1,18):
			draw_line(Vector2(-size.x*.5+9,y),Vector2(size.x*.5-9,y+2),Color("817b5f"),9,true)
			draw_line(Vector2(-size.x*.5+9,y-2),Vector2(size.x*.5-9,y),Color("a59a74"),1,true)
			_stockade_post(Vector2(-size.x*.5+6,y),40+posmod(y,7),Color("7b755b"))
			_stockade_post(Vector2(size.x*.5-6,y),43+posmod(y,5),Color("958765"))
		for x in [-size.x*.5+10,size.x*.5-10]:
			draw_line(Vector2(x,-size.y-10),Vector2(x,-16),Color("514f3d"),4,true)
			draw_line(Vector2(x-1,-size.y-10),Vector2(x-1,-16),Color("a39871"),1,true)
		for y in range(int(-size.y)+82,-25,120): _wall_pennant(Vector2(size.x*.5-8,y),-1)

func _stockade_post(at: Vector2, height: float, tone: Color) -> void:
	var poly=PackedVector2Array([at+Vector2(-5,0),at+Vector2(-5,-height+10),at+Vector2(0,-height),at+Vector2(6,-height+10),at+Vector2(6,0)])
	draw_colored_polygon(poly,tone)
	draw_line(at+Vector2(-2,-4),at+Vector2(-2,-height+11),tone.lightened(.24),1.4,true)
	draw_line(at+Vector2(3,-8),at+Vector2(2,-height+16),tone.darkened(.25),1,true)

func _wall_pennant(at: Vector2, side: int) -> void:
	# Fixed cloth is tied to a wall that already blocks movement. No extra
	# free-standing decorative obstacle or per-frame animation is introduced.
	draw_line(at,at+Vector2(0,-67),Color("525244"),2.5,true)
	draw_colored_polygon(PackedVector2Array([at+Vector2(0,-63),at+Vector2(side*28,-58),at+Vector2(side*22,-46),at+Vector2(side*28,-35),at+Vector2(0,-41)]),Color("3e5551"))
	draw_line(at+Vector2(side*3,-60),at+Vector2(side*23,-56),Color("b5a982"),1.5,true)
	draw_line(at+Vector2(side*8,-54),at+Vector2(side*8,-44),Color("b2a47a"),1.5,true)

func _grainstack() -> void:
	var size=_rect_size()
	draw_rect(Rect2(-size.x*.5,-size.y,size.x,size.y),Color("746b4c"))
	for i in range(maxi(2,int(size.x/24))):
		var x=-size.x*.5+14+i*24
		_poly([[x-10,-5],[x-12,-size.y-15],[x-7,-size.y-23],[x+9,-size.y-21],[x+12,-size.y-13],[x+10,-5]],Color("b8a674"))
		draw_line(Vector2(x-9,-size.y*.5-10),Vector2(x+10,-size.y*.5-10),Color("7e704d"),2,true)
		draw_line(Vector2(x-6,-size.y-16),Vector2(x-5,-8),Color("d3c18e"),1.4,true)
		for y in range(int(-size.y)-12,-7,7):
			draw_line(Vector2(x-9,y),Vector2(x+9,y-1),Color(.45,.48,.33,.23),.8,true)
		draw_line(Vector2(x-3,-size.y-21),Vector2(x+2,-size.y-14),Color("676e50"),2,true)

func _boatframe() -> void:
	var size=_rect_size()
	# Open ribs, pointed ends and a dark keel read as a stranded hull rather
	# than another green rectangular platform. The foot/sort anchor is unchanged.
	_poly([[-size.x*.5,-size.y*.5],[-size.x*.43,-size.y*.86],[-size.x*.29,-size.y],[size.x*.28,-size.y],[size.x*.43,-size.y*.84],[size.x*.5,-size.y*.5],[size.x*.43,-size.y*.14],[size.x*.28,0],[-size.x*.29,0],[-size.x*.43,-size.y*.14]],Color("534e3a"))
	_poly([[-size.x*.45,-size.y*.5],[-size.x*.36,-size.y*.85],[-size.x*.25,-size.y+10],[size.x*.25,-size.y+10],[size.x*.38,-size.y*.82],[size.x*.45,-size.y*.5],[size.x*.37,-size.y*.15],[size.x*.25,-10],[-size.x*.25,-10],[-size.x*.36,-size.y*.15]],Color("928767"))
	_poly([[-size.x*.40,-size.y*.5],[-size.x*.27,-size.y+21],[size.x*.25,-size.y+21],[size.x*.40,-size.y*.5],[size.x*.25,-21],[-size.x*.27,-21]],Color("596655"))
	for i in range(8):
		var x=-size.x*.36+i*size.x*.105
		var inset=20.0 if i in [0,7] else 10.0
		draw_polyline(PackedVector2Array([Vector2(x,-size.y+inset),Vector2(x-8,-size.y*.52),Vector2(x,-inset)]),Color("b5a079"),7,true)
		draw_polyline(PackedVector2Array([Vector2(x+2,-size.y+inset),Vector2(x-6,-size.y*.52),Vector2(x+2,-inset)]),Color("6b6248"),1.5,true)
		for y in [-size.y+16,-size.y*.52,-16]: draw_circle(Vector2(x,y),1.7,Color("445b51"))
	draw_line(Vector2(-size.x*.46,-size.y*.5),Vector2(size.x*.46,-size.y*.5),Color("5a543d"),9,true)
	draw_line(Vector2(-size.x*.46,-size.y*.5-3),Vector2(size.x*.46,-size.y*.5-3),Color("b2a17a"),1.7,true)
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
