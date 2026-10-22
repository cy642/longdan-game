extends SceneTree
## Production-size map shots for before/after visual review. Scenario state is
## explicit and memory-only; these are controlled captures, not a full playthrough.
const Game = preload("res://scripts/world.gd")
const Campaign = preload("res://scripts/campaign.gd")
class MemoryCampaign extends Campaign:
	func read_save() -> Dictionary: return {}
	func save() -> bool: return true
var world
var label = "after"
var captured: Array = []
var failures: Array = []
var requested_hero = Vector2.ZERO
var views = {
	"mountain":Vector2(740,615),"village":Vector2(850,650),
	"temple":Vector2(950,520),"house":Vector2(1040,640),
	"fork":Vector2(1210,720),"bridge":Vector2(1190,450),
	"hs_forest":Vector2(760,670),"hs_grain":Vector2(900,700),
	"hs_return":Vector2(760,800),"hs_camp":Vector2(890,570),
	"hs_river":Vector2(1100,650),"hs_final":Vector2(1000,460)
}
func _initialize() -> void: call_deferred("run")
func expect(value: bool, message: String) -> void:
	if not value: failures.append(message); push_error("MAP_IDENTITY_PREVIEW: "+message)
func reachable_grid_point(cell: Vector2i) -> bool:
	var terrain = world.terrain
	if not terrain.grid.is_in_boundsv(cell) or terrain.grid.is_point_solid(cell): return false
	var point: Vector2 = terrain.grid.get_point_position(cell)
	if terrain.blocked(point,world.hero.radius): return false
	var origin = Vector2(world.definition.spawn[0],world.definition.spawn[1])
	return not terrain.find_path(origin,point,world.hero.radius).is_empty()
func ensure_safe_feet(context: String) -> bool:
	if not world.terrain.blocked(world.hero.position,world.hero.radius): return true
	var requested: Vector2 = world.hero.position
	var nearest: Vector2i = world.terrain.nearest_cell(requested)
	var selected = Vector2.INF
	if reachable_grid_point(nearest):
		selected = world.terrain.grid.get_point_position(nearest)
	else:
		# Prefer the nearest reachable cell center, not an arbitrary corner of
		# a grid cell. A closed gate can split physically empty ground in two.
		var best = INF
		var region: Rect2i = world.terrain.grid.region
		for y in range(region.position.y,region.end.y):
			for x in range(region.position.x,region.end.x):
				var cell = Vector2i(x,y)
				var candidate: Vector2 = world.terrain.grid.get_point_position(cell)
				var distance = requested.distance_squared_to(candidate)
				if distance >= best or not reachable_grid_point(cell): continue
				best = distance; selected = candidate
	if not selected.is_finite():
		expect(false,context+": no reachable collision-free preview foot position"); return false
	world.hero.position = selected
	world.camera.position = selected; world.camera.reset_smoothing(); world.camera.force_update_scroll()
	print("MAP_IDENTITY_SAFE_PLACEMENT ",context," requested=",requested," actual=",selected)
	expect(not world.terrain.blocked(selected,world.hero.radius),context+": snapped feet clear the actual hero radius")
	return true
func native_feet_clear() -> bool:
	var shape = CircleShape2D.new(); shape.radius = world.hero.radius
	var query = PhysicsShapeQueryParameters2D.new()
	query.shape = shape; query.transform = Transform2D(0,world.hero.position); query.collision_mask = 1
	return world.get_world_2d().direct_space_state.intersect_shape(query,1).is_empty()
func enter(id: String, position: Vector2, special: String = "") -> void:
	var chapter = 2 if id.begins_with("hs_") else 1
	world.load_chapter(chapter); world.state.reset("normal",chapter)
	world.state.flags.supplies = true
	if chapter == 2:
		world.state.flags.huangzhong = true; world.state.flags.cart = true
		world.state.tactics = {"gate":"COUNTER_DIRECT","volley_spent":true,"roster":[]}
	if special == "support":
		world.state.flags.huangzhong = false
		var main: Array = world.definitions[id].get("main_groups",[])
		for group in main.slice(0,maxi(0,main.size()-1)): world.state.cleared.append(id+":"+str(group))
	elif special == "closed":
		world.state.tactics = {"gate":"PREPARE","volley_spent":false,"roster":[]}
	elif special == "cart":
		world.state.flags.cart = false
		world.state.tactics = {"escort_index":3,"cart_checkpoint":true}
		for stop in world.definitions[id].tactics.stops:
			if int(stop.index)<3: world.state.cleared.append(id+":"+str(stop.group))
	world.mode = "playing"; world.hero.reset_combat()
	world.enter_stage(id,position,false); world.ui.hide_overlay()
	requested_hero = position
	ensure_safe_feet(id+":"+special)
	world.hero.facing = PI/4; world.hero.update_visual()
	world.camera.position = world.hero.position; world.camera.zoom = Vector2.ONE*1.15
	world.camera.reset_smoothing(); world.camera.force_update_scroll()
	await process_frame; await physics_frame; await physics_frame
