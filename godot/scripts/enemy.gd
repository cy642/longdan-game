extends "res://scripts/actor.gd"
const BOSS_MOVES = {
	"xiahou": [
		[{"name":"双剑 · 起手","windup":.68,"active":.13,"recovery":.22,"range":142.0,"arc":.8,"damage":22}, {"name":"双剑 · 第二剑","windup":.32,"active":.13,"recovery":1.35,"range":152.0,"arc":1.1,"damage":24}],
		[{"name":"蓄势重斩","windup":1.14,"active":.18,"recovery":1.5,"range":168.0,"arc":.65,"damage":33,"lunge":55}],
		[{"name":"转身横斩","windup":.85,"active":.18,"recovery":1.4,"range":158.0,"arc":2.7,"damage":27}]],
	"zhanghe": [
		[{"name":"三连突 · 一","windup":.7,"active":.12,"recovery":.2,"range":190.0,"arc":.42,"damage":21}, {"name":"三连突 · 二","windup":.34,"active":.12,"recovery":.2,"range":200.0,"arc":.42,"damage":23}, {"name":"三连突 · 三","windup":.42,"active":.16,"recovery":1.45,"range":215.0,"arc":.55,"damage":27}],
		[{"name":"直线冲枪","windup":.96,"active":.23,"recovery":1.55,"range":195.0,"arc":.45,"damage":32,"lunge":160}],
		[{"name":"长枪横扫","windup":1.02,"active":.18,"recovery":1.4,"range":198.0,"arc":2.45,"damage":29}],
		[{"name":"回身枪","windup":.9,"active":.17,"recovery":.25,"range":198.0,"arc":2.45,"damage":25}, {"name":"回马反刺","windup":.45,"active":.13,"recovery":1.4,"range":228.0,"arc":.45,"damage":30}],
		[{"name":"迟势追枪","windup":1.18,"active":.15,"recovery":.27,"range":198.0,"arc":.45,"damage":25,"lunge":90}, {"name":"追枪 · 二","windup":.5,"active":.14,"recovery":.24,"range":208.0,"arc":.5,"damage":26}, {"name":"追枪 · 断势","windup":.68,"active":.18,"recovery":1.5,"range":230.0,"arc":.7,"damage":34}]]
}
var cooldown = 1.0
var alerted = false
var sequence: Array = []
var attack_count = 0
var stagger = 0.0
var stagger_max = 65.0
var stagger_shield = 0.0
var shield_broken = 0.0
var phase2 = false
var phase_time = 0.0

func configure(unit_kind: String, boss: String = "") -> void:
	kind = unit_kind; boss_id = boss
	max_hp = float({"sword":72,"spear":91,"archer":58,"shield":115,"elite":285,"boss":1350 if boss == "zhanghe" else 830}[kind])
	max_hp *= .84 if world.state.difficulty == "story" else 1
	hp = max_hp; radius = 22 if kind == "boss" else 14
	speed = 109 if kind == "boss" else 88 if kind == "archer" else 104
	stagger_max = 125 if kind == "boss" else 90 if kind == "elite" else 65
	display_name = "夏侯恩" if boss == "xiahou" else "张郃" if boss == "zhanghe" else "盾阵校尉" if kind == "elite" else ""
	cooldown = .6 + world.rng.randf() * .5

func start_action(target) -> void:
	var definition
	if kind == "boss":
		if sequence.is_empty():
			var pool = BOSS_MOVES[boss_id]
			var count = 3 if boss_id == "zhanghe" and not phase2 else pool.size()
			sequence = pool[attack_count % count].duplicate(true); attack_count += 1
		definition = sequence.pop_front()
	else:
		definition = world.attacks["arrow" if kind == "archer" else "spear" if kind == "spear" else "shield" if kind in ["shield", "elite"] else "cut"]
	facing = (target.position - position).angle()
	action = world.new_action("enemy", definition, facing)

func advance(dt: float) -> void:
	tick_common(dt)
	if hp <= 0:
		update_visual(); return
	for key in ["cooldown", "stagger_shield", "shield_broken", "phase_time"]:
		set(key, maxf(0, float(get(key)) - dt))
	stagger = maxf(0, stagger - dt * 1.6)
	if stun > 0 or phase_time > 0:
		update_visual(); return
	if boss_id == "zhanghe" and not phase2 and hp <= max_hp * .5:
		phase2 = true; phase_time = 1.35; action = {}; sequence = []
		world.fx.add("phase", position, 1.35, {"radius": 110.0})
		world.fx.floater(position, "张郃 · 枪势再起", Color("f4c994"))
		world.toast("张郃变招：回身反刺与迟势追枪。等连招收完再反击。")
		world.sound.play_cue("phase"); update_visual(); return
	var target = world.hero if kind == "boss" else world.nearest_friend(position, 560 if alerted else 410 if kind == "archer" else 275)
	if world.rescue and group_id.begins_with("rescue"):
		var healer = world.rescue.healer
		if not target or position.distance_to(healer.position) < position.distance_to(target.position) * .8: target = healer
	if not action.is_empty():
		advance_action(dt, target); update_visual(); return
	if not target:
		alerted = false; update_visual(); return
	alerted = true; facing = (target.position - position).angle()
	var distance = position.distance_to(target.position)
	var reach = 225 if kind == "boss" else 445 if kind == "archer" else 138 if kind == "spear" else 78
	if distance < reach and cooldown <= 0 and (kind in ["archer", "boss"] or world.attackers_count() < 2):
		start_action(target)
	elif kind == "archer" and distance < 150:
		move_ground(-Vector2.from_angle(facing) * speed * dt)
	elif distance > reach * .68:
		navigate(target.position, speed, dt)
	for other in world.enemies:
		if other == self or not other.body_alive(): continue
		var offset = position - other.position; var separation = offset.length()
		if separation > .1 and separation < radius + other.radius: move_ground(offset.normalized() * dt * 28)
	update_visual()

