extends Control
## Ground and route geometry come from the live region, so both maps stay in sync.
const WORLD_SIZE = Vector2(1600,1100)
const INK = Color("18332f")
const PAPER = Color("d9d9bc")
const GOLD = Color("dcc58c")
const MINT = Color("a9d3be")
const LOCKED = Color("a69878")
var world
var large = false

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip_contents = true

func map_bounds() -> Rect2:
	var margin = 8.0 if large else 4.0
	var available = size-Vector2.ONE*margin*2
	if large: available -= Vector2(178,27)
	available = available.max(Vector2.ONE)
	var factor = minf(available.x/WORLD_SIZE.x,available.y/WORLD_SIZE.y)
	return Rect2(Vector2.ONE*margin+(available-WORLD_SIZE*factor)/2,WORLD_SIZE*factor)

func map_position(point: Vector2, bounds: Rect2, inset: float = 0.0) -> Vector2:
	var projected = bounds.position+point/WORLD_SIZE*bounds.size
	return projected.clamp(bounds.position+Vector2.ONE*inset,bounds.end-Vector2.ONE*inset)

func camera_bounds(bounds: Rect2) -> Rect2:
	# The camera is clamped at region edges; the hero is not its screen center.
	var visible_size: Vector2 = world.get_viewport_rect().size/world.camera.zoom
	var center: Vector2 = world.camera.get_screen_center_position()
	var visible_world = Rect2(center-visible_size/2,visible_size).intersection(Rect2(Vector2.ZERO,WORLD_SIZE))
	return Rect2(bounds.position+visible_world.position/WORLD_SIZE*bounds.size,visible_world.size/WORLD_SIZE*bounds.size)

func _draw() -> void:
	if not world or world.definition.is_empty(): return
	var bounds = map_bounds()
	var factor = bounds.size.x/WORLD_SIZE.x
	var texture: Texture2D = world.terrain.ground_texture if is_instance_valid(world.terrain) else null
	draw_rect(bounds,Color("344d3b"))
	if texture:
		draw_texture_rect(texture,bounds,false,Color(.77,.84,.76))
		draw_rect(bounds,Color(.07,.17,.15,.13))
	elif world.stage=="bridge":
		draw_rect(Rect2(map_position(Vector2(0,30),bounds),Vector2(1600,255)*factor),Color("406c71"))
		draw_rect(Rect2(map_position(Vector2(1170,30),bounds),Vector2(200,255)*factor),Color("a7956f"))

	var secondary = world.definition.get("secondary_roads",[])
	for road in world.definition.get("roads",[]):
		# Overlay loaders may also append the secondary paths to the full road set.
		if road not in secondary: draw_route(road,bounds,false)
	for road in secondary: draw_route(road,bounds,true)
	for hut in world.definition.get("huts",[]):
		if not hut is Array or hut.size()<4: continue
		var rect = Rect2(bounds.position+Vector2(hut[0]-hut[2]/2.0,hut[1]-hut[3]/2.0)*factor,Vector2(hut[2],hut[3])*factor)
		rect = rect.intersection(bounds)
		draw_rect(rect,Color("43584b")); draw_rect(rect,Color("8e9c7d"),false,.8)
	if world.stage=="bridge" and not world.state.flags.get("supplies",false):
		var barrier = Rect2(bounds.position+Vector2(1070,725)*factor,Vector2(80,375)*factor).intersection(bounds)
		draw_rect(barrier,Color(.41,.32,.23,.8))
		for y in range(int(barrier.position.y)+2,int(barrier.end.y),5):
			draw_line(Vector2(barrier.position.x,y),Vector2(barrier.end.x,y),Color("c0a275"),1,true)

	var view = camera_bounds(bounds)
	if view.has_area():
		draw_rect(view,Color(.72,.85,.75,.06))
		draw_rect(view,Color(.77,.91,.82,.48),false,1)
	var landmarks = map_landmarks()
	for index in range(landmarks.size()):
		var landmark = landmarks[index]
		var p = map_position(Vector2(landmark.x,landmark.y),bounds,7)
		draw_landmark(p,large)
		if large: draw_number(p+Vector2(11,9),String.chr(65+index),Color("b4bda0"),bounds)

	# Draw the objective under markers so its ring never strikes through a number.
	var target: Vector2 = world.mission().get("pos",world.hero.position)
	var target_p = map_position(target,bounds,14 if large else 8)
	var target_r = 10.0 if large else 5.0
	draw_arc(target_p,target_r,0,TAU,32,INK,3.8 if large else 2.8,true)
	draw_arc(target_p,target_r,0,TAU,32,GOLD,1.8 if large else 1.3,true)
	for angle in [0.0,PI*.5,PI,PI*1.5]:
		draw_line(target_p+Vector2.from_angle(angle)*(target_r+1),target_p+Vector2.from_angle(angle)*(target_r+3),GOLD,1,true)
	for enemy in world.enemies:
		if not enemy.body_alive(): continue
		var p = map_position(enemy.position,bounds,3)
		draw_circle(p,3.1 if large else 2.2,INK)
		draw_circle(p,2.1 if large else 1.3,Color("d29a7f"))
	var objects: Array = world.definition.get("objects",[])
	for index in range(objects.size()):
		var object: Dictionary = objects[index]
		var p = map_position(Vector2(object.get("x",0),object.get("y",0)),bounds,8 if large else 4)
		var info = object_info(object)
		draw_object(p,str(object.get("kind","")),info.blocked,info.complete,large)
		if large: draw_number(p+Vector2(11,-10),str(index+1),info.color,bounds)
	draw_player(map_position(world.hero.position,bounds,10 if large else 6))
	draw_rect(bounds,Color("849379"),false,1)
	if large:
		draw_map_key(bounds)
		draw_legend(objects,landmarks,bounds)

