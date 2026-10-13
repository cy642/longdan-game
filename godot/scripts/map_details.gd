extends Node2D
## Editable map art. Ground is baked; upright landmarks keep their own Y-sort anchor.
## The JSON contains only local additions; chapter1.json remains the campaign source.
const DATA_PATH = "res://data/map_details.json"
static var layout_cache: Dictionary = {}
static var prop_frames: Dictionary = {}
var rendered_prop: Sprite2D
var definition: Dictionary = {}
var stage: String = ""
var layer: String = "ground"
var landmark: Dictionary = {}
var world
var breeze_clock = 0.0
var redraw_left = 0.0

static func apply_layout(source: Dictionary, stage_id: String) -> Dictionary:
	if layout_cache.is_empty():
		var parsed = JSON.parse_string(FileAccess.get_file_as_string(DATA_PATH))
		if parsed is Dictionary: layout_cache = parsed.get("stages", {})
	var result = source.duplicate(true)
	# Calling twice must never duplicate roads or colliders during scene re-entry.
	if result.has("map_details"): return result
	var details: Dictionary = layout_cache.get(stage_id, {}).duplicate(true)
	result["map_details"] = details
	result["secondary_roads"] = details.get("secondary_roads", []).duplicate(true)
	for road in details.get("roads", []): result.roads.append(road.duplicate(true))
	for road in result.secondary_roads: result.roads.append(road.duplicate(true))
	details["solids"] = []
	for item in details.get("landmarks", []):
		var anchor = Vector2(item.position[0], item.position[1])
		for shape in item.get("colliders", []):
			if shape.has("rect"):
				var r = shape.rect
				details.solids.append({"rect":[anchor.x+r[0], anchor.y+r[1], r[2], r[3]], "landmark":item.id})
			elif shape.has("circle"):
				var c = shape.circle
				details.solids.append({"circle":[anchor.x+c[0], anchor.y+c[1], c[2]], "landmark":item.id})
	return result

static func near_clearing(point: Vector2, data: Dictionary, margin: float = 0) -> bool:
	var details: Dictionary = data.get("map_details", {})
	for area in details.get("clearings", []):
		var relative = (point-Vector2(area[0],area[1]))/Vector2(area[2]+margin,area[3]+margin)
		if relative.length_squared() < 1: return true
	for surface in details.get("surfaces", []):
		var points = _points(surface.polygon)
		if Geometry2D.is_point_in_polygon(point, points): return true
		if margin > 0:
			for i in range(points.size()):
				if point.distance_to(Geometry2D.get_closest_point_to_segment(point,points[i],points[(i+1)%points.size()])) < margin: return true
	for item in details.get("landmarks", []):
		if point.distance_to(Vector2(item.position[0],item.position[1])) < 62+margin: return true
	return false

static func attach_landmarks(parent: Node2D, data: Dictionary, stage_id: String) -> Array:
	var created: Array = []
	var script = load("res://scripts/map_details.gd")
	for item in data.get("map_details", {}).get("landmarks", []):
		var node = script.new()
		node.name = "Landmark_"+str(item.id)
		node.stage = stage_id; node.definition = data; node.layer = "landmark"; node.landmark = item
		node.position = Vector2(item.position[0], item.position[1])
		node.world = parent.get_parent()
		parent.add_child(node); created.append(node)
	return created

func _ready() -> void:
	if layer == "landmark": _attach_rendered_prop()
	set_process(layer == "landmark" and landmark.get("kind", "") == "banner")

func _attach_rendered_prop() -> void:
	var manifest_path = "res://assets/props/landmarks.json"
	if prop_frames.is_empty() and FileAccess.file_exists(manifest_path):
		var parsed = JSON.parse_string(FileAccess.get_file_as_string(manifest_path))
		if parsed is Dictionary: prop_frames = parsed.get("props", {})
	var kind: String = landmark.get("kind", "")
	if not prop_frames.has(kind): return
	var frame: Dictionary = prop_frames[kind]
	if not ResourceLoader.exists(frame.image): return
	rendered_prop = Sprite2D.new()
	rendered_prop.name = "BlenderLandmark"
	rendered_prop.centered = false
	rendered_prop.texture = load(frame.image)
	rendered_prop.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	rendered_prop.scale = Vector2.ONE * float(frame.scale)
	rendered_prop.position = Vector2(frame.draw_offset[0],frame.draw_offset[1])
	add_child(rendered_prop)

