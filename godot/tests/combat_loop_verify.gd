extends SceneTree
## Exercise production combat and native hitboxes without player save access.
const Game = preload("res://scripts/world.gd")
const Campaign = preload("res://scripts/campaign.gd")
class MemoryCampaign extends Campaign:
	func read_save() -> Dictionary: return {}
	func save() -> bool: return true
class CombatEnemy extends "res://scripts/enemy.gd":
	func _ready() -> void:
		uid = get_instance_id(); collision_layer = 4; collision_mask = 1
		var shape = CollisionShape2D.new(); var circle = CircleShape2D.new()
		circle.radius = radius; shape.shape = circle; add_child(shape)
		home = position

var world
var hero
var checks = 0
var failures: Array = []

func _initialize() -> void: call_deferred("run")
func expect(condition: bool, message: String) -> void:
	checks += 1
	if not condition: failures.append(message); push_error("FAIL: " + message)
func settle() -> void:
	await process_frame; await physics_frame; await physics_frame
func isolate(art: String = "") -> void:
	world.active_boss = ""; world.boss = null; world.arrows.clear()
	for enemy in world.enemies:
		enemy.hp = 0; enemy.collision_layer = 0; enemy.action = {}; enemy.sequence = []
	world.mode = "playing"; world.ui.hide_overlay(); world.clear_input()
	world.state.set("battle_art", art)
	world.state.chapter = 1
	hero.reset_combat(); hero.invincible = 0; hero.position = Vector2(850,900)
func spawn(kind: String = "sword", at: Vector2 = Vector2(945,900), boss_id: String = ""):
	var enemy = CombatEnemy.new(); enemy.world = world; enemy.position = at
	enemy.group_id = "combat-loop-qa"; enemy.configure(kind,boss_id)
	world.actors.add_child(enemy); world.enemies.append(enemy); enemy.cooldown = 0
	return enemy
func key_press(key: Key) -> void:
	var event = InputEventKey.new(); event.keycode = key; event.pressed = true
	world._unhandled_input(event)
func key_release(key: Key) -> void:
	var event = InputEventKey.new(); event.keycode = key; event.pressed = false
	world._input(event)
func third_thrust() -> void:
	hero.combo = 2; hero.combo_left = 1; hero.action = {}; hero.facing = 0
	world.mouse_aim = false; hero.combo_target = null
	key_press(KEY_J); key_release(KEY_J)
	expect(hero.action.get("key","") == "thrust3","keyboard input selects the actual third thrust")
func finish_action(step: float) -> void:
	for tick in range(100):
		if hero.action.is_empty(): return
		hero.advance_action(step)

