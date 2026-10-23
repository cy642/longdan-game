extends Node2D
## Visible world anchors for every interaction; no invisible story trigger points.
const Visual=preload("res://scripts/actor_visual.gd")
var world
var data: Dictionary={}
var font: Font
var people: Array=[]
var clock=0.0
var redraw_clock=0.0
var last_state=""
var focused = false
var focus_blocked = false
var support_aim=Vector2.LEFT
var support_tension=0.0
var support_recoil=0.0

func set_support_pose(direction: Vector2,tension: float,recoil: float) -> void:
	if data.kind!="huangzhong": return
	if support_aim.is_equal_approx(direction) and is_equal_approx(support_tension,tension) and is_equal_approx(support_recoil,recoil): return
	support_aim=direction; support_tension=clampf(tension,0,1); support_recoil=clampf(recoil,0,1)
	queue_redraw()

func _ready() -> void:
	font=load("res://assets/fonts/NotoSansSC-Regular.otf")
	Visual.prepare()
	if data.id=="civilians":
		person("chapter",3,Vector2(-4,-6),61)
		for i in range(3): person("units",5+i,Vector2(-30+i*28,28+absf(i-1)*15),48)
	elif data.id=="adou": person("chapter",4,Vector2(44,-4),63)
	elif data.kind=="huangzhong": person("chapter",3,Vector2(2,-3),74)
	elif data.kind=="wounded": person("chapter",5,Vector2(0,4),57)
	elif data.kind=="jigu":
		if data.get("task","") in ["jg_front","jg_rear","jg_last_guard"]:
			person("chapter",5,Vector2(-26,2),52); person("chapter",6,Vector2(26,10),52)
		elif data.get("task","")=="jg_supplies":
			var frame=JSON.parse_string(FileAccess.get_file_as_string("res://assets/props/grain_rack.json"))
			var sprite=Sprite2D.new(); sprite.texture=load(frame.image); sprite.centered=false
			sprite.scale=Vector2.ONE*.35; sprite.position=-Vector2(frame.anchor_px[0],frame.anchor_px[1])*.35
			add_child(sprite)

func person(key: String,index: int,p: Vector2,height: float) -> void:
	var sprite=Sprite2D.new(); sprite.texture=Visual.frames[key][index]; sprite.centered=false
	var meta=Visual.atlas_data[key].frames[index]; var factor=height/meta.region[3]
	sprite.scale=Vector2.ONE*factor; sprite.position=p-Vector2(meta.anchor[0],meta.anchor[1])*factor
	add_child(sprite); people.append(sprite)

func _process(dt: float) -> void:
	if world.mode=="playing": clock+=dt
	if data.kind=="graincart":
		var director=world.get("tactics")
		if is_instance_valid(director) and is_instance_valid(director.cart): position=director.cart.position
	if data.id=="civilians":
		for sprite in people: sprite.visible=not world.state.flags.civilians
	elif data.id=="adou":
		for sprite in people: sprite.visible=not world.state.flags.mother
	elif data.kind=="jigu":
		for sprite in people:
			sprite.modulate.a=move_toward(sprite.modulate.a,0.0 if world.state.flags.get(data.get("task",""),false) else 1.0,dt*1.6)
	redraw_clock-=dt
	if redraw_clock>0: return
	redraw_clock=1.0/30.0
	var nearest: Dictionary = world.nearest_object()
	focused = not nearest.is_empty() and nearest.id == data.id
	focus_blocked = world.object_blocked(data)
	var state=str(world.state.flags)+str(focused)+str(focus_blocked)
	if data.kind=="gate": state+=gate_state()
	var animated=focused or data.kind in ["camp","hideflag"] or data.kind=="supplies" and world.state.flags.supplies or data.kind=="beacon" and world.state.flags.get("beacon",false)
	# Camera zoom expands the visible world area. Use the same bounds as the
	# scenery so campfires and flags never freeze while still on screen.
	var extent=world.get_viewport_rect().size/world.camera.zoom
	var visible_area=Rect2(world.camera.get_screen_center_position()-extent*.5,extent).grow(120)
	if state!=last_state or animated and world.mode=="playing" and visible_area.has_point(position):
		last_state=state; queue_redraw()

