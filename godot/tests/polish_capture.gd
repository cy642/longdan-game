extends SceneTree
## Native renderer evidence for the modeled landmarks and contextual interaction.
const Game = preload("res://scripts/world.gd")
const Campaign = preload("res://scripts/campaign.gd")
class MemoryCampaign extends Campaign:
	func read_save() -> Dictionary: return {}
	func save() -> bool: return true
var world

func _initialize() -> void: call_deferred("run")
func capture(label: String) -> void:
	await process_frame; await process_frame; await RenderingServer.frame_post_draw
	var error = root.get_texture().get_image().save_png("res://../.qa/polish-"+label+".png")
	if error != OK: push_error("POLISH_CAPTURE failed "+label); quit(1)
	print("POLISH_CAPTURE ",label)

func run() -> void:
	if DisplayServer.get_name() == "headless": quit(1); return
	root.size = Vector2i(1280,720)
	world = Game.new(); world.test_mode = true; world.state = MemoryCampaign.new()
	root.add_child(world); world.set_process(false); world.set_physics_process(false)
	await process_frame
	for row in [["temple",Vector2(960,470)],["house",Vector2(1080,540)],["fork",Vector2(1260,825)],["bridge",Vector2(1110,430)]]:
		world.mode="playing"; world.enter_stage(row[0],row[1],false); world.ui.hide_overlay()
		world.camera.position=row[1]; world.camera.force_update_scroll(); world.ui.refresh(.1)
		await capture(row[0])
	world.mode="playing"; world.enter_stage("mountain",Vector2(1110,295),false); world.ui.hide_overlay()
	world.camera.position=Vector2(1150,390); world.camera.force_update_scroll(); world.ui.refresh(.1)
	await capture("camp-focus")
	world.mode="playing"; world.enter_stage("mountain",Vector2(1320,265),false); world.ui.hide_overlay()
	world.camera.position=Vector2(1190,370); world.camera.force_update_scroll(); world.ui.refresh(.1)
	await capture("locked-exit")
	world.queue_free(); await process_frame; quit()
