extends "res://scripts/actor.gd"
const EnemyRoster = preload("res://scripts/enemy_roster.gd")
const ChangbanCombat = preload("res://scripts/changban_combat.gd")
const BOSS_MOVES = {
	"warden": [
		[{"name":"扣步落锤","windup":1.05,"active":.18,"recovery":1.20,"range":180.0,"arc":.75,"damage":29,"lock_fraction":.32,"style":"warden_drop"}],
		[{"name":"拦门横锤","windup":1.15,"active":.20,"recovery":1.35,"range":185.0,"arc":1.65,"damage":31,"lock_fraction":.32,"style":"warden_sweep"}],
		[{"name":"震砖重落","windup":1.25,"active":.18,"recovery":1.40,"range":191.0,"arc":.75,"damage":32,"lock_fraction":.25,"hit_shape":"circle","hit_offset":115.0,"hit_radius":76.0,"style":"warden_quake"}],
		[{"name":"压门回锤 · 扣步","windup":.85,"active":.20,"recovery":.20,"range":105.0,"arc":.60,"damage":23,"lunge":80.0,"lock_fraction":.25,"style":"warden_step"}, {"name":"压门回锤 · 迟势回扫","windup":.75,"active":.20,"recovery":1.45,"range":190.0,"arc":1.70,"damage":29,"lock_fraction":.25,"style":"warden_return"}]],
	"xiahou": [
		[{"name":"双剑 · 起手","windup":.68,"active":.13,"recovery":.22,"range":142.0,"arc":.8,"damage":22}, {"name":"双剑 · 第二剑","windup":.32,"active":.13,"recovery":1.35,"range":152.0,"arc":1.1,"damage":24}],
		[{"name":"蓄势重斩","windup":1.14,"active":.18,"recovery":1.5,"range":168.0,"arc":.65,"damage":33,"lunge":55}],
		[{"name":"转身横斩","windup":.85,"active":.18,"recovery":1.4,"range":158.0,"arc":2.7,"damage":27}]],
	"zhanghe": [
		[{"name":"三连突 · 一","windup":.7,"active":.12,"recovery":.2,"range":190.0,"arc":.42,"damage":21}, {"name":"三连突 · 二","windup":.34,"active":.12,"recovery":.2,"range":200.0,"arc":.42,"damage":23}, {"name":"三连突 · 三","windup":.42,"active":.16,"recovery":1.45,"range":215.0,"arc":.55,"damage":27}],
		[{"name":"直线冲枪","windup":.96,"active":.23,"recovery":1.55,"range":195.0,"arc":.45,"damage":32,"lunge":160}],
		[{"name":"长枪横扫","windup":1.02,"active":.18,"recovery":1.4,"range":198.0,"arc":2.45,"damage":29}],
		[{"name":"回身枪","windup":.9,"active":.17,"recovery":.25,"range":198.0,"arc":2.45,"damage":25}, {"name":"回马反刺","windup":.45,"active":.13,"recovery":1.4,"range":228.0,"arc":.45,"damage":30}],
		[{"name":"迟势追枪","windup":1.18,"active":.15,"recovery":.27,"range":198.0,"arc":.45,"damage":25,"lunge":90}, {"name":"追枪 · 二","windup":.5,"active":.14,"recovery":.24,"range":208.0,"arc":.5,"damage":26}, {"name":"追枪 · 断势","windup":.68,"active":.18,"recovery":1.5,"range":230.0,"arc":.7,"damage":34}]],
	"vanguard": [
		[{"name":"长戟点阵","windup":.78,"active":.15,"recovery":1.10,"range":195.0,"arc":.30,"damage":25,"lock_fraction":.38,"style":"vanguard_thrust"}],
		[{"name":"压阵冲锋","windup":1.00,"active":.30,"recovery":1.25,"range":110.0,"arc":.38,"damage":29,"lunge":150.0,"lock_fraction":.30,"style":"vanguard_charge"}],
		[{"name":"迟势横扫","windup":1.15,"active":.20,"recovery":1.35,"range":200.0,"arc":1.55,"damage":31,"lock_fraction":.38,"style":"vanguard_sweep"}],
		[{"name":"破阵回戟 · 突进","windup":.80,"active":.25,"recovery":.18,"range":110.0,"arc":.38,"damage":23,"lunge":132.0,"lock_fraction":.30,"style":"vanguard_charge"}, {"name":"破阵回戟 · 迟势回扫","windup":.70,"active":.20,"recovery":1.35,"range":205.0,"arc":1.60,"damage":30,"lock_fraction":.25,"style":"vanguard_return"}]],
	"dujun": [
		[{"name":"钩锁探身","windup":.95,"active":.15,"recovery":1.10,"range":192.0,"arc":.28,"damage":23,"pull":72.0,"style":"hook"}],
		[{"name":"双轮重斧 · 起斩","windup":.75,"active":.16,"recovery":.12,"range":162.0,"arc":1.24,"damage":24,"style":"axe"}, {"name":"双轮重斧 · 迟势回斩","windup":.45,"active":.17,"recovery":1.30,"range":180.0,"arc":1.60,"damage":28,"style":"axe_return"}],
		[{"name":"撼地断营","windup":1.20,"active":.20,"recovery":1.50,"range":214.0,"arc":1.08,"damage":35,"style":"slam"}],
		[{"name":"断锁追斩 · 短冲","windup":.60,"active":.22,"recovery":.20,"range":112.0,"arc":.48,"damage":22,"lunge":112.0,"style":"rush"}, {"name":"断锁追斩 · 扫营","windup":.48,"active":.18,"recovery":1.40,"range":184.0,"arc":1.85,"damage":30,"style":"axe_return"}]]
}
const SCOUT_CHAIN = [
	{"name":"双刀 · 起斩","windup":.50,"active":.12,"recovery":.18,"range":88.0,"arc":.82,"damage":13,"style":"dual_cut"},
	{"name":"双刀 · 返斩","windup":.28,"active":.12,"recovery":.90,"range":96.0,"arc":1.02,"damage":15,"style":"dual_return"}]
