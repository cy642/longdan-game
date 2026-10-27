extends RefCounted
## Continuous articulation of the original Zhao Yun paintings. This is not a
## replacement frame sheet: head, shoulders and the complete spear stay rigid,
## while the pelvis and two leg regions exchange a small ground-relative step.
static var cache: Dictionary = {}

static func smooth_weight(value: float) -> float:
	var t=clampf(value,0,1)
	return t*t*(3.0-2.0*t)

static func profile(key: String, index: int, meta: Dictionary) -> Dictionary:
	var size=Vector2(meta.region[2],meta.region[3])
	var anchor=Vector2(meta.anchor[0],meta.anchor[1])
	# Splits sit between the two painted greaves, not at the spear/cloth bbox.
	var splits={0:108.0,2:146.0,4:145.0,6:111.0,8:113.0,10:160.0,12:164.0}
	var split=float(splits.get(index,anchor.x)) if key=="walk" else anchor.x
	var hip=Vector2(anchor.x,size.y*.72)
	var weapons: Array[Rect2]=[]
	# The down-facing lance heads extend below the boot line. They must not
	# inherit a leg's bend, even though they overlap its lower half of the image.
	if key=="attack":
		if index==1: weapons.append(Rect2(.16,.49,.29,.51))
		elif index==3: weapons.append(Rect2(.57,.53,.43,.47))
		elif index==15: weapons.append(Rect2(0,.53,.40,.47))
	# The remaining authored lances lie above the leg hinge and share the
	# same upper transform automatically. The cape remains attached at its root.
	return {"size":size,"anchor":anchor,"hip":hip-anchor,"split":split,
		"leg_start":.72,"leg_end":.97,"head":Rect2(0,0,1,.62),"weapons":weapons}

static func build(key: String, index: int, atlas: Dictionary) -> Dictionary:
	var id=key+":"+str(index)
	if cache.has(id): return cache[id]
	var meta: Dictionary=atlas.frames[index]
	var info=profile(key,index,meta); var size: Vector2=info.size; var anchor: Vector2=info.anchor
	var xs: Array=[0.0,size.x]; var ys: Array=[0.0,size.y]
	for x in range(1,11): xs.append(size.x*x/11.0)
	for y in [.25,.50,.60,.67,.72,.78,.84,.90,.95,.97]: ys.append(size.y*y)
	for x in [info.split-6,info.split,info.split+6,anchor.x]:
		if x>0 and x<size.x and not xs.has(x): xs.append(x)
	if anchor.y>0 and anchor.y<size.y and not ys.has(anchor.y): ys.append(anchor.y)
	var holes: Array[Rect2]=[]
	for values in meta.get("exclude",[]):
		var hole=Rect2(values[0],values[1],values[2],values[3]); holes.append(hole)
		for x in [hole.position.x,hole.end.x]:
			if not xs.has(x): xs.append(x)
		for y in [hole.position.y,hole.end.y]:
			if not ys.has(y): ys.append(y)
	for weapon in info.weapons:
		for x in [weapon.position.x*size.x,weapon.end.x*size.x]:
			if not xs.has(x): xs.append(x)
		for y in [weapon.position.y*size.y,weapon.end.y*size.y]:
			if not ys.has(y): ys.append(y)
	xs.sort(); ys.sort()
	var rest=PackedVector2Array(); var uv=PackedVector2Array(); var weights: Array=[]
	var head_indices=PackedInt32Array(); var weapon_indices=PackedInt32Array(); var boot_indices=PackedInt32Array()
	var polygons: Array[PackedInt32Array]=[]; var origin=Vector2(meta.region[0],meta.region[1])
	for y in ys:
		for x in xs:
			var p=Vector2(x,y); var n=p/size; var protected=n.y<=.67
			var weapon=false
			for bounds in info.weapons:
				if bounds.grow(.00001).has_point(n): weapon=true
			var leg=clampf((x-float(info.split))/6.0,-1,1)
			var lower=0.0 if protected or weapon else smooth_weight((n.y-info.leg_start)/(info.leg_end-info.leg_start))
			var upper=1.0-lower
			var index_in_grid=rest.size()
			if info.head.has_point(n): head_indices.append(index_in_grid)
			if protected or weapon: weapon_indices.append(index_in_grid)
			if y>=anchor.y-4 and lower>.98: boot_indices.append(index_in_grid)
			rest.append(p-anchor); uv.append(p+origin); weights.append(Vector3(upper,lower,leg))
	for y in range(ys.size()-1):
		for x in range(xs.size()-1):
			var midpoint=Vector2((xs[x]+xs[x+1])*.5,(ys[y]+ys[y+1])*.5); var excluded=false
			for hole in holes:
				if hole.has_point(midpoint): excluded=true; break
			if excluded: continue
			var i=y*xs.size()+x
			polygons.append(PackedInt32Array([i,i+1,i+xs.size()+1,i+xs.size()]))
	info.merge({"rest":rest,"uv":uv,"weights":weights,"polygons":polygons,
		"head_indices":head_indices,"weapon_indices":weapon_indices,"boot_indices":boot_indices,
		"texture":load(atlas.file),"holes":holes})
	cache[id]=info
	return info

