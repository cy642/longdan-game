extends SceneTree
## Real hero geometry, original opaque boot pixels, and unchanged damage clocks.
## Does not render or read/write any player save. GPU review is separate.
const Hero=preload("res://scripts/hero.gd")
const Motion=preload("res://scripts/hero_motion.gd")
class Fixture extends Node2D:
	var state={"flags":{"adou":false}}
var checks=0
var failures: Array=[]
var boot_samples: Dictionary={}

func _initialize() -> void: call_deferred("run")
func expect(value: bool,message: String) -> void:
	checks+=1
	if not value: failures.append(message); push_error("HERO_MOTION: "+message)

func sample_source(data: Dictionary,points: PackedVector2Array,source: Vector2) -> Vector2:
	var local=source-data.anchor
	for polygon in data.polygons:
		var a: Vector2=data.rest[polygon[0]]; var c: Vector2=data.rest[polygon[2]]
		if local.x<a.x-.001 or local.x>c.x+.001 or local.y<a.y-.001 or local.y>c.y+.001: continue
		var u=clampf((local.x-a.x)/(c.x-a.x),0,1); var v=clampf((local.y-a.y)/(c.y-a.y),0,1)
		# Same diagonal as the immutable afterimage mesh: [0,1,2] / [0,2,3].
		if u>=v: return points[polygon[0]]*(1-u)+points[polygon[1]]*(u-v)+points[polygon[2]]*v
		return points[polygon[0]]*(1-v)+points[polygon[2]]*u+points[polygon[3]]*(v-u)
	return Vector2.INF

func actual_boot_pixels(visual) -> PackedVector2Array:
	var key=str(visual.last_frame[0])+":"+str(visual.last_frame[1])
	if boot_samples.has(key): return boot_samples[key]
	var meta: Dictionary=visual.atlas_data[visual.last_frame[0]].frames[visual.last_frame[1]]
	var texture: Texture2D=load(visual.atlas_data[visual.last_frame[0]].file)
	var image=texture.get_image()
	var result=PackedVector2Array(); var data: Dictionary=visual.hero_rig_data
	for y in range(maxi(0,int(meta.anchor[1])-6),mini(meta.region[3],int(meta.anchor[1])+3)):
		for x in range(meta.region[2]):
			if image.get_pixel(meta.region[0]+x,meta.region[1]+y).a<.86: continue
			var p=Vector2(x+.5,y+.5); var excluded=false
			for hole in data.holes:
				if hole.has_point(p): excluded=true
			for weapon in data.weapons:
				if weapon.has_point(p/data.size): excluded=true
			if not excluded: result.append(p)
	boot_samples[key]=result
	return result

func check_protected(visual,title: String) -> void:
	var data: Dictionary=visual.hero_rig_data; var points: PackedVector2Array=visual.hero_rig.polygon
	var upper=Motion.upper_transform(data,visual.hero_pose,visual.current_scale)
	var max_error=0.0
	for i in data.head_indices: max_error=maxf(max_error,points[i].distance_to(upper*data.rest[i]))
	expect(max_error<.0002,title+" painted face/hair retain one rigid transform")
	max_error=0.0
	for i in data.weapon_indices: max_error=maxf(max_error,points[i].distance_to(upper*data.rest[i]))
	expect(max_error<.0002,title+" whole spear stays rigid with the shoulder")
	expect(visual.position==Vector2.ZERO and visual.rotation==0 and visual.scale==Vector2.ONE,title+" never moves or scales the root away from its shadow")
	expect(visual.hero_rig.scale==visual.body.scale and is_equal_approx(visual.current_scale,.34),title+" keeps original density and mirror")
	var pixels=actual_boot_pixels(visual)
	expect(not pixels.is_empty(),title+" has original opaque boot samples")
	var bottom=-INF; var baseline=-INF; var all_covered=true
	for source in pixels:
		var sample=sample_source(data,points,source)
		all_covered=all_covered and sample.is_finite()
		baseline=maxf(baseline,(source.y-data.anchor.y)*visual.current_scale)
		bottom=maxf(bottom,sample.y*visual.current_scale)
	expect(all_covered,title+" all real opaque boot pixels remain inside drawable geometry")
	expect(absf(bottom-baseline)<1.1,title+" actual boot support stays within 1.1 game-space pixels at unit actor scale")

