extends SceneTree
## Real world scene and authored data; no player saves or graphical benchmark.
const Game=preload("res://scripts/world.gd")
const Campaign=preload("res://scripts/campaign.gd")
const Presentation=preload("res://scripts/changban_presentation.gd")
const Details=preload("res://scripts/map_details.gd")
class MemoryCampaign extends Campaign:
	var save_calls=0
	func read_save() -> Dictionary: return {}
	func save() -> bool: save_calls+=1; return true
var world
var checks=0
var failures: Array=[]

func _initialize() -> void: call_deferred("run")
func expect(ok: bool,message: String) -> void:
	checks+=1
	if not ok: failures.append(message); push_error("CHANGBAN_PRESENTATION: "+message)

func run() -> void:
	world=Game.new(); world.test_mode=true; world.state=MemoryCampaign.new(); root.add_child(world)
	world.set_process(false); world.set_physics_process(false)
	await process_frame
	var themes: Dictionary={}
	for id in Presentation.STAGES:
		world.state.reset("normal",1); world.load_chapter(1); world.mode="playing"
		world.hero.reset_combat(); world.enter_stage(id,Vector2.INF,false)
		await process_frame; await physics_frame; await process_frame
		var presentation=world.chapter_presentation
		expect(is_instance_valid(presentation),id+" production entry creates its presentation")
		if not is_instance_valid(presentation): continue
		var attached=0
		for child in world.actors.get_children():
			if child.get_script()==Presentation: attached+=1
		expect(attached==1,id+" re-entry has one presentation, never stacked copies")
		var data: Dictionary=world.definition.map_details
		if id=="mountain":
			var cairn=world.actors.get_node("Landmark_ridge_cairn")
			var sprite: Sprite2D=cairn.rendered_prop
			expect(sprite!=null and sprite.texture!=null and sprite.texture.resource_path=="res://assets/props/stela.png","ridge waystone uses the shipped detailed stone image at runtime")
			if sprite!=null:
				expect(sprite.scale.is_equal_approx(Vector2.ONE*.4) and sprite.position.is_equal_approx(Vector2(-30.4,-68.8)),"ridge stone retains its original height and aligned image foot")
			var shapes: Array=cairn.landmark.colliders
			var circle: Array=shapes[0].get("circle",[]) if shapes.size()==1 else []
			expect(cairn.position==Vector2(650,738) and circle.size()==3 and float(circle[0])==0 and float(circle[1])==0 and float(circle[2])==18,"ridge stone retains its logical anchor and 18px circular footprint")
		expect(presentation.enabled,id+" enables first-chapter atmosphere")
		expect(not presentation.theme.is_empty() and not themes.has(presentation.theme),id+" owns a distinct authored motif")
		themes[presentation.theme]=true
		expect(presentation.particles.size()>0 and presentation.particles.size()<=Presentation.MAX_PARTICLES,id+" finite locally authored effect budget")
		expect(presentation.z_index<world.actors.z_index,id+" atmosphere stays beneath actors and attacks")
		expect(not presentation.is_processing(),id+" only the guarded world clock advances presentation")
		expect(presentation.get_child_count()==0,id+" adds no hidden physics bodies, shadow lights or inputs")
		var combat_random_state=world.rng.state
		var old_particles=JSON.stringify(presentation.particles)
		presentation.setup(world)
		expect(world.rng.state==combat_random_state and JSON.stringify(presentation.particles)==old_particles,id+" deterministic setup never consumes combat randomness")
		for patch in data.story_materials:
			var polygon=Details._points(patch.polygon)
			expect(polygon.size()>=3 and not Geometry2D.triangulate_polygon(polygon).is_empty(),id+" material patch triangulates")
			for p in polygon: expect(Rect2(0,0,1600,1100).has_point(p),id+" story material stays within the map")
		var before=JSON.stringify(world.state.snapshot(),"",true)
		var saves=int(world.state.save_calls)
		presentation.advance(.4)
		expect(is_equal_approx(presentation.clock,.4),id+" advances during active gameplay")
		expect(JSON.stringify(world.state.snapshot(),"",true)==before and world.state.save_calls==saves,id+" visual advance never writes campaign or save")
		var motion=0
		for particle in presentation.particles:
			var first=presentation.particle_position(particle,0.0)
			var second=presentation.particle_position(particle,2.0)
			if first.distance_to(second)>.01: motion+=1
			for time in [0.0,.3,3.0,60.0,3600.0]:
				var p=presentation.particle_position(particle,time)
				expect(p.is_finite() and Rect2(0,0,1600,1100).has_point(p),id+" bounded local particle trajectory")
				if id=="bridge" and str(presentation.emitters[int(particle.emitter)].kind)=="water":
					expect(p.y<285 and (p.x<1170 or p.x>1370),"bridge glints never cross solid deck or dry bank")
		expect(motion>0,id+" motifs visibly move when world time advances")
		for mode in ["paused","map","dialog","dead","menu","ending"]:
			world.mode=mode; var old_clock=float(presentation.clock); var old_relief=float(presentation.relief_left)
			presentation.advance(.8)
			expect(presentation.clock==old_clock and presentation.relief_left==old_relief,id+" freezes on "+mode)
		world.mode="playing"; world.hero.hp=0; var old_clock=float(presentation.clock)
		presentation.advance(.8); expect(presentation.clock==old_clock,id+" also freezes during the lethal-hit boundary")
		world.hero.hp=world.hero.max_hp
		presentation.advance(INF); presentation.advance(-1)
		expect(presentation.clock==old_clock,id+" rejects nonfinite and negative clock input")
		world.hit_stop=.2; world._physics_process(.05)
		expect(presentation.clock==old_clock,id+" actual world hit-stop guard freezes atmosphere")
		world.hit_stop=0; world._physics_process(.05)
		expect(presentation.clock>old_clock,id+" actual world physics resumes the same presentation")
		if not presentation.milestone.is_empty():
			world.state.flags[presentation.milestone]=true
			presentation.advance(.1)
			expect(presentation.relief_count==1 and presentation.relief_left>0,id+" milestone emits one finite local beat")
			presentation.advance(3.0)
			expect(presentation.relief_count==1 and presentation.relief_left==0,id+" milestone does not loop")
			for emitter in presentation.emitters:
				expect(is_equal_approx(float(emitter.gain),presentation.target_gain(emitter)),id+" lamp or smoke settles to completed story state")
			presentation.setup(world); presentation.advance(.1)
			expect(presentation.relief_count==0,id+" loading completed milestone does not replay a reward pulse")
		await process_frame
	for chapter in [2,3,4]:
		world.state.reset("normal",chapter); world.load_chapter(chapter)
		world.enter_stage(Campaign.CHAPTER_STAGES[chapter][0],Vector2.INF,false)
		await process_frame
		expect(not is_instance_valid(world.chapter_presentation),"production later chapter "+str(chapter)+" removes the Changban presentation")
		var presentation=Presentation.new(); world.add_child(presentation); presentation.setup(world); presentation.advance(1.0)
		expect(not presentation.enabled and presentation.particles.is_empty() and presentation.clock==0,"later chapter "+str(chapter)+" remains untouched")
		presentation.queue_free(); await process_frame
	world.queue_free(); await process_frame; await process_frame
	print("CHANGBAN_PRESENTATION_VERIFY ",checks," checks; ",failures.size()," failures")
	quit(0 if failures.is_empty() else 1)
