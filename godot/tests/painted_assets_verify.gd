extends SceneTree
## Portable runtime-asset acceptance. May run by an absolute external --script
## with --main-pack; never reads art_source, .qa baselines, or player saves.
## Geometry/route preservation belongs to the separate map_identity baseline.
const Game = preload("res://scripts/world.gd")
const Campaign = preload("res://scripts/campaign.gd")
const Terrain = preload("res://scripts/terrain.gd")
const Scenery = preload("res://scripts/scenery.gd")
const Hanshui = preload("res://scripts/hanshui_layout.gd")
const Jigu = preload("res://scripts/jigu_layout.gd")
const Chencang = preload("res://scripts/chencang_layout.gd")
const Details = preload("res://scripts/map_details.gd")
const PaintedProps = preload("res://scripts/painted_props.gd")
const PaintedGround = preload("res://scripts/painted_ground.gd")
const OLD_LANDMARKS = {
	"altar":{"size":[280,280],"anchor":[140,238],"offset":[-70,-119],"logical_size":[140,140],"colliders":[{"rect":[-52,-22,104,36]}]},
	"stela":{"size":[152,200],"anchor":[76,172],"offset":[-38,-86],"logical_size":[76,100],"colliders":[{"rect":[-19,-13,38,24]}]},
	"grain_rack":{"size":[288,272],"anchor":[144,234],"offset":[-72,-117],"logical_size":[144,136],"colliders":[{"rect":[-46,-20,92,32]}]},
	"lantern":{"size":[160,244],"anchor":[52,218],"offset":[-26,-109],"logical_size":[80,122],"colliders":[{"circle":[0,0,7]}]}
}
const MARKERS = ["gateway_126","gateway_152","gateway_212","well_hoist"]
class MemoryCampaign extends Campaign:
	func read_save() -> Dictionary: return {}
	func save() -> bool: return true
var world
var checks = 0
var failures: Array = []
var landmark_manifest: Dictionary = {}
var marker_manifest: Dictionary = {}
var marker_atlas: Texture2D
var seen_landmarks: Dictionary = {}
var seen_markers: Dictionary = {}
var regions = 0
var cached_scenery = 0
var cached_hanshui = 0
var cached_jigu = 0
var seen_jigu: Dictionary = {}
var jigu_manifest: Dictionary = {}
var cached_chencang=0
var seen_chencang: Dictionary={}
var chencang_manifest: Dictionary={}

func _initialize() -> void: call_deferred("run")
func expect(value: bool, message: String) -> void:
	checks += 1
	if not value: failures.append(message); push_error("PAINTED_ASSETS: "+message)
func json_equal(a: Variant, b: Variant) -> bool:
	return JSON.parse_string(JSON.stringify(a)) == JSON.parse_string(JSON.stringify(b))
