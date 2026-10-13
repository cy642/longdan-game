extends SceneTree
## Native map regression checks. No player save is opened or written.
## Run: godot --headless --path godot --script res://tests/map_verify.gd
const Game = preload("res://scripts/world.gd")
const Campaign = preload("res://scripts/campaign.gd")
const Terrain = preload("res://scripts/terrain.gd")
const MapDetails = preload("res://scripts/map_details.gd")

class MemoryCampaign:
	extends Campaign
	var attempted_saves = 0
	func read_save() -> Dictionary:
		return {}
	func save() -> bool:
		attempted_saves += 1
		return true

var world
var checks = 0
var failures: Array[String] = []
var walked_distance = 0.0
var route_count = 0

func _initialize() -> void:
	call_deferred("run")

func expect(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)
		push_error("MAP_FAIL: " + message)

func settle() -> void:
	await process_frame
	await physics_frame
	await physics_frame
	await process_frame

func enter(id: String, reset_state: bool = true) -> void:
	if reset_state:
		world.state.reset()
	world.mode = "playing"
	world.pending_stage = {}
	world.hero.reset_combat()
	world.enter_stage(id, Vector2.INF, false)
	world.ui.hide_overlay()
	await settle()

func physics_free(point: Vector2, radius: float = 16.0) -> bool:
	var shape = CircleShape2D.new()
	shape.radius = radius
	var query = PhysicsShapeQueryParameters2D.new()
	query.shape = shape
	query.transform = Transform2D(0, point)
	query.collision_mask = 1
	return world.get_world_2d().direct_space_state.intersect_shape(query, 1).is_empty()

func walk_to(target: Vector2, label: String) -> bool:
	# Read navigation from the built production terrain, including map overlays.
	# Every segment is traversed with the real hero collision shape; a path alone
	# cannot pass this check when navigation and physical geometry disagree.
	var points = world.terrain.find_path(world.hero.position, target, world.hero.radius)
	if points.is_empty():
		expect(false, label + " has a navigation route")
		return false
	points.append(target)
	for point in points:
		var previous_distance = INF
		for _step in range(60):
			var distance = world.hero.position.distance_to(point)
			if distance <= 1.0:
				break
			if distance >= previous_distance - 0.01:
				expect(false, label + " native movement stuck at " + str(world.hero.position) + " heading to " + str(point))
				return false
			previous_distance = distance
			walked_distance += world.hero.move_ground((point - world.hero.position).limit_length(8.0))
		if world.hero.position.distance_to(point) > 1.0:
			expect(false, label + " exceeds movement budget at " + str(point))
			return false
	var reached = world.hero.position.distance_to(target) <= 1.0
	expect(reached, label + " reached by native movement")
	expect(physics_free(world.hero.position, 15.9), label + " ends outside collision geometry")
	return reached

func clear_guards() -> void:
	for enemy in world.enemies:
		enemy.hp = 0
		enemy.collision_layer = 0
		enemy.action = {}

func expect_spawn_clear(actor, label: String) -> void:
	var collision: CollisionShape2D = actor.get_node("GroundCollision")
	var shape_radius: float = collision.shape.radius
	expect(physics_free(actor.position, shape_radius - 0.01), label + " physical spawn clear at " + str(actor.position))