func advance_action(dt: float, target) -> void:
	var a = action; var d = a.def; var previous = a.t
	a.t += dt
	if target and a.t < d.windup * .45:
		a.dir = (target.position - position).angle(); facing = a.dir
	if not a.get("ready", false) and a.t >= d.windup - .12:
		a.ready = true; world.sound.play_cue("ready")
	var active_dt = maxf(0, minf(a.t, d.windup + d.active) - maxf(previous, d.windup))
	if active_dt > 0:
		if not a.fired:
			a.fired = true
			if kind == "archer":
				world.fire_arrow(self, a)
			else:
				world.fx.add("enemy_slash", position, d.active + .16, {"dir":a.dir, "radius":d.range, "arc":d.arc, "kind":kind, "lunge":d.get("lunge",0)})
			world.sound.play_cue("enemy_heavy" if d.get("lunge",0) > 0 or d.arc > 2 else "enemy")
		if kind != "archer":
			var travel = d.get("lunge", 0) * active_dt / d.active
			var steps = maxi(1, int(ceil(travel / 8)))
			for segment in range(steps + 1):
				if segment > 0 and travel > 0:
					a.travel += move_ground(Vector2.from_angle(a.dir) * travel / steps)
				for friend in world.combat_friends():
					if not friend.body_alive() or a.hits.has(friend.uid): continue
					if world.attack_hits(position, friend.position, d, a.dir, friend.radius):
						a.hits.append(friend.uid); friend.take_damage(d.damage, a.id)
	if a.t >= d.windup + d.active + d.recovery:
		action = {}; cooldown = .01 if not sequence.is_empty() else .15 if kind == "boss" else .25

func take_hit(damage: float, direction: float, knock: float, source: String, poise: float, break_shield: bool = false) -> void:
	if hp <= 0 or phase_time > 0 or (world.active_boss != "" and world.boss != self): return
	var armored = kind in ["shield", "elite"] and shield_broken <= 0
	var blocked = armored and absf(angle_difference(facing, direction + PI)) < 1.15 and not break_shield
	if blocked:
		damage *= .24; poise *= .45; world.fx.floater(position, "盾挡", Color("b9cdd4"))
	if armored and break_shield:
		shield_broken = 2.8; stun = .8; action = {}; sequence = []; cooldown = .8
		world.fx.add("break", position, .5, {"radius":50.0}); world.fx.floater(position,"破盾",Color("f6d89d"))
	var floor_hp = max_hp * .22 if source == "ally" else 0.0
	var actual = minf(maxf(0, hp - floor_hp), damage)
	if actual <= 0: return
	hp = maxf(floor_hp, hp - actual); hurt_flash = .16; alerted = true
	if source != "ally": world.fx.add("impact", position + Vector2(0,-24), .25, {"dir": direction, "gold": break_shield})
	if source == "player": world.hero.rage = minf(100, world.hero.rage + 4)
	if kind != "boss" and not blocked:
		knockback += Vector2.from_angle(direction) * knock
		if source == "player" and kind != "elite": stun = maxf(stun, .12); action = {}
	if stagger_shield <= 0:
		stagger += poise
		if stagger >= stagger_max:
			stagger = 0; stun = 2.1 if kind == "boss" else 1.3; stagger_shield = 4.4; action = {}; sequence = []; cooldown = 1.2
			world.fx.add("break",position,.5,{"radius":65.0}); world.fx.floater(position,"破势 · 反击",Color("f6d89d")); world.sound.play_cue("break")
	world.fx.floater(position,str(int(round(actual))),Color("a7c6b0") if source == "ally" else Color("fff0bb"))
	if hp <= 0:
		action = {}; sequence = []; collision_layer = 0
		world.state.kills += 1; world.hero.rage = minf(100,world.hero.rage + 8)
		world.sound.play_cue("kill")
		if kind == "boss": world.boss_defeated(self)
		elif kind == "elite":
			world.state.flags.elite = true; world.state.record("粮营盾阵校尉败退，粮草失去了最后的守卫。")
			world.toast("盾阵已破，靠近粮草按 E 点火。"); world.save_progress()
		elif world.rng.randf() < .22: world.loot.append({"pos":position,"life":35.0})
		world.check_groups()
	else: world.sound.play_cue("hit")
