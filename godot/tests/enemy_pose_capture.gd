extends SceneTree
## Real-renderer contact sheet and optional 30 fps loop samples. No save access.
const Preview = preload("res://tests/enemy_pose_preview.gd")
func _initialize() -> void: call_deferred("run")

func capture(path: String) -> void:
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	var result = root.get_texture().get_image().save_png(path)
	if result != OK: push_error("Enemy capture failed: " + path); quit(1)

func run() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("Enemy capture requires graphical rendering."); quit(1); return
	root.size = Vector2i(1280, 720)
	var label = "after"
	var sequence = false
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--label="): label = arg.trim_prefix("--label=")
		if arg == "--sequence": sequence = true
	var folder = "res://../.qa/enemy-" + label
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(folder))
	var preview = Preview.new(); root.add_child(preview); preview.set_process(false)
	await capture(folder + "/contact-right.png")
	preview.face = PI
	for i in range(preview.sample_units.size()): preview.sample(preview.sample_units[i], i % preview.PHASES.size())
	await capture(folder + "/contact-left.png")
	if sequence:
		preview.face = 0; preview.show_live(true); preview.set_process(false)
		for frame in range(195):
			preview.sample_live(frame / 30.0)
			await capture(folder + "/frame-%03d.png" % frame)
	print("ENEMY_POSE_CAPTURE ", ProjectSettings.globalize_path(folder))
	preview.queue_free(); await process_frame; quit()