func _process(delta: float) -> void:
	if not is_instance_valid(world) or world.mode != "playing": return
	breeze_clock += delta
	redraw_left -= delta
	if redraw_left <= 0:
		redraw_left = 1.0 / 24.0
		var extent: Vector2 = world.get_viewport_rect().size / world.camera.zoom
		var visible_area = Rect2(world.camera.get_screen_center_position()-extent*.5,extent).grow(140)
		if visible_area.has_point(position): queue_redraw()

func _flag_point(p: Vector2) -> Vector2:
	# The mast edge stays pinned. Only the cloth's free edge follows the breeze.
	var freedom = clampf((p.x-3.0)/40.0,0.0,1.0)
	return p+Vector2(sin(breeze_clock*1.7+position.x*.01+p.y*.07)*1.3, sin(breeze_clock*2.0+position.x*.01+p.x*.08)*3.6)*freedom

func _flag_poly(points: Array, color: Color) -> void:
	var cloth = PackedVector2Array()
	for p in points: cloth.append(_flag_point(Vector2(p[0],p[1])))
	draw_colored_polygon(cloth,color)

static func _points(values: Array) -> PackedVector2Array:
	var result = PackedVector2Array()
	for p in values: result.append(Vector2(p[0], p[1]))
	return result

func _draw() -> void:
	if layer == "landmark":
		if not landmark.is_empty() and rendered_prop == null: _draw_landmark()
		return
	if definition.is_empty(): return
	var details: Dictionary = definition.get("map_details", {})
	if stage == "mountain": _mountain_shelves()
	if stage == "bridge": _shoreline()
	for surface in details.get("surfaces", []): _surface(surface)
	_worn_paths(details)
	for step in details.get("steps", []): _stairs(step)
	match stage:
		"village":
			_woven_mat(Vector2(294,465),Vector2(43,24),Color("a9a684"))
			_woven_mat(Vector2(356,468),Vector2(34,23),Color("b5ac83"))
		"temple": _temple_inlay()
		"house":
			_well_court()
			_woven_mat(Vector2(1157,539),Vector2(46,21),Color("b6a785"))
		"fork": _camp_tracks()
		"mountain": _camp_platform()

func _poly(points: Array, color: Color) -> void:
	draw_colored_polygon(_points(points), color)

func _oval(center: Vector2, radius: float, squash: float, color: Color) -> void:
	draw_set_transform(center,0,Vector2(1,squash)); draw_circle(Vector2.ZERO,radius,color); draw_set_transform(Vector2.ZERO)

func _surface(surface: Dictionary) -> void:
	var points = _points(surface.polygon)
	var tone = {"stone":Color("a8ac92"),"flagstone":Color("9fa999"),"cobbles":Color("b5b496"),"earth":Color("b2a475"),"gravel":Color("b8b18c")}.get(surface.kind,Color("b2a475"))
	var closed = points.duplicate(); closed.append(points[0])
	draw_polyline(closed,Color(.25,.36,.26,.15),14,true)
	draw_colored_polygon(points,tone)
	draw_polyline(closed,tone.lightened(.1),2,true)
	var bounds = Rect2(points[0],Vector2.ZERO)
	for p in points: bounds = bounds.expand(p)
	var paving = surface.kind in ["stone","flagstone","cobbles"]
	var tile_size = Vector2(46,29) if surface.kind == "flagstone" else Vector2(31,21)
	if paving:
		for row in range(int(bounds.position.y/tile_size.y)-1,int(bounds.end.y/tile_size.y)+1):
			for column in range(int(bounds.position.x/tile_size.x)-1,int(bounds.end.x/tile_size.x)+1):
				var p = Vector2(column*tile_size.x+(row%2)*tile_size.x*.5,row*tile_size.y)
				var size = tile_size-Vector2(4,4)
				if not _inside_tile(p,size,points): continue
				var variation = posmod(column*17+row*31,11)
				var color = tone.lightened(.015+variation*.008) if variation%3 else tone.darkened(.035)
				var bevel = PackedVector2Array([p+Vector2(3,0),p+Vector2(size.x-2,0),p+Vector2(size.x,3),p+Vector2(size.x-1,size.y-2),p+Vector2(3,size.y),p+Vector2(0,size.y-3)])
				draw_colored_polygon(bevel,color)
				draw_line(p+Vector2(4,1),p+Vector2(size.x-4,1),Color(.83,.84,.68,.24),1,true)
				draw_line(p+Vector2(3,size.y),p+Vector2(size.x-3,size.y),Color(.26,.38,.29,.15),1,true)
				if variation == 4 or variation == 9:
					draw_polyline(PackedVector2Array([p+Vector2(size.x*.4,1),p+Vector2(size.x*.51,size.y*.45),p+Vector2(size.x*.37,size.y-2)]),Color(.31,.40,.32,.26),1,true)
				if variation == 6:
					draw_line(p+Vector2(2,3),p+Vector2(2,size.y-3),Color(.32,.48,.33,.4),2,true)
	else:
		for y in range(int(bounds.position.y),int(bounds.end.y),13):
			for x in range(int(bounds.position.x),int(bounds.end.x),19):
				var p = Vector2(x+posmod(y*13+x,13),y+posmod(x*17+y,8))
				if not Geometry2D.is_point_in_polygon(p,points): continue
				var hash_value = posmod(x*31+y*17,23)
				if hash_value < 11:
					draw_line(p,p+Vector2(4+hash_value*.6,-1),tone.darkened(.12)*Color(1,1,1,.45),1,true)
				else:
					_poly([[p.x-2,p.y],[p.x,p.y-2],[p.x+4,p.y],[p.x+1,p.y+1]],tone.lightened(.10))
	# Moss and chipped joints around the perimeter visually seat the plaza in grass.
	for i in range(points.size()):
		var a = points[i]; var b = points[(i+1)%points.size()]
		var count = maxi(1,int(a.distance_to(b)/23))
		for n in range(count):
			var p = a.lerp(b,(n+.35)/count)
			var tangent = (b-a).normalized()
			draw_line(p-tangent*5,p+tangent*4,Color(.35,.47,.31,.43),2,true)