const CROSSBOW_ATTACK = {"name":"汉水连弩 · 双发","windup":.90,"active":.29,"recovery":1.40,"range":445.0,"arc":.10,"damage":10,"projectile":true,"double_shot":true,"lock_fraction":.5,"style":"crossbow"}
const IRONSHIELD_ATTACK = {"name":"铁盾撞阵","windup":.95,"active":.20,"recovery":1.10,"range":82.0,"arc":.72,"damage":22,"lunge":86.0,"lock_fraction":.28,"style":"shield_charge"}
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
var hit_interrupt_guard = 0.0
var interrupt_guard_noticed = false
# A visual clock for an actual poise break, separate from the longer period
# during which poise cannot build again. Other stuns must not claim a break.
var poise_break_left = 0.0
var visual_profile: Dictionary = {}

func configure(unit_kind: String, boss: String = "") -> void:
	kind = unit_kind; boss_id = boss
	# The region is authoritative for the art family. Review worlds may not
	# expose Campaign.chapter, and restored squads keep their original kind.
	var region = str(world.get("stage")) if is_instance_valid(world) and world.get("stage") != null else ""
	var chapter_id = 4 if region.begins_with("cc_") else 3 if region.begins_with("jg_") else 2 if region.begins_with("hs_") else 1
	visual_profile = EnemyRoster.resolve(chapter_id,region,kind,boss_id,group_id)
	max_hp = float({"sword":72,"spear":91,"archer":58,"shield":115,"elite":285,"scout":75,"crossbow":65,"ironshield":140,"boss":1500 if boss == "warden" else 1450 if boss in ["dujun","vanguard"] else 1350 if boss == "zhanghe" else 830}.get(kind,72))
	max_hp *= .84 if world.state.difficulty == "story" else 1
	hp = max_hp; radius = 22 if kind == "boss" else 14
	speed = 109 if kind == "boss" else 88 if is_ranged() else 118 if kind == "scout" else 87 if kind == "ironshield" else 104
	stagger_max = 145 if boss == "warden" else 140 if boss == "vanguard" else 135 if boss == "dujun" else 125 if kind == "boss" else 90 if kind in ["elite","ironshield"] else 65
	display_name = str(visual_profile.name)
	cooldown = .6 + world.rng.randf() * .5

func is_ranged() -> bool:
	return kind in ["archer","crossbow"]

