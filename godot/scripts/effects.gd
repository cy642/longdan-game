extends Node2D
## Telegraphs reflect attack geometry; cosmetic effects never apply damage.
var world
var entries: Array = []
var labels: Array = []
var font: Font
var soft = false

func _ready() -> void:
	font = load("res://assets/fonts/NotoSansSC-Regular.otf")

func add(type: String, p: Vector2, duration: float, info: Dictionary = {}) -> void:
	entries.append({"type":type,"pos":p,"life":duration,"total":duration,"info":info})

func floater(p: Vector2, message: String, color: Color = Color("fff0bb")) -> void:
	labels.append({"pos":p+Vector2(0,-78),"text":message,"color":color,"life":.9})

func ghost(actor) -> void:
	if soft: return
	var body = actor.visual.body
	add("ghost",actor.position,.22,{"texture":body.texture,"offset":body.position,"scale":body.scale,"rotation":actor.visual.rotation})

func advance(dt: float) -> void:
	for e in entries: e.life -= dt
	entries = entries.filter(func(e): return e.life > 0)
	for label in labels:
		label.life -= dt; label.pos.y -= dt*25
	labels = labels.filter(func(label): return label.life>0)
	queue_redraw()

func sector(origin: Vector2, direction: float, radius: float, arc: float, color: Color) -> void:
	if arc >= PI-.001:
		draw_circle(origin,radius,color); return
	var points = PackedVector2Array([origin])
	for i in range(33): points.append(origin+Vector2.from_angle(direction-arc+2*arc*i/32)*radius)
	draw_colored_polygon(points,color)

func trail(p: Vector2, direction: float, radius: float, arc: float, color: Color, width: float) -> void:
	draw_arc(p,radius,direction-arc,direction+arc,48,color,width,true)

func swept_sector(p: Vector2,direction: float,radius: float,arc: float,travel: float,color: Color,edge: Color) -> void:
	var points=PackedVector2Array()
	for offset in [Vector2.ZERO,Vector2.from_angle(direction)*travel]:
		points.append(p+offset)
		for i in range(33): points.append(p+offset+Vector2.from_angle(direction-arc+2*arc*i/32)*radius)
	var hull=Geometry2D.convex_hull(points)
	draw_colored_polygon(hull,color); draw_polyline(hull,edge,1.5,true)

static func circle_telegraph(origin: Vector2,direction: float,definition: Dictionary) -> Dictionary:
	return {"center":origin+Vector2.from_angle(direction)*float(definition.get("hit_offset",0.0)),"radius":float(definition.get("hit_radius",0.0))}

