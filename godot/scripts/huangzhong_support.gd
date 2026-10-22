extends Node2D
## Player-commanded assistance for the grain-road encounter. A single visible
## arrow uses swept collision; it never acquires targets or fires on its own.
const COOLDOWN = 6.0
const DRAW_TIME = .28
const SHOT_RANGE = 560.0
const COMMAND_RANGE = 520.0
const HERO_TARGET_RANGE = 360.0
const ARROW_SPEED = 760.0
var world
var marker
var cooldown = 0.0
var draw_left = 0.0
var recoil_left = 0.0
var aimed_target
var aim = Vector2.LEFT
var arrow_position = Vector2.ZERO
var arrow_left = 0.0
var shots_fired = 0
var hits_landed = 0

func setup(game, actor_marker) -> void:
	world = game; marker = actor_marker; z_index = 5

func active() -> bool:
	return is_instance_valid(marker) and world.stage == "hs_grain" and world.state.chapter == 2 and not world.state.flags.get("huangzhong",false) and world.active_boss.is_empty()

func target_allowed(enemy) -> bool:
	return is_instance_valid(enemy) and enemy.body_alive() and enemy.kind not in ["boss","elite"] and enemy.group_id in world.definition.get("main_groups",[]) and enemy.hp > enemy.max_hp*.22

func line_clear(from: Vector2, to: Vector2) -> bool:
	var query = PhysicsRayQueryParameters2D.create(from,to,1)
	return world.get_world_2d().direct_space_state.intersect_ray(query).is_empty()

func choose_target():
	var selected = null; var best = INF
	for enemy in world.enemies:
		if not target_allowed(enemy): continue
		if marker.position.distance_to(enemy.position) > SHOT_RANGE or world.hero.position.distance_to(enemy.position) > HERO_TARGET_RANGE: continue
		if not line_clear(marker.position,enemy.position): continue
		# Prefer a nearby windup so the player can use the brief opening to
		# advance. This remains a single arrow, not an area stun or volley.
		var score = world.hero.position.distance_to(enemy.position)
		if not enemy.action.is_empty(): score -= 160
		if enemy.is_ranged(): score -= 60
		if score < best: selected = enemy; best = score
	return selected

func status() -> Dictionary:
	if not active(): return {"visible":false,"ready":false,"cooldown":0.0,"text":""}
	var cleared = not world.definition.get("main_groups",[]).is_empty()
	for id in world.definition.get("main_groups",[]):
		if not world.state.cleared.has(world.stage+":"+str(id)): cleared = false
	if cleared: return {"visible":true,"ready":false,"cooldown":0.0,"text":"围军已退 · 靠近黄忠按 E 接应"}
	var text = "3 冲阵 · 黄忠援射就绪"
	var ready = false
	if draw_left > 0: text = "黄忠拉弓 · 准备切入"
	elif arrow_left > 0: text = "黄忠援箭已出 · 抓住破绽"
	elif cooldown > 0: text = "黄忠援射 · %.1f 秒后就绪"%cooldown
	elif world.hero.position.distance_to(marker.position) > COMMAND_RANGE:
		text = "靠近黄忠，再按 3 请求援射"
	elif choose_target() != null:
		ready = true
	else:
		var blocked = false; var weakened = false
		for enemy in world.enemies:
			if not is_instance_valid(enemy) or not enemy.body_alive() or enemy.group_id not in world.definition.get("main_groups",[]): continue
			if marker.position.distance_to(enemy.position) > SHOT_RANGE or world.hero.position.distance_to(enemy.position) > HERO_TARGET_RANGE: continue
			if enemy.hp <= enemy.max_hp*.22: weakened = true
			elif not line_clear(marker.position,enemy.position): blocked = true
		text = "援射受地形遮挡 · 将围军引到开阔处" if blocked else "围军已虚弱 · 由赵云收阵" if weakened else "靠近北山围军，按 3 让黄忠援射"
	return {"visible":true,"ready":ready,"cooldown":cooldown,"text":text}