func _inside_tile(p: Vector2, size: Vector2, polygon: PackedVector2Array) -> bool:
	for corner in [p,p+Vector2(size.x,0),p+size,p+Vector2(0,size.y)]:
		if not Geometry2D.is_point_in_polygon(corner,polygon): return false
	return true

func _worn_paths(details: Dictionary) -> void:
	# Preserve the route through clearings; stone forecourts become worn paving.
	for surface in details.get("surfaces", []):
		var polygon = _points(surface.polygon)
		for road in definition.roads:
			for i in range(1,road.size()):
				var a = Vector2(road[i-1][0],road[i-1][1]); var b = Vector2(road[i][0],road[i][1])
				var count = maxi(1,int(a.distance_to(b)/9))
				var run = PackedVector2Array()
				for n in range(count):
					var p = a.lerp(b,float(n)/count); var next = a.lerp(b,float(n+1)/count)
					if Geometry2D.is_point_in_polygon(p,polygon) and Geometry2D.is_point_in_polygon(next,polygon):
						if run.is_empty(): run.append(p)
						run.append(next)
					else:
						_worn_path_run(run,surface.kind); run = PackedVector2Array()
				_worn_path_run(run,surface.kind)
	# Secondary routes have a sparse line of flat waystones, not another barrier.
	for road in details.get("secondary_roads", []):
		if stage not in ["temple","mountain","bridge"]: continue
		for i in range(1,road.size()):
			var a = Vector2(road[i-1][0],road[i-1][1]); var b = Vector2(road[i][0],road[i][1])
			var count = int(a.distance_to(b)/43)
			for n in range(1,count):
				var p = a.lerp(b,float(n)/count)
				draw_set_transform(p,(b-a).angle()+PI/2)
				_poly([[-17,-4],[14,-6],[19,1],[13,6],[-16,5],[-20,1]],Color(.68,.71,.59,.53))
				draw_line(Vector2(-12,-3),Vector2(11,-4),Color(.86,.84,.67,.45),1,true)
				draw_set_transform(Vector2.ZERO)

func _worn_path_run(points: PackedVector2Array, kind: String) -> void:
	if points.size() < 2: return
	var opacity = .045 if kind in ["stone","flagstone","cobbles"] else .13
	draw_polyline(points,Color(.94,.87,.67,opacity),38,true)
	if kind in ["earth","gravel"]:
		var normal = (points[-1]-points[0]).normalized().orthogonal()*15
		for side in [-1,1]:
			var rut = PackedVector2Array()
			for p in points: rut.append(p+normal*side)
			draw_polyline(rut,Color(.40,.35,.22,.10),2,true)

func _stairs(step: Dictionary) -> void:
	var center = Vector2(step.position[0],step.position[1])
	var forward = Vector2.from_angle(step.angle); var across = forward.orthogonal()
	var width = float(step.width); var count = int(step.count)
	for i in range(count):
		var p = center+forward*(i-(count-1)*.5)*11
		var a = p-across*width*.5; var b = p+across*width*.5
		draw_line(a-forward*3,b-forward*3,Color("697d6c"),10,true)
		draw_line(a,b,Color("b6b9a0") if i%2 else Color("adb298"),8,true)
		draw_line(a+forward*3,b+forward*3,Color("d0ceb0"),1.5,true)
		for j in range(1,4):
			var seam = a.lerp(b,j/4.0+(.04 if i%2 else -.04))
			draw_line(seam-forward*3,seam+forward*3,Color(.31,.42,.34,.5),1,true)