func test_layout_data() -> void:
	var parser = JSON.new()
	var parsed = parser.parse(FileAccess.get_file_as_string("res://data/map_details.json"))
	expect(parsed == OK, "editable map overlay JSON parses")
	if parsed != OK:
		return
	var overlay = parser.data
	expect(overlay is Dictionary and overlay.get("stages", {}).size() == 6, "editable overlay covers all six regions")
	var original = JSON.parse_string(FileAccess.get_file_as_string("res://data/chapter1.json")).StageDefinition
	for id in world.definitions:
		var once: Dictionary = MapDetails.apply_layout(original[id].duplicate(true), id)
		var twice: Dictionary = MapDetails.apply_layout(once.duplicate(true), id)
		expect(JSON.stringify(once, "", true) == JSON.stringify(twice, "", true), id + " layout application is idempotent")
		var usable_roads = true
		for road in once.roads:
			if not road is Array or road.size() < 2:
				usable_roads = false
				continue
			for point in road:
				if not point is Array or point.size() != 2:
					usable_roads = false
					continue
				if not (point[0] is int or point[0] is float) or not (point[1] is int or point[1] is float):
					usable_roads = false
					continue
				var position = Vector2(point[0], point[1])
				if not position.is_finite() or not Rect2(0, 0, 1600, 1100).has_point(position):
					usable_roads = false
		expect(usable_roads, id + " all applied roads contain usable world coordinates")

func test_spawn_and_landmarks() -> void:
	for id in world.definitions:
		await enter(id)
		expect_spawn_clear(world.hero, id + "/hero")
		for ally in world.allies:
			expect_spawn_clear(ally, id + "/" + str(ally.name))
		for enemy in world.enemies:
			expect_spawn_clear(enemy, id + "/" + enemy.group_id + "/" + enemy.kind)
		var solids: Array = world.definition.get("map_details", {}).get("solids", [])
		for index in range(solids.size()):
			var solid: Dictionary = solids[index]
			var center: Vector2
			var extent: Vector2
			if solid.has("rect"):
				var rect: Array = solid.rect
				center = Vector2(rect[0] + rect[2] * 0.5, rect[1] + rect[3] * 0.5)
				extent = Vector2(rect[2], rect[3]) * 0.5
			elif solid.has("circle"):
				var circle: Array = solid.circle
				center = Vector2(circle[0], circle[1])
				extent = Vector2.ONE * circle[2]
			else:
				expect(false, id + " overlay collider " + str(index) + " uses a supported shape")
				continue
			var label = id + " overlay collider " + str(index)
			expect(not physics_free(center, 0.5), label + " exists in the native physics space")
			expect(world.terrain.blocked(center, 0.5), label + " exists in the navigation blocker model")
			# Cardinal samples avoid the deliberately conservative rectangle corner
			# padding in terrain.blocked(), while testing both sides of each edge.
			var matching_edges = true
			for direction in [Vector2.LEFT, Vector2.RIGHT, Vector2.UP, Vector2.DOWN]:
				for gap in [-2.0, 2.0]:
					var point = center + direction * (extent + Vector2.ONE * (16.0 + gap))
					if world.terrain.blocked(point, 16.0) != (not physics_free(point, 16.0)):
						matching_edges = false
			expect(matching_edges, label + " native and navigation collider edges agree")
			var safe_grid = true
			var sample_bounds = Rect2(center - extent - Vector2.ONE * 65, extent * 2 + Vector2.ONE * 130)
			for y in range(28):
				for x in range(40):
					var point = Vector2(x * 40 + 20, y * 40 + 20)
					if not sample_bounds.has_point(point):
						continue
					if not physics_free(point, 17.9):
						if not world.terrain.grid.is_point_solid(Vector2i(x, y)):
							safe_grid = false
			expect(safe_grid, label + " nearby navigation cells never route through physical solids")
			# Tiny posts can fall between grid centers; edge queries above cover them.
		print("MAP_SPAWN_GEOMETRY ", id, " enemies=", world.enemies.size(), " landmarks_colliders=", solids.size())

func test_region_access() -> void:
	for id in world.definitions:
		await enter(id)
		var spawn: Vector2 = world.hero.position
		expect(physics_free(spawn), id + " default spawn is physically clear")
		for object in world.definition.objects:
			var target = Vector2(object.x, object.y)
			expect(physics_free(target), id + "/" + object.id + " interaction center is physically clear")
			world.hero.position = spawn
			await settle()
			if walk_to(target, id + "/" + object.id):
				expect(world.nearest_object().get("id", "") == object.id, id + "/" + object.id + " is selected within interaction range")
				walk_to(spawn, id + "/" + object.id + " return")
		print("MAP_REGION_ACCESS ", id, " objects=", world.definition.objects.size())

