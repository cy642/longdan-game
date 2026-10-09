extends "res://scripts/actor.gd"
## Explicit windup / active / recovery with one buffered deliberate input.
const BUFFER = .14
var qi = 100.0
var rage = 0.0
var potions = 3
var combo = 0
var combo_left = 0.0
var combo_target
var sweep_cd = 0.0
var dash_cd = 0.0
var dash_left = 0.0
var dash_age = 10.0
var dash_dir = 0.0
var invincible = 0.0
var counter_left = 0.0
var last_precision = -1
var buffer: Dictionary = {}
var footprint = 0
var ghost_clock = 0.0

func _init() -> void:
	faction = "hero"; kind = "hero"; speed = 202; radius = 16; facing = -.6

func reset_combat() -> void:
	hp = max_hp; qi = 100; potions = 3; rage = 0
	action = {}; buffer = {}; combo_left = 0; dash_left = 0; dash_cd = 0; sweep_cd = 0; counter_left = 0
	invincible = .7; knockback = Vector2.ZERO; stun = 0; hurt_flash = 0

func attack_direction(aim: float) -> float:
	if is_finite(aim):
		combo_target = null
		return aim
	if not is_instance_valid(combo_target) or not combo_target.body_alive() or position.distance_to(combo_target.position) > 215 or combo_left <= 0:
		combo_target = world.nearest_enemy(position, 215)
	return (combo_target.position - position).angle() if is_instance_valid(combo_target) else facing

func request(kind_name: String, move: Vector2 = Vector2.ZERO, aim: float = INF) -> bool:
	buffer = {}
	if world.mode != "playing": return false
	if perform(kind_name, move, aim): return true
	var wait = 0.0
	if not action.is_empty():
		var d = action.def
		wait = d.windup + d.active - action.t if kind_name == "dash" else d.windup + d.active + d.recovery - action.t
	if kind_name == "dash": wait = maxf(wait, maxf(dash_left, dash_cd))
	else: wait = maxf(wait, maxf(dash_left, sweep_cd if kind_name == "sweep" else 0))
	var resource = kind_name == "attack" or kind_name == "dash" and qi >= 16 or kind_name == "sweep" and qi >= 30 or kind_name == "sword" and world.state.flags.sword and rage >= 100
	if resource and wait > 0 and wait <= BUFFER:
		buffer = {"kind": kind_name, "move": move, "aim": aim, "left": BUFFER}
		return true
	return false

func perform(kind_name: String, move: Vector2, aim: float) -> bool:
	if dash_left > 0: return false
	if kind_name == "dash":
		if dash_cd > 0 or qi < 16: return false
		if not action.is_empty() and action.t >= action.def.windup and action.t < action.def.windup + action.def.active: return false
		action = {}; qi -= 16; dash_cd = .58; dash_left = .22; dash_age = 0; invincible = .24
		dash_dir = move.angle() if move.length() > .1 else facing; ghost_clock = 0
		world.sound.play_cue("dash")
		return true
	if not action.is_empty(): return false
	var key = kind_name
	if key == "attack":
		facing = attack_direction(aim)
		combo = combo % 3 + 1 if combo_left > 0 else 1
		key = "counter" if counter_left > 0 else "thrust" + str(combo)
		counter_left = 0; combo_left = 1.25
	elif key == "sweep":
		if sweep_cd > 0: return false
		if qi < 30:
			world.toast("气力不足，游走回气。")
			return false
		facing = attack_direction(aim); qi -= 30; sweep_cd = 3.4
	elif key == "sword":
		if not world.state.flags.sword:
			world.toast("先击败夏侯恩，夺得青釭剑。")
			return false
		if rage < 100:
			world.toast("命中敌人积累战意，满时可使青釭断势。")
			return false
		facing = attack_direction(aim); rage = 0
	elif key == "heal":
		if hp >= max_hp or potions <= 0:
			world.toast("体力充足，先留住行军药。" if hp >= max_hp else "药已用尽，到营火补满。")
			return false
		potions -= 1
	else: return false
	action = world.new_action(key, world.attacks[key], facing)
	return true

func consume_buffer(dt: float) -> void:
	if buffer.is_empty(): return
	buffer.left -= dt
	if buffer.left < 0:
		buffer = {}; return
	var b = buffer.duplicate()
	if perform(b.kind, b.move, b.aim): buffer = {}

