extends SceneTree
## Actual Godot renderer captures. Never reads or writes a player save.
const Game = preload("res://scripts/world.gd")
const Campaign = preload("res://scripts/campaign.gd")
class MemoryCampaign extends Campaign:
	func read_save() -> Dictionary: return {}
	func save() -> bool: return true

func _initialize() -> void:
	call_deferred("run")

func capture(name: String) -> void:
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	var error = root.get_texture().get_image().save_png("res://../.qa/" + name + ".png")
	if error != OK:
		push_error("Screenshot failed: " + name)
		quit(1)
	print("MAP_CAPTURE ", name)

func run() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("Map capture requires graphical rendering."); quit(1); return
	root.size = Vector2i(1280, 720)
	var label = "after"
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--label="): label = arg.trim_prefix("--label=")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://../.qa"))
	var world = Game.new()
	world.test_mode = true
	world.state = MemoryCampaign.new()
	root.add_child(world)
	world.set_physics_process(false)
	world.set_process(false)
	await process_frame
	for scenario in [["mountain", Vector2(1150,380)], ["village", Vector2(470,560)], ["temple",Vector2(700,520)], ["house",Vector2(1040,480)], ["fork",Vector2(1010,730)], ["bridge",Vector2(1130,360)]]:
		world.mode = "playing"
		world.enter_stage(scenario[0], scenario[1], false)
		world.ui.hide_overlay()
		world.camera.position = scenario[1]
		world.camera.force_update_scroll()
		world.ui.refresh(.1)
		await capture(label + "-" + scenario[0])
		if scenario[0] in ["village", "temple", "bridge"]:
			world.pause("map")
			await capture(label + "-" + scenario[0] + "-map")
			world.resume()
	world.queue_free()
	await process_frame
	quit()
