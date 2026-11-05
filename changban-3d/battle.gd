extends Node3D

signal updated
signal finished(won: bool)

const Warrior = preload("res://hero_visual.gd")
const Effects = preload("res://battle_fx.gd")
const Sounds = preload("res://battle_audio.gd")
const Traveller = preload("res://battle_traveller.gd")
const START := Vector3(0.0, 0.0, 14.0)
const RESCUE := Vector3(1.65, 0.0, -0.52)
const NORTH_LIP := -24.2
const EXIT := Vector3(0.0, 0.0, -25.0)
const DRAGON_RECHARGE := 7.5
const RIPOSTE_WINDOW := 1.0
const PERFECT_STEP := 0.13
const RUN_SPEED := 4.7

class Fighter:
	var body: Node3D
	var model: Node3D
	var cue: Node3D
	var kind: String
	var slot: int
	var health: float
	var max_health: float
	var state := "wait"
	var clock := 0.0
	var duration := 0.0
	var cooldown := 0.0
	var stride := 0.0
	var move_weight := 0.0
	var guard_open := 0.0
	var strikes := 0
	var reach := 1.95
	var angle := 0.72
	var power := 13.0
	var swing_heavy := false
	var connected := false

var camera_yaw := 0.0
var active := false
var hero: Node3D
var hp := 100.0
var hp_max := 100.0
var stage := 0

var actors := Node3D.new()
var hero_model: Node3D
var refugee: Node3D
var fx: Node3D
var sound: Node
var foes: Array[Fighter] = []
var pending := ""
var pending_time := 0.0
var action := "idle"
var elapsed := 0.0
var duration := 0.0
var contacted := false
var dash_dir := Vector3.FORWARD
var dash_cooldown := 0.0
var heavy_cooldown := 0.0
var dragon_cooldown := 0.0
var dragon_strokes := 0
var riposte_window := 0.0
var riposte_target: Fighter
var dodge_start := Vector3.ZERO
var motion_clock := 0.0
var aim_from := 0.0
var aim_to := 0.0
var invincible := 0.0
var hit_pause := 0.0
var stride := 0.0
var link := 0
var link_time := 0.0
var move_dir := Vector3.ZERO
var ground_velocity := Vector3.ZERO
var focus: Fighter
var lesson := ""
var lesson_time := 0.0
var baby_start := Transform3D.IDENTITY
var transfer_time := 1.0
var terminal := false
var ending_timer := 0.0
var ending_won := false
var last_threat := 0.0

func _ready() -> void:
	add_child(actors)
	sound = Sounds.new()
	add_child(sound)
	restart()

func restart() -> void:
	for child in actors.get_children():
		actors.remove_child(child)
		child.queue_free()
	sound.silence()
	foes.clear()
	focus = null
	fx = Effects.new()
	actors.add_child(fx)
	hero = Node3D.new()
	hero.name = "赵云"
	actors.add_child(hero)
	hero.position = START
	hero_model = _model(hero, "hero")
	hero_model.pose("idle", 0.0, 0.0, 0.0)
	refugee = Traveller.new()
	actors.add_child(refugee)
	refugee.position = RESCUE
	refugee.rotation.y = -2.58
	_spawn("guard", Vector3(-1.55,0.0,7.15))
	_spawn("shield", Vector3(2.4,0.0,4.15))
	hp = hp_max
	stage = 0
	action = "idle"
	elapsed = 0.0
	duration = 0.0
	link = 0
	link_time = 0.0
	dash_cooldown = 0.0
	heavy_cooldown = 0.0
	dragon_cooldown = 0.0
	dragon_strokes = 0
	riposte_window = 0.0
	riposte_target = null
	dodge_start = START
	motion_clock = 0.0
	aim_from = 0.0
	aim_to = 0.0
	invincible = 0.0
	hit_pause = 0.0
	pending = ""
	pending_time = 0.0
	move_dir = Vector3.ZERO
	ground_velocity = Vector3.ZERO
	stride = 0.0
	last_threat = 0.80
	transfer_time = 1.0
	terminal = false
	ending_timer = 0.0
	ending_won = false
	_note("先截住追兵，阿斗还在村中。", 4.0)

