extends RefCounted
## Editable silhouettes, rendered once into the shared scenery atlas.
const BUILDINGS = {
	"village":["5b5146","a39279","443d34","92826a"],
	"temple":["626f68","999889","424b46","77775f"],
	"house":["667574","c0b29a","5b5143","93816a"],
	"fork":["797359","afa07c","514b38","b0a17c"],
	"bridge":["6d7566","999e88","48554c","859078"],
	"hs_grain":["837458","b5a780","5b513e","b9a677"],
	"hs_camp":["64786e","9baf9d","43594e","98a998"],
	"hs_final":["586260","91958b","373f3d","7b8580"]
}

static func tree(s,kind: String) -> void:
	var size=float(s.data.size); var variant=posmod(int(s.data.seed),4)
	s.oval(Vector2(12,7),size*.78,.25,Color(.13,.20,.16,.16))
	s.draw_set_transform(Vector2.ZERO,0,Vector2(1.0-variant*.045,1.0+variant*.025))
	match kind:
		"bamboo":
			# Unequal culms and a clear lower trunk distinguish bamboo groves
			# from rounded broadleaf trees, without a dense green wall at feet.
			for i in range(5):
				var x=(i-2)*size*.35; var height=size*(2.1+.22*posmod(i+variant,4)); var lean=(i-2)*4
				var bottom=Vector2(x,3+abs(i-2)); var top=Vector2(x+lean,-height)
				s.draw_line(bottom,top,Color("3d5c46"),4,true)
				s.draw_line(bottom+Vector2(-1,0),top+Vector2(-1,0),Color("8b9d65"),1.2,true)
				for node in range(1,6):
					var at=bottom.lerp(top,float(node)/6)
					s.draw_line(at-Vector2(3,0),at+Vector2(3,0),Color("b1b68a"),1.2,true)
					if node<3: continue
					var end=at+Vector2((1 if (node+i)%2 else -1)*size*.7,-size*.24)
					s.draw_line(at,end,Color("3a5946"),1.4,true)
					for leaf in range(4):
						var base=at.lerp(end,(leaf+1)/4.0)
						var tip=base+Vector2((1 if (node+i)%2 else -1)*(9+leaf*2),-8+(leaf%2)*14)
						s.draw_colored_polygon(PackedVector2Array([base,base.lerp(tip,.5)+Vector2(0,-2.4),tip,base.lerp(tip,.6)+Vector2(0,2)]),Color("54785c") if (node+leaf)%3 else Color("809569"))
		"bare":
			var h=size*1.85
			s.polygon([[-5,6],[-3,-h*.55],[2,-h],[7,-h*.52],[8,5]],"57534a")
			s.draw_line(Vector2(-1,3),Vector2(0,-h*.70),Color("a49a7c"),2,true)
			for side in [-1,1]:
				var p=Vector2(2,-h*.46); var end=Vector2(side*size*.64,-h*(.86 if side<0 else .72))
				s.draw_polyline(PackedVector2Array([p,p.lerp(end,.48)+Vector2(side*3,8),end,end+Vector2(side*size*.16,-size*.17)]),Color("57534a"),3.8,true)
				s.draw_line(end-Vector2(side*9,-9),end+Vector2(-side*4,-size*.30),Color("676154"),2,true)
				s.draw_line(Vector2(side*3,2),Vector2(side*17,7),Color("746e5c"),2,true)
		"cypress":
			s.polygon([[-4,5],[-3,-size*2.1],[4,-size*2.2],[5,5]],"605f4c")
			for layer in range(4):
				var y=-size*(.7+layer*.36); var w=size*(.43-layer*.055)
				s.polygon([[-w,y+10],[-w*.7,y-7],[-w*.33,y-17],[1,y-size*.6],[w*.43,y-14],[w,y+6],[w*.3,y+13]], ["3f574b","496554","57725c","6b8066"][layer])
		"willow":
			s.polygon([[-6,6],[-2,-size*.6],[size*.13,-size*1.55],[size*.3,-size*1.5],[5,-size*.5],[7,5]],"5c695b")
			s.draw_line(Vector2(0,-size*.55),Vector2(-size*.5,-size*1.65),Color("5c695b"),4,true)
			for i in range(7):
				var x=(i-3)*size*.29; var top=Vector2(x,-size*(1.7-.08*abs(i-3)))
				var curve=PackedVector2Array([Vector2(4,-size*1.45),top,top+Vector2(12,size*.25),top+Vector2(18,size*(.8+.08*(i%3)))])
				s.draw_polyline(curve,Color("55755d"),2.5,true)
				for j in range(5):
					var p=top+Vector2(12+j*1.5,size*(.18+j*.13))
					s.draw_line(p,p+Vector2(-7,7),Color("829572"),3,true)
		"scrub":
			for i in range(4):
				var x=(i-1.5)*size*.28; var y=-size*(.25+float(i%2)*.16)
				s.draw_line(Vector2(x*.3,3),Vector2(x,y-12),Color("666a54"),2,true)
				s.polygon([[x-13,y],[x-8,y-11],[x-2,y-8],[x+5,y-17],[x+13,y-6],[x+15,y+2],[x+2,y+4]],"71816b" if i%2 else "839079")
		_:
			# Wind-shaped oak with exposed limbs, not the generic round-tree stamp.
			s.polygon([[-5,6],[-1,-size*1.1],[size*.2,-size*1.7],[size*.33,-size*1.65],[6,-size*.8],[8,5]],"71654e")
			for i in range(4):
				var p=Vector2((i-1.5)*size*(.39+.025*variant),-size*(1.40+.09*posmod(i+variant,3)))
				s.draw_line(Vector2(3,-size*.6),p,Color("71654e"),3.5,true)
				s.polygon([[p.x-22,p.y+4],[p.x-29,p.y-5],[p.x-15,p.y-17],[p.x-1,p.y-13],[p.x+10,p.y-23],[p.x+29,p.y-10],[p.x+22,p.y+3],[p.x+5,p.y+8]], ["747955","8d8c60","8d9168","9e9c73"][i])
	s.draw_set_transform(Vector2.ZERO)

