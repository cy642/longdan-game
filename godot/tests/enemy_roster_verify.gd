extends SceneTree
## Portable acceptance for independent enemy art. Exercises actual spawn/rig
## selection without player saves, GPU capture, or source-art file reads.
const Game = preload("res://scripts/world.gd")
const Campaign = preload("res://scripts/campaign.gd")
const Roster = preload("res://scripts/enemy_roster.gd")
const Enemy = preload("res://scripts/enemy.gd")
const ATLAS_COUNTS = {"enemy_changban":6,"enemy_hanshui":6,"enemy_jigu":6,"enemy_commanders":4}
# chapter, region, combat kind, boss, group, independently authored profile
const CASES = [
	[1,"mountain","sword","","m1","cb_sword"],
	[1,"mountain","spear","","m1","cb_spear"],
	[1,"mountain","archer","","m1","cb_archer"],
	[1,"mountain","shield","","m1","cb_shield"],
	[1,"fork","elite","","elite","cb_elite"],
	[1,"village","sword","","v1","cb_village"],
	[2,"hs_forest","sword","","forest_main","hs_sword"],
	[2,"hs_forest","spear","","forest_main","hs_spear"],
	[2,"hs_forest","scout","","forest_main","hs_scout"],
	[2,"hs_forest","crossbow","","forest_main","hs_crossbow"],
	[2,"hs_forest","ironshield","","forest_main","hs_ironshield"],
	[2,"hs_grain","crossbow","","hs_beacon_guard","hs_beacon"],
	[3,"jg_fog","sword","","jg_f1","jg_sword"],
	[3,"jg_fog","spear","","jg_f1","jg_spear"],
	[3,"jg_fog","scout","","jg_f1","jg_scout"],
	[3,"jg_fog","crossbow","","jg_f1","jg_crossbow"],
	[3,"jg_fog","ironshield","","jg_f1","jg_ironshield"],
	[3,"jg_signal","crossbow","","jg_s2","jg_signal"],
	[1,"temple","boss","xiahou","boss","boss_xiahou"],
	[1,"bridge","boss","zhanghe","boss","boss_zhanghe"],
	[2,"hs_final","boss","dujun","boss","boss_dujun"],
	[3,"jg_final","boss","vanguard","boss","boss_vanguard"]
]
const PROFILE_ORDER = {
	"enemy_changban":["cb_sword","cb_spear","cb_archer","cb_shield","cb_elite","cb_village"],
	"enemy_hanshui":["hs_sword","hs_spear","hs_scout","hs_crossbow","hs_ironshield","hs_beacon"],
	"enemy_jigu":["jg_sword","jg_spear","jg_scout","jg_crossbow","jg_ironshield","jg_signal"],
	"enemy_commanders":["boss_xiahou","boss_zhanghe","boss_dujun","boss_vanguard"]
}
const KIND_HP = {"sword":72,"spear":91,"archer":58,"shield":115,"elite":285,"scout":75,"crossbow":65,"ironshield":140}
const BOSS_HP = {"xiahou":830,"zhanghe":1350,"dujun":1450,"vanguard":1450}
class MemoryCampaign extends Campaign:
	func read_save() -> Dictionary: return {}
	func save() -> bool: return true
var world
var checks = 0
var failures: Array = []
var manifest: Dictionary = {}
var textures: Dictionary = {}
var images: Dictionary = {}
var seen_profiles: Dictionary = {}
var seen_frames: Dictionary = {}

func _initialize() -> void: call_deferred("run")
func expect(condition: bool, message: String) -> void:
	checks += 1
	if not condition: failures.append(message); push_error("ENEMY_ROSTER: "+message)
func settle() -> void:
	await process_frame; await physics_frame; await physics_frame
func fingerprints() -> Dictionary:
	var result: Dictionary = {}
	for path in [Campaign.SAVE_PATH,Campaign.LEGACY_PATH]:
		result[path] = FileAccess.get_file_as_bytes(path).hex_encode().sha256_text() if FileAccess.file_exists(path) else "absent"
	return result