func _model(parent: Node3D, kind: String) -> Node3D:
	var model: Node3D = Warrior.new()
	parent.add_child(model)
	model.configure(kind)
	return model

func _spawn(kind: String, where: Vector3) -> void:
	var e := Fighter.new()
	e.body = Node3D.new()
	actors.add_child(e.body)
	e.body.position = where
	e.body.rotation.y = PI
	e.model = _model(e.body, kind)
	e.kind = kind
	e.slot = foes.size()
	e.max_health = 134.0 if kind == "commander" else (51.0 if kind == "shield" else 43.0)
	e.health = e.max_health
	e.cooldown = 0.60 + 0.29 * e.slot
	foes.append(e)
	e.model.pose("idle", 0.0, 0.0, 0.0)

func _physics_process(dt: float) -> void:
	if not active:
		return
	if terminal:
		if ending_timer > 0.0:
			ending_timer = maxf(0.0, ending_timer - dt)
			if not ending_won:
				hero_model.pose("down", 1.0 - ending_timer / 0.59, stride, 0.0)
			fx.advance(dt)
			if ending_timer <= 0.0:
				active = false
				finished.emit(ending_won)
		return
	var axis := Input.get_vector("move_left","move_right","move_forward","move_back")
	move_dir = Vector3(axis.x, 0, axis.y).rotated(Vector3.UP, camera_yaw)
	if Input.is_action_just_pressed("dodge"):
		_queue("dodge")
	elif Input.is_action_just_pressed("dragon"):
		_queue("dragon")
	elif Input.is_action_just_pressed("heavy"):
		_queue("heavy")
	elif Input.is_action_just_pressed("attack"):
		_queue("attack")
	if hit_pause > 0.0:
		hit_pause -= dt
		return
	invincible = maxf(0.0, invincible - dt)
	motion_clock += dt * 2.1
	dash_cooldown = maxf(0.0, dash_cooldown - dt)
	heavy_cooldown = maxf(0.0, heavy_cooldown - dt)
	dragon_cooldown = maxf(0.0, dragon_cooldown - dt)
	riposte_window = maxf(0.0, riposte_window - dt)
	last_threat = maxf(0.0, last_threat - dt)
	link_time = maxf(0.0, link_time - dt)
	lesson_time = maxf(0.0, lesson_time - dt)
	if pending != "":
		if _can_begin(pending):
			_begin(pending)
			pending = ""
		else:
			pending_time -= dt
			if pending_time <= 0.0:
				pending = ""
	_advance_hero(dt)
	_trace_spear(dt)
	for e in foes:
		if terminal:
			break
		_advance_foe(e, dt)
	if not terminal:
		_follow(dt)
		_progress()
	fx.advance(dt)

func _queue(which: String) -> void:
	if which == "dragon" and dragon_cooldown > 0.17:
		return
	if which == "heavy" and heavy_cooldown > 0.17:
		return
	if which == "dodge" and dash_cooldown > 0.17:
		return
	pending = which
	pending_time = 0.17
	if which == "attack" and action == "dodge" and riposte_window > 0.0:
		pending_time = maxf(pending_time, duration - elapsed + 0.05)

func _can_begin(which: String) -> bool:
	if which == "dragon" and dragon_cooldown > 0.0:
		return false
	if which == "heavy" and heavy_cooldown > 0.0 or which == "dodge" and dash_cooldown > 0.0:
		return false
	if action == "idle":
		return true
	return which == "dodge" and action in ["attack","heavy"] and contacted and elapsed >= duration * 0.56