func run() -> void:
	var fixture=Fixture.new(); root.add_child(fixture)
	var hero=Hero.new(); hero.world=fixture; fixture.add_child(hero)
	var visual=hero.visual
	for direction in range(8):
		hero.facing=direction*PI/4; hero.hp=200; hero.action={}; hero.dash_left=0; hero.hurt_flash=0
		hero.moving=false; hero.walk_distance=0; visual.hero_move_amount=0; hero.update_visual()
		expect(visual.hero_rig!=null and visual.hero_rig.visible and not visual.body.visible,"direction %d uses the production hero mesh"%direction)
		check_protected(visual,"idle %d"%direction)
		var base=visual.hero_rig.polygon.duplicate(); var original_texture=visual.body.texture
		var largest_leg_change=0.0
		for step in range(17):
			hero.moving=true; hero.walk_distance=hero.HERO_STEP_DISTANCE*2*step/16.0
			visual.hero_move_amount=1; hero.update_visual()
			expect(visual.body.texture==original_texture,"walking keeps the same anatomical painting instead of popping its face per step")
			check_protected(visual,"walk %d:%d"%[direction,step])
			for i in visual.hero_rig_data.boot_indices:
				largest_leg_change=maxf(largest_leg_change,base[i].distance_to(visual.hero_rig.polygon[i])*visual.current_scale)
		expect(largest_leg_change>3.0,"direction %d visibly articulates greaves independently of the head"%direction)
		# Stopping is timed by real simulation updates; a paused refresh cannot
		# advance the response, and the root never gets a stop/start height bob.
		hero.moving=false
		visual.advance_time(1.0/60); hero.update_visual(); var first_stop=visual.hero_move_amount
		hero.update_visual(); expect(is_equal_approx(first_stop,visual.hero_move_amount),"repeated pose refresh without a tick cannot consume extra smoothing")
		for i in range(30): visual.advance_time(1.0/60); hero.update_visual()
		expect(first_stop>0 and first_stop<1 and visual.hero_move_amount<.001,"direction %d settles a stop without instantaneous whole-body sway"%direction)
		for kind in ["thrust1","thrust2","thrust3","counter","sweep","sword"]:
			var definition={"windup":.13,"active":.15,"recovery":.2}
			hero.action={"key":kind,"dir":hero.facing,"id":111,"t":0.0,"def":definition.duplicate(true)}
			for time in [.0,.06,.1299,.13,.1301,.17,.28,.35,.46,.4799]:
				hero.action.t=time; hero.update_visual(); check_protected(visual,"%s %d %.4f"%[kind,direction,time])
				expect(hero.action.def==definition and hero.action.t==time,"visual action sampling leaves live attack definition and clock untouched")
			# Continuous deformation values bracket each authored timing boundary.
			for boundary in [.13,.28,.48]:
				hero.action.t=boundary-.00001; var before=Motion.sample(hero,0)
				hero.action.t=boundary+.00001; var after=Motion.sample(hero,0)
				expect(before.shift.distance_to(after.shift)<.02 and absf(before.angle-after.angle)<.001,"%s %d has no procedural impulse jump at %.2f"%[kind,direction,boundary])
		# Downward lance / neighboring-frame geometry is protected by exact
		# original exclusions, including the formerly floating duplicate tip.
		for key in ["walk","attack"]:
			for index in range(visual.atlas_data[key].frames.size()):
				var data=Motion.build(key,index,visual.atlas_data[key])
				for polygon in data.polygons:
					var midpoint=Vector2.ZERO
					for i in polygon: midpoint+=data.uv[i]-Vector2(visual.atlas_data[key].frames[index].region[0],visual.atlas_data[key].frames[index].region[1])
					midpoint/=polygon.size()
					for hole in data.holes: expect(not hole.has_point(midpoint),"hero mesh cannot reintroduce excluded neighboring pixels")
	# Snapshot must be immutable while the next motion tick changes the rig.
	hero.action={}; hero.moving=true; hero.walk_distance=28; visual.hero_move_amount=1; hero.update_visual()
	var snapshot=visual.hero_snapshot(); var saved=snapshot.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX].duplicate()
	hero.walk_distance+=38; hero.update_visual()
	expect(snapshot.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]==saved,"afterimage owns a frozen mesh rather than following the live next step")
	expect(snapshot.transform==visual.hero_rig.transform,"afterimage scale and mirroring use the actual rig transform")
	hero.hp=0; hero.update_visual()
	expect(visual.body.visible and not visual.hero_rig.visible and visual.hero_snapshot().is_empty(),"death returns to its calibrated original reaction painting")
	fixture.queue_free(); await process_frame
	print("HERO_MOTION_VERIFY ",checks," checks; ",failures.size()," failures; original_boot_pixel_frames=",boot_samples.size())
	quit(0 if failures.is_empty() else 1)