func _mountain_shelves() -> void:
	var shelves = [
		[[60,175],[117,143],[201,159],[258,198],[246,251],[175,284],[91,263],[54,223]],
		[[362,312],[419,268],[502,278],[578,317],[564,371],[482,402],[399,378]],
		[[837,116],[895,85],[969,100],[1017,144],[993,189],[912,211],[849,170]]
	]
	for shelf in shelves:
		var polygon = _points(shelf)
		draw_colored_polygon(polygon,Color(.47,.57,.47,.54))
		var center = Vector2.ZERO
		for p in polygon: center += p
		center /= polygon.size()
		for band in range(4):
			var line = PackedVector2Array()
			for p in polygon: line.append(center+(p-center)*(1-band*.18))
			line.append(line[0]); draw_polyline(line,Color(.69,.73,.59,.21),2,true)
		for offset in [-27,18]:
			draw_polyline(PackedVector2Array([center+Vector2(-47,offset),center+Vector2(-9,offset-7),center+Vector2(7,offset+4),center+Vector2(48,offset-3)]),Color(.27,.39,.32,.25),2,true)

func _camp_platform() -> void:
	# Open front edge and broad steps point toward the existing interactive fire.
	_poly([[1115,207],[1141,180],[1220,180],[1255,215],[1242,266],[1140,280],[1106,247]],Color(.74,.73,.59,.43))
	for a in range(0,4):
		var p = Vector2(1115+a*37,282-a*3)
		draw_line(p,p+Vector2(31,-2),Color("9fa88b"),7,true)
		draw_line(p+Vector2(0,-2),p+Vector2(31,-4),Color("c9c7a5"),2,true)
	for x in [1090,1300]:
		draw_line(Vector2(x,224),Vector2(x+8,257),Color(.31,.43,.32,.35),4,true)

func _temple_inlay() -> void:
	var center = Vector2(960,491)
	for radius in [102,85]:
		var shape = PackedVector2Array()
		for i in range(9): shape.append(center+Vector2.from_angle(i*TAU/8+PI/8)*Vector2(radius,radius*.65))
		draw_polyline(shape,Color(.34,.47,.38,.24),3,true)
		draw_polyline(shape,Color(.82,.82,.66,.23),1,true)
	for side in [-1,1]:
		draw_polyline(PackedVector2Array([center+Vector2(side*64,0),center+Vector2(side*23,-23),center+Vector2(0,0),center+Vector2(side*23,23),center+Vector2(side*64,0)]),Color(.71,.72,.53,.34),3,true)
	# Four old plinth outlines are engraved into the floor, entirely traversable.
	for x in [755,1172]:
		for y in [352,619]:
			draw_rect(Rect2(x-21,y-12,42,24),Color(.34,.44,.34,.15),false,2)
			draw_line(Vector2(x-18,y-7),Vector2(x+15,y-7),Color(.83,.82,.64,.3),2,true)

func _well_court() -> void:
	var p = Vector2(1070,472)
	var curb = PackedVector2Array([p+Vector2(-52,-15),p+Vector2(-26,-36),p+Vector2(29,-34),p+Vector2(54,-8),p+Vector2(45,26),p+Vector2(-34,33),p+Vector2(-52,-15)])
	draw_polyline(curb,Color("858f76"),8,true)
	draw_polyline(curb,Color("c0bfa0"),2,true)
	# A shallow water runnel identifies the well court without changing walkability.
	draw_polyline(PackedVector2Array([p+Vector2(38,17),p+Vector2(74,44),p+Vector2(116,48)]),Color(.28,.46,.39,.5),5,true)
	draw_polyline(PackedVector2Array([p+Vector2(38,17),p+Vector2(74,44),p+Vector2(116,48)]),Color(.66,.77,.64,.6),1,true)

func _camp_tracks() -> void:
	for offset in [-15,15]:
		var points = PackedVector2Array([Vector2(1192,783+offset),Vector2(1251,814+offset),Vector2(1326,832+offset)])
		draw_polyline(points,Color(.38,.32,.20,.22),3,true)
		for i in range(8):
			var p = Vector2(1210+i*14,794+offset+i*4)
			draw_line(p-Vector2(2,4),p+Vector2(2,4),Color(.42,.35,.22,.18),1,true)
	_woven_mat(Vector2(1300,879),Vector2(52,25),Color("a99a67"))