func capture(name: String, scenario: String = "theme") -> void:
	# Boss setup may move the hero after enter(); validate every captured
	# gameplay scene, including the additional encounter shots.
	if not ensure_safe_feet(name): return
	world.camera.force_update_scroll(); world.ui.support_clock = 0; world.ui.refresh(.016)
	world.hero.update_visual(); world.fx.queue_redraw()
	# Let process-only visual state (for example foreground occlusion fading)
	# settle. World/physics stay disabled, so this cannot advance combat.
	# Use the same delay in both before and after sources.
	await create_timer(.25).timeout
	await process_frame; await process_frame; await RenderingServer.frame_post_draw
	var feet_clear = not world.terrain.blocked(world.hero.position,world.hero.radius)
	var physical_clear = native_feet_clear()
	expect(feet_clear and physical_clear,name+": hero feet are outside actual terrain collision")
	var path = ProjectSettings.globalize_path("res://../.qa/map-identity-"+label+"-"+name+".png")
	if FileAccess.file_exists(path):
		expect(false,"refusing to replace existing comparison image: "+path); return
	expect(root.get_texture().get_image().save_png(path)==OK,"saved "+name)
	captured.append({"name":name,"stage":world.stage,"scenario":scenario,"image":path,
		"hero":[world.hero.position.x,world.hero.position.y],
		"requested_hero":[requested_hero.x,requested_hero.y],
		"feet_clear":feet_clear,"physical_feet_clear":physical_clear,
		"camera":[world.camera.get_screen_center_position().x,world.camera.get_screen_center_position().y],
		"zoom":world.camera.zoom.x,"viewport":[root.size.x,root.size.y],
		"mode":world.mode,"huangzhong_met":world.state.flags.huangzhong,
		"cart_finished":world.state.flags.cart,"gate":world.state.tactics.get("gate",""),
		"support":world.tactics.support_status() if is_instance_valid(world.tactics) else {}})
	print("MAP_IDENTITY_CAPTURE ",name," ",path)
func run() -> void:
	if DisplayServer.get_name()=="headless":
		push_error("Map identity preview requires the real graphical renderer."); quit(1); return
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--label="): label = arg.trim_prefix("--label=")
	if label.is_empty() or label!=label.validate_filename():
		push_error("Use a plain filename label, for example before or after."); quit(1); return
	var manifest_path = ProjectSettings.globalize_path("res://../.qa/map-identity-"+label+"-manifest.json")
	if FileAccess.file_exists(manifest_path):
		push_error("Refusing to overwrite an existing capture manifest."); quit(1); return
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://../.qa"))
	root.size = Vector2i(1280,720)
	world = Game.new(); world.test_mode = true; world.state = MemoryCampaign.new(); root.add_child(world)
	world.set_process(false); world.set_physics_process(false)
	if root.focus_exited.is_connected(world.on_focus_lost): root.focus_exited.disconnect(world.on_focus_lost)
	await process_frame
	for id in views:
		await enter(id,views[id])
		await capture(id)
	# Gameplay-scale additions expose gate state, task props and telegraphs
	# which a completed-state tour or a full-map contact sheet could hide.
	await enter("hs_grain",Vector2(1080,410),"support")
	expect(world.tactics.support_status().visible,"unfinished grain-road support is visible")
	for enemy in world.enemies:
		if not enemy.is_ranged() and enemy.position.distance_to(world.hero.position)<180:
			enemy.stun = 0; enemy.start_action(world.hero); enemy.advance_action(.16,world.hero); enemy.update_visual(); break
	await capture("hs-grain-support","unfinished support and a real enemy windup")
	await enter("hs_camp",Vector2(890,570),"closed")
	expect(world.terrain.blocked(Vector2(1000,560),16),"PREPARE gate is physically closed")
	await capture("hs-camp-prepare","closed gate before the stratagem")
	await enter("hs_return",Vector2(820,650),"cart")
	expect(is_instance_valid(world.tactics.cart) and not world.state.flags.cart,"unfinished cart exists on its real waypoint")
	await capture("hs-return-cart","unfinished escort at the stone passage")
	await enter("temple",Vector2(950,520))
	world.begin_boss("xiahou"); world.boss.start_action(world.hero); world.boss.advance_action(.28,world.hero); world.boss.update_visual()
	world.camera.position = Vector2(950,520); world.camera.reset_smoothing()
	await capture("temple-windup","real Xiahou windup over the arena material")
	await enter("hs_final",Vector2(1000,460))
	world.begin_boss("dujun"); world.boss.start_action(world.hero); world.boss.advance_action(.3,world.hero); world.boss.update_visual()
	world.camera.position = Vector2(1000,460); world.camera.reset_smoothing()
	await capture("hs-final-windup","real Dujun windup over the iron arena")
	var output = FileAccess.open(manifest_path,FileAccess.WRITE)
	expect(output!=null,"capture manifest writable")
	if output:
		output.store_string(JSON.stringify({"label":label,"renderer":RenderingServer.get_video_adapter_name(),
			"captures":captured,"failures":failures,"player_saves":"MemoryCampaign: no read or write"},"  ",true)); output.close()
	print("MAP_IDENTITY_PREVIEW ",captured.size()," captures; ",failures.size()," failures")
	world.queue_free(); await process_frame
	quit(0 if failures.is_empty() else 1)
