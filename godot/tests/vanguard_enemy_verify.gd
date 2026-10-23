extends SceneTree
## Real Enemy/Hero actions and native terrain collisions, without touching saves.
const Game = preload("res://scripts/world.gd")
const Campaign = preload("res://scripts/campaign.gd")
const Enemy = preload("res://scripts/enemy.gd")
class MemoryCampaign extends Campaign:
	func read_save() -> Dictionary: return {}
	func save() -> bool: return true
class CombatEnemy extends "res://scripts/enemy.gd":
	func _ready() -> void:
		uid = get_instance_id(); collision_layer = 4; collision_mask = 1
		var shape = CollisionShape2D.new(); var circle = CircleShape2D.new()
		circle.radius = radius; shape.shape = circle; add_child(shape); home = position
var world
var checks = 0
var failures: Array = []

func _initialize() -> void: call_deferred("run")
func expect(ok: bool,message: String) -> void:
	checks += 1
	if not ok: failures.append(message); push_error("VANGUARD: "+message)
func settle() -> void:
	await process_frame; await physics_frame; await physics_frame
func reset() -> void:
	world.active_boss = ""; world.boss = null; world.arrows.clear(); world.fx.entries.clear()
	for unit in world.enemies:
		unit.hp = 0; unit.collision_layer = 0; unit.action = {}; unit.sequence = []
	world.hero.reset_combat(); world.hero.invincible = 0; world.hero.position = Vector2(850,900)
	world.mode = "playing"; world.ui.hide_overlay()
func spawn(at: Vector2 = Vector2(1000,900)):
	var enemy = CombatEnemy.new(); enemy.world = world; enemy.position = at
	enemy.group_id = "vanguard-qa"; enemy.configure("boss","vanguard")
	world.actors.add_child(enemy); world.enemies.append(enemy); enemy.cooldown = 0
	return enemy
func action(enemy,definition: Dictionary,direction: float) -> void:
	enemy.facing = direction; enemy.action = world.new_action("enemy",definition,direction)
func wall_at(at: Vector2,size: Vector2) -> StaticBody2D:
	var wall = StaticBody2D.new(); wall.collision_layer = 1; wall.position = at
	var shape = CollisionShape2D.new(); var rectangle = RectangleShape2D.new()
	rectangle.size = size; shape.shape = rectangle; wall.add_child(shape); world.add_child(wall)
	return wall

func attack_boundaries() -> void:
	for direction in [0.0,PI*.5,PI,-PI*.5]:
		for chain in Enemy.BOSS_MOVES.vanguard:
			for definition in chain:
				reset(); var enemy = spawn(Vector2(850,900)); var hero = world.hero
				hero.position = enemy.position+Vector2.from_angle(direction)*72
				action(enemy,definition,direction)
				var initial = enemy.position
				enemy.advance_action(definition.windup-.001,hero)
				expect(hero.hp == hero.max_hp and enemy.position == initial,definition.name+" harmless planted anticipation "+str(direction))
				enemy.advance_action(.002,hero)
				expect(hero.hp == hero.max_hp-definition.damage,definition.name+" active boundary deals real damage "+str(direction))
				expect(world.fx.entries.size() == 1 and world.fx.entries[0].info.style == definition.style,definition.name+" releases its own weapon effect")
				hero.invincible = 0; enemy.advance_action(definition.active+.002,hero)
				expect(hero.hp == hero.max_hp-definition.damage,definition.name+" cannot hit twice with the same action")
				hero.invincible = 0; enemy.advance_action(definition.recovery,hero)
				expect(hero.hp == hero.max_hp-definition.damage and enemy.action.is_empty(),definition.name+" harmless completed recovery")
				reset(); enemy = spawn(Vector2(850,900))
				hero.position = enemy.position+Vector2.from_angle(direction+PI)*72
				action(enemy,definition,direction); enemy.action.t = definition.windup*.6
				enemy.advance_action(definition.windup*.4+definition.active,hero)
				expect(hero.hp == hero.max_hp,definition.name+" leaves the rear of its locked sector safe")
				reset(); enemy = spawn(Vector2(850,900))
				hero.position = enemy.position+Vector2.from_angle(direction)*72
				action(enemy,definition,direction)
				enemy.advance_action(definition.windup*definition.lock_fraction+.01,hero)
				var locked = enemy.action.dir
				hero.position = enemy.position+Vector2.from_angle(direction+PI)*140
				enemy.advance_action(definition.windup+definition.active*.9-enemy.action.t,hero)
				expect(is_equal_approx(enemy.action.dir,locked) and hero.hp == hero.max_hp,definition.name+" never retargets after the visible lock")