static func building(s) -> void:
	var stage=str(s.data.style_id); var colors=BUILDINGS.get(stage,BUILDINGS.house)
	var roof=Color(colors[0]); var wall=Color(colors[1]); var beam=Color(colors[2]); var cloth=Color(colors[3])
	var w=float(s.data.w); var h=float(s.data.h); var floor_y=h*.5
	s.oval(Vector2(12,floor_y-3),w*.58,.32,Color(.15,.18,.14,.18))
	if s.data.kind=="tent":
		s.draw_colored_polygon(PackedVector2Array([Vector2(-w*.5,floor_y),Vector2(-w*.39,-h*.4),Vector2(0,-h*.5-23),Vector2(w*.5,floor_y)]),cloth)
		s.draw_colored_polygon(PackedVector2Array([Vector2(0,-h*.5-23),Vector2(0,floor_y),Vector2(w*.5,floor_y)]),cloth.darkened(.16))
		s.draw_colored_polygon(PackedVector2Array([Vector2(-17,floor_y),Vector2(0,-5),Vector2(16,floor_y)]),beam.darkened(.2))
		s.draw_line(Vector2(0,-h*.5-25),Vector2(0,floor_y+5),beam,3,true)
		for side in [-1,1]:
			s.draw_line(Vector2(side*w*.13,-h*.32),Vector2(side*w*.40,floor_y),Color(cloth.darkened(.25),.6),1.5,true)
			s.draw_line(Vector2(side*w*.39,-h*.35),Vector2(side*w*.51,floor_y),beam,1,true)
			s.draw_line(Vector2(side*w*.51,floor_y-4),Vector2(side*w*.51,floor_y+3),beam,3,true)
		if stage=="hs_final":
			for side in [-1,1]: s.draw_line(Vector2(side*18,floor_y-30),Vector2(side*34,floor_y),Color("654c46"),7,true)
		elif stage in ["fork","hs_grain"]:
			for i in range(3):
				var p=Vector2(-w*.34+i*10,floor_y-6)
				s.oval(p,9,.65,Color("c0ac7a")); s.draw_line(p+Vector2(-5,-1),p+Vector2(5,-2),Color("88774d"),1.2,true)
		else:
			s.draw_line(Vector2(-w*.34,floor_y-8),Vector2(-w*.18,floor_y-23),cloth.lightened(.12),2,true)
		return
	# Walls keep the original footprint. Timber, doorway and damage are tied to
	# the building rather than scattered as unrelated decorative rubble.
	s.draw_rect(Rect2(-w*.5,-h*.5,w,h),wall)
	s.draw_rect(Rect2(w*.25,-h*.5,w*.25,h),wall.darkened(.17))
	s.draw_line(Vector2(-w*.5,floor_y),Vector2(w*.5,floor_y),beam.lightened(.15),4,true)
	for x in [-w*.46,w*.24]: s.draw_line(Vector2(x,-h*.4),Vector2(x,floor_y),beam,5,true)
	s.draw_rect(Rect2(-13,floor_y-34,27,34),beam.darkened(.23))
	s.draw_line(Vector2(-16,floor_y-35),Vector2(17,floor_y-35),beam,3,true)
	s.draw_rect(Rect2(-w*.36,floor_y-37,19,17),beam)
	for i in range(3): s.draw_line(Vector2(-w*.34+i*5,floor_y-36),Vector2(-w*.34+i*5,floor_y-21),wall.lightened(.14),1.4,true)
	var damaged=s.data.kind=="ruin" or stage=="village"
	var top=Vector2(-6,-h*.5-29)
	var roof_polygon=PackedVector2Array([Vector2(-w*.5-9,-1),top,Vector2(w*.5+10,0),Vector2(3,13)])
	s.draw_colored_polygon(roof_polygon,roof)
	for i in range(12):
		if damaged and i in [7,8,9]: continue
		var edge=Vector2(-w*.5-7+i*(w+14)/11,1+sin(i*.8)*1.4)
		s.draw_line(top.lerp(edge,.24),edge,roof.lightened(.19),1.3,true)
	s.draw_polyline(PackedVector2Array([Vector2(-w*.5-9,-1),Vector2(3,13),Vector2(w*.5+10,0)]),roof.darkened(.35),4,true)
	if damaged:
		var offset=w*.16
		s.draw_colored_polygon(PackedVector2Array([Vector2(offset,-h*.34),Vector2(offset+19,-h*.21),Vector2(offset+13,-4),Vector2(offset-4,3),Vector2(offset-15,-9)]),beam.darkened(.26))
		for i in range(3): s.draw_line(Vector2(offset+i*8-8,-h*.34+3),Vector2(offset+i*6-5,-5+i*2),beam.lightened(.09),3,true)
		s.draw_polyline(PackedVector2Array([Vector2(w*.33,7),Vector2(w*.26,22),Vector2(w*.34,32),Vector2(w*.29,floor_y)]),wall.darkened(.31),1.5,true)
	if stage=="village":
		for i in range(5): s.draw_line(Vector2(-w*.43+i*7,floor_y-3),Vector2(-w*.40+i*5,floor_y-21-(i%3)*8),Color("5f5448",.45),4,true)
	elif stage=="house":
		s.draw_line(Vector2(-w*.5+4,floor_y-9),Vector2(w*.23-2,floor_y-9),Color("968f7c"),2,true)
		s.draw_rect(Rect2(20,floor_y-5,17,4),Color("b0a082"))
	elif stage=="temple":
		s.draw_line(Vector2(-w*.5-7,1),Vector2(-w*.5-13,-8),roof,4,true)
		s.draw_line(Vector2(w*.5+7,1),Vector2(w*.5+14,-8),roof,4,true)
