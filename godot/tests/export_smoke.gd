extends SceneTree
## Execute this script by absolute path with --main-pack to test exported assets.
const Game = preload("res://scripts/world.gd")
const Campaign = preload("res://scripts/campaign.gd")
class MemoryCampaign extends Campaign:
	func read_save() -> Dictionary: return {}
	func save() -> bool: return true

func _initialize() -> void: call_deferred("run")
func run() -> void:
	var world = Game.new(); world.test_mode = true; world.state = MemoryCampaign.new()
	root.add_child(world); world.set_process(false); world.set_physics_process(false)
	await process_frame
	var modeled = 0
	var enemies = 0
	for stage in ["mountain","village","temple","house","fork","bridge"]:
		world.mode = "playing"; world.enter_stage(stage,Vector2.INF,false)
		await process_frame
		if world.terrain.get_node_or_null("MapAtmosphere") == null:
			push_error("Missing exported atmosphere: "+stage); quit(1); return
		for item in world.definition.map_details.landmarks:
			if item.kind in ["altar","stela","grain_rack","lantern"]:
				var node = world.actors.get_node("Landmark_"+item.id)
				if node.rendered_prop == null:
					push_error("Missing exported Blender prop: "+item.id); quit(1); return
				modeled += 1
		for enemy in world.enemies:
			enemy.update_visual()
			if enemy.visual.rig == null:
				push_error("Missing exported enemy rig"); quit(1); return
			enemies += 1
	print("EXPORT_SMOKE_OK regions=6 modeled_landmarks=",modeled," articulated_enemies=",enemies)
	world.queue_free(); await process_frame; quit()
