extends SceneTree
## Local before/after map-art guard. Create its ignored baseline once with
## -- --write-baseline, then rerun without that flag after visual edits.
## Runtime state is in memory; no player save is read or written.
const Game = preload("res://scripts/world.gd")
const Campaign = preload("res://scripts/campaign.gd")
const BASELINE = "res://../.qa/map-identity-baseline.json"
class MemoryCampaign extends Campaign:
	func read_save() -> Dictionary: return {}
	func save() -> bool: return true
var world
var checks = 0
var failures: Array = []

func _initialize() -> void: call_deferred("run")
func expect(value: bool, message: String) -> void:
	checks += 1
	if not value: failures.append(message); push_error("MAP_IDENTITY: " + message)
func settle() -> void:
	await process_frame; await physics_frame; await physics_frame
func serializable(value: Variant) -> Variant:
	if value is Vector2 or value is Vector2i: return [value.x, value.y]
	if value is Rect2 or value is Rect2i: return [value.position.x, value.position.y, value.size.x, value.size.y]
	if value is Dictionary:
		var result = {}
		for key in value: result[key] = serializable(value[key])
		return result
	if value is Array or value is PackedVector2Array:
		var result = []
		for item in value: result.append(serializable(item))
		return result
	return value
func scenarios() -> Array:
	var result = []
	# This frozen baseline belongs to the original two chapters. New regions
	# receive their own layout/route suite; never regenerate the old baseline.
	for chapter in [1,2]:
		for id in Campaign.CHAPTER_STAGES[chapter]:
			result.append({"key":id,"chapter":chapter,"stage":id,"gate":"PREPARE","supplies":false})
	result.append({"key":"bridge_supplies_burned","chapter":1,"stage":"bridge","gate":"PREPARE","supplies":true})
	result.append({"key":"hs_camp_open","chapter":2,"stage":"hs_camp","gate":"PROBE_1","supplies":false})
	result.append({"key":"hs_camp_counter","chapter":2,"stage":"hs_camp","gate":"COUNTER_DIRECT","supplies":false})
	return result
func enter(scenario: Dictionary) -> void:
	world.load_chapter(scenario.chapter); world.state.reset("normal", scenario.chapter)
	world.state.flags.supplies = scenario.supplies
	if scenario.chapter == 2:
		world.state.tactics = {"gate":scenario.gate,"volley_spent":scenario.gate.begins_with("COUNTER"),"roster":[]}
	world.mode = "playing"; world.hero.reset_combat()
	world.enter_stage(scenario.stage, Vector2.INF, false); world.ui.hide_overlay()
	await settle()
	for enemy in world.enemies: enemy.set_physics_process(false); enemy.set_process(false)
func physical_shapes() -> Array:
	var result = []
	for node in world.terrain.get_children():
		if not node is StaticBody2D: continue
		for child in node.get_children():
			if not child is CollisionShape2D or child.disabled: continue
			var entry = {"at":serializable(node.position + child.position),"layer":node.collision_layer}
			if child.shape is RectangleShape2D: entry.rect = serializable(child.shape.size)
			elif child.shape is CircleShape2D: entry.radius = child.shape.radius
			else: entry.shape = child.shape.get_class()
			result.append(entry)
	return result
func walk_path(path: PackedVector2Array, target: Vector2) -> Dictionary:
	var points = path.duplicate(); points.append(target)
	var reached = true
	for point in points:
		var previous_distance = INF
		for _step in range(250):
			var distance = world.hero.position.distance_to(point)
			if distance <= 1: break
			if distance >= previous_distance - .001:
				reached = false; break
			previous_distance = distance
			world.hero.move_ground((point-world.hero.position).limit_length(8))
		if not reached or world.hero.position.distance_to(point) > 1:
			reached = false; break
	return {"reached":reached,"end":serializable(world.hero.position)}
func capture_snapshot(scenario: Dictionary) -> Dictionary:
	var definition = world.definition
	var origin = Vector2(definition.spawn[0], definition.spawn[1])
	var grid = []
	for y in range(world.terrain.grid.region.size.y):
		for x in range(world.terrain.grid.region.size.x):
			if world.terrain.grid.is_point_solid(Vector2i(x,y)): grid.append([x,y])
	var objects = []
	for object in definition.objects:
		var target = Vector2(object.x,object.y)
		var path = world.terrain.find_path(origin,target,world.hero.radius)
		var entry = {"id":object.id,"kind":object.kind,"at":serializable(target),
			"need":object.get("need", ""),"need_secondary":object.get("need_secondary", ""),
			"to":object.get("to", ""),"group":object.get("group", ""),
			"blocked_feet":world.terrain.blocked(target,world.hero.radius),"path":serializable(path)}
		world.hero.position = origin
		if not path.is_empty():
			entry.walk = walk_path(path,target)
			expect(entry.walk.reached, scenario.key + ": actual movement reaches " + object.id)
		else: entry.walk = {"reached":false,"end":serializable(origin)}
		objects.append(entry)
	world.hero.position = origin
	var water = []
	for rect in definition.get("layout",{}).get("water",[]):
		var center = Vector2(rect[0]+rect[2]*.5,rect[1]+rect[3]*.5)
		water.append({"rect":rect,"center_blocked":world.terrain.blocked(center,0)})
		expect(world.terrain.blocked(center,0),scenario.key + ": water remains impassable")
	return {"geometry":serializable(world.terrain.geometry),"physical_shapes":physical_shapes(),
		"rocks":serializable(world.terrain.rocks),"detail_circles":serializable(world.terrain.detail_circles),
		"huts":definition.huts,"roads":definition.roads,"secondary_roads":definition.get("secondary_roads",[]),
		"spawn":definition.spawn,"arena":definition.get("arena",{}),"groups":definition.groups,
		"props":definition.get("props",[]),"objects":objects,"tactics":definition.get("tactics",{}),
		"solids":definition.get("map_details",{}).get("solids",[]),"water":water,"solid_grid":grid,
		"gate_blocked":world.terrain.blocked(Vector2(1000,560),16) if scenario.stage=="hs_camp" else false,
		"gate_arrow_clear":world.terrain.line_clear(Vector2(910,560),Vector2(1120,560),2) if scenario.stage=="hs_camp" else true}
