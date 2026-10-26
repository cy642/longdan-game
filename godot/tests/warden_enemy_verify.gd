extends SceneTree
## Real Enemy/Hero mechanics and world hit geometry. No substitute boss art:
## this combat-only body omits rendering until the new atlas is delivered.
const Game = preload("res://scripts/world.gd")
const Campaign = preload("res://scripts/campaign.gd")
const Enemy = preload("res://scripts/enemy.gd")
const Effects = preload("res://scripts/effects.gd")
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
	if not ok: failures.append(message); push_error("WARDEN: "+message)
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
	enemy.group_id = "warden-qa"; enemy.configure("boss","warden")
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
		for chain in Enemy.BOSS_MOVES.warden:
			for definition in chain:
				reset(); var enemy = spawn(Vector2(850,800)); var hero = world.hero
				hero.position = enemy.position+Vector2.from_angle(direction)*72
				action(enemy,definition,direction); var initial = enemy.position
				enemy.advance_action(definition.windup-.001,hero)
				expect(hero.hp == hero.max_hp and enemy.position == initial,definition.name+" waits through the entire anticipation")
				enemy.advance_action(.002,hero)
				expect(hero.hp == hero.max_hp-definition.damage,definition.name+" hits on its active boundary in direction "+str(direction))
				expect(world.fx.entries.size() == 1 and world.fx.entries[0].info.style == definition.style,definition.name+" releases one corresponding impact effect")
				hero.invincible = 0; enemy.advance_action(definition.active+.002,hero)
				expect(hero.hp == hero.max_hp-definition.damage,definition.name+" hits at most once per action")
				hero.invincible = 0; enemy.advance_action(definition.recovery,hero)
				expect(hero.hp == hero.max_hp-definition.damage and enemy.action.is_empty(),definition.name+" recovery adds no hidden damage")
				reset(); enemy = spawn(Vector2(850,800))
				hero.position = enemy.position+Vector2.from_angle(direction+PI)*72
				action(enemy,definition,direction); enemy.action.t = definition.windup*.6
				enemy.advance_action(definition.windup*.4+definition.active,hero)
				expect(hero.hp == hero.max_hp,definition.name+" leaves the rear of its locked attack safe")
				reset(); enemy = spawn(Vector2(850,800))
				hero.position = enemy.position+Vector2.from_angle(direction)*72
				action(enemy,definition,direction)
				enemy.advance_action(definition.windup*definition.lock_fraction+.01,hero)
				var locked = enemy.action.dir
				hero.position = enemy.position+Vector2.from_angle(direction+PI)*150
				enemy.advance_action(definition.windup+definition.active*.9-enemy.action.t,hero)
				expect(is_equal_approx(enemy.action.dir,locked) and hero.hp == hero.max_hp,definition.name+" cannot turn after its warning locks")