func gate_state() -> String:
	var tactic_state=world.state.get("tactics")
	return str(tactic_state.get("gate","PREPARE")) if tactic_state is Dictionary else "PREPARE"

func oval(p: Vector2,r: float,squash: float,color: Color) -> void:
	draw_set_transform(p,0,Vector2(1,squash)); draw_circle(Vector2.ZERO,r,color); draw_set_transform(Vector2.ZERO)

func flame(p: Vector2,size: float) -> void:
	var pulse=sin(clock*8+position.x)*2
	oval(p+Vector2(0,7),size*1.6,.45,Color(1,.69,.25,.12))
	draw_colored_polygon(PackedVector2Array([p+Vector2(-size*.6,0),p+Vector2(-size*.3,-size*.8-pulse),p+Vector2(0,-size*1.65),p+Vector2(size*.32,-size*.9+pulse),p+Vector2(size*.63,0)]),Color("e49e54"))
	draw_colored_polygon(PackedVector2Array([p+Vector2(-size*.27,0),p+Vector2(0,-size*.95-pulse),p+Vector2(size*.28,0)]),Color("f6d08a"))
	for i in range(3):
		var t=fposmod(clock*.7+i*.31,1.0)
		draw_circle(p+Vector2(sin(t*6+i)*7,-size*(1+t*2)),1.3,Color(1,.87,.56,1-t))

func _draw_focus() -> void:
	if not focused: return
	var color = Color("d8b77b") if focus_blocked else Color("e4d7a1")
	var radius = 34.0 + sin(clock*3.0)*1.3
	draw_set_transform(Vector2(0,8),0,Vector2(1,.46))
	draw_arc(Vector2.ZERO,radius,0,TAU,48,Color(color,.70),2.0,true)
	draw_set_transform(Vector2.ZERO)
	# A small E badge links the physical target to the existing contextual HUD.
	var badge = Rect2(34,-16,20,22)
	draw_style_box(_focus_badge_style(color),badge)
	if font: draw_string(font,Vector2(40,0),"E",HORIZONTAL_ALIGNMENT_LEFT,-1,13,color)
	if focus_blocked:
		draw_line(Vector2(36,10),Vector2(51,10),Color(color,.8),2,true)

func _focus_badge_style(color: Color) -> StyleBoxFlat:
	var style = StyleBoxFlat.new()
	style.bg_color = Color(.08,.18,.16,.88)
	style.border_color = Color(color,.72)
	style.set_border_width_all(1)
	style.set_corner_radius_all(4)
	return style