func resource_contract(scenario: Dictionary) -> void:
	var ground = world.terrain.ground_texture
	expect(ground != null and ground.get_size() == Vector2(1600,1100), scenario.key + ": production ground is a full-size baked texture")
	expect(world.terrain.grain.is_empty() and world.terrain.pools.is_empty(), scenario.key + ": fine terrain is not rebuilt for each runtime scene")
	expect(world.actors.y_sort_enabled and world.terrain.z_index < world.actors.z_index,
		scenario.key + ": upright actors Y-sort above the ground")
	expect(world.ui.layer > world.fx.z_index, scenario.key + ": HUD remains above world effects")
	world.camera.zoom = Vector2.ONE * 1.15
	world._process(0)
	expect(world.camera.zoom.is_equal_approx(Vector2.ONE*1.15), scenario.key + ": normal play retains the shipped camera scale")
	for object in world.definition.objects:
		var marker = world.actors.get_node_or_null(NodePath(object.id))
		expect(is_instance_valid(marker), scenario.key + ": visible interaction anchor exists for " + object.id)
		if marker and object.kind != "graincart":
			expect(marker.position == Vector2(object.x,object.y), scenario.key + ": interaction art shares its actual gameplay position")
func atlas_contract() -> void:
	for pair in [["res://assets/maps/scenery.png","res://assets/maps/scenery.json"],
		["res://assets/maps/hanshui_props.png","res://assets/maps/hanshui_props.json"]]:
		expect(ResourceLoader.exists(pair[0]) and FileAccess.file_exists(pair[1]), "shared atlas and manifest exist: " + pair[0])
		var texture = load(pair[0])
		var manifest = JSON.parse_string(FileAccess.get_file_as_string(pair[1]))
		expect(texture is Texture2D and manifest is Dictionary and not manifest.is_empty(), "shared atlas/manifest load: " + pair[0])
		if not texture is Texture2D or not manifest is Dictionary: continue
		for key in manifest:
			var frame = manifest[key]
			var region = Rect2(frame.region[0],frame.region[1],frame.region[2],frame.region[3])
			expect(region.has_area() and Rect2(Vector2.ZERO,texture.get_size()).encloses(region),"atlas frame is inside its texture: " + key)
			expect(frame.anchor.size() == 2 and is_finite(float(frame.anchor[0])) and is_finite(float(frame.anchor[1])), "atlas frame has a finite ground anchor: " + key)
func compare_value(expected: Variant, actual: Variant, location: String) -> void:
	if expected is Dictionary and actual is Dictionary:
		expect(expected.size()==actual.size(),location+" field count remains unchanged")
		for key in expected:
			expect(actual.has(key),location+" contains "+str(key))
			if actual.has(key): compare_value(expected[key],actual[key],location+"/"+str(key))
	elif expected is Array and actual is Array:
		expect(expected==actual, location+" geometry/route data remains unchanged")
	else: expect(expected==actual,location+" remains unchanged")
func run() -> void:
	var write = "--write-baseline" in OS.get_cmdline_user_args()
	if write and FileAccess.file_exists(BASELINE):
		push_error("Refusing to overwrite an existing map baseline. Preserve it as the before evidence."); quit(1); return
	if not write and not FileAccess.file_exists(BASELINE):
		push_error("Missing local before baseline. Run -- --write-baseline before the map-art edit."); quit(1); return
	world = Game.new(); world.test_mode = true; world.state = MemoryCampaign.new()
	root.add_child(world); world.set_process(false); world.set_physics_process(false)
	await settle()
	var current = {"format":1,"scenarios":{}}
	for scenario in scenarios():
		await enter(scenario)
		resource_contract(scenario)
		current.scenarios[scenario.key] = capture_snapshot(scenario)
		print("MAP_IDENTITY_SCENARIO ",scenario.key)
	atlas_contract()
	current = JSON.parse_string(JSON.stringify(current))
	if write and failures.is_empty():
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://../.qa"))
		var output = FileAccess.open(BASELINE,FileAccess.WRITE)
		expect(output != null,"baseline can be written")
		if output: output.store_string(JSON.stringify(current,"  ",true)); output.close()
		print("MAP_IDENTITY_BASELINE ",ProjectSettings.globalize_path(BASELINE))
	elif not write:
		var expected = JSON.parse_string(FileAccess.get_file_as_string(BASELINE))
		expect(expected is Dictionary,"baseline JSON is valid")
		if expected is Dictionary: compare_value(expected,current,"map")
	print("MAP_IDENTITY_VERIFY ",checks," checks; ",failures.size()," failures; write_baseline=",write)
	world.queue_free(); await process_frame
	quit(0 if failures.is_empty() else 1)
