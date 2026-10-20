extends SceneTree
## Reproducible UI/feedback captures using real scenes and isolated in-memory saves.
const Game=preload("res://scripts/world.gd")
const Campaign=preload("res://scripts/campaign.gd")
class MemoryCampaign extends Campaign:
	func read_save() -> Dictionary: return last_save.duplicate(true)
	func save() -> bool: last_save=snapshot(); return true
var world

func _initialize() -> void: call_deferred("run")
func capture(label: String) -> void:
	world.camera.position=world.hero.position; world.camera.force_update_scroll()
	world.ui.refresh(.016)
	await process_frame; await process_frame; await RenderingServer.frame_post_draw
	var path=ProjectSettings.globalize_path("res://../.qa/playability-"+label+".png")
	if root.get_texture().get_image().save_png(path)!=OK:
		push_error("capture failed: "+label); quit(1)
	print("PLAYABILITY_CAPTURE ",label)

func run() -> void:
	if DisplayServer.get_name()=="headless":
		push_error("Use graphical Godot for UI review."); quit(1); return
	root.size=Vector2i(1280,720)
	world=Game.new(); world.test_mode=true; world.state=MemoryCampaign.new(); root.add_child(world)
	world.set_process(false); world.set_physics_process(false)
	if root.focus_exited.is_connected(world.on_focus_lost): root.focus_exited.disconnect(world.on_focus_lost)
	await process_frame
	world.load_chapter(2); world.state.reset("normal",2); world.mode="playing"
	world.enter_stage("hs_forest",Vector2(300,850),false); world.ui.hide_overlay()
	var camp={}
	for object in world.definition.objects:
		if object.kind=="camp": camp=object; break
	world.hero.position=Vector2(camp.x,camp.y); world.interact()
	await capture("camp")
	world.choose_battle_art("assault")
	world.hero.position=Vector2(700,690); world.hero.facing=0; world.hero.update_visual()
	world.hero.add_spear_spirit(3)
	await capture("spirit")
	world.hero.request("sweep",Vector2.ZERO,0)
	world.hero.advance_action(world.hero.action.def.windup+.02)
	world.hero.update_visual(); world.fx.queue_redraw()
	await capture("breakthrough")
	world.load_chapter(1); world.state.reset("normal",1)
	world.state.battle_art="counter"; world.state.flags.adou=true; world.state.flags.boss=true
	world.mode="playing"; world.enter_stage("bridge",Vector2(1270,180),false)
	world.finish(); await capture("report")
	world.ui.first_choice.pressed.emit(); await capture("journey")
	world.ui.first_choice.pressed.emit(); await capture("chapter2")
	if world.state.chapter!=2 or world.stage!="hs_forest" or world.state.battle_art!="counter":
		push_error("Journey did not reach chapter two with the selected style."); quit(1); return
	world.queue_free(); await process_frame; quit()