func run() -> void:
	world = Game.new(); world.test_mode = true; world.state = MemoryCampaign.new()
	root.add_child(world); world.set_physics_process(false); world.set_process(false)
	await settle(); hero = world.hero; world.state.difficulty = "normal"
	# Real hitboxes across 30/60/120 Hz and a dropped frame, including
	# overlapping targets and a killing hit, award once per action.
	for step in [1.0/30,1.0/60,1.0/120,.40]:
		isolate()
		var first = spawn(); var second = spawn("sword",Vector2(951,915))
		first.hp = 30
		await settle(); third_thrust(); finish_action(step)
		expect(first.hp == 0 and second.hp == second.max_hp-40,"third thrust damages both native hitboxes at " + str(step))
		expect(hero.spear_spirit == 1,"third thrust awards once across targets/frames at " + str(step))
		finish_action(step)
		expect(hero.spear_spirit == 1,"finished action cannot grant repeat spirit at " + str(step))
	isolate("assault"); var assault_target = spawn(); await settle()
	third_thrust(); finish_action(.4)
	expect(hero.spear_spirit == 2 and assault_target.hp == assault_target.max_hp-40,"assault grants two spirit without changing damage")
	hero.add_spear_spirit(2)
	expect(hero.spear_spirit == 3,"spirit is capped at three")
	isolate(); third_thrust(); finish_action(.4)
	expect(hero.spear_spirit == 0,"whiffed third thrust grants no spirit")
	isolate(); var phase_target = spawn("boss",Vector2(945,900),"dujun")
	phase_target.phase_time = 2
	await settle(); third_thrust(); finish_action(.4)
	expect(hero.spear_spirit == 0 and phase_target.hp == phase_target.max_hp,"invulnerable phase grants no spirit")
	isolate(); var armored = spawn("shield"); armored.facing = PI
	await settle(); third_thrust()
	hero.action.def = hero.action.def.duplicate(true); hero.action.def.damage = 0
	finish_action(.4)
	expect(hero.spear_spirit == 0 and armored.hp == armored.max_hp,"a shield contact with no HP damage grants no spirit")
	isolate(); var behind_wall = spawn()
	var wall = StaticBody2D.new(); wall.collision_layer = 1; wall.position = Vector2(900,900)
	var wall_shape = CollisionShape2D.new(); var wall_rect = RectangleShape2D.new()
	wall_rect.size = Vector2(12,300); wall_shape.shape = wall_rect; wall.add_child(wall_shape); world.add_child(wall)
	await settle(); third_thrust(); finish_action(.4)
	expect(hero.spear_spirit == 0 and behind_wall.hp == behind_wall.max_hp,"terrain occlusion prevents both damage and spirit")
	wall.queue_free(); await settle()

	# A real dodge is required: incidental spawn i-frames do not count.
	for art in ["","assault","counter"]:
		isolate(art); hero.qi = 40
		var count = world.state.precision_count
		key_press(KEY_SPACE); key_release(KEY_SPACE)
		var started_qi = hero.qi
		expect(hero.dash_left > 0,"space input starts production dodge")
		hero.take_damage(15,300+checks); var unique_id = hero.last_precision
		var once = hero.spear_spirit; hero.take_damage(15,unique_id)
		expect(once == (2 if art == "counter" else 1) and hero.spear_spirit == once,"precision grants correct art reward once: "+art)
		expect(world.state.precision_count == count+1 and hero.hp == hero.max_hp,"precision avoids damage and deduplicates attack ID: "+art)
		expect(hero.qi == started_qi+12,"precision retains original qi refund: "+art)
	isolate(); hero.invincible = .5; hero.take_damage(15,991)
	expect(hero.spear_spirit == 0,"spawn invulnerability is not a precise dodge")
	isolate(); hero.request("dash",Vector2.RIGHT,0); hero.dash_age = .15
	hero.take_damage(15,992)
	expect(hero.spear_spirit == 0,"late normal-difficulty dodge gives no precision spirit")
	isolate(); hero.request("dash",Vector2.RIGHT,0); hero.take_damage(0,993)
	expect(hero.spear_spirit == 0 and hero.counter_left == 0,"zero-damage contact cannot farm precision rewards")

	# Q consumes only after resources/cooldowns allow a cast, keeps one
	# shared-table definition intact, and enhances every native target.
	isolate(); hero.spear_spirit = 3; hero.qi = 29
	key_press(KEY_Q); key_release(KEY_Q)
	expect(hero.spear_spirit == 3 and hero.action.is_empty(),"insufficient qi preserves full spirit")
	hero.qi = 100; hero.sweep_cd = .5; hero.request("sweep")
	expect(hero.spear_spirit == 3 and hero.action.is_empty(),"cooldown rejection preserves full spirit")
	hero.sweep_cd = 0
	var original_sweep = world.attacks.sweep.duplicate(true)
	var near = spawn("shield",Vector2(945,900)); near.facing = PI
	var far = spawn("sword",Vector2(1045,900))
	await settle(); key_press(KEY_Q); key_release(KEY_Q)
	expect(hero.action.get("empowered",false) and hero.spear_spirit == 0 and hero.qi == 70,"Q spends full spirit once alongside its original qi cost")
	expect(is_equal_approx(hero.action.def.range,original_sweep.range*1.18) and is_equal_approx(hero.action.def.stagger,original_sweep.stagger*1.6),"empowered Q enhances reach and poise")
	expect(hero.action.def.damage == original_sweep.damage and world.attacks.sweep == original_sweep,"empowerment never mutates shared attacks or increases base damage")
	finish_action(.4)
	expect(near.hp == near.max_hp-42 and far.hp == far.max_hp-42,"empowered sweep connects both near and extended-reach targets")
	expect(near.shield_broken > 0 and hero.spear_spirit == 0,"empowered sweep still breaks shields without repeat spending or gain")
	hero.sweep_cd = 0; hero.request("sweep",Vector2.ZERO,0)
	expect(not hero.action.get("empowered",false) and hero.action.def == original_sweep,"next uncharged sweep returns to authored values")
	isolate(); world.state.chapter = 2; world.state.rewards.huilan = true
	world.state.tactics.huilan_equipped = true; hero.spear_spirit = 3
	var original_huilan = world.attacks.huilan.duplicate(true)
	hero.request("sweep",Vector2.ZERO,0)
	expect(hero.action.key == "huilan" and hero.action.get("empowered",false),"huilan variant can consume spirit")
	expect(is_equal_approx(hero.action.def.stagger,original_huilan.stagger*1.6) and world.attacks.huilan == original_huilan,"huilan empowerment keeps its own authored balance")
	isolate("counter"); var counter_one = spawn(); var counter_two = spawn("sword",Vector2(955,910))
	await settle(); hero.qi = 50; hero.counter_left = 1
	key_press(KEY_J); key_release(KEY_J); finish_action(.2)
	expect(counter_one.hp == counter_one.max_hp-48 and counter_two.hp == counter_two.max_hp-48,"counter hits multiple native targets")
	expect(hero.qi == 62,"counter-art refund occurs once per action, not once per enemy")
	isolate("assault"); spawn(); await settle(); hero.qi = 50; hero.counter_left = 1
	hero.request("attack",Vector2.ZERO,0); finish_action(.2)
	expect(hero.qi == 50,"other arts do not receive counter-art refund")

	isolate(); hero.spear_spirit = 3; hero.take_damage(15,1001)
	expect(hero.spear_spirit == 2 and hero.hp == hero.max_hp-15,"real damage loses exactly one spirit")
	hero.take_damage(15,1002)
	expect(hero.spear_spirit == 2,"invulnerable repeat contact does not lose extra spirit")
	hero.invincible = 0; hero.take_damage(0,1003)
	expect(hero.spear_spirit == 2,"zero damage does not lose spirit or claim a damaging hit")
	hero.reset_combat()
	expect(hero.spear_spirit == 0,"retry reset clears stored spirit")

	# Retaliation protection is finite, does not shift the telegraph/hit
	# window, and is overridden by purposeful heavy attacks or poise break.
	isolate(); var guard = spawn("scout"); guard.max_hp = 1000; guard.hp = 1000
	await settle(); guard.start_action(hero); guard.advance_action(.15,hero)
	guard.take_hit(1,0,0,"player",0)
	expect(guard.action.is_empty() and guard.sequence.is_empty() and is_equal_approx(guard.hit_interrupt_guard,.65),"first light hit interrupts and starts a finite protection window")
	guard.stun = 0; guard.start_action(hero); guard.advance_action(.15,hero)
	var retaliation = guard.action.id; var before_time = guard.action.t; var before_hp = guard.hp
	guard.take_hit(1,0,0,"player",0)
	expect(not guard.action.is_empty() and guard.action.id == retaliation and guard.action.t == before_time,"protected retaliation keeps its original action and timeline")
	expect(guard.hp == before_hp-1 and guard.stun == 0,"protection prevents repeated light interruption but never damage")
	var hp_before_counter = hero.hp
	guard.advance_action(.34,hero)
	expect(hero.hp == hp_before_counter,"retaliation cannot damage before its original windup")
	guard.advance_action(.02,hero)
	expect(hero.hp == hp_before_counter-13,"retaliation hits at its original readable active time")
	guard.take_hit(1,0,0,"player",0,true)
	expect(guard.action.is_empty() and guard.sequence.is_empty(),"heavy breaking strike overrides light-hit protection")
	guard.stun = 0; guard.cooldown = 2; guard.advance(.66); guard.start_action(hero)
	guard.take_hit(1,0,0,"player",0)
	expect(guard.action.is_empty() and guard.hit_interrupt_guard > 0,"normal light interruption returns after protection expires")
	guard.stun = 0; guard.start_action(hero); guard.stagger = guard.stagger_max-1
	guard.take_hit(1,0,0,"player",2)
	expect(guard.action.is_empty() and guard.stun >= 1.3 and guard.stagger_shield > 0,"poise break overrides protection and grants the full counter window")
	isolate(); var boss = spawn("boss",Vector2(945,900),"dujun"); boss.start_action(hero)
	var boss_action = boss.action.id; boss.take_hit(1,0,0,"player",0)
	expect(boss.action.id == boss_action and boss.hit_interrupt_guard == 0,"bosses keep authored poise rules instead of gaining light-hit protection")

	print("COMBAT_LOOP_VERIFY checks=",checks," failures=",failures.size())
	world.queue_free(); await process_frame
	quit(0 if failures.is_empty() else 1)