func _woven_mat(center: Vector2, size: Vector2, color: Color) -> void:
	draw_rect(Rect2(center-size*.5+Vector2(2,3),size),Color(.23,.31,.23,.17))
	draw_rect(Rect2(center-size*.5,size),color)
	for y in range(int(-size.y*.5+3),int(size.y*.5),4): draw_line(center+Vector2(-size.x*.5+2,y),center+Vector2(size.x*.5-2,y),color.darkened(.14),1,true)
	for x in [-1,1]: draw_line(center+Vector2(x*(size.x*.5-4),-size.y*.5),center+Vector2(x*(size.x*.5-4),size.y*.5),color.lightened(.18),2,true)

func _shoreline() -> void:
	for interval in [[25,1120],[1405,1575]]:
		var polygon = PackedVector2Array([Vector2(interval[0],286),Vector2(interval[1],286)])
		var lower = PackedVector2Array()
		for x in range(interval[0],interval[1]+1,25): lower.append(Vector2(x,312+sin(x*.021)*7+cos(x*.009)*5))
		lower.reverse(); polygon.append_array(lower)
		draw_colored_polygon(polygon,Color("a6ac85"))
		var edge = PackedVector2Array(); for x in range(interval[0],interval[1]+1,20): edge.append(Vector2(x,290+sin(x*.014)*2))
		draw_polyline(edge,Color("d1cf9f"),3,true)
		draw_polyline(edge,Color(.78,.88,.70,.3),8,true)
		for x in range(interval[0]+9,interval[1]-10,29):
			var y = 303+posmod(x*17,12)
			_poly([[x-5,y],[x-2,y-4],[x+6,y-3],[x+8,y+1],[x+1,y+3]],Color("7e9279"))
			draw_line(Vector2(x-2,y-3),Vector2(x+4,y-3),Color("c6c8a0"),1,true)
		for x in range(interval[0]+20,interval[1]-20,74):
			var base = Vector2(x,301+sin(x*.02)*5)
			for j in range(5):
				var tip = base+Vector2((j-2)*5,-18-posmod(j*7+x,18))
				draw_line(base+Vector2((j-2)*2,0),tip,Color("637d58"),1.4,true)
				if j%2: draw_line(tip,tip+Vector2(1,-6),Color("a18f60"),3,true)

func _draw_landmark() -> void:
	match landmark.kind:
		"gateway": _gateway()
		"cairn": _cairn()
		"stela": _stela()
		"banner": _banner()
		"waypost","double_waypost": _waypost()
		"aid_awning": _aid_awning()
		"altar": _altar()
		"well_hoist": _well_hoist()
		"lantern": _lantern()
		"grain_rack": _grain_rack()
		"mooring": _mooring()

func _shadow(width: float, squash: float = .26) -> void:
	_oval(Vector2(9,5),width,squash,Color(.12,.25,.21,.20))

func _stone_block(center: Vector2, size: Vector2, color: Color) -> void:
	draw_rect(Rect2(center-Vector2(size.x*.5,size.y),size),color)
	_poly([[center.x-size.x*.5,center.y-size.y],[center.x-size.x*.5+5,center.y-size.y-5],[center.x+size.x*.5+5,center.y-size.y-5],[center.x+size.x*.5,center.y-size.y]],color.lightened(.15))
	_poly([[center.x+size.x*.5,center.y],[center.x+size.x*.5+5,center.y-5],[center.x+size.x*.5+5,center.y-size.y-5],[center.x+size.x*.5,center.y-size.y]],color.darkened(.14))

