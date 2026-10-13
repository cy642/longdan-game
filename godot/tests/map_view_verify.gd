extends SceneTree
## Exercise the real map against region reloads and current campaign conditions.
## test_mode disables all save writes; no player's progress is loaded or changed.
const Game = preload("res://scripts/world.gd")
const MapView = preload("res://scripts/map_view.gd")
var world
var checks = 0
var failures: Array = []

func _initialize() -> void:
	call_deferred("run")

func expect(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)
		push_error("MAP FAIL: "+message)

func run() -> void:
	root.size = Vector2i(1280,720)
	world = Game.new(); world.test_mode = true
	world.state.save_path = "user://map-view-test-unused.json"
	root.add_child(world)
	world.set_process(false); world.set_physics_process(false)
	await process_frame
	var map = MapView.new(); map.world = world; map.large = true; map.size = Vector2(630,365)
	root.add_child(map)
	var miniature = world.ui.mini_map
	for stage in ["mountain","village","temple","house","fork","bridge","mountain"]:
		world.mode = "map"; world.enter_stage(stage,Vector2(180,920),false)
		await process_frame
		expect(world.terrain.ground_texture!=null,stage+" shares the live baked ground")
		for view in [map,miniature]:
			var bounds: Rect2 = view.map_bounds()
			expect(Rect2(Vector2.ZERO,view.size).encloses(bounds),stage+" map fits its control")
			for corner in [Vector2(45,55),Vector2(1550,55),Vector2(45,1040),Vector2(1550,1040)]:
				world.hero.position = corner; world.camera.position = corner; world.camera.force_update_scroll()
				await process_frame
				var visible: Rect2 = view.camera_bounds(bounds)
				expect(visible.has_area() and bounds.grow(.01).encloses(visible),stage+" camera frame is clipped at "+str(corner))
				expect(bounds.has_point(view.map_position(corner,bounds,8)),stage+" player remains visible at "+str(corner))
			view.queue_redraw()
		await process_frame
	# The locked / open glyph must follow exactly the interaction gate.
	var exit_object: Dictionary = world.object_by_id("toVillage")
	world.state.flags.mountain = false
	expect(map.object_info(exit_object).blocked,"mountain exit is locked before the route is cleared")
	world.state.flags.mountain = true
	expect(not map.object_info(exit_object).blocked,"mountain exit opens with the campaign flag")
	world.enter_stage("village",Vector2(330,495),false)
	var rescue: Dictionary = world.object_by_id("civilians")
	expect(not map.object_info(rescue).complete,"rescue is not marked complete in advance")
	world.state.flags.civilians = true
	expect(map.object_info(rescue).complete,"completed rescue is reflected on the map")
	# Optional overlays do not become mandatory for old or third-party regions.
	world.definition = world.definition.duplicate(true)
	world.definition.erase("secondary_roads"); world.definition.erase("landmarks")
	expect(map.map_landmarks().is_empty(),"original definitions need no landmark field")
	expect(map.route_points({"unknown":true},map.map_bounds()).is_empty(),"unknown route data is ignored")
	world.definition.landmarks = [{"x":220,"y":500,"label":"Visible"},{"x":220,"y":510,"label":"Hidden","hidden":true},{"x":220,"y":520,"label":"Future","need":"unseen_flag"},{"unknown":true}]
	expect(map.map_landmarks().size()==1,"hidden and untriggered landmarks do not reveal later story")
	map.queue_redraw(); miniature.queue_redraw(); await process_frame
	print("MAP_VIEW_VERIFY ",checks," checks, ",failures.size()," failures")
	map.queue_free(); world.queue_free(); await process_frame
	quit(0 if failures.is_empty() else 1)