func _draw() -> void:
	if data.is_empty(): return
	_draw_focus()
	match data.kind:
		"jigu": _draw_jigu()
		"camp":
			oval(Vector2(1,6),26,.45,Color(.18,.25,.2,.25))
			for i in range(8): oval(Vector2.from_angle(i*TAU/8)*Vector2(22,9),5,.7,Color("828b6d"))
			draw_line(Vector2(-16,2),Vector2(15,7),Color("71553c"),5,true)
			draw_line(Vector2(14,1),Vector2(-12,9),Color("8a6746"),5,true)
			flame(Vector2(0,1),18)
		"exit","finish":
			var done=not world.object_blocked(data)
			var color=Color("c6d8b6") if done else Color("8f9b80")
			draw_line(Vector2(-20,5),Vector2(-20,-62),Color("53674d"),4,true)
			draw_colored_polygon(PackedVector2Array([Vector2(-18,-60),Vector2(21,-54),Vector2(9,-43),Vector2(-18,-46)]),Color("738f78") if done else Color("827e64"))
			draw_arc(Vector2.ZERO,29,0,TAU,36,Color(color,.5),1.5,true)
			draw_line(Vector2(-8,0),Vector2(8,0),color,2,true)
			draw_polyline(PackedVector2Array([Vector2(2,-5),Vector2(9,0),Vector2(2,5)]),color,2,true)
		"boss":
			if data.id=="jg_vanguard" and world.state.flags.get("jg_boss",false): return
			if data.id=="xiahouGate" and world.state.flags.temple or data.id=="zhangheGate" and world.state.flags.boss: return
			if data.id=="hs_dujun" and world.state.flags.get("dujun",false): return
			for x in [-30,30]:
				draw_line(Vector2(x,6),Vector2(x,-78),Color("74674b"),4,true)
				draw_colored_polygon(PackedVector2Array([Vector2(x+1,-76),Vector2(x+23,-71),Vector2(x+14,-46),Vector2(x+1,-49)]),Color("8e6553"))
			draw_arc(Vector2.ZERO,37,0,TAU,40,Color(.8,.68,.47,.45),2,true)
		"supplies":
			for i in range(6):
				var p=Vector2(-29+i%3*28,-15+int(i/3)*19)
				oval(p+Vector2(2,9),18,.45,Color(.24,.29,.19,.22))
				draw_rect(Rect2(p-Vector2(12,22),Vector2(24,25)),Color("a78c59")); oval(p+Vector2(0,-22),12,.38,Color("ceba84"))
				draw_line(p+Vector2(-12,-12),p+Vector2(12,-12),Color("786544"),2,true)
				if world.state.flags.supplies: flame(p-Vector2(0,12),15)
		"story":
			var well=get_parent().get_node_or_null("Landmark_well_hoist")
			if well==null or not is_instance_valid(well.get("rendered_prop")):
				oval(Vector2(-20,13),26,.46,Color(.16,.29,.24,.23))
				oval(Vector2(-20,3),23,.6,Color("aaaf8b")); oval(Vector2(-20,-3),22,.55,Color("d0cbb1")); oval(Vector2(-20,-4),14,.53,Color("445d51"))
				draw_line(Vector2(-46,-22),Vector2(1,-22),Color("756a50"),5,true)
				for x in [-43,-1]: draw_line(Vector2(x,7),Vector2(x,-25),Color("8e7c58"),4,true)
		"huangzhong":
			# A pale-haired source portrait keeps the friendly Q-style face. The
			# yellow mantle and full bow silhouette identify this older general.
			oval(Vector2(3,10),29,.43,Color(.16,.26,.22,.22))
			draw_colored_polygon(PackedVector2Array([Vector2(-20,-39),Vector2(13,-43),Vector2(29,-12),Vector2(24,8),Vector2(7,2),Vector2(-19,7),Vector2(-25,-14)]),Color("b5a05d"))
			draw_polyline(PackedVector2Array([Vector2(-22,-37),Vector2(-26,-11),Vector2(-20,6)]),Color("e4d49b"),2.2,true)
			var bow_direction=support_aim if support_tension>0 or support_recoil>0 else Vector2.LEFT
			draw_set_transform(Vector2(0,-25),bow_direction.angle())
			draw_arc(Vector2(25-support_recoil*3,0),25,-PI*.42,PI*.42,24,Color("a48350"),3.8,true)
			var drawn=Vector2(32-support_tension*14,0)
			draw_polyline(PackedVector2Array([Vector2(32,-24),drawn,Vector2(32,24)]),Color("dbd1b0"),1.2,true)
			draw_line(drawn,drawn+Vector2(25,0),Color("a09267"),2,true)
			if support_tension>0:
				draw_circle(Vector2(18,1),3,Color("dfbd98"))
				draw_circle(drawn+Vector2(0,2),3,Color("dfbd98"))
			draw_set_transform(Vector2.ZERO)
		"wounded":
			oval(Vector2(0,12),31,.47,Color(.16,.27,.21,.23))
			draw_rect(Rect2(-32,0,64,16),Color("8e8a65")); draw_rect(Rect2(-28,0,56,11),Color("b7b69b"))
			for x in [-26,26]: draw_line(Vector2(x,10),Vector2(x,19),Color("6c6c50"),4,true)
			var recovered=world.state.flags.get("wounded",false)
			draw_rect(Rect2(21,-22,20,17),Color("ddd5ad"))
			if not recovered:
				draw_line(Vector2(31,-18),Vector2(31,-9),Color("a56f55"),3,true)
				draw_line(Vector2(27,-14),Vector2(35,-14),Color("a56f55"),3,true)
		"beacon":
			oval(Vector2(1,10),40,.43,Color(.15,.25,.19,.25))
			for x in [-26,26]: draw_line(Vector2(x,7),Vector2(x,-43),Color("655c43"),5,true)
			for y in [-18,-5,8]: draw_line(Vector2(-31,y),Vector2(31,y),Color("8c7d56"),7,true)
			for i in range(6):
				var p=Vector2(-22+i*9,-20)
				draw_line(p,p+Vector2(-8,-31),Color("bba66f"),2,true)
				draw_colored_polygon(PackedVector2Array([p+Vector2(-10,-35),p+Vector2(-4,-32),p+Vector2(-6,-26)]),Color("a56d56"))
			if world.state.flags.get("beacon",false): flame(Vector2(0,-20),27)
		"hideflag":
			oval(Vector2(0,6),24,.43,Color(.17,.25,.19,.21))
			draw_line(Vector2(0,5),Vector2(0,-84),Color("676c50"),5,true)
			draw_circle(Vector2(0,-87),3,Color("d6c28b"))
			var sway=sin(clock*2.2)*2
			draw_colored_polygon(PackedVector2Array([Vector2(2,-81),Vector2(44,-76+sway),Vector2(37,-45+sway),Vector2(21,-51),Vector2(3,-45)]),Color("548b82"))
			draw_polyline(PackedVector2Array([Vector2(15,-70),Vector2(25,-62),Vector2(15,-55),Vector2(34,-55)]),Color("e1d6a6"),2,true)
			oval(Vector2(-12,10),6,.43,Color("8a9d78")); oval(Vector2(13,13),6,.43,Color("8a9d78"))
		"gate":
			var open=gate_state()!="PREPARE"
			# The interaction stands inside the camp; hinge art belongs on the
			# actual wall opening, not 70 pixels in front of that opening.
			var gate_x=float(world.definition.get("tactics",{}).get("gate_line",position.x))-position.x
			draw_set_transform(Vector2(gate_x,0))
			for side in [-1,1]:
				var hinge=Vector2(0,side*118)
				oval(hinge+Vector2(3,6),19,.44,Color(.17,.25,.19,.25))
				draw_rect(Rect2(hinge-Vector2(14,30),Vector2(28,42)),Color("6c6d4d"))
				draw_line(hinge-Vector2(9,29),hinge+Vector2(9,-29),Color("a5a174"),3,true)
				var end=hinge+Vector2(85,0) if open else Vector2(0,side*3)
				draw_line(hinge,end,Color("4c5542"),16,true)
				draw_line(hinge+Vector2(-2,-3),end+Vector2(-2,-3),Color("9b8c5e"),8,true)
				for n in range(1,5): draw_circle(hinge.lerp(end,n/5.0),2,Color("cfba7d"))
			draw_set_transform(Vector2.ZERO)
		"drum":
			oval(Vector2(2,12),35,.44,Color(.15,.26,.22,.24))
			for x in [-22,22]: draw_line(Vector2(x,10),Vector2(x,-21),Color("676248"),6,true)
			draw_rect(Rect2(-27,-31,54,32),Color("8f5944")); oval(Vector2(0,0),27,.42,Color("b58255"))
			oval(Vector2(0,-31),29,.48,Color("b69265")); oval(Vector2(0,-32),25,.45,Color("e0cf9b"))
			for i in range(12):
				var p=Vector2.from_angle(i*TAU/12)*Vector2(26,12)+Vector2(0,-32)
				draw_circle(p,1.3,Color("705943"))
			draw_line(Vector2(-22,-40),Vector2(16,-18),Color("9f8559"),3,true)
			draw_line(Vector2(19,-41),Vector2(-14,-20),Color("b79b68"),3,true)
		"graincart":
			# The cart is a moving production node; this marker only locates the
			# escort interaction, rather than painting a second stationary cart.
			if focused: draw_arc(Vector2.ZERO,42,0,TAU,32,Color(.82,.82,.58,.35),1.2,true)
	var label=data.label
	if data.id=="civilians" and world.state.flags.civilians: label="医者与百姓已获救"
	elif data.id=="adou" and world.state.flags.mother: label="井畔逆命 · 母子平安"
	elif data.kind=="huangzhong" and world.state.flags.get("huangzhong",false): label="黄忠 · 已接应"
	elif data.kind=="wounded" and world.state.flags.get("wounded",false): label="张著与伤兵 · 已获救"
	elif data.kind=="beacon" and world.state.flags.get("beacon",false): label="火箭辎重 · 已焚毁"
	elif data.kind=="jigu":
		var task=str(data.get("task",""))
		if world.state.flags.get(task,false): label={"jg_banner":"号旗已夺 · 箭阵已停","jg_dispatch":"军报已收回","jg_front":"前队已撤","jg_rear":"后队已撤","jg_rearguard":"后军已收拢","jg_supplies":"辎重已归队","jg_last_guard":"末队已接回"}.get(task,"已完成")
		elif task=="bridge_choice":
			if world.state.flags.jg_bridge_cut: label="断索截敌 · 退路已定"
			elif world.state.flags.jg_bridge_held: label="留桥接应 · 等待末队"
	if font:
		var width=font.get_string_size(label,HORIZONTAL_ALIGNMENT_LEFT,-1,12).x
		var p=Vector2(-width/2,30 if data.kind!="rescue" else 72)
		draw_string_outline(font,p,label,HORIZONTAL_ALIGNMENT_LEFT,-1,12,3,Color(.15,.26,.2,.8))
		draw_string(font,p,label,HORIZONTAL_ALIGNMENT_LEFT,-1,12,Color("f0e3b2"))