static func sample(actor, move_amount: float) -> Dictionary:
	var direction=Vector2.from_angle(actor.facing)
	var phase=actor.walk_distance/actor.HERO_STEP_DISTANCE*PI
	var step=sin(phase)
	var pose={"angle":step*.018*move_amount,"shift":Vector2(step*.65,absf(step)*.28)*move_amount,
		"stride":step*3.6*move_amount,"lift":.8*move_amount,"gait":phase}
	if not actor.action.is_empty():
		pose.stride=0.0; pose.lift=0.0
		var a: Dictionary=actor.action; var d: Dictionary=a.def
		if a.key=="heal":
			var settle=smooth_weight(minf(a.t/.18,1.0))*smooth_weight(minf((d.windup+d.active+d.recovery-a.t)/.18,1.0))
			pose.angle=.025*settle; pose.shift=Vector2(0,.9*settle)
		else:
			var wind=maxf(.001,d.windup); var active=maxf(.001,d.active); var recovery=maxf(.001,d.recovery)
			var load_amount=smooth_weight(a.t/wind)
			var release=smooth_weight((a.t-wind)/minf(.045,active*.45))
			var settle=1.0-smooth_weight((a.t-wind-active)/recovery)
			var force=1.24 if a.key in ["thrust3","counter","sweep","huilan","sword"] else 1.0
			var reach=lerpf(-2.5*load_amount,5.0*force,release)*settle
			pose.angle=lerpf(-.036*load_amount,.052*force,release)*settle*direction.x
			pose.shift=Vector2(direction.x*reach,direction.y*reach*.28+lerpf(1.1*load_amount,.25,release)*settle)
			if a.key in ["thrust2","sweep","huilan","sword"]:
				pose.angle+=sin(release*PI)*.035*settle
	elif actor.dash_left>0:
		pose.angle=.075*direction.x; pose.shift=Vector2(direction.x*2.2,1.2)
		pose.stride=step*1.4; pose.lift=0.0
	if actor.hurt_flash>0 and actor.hp>0:
		var recoil=sin(clampf(actor.hurt_flash/.22,0,1)*PI)
		pose.shift-=Vector2(direction.x*2.3,direction.y*.65)*recoil
		pose.angle-=direction.x*.025*recoil
	return pose

static func upper_transform(data: Dictionary, pose: Dictionary, density: float) -> Transform2D:
	var upper=Transform2D(pose.angle,Vector2.ZERO); var hip: Vector2=data.hip
	upper.origin=hip-upper*hip+pose.shift/maxf(.001,density)
	return upper

static func deform(data: Dictionary, pose: Dictionary, density: float) -> PackedVector2Array:
	var points: PackedVector2Array=data.rest.duplicate()
	var upper=upper_transform(data,pose,density)
	for i in range(points.size()):
		var p=points[i]; var w: Vector3=data.weights[i]
		if w.x>0: p=p.lerp(upper*p,w.x)
		if w.y>0:
			p.x+=pose.stride*w.z*w.y/density
			p.y-=maxf(0,sin(pose.gait)*w.z)*pose.lift*w.y/density
		points[i]=p
	return points

static func snapshot_mesh(data: Dictionary, points: PackedVector2Array) -> ArrayMesh:
	var texture: Texture2D=data.texture; var normalized_uv=PackedVector2Array()
	for p in data.uv: normalized_uv.append(p/texture.get_size())
	var indices=PackedInt32Array()
	for polygon in data.polygons:
		indices.append_array(PackedInt32Array([polygon[0],polygon[1],polygon[2],polygon[0],polygon[2],polygon[3]]))
	var arrays: Array=[]; arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX]=points; arrays[Mesh.ARRAY_TEX_UV]=normalized_uv; arrays[Mesh.ARRAY_INDEX]=indices
	var mesh=ArrayMesh.new(); mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
	return mesh
