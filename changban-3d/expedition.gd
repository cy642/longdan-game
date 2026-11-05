extends Node3D

const FieldHUD := preload("res://field_hud.gd")
const Drift := preload("res://wind.gd")

@onready var battle = $Battle
var camera := Camera3D.new()
var hud := FieldHUD.new()
var drift := Drift.new()
var mode := "title"
var yaw := 0.0
var pitch := 0.29
var distance := 5.6
var focus := Vector3.ZERO
var drag := false
var elapsed := 0.0
var camera_length := 5.6

func _enter_tree() -> void:
	var keys := {
		"move_left":[KEY_A],"move_right":[KEY_D],"move_forward":[KEY_W],"move_back":[KEY_S],
		"attack":[KEY_J],"heavy":[KEY_K,KEY_Q],"dragon":[KEY_R],"dodge":[KEY_SPACE],"interact":[KEY_E],
		"turn_left":[KEY_LEFT],"turn_right":[KEY_RIGHT]
	}
	for action in keys:
		if InputMap.has_action(action):
			continue
		InputMap.add_action(action)
		for code in keys[action]:
			var event := InputEventKey.new()
			event.physical_keycode = code
			InputMap.action_add_event(action,event)
		if action == "attack":
			var click := InputEventMouseButton.new()
			click.button_index = MOUSE_BUTTON_LEFT
			InputMap.action_add_event(action,click)

func _ready() -> void:
	_setup_light()
	add_child(drift)
	add_child(camera)
	camera.current = true
	camera.near = 0.12
	camera.far = 200.0
	var layer := CanvasLayer.new()
	add_child(layer)
	layer.add_child(hud)
	hud.primary_pressed.connect(_primary)
	hud.secondary_pressed.connect(_secondary)
	hud.sound_pressed.connect(_toggle_sound)
	battle.finished.connect(_end)
	_set_mode("title")
	_title_camera()

func _setup_light() -> void:
	var material := ShaderMaterial.new()
	material.shader = preload("res://art/landscape/daybreak.gdshader")
	var sky := Sky.new()
	sky.sky_material = material
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("#bbccd8")
	env.ambient_light_energy = 0.55
	env.ambient_light_sky_contribution = 0.0
	env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	env.fog_enabled = true
	env.fog_light_color = Color("#a8b7b2")
	env.fog_density = 0.006
	env.fog_sky_affect = 0.1
	env.fog_sun_scatter = 0.22
	var world_env := WorldEnvironment.new()
	world_env.environment = env
	add_child(world_env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-40.0,-38.0,0)
	sun.light_color = Color("#ffe6c9")
	sun.light_energy = 0.78
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 46.0
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
	sun.shadow_bias = 0.045
	add_child(sun)

func _start() -> void:
	battle.restart()
	yaw = 0.0
	pitch = 0.29
	distance = 5.6
	camera_length = distance
	battle.hero.rotation.y = 0.0
	battle.camera_yaw = yaw
	focus = battle.hero.global_position + Vector3.UP * 1.18
	hud.last_hp = 1.0
	_set_mode("play")
	_follow_camera(0.01,true)

func _primary() -> void:
	if mode == "pause":
		_set_mode("play")
	else:
		_start()

func _secondary() -> void:
	if mode == "pause":
		_start()
	else:
		battle.restart()
		_set_mode("title")
		_title_camera()

func _toggle_sound() -> void:
	AudioServer.set_bus_mute(0,not AudioServer.is_bus_mute(0))
	hud.show_mode(mode,AudioServer.is_bus_mute(0))

func _end(won: bool) -> void:
	_set_mode("won" if won else "lost")

func _set_mode(next_mode: String) -> void:
	mode = next_mode
	battle.active = mode == "play"
	_release_mouse()
	hud.show_mode(mode,AudioServer.is_bus_mute(0))
	drift.set_process(mode == "title" or mode == "play")