func numeric_array(value: Variant, size: int) -> bool:
	if not value is Array or value.size()!=size: return false
	for number in value:
		if not (number is int or number is float) or not is_finite(float(number)): return false
	return true
func unit_rect(value: Variant) -> bool:
	if not numeric_array(value,4): return false
	var rect = Rect2(value[0],value[1],value[2],value[3])
	return rect.has_area() and Rect2(0,0,1,1).encloses(rect)
func geometry_meta_valid(meta: Dictionary, texture: Texture2D) -> bool:
	if texture==null or not numeric_array(meta.get("region"),4) or not numeric_array(meta.get("anchor"),2): return false
	var r = meta.region; var region = Rect2(r[0],r[1],r[2],r[3])
	if not region.has_area() or not Rect2(Vector2.ZERO,texture.get_size()).encloses(region): return false
	if not unit_rect(meta.get("head_rect")) or not numeric_array(meta.get("hip"),2): return false
	if not Rect2(0,0,1,1).has_point(Vector2(meta.hip[0],meta.hip[1])): return false
	var height = float(meta.get("body_height",0)); var leg_start = float(meta.get("leg_start",-1))
	if not is_finite(height) or height<=0 or height>r[3] or not is_finite(leg_start) or leg_start<=0 or leg_start>=1: return false
	if meta.anchor[0]<0 or meta.anchor[0]>r[2] or meta.anchor[1]<=0 or meta.anchor[1]>r[3]+4: return false
	if not meta.get("rigid_weapon_regions") is Array or meta.rigid_weapon_regions.is_empty(): return false
	for rect in meta.rigid_weapon_regions:
		if not unit_rect(rect): return false
	if not meta.get("boot_regions") is Array or meta.boot_regions.is_empty() or meta.boot_regions.size()>2: return false
	for rect in meta.boot_regions:
		if not unit_rect(rect): return false
	if not meta.get("exclude") is Array: return false
	for hole in meta.exclude:
		if not numeric_array(hole,4) or not Rect2(0,0,r[2],r[3]).encloses(Rect2(hole[0],hole[1],hole[2],hole[3])): return false
	return true
func has_painted_boot_near_anchor(atlas: String, meta: Dictionary, body_scale: float) -> bool:
	var pixels: Image = images.get(atlas)
	if pixels==null or pixels.is_empty(): return false
	var r = meta.region; var anchor = Vector2(meta.anchor[0],meta.anchor[1])
	var minimum_x = INF; var maximum_x = -INF; var nearest_contact = INF
	for boot in meta.boot_regions:
		var start = Vector2(boot[0]*r[2],boot[1]*r[3]); var end = start+Vector2(boot[2]*r[2],boot[3]*r[3])
		var bottom = -INF
		minimum_x = minf(minimum_x,start.x); maximum_x = maxf(maximum_x,end.x)
		for y in range(maxi(0,int(floor(start.y))),mini(int(r[3]),int(ceil(end.y)))):
			for x in range(maxi(0,int(floor(start.x))),mini(int(r[2]),int(ceil(end.x)))):
				var source_point = Vector2(r[0]+x+.5,r[1]+y+.5)
				if source_pixel_excluded(meta,source_point): continue
				if pixels.get_pixel(int(r[0])+x,int(r[1])+y).a>=24.0/255.0: bottom=maxf(bottom,float(y))
		if not is_finite(bottom): return false
		nearest_contact=minf(nearest_contact,absf(anchor.y-bottom))
	var horizontal_gap = maxf(0,maxf(minimum_x-anchor.x,anchor.x-maximum_x))
	# Wide stances put the logical pivot BETWEEN boots, not inside a narrow
	# center strip. A shield can conceal one boot; its pivot must still lie
	# within the existing 17-world-pixel ground shadow of the visible boot.
	var x_valid = horizontal_gap<=.001 if meta.boot_regions.size()==2 else horizontal_gap*body_scale<=17.0
	return x_valid and nearest_contact<=4.0

func profile_body_scale(atlas: String, index: int, meta: Dictionary) -> float:
	for row in CASES:
		if row[5]==PROFILE_ORDER[atlas][index]:
			return float(Roster.resolve(row[0],row[1],row[2],row[3],row[4]).height)/float(meta.body_height)
	return 0

