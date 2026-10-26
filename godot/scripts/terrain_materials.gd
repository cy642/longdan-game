extends RefCounted
const Painted=preload("res://scripts/painted_ground.gd")
## Art-only region grammar. No random draws are shared with terrain collision.
## These strokes are captured into the existing single ground texture.
const PROFILES = {
	"mountain":{"ground":"a69b7f","road":"c2ae88","width":74.0,"plant":"dry","tree":"weathered","keep":.62},
	"village":{"ground":"9b8c77","road":"ae987c","width":104.0,"plant":"yard","tree":"bare","keep":.19},
	"temple":{"ground":"858b7b","road":"9b9c8a","width":68.0,"plant":"moss","tree":"cypress","keep":.40},
	"house":{"ground":"a09780","road":"b5a184","width":76.0,"plant":"yard","tree":"bare","keep":.22},
	"fork":{"ground":"afa07e","road":"b9a178","width":106.0,"plant":"stubble","tree":"weathered","keep":.22},
	"bridge":{"ground":"95998a","road":"b1a48b","width":92.0,"plant":"bank","tree":"willow","keep":.28},
	"hs_forest":{"ground":"637e6b","road":"91957d","width":75.0,"plant":"bamboo","tree":"bamboo","keep":.88},
	"hs_grain":{"ground":"a49f80","road":"b4ab8c","width":106.0,"plant":"stubble","tree":"scrub","keep":.25},
	"hs_return":{"ground":"8f9690","road":"a6a797","width":84.0,"plant":"shale","tree":"scrub","keep":.26},
	"hs_camp":{"ground":"9b9780","road":"ada289","width":108.0,"plant":"yard","tree":"scrub","keep":.12},
	"hs_river":{"ground":"87958b","road":"9f9e88","width":88.0,"plant":"bank","tree":"willow","keep":.20},
	"hs_final":{"ground":"777f79","road":"96958a","width":108.0,"plant":"yard","tree":"bare","keep":.10},
	"jg_fog":{"ground":"7d8985","road":"aaa995","width":92.0,"plant":"shale","tree":"weathered","keep":.42},
	"jg_signal":{"ground":"979785","road":"b5aa8c","width":98.0,"plant":"dry","tree":"bare","keep":.22},
	"jg_pass":{"ground":"838e89","road":"b2ad96","width":112.0,"plant":"shale","tree":"weathered","keep":.17},
	"jg_rearguard":{"ground":"8e9183","road":"b0a58b","width":112.0,"plant":"yard","tree":"bare","keep":.19},
	"jg_bridge":{"ground":"87958f","road":"b7ad94","width":112.0,"plant":"shale","tree":"weathered","keep":.15},
	"jg_final":{"ground":"989885","road":"b6ad94","width":106.0,"plant":"dry","tree":"bare","keep":.10},
	"cc_outer":{"ground":"354c59","road":"63777d","width":125.0,"plant":"yard","tree":"bare","keep":0.0},
	"cc_beacon":{"ground":"334b5b","road":"687e84","width":136.0,"plant":"yard","tree":"bare","keep":0.0},
	"cc_street":{"ground":"394e5b","road":"687b81","width":145.0,"plant":"yard","tree":"bare","keep":0.0},
	"cc_store":{"ground":"40525b","road":"76817f","width":148.0,"plant":"yard","tree":"bare","keep":0.0},
	"cc_bastion":{"ground":"334957","road":"62757e","width":142.0,"plant":"yard","tree":"bare","keep":0.0},
	"cc_final":{"ground":"354a58","road":"6b7b81","width":142.0,"plant":"yard","tree":"bare","keep":0.0}
}

static func profile(stage: String) -> Dictionary:
	return PROFILES.get(stage,PROFILES.mountain)

static func keep_tree(stage: String,p: Vector2,seed_value: int) -> bool:
	var chance=float(profile(stage).keep)
	# Houses and drill grounds have cleared interiors; vegetation belongs at
	# their margins. The same source candidate consumes the same old RNG draws.
	if stage in ["village","house","hs_camp","hs_final"]:
		if p.x<140 or p.x>1480 or p.y<120 or p.y>1010: chance+=.22
		elif stage=="village" and p.x>350 and p.x<1250 and p.y>340 and p.y<940: chance*=.2
		elif stage=="house" and p.x>800 and p.y<750: chance*=.15
	return float(posmod(seed_value,1000))/1000.0<chance

static func _oval(canvas: Node2D,p: Vector2,r: float,squash: float,c: Color) -> void:
	canvas.draw_set_transform(p,0,Vector2(1,squash))
	canvas.draw_circle(Vector2.ZERO,r,c)
	canvas.draw_set_transform(Vector2.ZERO)

