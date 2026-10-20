extends SceneTree
## Real production scenes at the shipped camera scale. Captures never open a save.
const Game=preload("res://scripts/world.gd")
const Campaign=preload("res://scripts/campaign.gd")
class MemoryCampaign extends Campaign:
	func read_save() -> Dictionary: return {}
	func save() -> bool: return true

func _initialize() -> void: call_deferred("run")

func run() -> void:
	if DisplayServer.get_name()=="headless":
		push_error("Theme captures need the graphical renderer."); quit(1); return
	root.size=Vector2i(1280,720)
	var game=Game.new(); game.test_mode=true; game.state=MemoryCampaign.new()
	root.add_child(game)
	game.set_process(false); game.set_physics_process(false)
	if root.focus_exited.is_connected(game.on_focus_lost): root.focus_exited.disconnect(game.on_focus_lost)
	await process_frame
	var views={
		"mountain":Vector2(740,615),"village":Vector2(850,650),
		"temple":Vector2(950,520),"house":Vector2(1040,640),
		"fork":Vector2(1210,720),"bridge":Vector2(1190,450),
		"hs_forest":Vector2(760,670),"hs_grain":Vector2(900,700),
		"hs_return":Vector2(880,700),"hs_camp":Vector2(890,570),
		"hs_river":Vector2(1100,650),"hs_final":Vector2(1000,460)
	}
	for id in views:
		var chapter=2 if id.begins_with("hs_") else 1
		game.load_chapter(chapter); game.state.reset("normal",chapter)
		game.state.flags.supplies=true
		if chapter==2:
			game.state.flags.huangzhong=true; game.state.flags.cart=true
			game.state.tactics={"gate":"COUNTER_DIRECT","volley_spent":true,"roster":[]}
		game.mode="playing"; game.hero.reset_combat()
		game.enter_stage(id,views[id],false); game.ui.hide_overlay()
		game.hero.facing=PI/4; game.hero.update_visual()
		game.camera.position=views[id]; game.camera.zoom=Vector2.ONE*1.15
		game.camera.reset_smoothing(); game.camera.force_update_scroll()
		game.ui.refresh(.1)
		await process_frame; await process_frame; await RenderingServer.frame_post_draw
		var path="res://../.qa/theme-"+id+".png"
		var error=root.get_texture().get_image().save_png(ProjectSettings.globalize_path(path))
		if error!=OK: push_error("Could not capture "+id); quit(1); return
		print("THEME_CAPTURE ",id," camera=",game.camera.zoom)
	game.queue_free(); await process_frame; quit()