func route_points(road, bounds: Rect2) -> PackedVector2Array:
	var source = road.get("points",[]) if road is Dictionary else road
	var points = PackedVector2Array()
	if not source is Array: return points
	for point in source:
		if point is Array and point.size()>=2:
			points.append(map_position(Vector2(point[0],point[1]),bounds,1))
	return points

func draw_route(road, bounds: Rect2, secondary: bool) -> void:
	var points = route_points(road,bounds)
	if points.size()<2: return
	var width = (1.5 if large else .85) if secondary else (2.4 if large else 1.4)
	var color = Color("b1b390") if secondary else Color("d1be8e")
	draw_polyline(points,Color(.16,.25,.18,.52),width+1.8,true)
	if secondary:
		for index in range(1,points.size()):
			draw_dashed_line(points[index-1],points[index],color,width,4 if large else 2,true,true)
	else: draw_polyline(points,color,width,true)

func object_info(object: Dictionary) -> Dictionary:
	var kind = str(object.get("kind",""))
	var id = str(object.get("id",""))
	var blocked: bool = world.object_blocked(object)
	var completion_flag = {"civilians":"civilians","adou":"mother","supplies":"supplies","xiahouGate":"temple","zhangheGate":"boss","hs_huangzhong":"huangzhong","hs_zhangzhu":"wounded","hs_beacon":"beacon","hs_dujun":"dujun","jg_vanguard":"jg_boss","cc_warden":"cc_boss"}.get(id,"")
	if kind in ["jigu","chencang"]: completion_flag=str(object.get("task",""))
	var complete: bool = not completion_flag.is_empty() and world.state.flags.get(completion_flag,false)
	if completion_flag=="route_choice": complete=world.state.flags.get("cc_route_front",false) or world.state.flags.get("cc_route_flank",false)
	elif completion_flag=="bridge_choice": complete=world.state.flags.get("jg_bridge_cut",false) or world.state.flags.get("jg_bridge_held",false)
	var title = str(object.get("label","地标"))
	var status = "可交互"
	var color = Color("c8b891")
	match kind:
		"huangzhong","wounded","beacon","graincart","hideflag","gate","drum","hint","jigu","chencang":
			status="待完成" if blocked else "可交互"; color=MINT
		"exit","finish":
			status = "待开放" if blocked else "可通行"
			color = LOCKED if blocked else MINT
		"camp":
			status = "休整 · 补药"; color = GOLD
		"rescue":
			title = "医者与百姓"; status = "救援地点"; color = MINT
		"story":
			title = "井畔旧宅"; status = "可探访"; color = MINT
		"boss":
			title = "守将据点"; status = "守军驻守"; color = Color("c39b82")
		"supplies":
			title = "粮草营地"; status = "可探访"
	if complete: status = "已完成"; color = Color("879e87")
	elif blocked and kind not in ["exit","finish","camp"]: status = "守军驻守"
	return {"title":title,"status":status,"color":color,"blocked":blocked,"complete":complete}