func _begin(which: String) -> void:
	action = "riposte" if which == "attack" and riposte_window > 0.0 else which
	elapsed = 0.0
	contacted = false
	aim_from = hero.rotation.y
	aim_to = aim_from
	ground_velocity = Vector3.ZERO
	match action:
		"dodge":
			dodge_start = hero.position
			dash_dir = move_dir.normalized() if move_dir.length() > 0.05 else _front(hero)
			hero.rotation.y = _heading(dash_dir)
			duration = 0.32
			invincible = 0.24
			dash_cooldown = 0.59
			sound.play("dodge")
		"dragon":
			duration = 0.98
			dragon_strokes = 0
			dragon_cooldown = DRAGON_RECHARGE
			_aim_weapon(5.0)
			fx.dragon_coil(hero.position, hero.rotation.y)
			sound.play("coil")
			_note("游龙回锋", duration)
		"riposte":
			duration = 0.43
			riposte_window = 0.0
			if riposte_target and riposte_target.health > 0.0 and hero.position.distance_to(riposte_target.body.position) <= 4.0:
				focus = riposte_target
				aim_to = _heading(riposte_target.body.position - hero.position)
			else:
				_aim_weapon(3.8)
			riposte_target = null
			sound.play("swish")
			_note("回马枪", duration + 0.34)
		"attack", "heavy":
			duration = 0.63 if action == "heavy" else 0.37
			if action == "heavy":
				heavy_cooldown = 0.86
			elif link_time <= 0.0:
				link = 0
			link = link + 1 if action == "attack" else 0
			link_time = duration + 0.52
			_aim_weapon(3.65)
			sound.play("swish")

func _aim_weapon(reach: float) -> void:
	var aim := move_dir.normalized() if move_dir.length() > 0.05 else _front(hero)
	var target := _pick_target(aim, reach)
	if target:
		aim = (target.body.position - hero.position).normalized()
		focus = target
	aim_to = _heading(aim)

func _advance_hero(dt: float) -> void:
	var walking := 0.0
	if action == "idle":
		var acceleration := 47.0 if move_dir.length_squared() > 0.001 else 59.0
		ground_velocity = ground_velocity.move_toward(move_dir * RUN_SPEED, acceleration * dt)
		var motion := ground_velocity * dt
		if motion.length_squared() > 0.00001:
			hero.rotation.y = lerp_angle(hero.rotation.y, _heading(ground_velocity), 1.0 - exp(-18.0 * dt))
			var origin := hero.position
			_move_hero(motion)
			var travelled := origin.distance_to(hero.position)
			walking = clampf(travelled / (RUN_SPEED * dt), 0.0, 1.0)
			stride += travelled * 5.3
			if travelled < motion.length() * 0.5:
				ground_velocity = (hero.position - origin) / dt
		hero_model.pose("idle", motion_clock, stride, walking)
		return
	var old_phase := elapsed / duration
	elapsed = minf(elapsed + dt, duration)
	var phase := elapsed / duration
	if action in ["attack","heavy","dragon","riposte"]:
		hero.rotation.y = lerp_angle(aim_from, aim_to, smoothstep(0.0,0.30,phase))
	match action:
		"dodge":
			_move_hero(dash_dir * dt * (11.8 - 7.6 * phase))
		"dragon":
			# Integrate each authored burst up to its contact before checking the hit.
			# A wide frame can cross both windows without hitting twice at the end.
			var cursor := old_phase
			for contact: float in [0.34, 0.64]:
				if cursor < contact and phase >= contact:
					_dragon_step(cursor, contact)
					_dragon_contact(dragon_strokes == 0)
					dragon_strokes += 1
					cursor = contact
			_dragon_step(cursor, phase)
		"riposte":
			var travel := smoothstep(0.12, 0.37, phase) - smoothstep(0.12, 0.37, old_phase)
			_move_hero(_front(hero) * travel * 0.90, 1.12)
			if not contacted and phase >= 0.37:
				contacted = true
				fx.return_thrust(hero.position, hero.rotation.y)
				_resolve_contact(3.12, 0.59, 34.0, true, Color("fff2b9"))
		"attack", "heavy":
			if phase >= 0.22 and phase <= 0.57:
				var speed := 3.5 if action == "heavy" else 2.6
				_move_hero(_front(hero) * speed * dt)
			var contact := 0.49 if action == "heavy" else 0.38
			if not contacted and phase >= contact:
				contacted = true
				_player_contact(action == "heavy")
	hero_model.pose(action, phase, stride, walking)
	if elapsed >= duration:
		action = "idle"