func combat_status() -> String:
	if hp <= 0 or get_meta("withdrawing",false): return ""
	if phase_time > 0: return "phase"
	if poise_break_left > 0 and stun > 0: return "break"
	if not action.is_empty() and action.t >= action.def.windup + action.def.active and sequence.is_empty(): return "recovery"
	if hit_interrupt_guard > 0 and stun <= 0 and kind not in ["boss","elite"]: return "guard"
	if shield_broken > 0: return "shield"
	return ""

func combat_status_remaining(status: String) -> float:
	match status:
		"break": return clampf(minf(poise_break_left,stun)/(2.1 if kind == "boss" else 1.3),0,1)
		"guard": return clampf(hit_interrupt_guard/.65,0,1)
		"shield": return clampf(shield_broken/2.8,0,1)
		"recovery":
			if not action.is_empty():
				var d = action.def
				return clampf((d.windup+d.active+d.recovery-action.t)/maxf(.001,d.recovery),0,1)
	return 0.0

func ranged_slot_available() -> bool:
	if is_instance_valid(world.get("tactics")) and world.tactics.has_method("ranged_hazard_active") and world.tactics.ranged_hazard_active(): return false
	# A burst owns one slot through its reload, so a second archer cannot
	# silently overlap the delayed second bolt or its recovery indication.
	for other in world.enemies:
		if other == self or not other.body_alive() or not other.is_ranged(): continue
		if not other.action.is_empty(): return false
	return true

func melee_path_clear(target) -> bool:
	# The same terrain bodies that stop charges and arrows also stop a long
	# hook or an axe from hitting through the far side of a camp wall.
	var query = PhysicsRayQueryParameters2D.create(position,target.position,1)
	return get_world_2d().direct_space_state.intersect_ray(query).is_empty()

func start_action(target) -> void:
	var definition
	if kind == "boss":
		if sequence.is_empty():
			var pool = BOSS_MOVES[boss_id]
			var count = 3 if boss_id in ["zhanghe","dujun","vanguard","warden"] and not phase2 else pool.size()
			sequence = pool[attack_count % count].duplicate(true); attack_count += 1
		definition = sequence.pop_front()
	elif kind == "scout":
		if sequence.is_empty(): sequence = SCOUT_CHAIN.duplicate(true)
		definition = sequence.pop_front()
	elif kind == "crossbow": definition = CROSSBOW_ATTACK
	elif kind == "ironshield": definition = IRONSHIELD_ATTACK
	else:
		definition = world.attacks["arrow" if kind == "archer" else "spear" if kind == "spear" else "shield" if kind in ["shield", "elite"] else "cut"]
	facing = (target.position - position).angle()
	action = world.new_action("enemy", definition, facing)
	if is_ranged(): action.shots_fired = 0

