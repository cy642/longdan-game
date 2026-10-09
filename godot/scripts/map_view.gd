extends Control
var world
var large = false

func _draw() -> void:
	if not world or world.definition.is_empty(): return
	var padding=Vector2(10,10)
	var area=size-padding*2
	var factor=minf(area.x/1600.0,area.y/1100.0)
	var offset=(size-Vector2(1600,1100)*factor)/2
	draw_rect(Rect2(offset,Vector2(1600,1100)*factor),Color("253f38"))
	for road in world.definition.roads:
		var points=PackedVector2Array()
		for p in road: points.append(offset+Vector2(p[0],p[1])*factor)
		draw_polyline(points,Color("9b9b72"),maxf(2,70*factor),true)
	if world.stage=="bridge":
		draw_rect(Rect2(offset+Vector2(0,30)*factor,Vector2(1600,255)*factor),Color("406c71"))
		draw_rect(Rect2(offset+Vector2(1170,30)*factor,Vector2(200,255)*factor),Color("b4a273"))
	for hut in world.definition.huts:
		draw_rect(Rect2(offset+Vector2(hut[0]-hut[2]/2.0,hut[1]-hut[3]/2.0)*factor,Vector2(hut[2],hut[3])*factor),Color("64776c"))
	for obj in world.definition.objects:
		var color=Color("d9bc7d") if obj.kind=="camp" else Color("adc6b0") if obj.kind=="exit" else Color("b79b72")
		var p=offset+Vector2(obj.x,obj.y)*factor
		draw_circle(p,4 if large else 2.3,color)
		if large:
			var font=world.ui.font
			draw_string(font,p+Vector2(8,-3),obj.label,HORIZONTAL_ALIGNMENT_LEFT,-1,13,Color("d3d6bd"))
	for enemy in world.enemies:
		if enemy.body_alive(): draw_circle(offset+enemy.position*factor,3 if large else 1.8,Color("e79677"))
	var target=world.mission().pos
	draw_arc(offset+target*factor,8 if large else 4,0,TAU,24,Color("f5d78a"),1.5,true)
	var p=offset+world.hero.position*factor
	draw_circle(p,5 if large else 3,Color("bcefed"))
	draw_line(p,p+Vector2.from_angle(world.hero.facing)*(12 if large else 7),Color("eff9ee"),2,true)
	var visible=world.get_viewport_rect().size/world.camera.zoom*factor
	draw_rect(Rect2(p-visible/2,visible),Color(.77,.9,.8,.15),false,1)
