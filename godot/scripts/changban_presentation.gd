extends Node2D
## Local authored atmosphere for the first chapter's quality slice. The world
## advances this after its pause / death / hit-stop guards. No own process loop,
## combat RNG, input, physics, new objectives or persistence lives here.
const STAGES=["mountain","village","temple","house","fork","bridge"]
const REDRAW_STEP=1.0/20.0
const MAX_PARTICLES=28
var world
var stage=""
var theme=""
var enabled=false
var clock=0.0
var redraw_left=0.0
var particles: Array=[]
var emitters: Array=[]
var milestone=""
var milestone_seen=false
var milestone_position=Vector2.ZERO
var relief_left=0.0
var relief_count=0

func setup(game) -> void:
	world=game; stage=str(world.stage); z_index=-2
	clock=0; redraw_left=0; relief_left=0; relief_count=0
	particles.clear(); emitters.clear()
	enabled=stage in STAGES and int(world.state.chapter)==1
	if not enabled: queue_redraw(); return
	var data: Dictionary=world.definition.get("map_details",{}).get("presentation",{})
	theme=str(data.get("theme","")); milestone=str(data.get("milestone",""))
	var position_values=data.get("landmark",[0,0])
	milestone_position=Vector2(position_values[0],position_values[1])
	milestone_seen=flag(milestone)
	var random=RandomNumberGenerator.new(); random.seed=int(world.definition.seed)+40091
	for source in data.get("emitters",[]):
		var emitter: Dictionary=source.duplicate(true)
		emitter["origin"]=Vector2(source.position[0],source.position[1])
		emitter["extent"]=Vector2(source.span[0],source.span[1])
		emitter["gain"]=target_gain(emitter)
		emitters.append(emitter)
		for slot in range(mini(8,int(source.get("count",1)))):
			if particles.size()>=MAX_PARTICLES: break
			particles.append({"emitter":emitters.size()-1,"phase":random.randf(),"side":random.randf_range(-1,1),"speed":random.randf_range(.065,.105),"size":random.randf_range(1.5,2.8),"slot":slot})
	queue_redraw()

func flag(key: String) -> bool:
	return not key.is_empty() and bool(world.state.flags.get(key,false))

func target_gain(emitter: Dictionary) -> float:
	if emitter.has("only_after") and not flag(str(emitter.only_after)): return 0.0
	if emitter.has("stop_after") and flag(str(emitter.stop_after)): return 0.0
	if emitter.has("dim_after") and flag(str(emitter.dim_after)): return .24
	if emitter.has("bright_after"): return 1.0 if flag(str(emitter.bright_after)) else .38
	return 1.0

func advance(dt: float) -> void:
	if not enabled or not is_instance_valid(world) or world.mode!="playing": return
	if is_instance_valid(world.hero) and world.hero.hp<=0: return
	if not is_finite(dt) or dt<=0: return
	clock+=dt
	for emitter in emitters:
		emitter.gain=move_toward(float(emitter.gain),target_gain(emitter),dt*.72)
	if not milestone_seen and flag(milestone):
		milestone_seen=true; relief_left=2.4; relief_count+=1
	relief_left=maxf(0,relief_left-dt)
	redraw_left-=dt
	if redraw_left<=0:
		redraw_left=REDRAW_STEP; queue_redraw()

func visible_bounds() -> Rect2:
	if not is_instance_valid(world) or not is_instance_valid(world.camera): return Rect2(0,0,1600,1100)
	var extent: Vector2=world.get_viewport_rect().size/world.camera.zoom
	return Rect2(world.camera.get_screen_center_position()-extent*.5,extent).grow(110)

func particle_position(particle: Dictionary,at_time: float) -> Vector2:
	var source: Dictionary=emitters[int(particle.emitter)]
	var span: Vector2=source.extent; var at: Vector2=source.origin
	var phase=fposmod(float(particle.phase)+at_time*float(particle.speed),1.0)
	match str(source.kind):
		"smoke": return at+Vector2(float(particle.side)*span.x+sin(phase*3.8+float(particle.phase)*TAU)*8,-phase*span.y)
		"ash": return at+Vector2(phase*span.x,-phase*span.y+sin(phase*PI)*5)
		"water": return at+Vector2((phase-.5)*span.x,float(particle.side)*span.y*.5)
		"lamp","cloth": return at
		_: return at+Vector2((phase-.5)*span.x,sin(phase*PI+float(particle.phase)*TAU)*span.y*.36)