func use_exit(object_id: String, destination: String) -> bool:
	var source: String = world.stage
	var object: Dictionary = world.object_by_id(object_id)
	if object.is_empty():
		expect(false, source + " contains exit " + object_id)
		return false
	clear_guards()
	if not walk_to(Vector2(object.x, object.y), source + "/" + object_id):
		return false
	var used: bool = world.interact()
	expect(used and not world.pending_stage.is_empty(), source + "/" + object_id + " schedules real scene transition")
	if world.pending_stage.is_empty():
		return false
	world._physics_process(0.0)
	await settle()
	var arrived: bool = world.stage == destination
	expect(arrived, source + "/" + object_id + " enters " + destination)
	expect(physics_free(world.hero.position), source + "/" + object_id + " arrival spawn is physically clear")
	route_count += 1
	return arrived

func test_story_routes() -> void:
	await enter("mountain")
	for key in ["mountain", "temple", "sword", "adou", "house"]:
		world.state.flags[key] = true
	# Traverse every reversible connection through the production interaction API.
	await use_exit("toVillage", "village")
	await use_exit("backMountain", "mountain")
	await use_exit("toVillage", "village")
	await use_exit("toTemple", "temple")
	await use_exit("backVillage", "village")
	await use_exit("toTemple", "temple")
	await use_exit("toHouse", "house")
	await use_exit("backTemple", "temple")
	await use_exit("shortcut", "village")
	# The healer branch remains accessible from the shortcut arrival point.
	clear_guards()
	var rescue = world.object_by_id("civilians")
	if walk_to(Vector2(rescue.x, rescue.y), "shortcut to healer rescue"):
		expect(world.interact() and world.state.flags.healer, "healer branch activates after returning through the shortcut")
		world.choose_route("continue")
	await use_exit("toTemple", "temple")
	await use_exit("toHouse", "house")
	await use_exit("toFork", "fork")
	await use_exit("backHouse", "house")
	await use_exit("toFork", "fork")
	clear_guards()
	var supply = world.object_by_id("supplies")
	walk_to(Vector2(supply.x, supply.y), "fork optional supply camp")
	var bridge_exit = world.object_by_id("toBridge")
	walk_to(Vector2(bridge_exit.x, bridge_exit.y), "supply camp returns to main route")
	expect(world.interact() and world.mode == "dialog" and world.pending_stage.is_empty(), "bridge commitment asks before the point of no return")
	world.choose_route("continue")
	expect(world.stage == "fork" and not world.state.flags.committed, "declining bridge commitment preserves backtracking")
	await use_exit("backHouse", "house")
	await use_exit("toFork", "fork")
	clear_guards()
	walk_to(Vector2(bridge_exit.x, bridge_exit.y), "return to bridge departure")
	expect(world.interact(), "bridge departure can be used again after backtracking")
	world.choose_route("commit")
	expect(world.state.flags.committed and world.pending_stage.get("id") == "bridge", "committing schedules the correct final region")
	world._physics_process(0.0)
	await settle()
	expect(world.stage == "bridge" and physics_free(world.hero.position), "committed bridge arrival is physically clear")

