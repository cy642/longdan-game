extends SceneTree
## Bounds and determinism of chapter-specific scenery. No campaign or user saves.
const Atmosphere=preload("res://scripts/map_atmosphere.gd")
const Game=preload("res://scripts/world.gd")
const Campaign=preload("res://scripts/campaign.gd")
class MemoryCampaign extends Campaign:
	func read_save() -> Dictionary: return {}
	func save() -> bool: return true
class ReviewWorld extends Node2D:
	var definition: Dictionary={}
	var mode="playing"
	var camera=Camera2D.new()
	var rng=RandomNumberGenerator.new()
	func _ready() -> void:
		camera.enabled=false; add_child(camera); rng.seed=83781
var checks=0
var failures: Array=[]

func _initialize() -> void: call_deferred("run")
func expect(ok: bool,label: String) -> void:
	checks+=1
	if not ok: failures.append(label); push_error("THEME_ATMOSPHERE_FAIL "+label)

func run() -> void:
	var review=ReviewWorld.new(); root.add_child(review)
	var source={}
	for chapter in [1,2]:
		var data=JSON.parse_string(FileAccess.get_file_as_string("res://data/chapter"+str(chapter)+".json"))
		source.merge(data.StageDefinition)
	var trees=[{"pos":Vector2(220,280)},{"pos":Vector2(1180,810)},{"pos":Vector2(760,160)}]
	for id in source:
		review.definition=source[id]
		var atmosphere=Atmosphere.new(); review.add_child(atmosphere); atmosphere.set_process(false)
		var combat_rng=review.rng.state
		atmosphere.configure(review,id,trees,int(source[id].seed))
		expect(review.rng.state==combat_rng,id+" decoration leaves combat RNG unchanged")
		expect(atmosphere.leaves.size()<=14 and atmosphere.drift.size()<=18,id+" small scenery arrays are bounded")
		expect(atmosphere.ripples.size()<=48 and atmosphere.reeds.size()<=32,id+" shoreline work is bounded")
		expect(atmosphere.get_child_count()==0,id+" no fullscreen texture or particle node")
		expect(atmosphere.theme==("hanshui_mist" if id.begins_with("hs_") else "changban_dust"),id+" chooses the chapter theme")
		var leaf_sample=atmosphere.leaves.duplicate(true)
		var drift_sample=atmosphere.drift.duplicate(true)
		var water_sample=atmosphere.ripples.duplicate(true)
		atmosphere.configure(review,id,trees,int(source[id].seed))
		expect(atmosphere.leaves==leaf_sample and atmosphere.drift==drift_sample and atmosphere.ripples==water_sample,id+" reconfiguration is deterministic and does not accumulate particles")
		var old_clock=atmosphere.clock
		for mode in ["map","paused","dialogue","menu"]:
			review.mode=mode; atmosphere._process(2)
			expect(atmosphere.clock==old_clock,id+" stops outside gameplay: "+mode)
		review.mode="playing"; atmosphere._process(.1)
		expect(atmosphere.clock>old_clock,id+" atmosphere moves while playing")
		if id.begins_with("hs_"):
			var water: Array=source[id].layout.get("water",[])
			expect(atmosphere.ripples.is_empty()==water.is_empty(),id+" ripples exist exactly where its own layout contains water")
			expect(atmosphere.leaf_color.b>atmosphere.leaf_color.r,id+" bamboo leaf palette is cool")
			for ripple in atmosphere.ripples:
				for seconds in [0.0,.5,60.0,3600.0,86400.0]:
					var p: Vector2=atmosphere.river_position(ripple,seconds)
					var end=Vector2(minf(p.x+ripple.width,ripple.area.end.x),p.y-1)
					var inside=false
					for rect in water:
						var area=Rect2(rect[0],rect[1],rect[2],rect[3])
						if area.has_point(p) and area.has_point(end) and area.has_point(p+Vector2(4,4)): inside=true
					expect(inside,id+" animated water strokes and shadows stay within real water at "+str(seconds))
		else:
			expect(atmosphere.leaf_color.r>atmosphere.leaf_color.b,id+" Changban foliage remains warm")
			expect(atmosphere.ripples.is_empty() or id=="bridge",id+" land has no misplaced river glints")
		atmosphere.queue_free(); await process_frame
	# Empty-tree maps still have finite atmosphere and can be configured twice.
	review.definition=source.hs_final
	var empty=Atmosphere.new(); review.add_child(empty)
	empty.configure(review,"hs_final",[],21906)
	expect(empty.leaves.is_empty(),"treeless iron camp has no leaves from another chapter")
	expect(not empty.ripples.is_empty(),"treeless iron camp still animates its actual northern water")
	empty.queue_free(); review.queue_free(); await process_frame
	await verify_camp_camera()
	print("THEME_ATMOSPHERE_VERIFY ",checks," checks; ",failures.size()," failures")
	quit(0 if failures.is_empty() else 1)

func verify_camp_camera() -> void:
	var game=Game.new(); game.test_mode=true; game.state=MemoryCampaign.new()
	root.add_child(game); game.set_process(false); game.set_physics_process(false)
	await process_frame
	game.state.reset("normal",2); game.load_chapter(2); game.mode="playing"
	game.enter_stage("hs_camp",Vector2(820,530),false); game.ui.hide_overlay()
	expect(is_instance_valid(game.tactics),"camera regression uses the real camp director")
	for phase in ["PREPARE","PROBE_1","PROBE_2","WITHDRAW","BEST_WINDOW","LATE_WINDOW","COUNTER","COUNTER_DIRECT"]:
		game.tactics.gate_state=phase
		for dt in [.016,.1,.6]:
			game._process(dt)
			expect(game.camera.zoom.is_equal_approx(Vector2(1.15,1.15)),phase+" keeps Zhao Yun at the fixed world scale after "+str(dt)+" seconds")
	game.camera.zoom=Vector2(1.05,1.05)
	game._process(.016)
	expect(game.camera.zoom.is_equal_approx(Vector2(1.15,1.15)),"legacy retreat camera zoom is corrected in one frame")
	for mode in ["paused","map","playing"]:
		game.mode=mode; game._process(.016)
		expect(game.camera.zoom.is_equal_approx(Vector2(1.15,1.15)),mode+" does not change actor scale")
	game.queue_free(); await process_frame