func _draw() -> void:
	if not world or not is_instance_valid(world.hero): return
	if world.mode in ["playing","pause","map"]:
		for enemy in world.enemies:
			if not enemy.body_alive(): continue
			draw_enemy_status(enemy)
			if enemy.action.is_empty() or enemy.stun>0 or enemy.phase_time>0: continue
			var a = enemy.action; var d = a.def
			var second_bolt=enemy.kind=="crossbow" and int(a.get("shots_fired",0))<2 and a.t<d.windup+.29
			if a.t >= d.windup and not second_bolt: continue
			var progress = clampf(a.t/d.windup,0,1)
			var locked = a.t>=d.windup*d.get("lock_fraction",.45)
			var c = Color(.74,.21,.18,.16+progress*.12)
			# Burnt-red edges retain contrast on both warm grain roads and grey
			# rock. Pale orange disappeared into the new ochre freight surface.
			var edge = Color(.86,.29,.18,.72+progress*.25)
			var p = enemy.position; var r = d.range+16
			if enemy.is_ranged():
				p+=Vector2(0,-8)
				var end = p+Vector2.from_angle(a.dir)*820
				var query = PhysicsRayQueryParameters2D.create(p,end,1)
				var result = world.get_world_2d().direct_space_state.intersect_ray(query)
				if not result.is_empty(): end = result.position
				draw_line(p,end,c,48,true); draw_line(p,end,edge,1.5 if locked else .7,true)
			elif d.get("hit_shape","") == "circle":
				var mark = circle_telegraph(p,a.dir,d)
				draw_circle(mark.center,mark.radius,c)
				draw_circle(mark.center,mark.radius*progress,Color(.92,.44,.28,.09))
				draw_arc(mark.center,mark.radius,0,TAU,56,edge,2 if locked else 1,true)
				draw_line(mark.center+Vector2(-6,0),mark.center+Vector2(6,0),edge,1.5,true)
				draw_line(mark.center+Vector2(0,-6),mark.center+Vector2(0,6),edge,1.5,true)
			else:
				var lunge = maxf(0,d.get("lunge",0)-a.travel)
				if lunge>0: swept_sector(p,a.dir,r,d.arc,lunge,c,edge)
				else: sector(p,a.dir,r,d.arc,c)
				sector(p,a.dir,r*progress,d.arc,Color(.92,.44,.28,.09))
				trail(p,a.dir,r,d.arc,edge,2 if locked else 1)
				for side in [-1,1]: draw_line(p,p+Vector2.from_angle(a.dir+d.arc*side)*r,edge,1,true)
			if progress>.82: draw_circle(p+Vector2(0,-90),3,Color("ffe4c0"))
		for prop in world.props:
			if prop.fuse>=0 and not prop.spent:
				var p = Vector2(prop.x,prop.y)
				draw_circle(p,prop.blastRadius+world.hero.radius,Color(.9,.33,.17,.16))
				draw_arc(p,prop.blastRadius+world.hero.radius,0,TAU,72,Color(1,.72,.36,.75),2,true)
				draw_circle(p+Vector2(0,-45),8,Color("ffc173"))
		for item in world.loot:
			draw_circle(item.pos,12,Color(.4,.82,.6,.13)); draw_circle(item.pos,5,Color("badbab"))
			draw_line(item.pos+Vector2(-3,0),item.pos+Vector2(3,0),Color("42684e"),2,true)
		for arrow in world.arrows:
			var p = arrow.pos; var direction = Vector2.from_angle(arrow.dir)
			draw_line(p-direction*20,p,Color("d5b879"),2,true)
			draw_colored_polygon(PackedVector2Array([p+direction*5,p-direction*4+direction.orthogonal()*3,p-direction*4-direction.orthogonal()*3]),Color("eef0d4"))
			for side in [-1,1]: draw_line(p-direction*18,p-direction*23+direction.orthogonal()*4*side,Color("e1d8bc"),2,true)
	for e in entries:
		var p = e.pos; var t = 1-e.life/e.total; var alpha = 1-t; var info = e.info
		var r = float(info.get("radius",50)); var direction = float(info.get("dir",0)); var arc = float(info.get("arc",.7))
		match e.type:
			"fire_warning":
				draw_circle(p,r,Color(.9,.32,.18,.13)); draw_arc(p,r,0,TAU,40,Color(1,.58,.3,.8),2,true)
				draw_arc(p,r*(.2+.8*t),0,TAU,40,Color(1,.7,.3,.8),2,true)
			"rally":
				draw_arc(p,r*(.2+.8*t),0,TAU,48,Color(1,.84,.42,alpha*.7),4,true)
			"slash","ally","enemy_slash":
				var enemy = e.type=="enemy_slash"
				var key = info.get("key","")
				var gold = key in ["sweep","thrust3"]
				var c = Color(1,.69,.42,alpha) if enemy else Color(1,.86,.54,alpha) if gold else Color(.6,.95,1,alpha)
				if enemy and str(info.get("style","")).begins_with("vanguard_"):
					draw_vanguard_strike(p,direction,r,arc,t,alpha,str(info.style))
					continue
				if enemy and str(info.get("style","")).begins_with("warden_"):
					draw_warden_strike(p,direction,r,arc,t,alpha,info)
					continue
				if not enemy and info.get("empowered",false) and key in ["sweep","huilan"]:
					# A hollow cyan/gold spear arc, not an opaque flash over enemy
					# warnings. Five draw calls replace the old slash + rally ring.
					var center = p+Vector2(0,-20)
					var spread = minf(arc,PI-.02)
					trail(center,direction,r*(.72+.12*t),spread,Color(.57,.94,1,alpha*.62),2 if soft else 3)
					trail(center,direction,r*(.83+.12*t),spread,Color(1,.88,.54,alpha*.62),2 if soft else 3)
					for offset in [-.55,0.0,.55]:
						var ray = Vector2.from_angle(direction+spread*offset)
						draw_line(center+ray*r*(.76+.12*t),center+ray*r*(.94+.06*t),Color(1,.96,.74,alpha*.78),2,true)
				elif arc>.95 or key in ["sweep","sword"]:
					for i in range(3): trail(p+Vector2(0,-20),direction,r*(.6+.12*i),minf(arc,PI-.02),Color(c,alpha*(.22+i*.14)),(8-i*2) if not soft else 2)
				else:
					var start = p+Vector2(0,-25)+Vector2.from_angle(direction)*25
					var end = p+Vector2(0,-25)+Vector2.from_angle(direction)*r*(.65+.35*t)
					draw_line(start,end,Color(c,alpha*.25),10,true); draw_line(start,end,c,3,true)
				if key=="sword":
					for i in range(8):
						var a = direction+(i-3.5)*.2; var point = p+Vector2.from_angle(a)*r*(.4+.6*t)
						draw_line(point-Vector2.from_angle(a)*25,point,Color(.77,1,.96,alpha*.7),2,true)
			"impact","break":
				var golden = info.get("gold",false) or e.type=="break"
				var c = Color(1,.88,.61,alpha) if golden else Color(.74,1,1,alpha)
				for i in range(10):
					var a = i*2.399+direction; var distance = (13+posmod(i*17,30))*t
					draw_line(p+Vector2.from_angle(a)*distance,p+Vector2.from_angle(a)*(distance+7*(1-t)),c,2,true)
				if e.type=="break": draw_arc(p,r*(.2+.8*t),0,TAU,40,Color(c,alpha*.55),2,true)
			"heal","perfect","phase","explosion":
				var c = Color(.65,.93,.72,alpha) if e.type=="heal" else Color(.65,.98,1,alpha) if e.type=="perfect" else Color(1,.55,.33,alpha)
				for i in range(2): draw_arc(p,r*(.25+t*.75)-i*9,0,TAU,60,Color(c,alpha*(.4-i*.15)),3,true)
				if e.type=="explosion": draw_circle(p,r*(.2+.7*t),Color(1,.81,.47,alpha*.12))
			"dust":
				for i in range(3): draw_circle(p+Vector2(i*4-4,-t*8),r*(.25+.35*t),Color(.88,.81,.59,alpha*.19))
			"ghost":
				draw_set_transform(p+info.offset,info.rotation,info.scale)
				draw_texture(info.texture,Vector2.ZERO,Color(.59,.92,.96,alpha*.23))
				draw_set_transform(Vector2.ZERO)
	for label in labels:
		var alpha = minf(1,label.life/.25)
		var width = font.get_string_size(label.text,HORIZONTAL_ALIGNMENT_LEFT,-1,15).x
		var p = label.pos-Vector2(width/2,0)
		draw_string_outline(font,p,label.text,HORIZONTAL_ALIGNMENT_LEFT,-1,15,3,Color(.08,.15,.15,alpha))
		draw_string(font,p,label.text,HORIZONTAL_ALIGNMENT_LEFT,-1,15,Color(label.color,alpha))

