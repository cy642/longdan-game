extends SceneTree
## Production enemy nodes; no player save reads/writes, no animation-only damage.
const Game = preload("res://scripts/world.gd")
const Campaign = preload("res://scripts/campaign.gd")
const Enemy = preload("res://scripts/enemy.gd")
class MemoryCampaign extends Campaign:
	func read_save() -> Dictionary: return {}
	func save() -> bool: return true
var world
var checks = 0
var failures: Array = []

func _initialize() -> void: call_deferred("run")
func expect(condition: bool, message: String) -> void:
	checks += 1
	if not condition: failures.append(message); push_error("FAIL: " + message)

func pose_distance(a: Dictionary, b: Dictionary) -> float:
	var distance = 0.0
	for key in a: distance = maxf(distance, absf(a[key] - b[key]))
	return distance

func vertex_distance(a: PackedVector2Array, b: PackedVector2Array) -> float:
	var distance = 0.0
	for i in range(a.size()): distance = maxf(distance, a[i].distance_to(b[i]))
	return distance

func sample(enemy, definition: Dictionary, time: float, id: int = 501) -> Dictionary:
	enemy.action = world.new_action("enemy", definition, enemy.facing)
	enemy.action.id = id; enemy.action.t = time
	return enemy.visual.sample_enemy_action(enemy.action)

func settle() -> void:
	await process_frame; await physics_frame; await physics_frame