func source_pixel_excluded(meta: Dictionary, at: Vector2) -> bool:
	var local = at-Vector2(meta.region[0],meta.region[1])
	for hole in meta.exclude:
		if Rect2(hole[0],hole[1],hole[2],hole[3]).has_point(local): return true
	return false

func share_visible_pixels(atlas: String, first: Dictionary, second: Dictionary) -> bool:
	var a = first.region; var b = second.region
	var overlap = Rect2(a[0],a[1],a[2],a[3]).intersection(Rect2(b[0],b[1],b[2],b[3]))
	if not overlap.has_area(): return false
	var pixels: Image = images.get(atlas)
	if pixels==null: return true
	for y in range(int(overlap.position.y),int(overlap.end.y)):
		for x in range(int(overlap.position.x),int(overlap.end.x)):
			var point = Vector2(x+.5,y+.5)
			if source_pixel_excluded(first,point) or source_pixel_excluded(second,point): continue
			if pixels.get_pixel(x,y).a>.08: return true
	return false

func verify_manifest() -> bool:
	var raw = JSON.parse_string(FileAccess.get_file_as_string("res://data/enemy_atlas.json"))
	if not raw is Dictionary: expect(false,"enemy atlas is a runtime dictionary"); return false
	manifest = raw
	var keys = manifest.keys(); keys.sort(); var expected = ATLAS_COUNTS.keys(); expected.sort()
	expect(keys==expected,"new metadata contains exactly four independent enemy atlases")
	var paths: Dictionary = {}; var all_valid = true
	for key in ATLAS_COUNTS:
		var info: Dictionary = manifest.get(key,{})
		var path = str(info.get("file",""))
		expect(path.begins_with("res://assets/") and path.ends_with(".png") and path not in ["res://assets/chibi-units-v1.png","res://assets/chapter1-units-v2.png"],key+" points to new runtime enemy art")
		expect(not paths.has(path),key+" owns a separate atlas file"); paths[path] = true
		var texture = load(path) as Texture2D
		textures[key] = texture
		expect(texture!=null,key+" imported texture is loadable")
		if texture!=null:
			var pixels = texture.get_image()
			if pixels!=null and pixels.is_compressed(): pixels.decompress()
			images[key] = pixels
		var frames: Array = info.get("frames",[])
		expect(frames.size()==ATLAS_COUNTS[key],key+" retains its authored complete roster count")
		if frames.size()!=ATLAS_COUNTS[key]: all_valid = false
		var previous_frames: Array = []
		for index in range(frames.size()):
			var valid = frames[index] is Dictionary and geometry_meta_valid(frames[index],texture)
			expect(valid,key+":"+str(index)+" has finite frame, foot, anatomical height and rig regions")
			if not valid: all_valid = false; continue
			var meta: Dictionary = frames[index]; var r = meta.region
			# Component crops may have intersecting bounding boxes. Only visible
			# pixels after the authored exclusion holes must have one owner.
			for previous in previous_frames: expect(not share_visible_pixels(key,previous,meta),key+" frames never duplicate visible source pixels after exclusions")
			previous_frames.append(meta)
			expect(has_painted_boot_near_anchor(key,meta,profile_body_scale(key,index,meta)),key+":"+str(index)+" authored boot alpha reaches the ground anchor within four source pixels")
	return all_valid