func circle_contracts() -> void:
	var definition = Enemy.BOSS_MOVES.warden[2][0]
	for direction in [0.0,PI*.5,PI,-PI*.5]:
		var origin = Vector2(850,800); var ray = Vector2.from_angle(direction); var side = ray.orthogonal()
		var mark = Effects.circle_telegraph(origin,direction,definition)
		expect(mark.center.distance_to(origin+ray*115) < .001 and mark.radius == 76,"warning uses the authored forward impact center and radius")
		# This position is inside the circle once target radius is included,
		# but outside the old .75-radian sector. Close to the boss is the converse.
		for sample in [[origin+ray*70+side*80,true],[origin+ray*10,false],[mark.center+side*(76+16-.01),true],[mark.center+side*(76+16+.01),false]]:
			reset(); var enemy = spawn(origin); world.hero.position = sample[0]
			expect(Game.attack_hits(origin,sample[0],definition,direction,16) == sample[1],"circle boundary differs correctly from sector geometry")
			action(enemy,definition,direction); enemy.action.t = definition.windup*.6
			enemy.advance_action(definition.windup*.4+.001,world.hero)
			expect((world.hero.hp < world.hero.max_hp) == sample[1],"real circle damage matches its displayed footprint")
			var emitted: Dictionary = world.fx.entries[0].info
			var impact = Effects.circle_telegraph(origin,direction,emitted)
			expect(emitted.hit_shape == "circle" and impact.center == mark.center and impact.radius == mark.radius,"impact effect retains the same circle metadata as anticipation and damage")
		reset(); var enemy = spawn(origin); world.hero.position = origin+ray*160
		var wall = wall_at(origin+ray*85,Vector2(12,260) if absf(ray.x) > .5 else Vector2(260,12))
		await settle(); action(enemy,definition,direction); enemy.advance_action(1.30,world.hero)
		expect(world.hero.hp == world.hero.max_hp,"circle shock cannot damage through a real wall")
		wall.queue_free(); await settle()
	for step in [1.0/30,1.0/60,1.0/120,.20]:
		reset(); var enemy = spawn(Vector2(850,900)); world.hero.position = enemy.position+Vector2(115,0)
		expect(world.terrain.line_clear(enemy.position,world.hero.position,16),"circle timing fixture is outside physical terrain")
		action(enemy,definition,0); var elapsed = 0.0; var early = false
		while elapsed < 3.0:
			world.hero.invincible = 0; enemy.advance_action(step,world.hero); elapsed += step
			if elapsed < definition.windup-.000001 and world.hero.hp < world.hero.max_hp: early = true
		expect(not early and world.hero.hp == world.hero.max_hp-32,"circle has no early or duplicated impact at "+str(step))
		expect(enemy.action.is_empty(),"circle completes its full recovery at "+str(step))
		expect(world.fx.entries.size() == 1 and world.fx.entries[0].info.hit_shape == "circle","circle emits one matching impact at "+str(step))

func charge_and_combo() -> void:
	var step_move = Enemy.BOSS_MOVES.warden[3][0]
	for direction in [0.0,PI*.5,PI,-PI*.5]:
		for step in [1.0/30,1.0/60,1.0/120,.20]:
			reset(); var enemy = spawn(Vector2(850,800)); var origin = enemy.position; var ray = Vector2.from_angle(direction)
			world.hero.position = origin+ray*160
			var wall = wall_at(origin+ray*60,Vector2(12,260) if absf(ray.x) > .5 else Vector2(260,12))
			await settle(); action(enemy,step_move,direction)
			var elapsed = 0.0
			while elapsed < 1.5:
				enemy.advance_action(step,world.hero); elapsed += step
			expect((enemy.position-origin).dot(ray) < 35,"short step stops at brick collision at "+str(step))
			expect(world.hero.hp == world.hero.max_hp,"blocked hammer cannot reach through brick at "+str(step))
			wall.queue_free(); await settle()
	for step in [1.0/30,1.0/60,1.0/120,.20]:
		reset(); var enemy = spawn(); var hero = world.hero
		enemy.phase2 = true; enemy.attack_count = 3; enemy.start_action(hero)
		var elapsed = 0.0; var first_id = enemy.action.id; var return_id = -1; var saw_recovery = false; var false_opening = false
		while elapsed < 3.9:
			if not enemy.action.is_empty():
				if enemy.action.def.style == "warden_return": return_id = enemy.action.id
				if enemy.combat_status() == "recovery":
					saw_recovery = true
					if return_id < 0 or not enemy.sequence.is_empty(): false_opening = true
			hero.invincible = 0; enemy.advance_action(step,hero); elapsed += step
		expect(is_equal_approx(enemy.position.x,920),"short step retains exactly eighty pixels at "+str(step))
		expect(return_id > 0 and return_id != first_id and hero.hp == hero.max_hp-52,"two distinct actual hits survive dropped frames at "+str(step))
		expect(saw_recovery and not false_opening,"counter cue appears only after both hammer segments at "+str(step))
		expect(enemy.action.is_empty() and enemy.sequence.is_empty(),"full chain finishes without a hidden third strike")