func _gateway() -> void:
	var half = float(landmark.get("span",152))*.5
	var tone = Color(landmark.get("tone","648379"))
	var broken = bool(landmark.get("broken",false))
	for side in [-1,1]:
		var x = side*half
		_oval(Vector2(x+6,6),20,.31,Color(.12,.25,.21,.18))
		_stone_block(Vector2(x,3),Vector2(22,13),Color("969f83"))
		draw_line(Vector2(x,-8),Vector2(x,-86),Color("3e574a"),12,true)
		draw_line(Vector2(x-2,-10),Vector2(x-2,-87),Color("8d9170"),4,true)
		_stone_block(Vector2(x,-69),Vector2(26,9),Color("9ea184"))
		draw_line(Vector2(x,-68),Vector2(x-side*24,-82),Color("69745a"),6,true)
	if broken:
		_poly([[-half-20,-82],[-half-18,-94],[-5,-92],[-14,-83]],tone.darkened(.18))
		_poly([[20,-88],[half+16,-97],[half+25,-81],[26,-80]],tone)
		_poly([[-half-26,-92],[-half-16,-109],[-13,-108],[-20,-95]],tone)
		draw_line(Vector2(-half-18,-108),Vector2(-18,-107),tone.lightened(.27),2,true)
	else:
		draw_rect(Rect2(-half-15,-89,half*2+30,12),Color("536d5b"))
		_poly([[-half-30,-89],[-half-17,-106],[0,-121],[half+17,-106],[half+30,-89],[0,-96]],tone.darkened(.17))
		_poly([[-half-27,-93],[-half-16,-108],[0,-120],[half+17,-105],[half+27,-93],[0,-100]],tone)
		for i in range(14):
			var x = -half-16+i*(half*2+32)/13
			draw_line(Vector2(x,-96-absf(x)/half*6),Vector2(x*.83,-114+absf(x)*.065),tone.lightened(.28),1.3,true)
		draw_polyline(PackedVector2Array([Vector2(-half-29,-92),Vector2(0,-98),Vector2(half+28,-92)]),Color("36574b"),3,true)
		_stone_block(Vector2(0,-64),Vector2(38,18),Color("a6a581"))
		draw_line(Vector2(-12,-75),Vector2(11,-75),Color("536f5b"),2,true)
		draw_line(Vector2(-6,-70),Vector2(7,-70),Color("536f5b"),2,true)

func _cairn() -> void:
	_shadow(30)
	_poly([[-23,3],[-25,-10],[-8,-20],[13,-19],[25,-6],[16,7]],Color("738675"))
	_poly([[-25,-10],[-8,-20],[13,-19],[5,-4],[-12,0]],Color("b4baa0"))
	_poly([[-17,-16],[-12,-31],[4,-37],[20,-26],[13,-15],[0,-11]],Color("839583"))
	_poly([[-17,-16],[-12,-31],[4,-37],[7,-25]],Color("c2c4a6"))
	_poly([[-7,-34],[-5,-55],[4,-67],[14,-53],[10,-35]],Color("7e9181"))
	_poly([[-7,-34],[-5,-55],[4,-67],[3,-40]],Color("c4c7aa"))
	draw_line(Vector2(-8,-24),Vector2(13,-21),Color("9b8060"),3,true)
	draw_line(Vector2(9,-22),Vector2(22,-38),Color("a5885e"),2,true)
	_poly([[20,-39],[36,-42],[34,-29],[22,-27]],Color("b49a66"))

func _stela() -> void:
	_shadow(29)
	_stone_block(Vector2(0,5),Vector2(45,12),Color("819782"))
	_poly([[-18,-8],[-17,-55],[-8,-65],[14,-61],[20,-52],[17,-8]],Color("839d88"))
	_poly([[-18,-8],[-17,-55],[-8,-65],[-9,-17]],Color("b7bda0"))
	draw_polyline(PackedVector2Array([Vector2(-8,-56),Vector2(9,-54),Vector2(12,-18),Vector2(-7,-19),Vector2(-8,-56)]),Color("627e6b"),1.5,true)
	for y in [-46,-39,-32]:
		draw_line(Vector2(-3,y),Vector2(7,y+1),Color("486b58"),2,true)
	draw_line(Vector2(7,-54),Vector2(1,-43),Color("b4b89a"),1,true)
	draw_polyline(PackedVector2Array([Vector2(-19,-4),Vector2(-14,-20),Vector2(-17,-30)]),Color("53754f"),2,true)

func _banner() -> void:
	_shadow(20)
	var tone = Color(landmark.get("tone","679083"))
	_stone_block(Vector2(0,4),Vector2(18,11),Color("89997e"))
	draw_line(Vector2(0,-6),Vector2(0,-111),Color("415e4f"),5,true)
	draw_line(Vector2(-1,-10),Vector2(-1,-107),Color("a3a581"),1.5,true)
	draw_line(Vector2(-5,-107),Vector2(47,-104),Color("546954"),4,true)
	_flag_poly([[3,-103],[43,-100],[40,-55],[28,-63],[17,-50],[4,-57]],tone)
	_flag_poly([[3,-103],[12,-101],[13,-57],[4,-57]],tone.lightened(.22))
	draw_line(_flag_point(Vector2(12,-92)),_flag_point(Vector2(33,-90)),Color("d6cc98"),2,true)
	_flag_poly([[19,-84],[25,-88],[31,-78],[25,-69],[20,-75]],Color("d3c694"))
	draw_line(Vector2(5,-105),Vector2(-19,-7),Color(.50,.53,.37,.65),1,true)
	draw_circle(Vector2(0,-113),3,Color("c4b383"))