func draw_vanguard_strike(p: Vector2,direction: float,radius: float,arc: float,t: float,alpha: float,style: String) -> void:
	# Narrow steel edges and sparse red sparks identify the long halberd. The
	# ground warning above still comes from the authoritative attack geometry.
	var center=p+Vector2(0,-20)
	var steel=Color(.86,.89,.79,alpha*.85)
	var red=Color(.84,.39,.26,alpha*.65)
	if style in ["vanguard_sweep","vanguard_return"]:
		var sign=-1.0 if style=="vanguard_return" else 1.0
		var head=direction+sign*lerpf(-arc,arc,clampf(t*1.6,0,1))
		var tail=head-sign*minf(.65,arc)
		draw_arc(center,radius*.82,minf(head,tail),maxf(head,tail),24,red,5 if not soft else 2,true)
		draw_arc(center,radius*.89,minf(head,tail),maxf(head,tail),24,steel,2,true)
		var ray=Vector2.from_angle(head)
		draw_line(center+ray*radius*.75,center+ray*radius*.96,steel,2,true)
	else:
		var ray=Vector2.from_angle(direction)
		var side=ray.orthogonal()
		var end=center+ray*radius*(.58+.35*t)
		draw_line(center+ray*25,end,red,6 if not soft else 2,true)
		draw_line(center+ray*32,end,steel,2,true)
		for sign in [-1,1]: draw_line(end-ray*17+side*sign*5,end,steel,1.4,true)
		if style=="vanguard_charge":
			# Local scuffs avoid painting a full charge through a collision wall.
			for sign in [-1,1]:
				var edge=p+side*sign*19
				draw_line(edge-ray*(8+24*t),edge-ray*7,Color(.64,.58,.46,alpha*.4),3,true)