func _player_contact(heavy: bool) -> void:
	var reach := 3.05 if heavy else 2.62
	var angle := 0.99 if heavy else 0.91
	var damage := 30.0 if heavy else (20.0 if link % 3 == 0 else 15.0)
	_resolve_contact(reach, angle, damage, heavy, Color("f1c46c") if heavy else Color("bbf5ff"))

func _trace_spear(dt: float) -> void:
	var cutting := action in ["attack","heavy","riposte","dragon"] and elapsed >= duration*0.16 and elapsed < duration*0.71
	if not cutting and fx.blade_history.is_empty():
		return
	var tint := Color("d4f5ff") if action == "attack" else Color("a2e6ed")
	if action == "riposte":
		tint = Color("fff0b5")
	# Both points are on the animated silver head, in weapon space. A body turn
	# or interrupted thrust leaves the old stroke behind in world space.
	var weapon: Node3D = hero_model.steel
	fx.trace_blade(weapon.to_global(Vector3(0.0,0.0,-1.785)), weapon.to_global(Vector3(0.063,0.025,-1.49)), tint, dt, cutting)

func _dragon_step(a: float, b: float) -> void:
	var approach := smoothstep(0.12, 0.34, b) - smoothstep(0.12, 0.34, a)
	var lunge := smoothstep(0.46, 0.64, b) - smoothstep(0.46, 0.64, a)
	# Keep room for the spear to reach the target instead of driving the breastplate
	# into the enemy between the sweep and the return thrust.
	_move_hero(_front(hero) * (approach * 0.72 + lunge * 1.34), 1.36)

func _dragon_contact(sweep: bool) -> void:
	fx.dragon_cut(hero.position, hero.rotation.y, sweep)
	sound.play("sweep" if sweep else "point")
	if sweep:
		_resolve_contact(2.70, 1.56, 16.0, true, Color("81ddd9"))
	else:
		contacted = true
		_resolve_contact(3.28, 0.55, 23.0, true, Color("e5fbff"), true)

func _resolve_contact(reach: float, angle: float, damage: float, heavy: bool, color: Color, dragon_finish := false) -> void:
	var face := _front(hero)
	var cue := ""
	for e in foes:
		if e.health <= 0.0:
			continue
		var delta := e.body.position - hero.position
		if not _in_sector(face, delta, reach, angle):
			continue
		focus = e
		var contact_pos := e.body.position + Vector3.UP * (1.27 if e.kind == "commander" else 0.99)
		var blocks := e.kind == "shield" and e.guard_open <= 0.0 and e.state in ["wait","windup"] and _front(e.body).dot(-delta.normalized()) > 0.35
		if blocks and not heavy:
			fx.contact(contact_pos, face, Color("efcd82"), false)
			if cue == "": cue = "steel"
			_note("正面被盾挡住了，用重枪破盾。", 1.65)
			continue
		var breaks := blocks and heavy
		if breaks:
			e.guard_open = 2.1
		e.health = maxf(0.0, e.health - damage)
		var armor := e.kind == "commander" and e.state in ["windup","swing"]
		if e.health <= 0.0:
			_set_enemy_state(e, "down", 0.65)
		elif not armor and (heavy or e.kind != "commander" and e.state != "swing"):
			_set_enemy_state(e, "hurt", 0.32 if heavy else 0.13)
			e.cooldown = maxf(e.cooldown, 0.30)
		if not armor:
			e.body.position = _bounds(e.body.position + face * (0.24 if heavy else 0.09))
		fx.contact(contact_pos, face, color, heavy)
		if dragon_finish:
			fx.dragon_impact(contact_pos, hero.rotation.y)
		if breaks:
			_note("破盾！趁盾兵失衡追击。", 1.45)
			cue = "break"
		elif cue != "break":
			cue = "impact"
	if cue != "":
		sound.play(cue)
		hit_pause = 0.042 if heavy or cue == "break" else 0.025
		updated.emit()