func _release_mouse() -> void:
	drag = false
	if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT and mode == "play" and is_instance_valid(battle) and hud.is_inside_tree():
		_set_mode("pause")

func _input(event: InputEvent) -> void:
	if not hud.is_inside_tree():
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ESCAPE and mode in ["play","pause"]:
			_set_mode("pause" if mode == "play" else "play")
			get_viewport().set_input_as_handled()
			return
	if mode != "play":
		return
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_RIGHT:
			drag = event.pressed
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED if drag else Input.MOUSE_MODE_VISIBLE
			get_viewport().set_input_as_handled()
		elif event.pressed and event.button_index in [MOUSE_BUTTON_WHEEL_UP,MOUSE_BUTTON_WHEEL_DOWN]:
			distance = clampf(distance + (-0.5 if event.button_index == MOUSE_BUTTON_WHEEL_UP else 0.5), 3.6,8.0)
			get_viewport().set_input_as_handled()
	elif drag and event is InputEventMouseMotion:
		yaw = wrapf(yaw - event.relative.x*0.005,-PI,PI)
		pitch = clampf(pitch + event.relative.y*0.003,0.12,0.78)

func _physics_process(delta: float) -> void:
	if mode == "play":
		yaw = wrapf(yaw - Input.get_axis("turn_left","turn_right")*1.85*delta,-PI,PI)
		_follow_camera(delta)
		hud.update_battle(battle,camera,delta)
	elif mode == "title":
		elapsed += delta
		_title_camera()

func _title_camera() -> void:
	var h: Vector3 = battle.hero.global_position
	var side := sin(elapsed*0.17)*0.28
	camera.position = h + Vector3(2.95 + side,2.11,3.72)
	# The title leaves the right-hand side open for the hero and the road beyond.
	var aim := h + Vector3.UP*1.13
	var forward := camera.position.direction_to(aim)
	var right := forward.cross(Vector3.UP).normalized()
	camera.look_at(aim - right*1.0,Vector3.UP)
	battle.hero.rotation.y = atan2(h.x-camera.position.x,h.z-camera.position.z) + 0.37
	# A held guard at the chapter opening. Both feet remain planted.
	var model = battle.hero_model
	model.pose("idle",elapsed*1.65,0,0)
	model.head.rotation.y += sin(elapsed*0.63)*0.045
	model.silk.rotation.x += -0.09 + sin(elapsed*2.5)*0.07
	camera.fov = 44.0

func _follow_camera(dt: float, instant := false) -> void:
	var target_fov := 56.0
	if battle.action == "dragon":
		var phase: float = battle.elapsed / battle.duration
		target_fov -= 2.0*sin(PI*clampf(phase/.33,0,1))
		target_fov += 3.2*sin(PI*clampf((phase-.33)/.67,0,1))
	camera.fov = target_fov if instant else lerpf(camera.fov,target_fov,1.0-exp(-15.*dt))
	var behind := Vector3(sin(yaw),0,cos(yaw))
	var right := Vector3(behind.z,0,-behind.x)
	var target: Vector3 = battle.hero.global_position + Vector3.UP*1.20 - behind*0.38 + right*.28
	focus = target if instant else focus.lerp(target,1.0-exp(-13.0*dt))
	var offset := (behind*cos(pitch) + Vector3.UP*sin(pitch) + right*.16).normalized()
	var query := PhysicsRayQueryParameters3D.create(focus,focus + offset*distance,2)
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	var allowed := distance
	if not hit.is_empty():
		allowed = maxf(0.65,focus.distance_to(hit.position)-0.22)
	camera_length = allowed if instant or allowed < camera_length else lerpf(camera_length,allowed,1.0-exp(-5.0*dt))
	camera.position = focus + offset*camera_length
	camera.look_at(focus - behind*0.65 + right*.24,Vector3.UP)
	# The shoulder camera looks slightly across the player. WASD follows the
	# actual view direction even during an orbit or when near a house wall.
	battle.camera_yaw = atan2(camera.basis.z.x,camera.basis.z.z)