func _draw() -> void:
	if not enabled: return
	var bounds=visible_bounds()
	# All marks sit beneath actors, telegraphs and interaction labels. No
	# fullscreen haze or vignette is added, and no point light adds a shadow pass.
	for particle in particles:
		var emitter: Dictionary=emitters[int(particle.emitter)]
		var gain=float(emitter.gain)
		if gain<=.005: continue
		var p=particle_position(particle,clock)
		if not bounds.has_point(p): continue
		var phase=fposmod(float(particle.phase)+clock*float(particle.speed),1.0)
		var fade=sin(phase*PI)*gain
		match str(emitter.kind):
			"smoke": _smoke(p,phase,fade,particle)
			"ash":
				var color=Color("c2b69c",fade*.30)
				draw_line(p,p+Vector2(3+sin(clock+float(particle.phase)*6)*2,-2),color,1.5,true)
			"lamp": _lamp(p,emitter.extent,gain)
			"water":
				var width=8+phase*16
				draw_set_transform(p,0,Vector2(1,.25))
				draw_arc(Vector2.ZERO,width,.12,PI*.88,14,Color("d4ded0",fade*.22),1.2,true)
				draw_set_transform(Vector2.ZERO)
			"cloth":
				var sway=sin(clock*1.6)*1.6
				draw_colored_polygon(PackedVector2Array([p+Vector2(-12,0),p+Vector2(10,-3+sway),p+Vector2(15,5),p+Vector2(-7,8)]),Color("d8cfad",gain*.55))
				draw_line(p+Vector2(-4,0),p+Vector2(4,5),Color("a1987d",gain*.4),1,true)
			"leaves":
				var direction=Vector2.from_angle(sin(clock*1.7+float(particle.phase)*TAU)*.7)
				var length=float(particle.size)*1.5
				var color=Color("a59465" if stage=="mountain" else "b3b48c" if stage=="temple" else "a6b093",fade*.48)
				draw_line(p-direction*length,p+direction*length,color,1.5,true)
			"chaff":
				draw_line(p,p+Vector2(4,1),Color("d1bd83",fade*.4),1.3,true)
			_:
				draw_line(p,p+Vector2(2,0),Color("e2d8b7",fade*.24),1.3,true)
	if relief_left>0 and bounds.has_point(milestone_position):
		var fade=relief_left/2.4; var radius=22+(1-fade)*54
		draw_set_transform(milestone_position,0,Vector2(1,.40))
		draw_arc(Vector2.ZERO,radius,.08,PI-.08,24,Color("e3d5a2",sin(fade*PI)*.24),1.5,true)
		draw_set_transform(Vector2.ZERO)

func _smoke(p: Vector2,phase: float,fade: float,particle: Dictionary) -> void:
	var radius=6+phase*13
	# Sparse overlapping soft-value shapes read as an off-road chimney trail;
	# low opacity and a single layer leave character silhouettes intact.
	var color=Color("5b6057" if stage=="fork" else "827d6e",fade*.048)
	draw_set_transform(p,0,Vector2(1.35,.85))
	draw_circle(Vector2.ZERO,radius,color)
	draw_circle(Vector2(radius*.48,-radius*.2),radius*.66,Color(color,color.a*.75))
	draw_circle(Vector2(-radius*.42,radius*.08),radius*.57,Color(color,color.a*.62))
	draw_set_transform(Vector2.ZERO)
	if stage=="fork" and phase<.28 and int(particle.slot)%2==0:
		draw_circle(p+Vector2(2,-4),1.5,Color("d5a06a",fade*.23))

func _lamp(p: Vector2,span: Vector2,gain: float) -> void:
	var flicker=1+sin(clock*2.4+p.x*.05)*.04
	draw_set_transform(p,0,Vector2(1,span.y/span.x))
	for layer_index in range(3,0,-1):
		draw_circle(Vector2.ZERO,span.x*(.52+layer_index*.16)*flicker,Color("ead49c",gain*(.015 if layer_index==3 else .022)))
	draw_set_transform(Vector2.ZERO)

func summary() -> Dictionary:
	var visible_count=0
	var bounds=visible_bounds()
	for particle in particles:
		if float(emitters[int(particle.emitter)].gain)>.005 and bounds.has_point(particle_position(particle,clock)): visible_count+=1
	return {"enabled":enabled,"stage":stage,"theme":theme,"clock":clock,"particles":particles.size(),"visible_particles":visible_count,"relief_count":relief_count,"relief_left":relief_left}