func advance(dt: float, move: Vector2, held_attack: bool, aim: float) -> void:
	tick_common(dt)
	for key in ["combo_left", "sweep_cd", "dash_cd", "dash_left", "invincible", "counter_left"]:
		set(key, maxf(0, float(get(key)) - dt))
	dash_age += dt; qi = minf(100, qi + dt * (0 if dash_left > 0 else 17))
	consume_buffer(dt)
	if action.is_empty():
		if is_finite(aim): facing = aim
		elif move.length() > .1: facing = move.angle()
	if dash_left > 0:
		move_ground(Vector2.from_angle(dash_dir) * 555 * dt)
		ghost_clock -= dt
		if ghost_clock <= 0:
			ghost_clock += .035; world.fx.ghost(self)
	else:
		var slow = 1.0
		if not action.is_empty(): slow = .12 if action.key == "heal" else .38 if action.t < action.def.windup else .62
		move_ground(move * speed * slow * dt)
		var step = int(walk_distance / 32)
		if moving and step != footprint:
			footprint = step; world.sound.play_cue("step")
			world.fx.add("dust", position + Vector2(7 if step % 2 else -7, 1), .3, {"radius": 8.0})
	if held_attack and buffer.is_empty(): perform("attack", move, aim)
	advance_action(dt)
	consume_buffer(0)
	update_visual()

func advance_action(dt: float) -> void:
	if action.is_empty(): return
	var a = action; var d = a.def; var previous = a.t
	a.t += dt; facing = a.dir
	# Interval overlap makes narrow hit / healing windows reliable across slow frames.
	var active_dt = maxf(0, minf(a.t, d.windup + d.active) - maxf(previous, d.windup))
	if active_dt > 0:
		if not a.fired:
			a.fired = true
			if a.key == "heal":
				var amount = minf(85, max_hp - hp); hp += amount
				world.fx.add("heal", position, .65, {"radius": 52.0})
				world.fx.floater(position, "+" + str(int(ceil(amount))) + " 体力", Color("b7e9c4"))
				world.sound.play_cue("heal")
			else:
				world.fx.add("slash", position, d.active + .22, {"dir": a.dir, "radius": d.range, "arc": d.arc, "key": a.key})
				world.sound.play_cue("ultimate" if a.key == "sword" else "heavy" if a.key in ["sweep", "thrust3", "counter"] else "swing")
		if a.key != "heal":
			for enemy in world.melee_targets(self, d, a.dir, 4):
				if a.hits.has(enemy.uid): continue
				a.hits.append(enemy.uid)
				var before = enemy.hp
				enemy.take_hit(d.damage, a.dir, 205 if a.key == "sweep" else 65, "player", d.stagger, a.key in ["sweep", "sword"])
				if enemy.hp < before:
					world.camera_impact(5 if a.key == "sword" else 3 if a.key in ["thrust3", "sweep", "counter"] else 1.5)
					if not a.get("stopped", false):
						world.hit_stop = .055 if a.key == "sword" else .04 if a.key in ["thrust3", "sweep", "counter"] else .018
						a.stopped = true
			for prop in world.props:
				if prop.spent or prop.fuse >= 0 or a.hits.has(prop.id): continue
				if world.attack_hits(position, Vector2(prop.x, prop.y), d, a.dir, prop.r):
					a.hits.append(prop.id); prop.fuse = .9
					world.toast("油车已引燃，立即闪开红圈！"); world.sound.play_cue("ignite")
	if a.t >= d.windup + d.active + d.recovery: action = {}

func take_damage(amount: float, attack_id: int = -1) -> bool:
	if hp <= 0: return false
	if invincible > 0:
		var precision_window = .18 if world.state.difficulty == "story" else .12
		if attack_id >= 0 and dash_left > 0 and dash_age <= precision_window and last_precision != attack_id:
			last_precision = attack_id; counter_left = 1.2; qi = minf(100, qi + 12); rage = minf(100, rage + 8)
			world.state.precision_count += 1
			world.fx.add("perfect", position, .55, {"radius": 80.0})
			world.fx.floater(position, "精准闪避 · 回马枪", Color("b7f1f0")); world.sound.play_cue("perfect")
		return false
	amount *= .64 if world.state.difficulty == "story" else 1
	hp = maxf(0, hp - amount); invincible = .26; hurt_flash = .22
	world.fx.floater(position, "-" + str(int(round(amount))), Color("efad98"))
	world.camera_impact(4); world.sound.play_cue("hurt")
	if not action.is_empty() and action.key == "heal":
		action = {}; world.toast("服药被打断，拉开距离再用药。")
	if hp <= 0: world.defeat("长枪落尘", "记住敌将的收招，这一回还能重新来过。")
	return true