func advance(dt: float) -> void:
	if visual: visual.advance_time(dt)
	tick_common(dt)
	if hp <= 0:
		action = {}; sequence = []
		update_visual(); return
	if get_meta("withdrawing",false):
		# Retreating soldiers keep their identity/HP for the river encounter.
		# Their old windup and queued combo cannot fire while leaving camp.
		action = {}; sequence = []; cooldown = maxf(cooldown,.6)
		if stun <= 0: navigate(get_meta("retreat_target",position),speed,dt)
		update_visual(); return
	for key in ["cooldown", "stagger_shield", "shield_broken", "phase_time", "hit_interrupt_guard", "poise_break_left"]:
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
	if boss_id == "dujun" and not phase2 and hp <= max_hp * .5:
		phase2 = true; phase_time = 1.10; action = {}; sequence = []; attack_count = 3; cooldown = .1
		world.fx.add("phase", position, 1.10, {"radius":112.0})
		world.fx.floater(position,"铁面督军 · 断锁追斩",Color("f4c994"))
		world.toast("铜环崩落！短冲后还有一记扫斧，等整套收完再反击。")
		world.sound.play_cue("phase"); update_visual(); return
	if boss_id == "vanguard" and not phase2 and hp <= max_hp * .5:
		phase2 = true; phase_time = 1.20; action = {}; sequence = []; attack_count = 3; cooldown = .1
		world.fx.add("phase", position, 1.20, {"radius":110.0})
		world.fx.floater(position,"玄甲先锋 · 破阵回戟",Color("e8c6a0"))
		world.toast("长戟压低！侧闪避开冲锋，迟势回扫收完再反击。")
		world.sound.play_cue("phase"); update_visual(); return
	if boss_id == "warden" and not phase2 and hp <= max_hp * .5:
		phase2 = true; phase_time = 1.20; action = {}; sequence = []; attack_count = 3; cooldown = .1
		world.fx.add("phase",position,1.20,{"radius":110.0})
		world.fx.floater(position,"镇关都尉 · 压门回锤",Color("e7c395"))
		world.toast("重锤压低！短步后还有迟势回锤，整套落下再进。")
		world.sound.play_cue("phase"); update_visual(); return
	var target = world.hero if kind == "boss" else world.nearest_friend(position, 560 if alerted else 410 if is_ranged() else 275,not is_ranged())
	if world.rescue and group_id.begins_with("rescue"):
		var healer = world.rescue.healer
		if not target or position.distance_to(healer.position) < position.distance_to(target.position) * .8: target = healer
	if not action.is_empty():
		advance_action(dt, target); update_visual(); return
	if not target:
		alerted = false; update_visual(); return
	alerted = true; facing = (target.position - position).angle()
	var distance = position.distance_to(target.position)
	var reach = 225 if kind == "boss" else 445 if is_ranged() else 138 if kind == "spear" else 135 if kind == "ironshield" else 88 if kind == "scout" else 78
	if distance < reach and cooldown <= 0 and ChangbanCombat.attack_lane(self,target) and (ranged_slot_available() if is_ranged() else kind == "boss" or world.attackers_count() < 2) and (kind == "boss" or not sequence.is_empty() or not world.has_method("claim_enemy_attack_turn") or world.claim_enemy_attack_turn()):
		start_action(target)
	elif ChangbanCombat.advance_spacing(self,target,dt):
		pass
	elif is_ranged() and distance < 150:
		move_ground(-Vector2.from_angle(facing) * speed * dt)
	elif distance > reach * .68:
		navigate(target.position, speed, dt)
	for other in world.enemies:
		if other == self or not other.body_alive(): continue
		var offset = position - other.position; var separation = offset.length()
		if separation > .1 and separation < radius + other.radius: move_ground(offset.normalized() * dt * 28)
	update_visual()

func advance_action(dt: float, target) -> void:
	# Called both by the game and boundary tests. A killed or interrupted unit
	# must never release a pending second bolt from an old action dictionary.
	if hp <= 0 or action.is_empty() or stun > 0 or phase_time > 0: return
	var a = action; var d = a.def; var previous = a.t
	a.t += dt
	if target and a.t < d.windup * d.get("lock_fraction",.45):
		a.dir = (target.position - position).angle(); facing = a.dir
	if not a.get("ready", false) and a.t >= d.windup - .12:
		a.ready = true; world.sound.play_cue("ready")
	var active_dt = maxf(0, minf(a.t, d.windup + d.active) - maxf(previous, d.windup))
	if is_ranged():
		# Release by crossing event times, not by the rendered frame. Even a
		# .20 second frame catches each bolt exactly once. Both share the aim
		# locked before the first release; their hit/precision IDs are distinct.
		var releases = [float(d.windup),float(d.windup)+.25] if kind == "crossbow" else [float(d.windup)]
		for shot in range(releases.size()):
			if int(a.get("shots_fired",0)) > shot or a.t < releases[shot]: continue
			if previous > releases[shot]: continue
			var projectile = world.new_action("enemy",d,a.dir)
			projectile.spawn_delay = clampf(releases[shot]-previous,0,dt)
			world.fire_arrow(self,projectile)
			a.shots_fired = shot+1; a.fired = true
			world.sound.play_cue("enemy")
	if active_dt > 0:
		if not a.fired and not is_ranged():
			a.fired = true
			world.fx.add("enemy_slash", position, d.active + .16, {"dir":a.dir, "radius":d.range, "arc":d.arc, "kind":kind, "lunge":d.get("lunge",0),"style":d.get("style",""),"hit_shape":d.get("hit_shape","sector"),"hit_offset":d.get("hit_offset",0.0),"hit_radius":d.get("hit_radius",0.0)})
			world.sound.play_cue("enemy_heavy" if d.get("lunge",0) > 0 or d.arc > 2 else "enemy")
		if not is_ranged():
			var travel = d.get("lunge", 0) * active_dt / d.active
			var steps = maxi(1, int(ceil(travel / 8)))
			for segment in range(steps + 1):
				if segment > 0 and travel > 0:
					a.travel += move_ground(Vector2.from_angle(a.dir) * travel / steps)
				for friend in world.combat_friends():
					if not friend.body_alive() or a.hits.has(friend.uid): continue
					if world.attack_hits(position, friend.position, d, a.dir, friend.radius) and melee_path_clear(friend):
						a.hits.append(friend.uid)
						var connected = friend.take_damage(d.damage, a.id)
						# Hero.take_damage is authoritative for dash i-frames and
						# precise dodge. Pull only follows a confirmed damaging hit.
						if connected and d.get("pull",0) > 0 and friend.body_alive():
							var pull_distance = minf(float(d.pull),maxf(0,friend.position.distance_to(position)-radius-friend.radius-8))
							friend.knockback += (position-friend.position).normalized()*pull_distance*12
	if a.t >= d.windup + d.active + d.recovery:
		action = {}; cooldown = .01 if not sequence.is_empty() else world.enemy_chain_rest(self) if world.has_method("enemy_chain_rest") else .15 if kind == "boss" else .25
		if not sequence.is_empty() and (kind == "scout" or boss_id in ["dujun","vanguard","warden"]) and target and target.body_alive():
			# Preserve short chains at 30/60/120 Hz without losing the time
			# after a crossed boundary, or exposing a false counter window.
			var overflow = a.t - d.windup - d.active - d.recovery
			start_action(target)
			if overflow > 0: advance_action(overflow,target)