func _pick_target(aim: Vector3, reach: float) -> Fighter:
	var target: Fighter = null
	var best := INF
	for e in foes:
		if e.health <= 0:
			continue
		var delta := e.body.position - hero.position
		var dist := delta.length()
		if dist > reach or dist > 0.8 and aim.dot(delta.normalized()) < 0.20:
			continue
		var score := dist + (1.0 - aim.dot(delta.normalized())) * 0.87
		if score < best:
			best = score
			target = e
	return target

func _move_hero(motion: Vector3, striking_distance := 0.54) -> void:
	if motion.length_squared() < 0.0000001:
		return
	var dest := _bounds(hero.position + motion)
	for e in foes:
		if e.health <= 0.0:
			continue
		var previous := hero.position - e.body.position
		var delta := dest - e.body.position
		var dist := delta.length()
		var separation := clampf(previous.length(), 0.54, striking_distance)
		if striking_distance > 0.54 and delta.dot(previous) <= 0.0 and previous.length_squared() > 0.0001:
			dest = e.body.position + previous.normalized() * separation
		elif dist > 0.0001 and dist < separation:
			dest = e.body.position + delta * (separation / dist)
	hero.position = _bounds(dest)

func _bounds(point: Vector3) -> Vector3:
	var bank := clampf(maxf(point.z + 13.8, NORTH_LIP - point.z) / 2.8, 0.0, 1.0)
	var edge := lerpf(4.0, 6.8, bank)
	var bounded := Vector3(clampf(point.x, -edge, edge), 0.0, clampf(point.z, -27.15, 17.7))
	for obstacle in [Vector3(-5.35, 1.25, 1.2), Vector3(6.65, 1.2, 4.3)]:
		var center := Vector3(obstacle.x, 0, obstacle.z)
		var offset := bounded - center
		var length := offset.length()
		if length >= obstacle.y:
			continue
		if length < 0.0001:
			offset = Vector3.RIGHT if center.x < 0.0 else Vector3.LEFT
		bounded = center + offset.normalized() * obstacle.y
		if absf(bounded.x) > edge:
			bounded.x = signf(bounded.x) * edge
			var dx := bounded.x - center.x
			var dz := sqrt(maxf(0.0, obstacle.y * obstacle.y - dx * dx))
			bounded.z = center.z + (dz if offset.z >= 0.0 else -dz)
	return bounded

func _front(node: Node3D) -> Vector3:
	return Vector3.FORWARD.rotated(Vector3.UP, node.rotation.y)

func _heading(direction: Vector3) -> float:
	return atan2(-direction.x, -direction.z)

func _in_sector(face: Vector3, delta: Vector3, reach: float, angle: float) -> bool:
	var dist := delta.length()
	return dist <= reach and (dist < 0.14 or face.dot(delta / dist) >= cos(angle))