func charge_collisions() -> void:
	for direction in [0.0,PI*.5,PI,-PI*.5]:
		for step in [1.0/30,1.0/60,1.0/120,.20]:
			reset(); var enemy = spawn(Vector2(850,800)); var origin = enemy.position
			var ray = Vector2.from_angle(direction)
			world.hero.position = origin+ray*170
			var size = Vector2(12,300) if absf(ray.x) > .5 else Vector2(300,12)
			var wall = wall_at(origin+ray*70,size); await settle()
			var definition = Enemy.BOSS_MOVES.vanguard[1][0]
			action(enemy,definition,direction)
			var elapsed = 0.0
			while elapsed < 2.65:
				enemy.advance_action(step,world.hero); elapsed += step
			expect((enemy.position-origin).dot(ray) < 45,"charge stops at native wall at "+str(step)+" / "+str(direction))
			expect(world.hero.hp == world.hero.max_hp,"halberd cannot damage through rock at "+str(step)+" / "+str(direction))
			wall.queue_free(); await settle()
	# The charge substeps must also catch a target crossed within one dropped frame.
	for step in [1.0/30,1.0/60,1.0/120,.20]:
		reset(); var enemy = spawn(); var definition = Enemy.BOSS_MOVES.vanguard[1][0]
		world.hero.position = Vector2(895,900); action(enemy,definition,PI)
		var elapsed = 0.0
		while elapsed < 2.65:
			world.hero.invincible = 0; enemy.advance_action(step,world.hero); elapsed += step
		expect(is_equal_approx(enemy.position.x,850),"unblocked charge travels the same distance at "+str(step))
		expect(world.hero.hp == world.hero.max_hp-29,"charge crosses target once at "+str(step))

func combo_timing() -> void:
	for step in [1.0/30,1.0/60,1.0/120,.20]:
		reset(); var enemy = spawn(); var hero = world.hero
		enemy.phase2 = true; enemy.attack_count = 3; enemy.start_action(hero)
		var elapsed = 0.0; var first_id = enemy.action.id; var second_id = -1
		var saw_recovery = false; var false_opening = false
		while elapsed < 3.8:
			if not enemy.action.is_empty():
				if enemy.action.def.style == "vanguard_return": second_id = enemy.action.id
				if enemy.combat_status() == "recovery":
					saw_recovery = true
					if second_id < 0 or not enemy.sequence.is_empty(): false_opening = true
			hero.invincible = 0; enemy.advance_action(step,hero); elapsed += step
		expect(second_id > 0 and second_id != first_id,"two real combo hit IDs at "+str(step))
		expect(saw_recovery and not false_opening,"only the final return sweep exposes counter window at "+str(step))
		expect(hero.hp == hero.max_hp-53,"complete charge and return deal two finite hits at "+str(step))
		expect(enemy.action.is_empty() and enemy.sequence.is_empty(),"complete combo ends at "+str(step))