func test_collision() -> void:
	for id in world.definitions:
		await enter(id)
		for hut in world.definition.huts:
			var center = Vector2(hut[0], hut[1] + 7.5)
			var left = Vector2(hut[0] - hut[2] / 2.0 - 50.0, center.y)
			expect(not physics_free(center, 1.0), id + " building center has a physical blocker")
			if physics_free(left):
				world.hero.position = left
				await settle()
				world.hero.move_ground(Vector2(hut[2] + 100.0, 0))
				expect(world.hero.position.x < hut[0] - hut[2] / 2.0, id + " continuous move cannot cross a building")
		for prop in world.props:
			if not prop.spent:
				expect(not physics_free(Vector2(prop.x, prop.y), 1.0), id + "/" + prop.id + " intact oil cart has a physical blocker")
	await enter("bridge")
	for x in [450.0, 1050.0, 1460.0]:
		world.hero.position = Vector2(x, 340)
		await settle()
		world.hero.move_ground(Vector2(0, -250))
		expect(world.hero.position.y >= 300.0, "river bank blocks northbound movement at x=" + str(x))
	for x in [1210.0, 1270.0, 1330.0]:
		world.hero.position = Vector2(x, 340)
		await settle()
		world.hero.move_ground(Vector2(0, -235))
		expect(world.hero.position.y < 110.0, "wooden bridge northbound lane is open at x=" + str(x))
		world.hero.move_ground(Vector2(0, 235))
		expect(world.hero.position.y > 335.0, "wooden bridge southbound lane is open at x=" + str(x))
	world.hero.position = Vector2(1270, 160)
	await settle()
	world.hero.move_ground(Vector2(-350, 0))
	expect(world.hero.position.x >= 1185, "western bridge edge prevents walking into water")
	world.hero.position = Vector2(1270, 160)
	await settle()
	world.hero.move_ground(Vector2(350, 0))
	expect(world.hero.position.x <= 1355, "eastern bridge edge prevents walking into water")
	world.hero.position = Vector2(1000, 850)
	await settle()
	world.hero.move_ground(Vector2(240, 0))
	expect(world.hero.position.x < 1055, "unburned supplies keep the east blockade physically closed")
	world.state.flags.supplies = true
	await enter("bridge", false)
	world.hero.position = Vector2(1000, 850)
	await settle()
	world.hero.move_ground(Vector2(240, 0))
	expect(world.hero.position.x > 1166, "burned supplies open the east blockade physically; reached " + str(world.hero.position))
	expect(not world.group_alive("bArchers"), "burned supplies remove the bridge archer deployment")

func count_kind(node: Node, kind: String) -> int:
	var total = 1 if node.is_class(kind) else 0
	for child in node.get_children():
		total += count_kind(child, kind)
	return total

func test_reentry() -> void:
	var baseline = {}
	for id in world.definitions:
		await enter(id)
		baseline[id] = [count_kind(world, "Node"), count_kind(world, "StaticBody2D"), count_kind(world, "CollisionShape2D"), world.actors.get_child_count()]
	var orphan_baseline = int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT))
	for cycle in range(3):
		for id in world.definitions:
			var previous_terrain = weakref(world.terrain)
			await enter(id)
			var current = [count_kind(world, "Node"), count_kind(world, "StaticBody2D"), count_kind(world, "CollisionShape2D"), world.actors.get_child_count()]
			expect(previous_terrain.get_ref() == null, id + " releases replaced terrain on cycle " + str(cycle))
			expect(current == baseline[id], id + " node / collider counts remain stable on cycle " + str(cycle))
			expect(int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT)) <= orphan_baseline, id + " creates no orphan nodes on cycle " + str(cycle))
			expect(physics_free(world.hero.position), id + " spawn remains physically clear after reentry")

func run() -> void:
	world = Game.new()
	world.test_mode = true
	# UI construction reads a save even in test_mode: replace state before _ready.
	world.state = MemoryCampaign.new()
	root.add_child(world)
	world.set_process(false)
	world.set_physics_process(false)
	await settle()
	expect(world.definitions.size() == 6, "all six production regions are loaded")
	test_layout_data()
	await test_spawn_and_landmarks()
	await test_region_access()
	await test_story_routes()
	await test_collision()
	await test_reentry()
	expect(world.state.attempted_saves == 0, "test mode never attempts to persist campaign state")
	print("GODOT_MAP_VERIFY ", checks, " checks; ", failures.size(), " failures; transitions=", route_count, "; native_distance=", int(walked_distance))
	world.queue_free()
	await process_frame
	await process_frame
	quit(0 if failures.is_empty() else 1)
