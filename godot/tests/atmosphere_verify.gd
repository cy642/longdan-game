extends SceneTree
## Real nodes with isolated campaign state: art anchors, motion, focus and pause.
const Game = preload("res://scripts/world.gd")
const Campaign = preload("res://scripts/campaign.gd")
class MemoryCampaign extends Campaign:
	func read_save() -> Dictionary: return {}
	func save() -> bool: return true
var checks = 0
var failures: Array = []

func _initialize() -> void: call_deferred("run")
func expect(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures.append(label)
		push_error("ATMOSPHERE FAIL: "+label)

func run() -> void:
	var world = Game.new()
	world.test_mode = true
	world.state = MemoryCampaign.new()
	root.add_child(world)
	world.set_process(false); world.set_physics_process(false)
	await process_frame
	var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/props/landmarks.json")).props
	var modeled_count = 0
	for stage in ["mountain","village","temple","house","fork","bridge","mountain"]:
		world.mode = "playing"
		world.enter_stage(stage,Vector2(180,920),false)
		await process_frame
		var atmosphere = world.terrain.get_node_or_null("MapAtmosphere")
		expect(atmosphere != null,stage+" has a single atmosphere node")
		expect(atmosphere.leaves.size() <= 14,stage+" has a bounded leaf count")
		var previous_clock: float = atmosphere.clock
		atmosphere._process(.1)
		expect(atmosphere.clock > previous_clock,stage+" moves during play")
		world.mode = "map"
		previous_clock = atmosphere.clock
		atmosphere._process(.1)
		expect(atmosphere.clock == previous_clock,stage+" pauses on military map")
		world.mode = "playing"
		if stage == "bridge":
			expect(atmosphere.ripples.size() == 38,"river has bounded glint count")
			for ripple in atmosphere.ripples:
				for seconds in [0.0,60.0,3600.0]:
					var p: Vector2 = atmosphere.river_position(ripple,seconds)
					expect(p.y < 285 and (p.x < 1170 or p.x > 1370),"river motion stays off bridge and bank")
		else: expect(atmosphere.ripples.is_empty(),stage+" has no misplaced river motion")
		for item in world.definition.map_details.landmarks:
			var node = world.actors.get_node("Landmark_"+item.id)
			if manifest.has(item.kind):
				modeled_count += 1
				var frame: Dictionary = manifest[item.kind]
				expect(node.rendered_prop != null,item.id+" uses a rendered Blender prop")
				expect(node.position == Vector2(item.position[0],item.position[1]),item.id+" retains Y-sort origin")
				expect(node.rendered_prop.position == Vector2(frame.draw_offset[0],frame.draw_offset[1]),item.id+" retains exact projected foot anchor")
				expect(node.rendered_prop.texture.get_size() == Vector2(frame.image_size[0],frame.image_size[1]),item.id+" imports full RGBA sprite")
				expect(item.colliders == frame.colliders,item.id+" matches original physics footprint")
			if item.kind == "banner":
				var pinned = node._flag_point(Vector2(3,-103))
				node._process(.4)
				expect(node._flag_point(Vector2(3,-103)) == pinned,item.id+" cloth remains pinned to mast")
				world.mode = "paused"
				var old_clock: float = node.breeze_clock
				node._process(.4)
				expect(old_clock == node.breeze_clock,item.id+" stops breeze outside play")
				world.mode = "playing"
	expect(modeled_count == 6,"all six landmark instances use four source models")
	world.enter_stage("mountain",Vector2(180,920),false)
	var object: Dictionary = world.object_by_id("toVillage")
	world.hero.position = Vector2(object.x,object.y)+Vector2(0,40)
	var marker = world.actors.get_node("toVillage")
	marker._process(1.0)
	expect(marker.focused,"nearest physical interaction gets E badge")
	expect(marker.focus_blocked,"locked exit has blocked focus state")
	world.state.flags.mountain = true
	marker._process(1.0)
	expect(not marker.focus_blocked,"focus state updates after gate opens")
	world.mode = "map"
	marker._process(1.0)
	expect(not marker.focused,"focus badge clears while map is open")
	world.mode = "playing"
	world.hero.position = Vector2(180,920)
	marker._process(1.0)
	expect(not marker.focused,"leaving interaction range removes focus")
	var camp: Dictionary = {}
	for candidate in world.definition.objects:
		if candidate.kind == "camp": camp = candidate; break
	var enemy = world.enemies[0]
	enemy.position = Vector2(camp.x,camp.y)+Vector2(80,0)
	enemy.alerted = true
	expect(world.object_blocked(camp),"camp focus and actual interaction share enemy threat rule")
	expect(world.interaction_text(camp) == "先击退附近敌军，再休整。","camp HUD explains the actual blocked action")
	enemy.hp = 0
	expect(not world.camp_threatened(camp),"defeated nearby enemy no longer blocks camp")
	print("ATMOSPHERE_VERIFY ",checks," checks; ",failures.size()," failures")
	world.queue_free(); await process_frame
	quit(0 if failures.is_empty() else 1)