func draw_warden_strike(p: Vector2,direction: float,radius: float,arc: float,t: float,alpha: float,info: Dictionary) -> void:
	# Heavy impacts use sparse masonry fragments, never a second drawn hammer.
	# The circle uses precisely the offset/radius from the damage definition.
	var style = str(info.get("style",""))
	var dust = Color(.76,.62,.43,alpha*.55)
	var light = Color(.96,.85,.61,alpha*.80)
	if style == "warden_quake":
		var mark = circle_telegraph(p,direction,info)
		draw_arc(mark.center,mark.radius,0,TAU,48,Color(.84,.45,.24,alpha*.35),2,true)
		draw_arc(mark.center,mark.radius*(.28+.72*t),0,TAU,48,dust,3 if not soft else 2,true)
		for i in range(6):
			var ray = Vector2.from_angle(direction+i*TAU/6)
			var tip = mark.center+ray*mark.radius*(.38+.45*t)
			draw_line(mark.center+ray*12,tip,dust,2,true)
			draw_line(tip,tip+ray.rotated(.35)*7,light,1.5,true)
	elif style in ["warden_sweep","warden_return"]:
		var sign = -1.0 if style == "warden_return" else 1.0
		var head = direction+sign*lerpf(-arc,arc,clampf(t*1.5,0,1))
		var tail = head-sign*minf(.60,arc)
		draw_arc(p+Vector2(0,-13),radius*.78,minf(head,tail),maxf(head,tail),26,dust,7 if not soft else 3,true)
		draw_arc(p+Vector2(0,-13),radius*.85,minf(head,tail),maxf(head,tail),26,light,2,true)
	else:
		var impact = p+Vector2.from_angle(direction)*radius*.72
		for i in range(5):
			var ray = Vector2.from_angle(direction+(i-2)*.45)
			var from = impact+ray*8
			draw_line(from,impact+ray*(17+20*t),light if i%2 else dust,2,true)
		if style == "warden_step":
			var side = Vector2.from_angle(direction).orthogonal()
			for sign in [-1,1]:
				draw_line(p+side*sign*19,p+side*sign*19-Vector2.from_angle(direction)*24*t,dust,3,true)

func draw_enemy_status(enemy) -> void:
	var p = enemy.position
	var body_height = float(enemy.visual_profile.get("height",84.0 if enemy.kind in ["boss","elite"] else 65.0))
	var bar_y = -body_height-11.0
	# Only the nameplate is culled; a distant bow can still telegraph into
	# the viewport. This avoids redrawing offscreen health/text every frame.
	var screen_position = get_canvas_transform() * (p+Vector2(0,bar_y-12))
	if not get_viewport_rect().grow(100).has_point(screen_position): return
	if enemy.kind not in ["boss","elite"] and enemy.hp<enemy.max_hp:
		draw_rect(Rect2(p+Vector2(-18,bar_y),Vector2(36,3)),Color(.08,.17,.17,.8))
		draw_rect(Rect2(p+Vector2(-18,bar_y),Vector2(36*enemy.hp/enemy.max_hp,3)),Color("d99178"))
	if enemy.kind != "boss" and (enemy.stagger > 0 or enemy.hp < enemy.max_hp):
		draw_rect(Rect2(p+Vector2(-18,bar_y+5),Vector2(36,2)),Color(.08,.17,.17,.7))
		if enemy.stagger_shield <= 0:
			draw_rect(Rect2(p+Vector2(-18,bar_y+5),Vector2(36*clampf(enemy.stagger/enemy.stagger_max,0,1),2)),Color("efcf83"))
	var status = enemy.combat_status()
	var text = {"phase":"变招 · 留意新式","break":"破势 · 追击","shield":"盾防已破","recovery":"收招 · 反击","guard":"稳势 · 抗轻击"}.get(status,"")
	var tint = Color("e8d398") if status not in ["guard","recovery"] else Color("e6ae72") if status == "guard" else Color("a7e1d1")
	if text!="" and font:
		var size = font.get_string_size(text,HORIZONTAL_ALIGNMENT_LEFT,-1,12).x
		var origin = p+Vector2(-size/2,-body_height-23)
		draw_rect(Rect2(origin+Vector2(-6,-14),Vector2(size+12,19)),Color(.07,.18,.17,.85))
		draw_string(font,origin,text,HORIZONTAL_ALIGNMENT_LEFT,-1,12,tint)
		if status != "phase":
			var remaining = enemy.combat_status_remaining(status)
			draw_line(origin+Vector2(-4,3),origin+Vector2(-4+(size+8)*remaining,3),tint,2,true)