func _waypost() -> void:
	_shadow(17)
	draw_line(Vector2(0,3),Vector2(1,-67),Color("53694e"),7,true)
	draw_line(Vector2(-2,1),Vector2(-1,-66),Color("a19d72"),2,true)
	var direction = int(landmark.get("direction",1))
	for row in range(2 if landmark.kind == "double_waypost" else 1):
		var side = direction if row == 0 else -1
		var y = -55+row*23
		_poly([[-26*side,y-8],[23*side,y-8],[35*side,y],[23*side,y+8],[-26*side,y+8]],Color("a5a079") if row==0 else Color("8e9b76"))
		draw_line(Vector2(-19*side,y-5),Vector2(23*side,y-5),Color("cec39a"),1.5,true)
		draw_line(Vector2(-15*side,y+2),Vector2(16*side,y+2),Color("647658"),2,true)
		draw_polyline(PackedVector2Array([Vector2(12*side,y-3),Vector2(18*side,y+2),Vector2(12*side,y+6)]),Color("647658"),2,true)

func _aid_awning() -> void:
	_shadow(55)
	for x in [-37,37]:
		draw_line(Vector2(x,2),Vector2(x,-69),Color("656d4e"),5,true)
		draw_line(Vector2(x-1,0),Vector2(x-1,-69),Color("b2ab7d"),1.5,true)
	_stone_block(Vector2(0,-3),Vector2(59,16),Color("908762"))
	_poly([[-34,-22],[26,-22],[31,-8],[-28,-8]],Color("cec6a4"))
	for x in [-18,7,22]: draw_line(Vector2(x,-21),Vector2(x+3,-9),Color("b6b194"),1,true)
	_poly([[-48,-50],[-33,-77],[14,-83],[48,-51],[32,-44],[-28,-45]],Color("929b75"))
	_poly([[-48,-50],[-33,-77],[14,-83],[7,-56]],Color("c2ba90"))
	_poly([[7,-56],[14,-83],[48,-51],[32,-44]],Color("9d9f78"))
	draw_polyline(PackedVector2Array([Vector2(-48,-50),Vector2(-30,-46),Vector2(-15,-51),Vector2(6,-47),Vector2(23,-51),Vector2(32,-44),Vector2(48,-51)]),Color("677a58"),3,true)
	# Folded cloth and a small medicine chest sit on the sheltered cot.
	draw_rect(Rect2(-24,-34,25,13),Color("bfc5a4")); draw_rect(Rect2(-22,-31,21,2),Color("849b7d"))
	draw_rect(Rect2(12,-37,19,17),Color("8e7453")); draw_rect(Rect2(10,-39,23,5),Color("b49f6d"))
	draw_line(Vector2(21,-34),Vector2(21,-25),Color("d8c68b"),2,true)

func _altar() -> void:
	_shadow(64)
	_stone_block(Vector2(0,9),Vector2(114,13),Color("778c7a"))
	_stone_block(Vector2(0,-4),Vector2(97,15),Color("b3b79b"))
	_stone_block(Vector2(0,-20),Vector2(79,22),Color("8fa28c"))
	_stone_block(Vector2(0,-43),Vector2(93,8),Color("c3c4a5"))
	_poly([[-26,-53],[-26,-83],[-17,-100],[15,-100],[26,-83],[26,-53]],Color("607f71"))
	_poly([[-19,-55],[-19,-83],[-11,-94],[12,-94],[20,-82],[20,-55]],Color("92a58d"))
	draw_polyline(PackedVector2Array([Vector2(0,-86),Vector2(-10,-72),Vector2(0,-60),Vector2(10,-72),Vector2(0,-86)]),Color("c3c6a1"),2,true)
	draw_line(Vector2(-27,-85),Vector2(-8,-71),Color("526e61"),2,true)
	for x in [-35,35]:
		_stone_block(Vector2(x,-48),Vector2(13,10),Color("8f8761"))
		draw_line(Vector2(x-2,-58),Vector2(x-2,-70),Color("c4ae7b"),1.5,true)
		draw_line(Vector2(x+3,-58),Vector2(x+3,-67),Color("c4ae7b"),1.5,true)
	for x in [-28,0,28]: draw_rect(Rect2(x-6,-34,12,10),Color("698571"),false,1.5)

