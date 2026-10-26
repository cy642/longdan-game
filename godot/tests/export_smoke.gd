extends SceneTree
## Execute this script by absolute path with --main-pack to test exported assets.
const Game = preload("res://scripts/world.gd")
const Campaign = preload("res://scripts/campaign.gd")
const JiguDirector = preload("res://scripts/jigu_director.gd")
const JiguLayout = preload("res://scripts/jigu_layout.gd")
const ChencangDirector = preload("res://scripts/chencang_director.gd")
const ChencangLayout = preload("res://scripts/chencang_layout.gd")
const Roster = preload("res://scripts/enemy_roster.gd")
const ROSTER_CASES = [
	[1,"mountain","sword","","m1","cb_sword"],[1,"mountain","spear","","m1","cb_spear"],
	[1,"mountain","archer","","m1","cb_archer"],[1,"mountain","shield","","m1","cb_shield"],
	[1,"fork","elite","","elite","cb_elite"],[1,"village","sword","","v1","cb_village"],
	[2,"hs_forest","sword","","forest_main","hs_sword"],[2,"hs_forest","spear","","forest_main","hs_spear"],
	[2,"hs_forest","scout","","forest_main","hs_scout"],[2,"hs_forest","crossbow","","forest_main","hs_crossbow"],
	[2,"hs_forest","ironshield","","forest_main","hs_ironshield"],[2,"hs_grain","crossbow","","hs_beacon_guard","hs_beacon"],
	[3,"jg_fog","sword","","jg_f1","jg_sword"],[3,"jg_fog","spear","","jg_f1","jg_spear"],
	[3,"jg_fog","scout","","jg_f1","jg_scout"],[3,"jg_fog","crossbow","","jg_f1","jg_crossbow"],
	[3,"jg_fog","ironshield","","jg_f1","jg_ironshield"],[3,"jg_signal","crossbow","","jg_s2","jg_signal"],
	[1,"temple","boss","xiahou","boss","boss_xiahou"],[1,"bridge","boss","zhanghe","boss","boss_zhanghe"],
	[2,"hs_final","boss","dujun","boss","boss_dujun"],[3,"jg_final","boss","vanguard","boss","boss_vanguard"],
	[4,"cc_outer","sword","","cc_o1","cc_sword"],[4,"cc_outer","spear","","cc_o1","cc_spear"],
	[4,"cc_beacon","scout","","cc_b1","cc_scout"],[4,"cc_outer","crossbow","","cc_o2","cc_crossbow"],
	[4,"cc_outer","ironshield","","cc_o2","cc_ironshield"],[4,"cc_beacon","crossbow","","cc_orders_guard","cc_orders"],
	[4,"cc_final","boss","warden","boss","boss_warden"]
]
class MemoryCampaign extends Campaign:
	func read_save() -> Dictionary: return {}
	func save() -> bool: return true

func _initialize() -> void: call_deferred("run")

func verify_enemy_roster(world) -> bool:
	var metadata = JSON.parse_string(FileAccess.get_file_as_string("res://data/enemy_atlas.json"))
	if not metadata is Dictionary:
		push_error("Missing exported enemy roster metadata"); return false
	var used_frames: Dictionary = {}; var used_atlases: Dictionary = {}
	for row in ROSTER_CASES:
		world.state.reset("normal",row[0]); world.load_chapter(row[0]); world.mode="playing"
		world.enter_stage(row[1],Vector2.INF,false); await process_frame
		var enemy = world.spawn_enemy(row[2],Vector2(850,900),row[4],row[3]); enemy.update_visual()
		var profile: Dictionary = enemy.visual_profile
		if profile.get("id","")!=row[5] or profile!=Roster.resolve(row[0],row[1],row[2],row[3],row[4]):
			push_error("Wrong exported enemy profile: "+str(row[5])); return false
		var atlas = str(profile.get("atlas","")); var index = int(profile.get("index",-1))
		if not metadata.has(atlas) or index<0 or index>=metadata[atlas].frames.size():
			push_error("Missing exported enemy frame: "+str(row[5])); return false
		var visual = enemy.visual; var identity = atlas+":"+str(index)
		if used_frames.has(identity) or visual.rig==null or visual.enemy_equipment!=null or visual.body.visible or visual.last_frame[0]!=atlas or visual.last_frame[1]!=index:
			push_error("Missing independent exported rig: "+str(row[5])); return false
		if not atlas.begins_with("enemy_") or visual.rig.texture.resource_path!=metadata[atlas].file:
			push_error("Exported enemy still uses an old/wrong sprite: "+str(row[5])); return false
		if metadata[atlas].file in ["res://assets/chibi-units-v1.png","res://assets/chapter1-units-v2.png"]:
			push_error("Exported roster aliases old NPC art: "+str(row[5])); return false
		used_frames[identity]=true; used_atlases[metadata[atlas].file]=true
	return used_frames.size()==29 and used_atlases.size()==6

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
	world.state.reset("normal",4); world.load_chapter(4)
	var chencang_props=0
	for stage in ["cc_outer","cc_beacon","cc_street","cc_store","cc_bastion","cc_final"]:
		world.mode="playing"; world.enter_stage(stage,Vector2.INF,false); await process_frame
		if not is_instance_valid(world.tactics) or world.tactics.get_script()!=ChencangDirector or world.terrain.ground_texture==null or world.terrain.ground_texture.get_size()!=Vector2(1600,1100):
			push_error("Missing exported fourth-chapter director/ground: "+stage); quit(1); return
		if world.terrain.get_node_or_null("MapAtmosphere")==null or world.tactics.support_status().visible or world.tactics.cart!=null:
			push_error("Invalid exported fourth-chapter atmosphere/compatibility: "+stage); quit(1); return
		var region_props=0
		for node in world.actors.get_children():
			if node.get_script()!=ChencangLayout or node.layer!="landmark": continue
			if node.rendered_prop==null or not node.rendered_prop.texture is AtlasTexture:
				push_error("Missing exported Chencang atlas prop: "+str(node.item.kind)); quit(1); return
			region_props+=1
		if region_props!=world.definition.get("layout",{}).get("cc_props",[]).size():
			push_error("Missing exported authored Chencang props: "+stage); quit(1); return
		chencang_props+=region_props
	world.begin_boss("warden"); world.boss.update_visual()
	if world.boss.display_name!="镇关都尉" or world.boss.boss_id!="warden" or world.boss.max_hp!=1500 or world.boss.visual.rig==null:
		push_error("Missing exported Chencang warden boss/rig"); quit(1); return
	if not await verify_enemy_roster(world): quit(1); return
	if ChencangLayout.sources_loaded or not ChencangLayout.source_frames.is_empty():
		push_error("Exported runtime loaded Chencang authoring source"); quit(1); return
	print("EXPORT_SMOKE_OK regions=24 modeled_landmarks=",modeled," chapter1_articulated_enemies=",enemies," chapter2_new_enemies=3 bosses=dujun,vanguard,warden huangzhong_support=ready jigu_props=",jigu_props," chencang_props=",chencang_props," independent_enemy_profiles=29 enemy_atlases=6")
	world.queue_free(); await process_frame; quit()
