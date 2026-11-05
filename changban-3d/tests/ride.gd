extends SceneTree

# Drives only normal player inputs from the title to the northern bank.
# Pass -- --stills=D:/an/existing/directory for rendered PNGs.
var game
var tick := 0
var ride_tick := 0
var seen := {}
var captures := {}
var queued_capture := ""
var destination := ""
var film_dir := ""
var pause_position := Vector3.ZERO
var pause_stage := 0
var mode := "ride"
var result_time := 0
var resume_ticks := 0
var held := {}
var failures := 0
var dragon_used := false
var stopped := false

func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--stills="):
			destination = arg.trim_prefix("--stills=")
		if arg.begins_with("--film="):
			film_dir = arg.trim_prefix("--film=")
	call_deferred("_boot")

func _boot() -> void:
	game = load("res://longdan.tscn").instantiate()
	root.add_child(game)
	current_scene = game
	var colored := false
	var ridge_count := 0
	for mesh in game.get_node("Landscape").find_children("*","MeshInstance3D",true,false):
		var material = mesh.get_active_material(0)
		if material is BaseMaterial3D and material.vertex_color_use_as_albedo:
			colored = true
		if str(mesh.name).begins_with("Painted distant ridge") and mesh.material_override is ShaderMaterial:
			ridge_count += 1
	_check(colored and ridge_count >= 3, "painted surfaces and three distant ridges imported")
	_check(game.get_node("Landscape").find_children("*","CollisionShape3D",true,false).size() >= 6, "solid camera obstacles")
	if not destination.is_empty() or not film_dir.is_empty():
		RenderingServer.frame_post_draw.connect(_after_draw)
	physics_frame.connect(_drive)

func _press(action: String, state: bool) -> void:
	if state == bool(held.get(action,false)):
		return
	held[action] = state
	if state:
		Input.action_press(action)
	else:
		Input.action_release(action)

func _release_all() -> void:
	for key in held.keys():
		_press(key,false)

func _key(code: Key, is_down: bool) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.pressed = is_down
	Input.parse_input_event(event)
	Input.flush_buffered_events()

func _check(value: bool, label: String) -> void:
	print(("OK " if value else "FAIL ") + label)
	if not value:
		failures += 1

func _save(label: String) -> void:
	if destination.is_empty() or captures.has(label) or not queued_capture.is_empty():
		return
	queued_capture = label

func _after_draw() -> void:
	if not film_dir.is_empty() and tick % 5 == 0 and mode == "ride" and game.mode == "play" and tick > 32:
		var frame := root.get_texture().get_image()
		frame.resize(800,450,Image.INTERPOLATE_LANCZOS)
		frame.save_jpg(film_dir.path_join("frame-%05d.jpg" % tick),0.91)
	if not queued_capture.is_empty():
		var path := destination.path_join(queued_capture + ".png")
		var result := root.get_texture().get_image().save_png(path)
		_check(result == OK, "frame " + queued_capture)
		captures[queued_capture] = true
		queued_capture = ""

func _finish() -> void:
	stopped = true
	_release_all()
	print("CHANGBAN 3D RIDE | stages ", seen.keys()," | failures ", failures)
	quit(0 if failures == 0 else 1)

func _drive() -> void:
	if stopped:
		return
	tick += 1
	if tick > 9500:
		_check(false,"ride deadline at " + str(game.battle.stage) + ", " + str(game.battle.hero.position))
		_finish()
		return
	if tick == 4:
		_check(game.mode == "title" and not game.battle.active, "title and inert battlefield")
		_save("01-title")
	if tick == 8:
		_key(KEY_ENTER,true)
	if tick == 9:
		_key(KEY_ENTER,false)
	if game.mode == "title":
		if tick > 35:
			_check(false,"title keyboard start")
			_finish()
		return
	if game.mode == "won":
		if result_time == 0:
			result_time = tick
			_release_all()
			_check(seen.has(0) and seen.has(1) and seen.has(2) and seen.has(3), "four stages reached by inputs")
			_check(game.battle.refugee.position.z < -24.2, "escort crossed")
			_check(dragon_used, "player cast both strokes in normal combat")
			_save("07-clear")
		if tick - result_time == 6:
			game.hud.primary.pressed.emit()
			_check(game.mode == "play" and game.battle.stage == 0 and game.battle.hp == game.battle.hp_max, "successful replay resets health and objectives")
			mode = "stand"
		return
	if game.mode == "lost":
		_check(mode == "stand", "loss and retry")
		if mode == "stand":
			game.hud.primary.pressed.emit()
			_check(game.battle.active and game.battle.stage == 0 and game.battle.hp > 0, "retry after defeat")
		_finish()
		return
	if game.mode == "pause":
		resume_ticks += 1
		if resume_ticks % 8 == 0:
			if resume_ticks == 8:
				_check(game.battle.hero.position.is_equal_approx(pause_position) and pause_stage == game.battle.stage,"pause holds simulation")
			_key(KEY_ESCAPE,true)
			_key(KEY_ESCAPE,false)
		return
	if mode == "stand":
		return
	ride_tick += 1
	var b = game.battle
	if ride_tick == 12:
		_save("02-road")
	if ride_tick == 17:
		pause_position = b.hero.position
		pause_stage = b.stage
		_key(KEY_ESCAPE,true)
		_key(KEY_ESCAPE,false)
		return
	if not seen.has(b.stage):
		seen[b.stage] = tick
		print("STAGE ", b.stage," tick ",tick," hp ",b.hp)
	var goal: Vector3 = b.objective_position()
	var delta: Vector3 = goal - b.hero.position
	var combat: bool = b.stage in [0,2] and not b.terminal
	var near := delta.length() < 2.18
	var direction := delta.normalized() if not near or not combat else Vector3.ZERO
	direction = direction.rotated(Vector3.UP,-b.camera_yaw)
	if b.stage == 3 and b.hero.position.z < -25.10:
		direction = Vector3.ZERO
	_press("move_forward",direction.z < -0.18)
	_press("move_back",direction.z > 0.18)
	_press("move_left",direction.x < -0.18)
	_press("move_right",direction.x > 0.18)
	_press("interact",b.can_interact() and tick % 4 == 0)
	var fighting: bool = combat and delta.length() < 3.0
	var cast: bool = combat and delta.length() < 3.75 and b.dragon_cooldown <= 0
	_press("dragon",cast and tick % 5 == 0)
	_press("heavy",fighting and b.heavy_cooldown <= 0.06 and tick % 5 == 0)
	_press("attack",fighting and b.heavy_cooldown > 0.06 and tick % 6 == 0)
	if b.stage == 0 and b.action in ["attack","heavy"] and b.contacted and delta.length() < 3.0:
		_save("03-skirmish")
	if b.action == "dragon":
		if b.dragon_strokes == 1:
			_save("08-dragon-sweep")
		elif b.dragon_strokes == 2:
			dragon_used = true
			_save("09-dragon-lance")
	if b.stage == 1 and b.hero.position.z < 2.8 and b.hero.position.z > 0.4:
		_save("04-village")
	if b.stage == 2 and b.hero.position.z < -9.0:
		for fighter in b.foes:
			if fighter.kind == "commander" and fighter.state == "windup":
				_save("05-commander")
	if b.stage == 3 and b.hero.position.z < -15.0 and b.hero.position.z > -21.0:
		_save("06-crossing")