func read_manifest(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		expect(false,"runtime manifest exists: "+path); return {}
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not parsed is Dictionary:
		expect(false,"runtime manifest is a dictionary: "+path); return {}
	return parsed
func finite_pair(value: Variant) -> bool:
	if not value is Array or value.size()!=2: return false
	for item in value:
		if not (item is int or item is float) or not is_finite(float(item)): return false
	return true
func valid_frame(frame: Variant, texture: Texture2D) -> bool:
	if not frame is Dictionary or texture==null or not finite_pair(frame.get("anchor")): return false
	var values = frame.get("region")
	if not values is Array or values.size()!=4: return false
	for value in values:
		if not (value is int or value is float) or not is_finite(float(value)): return false
	var region = Rect2(values[0],values[1],values[2],values[3])
	return region.has_area() and Rect2(Vector2.ZERO,texture.get_size()).encloses(region)
func atlas_sprite_valid(sprite: Sprite2D, texture: Texture2D, frame: Dictionary, scale_factor: float = 1) -> bool:
	if sprite==null or not sprite.texture is AtlasTexture or not valid_frame(frame,texture): return false
	var view: AtlasTexture = sprite.texture
	var r: Array = frame.region
	return view.atlas==texture and view.region==Rect2(r[0],r[1],r[2],r[3]) and view.filter_clip and not sprite.centered and sprite.position.is_equal_approx(-Vector2(frame.anchor[0],frame.anchor[1])*scale_factor) and sprite.scale.is_equal_approx(Vector2.ONE*scale_factor)
func verify_runtime_manifests() -> void:
	landmark_manifest = read_manifest("res://assets/props/landmarks.json").get("props",{})
	for kind in OLD_LANDMARKS:
		var contract: Dictionary = OLD_LANDMARKS[kind]
		var frame: Dictionary = landmark_manifest.get(kind,{})
		expect(not frame.is_empty(),"legacy landmark is present: "+kind)
		if frame.is_empty(): continue
		expect(json_equal(frame.get("image_size"),contract.size) and json_equal(frame.get("logical_size"),contract.logical_size),"legacy image and world dimensions retained: "+kind)
		expect(json_equal(frame.get("anchor_px"),contract.anchor) and json_equal(frame.get("draw_offset"),contract.offset) and is_equal_approx(float(frame.get("scale",0)),.5),"legacy foot anchor, offset and scale retained: "+kind)
		expect(json_equal(frame.get("logical_anchor"),[-contract.offset[0],-contract.offset[1]]) and json_equal(frame.get("colliders"),contract.colliders),"legacy logical foot and collision metadata retained: "+kind)
		var expected_path = "res://assets/props/"+str(kind)+".png"
		expect(frame.get("image","")==expected_path and ResourceLoader.exists(expected_path),"legacy landmark uses its portable runtime image: "+kind)
		var texture = load(expected_path) as Texture2D
		expect(texture!=null and texture.get_size()==Vector2(contract.size[0],contract.size[1]),"legacy landmark imported image has expected dimensions: "+kind)
	marker_manifest = read_manifest("res://assets/props/painted_markers.json")
	expect(ResourceLoader.exists("res://assets/props/painted_markers.png"),"painted marker atlas is exported")
	marker_atlas = load("res://assets/props/painted_markers.png") as Texture2D
	var actual_keys = marker_manifest.keys(); actual_keys.sort()
	var expected_keys = MARKERS.duplicate(); expected_keys.sort()
	expect(actual_keys==expected_keys,"painted marker manifest contains the four authored frames")
	for key in MARKERS:
		expect(valid_frame(marker_manifest.get(key),marker_atlas),"painted marker region and finite ground anchor are valid: "+key)
	for pair in [["res://assets/maps/scenery.png","res://assets/maps/scenery.json"],["res://assets/maps/hanshui_props.png","res://assets/maps/hanshui_props.json"],["res://assets/maps/jigu_props.png","res://assets/maps/jigu_props.json"],["res://assets/maps/chencang_props.png","res://assets/maps/chencang_props.json"]]:
		var texture = load(pair[0]) as Texture2D
		var manifest = read_manifest(pair[1])
		expect(texture!=null and not manifest.is_empty(),"shared runtime atlas loads: "+pair[0])
		var bad: Array = []
		for key in manifest:
			if not valid_frame(manifest[key],texture): bad.append(key)
		expect(bad.is_empty(),"shared atlas frames remain inside the image with finite anchors: "+str(bad))
	jigu_manifest = read_manifest("res://assets/maps/jigu_props.json")
	chencang_manifest=read_manifest("res://assets/maps/chencang_props.json")
	var cc_keys=chencang_manifest.keys(); cc_keys.sort()
	expect(cc_keys==["beacon_tower","city_gate","drum_tower","supply_crates","wall_segment","warehouse"],"Chencang runtime atlas has six independently authored architectural components")
func verify_region(stage: String, chapter: int) -> void:
	world.load_chapter(chapter); world.state.reset("normal",chapter)
	world.mode = "playing"; world.hero.reset_combat()
	world.enter_stage(stage,Vector2.INF,false); world.ui.hide_overlay()
	await process_frame; await physics_frame; await physics_frame
	regions += 1
	var ground: Texture2D = world.terrain.ground_texture
	expect(ground!=null and ground.get_size()==Vector2(1600,1100),stage+": full-size baked ground loads")
	expect(world.terrain.grain.is_empty() and world.terrain.pools.is_empty(),stage+": runtime avoids procedural ground reconstruction")
	var scenery_found = 0; var hanshui_found = 0; var jigu_found = 0; var chencang_found=0
	var scenery_errors: Array = []; var hanshui_errors: Array = []; var detail_errors: Array = []; var jigu_errors: Array = []; var chencang_errors: Array=[]
	for node in world.actors.get_children():
		if node.get_script()==Scenery:
			if node.data.kind=="oil": continue # Dynamic interactive prop keeps its own draw path.
			scenery_found += 1
			var key = Scenery.frame_key(node.data)
			var frame: Dictionary = Scenery.manifest.get(key,{})
			var factor = float(node.data.size)/float(frame.get("size",1)) if node.data.kind in ["tree","rock"] else 1.0
			if not atlas_sprite_valid(node.cached_sprite,Scenery.atlas,frame,factor): scenery_errors.append(key)
		elif node.get_script()==Hanshui and node.layer=="landmark":
			hanshui_found += 1
			var key = Hanshui.frame_key(node.item)
			if not atlas_sprite_valid(node.rendered_prop,Hanshui.prop_atlas,Hanshui.prop_frames.get(key,{})): hanshui_errors.append(key)
		elif node.get_script()==Jigu and node.layer=="landmark":
			jigu_found += 1
			var key = Jigu.frame_key(node.item); seen_jigu[key] = true
			var expected_position: Vector2
			if node.item.has("rect"):
				var r: Array = node.item.rect; expected_position = Vector2(r[0]+r[2]*.5,r[1]+r[3])
			else: expected_position = Vector2(node.item.position[0],node.item.position[1])
			if node.position!=expected_position: jigu_errors.append(key+": logical ground/sort origin")
			if not json_equal(Jigu.prop_frames.get(key,{}),jigu_manifest.get(key,{})): jigu_errors.append(key+": runtime frame metadata")
			if not atlas_sprite_valid(node.rendered_prop,Jigu.prop_atlas,jigu_manifest.get(key,{})): jigu_errors.append(key+": cached region or foot anchor")
			var watches_bridge = stage=="jg_bridge" and node.item.kind=="rope_posts"
			if node.is_processing()!=watches_bridge: jigu_errors.append(key+": unexpected process policy")
			if watches_bridge:
				var original_position: Vector2 = node.position
				var original_sprite = node.rendered_prop
				world.state.flags.jg_bridge_cut = true; await process_frame; await process_frame
				var variant = node.item.duplicate(); variant.cut = true
				var cut_key = Jigu.frame_key(variant); seen_jigu[cut_key] = true
				expect(node.cut_variant and atlas_sprite_valid(node.rendered_prop,Jigu.prop_atlas,jigu_manifest.get(cut_key,{})),stage+": live cut decision switches to its exported atlas frame")
				expect(node.position==original_position and node.rendered_prop==original_sprite,stage+": cut art preserves the ground anchor and reuses the existing sprite")
				world.state.flags.jg_bridge_cut = false; await process_frame; await process_frame
				expect(not node.cut_variant and atlas_sprite_valid(node.rendered_prop,Jigu.prop_atlas,jigu_manifest.get(key,{})),stage+": retained bridge state restores the intact cached frame")
		elif node.get_script()==Chencang and node.layer=="landmark":
			chencang_found+=1
			var key=Chencang.frame_key(node.item); seen_chencang[key]=true
			var frame: Dictionary=chencang_manifest.get(key,{})
			var factor=float(node.item.width)/float(frame.get("baked_width",1))
			if node.position!=Vector2(node.item.position[0],node.item.position[1]): chencang_errors.append(key+": logical ground/sort origin")
			if not json_equal(Chencang.prop_frames.get(key,{}),frame): chencang_errors.append(key+": runtime frame metadata")
			if not atlas_sprite_valid(node.rendered_prop,Chencang.prop_atlas,frame,factor): chencang_errors.append(key+": cached region or foot anchor")
			if node.item.get("beacon",false):
				var original_sprite=node.rendered_prop; var original_position: Vector2=node.position
				expect(node.beacon_on,stage+": uncleared beacon starts visibly burning")
				world.mode="pause"; var clock=node.fire_clock
				node._process(30)
				expect(node.fire_clock==clock,stage+": paused beacon does not advance visual flame time")
				world.state.flags.cc_beacon_out=true; await process_frame; await process_frame
				expect(not node.beacon_on and node.rendered_prop==original_sprite and node.position==original_position,stage+": extinguishing stops flame without moving or replacing cached architecture")
				world.state.flags.cc_beacon_out=false; world.mode="playing"; await process_frame; await process_frame
				expect(node.beacon_on and atlas_sprite_valid(node.rendered_prop,Chencang.prop_atlas,frame,factor),stage+": retry state restores flame over the same anchored frame")
		elif node.get_script()==Details and node.layer=="landmark":
			var kind = str(node.landmark.kind)
			var expected_position = Vector2(node.landmark.position[0],node.landmark.position[1])
			if node.position!=expected_position: detail_errors.append(str(node.landmark.id)+": sort origin")
			if OLD_LANDMARKS.has(kind):
				seen_landmarks[kind] = true
				var frame: Dictionary = landmark_manifest.get(kind,{})
				var sprite: Sprite2D = node.rendered_prop
				if sprite==null or frame.is_empty():
					detail_errors.append(kind+": missing cached image"); continue
				var contract: Dictionary = OLD_LANDMARKS[kind]
				if sprite.centered or not sprite.scale.is_equal_approx(Vector2.ONE*.5) or sprite.position!=Vector2(contract.offset[0],contract.offset[1]) or sprite.texture==null or sprite.texture.get_size()!=Vector2(contract.size[0],contract.size[1]):
					detail_errors.append(kind+": image dimensions or ground anchor")
				# The original first-chapter instances own these colliders.
				# Hanshui also reuses the images as non-solid decorations;
				# its layout.solids, not image metadata, owns physical geometry.
				if chapter==1 and not json_equal(node.landmark.get("colliders",[]),contract.colliders): detail_errors.append(kind+": collision footprint")
			elif kind=="well_hoist" or kind=="gateway":
				var key = kind+"_"+str(int(node.landmark.get("span",152))) if kind=="gateway" else kind
				seen_markers[key] = true
				if not atlas_sprite_valid(node.rendered_prop,marker_atlas,marker_manifest.get(key,{})): detail_errors.append(key+": cached marker")
	var expected_scenery = world.definition.huts.size()+world.terrain.trees.size()+world.terrain.rocks.size()
	expect(scenery_found==expected_scenery and scenery_errors.is_empty(),stage+": authored trees, rocks and houses all use cached frames "+str(scenery_errors))
	expect(hanshui_found==world.definition.get("layout",{}).get("decor",[]).size() and hanshui_errors.is_empty(),stage+": Hanshui decorations all use cached frames "+str(hanshui_errors))
	expect(jigu_found==world.definition.get("layout",{}).get("jigu_props",[]).size() and jigu_errors.is_empty(),stage+": Jigu props all use cached frames and authored foot anchors "+str(jigu_errors))
	expect(chencang_found==world.definition.get("layout",{}).get("cc_props",[]).size() and chencang_errors.is_empty(),stage+": Chencang architecture uses cached frames and scaled foot anchors "+str(chencang_errors))
	expect(detail_errors.is_empty(),stage+": old landmarks and painted markers keep their runtime contracts "+str(detail_errors))
	cached_scenery += scenery_found; cached_hanshui += hanshui_found; cached_jigu += jigu_found
	cached_chencang+=chencang_found
	expect(not PaintedProps.loaded and not PaintedGround.checked,stage+": no bake-only painted source loader was called")
	expect(not Chencang.sources_loaded and not Chencang.source_ready and Chencang.source_frames.is_empty(),stage+": Chencang source image and calibration remain unloaded at runtime")
func run() -> void:
	expect(not Terrain.baking and not Scenery.baking and not Hanshui.baking and not Jigu.baking and not Chencang.baking,"suite starts in normal runtime mode")
	expect(not PaintedProps.loaded and not PaintedGround.checked,"bake-only source loaders start untouched")
	verify_runtime_manifests()
	world = Game.new(); world.test_mode = true; world.state = MemoryCampaign.new()
	root.add_child(world); world.set_process(false); world.set_physics_process(false)
	await process_frame
	for chapter in Campaign.CHAPTER_STAGES:
		for stage in Campaign.CHAPTER_STAGES[chapter]: await verify_region(stage,chapter)
	for kind in OLD_LANDMARKS: expect(seen_landmarks.has(kind),"production maps exercised legacy landmark "+kind)
	for key in MARKERS: expect(seen_markers.has(key),"production maps exercised painted marker "+key)
	for key in jigu_manifest: expect(seen_jigu.has(key),"production maps exercised Jigu atlas frame "+key)
	for key in chencang_manifest: expect(seen_chencang.has(key),"production maps exercised Chencang atlas frame "+key)
	expect(regions==24 and cached_jigu>0 and cached_chencang>0 and not Jigu.baking and not Chencang.baking,"all twenty-four regions and new chapter caches were exercised without enabling a bake")
	expect(not PaintedProps.loaded and PaintedProps.frames.is_empty() and PaintedProps.sheets.is_empty() and PaintedProps.textures.is_empty(),"runtime leaves all painted-prop source caches empty")
	expect(not PaintedGround.checked and PaintedGround.tiles.is_empty(),"runtime leaves painted-ground source tiles unloaded")
	print("PAINTED_ASSETS_VERIFY ",checks," checks; ",failures.size()," failures; regions=",regions," cached_scenery=",cached_scenery," cached_hanshui=",cached_hanshui," cached_jigu=",cached_jigu," cached_chencang=",cached_chencang," source_loaders_untouched=",not PaintedProps.loaded and not PaintedGround.checked and not Chencang.sources_loaded)
	world.queue_free(); await process_frame
	quit(0 if failures.is_empty() else 1)