func verify_case(row: Array) -> void:
	world.load_chapter(row[0]); world.state.reset("normal",row[0]); world.mode = "playing"
	world.enter_stage(row[1],Vector2.INF,false); world.ui.hide_overlay(); await settle()
	var actor = world.spawn_enemy(row[2],Vector2(850,900),row[4],row[3]); actor.update_visual()
	var profile: Dictionary = actor.visual_profile
	expect(profile.get("id","")==row[5],str(row[5])+" selected by actual production spawn context")
	if profile.is_empty(): return
	var resolved: Dictionary = Roster.resolve(row[0],row[1],row[2],row[3],row[4])
	expect(profile==resolved,str(row[5])+" production binding matches the public resolver")
	var atlas = str(profile.get("atlas","")); var index = int(profile.get("index",-1))
	expect(PROFILE_ORDER.has(atlas) and index>=0 and index<PROFILE_ORDER.get(atlas,[]).size(),str(row[5])+" references a known runtime frame")
	if not PROFILE_ORDER.has(atlas) or index<0 or index>=PROFILE_ORDER[atlas].size(): return
	expect(PROFILE_ORDER[atlas][index]==row[5],str(row[5])+" maps to its independently authored sprite slot")
	var identity = atlas+":"+str(index)
	expect(not seen_profiles.has(row[5]) and not seen_frames.has(identity),str(row[5])+" does not reuse another profile's frame")
	seen_profiles[row[5]] = true; seen_frames[identity] = true
	expect(not str(profile.get("name","")).is_empty() and actor.display_name==profile.name,str(row[5])+" exposes its actual roster identity")
	expect(actor.kind==row[2] and actor.boss_id==row[3],str(row[5])+" art selection never replaces combat kind")
	expect(actor.max_hp==(BOSS_HP[row[3]] if row[2]=="boss" else KIND_HP[row[2]]),str(row[5])+" new art preserves combat health")
	var height = float(profile.get("height",0)); var large = row[2] in ["elite","boss"]
	expect(is_finite(height) and height>=(75 if large else 55) and height<=(130 if large else 100),str(row[5])+" has readable human-scale body height")
	var meta: Dictionary = manifest[atlas].frames[index]; var visual = actor.visual
	var model_scale = height/float(meta.body_height)
	expect(visual.rig!=null and not visual.body.visible and visual.enemy_equipment==null,str(row[5])+" renders complete new art without duplicate old equipment")
	expect(visual.rig.texture.resource_path==manifest[atlas].file and visual.last_frame[0]==atlas and visual.last_frame[1]==index,str(row[5])+" visible rig uses the selected new atlas")
	expect(not visual.rig_data.head_indices.is_empty() and not visual.rig_data.weapon_indices.is_empty(),str(row[5])+" rigid protections cover nonempty face and weapon regions")
	var health = actor.hp; var actor_position = actor.position; var serial = world.serial
	actor.start_action(world.hero)
	var definition: Dictionary = actor.action.def.duplicate(true)
	actor.action = {}; var action_serial = world.serial
	for direction in range(8):
		actor.facing = direction*PI/4
		for phase in ["idle","walk_a","walk_b","windup","strike","recovery"]:
			actor.action = {}; actor.moving = phase.begins_with("walk")
			actor.walk_distance = 18 if phase=="walk_a" else 65 if phase=="walk_b" else 0
			visual.move_blend = 1 if actor.moving else 0
			if phase in ["windup","strike","recovery"]:
				var time = definition.windup*.9 if phase=="windup" else definition.windup+definition.active*.42 if phase=="strike" else definition.windup+definition.active+definition.recovery*.9
				actor.action = {"id":901,"key":"enemy","dir":actor.facing,"t":time,"def":definition}
			actor.update_visual()
			var description = str(row[5])+" "+phase+" facing "+str(direction)
			expect(is_equal_approx(visual.current_scale,model_scale) and visual.rig.scale.abs().is_equal_approx(Vector2.ONE*model_scale),description+" retains anatomical scale")
			expect(visual.position.is_zero_approx() and visual.rotation==0 and visual.scale==Vector2.ONE and visual.rig.position.is_zero_approx(),description+" leaves the ground origin fixed")
			var foot = visual.body.transform*Vector2(meta.anchor[0],meta.anchor[1])
			expect(foot.length()<.001,description+" mirrored source foot maps to the actor origin")
			var head_error = 0.0; var weapon_error = 0.0; var finite = true
			var upper = visual.enemy_upper_transform(visual.displayed_pose)
			for point in visual.rig.polygon:
				if not point.is_finite(): finite = false
			for i in visual.rig_data.head_indices: head_error = maxf(head_error,visual.rig.polygon[i].distance_to(upper*visual.rig_data.rest[i]))
			for i in visual.rig_data.weapon_indices: weapon_error = maxf(weapon_error,visual.rig.polygon[i].distance_to(upper*visual.rig_data.rest[i]))
			expect(finite and head_error<.001 and weapon_error<.001,description+" keeps face and complete painted weapon rigid")
			if actor.moving:
				var rest_bottom = -INF; var posed_bottom = -INF
				for i in range(visual.rig_data.rest.size()):
					if visual.rig_data.weapon_indices.has(i): continue
					rest_bottom = maxf(rest_bottom,visual.rig_data.rest[i].y); posed_bottom = maxf(posed_bottom,visual.rig.polygon[i].y)
				expect(absf(posed_bottom-rest_bottom)*model_scale<.7,description+" keeps a support boot planted")
	expect(actor.hp==health and actor.position==actor_position and world.serial==action_serial and action_serial>serial,str(row[5])+" visual sampling never advances physics, damage or attacks")
	actor.action = {}; actor.moving = false; actor.hp = 0; actor.collision_layer = 0