func phase_and_interruptions() -> void:
	reset(); var enemy = spawn(); var hero = world.hero
	for index in range(6):
		enemy.attack_count = index; enemy.action = {}; enemy.sequence.clear(); enemy.start_action(hero)
		expect(enemy.action.def.style == ["warden_drop","warden_sweep","warden_quake"][index%3],"upper half cycles the three advertised moves")
	enemy.phase2 = true; enemy.attack_count = 3; enemy.action = {}; enemy.sequence.clear(); enemy.start_action(hero)
	enemy.take_hit(1,0,0,"player",145)
	expect(enemy.stun > 2 and enemy.action.is_empty() and enemy.sequence.is_empty(),"real poise break cancels the whole pressure combo")
	var hp = hero.hp; enemy.advance_action(3,hero)
	expect(hero.hp == hp and enemy.combat_status() == "break","broken hammer cannot release its queued return")
	reset(); enemy = spawn(); enemy.phase2 = true; enemy.attack_count = 3; enemy.start_action(hero)
	enemy.hp = 0; enemy.advance_action(2,hero); enemy.advance(.01)
	expect(enemy.action.is_empty() and enemy.sequence.is_empty() and hero.hp == hero.max_hp,"death discards pending hammer hits")
	reset(); enemy = spawn(); action(enemy,Enemy.BOSS_MOVES.warden[2][0],PI)
	world.mode = "pause"; var paused = enemy.action.t; await settle()
	expect(enemy.action.t == paused and hero.hp == hero.max_hp,"pause freezes circle anticipation")
	world.mode = "playing"; hero.perform("dash",Vector2.UP,0); var precise = world.state.precision_count
	enemy.advance_action(1.26,hero)
	expect(hero.hp == hero.max_hp and world.state.precision_count == precise+1,"real circle respects dodge invulnerability and precision reward")
	hero.invincible = 0; enemy.advance_action(.12,hero)
	expect(hero.hp == hero.max_hp and world.state.precision_count == precise+1,"one avoided impact cannot hit or award precision twice")
	reset(); enemy = spawn(); enemy.start_action(hero); enemy.hp = enemy.max_hp*.49
	var speed = enemy.speed; var count = world.enemies.size(); enemy.advance(.01)
	expect(enemy.phase2 and enemy.phase_time == 1.2 and enemy.action.is_empty() and hero.hp == hero.max_hp,"half health creates a harmless explicit transition")
	var health = enemy.hp; enemy.take_hit(100,0,0,"player",200)
	expect(enemy.hp == health and enemy.stagger == 0,"transition cannot be damaged or skipped by poise")
	var phases = world.fx.entries.filter(func(e): return e.type=="phase").size(); enemy.advance(1.21)
	expect(not enemy.action.is_empty() and enemy.action.def.style == "warden_step" and enemy.sequence.size() == 1,"phase two begins with the advertised step then return")
	expect(enemy.speed == speed and world.enemies.size() == count,"phase two adds no speed multiplier or reinforcements")
	enemy.action = {}; enemy.sequence.clear(); enemy.cooldown = 10
	for tick in range(10): enemy.advance(.1)
	expect(enemy.phase_time == 0 and world.fx.entries.filter(func(e): return e.type=="phase").size() == phases,"half-health transition is unique per fight")
	reset(); enemy = spawn(); enemy.take_hit(99999,0,0,"ally",0)
	expect(is_equal_approx(enemy.hp,1500*.22),"allies cannot finish the new boss")

func run() -> void:
	world = Game.new(); world.test_mode = true; world.state = MemoryCampaign.new(); root.add_child(world)
	world.set_physics_process(false); world.set_process(false); await settle(); world.state.difficulty = "normal"; reset()
	var enemy = spawn()
	expect(world.terrain.line_clear(enemy.position,world.hero.position,22),"combat fixture has a genuinely clear movement and hammer lane")
	expect(enemy.max_hp == 1500 and enemy.stagger_max == 145 and enemy.display_name == "镇关都尉","new boss has its explicit narrow difficulty increase")
	expect(enemy.visual_profile.id == "boss_warden" and enemy.visual_profile.atlas == "enemy_warden","combat actor requests its own new portrait without old-art substitution")
	world.state.difficulty = "story"; var story = spawn()
	expect(is_equal_approx(story.max_hp,1500*.84),"story difficulty keeps the existing reduction")
	world.state.difficulty = "normal"
	attack_boundaries(); await circle_contracts(); await charge_and_combo(); await phase_and_interruptions()
	print("WARDEN_ENEMY_VERIFY ",checks," checks; ",failures.size()," failures")
	world.queue_free(); await process_frame; await process_frame
	quit(0 if failures.is_empty() else 1)