func _advance_foe(e: Fighter, dt: float) -> void:
	if not e.body.visible:
		return
	e.cooldown = maxf(0.0, e.cooldown - dt)
	e.guard_open = maxf(0.0, e.guard_open - dt)
	e.clock += dt
	e.move_weight = 0.0
	var delta := hero.position - e.body.position
	var dist := delta.length()
	match e.state:
		"wait":
			if dist < (10.0 if stage == 2 else 11.0):
				e.body.rotation.y = lerp_angle(e.body.rotation.y, _heading(delta), 1.0 - exp(-11.0 * dt))
				var attack_distance := 2.56 if e.kind == "commander" else 1.75
				if dist <= attack_distance and e.cooldown <= 0.0 and last_threat <= 0.0 and _attack_slot_free():
					_arm(e, delta)
				else:
					_walk_enemy(e, delta, dist, attack_distance, dt)
		"windup":
			if e.clock >= e.duration:
				_set_enemy_state(e, "swing", 0.38 if e.swing_heavy else 0.30)
				e.connected = false
				last_threat = maxf(last_threat, 0.42)
				sound.play("swish")
		"swing":
			if not e.connected and e.clock >= e.duration * 0.18:
				e.connected = true
				fx.strike(e.body.position, e.body.rotation.y, e.swing_heavy, Color("ffc683"))
				var facing := _front(e.body)
				var threatened := _in_sector(facing, delta, e.reach, e.angle)
				if action == "dodge" and invincible > 0.0:
					var started_in_arc := _in_sector(facing, dodge_start - e.body.position, e.reach, e.angle)
					if elapsed <= PERFECT_STEP and (threatened or started_in_arc):
						riposte_window = RIPOSTE_WINDOW
						riposte_target = e
						fx.perfect_step(dodge_start, _heading(e.body.position - dodge_start))
						sound.play("parry")
						_note("避锋！按 J 回马枪。", RIPOSTE_WINDOW)
				elif threatened:
					_damage_hero(e.power, e.body.position)
			if e.clock >= e.duration:
				_set_enemy_state(e, "recover", 0.70 if e.kind == "commander" else 0.48)
		"recover","hurt":
			if e.clock >= e.duration:
				_set_enemy_state(e, "wait", 0.0)
				e.cooldown = maxf(e.cooldown, 0.57 if e.kind == "commander" else 0.75)
		"down":
			if e.clock >= e.duration:
				e.model.pose("down", 1.0, e.stride, 0.0)
				if e.clock >= e.duration + 1.0:
					e.body.hide()
				return
	_pose_enemy(e)

func _walk_enemy(e: Fighter, delta: Vector3, dist: float, attack_distance: float, dt: float) -> void:
	var forward := delta.normalized()
	var side := -1.0 if e.slot % 2 == 0 else 1.0
	var desired := Vector3.ZERO
	if dist > attack_distance * 0.93:
		desired = forward + Vector3(forward.z, 0, -forward.x) * side * (0.10 if dist > 3.0 else 0.35)
	elif dist < attack_distance * 0.64:
		desired = -forward * 0.70
	for other in foes:
		if other == e or other.health <= 0:
			continue
		var apart := e.body.position - other.body.position
		var space := apart.length()
		if space > 0.001 and space < 1.10:
			desired += apart / space * (1.10 - space) * 1.68
	var speed := 2.4 if e.kind == "guard" else (1.98 if e.kind == "shield" else 2.18)
	var motion := desired.limit_length(1.0) * dt * speed
	var origin := e.body.position
	e.body.position = _bounds(e.body.position + motion)
	var travelled := origin.distance_to(e.body.position)
	e.move_weight = clampf(travelled / (dt * speed), 0.0, 1.0)
	e.stride += travelled * 5.0

func _attack_slot_free() -> bool:
	for other in foes:
		if other.state in ["windup","swing"]:
			return false
	return true