func take_hit(damage: float, direction: float, knock: float, source: String, poise: float, break_shield: bool = false) -> void:
	if hp <= 0 or phase_time > 0 or (world.active_boss != "" and world.boss != self): return
	var armored = kind in ["shield", "elite","ironshield"] and shield_broken <= 0
	var blocked = armored and absf(angle_difference(facing, direction + PI)) < 1.15 and not break_shield
	var player_feedback=source=="player" and is_instance_valid(world.hero) and world.hero.has_method("contact_feedback")
	var broke_shield=armored and break_shield
	var broke_poise=false
	if blocked:
		damage *= .24; poise *= .45; world.fx.floater(position, "盾挡", Color("b9cdd4"))
	if armored and break_shield:
		shield_broken = 2.8; stun = .8; action = {}; sequence = []; cooldown = .8
		world.fx.add("break", position, .5, {"radius":50.0}); world.fx.floater(position,"破盾",Color("f6d89d"))
	var floor_hp = max_hp * .22 if source == "ally" else 0.0
	var actual = minf(maxf(0, hp - floor_hp), damage)
	if actual <= 0: return
	hp = maxf(floor_hp, hp - actual); hurt_flash = .16; alerted = true
	if source != "ally" and not player_feedback: world.fx.add("impact", position + Vector2(0,-24), .25, {"dir": direction, "gold": break_shield})
	if source == "player": world.hero.rage = minf(100, world.hero.rage + 4)
	if kind != "boss" and not blocked:
		knockback += Vector2.from_angle(direction) * knock
		if source == "player" and kind != "elite":
			if break_shield or hit_interrupt_guard <= 0:
				stun = maxf(stun, .12); action = {}; sequence = []
				hit_interrupt_guard = .65; interrupt_guard_noticed = false
			elif not interrupt_guard_noticed:
				# Keep the same visible windup and active times. Light hits still
				# damage, but cannot repeatedly erase this soldier's retaliation.
				interrupt_guard_noticed = true
				world.fx.floater(position, "稳住阵脚", Color("e9b78f"))
	if stagger_shield <= 0:
		stagger += poise
		if stagger >= stagger_max:
			broke_poise=true
			stagger = 0; stun = 2.1 if kind == "boss" else 1.3; stagger_shield = 4.4; action = {}; sequence = []; cooldown = 1.2
			poise_break_left = stun
			world.fx.add("break",position,.5,{"radius":65.0}); world.fx.floater(position,"破势 · 反击",Color("f6d89d"))
			if not player_feedback: world.sound.play_cue("break")
	if visual: visual.react_to_hit(direction, blocked, hp <= 0)
	world.fx.floater(position,str(int(round(actual))),Color("a7c6b0") if source == "ally" else Color("fff0bb"))
	if player_feedback: world.hero.contact_feedback(self,direction,actual,blocked,broke_shield,broke_poise,hp<=0)
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
	elif not player_feedback: world.sound.play_cue("hit")