func _well_hoist() -> void:
	# The campaign interaction already draws the stone well; add its working hoist.
	for x in [-30,47]:
		_stone_block(Vector2(x,1),Vector2(13,7),Color("8d987b"))
		draw_line(Vector2(x,-5),Vector2(x,-65),Color("665f48"),6,true)
		draw_line(Vector2(x-1,-7),Vector2(x-1,-65),Color("ad9c71"),2,true)
	draw_line(Vector2(-37,-65),Vector2(54,-65),Color("716b4d"),9,true)
	draw_line(Vector2(-37,-68),Vector2(54,-68),Color("bbaa7c"),2,true)
	draw_circle(Vector2(0,-59),7,Color("4c6552")); draw_circle(Vector2(0,-59),3,Color("b1a576"))
	draw_line(Vector2(0,-56),Vector2(0,-12),Color("c0ae7e"),1.5,true)
	draw_line(Vector2(4,-55),Vector2(23,-35),Color("a4996d"),1.5,true)
	_poly([[35,-2],[33,-19],[49,-19],[47,-2]],Color("9c8259"))
	_oval(Vector2(41,-19),8,.39,Color("cab686")); _oval(Vector2(41,-19),5,.33,Color("536f61"))
	draw_arc(Vector2(41,-20),6,PI,TAU,12,Color("7b7856"),1.5,true)

func _lantern() -> void:
	_shadow(19)
	_stone_block(Vector2(0,5),Vector2(19,11),Color("8b987b"))
	draw_line(Vector2(0,-7),Vector2(0,-87),Color("56674e"),6,true)
	draw_line(Vector2(0,-82),Vector2(28,-82),Color("7c7956"),5,true)
	draw_line(Vector2(25,-82),Vector2(25,-72),Color("c5b17a"),1,true)
	_poly([[16,-71],[33,-71],[36,-52],[32,-45],[17,-45],[13,-52]],Color("c2ad73"))
	_poly([[19,-68],[29,-68],[31,-48],[18,-48]],Color("e3ca89"))
	for y in [-69,-48]: draw_line(Vector2(15,y),Vector2(34,y),Color("778064"),2,true)
	draw_line(Vector2(25,-44),Vector2(25,-36),Color("a99763"),2,true)

func _grain_rack() -> void:
	_shadow(60)
	for x in [-45,45]:
		draw_line(Vector2(x,5),Vector2(x,-63),Color("615f46"),6,true)
		draw_line(Vector2(x,-56),Vector2(-x,-8),Color("867853"),3,true)
	draw_rect(Rect2(-49,-8,99,10),Color("7a6e4c"))
	for column in range(4):
		var x = -33+column*22
		_poly([[x-10,-10],[x-12,-34],[x-8,-42],[x+6,-43],[x+11,-34],[x+10,-10]],Color("b5a371") if column%2 else Color("c3b17c"))
		_poly([[x-9,-34],[x-7,-41],[x+5,-41],[x+9,-34]],Color("d3bf85"))
		draw_line(Vector2(x-10,-25),Vector2(x+9,-25),Color("91835b"),2,true)
		draw_line(Vector2(x,-42),Vector2(x+1,-13),Color(.88,.80,.54,.28),2,true)
	_poly([[-58,-57],[-47,-80],[1,-94],[48,-79],[59,-56],[9,-61]],Color("a69868"))
	_poly([[-58,-57],[-47,-80],[1,-94],[6,-62]],Color("c4b37e"))
	for i in range(18):
		var x = -51+i*6
		draw_line(Vector2(x,-59-absf(x)*.15),Vector2(x*.83,-82- (1-absf(x)/60)*8),Color(.85,.78,.53,.53),1.5,true)
	draw_line(Vector2(-59,-57),Vector2(6,-60),Color("877b55"),3,true)
	draw_line(Vector2(6,-60),Vector2(59,-56),Color("796d4b"),3,true)

func _mooring() -> void:
	_shadow(25)
	_stone_block(Vector2(0,6),Vector2(34,11),Color("80957f"))
	_stone_block(Vector2(0,-7),Vector2(23,29),Color("9dae94"))
	_stone_block(Vector2(0,-36),Vector2(30,8),Color("b6bea0"))
	draw_line(Vector2(-12,-20),Vector2(12,-20),Color("998d64"),3,true)
	draw_polyline(PackedVector2Array([Vector2(6,-19),Vector2(34,3),Vector2(48,4)]),Color("b6a272"),2,true)
	for r in [8,11,14]:
		draw_set_transform(Vector2(48,4),0,Vector2(1,.45)); draw_arc(Vector2.ZERO,r,0,TAU,20,Color("bba675"),1.5,true); draw_set_transform(Vector2.ZERO)