func selection_boundaries() -> void:
	expect(Roster.resolve(1,"village","spear").id=="cb_spear","village override does not repaint every combat kind")
	expect(Roster.resolve(2,"hs_grain","crossbow","","other").id=="hs_crossbow","beacon art requires the actual beacon group")
	expect(Roster.resolve(2,"hs_forest","crossbow","","hs_beacon_guard").id=="hs_crossbow","beacon group name alone does not leak across regions")
	expect(Roster.resolve(3,"jg_signal","crossbow","","jg_s1").id=="jg_crossbow","signal specialist requires the authored second group")
	expect(Roster.resolve(3,"jg_fog","crossbow","","jg_s2").id=="jg_crossbow","signal specialist never leaks to fog encounters")
	world.load_chapter(1); world.state.reset("normal",1); world.mode="playing"; world.enter_stage("mountain",Vector2.INF,false)
	var first = world.spawn_enemy("sword",Vector2(850,900),"binding-check")
	var original = first.visual_profile.duplicate(true)
	world.state.chapter=2; world.stage="hs_forest"
	var second = world.spawn_enemy("sword",Vector2(950,900),"binding-check")
	first.update_visual(); second.update_visual()
	expect(first.visual_profile==original and first.visual.last_frame[0]=="enemy_changban" and second.visual.last_frame[0]=="enemy_hanshui","existing enemy keeps its bound profile when another chapter requests a cached rig")
	expect(first.visual.rig_data.texture!=second.visual.rig_data.texture,"same combat kind across chapters never shares the wrong cached texture")
	var ally = world.allies[0]; ally.update_visual()
	expect(ally.faction=="ally" and ally.visual.last_frame[0]=="chapter","friendly soldier retains its old independent art path")
	var civil = world.spawn_civil("civil",Vector2(900,950),0); civil.update_visual()
	expect(civil.visual.last_frame[0]=="units","civilian art is not replaced by enemy profile selection")
	# Restore the actual mountain scene's state before deferred UI drawing;
	# the temporary chapter switch above tests binding, not map orchestration.
	world.state.chapter=1; world.stage="mountain"

func run() -> void:
	var before = fingerprints()
	if not verify_manifest():
		print("ENEMY_ROSTER_VERIFY ",checks," checks; ",failures.size()," failures; invalid metadata blocks actor sampling"); quit(1); return
	world = Game.new(); world.test_mode=true; world.state=MemoryCampaign.new()
	root.add_child(world); world.set_process(false); world.set_physics_process(false); await settle()
	for row in CASES: await verify_case(row)
	selection_boundaries()
	expect(seen_profiles.size()==22 and seen_frames.size()==22,"all eighteen chapter soldiers and four commanders have distinct frame mappings")
	expect(fingerprints()==before,"enemy roster verification never rewrites player save files")
	print("ENEMY_ROSTER_VERIFY ",checks," checks; ",failures.size()," failures; profiles=",seen_profiles.size()," distinct_frames=",seen_frames.size())
	world.queue_free(); await process_frame; await process_frame
	quit(0 if failures.is_empty() else 1)