func draw_object(p: Vector2, kind: String, blocked: bool, complete: bool, detailed: bool) -> void:
	var radius = 6.5 if detailed else 3.5
	var color = LOCKED if blocked else MINT
	if kind=="camp": color = GOLD
	elif kind=="boss": color = Color("c39b82")
	elif kind=="supplies": color = Color("c8b891")
	if complete: color = Color("879e87")
	draw_circle(p,radius+2,Color(.07,.16,.14,.9))
	var weight = 1.4 if detailed else 1.0
	match kind:
		"exit","finish":
			draw_rect(Rect2(p-Vector2.ONE*radius,Vector2.ONE*radius*2),color,false,weight)
			if blocked:
				draw_line(p+Vector2(-radius*.55,-radius*.55),p+Vector2(radius*.55,radius*.55),color,weight,true)
				draw_line(p+Vector2(radius*.55,-radius*.55),p+Vector2(-radius*.55,radius*.55),color,weight,true)
			else:
				draw_line(p-Vector2(radius*.65,0),p+Vector2(radius*.6,0),color,weight,true)
				draw_polyline(PackedVector2Array([p+Vector2(0,-radius*.6),p+Vector2(radius*.65,0),p+Vector2(0,radius*.6)]),color,weight,true)
		"camp":
			draw_colored_polygon(PackedVector2Array([p+Vector2(-radius,radius*.5),p+Vector2(-radius*.3,-radius*.45),p+Vector2(0,-radius),p+Vector2(radius*.7,0),p+Vector2(radius,radius*.5)]),color)
			draw_line(p+Vector2(-radius,radius),p+Vector2(radius,radius),color,weight,true)
		"rescue","story":
			draw_line(p-Vector2(radius,0),p+Vector2(radius,0),color,weight+1,true)
			draw_line(p-Vector2(0,radius),p+Vector2(0,radius),color,weight+1,true)
		"boss":
			var diamond = PackedVector2Array([p+Vector2(0,-radius),p+Vector2(radius,0),p+Vector2(0,radius),p-Vector2(radius,0),p-Vector2(0,radius)])
			draw_polyline(diamond,color,weight,true)
			draw_circle(p,1.4,color)
		"supplies":
			draw_rect(Rect2(p-Vector2.ONE*radius,Vector2.ONE*radius*2),color,false,weight)
			draw_line(p-Vector2(0,radius),p+Vector2(0,radius),color,weight,true)
		_:
			draw_circle(p,radius*.65,color)
	if complete and detailed:
		draw_polyline(PackedVector2Array([p+Vector2(-4,1),p+Vector2(-1,4),p+Vector2(5,-3)]),PAPER,1.7,true)

func draw_player(p: Vector2) -> void:
	var facing = Vector2.from_angle(world.hero.facing)
	var across = facing.orthogonal()
	var r = 7.5 if large else 4.2
	draw_circle(p,r+2,INK)
	var arrow = PackedVector2Array([p+facing*r,p-facing*r*.65+across*r*.65,p-facing*r*.3,p-facing*r*.65-across*r*.65])
	draw_colored_polygon(arrow,Color("c9ede0"))
	if large: draw_line(p,p+facing*(r+3),Color("eff9ee"),1,true)

func map_landmarks() -> Array:
	# Only explicitly published cartographic labels are included; no story data is read.
	var entries: Array = []
	for entry in world.definition.get("landmarks",[]):
		if not entry is Dictionary or not entry.has("x") or not entry.has("y"): continue
		var label = str(entry.get("map_label",entry.get("label","")))
		if label.is_empty() or entry.get("hidden",false): continue
		if entry.has("need") and not world.state.flags.get(entry.need,false): continue
		entries.append({"x":entry.x,"y":entry.y,"label":label})
		if entries.size()==3: break
	return entries

