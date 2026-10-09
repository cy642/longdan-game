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

func _ready() -> void:
	font=load("res://assets/fonts/NotoSansSC-Regular.otf")
	Visual.prepare()
	if data.id=="civilians":
		person("chapter",3,Vector2(-4,-6),61)
		for i in range(3): person("units",5+i,Vector2(-30+i*28,28+absf(i-1)*15),48)
	elif data.id=="adou": person("chapter",4,Vector2(20,-4),63)

func person(key: String,index: int,p: Vector2,height: float) -> void:
	var sprite=Sprite2D.new(); sprite.texture=Visual.frames[key][index]; sprite.centered=false
	var meta=Visual.atlas_data[key].frames[index]; var factor=height/meta.region[3]
	sprite.scale=Vector2.ONE*factor; sprite.position=p-Vector2(meta.anchor[0],meta.anchor[1])*factor
	add_child(sprite); people.append(sprite)

func _process(dt: float) -> void:
	if world.mode=="playing": clock+=dt
	if data.id=="civilians":
		for sprite in people: sprite.visible=not world.state.flags.civilians
	elif data.id=="adou":
		for sprite in people: sprite.visible=not world.state.flags.mother
	redraw_clock-=dt
	if redraw_clock>0: return
	redraw_clock=1.0/30.0
	var state=str(world.state.flags)
	var animated=data.kind=="camp" or data.kind=="supplies" and world.state.flags.supplies
	var visible_area=Rect2(world.camera.position-world.get_viewport_rect().size*.6,world.get_viewport_rect().size*1.2).grow(120)
	if state!=last_state or animated and world.mode=="playing" and visible_area.has_point(position):
		last_state=state; queue_redraw()

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

func _draw() -> void:
	if data.is_empty(): return
	match data.kind:
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
			if data.id=="xiahouGate" and world.state.flags.temple or data.id=="zhangheGate" and world.state.flags.boss: return
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
			oval(Vector2(-20,13),26,.46,Color(.16,.29,.24,.23))
			oval(Vector2(-20,3),23,.6,Color("aaaf8b")); oval(Vector2(-20,-3),22,.55,Color("d0cbb1")); oval(Vector2(-20,-4),14,.53,Color("445d51"))
			draw_line(Vector2(-46,-22),Vector2(1,-22),Color("756a50"),5,true)
			for x in [-43,-1]: draw_line(Vector2(x,7),Vector2(x,-25),Color("8e7c58"),4,true)
	var label=data.label
	if data.id=="civilians" and world.state.flags.civilians: label="医者与百姓已获救"
	elif data.id=="adou" and world.state.flags.mother: label="井畔逆命 · 母子平安"
	if font:
		var width=font.get_string_size(label,HORIZONTAL_ALIGNMENT_LEFT,-1,12).x
		var p=Vector2(-width/2,30 if data.kind!="rescue" else 72)
		draw_string_outline(font,p,label,HORIZONTAL_ALIGNMENT_LEFT,-1,12,3,Color(.15,.26,.2,.8))
		draw_string(font,p,label,HORIZONTAL_ALIGNMENT_LEFT,-1,12,Color("f0e3b2"))
