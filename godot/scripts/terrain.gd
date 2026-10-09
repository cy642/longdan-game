extends Node2D
## Ground is baked once for export; collision and navigation stay native.
const Scenery = preload("res://scripts/scenery.gd")
static var baking = false
var world
var definition: Dictionary
var rocks: Array = []
var trees: Array = []
var geometry: Array = []
var grid = AStarGrid2D.new()
var grain: Array = []
var pools: Array = []
var ground_color = Color("9baa88")
var road_color = Color("c5b27f")
var ground_texture: Texture2D
var banks: Array = []

func build(data: Dictionary) -> void:
	definition = data
	var baked_path = "res://assets/maps/"+world.stage+".png"
	if not baking and ResourceLoader.exists(baked_path): ground_texture=load(baked_path)
	var random = RandomNumberGenerator.new(); random.seed = int(data.seed)
	ground_color = {"forest":Color("7e9877"),"village":Color("a0a383"),"temple":Color("809082"),"house":Color("91a180"),"camp":Color("a09b78"),"river":Color("7b9b8b")}[data.mood]
	road_color = Color("c1ac7c") if data.mood != "temple" else Color("a6afa0")
	for h in data.huts:
		var d = {"kind": h[4], "w":h[2], "h":h[3]}
		place_scenery(Vector2(h[0],h[1]),d)
		add_rect(Rect2(h[0]-h[2]/2.0,h[1]-h[3]/2.0+15,h[2],h[3]-15))
	for _i in range(170):
		var p = Vector2(random.randf_range(45,1555),random.randf_range(65,1040))
		if road_distance(p) < 110 or near_interest(p,145) or in_arena(p,90) or (world.stage == "bridge" and p.y < 310): continue
		var d = {"kind":"tree", "size":random.randf_range(25,44),"variant":random.randf(),"seed":random.randi()}
		trees.append({"pos":p,"size":d.size}); place_scenery(p,d)
	for _i in range(26):
		var p = Vector2(random.randf_range(85,1515),random.randf_range(90,1010))
		if road_distance(p) < 83 or near_interest(p,120) or in_arena(p,50) or (world.stage == "bridge" and p.y < 310): continue
		var r = random.randf_range(12,24); rocks.append({"pos":p,"r":r})
		place_scenery(p,{"kind":"rock","size":r}); add_circle(p,r*.7)
	if ground_texture==null:
		for _i in range(6200):
			var p = Vector2(random.randf()*1600,random.randf()*1100)
			grain.append({"pos":p,"distance":road_distance(p),"size":random.randf_range(2,7),"light":random.randf(),"flower":random.randf()<.022})
		for _i in range(220):
			pools.append({"pos":Vector2(random.randf()*1600,random.randf()*1100),"r":random.randf_range(25,120),"light":random.randf()})
		for road in definition.roads:
			for i in range(1,road.size()):
				var a=Vector2(road[i-1][0],road[i-1][1]); var b=Vector2(road[i][0],road[i][1]); var normal=(b-a).normalized().orthogonal()
				for step in range(int(a.distance_to(b)/13)+1):
					var p=a.lerp(b,float(step)/maxi(1,int(a.distance_to(b)/13)))
					for side in [-1,1]: banks.append({"pos":p+normal*side*random.randf_range(42,56),"r":random.randf_range(3,9),"color":random.randf(),"dir":normal*side})
	add_rect(Rect2(-100,-100,1800,130)); add_rect(Rect2(-100,1070,1800,130))
	add_rect(Rect2(-100,0,120,1100)); add_rect(Rect2(1580,0,120,1100))
	if world.stage == "bridge":
		add_rect(Rect2(0,0,1170,285)); add_rect(Rect2(1370,0,230,285))
		if not world.state.flags.supplies: add_rect(Rect2(1070,725,80,375))
	for prop in world.props:
		var p = Vector2(prop.x,prop.y)
		var graphic = place_scenery(p,{"kind":"oil","prop":prop})
		prop.graphic = graphic
		if not prop.spent:
			prop.body = add_circle(p,prop.r)
	build_grid()
	queue_redraw()

func place_scenery(p: Vector2, data: Dictionary):
	var item = Scenery.new(); item.position = p; item.data = data; world.actors.add_child(item)
	return item

func add_rect(rect: Rect2):
	var body = StaticBody2D.new(); body.collision_layer = 1; body.collision_mask = 0
	body.position = rect.get_center(); var shape = CollisionShape2D.new()
	var rectangle = RectangleShape2D.new(); rectangle.size = rect.size; shape.shape = rectangle
	body.add_child(shape); add_child(body); geometry.append({"rect":rect})
	return body

func add_circle(p: Vector2, radius: float):
	var body = StaticBody2D.new(); body.collision_layer = 1; body.collision_mask = 0; body.position = p
	var shape = CollisionShape2D.new(); var circle = CircleShape2D.new(); circle.radius = radius; shape.shape = circle
	body.add_child(shape); add_child(body)
	return body