func _arm(e: Fighter, towards: Vector3) -> void:
	e.strikes += 1
	e.swing_heavy = e.kind == "commander" and e.strikes % 2 == 1
	e.reach = 1.97
	e.angle = 0.83
	e.power = 12.0 if e.kind == "guard" else 14.0
	var windup := 0.71 if e.kind == "shield" else 0.59
	if e.kind == "commander":
		e.reach = 3.05 if e.swing_heavy else 3.65
		e.angle = 1.23 if e.swing_heavy else 0.55
		e.power = 25.0 if e.swing_heavy else 20.0
		windup = 0.94 if e.swing_heavy else 0.74
		if e.health < e.max_health * 0.48:
			windup *= 0.89
	e.body.rotation.y = _heading(towards)
	_set_enemy_state(e, "windup", windup)
	e.cue = fx.warning(e.reach, e.angle, e.kind == "commander")
	e.cue.position = e.body.position + Vector3.UP * 0.073
	e.cue.rotation.y = e.body.rotation.y
	if e.kind == "commander":
		_note("守将压刀，拉开距离或闪过横扫。" if e.swing_heavy else "守将收窄枪路，向侧面闪避。", windup + 0.22)
	sound.play("warn")

func _pose_enemy(e: Fighter) -> void:
	var phase := clampf(e.clock / maxf(e.duration, 0.01), 0.0, 1.0)
	var swing := "heavy" if e.swing_heavy else "attack"
	match e.state:
		"windup": e.model.pose(swing, phase * 0.29, e.stride, 0.0)
		"swing": e.model.pose(swing, 0.29 + phase * 0.49, e.stride, 0.0)
		"recover": e.model.pose(swing, 0.78 + phase * 0.22, e.stride, 0.0)
		"hurt", "down": e.model.pose(e.state, phase, e.stride, 0.0)
		_: e.model.pose("idle", motion_clock + float(e.slot), e.stride, e.move_weight)

func _set_enemy_state(e: Fighter, state: String, time: float) -> void:
	if is_instance_valid(e.cue):
		e.cue.queue_free()
		e.cue = null
	e.state = state
	e.clock = 0.0
	e.duration = time

func _damage_hero(amount: float, source: Vector3) -> void:
	if terminal or invincible > 0.0:
		return
	hp = maxf(0.0, hp - amount)
	riposte_window = 0.0
	riposte_target = null
	invincible = 0.47
	var direction := (hero.position - source).normalized()
	fx.contact(hero.position + Vector3.UP * 1.15, direction, Color("f38c6b"), true)
	sound.play("hurt")
	hero.position = _bounds(hero.position + direction * 0.25)
	if hp <= 0.0:
		_end(false)
		return
	action = "hurt"
	ground_velocity = Vector3.ZERO
	elapsed = 0.0
	duration = 0.23
	contacted = false
	hit_pause = 0.045
	_note("敌兵出招前会亮出刀路，侧闪后可反击。", 1.60)

func _follow(dt: float) -> void:
	if transfer_time < 0.34:
		transfer_time = minf(0.34, transfer_time + dt)
		var t := smoothstep(0.0, 0.34, transfer_time)
		var baby: Node3D = refugee.child_bundle
		var end := Transform3D(Basis.from_euler(Vector3(-0.06, PI - 0.24, -0.34)), Vector3(0.254, 0.214, 0.272))
		baby.transform = baby_start.interpolate_with(end, t)
		baby.position.y += sin(t * PI) * 0.11
	var speed := 0.0
	if stage >= 2:
		var target := hero.position
		var stand_off := 1.44
		# Once Zhao Yun sets foot on the bank the villager walks up beside him.
		# This lets the escort finish even when the player stops at the banner.
		if stage == 3 and hero.position.z < NORTH_LIP:
			target.x += -0.78 if hero.position.x > 0.0 else 0.78
			target.z -= 0.46
			stand_off = 0.08
		var delta := target - refugee.position
		var dist := delta.length()
		if dist > stand_off:
			speed = minf(5.6, 0.97 + (dist - stand_off) * 1.8)
			var step := delta.normalized() * minf(dist - stand_off, speed * dt)
			refugee.position = _bounds(refugee.position + step)
			refugee.rotation.y = lerp_angle(refugee.rotation.y, _heading(delta), 1.0 - exp(-9.0 * dt))
	elif hero.position.distance_to(refugee.position) < 3.5:
		refugee.rotation.y = lerp_angle(refugee.rotation.y, _heading(hero.position - refugee.position), 1.0 - exp(-5.0 * dt))
	refugee.advance(dt, speed)

