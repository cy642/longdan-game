extends SceneTree
## Execute this script by absolute path with --main-pack to test exported assets.
const Game = preload("res://scripts/world.gd")
const Campaign = preload("res://scripts/campaign.gd")
const JiguDirector = preload("res://scripts/jigu_director.gd")
const JiguLayout = preload("res://scripts/jigu_layout.gd")
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
					push_error("Missing exported cached landmark: "+item.id); quit(1); return
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
	world.state.reset("normal",3); world.load_chapter(3)
	var jigu_props = 0
	for stage in ["jg_fog","jg_signal","jg_pass","jg_rearguard","jg_bridge","jg_final"]:
		world.mode="playing"; world.enter_stage(stage,Vector2.INF,false); await process_frame
		if not is_instance_valid(world.tactics) or world.tactics.get_script()!=JiguDirector or world.terrain.ground_texture==null or world.terrain.ground_texture.get_size()!=Vector2(1600,1100):
			push_error("Missing exported third-chapter director/ground: "+stage); quit(1); return
		if world.terrain.get_node_or_null("MapAtmosphere")==null or world.tactics.support_status().visible or world.tactics.cart!=null:
			push_error("Invalid exported third-chapter atmosphere/compatibility: "+stage); quit(1); return
		var region_props = 0
		for node in world.actors.get_children():
			if node.get_script()!=JiguLayout or node.layer!="landmark": continue
			if node.rendered_prop==null or not node.rendered_prop.texture is AtlasTexture:
				push_error("Missing exported Jigu atlas prop: "+str(node.item.kind)); quit(1); return
			region_props+=1
		if region_props!=world.definition.get("layout",{}).get("jigu_props",[]).size():
			push_error("Missing exported authored Jigu props: "+stage); quit(1); return
		jigu_props+=region_props
	world.begin_boss("vanguard"); world.boss.update_visual()
	if world.boss.display_name!="玄甲先锋" or world.boss.boss_id!="vanguard" or world.boss.visual.rig==null:
		push_error("Missing exported Jigu vanguard boss/rig"); quit(1); return
	print("EXPORT_SMOKE_OK regions=18 modeled_landmarks=",modeled," chapter1_articulated_enemies=",enemies," chapter2_new_enemies=3 bosses=dujun,vanguard huangzhong_support=ready jigu_props=",jigu_props)
	world.queue_free(); await process_frame; quit()