func request() -> bool:
	if world.mode != "playing" or not active(): return false
	var current = status()
	if not current.ready:
		world.toast(current.text); return false
	aimed_target = choose_target()
	if not is_instance_valid(aimed_target): return false
	aim = (aimed_target.position-marker.position).normalized()
	draw_left = DRAW_TIME; cooldown = COOLDOWN
	marker.set_support_pose(aim,0,0)
	world.toast("黄忠：子龙，老夫为你开路！")
	world.fx.floater(marker.position,"援射",Color("e6d59b"))
	queue_redraw(); return true

func cancel() -> void:
	draw_left = 0; recoil_left = 0; arrow_left = 0; aimed_target = null
	if is_instance_valid(marker): marker.set_support_pose(aim,0,0)
	queue_redraw()

func advance(dt: float) -> void:
	if world.mode != "playing": return
	if not active():
		if draw_left > 0 or recoil_left > 0 or arrow_left > 0: cancel()
		return
	cooldown = maxf(0,cooldown-dt); recoil_left = maxf(0,recoil_left-dt)
	var travel_dt = dt
	if draw_left > 0:
		if not target_allowed(aimed_target): cancel(); return
		var previous = draw_left
		draw_left = maxf(0,draw_left-dt)
		marker.set_support_pose(aim,1-draw_left/DRAW_TIME,0)
		if draw_left > 0: return
		# Aim was locked when requested. Dodging soldiers can evade the shot;
		# its segment collision below also respects newly closed obstacles.
		arrow_position = marker.position; arrow_left = SHOT_RANGE
		shots_fired += 1; recoil_left = .18
		world.sound.play_cue("swing")
		travel_dt = maxf(0,dt-previous)
	if arrow_left > 0 and travel_dt > 0: advance_arrow(travel_dt)
	marker.set_support_pose(aim,0,recoil_left/.18)
	if recoil_left > 0 or arrow_left > 0: queue_redraw()

func advance_arrow(dt: float) -> void:
	var previous = arrow_position
	var distance = minf(ARROW_SPEED*dt,arrow_left)
	var end = previous+aim*distance
	var ray = PhysicsRayQueryParameters2D.create(previous,end,1)
	var obstacle = world.get_world_2d().direct_space_state.intersect_ray(ray)
	if not obstacle.is_empty(): end = obstacle.position
	var target = null; var nearest = INF
	for enemy in world.enemies:
		if not target_allowed(enemy): continue
		var fraction = Geometry2D.segment_intersects_circle(previous,end,enemy.position,enemy.radius+3)
		if fraction >= 0 and fraction <= 1 and fraction < nearest:
			target = enemy; nearest = fraction
	if target != null:
		arrow_position = previous.lerp(end,nearest); arrow_left = 0
		var before = target.hp
		var blocked = target.kind in ["shield","ironshield"] and target.shield_broken <= 0 and absf(angle_difference(target.facing,aim.angle()+PI)) < 1.15
		target.take_hit(10,aim.angle(),0,"ally",24,false)
		if target.hp < before:
			hits_landed += 1
			world.fx.add("impact",target.position+Vector2(0,-24),.22,{"dir":aim.angle(),"gold":true})
			if not blocked:
				# A six-second command earns one short opening. Preserve a longer
				# genuine poise break, and never stun a frontal heavy shield.
				target.action = {}; target.sequence = []
				target.stun = maxf(target.stun,.32); target.cooldown = maxf(target.cooldown,.32)
	else:
		arrow_position = end
		arrow_left = 0 if not obstacle.is_empty() else maxf(0,arrow_left-distance)
	queue_redraw()

func _draw() -> void:
	if arrow_left <= 0: return
	var p = arrow_position+Vector2(0,-25)
	draw_line(p-aim*25,p,Color("e5c17d"),2.2,true)
	draw_colored_polygon(PackedVector2Array([p+aim*5,p-aim*4+aim.orthogonal()*3,p-aim*4-aim.orthogonal()*3]),Color("f5e7ba"))
	for side in [-1,1]: draw_line(p-aim*19,p-aim*25+aim.orthogonal()*4*side,Color("dbc78e"),2,true)