static func ground(canvas: Node2D,stage: String,grain: Array,pools: Array) -> void:
	var material=profile(stage); var base=Color(material.ground)
	# Broad ground stays quieter than actor silhouettes and local authored
	# surfaces. Strong grass/leaf detail belongs to clumps, not every pixel.
	var strength={"temple":.28,"hs_forest":.28,"hs_return":.36,"village":.34,"house":.34,"hs_camp":.34,"hs_final":.34}.get(stage,.40)
	if stage.begins_with("jg_"): strength=.34
	if stage.begins_with("cc_"): strength=.25
	if Painted.paint(canvas,PackedVector2Array([Vector2.ZERO,Vector2(1600,0),Vector2(1600,1100),Vector2(0,1100)]),Painted.ground_kind(stage),base,stage,0.0,strength): return
	canvas.draw_rect(Rect2(0,0,1600,1100),base)
	# Broad quiet masses; fine marks accumulate in believable strips, not an
	# evenly scattered carpet of identical V-shaped grass or polygon confetti.
	for pool in pools:
		var edge=PackedVector2Array()
		for i in range(22):
			var angle=i*TAU/22.0; var r=pool.r*(1+sin(i*1.4+pool.pos.x*.01)*.08)
			edge.append(pool.pos+Vector2(cos(angle)*r,sin(angle)*r*.48))
		var tint=base.darkened(.22) if pool.light<.5 else base.lightened(.20)
		tint.a=.14 if material.plant in ["bamboo","shale"] else .11
		canvas.draw_colored_polygon(edge,tint)
	for g in grain:
		var p: Vector2=g.pos
		if stage=="bridge" and p.y<310: continue
		if g.distance<float(material.width)*.58: continue
		var cluster=sin(p.x*.013+sin(p.y*.019)*2.6)*cos(p.y*.009-p.x*.002)
		if g.light>.58:
			_oval(canvas,p,g.size*.28,.48,Color(base.darkened(.18),.18))
		match material.plant:
			"yard":
				if g.light<.93: continue
				canvas.draw_line(p,p+Vector2(g.size*1.3,-.8),Color(base.darkened(.24),.24),1,true)
			"shale":
				if g.light<.65 or cluster<.05: continue
				canvas.draw_polyline(PackedVector2Array([p+Vector2(-g.size*2,1),p,p+Vector2(g.size*1.5,-2)]),Color(base.darkened(.25),.24),1,true)
			"moss":
				if cluster<.2 or g.light<.64: continue
				_oval(canvas,p,g.size*.8,.34,Color("76846b",.24))
			"bamboo":
				if cluster<-.1 or g.light<.68: continue
				var direction=Vector2(.8,-.45 if int(p.x)%3 else .34)
				canvas.draw_line(p,p+direction*g.size*1.6,Color("c0bd89",.29),1.5,true)
				if g.light>.9: canvas.draw_line(p+Vector2(4,3),p+Vector2(2,-2),Color("354d3e",.35),1.2,true)
			"stubble":
				if g.light<.79 or cluster<.1: continue
				for i in range(2): canvas.draw_line(p+Vector2(i*3,0),p+Vector2(i*3-1,-g.size*.65),Color("7a7655",.34),1.2,true)
			"bank":
				if g.light<.87: continue
				_oval(canvas,p,g.size*.6,.36,Color(base.darkened(.20),.34))
				canvas.draw_line(p+Vector2(-2,-1),p+Vector2(1,-1.7),Color(base.lightened(.25),.4),1,true)
			_:
				if cluster<.12 or g.light<.72: continue
				canvas.draw_line(p,p+Vector2(-2,-g.size),Color("746c50",.38),1.2,true)
				if g.light>.87: canvas.draw_line(p+Vector2(2,0),p+Vector2(4,-g.size*.7),Color("cdc19a",.48),1,true)

static func roads(canvas: Node2D,stage: String,definition: Dictionary) -> void:
	var material=profile(stage); var color=Color(material.road)
	if Painted.available(): color=color.lightened(.055 if stage in ["village","house"] else .035 if stage=="hs_return" else .025)
	for path in definition.roads:
		var width=float(material.width)
		if path in definition.get("secondary_roads",[]): width*=.68
		# A strip follows each surveyed road, with worn uneven shoulders. All
		# joins stay filled; source coordinates remain the navigation authority.
		for segment in range(1,path.size()):
			var a=Vector2(path[segment-1][0],path[segment-1][1]); var b=Vector2(path[segment][0],path[segment][1])
			var normal=(b-a).normalized().orthogonal(); var count=maxi(2,int(a.distance_to(b)/24.0))
			var left=PackedVector2Array(); var right=PackedVector2Array()
			for i in range(count+1):
				var t=float(i)/count; var p=a.lerp(b,t)
				var wear=sin(p.x*.027+p.y*.019)*3.5+sin(p.y*.067)*1.3
				left.append(p+normal*(width*.5+wear)); right.append(p-normal*(width*.5-wear*.7))
			var strip=left.duplicate(); var reverse=right.duplicate(); reverse.reverse(); strip.append_array(reverse)
			var painted=Painted.paint(canvas,strip,Painted.road_kind(stage),color,stage,9.0,.42)
			if painted:
				Painted.circle(canvas,a,width*.47,Painted.road_kind(stage),color,stage,9.0,.42)
				Painted.circle(canvas,b,width*.47,Painted.road_kind(stage),color,stage,9.0,.42)
			else:
				canvas.draw_colored_polygon(strip,color)
				canvas.draw_circle(a,width*.47,color); canvas.draw_circle(b,width*.47,color)
				canvas.draw_polyline(left,Color(color.darkened(.23),.28),4,true)
				canvas.draw_polyline(right,Color(color.darkened(.21),.24),3,true)
			for i in range(count):
				var p=a.lerp(b,(i+.5)/count)
				# Ruts tell the freight routes; pedestrian and sacred paths have
				# no ornamental twin rail lines.
				if stage in ["fork","hs_grain","hs_return","hs_camp","hs_river"] and i%6!=0:
					for side in [-1,1]:
						var rut=p+normal*(side*20+sin(p.y*.02)*2)
						canvas.draw_line(rut,rut+(b-a).normalized()*19,Color(color.darkened(.37),.25),2.4,true)
				elif not painted and stage in ["mountain","hs_forest"] and i%3==0:
					_oval(canvas,p+normal*sin(i*2.4)*17,7,.35,Color(color.darkened(.17),.27))
				if not painted and i%4==0:
					var shoulder=p+normal*(1 if i%8==0 else -1)*(width*.47)
					canvas.draw_line(shoulder,shoulder+(b-a).normalized()*9,Color(color.lightened(.17),.36),2,true)