func draw_landmark(p: Vector2, detailed: bool) -> void:
	var r = 4.0 if detailed else 2.0
	draw_circle(p,r+1.5,INK)
	draw_polyline(PackedVector2Array([p+Vector2(0,-r),p+Vector2(r,0),p+Vector2(0,r),p-Vector2(r,0),p-Vector2(0,r)]),Color("b4bda0"),1,true)

func map_font() -> Font:
	return world.ui.font if world.ui and world.ui.font else ThemeDB.fallback_font

func fit_text(value: String, width: float, font_size: int) -> String:
	var font = map_font()
	if font.get_string_size(value,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size).x<=width: return value
	while not value.is_empty() and font.get_string_size(value+"…",HORIZONTAL_ALIGNMENT_LEFT,-1,font_size).x>width:
		value = value.left(-1)
	return value+"…"

func draw_number(p: Vector2, value: String, color: Color, bounds: Rect2) -> void:
	p = p.clamp(bounds.position+Vector2(8,8),bounds.end-Vector2(8,8))
	draw_circle(p,7.3,INK)
	var width = map_font().get_string_size(value,HORIZONTAL_ALIGNMENT_LEFT,-1,10).x
	draw_string(map_font(),p+Vector2(-width/2,3.5),value,HORIZONTAL_ALIGNMENT_LEFT,-1,10,color)

func draw_map_key(bounds: Rect2) -> void:
	var y = minf(size.y-11,bounds.end.y+20)
	var x = bounds.position.x
	draw_line(Vector2(x,y-4),Vector2(x+20,y-4),Color("d1be8e"),2.4,true)
	draw_string(map_font(),Vector2(x+26,y),"主路",HORIZONTAL_ALIGNMENT_LEFT,-1,11,PAPER)
	draw_dashed_line(Vector2(x+75,y-4),Vector2(x+95,y-4),Color("b1b390"),1.4,4,true,true)
	draw_string(map_font(),Vector2(x+101,y),"支路",HORIZONTAL_ALIGNMENT_LEFT,-1,11,PAPER)
	draw_string(map_font(),Vector2(bounds.end.x-53,y),"北 ↑",HORIZONTAL_ALIGNMENT_LEFT,-1,11,Color("b7c9b0"))

func draw_legend(objects: Array, landmarks: Array, bounds: Rect2) -> void:
	var left = bounds.end.x+16
	var width = maxf(1,size.x-left-7)
	draw_line(Vector2(left-8,8),Vector2(left-8,size.y-8),Color("496153"),1,true)
	draw_string(map_font(),Vector2(left,22),"行军地标",HORIZONTAL_ALIGNMENT_LEFT,width,13,GOLD)
	var count = objects.size()+landmarks.size()
	var row = minf(37,maxf(24,(size.y-83)/maxi(1,count)))
	var y = 47.0
	for index in range(objects.size()):
		var info = object_info(objects[index])
		draw_number(Vector2(left+7,y-3),str(index+1),info.color,Rect2(Vector2(left-1,0),Vector2(width,size.y)))
		draw_string(map_font(),Vector2(left+22,y),fit_text(info.title,width-22,12),HORIZONTAL_ALIGNMENT_LEFT,width-22,12,PAPER)
		draw_string(map_font(),Vector2(left+22,y+14),fit_text(info.status,width-22,11),HORIZONTAL_ALIGNMENT_LEFT,width-22,11,info.color)
		y += row
	for index in range(landmarks.size()):
		draw_number(Vector2(left+7,y-3),String.chr(65+index),Color("b4bda0"),Rect2(Vector2(left-1,0),Vector2(width,size.y)))
		draw_string(map_font(),Vector2(left+22,y),fit_text(landmarks[index].label,width-22,12),HORIZONTAL_ALIGNMENT_LEFT,width-22,12,PAPER)
		y += row
	var key_y = size.y-32
	draw_arc(Vector2(left+7,key_y-4),5,0,TAU,20,GOLD,1.4,true)
	draw_string(map_font(),Vector2(left+21,key_y),"当前目标",HORIZONTAL_ALIGNMENT_LEFT,width-21,11,PAPER)
	draw_circle(Vector2(left+7,key_y+14),2.4,Color("d29a7f"))
	draw_string(map_font(),Vector2(left+21,key_y+18),"敌军",HORIZONTAL_ALIGNMENT_LEFT,width-21,11,PAPER)
