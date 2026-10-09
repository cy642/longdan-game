extends Node2D
var data: Dictionary = {}

func polygon(points: Array, color: String) -> void:
	var p = PackedVector2Array()
	for point in points: p.append(Vector2(point[0],point[1]))
	draw_colored_polygon(p,Color(color))

func oval(center: Vector2, radius: float, squash: float, color: Color) -> void:
	draw_set_transform(center,0,Vector2(1,squash)); draw_circle(Vector2.ZERO,radius,color); draw_set_transform(Vector2.ZERO)

func _draw() -> void:
	if data.is_empty(): return
	match data.kind:
		"tree": draw_tree()
		"rock": draw_rock()
		"oil": draw_oil()
		_: draw_building()

func draw_tree() -> void:
	var s = data.size
	var random = RandomNumberGenerator.new(); random.seed = int(data.seed)
	oval(Vector2(18,7),s*.95,.28,Color(.08,.25,.21,.16))
	polygon([[-7,5],[-4,-s*1.5],[3,-s*1.6],[7,5],[13,8],[0,9]],"4c6050")
	draw_line(Vector2(0,-s*.4),Vector2(-s*.4,-s*1.3),Color("3b5448"),4,true)
	if data.variant < .32:
		var colors = ["31544a","406653","527d60","6c946c","88a579"]
		for i in range(5):
			var y = -s*.2-i*s*.34; var w = s*(1.16-i*.19)
			polygon([[-w,y+4],[-w*.5,y-s*.28],[1,y-s*.77],[w*.5,y-s*.22],[w,y+4],[w*.3,y+11],[-w*.25,y+12]],colors[i])
			draw_line(Vector2(-w*.72,y),Vector2(1,y-s*.64),Color(.73,.83,.63,.2),1.2,true)
	else:
		var colors = [Color("365c4d"),Color("426c55"),Color("568164"),Color("70986f"),Color("8dab7f")]
		for i in range(12):
			var angle = i*2.4
			var p = Vector2(cos(angle)*s*.4,-s*1.4+sin(angle)*s*.34-(s*.1 if i>8 else 0))
			oval(p,s*(.64-i*.012),.7,colors[mini(4,int(i/3))])
			for _j in range(8):
				var dot = p+Vector2(random.randf_range(-s*.45,s*.45),random.randf_range(-s*.24,s*.24))
				oval(dot,random.randf_range(2,4),.42,Color(.83,.89,.65,.14))

func draw_rock() -> void:
	var r = data.size; oval(Vector2(5,5),r*1.2,.4,Color(.13,.31,.26,.2))
	polygon([[-r,0],[-r*.4,-r*.8],[r*.3,-r*.84],[r,0],[r*.5,r*.38]],"768b7e")
	polygon([[-r,0],[-r*.4,-r*.8],[r*.3,-r*.84],[r*.15,-2]],"b8c2a9")
	draw_line(Vector2(r*.3,-r*.75),Vector2(r*.15,-2),Color("567769"),1,true)

func draw_building() -> void:
	var w = float(data.w); var h = float(data.h)
	oval(Vector2(18,h*.28),w*.67,.43,Color(.12,.25,.23,.17))
	if data.kind == "tent":
		polygon([[-w/2,h/2],[-w/2+10,-h/2],[0,-h/2-27],[w/2,h/2]],"b6a57e")
		polygon([[0,-h/2-27],[0,h/2],[w/2,h/2]],"8f7d61")
		polygon([[-14,h/2],[1,-8],[19,h/2]],"344a42")
		draw_line(Vector2(0,-h/2-30),Vector2(0,h/2+9),Color("525744"),3,true)
		return
	draw_rect(Rect2(-w/2,-h/2,w,h),Color("c4bf9a"))
	draw_rect(Rect2(w*.19,-h/2,w*.31,h),Color(.48,.55,.43,.35))
	draw_rect(Rect2(-14,h/2-37,28,37),Color("354c43"))
	draw_rect(Rect2(-w/2+14,h/2-38,21,18),Color("647060"))
	for i in range(4): draw_line(Vector2(-w/2+17+i*4,h/2-37),Vector2(-w/2+17+i*4,h/2-22),Color("c9c5a0"),1,true)
	draw_line(Vector2(-w/2,h/2),Vector2(w/2,h/2),Color("77836a"),4,true)
	if data.kind == "ruin":
		polygon([[-w/2-10,-3],[-10,-h/2-35],[15,-h/2-20],[-w/2+18,6]],"61766b")
		for i in range(5): draw_line(Vector2(13+i*12,-h/2+i%2*11),Vector2(15+i*12,-h/2-22+i%2*18),Color("635f4b"),4,true)
		polygon([[-17,h/2-5],[3,-10],[17,3],[35,h/2]],"a1a586")
	else:
		polygon([[-w/2-14,-1],[-6,-h/2-38],[w/2+16,-1],[4,12]],"536f65")
		polygon([[-6,-h/2-38],[w/2+16,-1],[4,12],[-6,-h/2-12]],"3e5c53")
		for i in range(14):
			var px = -w/2-9+i*(w+20)/13
			draw_line(Vector2(px,0),Vector2(-6+(px+6)*.12,-h/2-29),Color(.66,.76,.66,.55),1.5,true)
		draw_polyline(PackedVector2Array([Vector2(-w/2-14,-1),Vector2(4,12),Vector2(w/2+16,-1)]),Color("2f5147"),4,true)

func draw_oil() -> void:
	var p = data.prop
	if p.spent:
		oval(Vector2.ZERO,28,.4,Color(.17,.22,.17,.3))
		for i in range(6): draw_line(Vector2(-22+i*8,2),Vector2(-13+i*6,-10),Color("554c3f"),3,true)
		return
	oval(Vector2(5,7),32,.35,Color(.14,.26,.21,.2))
	for x in [-22,22]:
		draw_circle(Vector2(x,4),9,Color("626750")); draw_circle(Vector2(x,4),4,Color("b0a37a"))
	draw_rect(Rect2(-25,-21,50,24),Color("9b875b"))
	for i in range(3):
		var x = -16+i*16
		draw_rect(Rect2(x-7,-40,14,26),Color("b3a16d")); oval(Vector2(x,-40),7,.38,Color("d2be83"))
		draw_line(Vector2(x-7,-31),Vector2(x+7,-31),Color("756746"),2,true)
	draw_line(Vector2(-25,-14),Vector2(25,-14),Color("61563d"),3,true)