func road_distance(p: Vector2) -> float:
	var best = INF
	for road in definition.roads:
		for i in range(1,road.size()):
			var a = Vector2(road[i-1][0],road[i-1][1]); var b = Vector2(road[i][0],road[i][1])
			best = minf(best,p.distance_to(Geometry2D.get_closest_point_to_segment(p,a,b)))
	return best

func near_interest(p: Vector2, radius: float) -> bool:
	for obj in definition.objects:
		if p.distance_to(Vector2(obj.x,obj.y)) < radius: return true
	for hut in definition.huts:
		if p.distance_to(Vector2(hut[0],hut[1])) < radius: return true
	return false

func in_arena(p: Vector2, margin: float = 0) -> bool:
	if not definition.has("arena"): return false
	var a = definition.arena
	return absf(p.x-a.x)<a.rx+margin and absf(p.y-a.y)<a.ry+margin

func blocked(p: Vector2, radius: float = 14) -> bool:
	for g in geometry:
		if g.rect.grow(radius).has_point(p): return true
	for rock in rocks:
		if p.distance_to(rock.pos) < rock.r*.7+radius: return true
	for prop in world.props:
		if not prop.spent and p.distance_to(Vector2(prop.x,prop.y)) < prop.r+radius: return true
	return false

func line_clear(a: Vector2, b: Vector2, radius: float = 2) -> bool:
	var steps = maxi(1,int(ceil(a.distance_to(b)/12)))
	for i in range(steps+1):
		if blocked(a.lerp(b,float(i)/steps),radius): return false
	return true

func build_grid() -> void:
	grid.region = Rect2i(0,0,40,28); grid.cell_size = Vector2(40,40); grid.offset = Vector2(20,20)
	grid.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES; grid.update()
	for y in range(28):
		for x in range(40): grid.set_point_solid(Vector2i(x,y),blocked(Vector2(x*40+20,y*40+20),18))

func nearest_cell(p: Vector2) -> Vector2i:
	var origin = Vector2i(clampi(int(p.x/40),0,39),clampi(int(p.y/40),0,27))
	if not grid.is_point_solid(origin): return origin
	for distance in range(1,6):
		for y in range(-distance,distance+1):
			for x in range(-distance,distance+1):
				var cell = origin+Vector2i(x,y)
				if grid.is_in_boundsv(cell) and not grid.is_point_solid(cell): return cell
	return origin

func find_path(a: Vector2, b: Vector2, _radius: float) -> PackedVector2Array:
	return grid.get_point_path(nearest_cell(a),nearest_cell(b))

func stroke(points: PackedVector2Array, color: Color, width: float) -> void:
	draw_polyline(points,color,width,true)
	for p in points: draw_circle(p,width/2,color)