func run() -> void:
	world = Game.new(); world.test_mode = true; world.state = MemoryCampaign.new()
	root.add_child(world); world.set_physics_process(false); world.set_process(false)
	await settle()
	world.mode = "playing"; world.ui.hide_overlay(); world.state.difficulty = "normal"
	for unit in [["sword",""], ["spear",""], ["archer",""], ["shield",""], ["elite",""], ["boss","xiahou"], ["boss","zhanghe"]]:
		var enemy = world.spawn_enemy(unit[0], Vector2(850,900), "animation-test", unit[1])
		var v = enemy.visual
		var name = unit[0] + unit[1]
		expect(v.rig != null and not v.body.visible, name + " uses articulated original pixels")
		expect(v.rig.texture.resource_path == v.atlas_data[v.last_frame[0]].file, name + " uses original atlas")
		expect(v.rig.polygon.size() > 100 and v.rig.polygons.size() > 70, name + " has connected deformation grid")
		var rest: PackedVector2Array = v.rig.polygon.duplicate()
		enemy.moving = true; enemy.walk_distance = 18
		v.advance_time(.1); enemy.update_visual()
		expect(vertex_distance(rest,v.rig.polygon) * v.current_scale > 2.0, name + " legs move independently while walking")
		expect(v.position.is_zero_approx() and v.rotation == 0 and v.scale == Vector2.ONE, name + " walk origin stays on ground shadow")
		# At least one lower boot remains planted; no whole-sprite vertical bounce.
		var original_bottom = -INF; var animated_bottom = -INF
		for i in range(v.rig.polygon.size()):
			if v.rig_data.weapon_indices.has(i): continue
			original_bottom = maxf(original_bottom,v.rig_data.rest[i].y)
			animated_bottom = maxf(animated_bottom,v.rig.polygon[i].y)
		expect(absf(animated_bottom-original_bottom) * v.current_scale < .7, name + " support boot stays at ground height")
		enemy.moving = false; v.move_blend = 0
		var definitions: Array = []
		if enemy.kind == "boss":
			for chain in Enemy.BOSS_MOVES[enemy.boss_id]: definitions.append_array(chain)
		else:
			enemy.start_action(world.hero); definitions.append(enemy.action.def)
		for d in definitions:
			var title = name + ": " + d.name
			var total = d.windup + d.active + d.recovery
			for facing in [0.0, PI, PI/2, -PI/2]:
				enemy.facing = facing
				for boundary in [d.windup, d.windup + d.active, total]:
					var before = sample(enemy,d,boundary-.00001)
					var after = sample(enemy,d,boundary+.00001)
					expect(pose_distance(before,after) < .004, title + " continuous phase boundary " + str(boundary))
				expect(pose_distance(sample(enemy,d,0),v.neutral_pose()) == 0, title + " begins at guard")
				expect(pose_distance(sample(enemy,d,total),v.neutral_pose()) < .0001, title + " finishes in guard")
				var windup = sample(enemy,d,d.windup*.9)
				var active = sample(enemy,d,d.windup+d.active*.42)
				expect(pose_distance(windup,active) > .25, title + " anticipation and release visibly differ")
				var previous: PackedVector2Array
				var biggest_step = 0.0
				# Sample real rendered geometry at a fine rate to catch root jumps,
				# source exclusions, invalid vertices and abrupt end-of-action snaps.
				for step in range(81):
					var t = total * step / 80.0
					sample(enemy,d,t); enemy.update_visual()
					var points: PackedVector2Array = v.rig.polygon
					if not previous.is_empty(): biggest_step = maxf(biggest_step,vertex_distance(previous,points)*v.current_scale)
					previous = points.duplicate()
					expect(v.position.is_zero_approx() and v.rotation == 0 and v.scale == Vector2.ONE, title + " attack stays foot anchored")
					expect(points.size() == rest.size(), title + " grid remains intact")
					var finite = true
					for p in points:
						if not p.is_finite(): finite = false
					expect(finite, title + " mesh coordinates remain finite")
					var head_error = 0.0
					var pose = v.displayed_pose
					var upper = v.enemy_upper_transform(pose)
					for i in v.rig_data.head_indices:
						var expected = upper * v.rig_data.rest[i]
						head_error = maxf(head_error,points[i].distance_to(expected))
					expect(head_error < .001, title + " face and helmet remain one rigid shape")
					var weapon_error = 0.0
					for i in v.rig_data.weapon_indices:
						weapon_error = maxf(weapon_error,points[i].distance_to(upper * v.rig_data.rest[i]))
					expect(weapon_error < .001, title + " blade and shaft remain rigid with no kinks")
				expect(biggest_step < 32.0, title + " no phase teleport in rendered vertices")
		# All exclusions must remain geometry holes, rather than stray atlas pixels.
		var meta = v.atlas_data[v.last_frame[0]].frames[v.last_frame[1]]
		var atlas_origin = Vector2(meta.region[0],meta.region[1])
		var clear = true
		for excluded in meta.get("exclude",[]):
			var hole = Rect2(excluded[0],excluded[1],excluded[2],excluded[3])
			for polygon in v.rig.polygons:
				var midpoint = Vector2.ZERO
				for i in polygon: midpoint += v.rig.uv[i] - atlas_origin
				if hole.has_point(midpoint / polygon.size()): clear = false
		expect(clear,name + " source-neighbor exclusions remain clipped")
		enemy.hp = 0; enemy.collision_layer = 0; enemy.action = {}

	var hero = world.hero; hero.position = Vector2(850,900)
	var sword = world.spawn_enemy("sword",Vector2(930,900),"contracts")
	await settle()
	hero.reset_combat(); hero.invincible = 0; hero.position = Vector2(850,900)
	sword.start_action(hero)
	var d = sword.action.def
	sword.advance_action(d.windup-.001,hero)
	expect(hero.hp == hero.max_hp,"enemy windup never deals damage")
	sword.advance_action(.002,hero)
	expect(is_equal_approx(hero.hp,hero.max_hp-d.damage),"damage starts in unchanged active window")
	hero.invincible = 0; sword.advance_action(d.active*.5,hero)
	expect(is_equal_approx(hero.hp,hero.max_hp-d.damage),"one attack never hits the target twice")
	hero.reset_combat(); hero.invincible = 0; sword.start_action(hero)
	sword.advance_action(d.windup+d.active+.01,hero)
	expect(is_equal_approx(hero.hp,hero.max_hp-d.damage),"skipped active window still damages exactly once")
	var archer = world.spawn_enemy("archer",Vector2(930,900),"contracts")
	archer.start_action(hero); world.arrows.clear()
	archer.advance_action(archer.action.def.windup-.001,hero)
	expect(world.arrows.is_empty(),"archer never releases early")
	archer.advance_action(.08,hero)
	expect(world.arrows.size() == 1,"archer releases one arrow across short active window")
	archer.advance_action(.1,hero)
	expect(world.arrows.size() == 1,"archer recovery does not fire a second arrow")

	var shield = world.spawn_enemy("shield",Vector2(930,900),"contracts")
	shield.facing = PI; shield.start_action(hero)
	var counter_id = shield.action.id
	shield.take_hit(25,0,65,"player",10)
	expect(not shield.action.is_empty() and shield.action.id == counter_id and shield.stun == 0,"block recoil preserves counterattack")
	shield.update_visual()
	shield.take_hit(42,0,205,"player",34,true)
	expect(shield.action.is_empty() and shield.stun > 0 and shield.shield_broken > 0,"shield break still cancels and opens guard")

	sword.hp = 72; sword.hurt_flash = 0; sword.stun = 0; sword.knockback = Vector2.ZERO
	sword.start_action(hero); sword.action.t = sword.action.def.windup*.8; sword.update_visual()
	var interrupted = sword.visual.displayed_pose.duplicate()
	sword.take_hit(10,0,50,"player",0)
	sword.update_visual()
	expect(sword.action.is_empty(),"normal player hit still interrupts ordinary enemy")
	expect(pose_distance(interrupted,sword.visual.displayed_pose) < .0001,"hit begins from interrupted pose without snap")
	sword.visual.advance_time(.08); sword.update_visual()
	expect(pose_distance(interrupted,sword.visual.displayed_pose) > .1,"hit produces readable upper-body recoil")
	sword.stun = 0; sword.visual.advance_time(.5); sword.update_visual()
	expect(pose_distance(sword.visual.displayed_pose,sword.visual.neutral_pose()) < .001,"recoil settles back into guard")
	sword.take_hit(1000,0,0,"player",0)
	sword.update_visual()
	expect(sword.visual.modulate.a > .99 and sword.visual.rotation == 0,"lethal hit starts fully visible before falling")
	var alpha = 1.0; var angle = 0.0
	for t in [.05,.1,.2,.3,.46,.7,1.0,2.0,5.0,10.0]:
		sword.dead_time = t; sword.update_visual()
		expect(sword.visual.modulate.a <= alpha + .001,"corpse fade never reverses")
		expect(absf(sword.visual.rotation) >= angle,"death rotation settles monotonically")
		alpha = sword.visual.modulate.a; angle = absf(sword.visual.rotation)
	expect(alpha == 0,"corpse reaches transparent only after full death lifetime")
	print("ENEMY_ANIMATION_VERIFY ",checks," checks; ",failures.size()," failures")
	world.queue_free(); await process_frame; await process_frame
	quit(0 if failures.is_empty() else 1)