func interruptions_and_phase() -> void:
	reset(); var enemy = spawn(); var hero = world.hero
	for index in range(6):
		enemy.attack_count = index; enemy.sequence.clear(); enemy.start_action(hero)
		expect(enemy.action.def.style == ["vanguard_thrust","vanguard_charge","vanguard_sweep"][index%3],"upper half cycles distinct first phase attacks")
	enemy.phase2 = true; enemy.attack_count = 3; enemy.sequence.clear(); enemy.start_action(hero)
	var first_id = enemy.action.id
	enemy.take_hit(1,0,0,"player",140)
	expect(enemy.action.is_empty() and enemy.sequence.is_empty() and enemy.stun > 2,"real poise break cancels entire charge/return chain")
	expect(enemy.combat_status() == "break","poise break exposes the real recovery clock")
	var health = hero.hp; enemy.advance_action(2.0,hero)
	expect(hero.hp == health and world.fx.entries.filter(func(e): return e.type=="enemy_slash").is_empty(),"cancelled chain cannot release delayed damage or strike effect")
	reset(); enemy = spawn(); enemy.phase2 = true; enemy.attack_count = 3; enemy.start_action(hero)
	enemy.hp = 0; enemy.advance_action(2.0,hero); enemy.advance(.01)
	expect(hero.hp == hero.max_hp and enemy.action.is_empty() and enemy.sequence.is_empty(),"death cancels both pending combo segments")
	reset(); enemy = spawn(); enemy.start_action(hero)
	world.mode = "pause"; var paused = enemy.action.t; await settle()
	expect(enemy.action.t == paused and hero.hp == hero.max_hp,"pause does not advance pending strike")
	world.mode = "playing"; enemy.advance_action(.79,hero)
	expect(hero.hp == hero.max_hp-25,"resuming releases the pending strike once")
	reset(); enemy = spawn(); enemy.start_action(hero)
	hero.perform("dash",Vector2.UP,0); var precision = world.state.precision_count
	enemy.advance_action(.79,hero)
	expect(hero.hp == hero.max_hp and world.state.precision_count == precision+1,"production dodge avoids halberd and awards one precise dodge")
	hero.invincible = 0; enemy.advance_action(.10,hero)
	expect(hero.hp == hero.max_hp and world.state.precision_count == precision+1,"one dodged action cannot hit again or farm precision")
	reset(); enemy = spawn(); enemy.start_action(hero); enemy.hp = enemy.max_hp*.49
	enemy.advance(.01)
	expect(enemy.phase2 and is_equal_approx(enemy.phase_time,1.2) and enemy.action.is_empty(),"half health cancels old move for a harmless transition")
	var phase_health = enemy.hp; enemy.take_hit(100,0,0,"player",200)
	expect(enemy.hp == phase_health and enemy.stagger == 0,"transition cannot be damaged or force-skipped")
	var phase_count = world.fx.entries.filter(func(e): return e.type=="phase").size()
	enemy.advance(1.21)
	expect(not enemy.action.is_empty() and enemy.action.def.style == "vanguard_charge" and not enemy.sequence.is_empty(),"second phase opens with the advertised charge/return")
	enemy.action = {}; enemy.sequence.clear(); enemy.cooldown = 10
	for frame in range(10): enemy.advance(.10)
	expect(enemy.phase_time == 0 and world.fx.entries.filter(func(e): return e.type=="phase").size() == phase_count,"half health transition triggers only once per fight")
	reset(); enemy = spawn(); enemy.take_hit(99999,0,0,"ally",0)
	expect(is_equal_approx(enemy.hp,enemy.max_hp*.22),"allies cannot finish the new boss")
	expect(first_id > 0,"actions use the shared monotonic hit ID source")

func run() -> void:
	world = Game.new(); world.test_mode = true; world.state = MemoryCampaign.new()
	root.add_child(world); world.set_physics_process(false); world.set_process(false)
	await settle(); world.state.difficulty = "normal"; reset()
	var enemy = spawn()
	expect(enemy.max_hp == 1450 and enemy.stagger_max == 140 and enemy.display_name == "玄甲先锋","new boss uses explicit balance and identity")
	world.state.difficulty = "story"; var story = spawn()
	expect(is_equal_approx(story.max_hp,1450*.84),"story mode retains existing health reduction")
	world.state.difficulty = "normal"
	attack_boundaries(); await charge_collisions(); combo_timing(); await interruptions_and_phase()
	print("VANGUARD_ENEMY_VERIFY ",checks," checks; ",failures.size()," failures")
	world.queue_free(); await process_frame; await process_frame
	quit(0 if failures.is_empty() else 1)
