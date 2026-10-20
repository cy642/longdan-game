extends SceneTree
## Capture the real production sprites at one camera/actor scale; no player save.
const Preview = preload("res://tests/pose_preview.gd")

func _initialize() -> void: call_deferred("run")

func run() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("Hero capture requires graphical rendering."); quit(1); return
	root.size = Vector2i(1280, 1080)
	root.content_scale_size = Vector2i(1280, 1080)
	var label = "after"
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--label="): label = arg.trim_prefix("--label=")
	var preview = Preview.new()
	root.add_child(preview)
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	var output = "res://../.qa/hero-poses-" + label + ".png"
	var error = root.get_texture().get_image().save_png(output)
	if error != OK: push_error("Hero capture failed: " + output); quit(1); return
	print("HERO_POSE_CAPTURE ", ProjectSettings.globalize_path(output))
	preview.queue_free()
	await process_frame
	quit()