func _draw_jigu() -> void:
	var task=str(data.get("task","")); var done=world.state.flags.get(task,false)
	if task=="jg_supplies": return # Cached illustrated supply rack owns its silhouette.
	if task=="jg_dispatch":
		oval(Vector2(0,7),24,.36,Color(.1,.16,.19,.22))
		for i in range(3):
			var p=Vector2(-14+i*12,1-i*3)
			draw_line(p-Vector2(0,13),p+Vector2(5,9),Color("79624b"),9,true)
			draw_line(p-Vector2(0,11),p+Vector2(5,7),Color("c6b88c").darkened(.2 if done else 0),6,true)
			draw_line(p-Vector2(4,0),p+Vector2(7,-2),Color("8f4d3a"),2,true)
		return
	var mast=Vector2(-13,4); var top=Vector2(-13,-74)
	oval(Vector2(1,9),23,.37,Color(.08,.15,.2,.25))
	draw_line(mast,top,Color("574e46"),5,true); draw_line(mast+Vector2(-1,-2),top+Vector2(-1,1),Color("b69a72"),1.5,true)
	var enemy_flag=task=="jg_banner" and not done
	var color=Color("944d40") if enemy_flag else Color("508b85")
	var sway=sin(clock*1.9+position.x*.01)*3
	var cloth=PackedVector2Array([top+Vector2(2,3),top+Vector2(40,9+sway),top+Vector2(34,25+sway),top+Vector2(41,38+sway),top+Vector2(2,33)])
	draw_colored_polygon(cloth,color); draw_polyline(PackedVector2Array([cloth[0],cloth[1],cloth[2],cloth[3]]),color.lightened(.3),1.3,true)
	draw_polyline(PackedVector2Array([top+Vector2(13,12),top+Vector2(26,19),top+Vector2(13,25)]),Color("e6d4a6"),2,true)
	if task=="bridge_choice":
		for side in [-1,1]:
			var p=Vector2(side*23,10)
			draw_line(p,p-Vector2(0,34),Color("76553c"),8,true)
			for y in range(3): draw_line(p+Vector2(-5,-11-y*4),p+Vector2(5,-12-y*4),Color("b9a579"),1.5,true)
		if not world.state.flags.jg_bridge_cut: draw_line(Vector2(-23,-14),Vector2(23,-11),Color("b9a579"),3,true)
