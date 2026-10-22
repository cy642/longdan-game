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
	world.state.reset("normal",2); world.load_chapter(2)
	for stage in ["hs_forest","hs_grain","hs_return","hs_camp","hs_river","hs_final"]:
		world.mode="playing"; world.enter_stage(stage,Vector2.INF,false); await process_frame
		if not is_instance_valid(world.tactics) or world.terrain.ground_texture==null:
			push_error("Missing exported second-chapter region: "+stage); quit(1); return
		if stage=="hs_grain" and (not is_instance_valid(world.tactics.support) or not world.tactics.support_status().visible):
			push_error("Missing exported Huangzhong support"); quit(1); return
	for kind in ["scout","crossbow","ironshield"]:
		var enemy=world.spawn_enemy(kind,Vector2(700,700),"export_check"); enemy.update_visual()
		if enemy.visual.rig==null:
			push_error("Missing exported chapter-two enemy: "+kind); quit(1); return
	world.begin_boss("dujun")
	if world.boss.display_name!="铁面督军":
		push_error("Missing exported final boss"); quit(1); return
	print("EXPORT_SMOKE_OK regions=12 modeled_landmarks=",modeled," chapter1_articulated_enemies=",enemies," chapter2_new_enemies=3 boss=dujun huangzhong_support=ready")
	world.queue_free(); await process_frame; quit()