func _draw() -> void:
	if definition.is_empty(): return
	if ground_texture!=null:
		draw_texture(ground_texture,Vector2.ZERO)
		if world.stage=="bridge" and not world.state.flags.supplies: draw_blockade()
		return
	draw_rect(Rect2(0,0,1600,1100),ground_color)
	for pool in pools:
		for i in range(4):
			draw_set_transform(pool.pos,0,Vector2(1,.62))
			draw_circle(Vector2.ZERO,pool.r*(1-i*.16),Color(.88,.86,.64,.019) if pool.light>.5 else Color(.1,.25,.18,.022))
	draw_set_transform(Vector2.ZERO)
	for tree in trees:
		draw_set_transform(tree.pos,0,Vector2(1,.5))
		draw_circle(Vector2.ZERO,tree.size*1.5,Color(.13,.31,.22,.07))
	draw_set_transform(Vector2.ZERO)
	for road in definition.roads:
		var points = PackedVector2Array()
		for p in road: points.append(Vector2(p[0],p[1]))
		stroke(points,Color(.22,.3,.19,.10),115)
		stroke(points,Color(.29,.32,.19,.16),103)
		stroke(points,road_color.darkened(.09),95)
		stroke(points,road_color,86); stroke(points,Color(.9,.82,.61,.18),58)
		stroke(points,Color(.95,.89,.69,.07),32)
		for offset in [-17,17]:
			var rut = PackedVector2Array()
			for p in points: rut.append(p+Vector2(offset,4))
			draw_polyline(rut,Color(.39,.33,.23,.12),2,true)
	for g in grain:
		var p = g.pos
		if world.stage == "bridge" and p.y<310: continue
		if g.distance<43:
			draw_set_transform(p,0,Vector2(1,.46))
			draw_circle(Vector2.ZERO,g.size*.3,Color(.42,.38,.26,.16))
			draw_circle(Vector2(-.4,-.6),g.size*.18,Color(.88,.83,.65,.25))
			draw_set_transform(Vector2.ZERO)
			if g.light>.88: draw_line(p,p+Vector2(g.size*2,1),Color(.47,.41,.26,.13),1,true)
		else:
			var c = Color(.23,.38,.24,.33) if g.light>.5 else Color(.72,.79,.53,.37)
			if g.light>.8:
				draw_set_transform(p,0,Vector2(1,.4)); draw_circle(Vector2.ZERO,g.size*.8,Color(.21,.36,.23,.12)); draw_set_transform(Vector2.ZERO)
			draw_polyline(PackedVector2Array([p+Vector2(-2,-g.size*.65),p,p+Vector2(2,-g.size)]),c,1,true)
			if g.flower: draw_circle(p+Vector2(0,-g.size),1.5,Color("e5dfad"))
	for bank in banks:
		draw_set_transform(bank.pos,0,Vector2(1,.48))
		draw_circle(Vector2.ZERO,bank.r,Color(.27,.36,.22,.24))
		draw_circle(Vector2(-1,-1),bank.r*.76,Color(.62,.67,.43,.42))
		draw_set_transform(Vector2.ZERO)
		for i in range(3): draw_line(bank.pos+Vector2(i*3-3,1),bank.pos+Vector2(i*3-4,-bank.r*(.7+i*.16)),Color(.43,.53,.31,.48),1.3,true)
	for tree in trees:
		for i in range(4):
			draw_set_transform(tree.pos+Vector2(12+i*4,8+i*2),0,Vector2(1,.43))
			draw_circle(Vector2.ZERO,tree.size*(1.15-i*.1),Color(.09,.23,.18,.024))
	draw_set_transform(Vector2.ZERO)
	for tree in trees:
		for i in range(11):
			var angle=i*2.4+tree.pos.x*.2; var p=tree.pos+Vector2(cos(angle)*tree.size*.75,sin(angle)*tree.size*.25)
			draw_colored_polygon(PackedVector2Array([p+Vector2(-3,0),p+Vector2(0,-2),p+Vector2(4,1),p+Vector2(0,2)]),Color(.72,.65,.35,.25) if i%3==0 else Color(.48,.6,.31,.23))
	for h in definition.huts:
		# Weathered foundations and moss connect structures to the ground.
		for i in range(4): draw_rect(Rect2(h[0]-h[2]/2.0-7-i*3,h[1]-h[3]/2.0-5-i*2,h[2]+14+i*6,h[3]+10+i*4),Color(.17,.29,.21,.022))
	if definition.mood == "temple":
		var arena = definition.arena
		for y in range(300,730,36):
			for x in range(610,1320,54):
				if Vector2(x,y).distance_to(Vector2(arena.x,arena.y)) > 365: continue
				draw_rect(Rect2(x+2,y+2,50,31),Color(.74,.77,.67,.45))
				draw_line(Vector2(x+8,y+15),Vector2(x+27,y+9),Color(.34,.42,.34,.2),1,true)
		draw_arc(Vector2(arena.x,arena.y),160,0,TAU,64,Color(.89,.86,.69,.26),2,true)
	if world.stage == "bridge":
		draw_rect(Rect2(0,30,1600,255),Color("356e70"))
		for y in range(32,285,3): draw_rect(Rect2(0,y,1600,3),Color(.19+y*.00016,.39+y*.00013,.4+y*.0002,1))
		for y in [34,271,277]: draw_line(Vector2(0,y),Vector2(1600,y),Color(.63,.77,.66,.25),3,true)
		for i in range(75):
			var p = Vector2(posmod(i*97,1600),45+posmod(i*31,225))
			draw_line(p,p+Vector2(22+i%40,0),Color(.73,.91,.86,.16),1,true)
		for i in range(36):
			var p=Vector2(posmod(i*137,1600),55+posmod(i*71,205))
			draw_arc(p,17+i%13,PI*.08,PI*.87,14,Color(.72,.84,.75,.11),1.2,true)
		draw_rect(Rect2(1165,35,210,270),Color("5a6048"))
		for y in range(40,305,13):
			draw_rect(Rect2(1173,y,194,10),Color("aa946c") if y%2 else Color("9a845f"))
			draw_line(Vector2(1178,y+2),Vector2(1358,y+2),Color(.89,.79,.57,.4),1,true)
		for x in [1168,1366]:
			draw_line(Vector2(x,35),Vector2(x,310),Color("435347"),7)
			for y in range(42,310,40): draw_rect(Rect2(x-5,y-10,11,20),Color("6d7053"))
		if not baking and not world.state.flags.supplies: draw_blockade()

func draw_blockade() -> void:
	# The east route changes with the story, so it stays outside the static bake.
	for y in range(740,1080,40):
		draw_line(Vector2(1070,y-10),Vector2(1150,y+10),Color("5b6249"),8,true)
		draw_line(Vector2(1070,y+10),Vector2(1150,y-10),Color("737859"),6,true)