func _progress() -> void:
	match stage:
		0:
			if _nearest_enemy() == null:
				stage = 1
				_note("追兵已退。去村井找抱着阿斗的乡民。", 3.0)
		1:
			if can_interact() and Input.is_action_just_pressed("interact"):
				_rescue()
		2:
			if _nearest_enemy() == null:
				stage = 3
				_note("桥头已开，护住阿斗，带乡民过桥。", 3.0)
		3:
			if hero.position.z < NORTH_LIP and refugee.position.z < NORTH_LIP:
				stage = 4
				_end(true)

func _rescue() -> void:
	stage = 2
	var baby: Node3D = refugee.child_bundle
	baby.reparent(hero_model.body, true)
	baby_start = baby.transform
	transfer_time = 0.0
	hp = minf(hp_max, hp + 30.0)
	sound.play("rescue")
	_spawn("commander", Vector3(-0.40,0,-17.7))
	_spawn("guard", Vector3(2.46,0,-14.55))
	_note("阿斗已接过，乡民随行。去北桥截住守将。", 3.5)

func _end(won: bool) -> void:
	if terminal:
		return
	terminal = true
	ending_won = won
	ending_timer = 0.42 if won else 0.59
	pending = ""
	riposte_window = 0.0
	riposte_target = null
	if won:
		sound.play("clear")
		hero_model.pose("idle", 0.0, stride, 0.0)
	else:
		hero_model.pose("down", 0.0, stride, 0.0)
	updated.emit()

func _nearest_enemy() -> Fighter:
	var nearest: Fighter = null
	var best := INF
	for e in foes:
		if e.health <= 0.0:
			continue
		var distance := hero.position.distance_squared_to(e.body.position)
		if distance < best:
			nearest = e
			best = distance
	return nearest

func _note(message: String, time: float) -> void:
	lesson = message
	lesson_time = time
	updated.emit()

func can_interact() -> bool:
	return stage == 1 and hero.position.distance_to(refugee.position) <= 1.92

func objective_text() -> String:
	match stage:
		0: return "击退山道追兵"
		1: return "从村井接回阿斗"
		2: return "击破桥头守将与亲兵"
		3: return "护送阿斗与乡民过桥"
	return "长坂突围"

func status_text() -> String:
	if can_interact():
		return "按 E 从乡民手中接过阿斗"
	if riposte_window > 0.0:
		return "避锋！按 J 回马枪。"
	if lesson_time > 0.0:
		return lesson
	match stage:
		0: return "重枪可击穿正面的盾防。"
		1: return "向北进村，寻找披赭衣的乡民。"
		2: return "等守将出招落空，抢进身位还击。"
		3: return "背好阿斗，沿桥走到北端，乡民会跟上。"
	return ""

func objective_position() -> Vector3:
	if stage == 0 or stage == 2:
		var near := _nearest_enemy()
		if near:
			return near.body.position
	if stage == 1:
		return refugee.position
	return EXIT

func enemy_status() -> Dictionary:
	var target := _nearest_enemy()
	if focus and focus.health > 0.0 and hero.position.distance_to(focus.body.position) < 4.0:
		target = focus
	if stage == 2:
		for e in foes:
			if e.kind == "commander" and e.health > 0.0:
				target = e
				break
	if target == null or target.body.position.distance_to(hero.position) > 12.0:
		return {}
	var names := {"guard":"曹军枪兵", "shield":"持盾校尉", "commander":"桥头守将"}
	return {"name": names[target.kind], "health": target.health, "max_health": target.max_health}
