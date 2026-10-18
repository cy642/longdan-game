extends SceneTree
## Real production combat, hero i-frames and terrain collision; visual-only
## readiness is covered separately by enemy_animation_verify.gd.
const Game = preload("res://scripts/world.gd")
const Campaign = preload("res://scripts/campaign.gd")
const Enemy = preload("res://scripts/enemy.gd")
class MemoryCampaign extends Campaign:
	func read_save() -> Dictionary: return {}
	func save() -> bool: return true
class CombatEnemy extends "res://scripts/enemy.gd":
	# Omit the renderer so combat boundary cases do not depend on atlas art.
	# Every tested action, hit, movement and interruption remains production.
	func _ready() -> void:
		uid = get_instance_id(); collision_layer = 4; collision_mask = 1
		var shape = CollisionShape2D.new(); var circle = CircleShape2D.new()
		circle.radius = radius; shape.shape = circle; add_child(shape)
		home = position
var world
var checks = 0
var failures: Array = []

func _initialize() -> void: call_deferred("run")
func expect(condition: bool,message: String) -> void:
	checks += 1
	if not condition: failures.append(message); push_error("FAIL: "+message)
func settle() -> void:
	await process_frame; await physics_frame; await physics_frame
func spawn(kind: String,at: Vector2 = Vector2(930,900),boss: String = ""):
	var enemy = CombatEnemy.new(); enemy.world = world; enemy.position = at
	enemy.group_id = "hanshui-combat-qa"; enemy.configure(kind,boss)
	world.actors.add_child(enemy); world.enemies.append(enemy); enemy.cooldown = 0
	return enemy
func reset_target(at: Vector2 = Vector2(850,900)) -> void:
	world.mode = "playing"; world.hero.reset_combat(); world.hero.invincible = 0; world.hero.position = at
func isolate() -> void:
	world.active_boss = ""; world.boss = null; world.arrows.clear()
	for enemy in world.enemies:
		enemy.hp = 0; enemy.collision_layer = 0; enemy.action = {}; enemy.sequence = []
	reset_target()
func test_burst(step: float) -> void:
	isolate(); var enemy = spawn("crossbow"); var hero = world.hero
	enemy.start_action(hero); var locked = enemy.action.dir; var elapsed = 0.0
	var counts: Array = []; var ids: Array = []
	while elapsed < 2.75:
		var dt = minf(step,2.75-elapsed)
		enemy.advance_action(dt,hero); elapsed += dt
		counts.append(world.arrows.size())
		if elapsed < .9-.000001: expect(world.arrows.is_empty(),"burst has no early bolt at "+str(step))
	expect(world.arrows.size() == 2,"burst emits exactly two bolts at "+str(step))
	for arrow in world.arrows:
		ids.append(arrow.id)
		expect(is_equal_approx(arrow.dir,locked),"both bolts retain locked aim at "+str(step))
	expect(ids[0] != ids[1],"each bolt owns a distinct precision-dodge id at "+str(step))
	expect(enemy.action.is_empty(),"burst finishes after explicit reload at "+str(step))
func wall_between(x: float) -> StaticBody2D:
	var wall = StaticBody2D.new(); wall.collision_layer = 1; wall.position = Vector2(x,900)
	var shape = CollisionShape2D.new(); var rectangle = RectangleShape2D.new()
	rectangle.size = Vector2(12,300); shape.shape = rectangle; wall.add_child(shape)
	world.add_child(wall); return wall

func run() -> void:
	world = Game.new(); world.test_mode = true; world.state = MemoryCampaign.new()
	root.add_child(world); world.set_physics_process(false); world.set_process(false)
	await settle(); world.ui.hide_overlay(); world.state.difficulty = "normal"
	isolate()
	for unit in [["scout",75],["crossbow",65],["ironshield",140],["boss",1450]]:
		var enemy = spawn(unit[0],Vector2(930,900),"dujun" if unit[0] == "boss" else "")
		expect(enemy.max_hp == unit[1],unit[0]+" has explicit chapter-two balance")
		expect(enemy.is_ranged() == (unit[0] == "crossbow"),unit[0]+" ranged classification")
	isolate(); world.state.difficulty = "story"
	var story = spawn("boss",Vector2(930,900),"dujun")
	expect(is_equal_approx(story.max_hp,1450*.84),"dujun preserves story difficulty")
	world.state.difficulty = "normal"
	for step in [1.0/30,1.0/60,1.0/120,.20]: test_burst(step)
	isolate(); var bow = spawn("crossbow"); var hero = world.hero
	bow.start_action(hero); bow.advance_action(.46,hero)
	var aim = bow.action.dir; hero.position += Vector2(0,180)
	bow.advance_action(.74,hero)
	expect(world.arrows.size() == 2 and is_equal_approx(world.arrows[0].dir,aim) and is_equal_approx(world.arrows[1].dir,aim),"second bolt never silently tracks after aim lock")
	isolate(); bow = spawn("crossbow"); bow.start_action(hero); bow.advance_action(.95,hero)
	expect(world.arrows.size() == 1,"first bolt releases before cancellation")
	bow.take_hit(10,0,0,"player",0); bow.advance_action(.40,hero)
	expect(world.arrows.size() == 1 and bow.action.is_empty(),"player interrupt cancels the pending second bolt")
	isolate(); bow = spawn("crossbow"); bow.start_action(hero); bow.advance_action(.95,hero)
	bow.hp = 0; bow.advance_action(.4,hero)
	expect(world.arrows.size() == 1,"a dead burst unit cannot release its pending second bolt")
	isolate(); bow = spawn("crossbow"); bow.start_action(hero); bow.advance_action(.95,hero)
	# Pause is implemented by the world not advancing enemies; wall-clock
	# scene frames must not move this production action or launch a bolt.
	world.mode = "pause"; var paused_time = bow.action.t
	await settle()
	expect(is_equal_approx(bow.action.t,paused_time) and world.arrows.size() == 1,"pause freezes delayed second bolt")
	world.mode = "playing"; bow.advance_action(.25,hero)
	expect(world.arrows.size() == 2,"resuming releases only the pending second bolt")
	isolate(); bow = spawn("crossbow"); var other_bow = spawn("archer",Vector2(1040,900))
	bow.start_action(hero)
	expect(not other_bow.ranged_slot_available(),"double shot reserves the only ranged slot")
	bow.advance_action(1.3,hero)
	expect(not other_bow.ranged_slot_available(),"reload remains a readable ranged slot")
	bow.advance_action(1.4,hero)
	expect(other_bow.ranged_slot_available(),"next ranged unit can fire after reload finishes")
	isolate(); bow = spawn("crossbow"); bow.start_action(hero); bow.advance_action(.95,hero)
	bow.set_meta("withdrawing",true); bow.set_meta("retreat_target",Vector2(1100,900))
	var retreat_hp = bow.hp; bow.advance(.2)
	expect(bow.action.is_empty() and bow.sequence.is_empty() and world.arrows.size() == 1,"retreat cancels pending attacks and second bolt")
	expect(bow.position.x > 930 and bow.hp == retreat_hp,"retreat navigates with the same living soldier and HP")
	isolate(); var entry = spawn("scout"); entry.stun = .6
	entry.advance(.2); entry.advance(.2)
	expect(entry.action.is_empty(),"new arrival cannot attack during entry grace")
	entry.advance(.21)
	expect(not entry.action.is_empty(),"arrival grace expires into normal readable windup")

	# Both scout slashes are separate real hit IDs, with no false opening
	# while the first recovery leads into the second anticipation.
	for step in [1.0/30,1.0/60,1.0/120,.20]:
		isolate(); var scout = spawn("scout"); scout.start_action(hero)
		var elapsed = 0.0; var saw_second = false
		while elapsed < 2.25:
			hero.invincible = 0
			if not scout.action.is_empty() and scout.action.def.name == "双刀 · 返斩": saw_second = true
			scout.advance_action(step,hero); elapsed += step
		expect(saw_second and is_equal_approx(hero.hp,hero.max_hp-28),"scout completes two unique hits at "+str(step))
		expect(scout.action.is_empty() and scout.sequence.is_empty(),"scout exposes final recovery only at "+str(step))
	isolate(); var scout = spawn("scout"); scout.start_action(hero)
	scout.take_hit(10,0,0,"player",0)
	expect(scout.sequence.is_empty() and scout.action.is_empty(),"interrupt also discards queued second knife")

	isolate(); var shield = spawn("ironshield"); shield.facing = PI; shield.start_action(hero)
	var shield_id = shield.action.id; var shield_hp = shield.hp
	shield.take_hit(25,0,0,"player",10)
	expect(is_equal_approx(shield.hp,shield_hp-6) and shield.action.id == shield_id,"iron shield blocks front hit without losing charge")
	shield.take_hit(42,0,0,"player",34,true)
	expect(shield.action.is_empty() and shield.shield_broken > 0 and shield.stun > 0,"sweep breaks iron shield and cancels the charge")
	isolate(); shield = spawn("ironshield"); shield.start_action(hero); shield.advance_action(.94,hero)
	expect(hero.hp == hero.max_hp and is_equal_approx(shield.position.x,930),"iron shield does not move or hit before charge windup")
	shield.advance_action(.22,hero)
	expect(hero.hp == hero.max_hp-22 and shield.position.x < 870,"iron charge moves along its real attack sector")

	# Hook only pulls after Hero.take_damage confirms a real hit. Precise
	# dodge is counted by production hero code and leaves knockback untouched.
	isolate(); var boss = spawn("boss",Vector2(1000,900),"dujun")
	boss.start_action(hero); boss.advance_action(.949,hero)
	expect(hero.hp == hero.max_hp and hero.knockback.is_zero_approx(),"hook does not pull during anticipation")
	boss.advance_action(.003,hero)
	expect(hero.hp == hero.max_hp-23 and hero.knockback.x > 0,"confirmed hook hit pulls toward dujun")
	var hero_x = hero.position.x; hero.tick_common(1.0/60)
	expect(hero.position.x > hero_x,"hook pull uses actual ground movement")
	isolate(); boss = spawn("boss",Vector2(1000,900),"dujun"); boss.start_action(hero)
	hero.perform("dash",Vector2.UP,0); var precision = world.state.precision_count
	boss.advance_action(.96,hero)
	expect(hero.hp == hero.max_hp and hero.knockback.is_zero_approx(),"dodge invulnerability prevents hook damage and pull")
	expect(world.state.precision_count == precision+1,"dujun hook still awards precise dodge")
	isolate(); boss = spawn("boss",Vector2(1000,900),"dujun"); var wall = wall_between(925)
	await settle(); boss.start_action(hero); boss.advance_action(1.0,hero)
	expect(hero.hp == hero.max_hp and hero.knockback.is_zero_approx(),"hook cannot reach through a camp wall")
	wall.queue_free(); await settle()
	# A collision wall behind the victim remains solid throughout the pull.
	isolate(); boss = spawn("boss",Vector2(1000,900),"dujun"); boss.start_action(hero); boss.advance_action(1.0,hero)
	wall = wall_between(890); await settle()
	for frame in range(30): hero.tick_common(1.0/60)
	expect(hero.position.x <= 869.0,"hook pull never crosses a new wall or riverbank")
	wall.queue_free(); await settle()
	# All authored dujun segments use their displayed direction and sector,
	# including the delayed return cut and phase-two sweep. Check one frame
	# on either side of both active boundaries in all four directions.
	for direction in [0.0,PI/2,PI,-PI/2]:
		for chain in Enemy.BOSS_MOVES.dujun:
			for definition in chain:
				isolate(); boss = spawn("boss",Vector2(850,900),"dujun")
				reset_target(boss.position+Vector2.from_angle(direction)*72)
				boss.facing = direction; boss.action = world.new_action("enemy",definition,direction)
				boss.advance_action(definition.windup-.001,hero)
				expect(hero.hp == hero.max_hp,definition.name+" windup is harmless dir "+str(direction))
				boss.advance_action(.002,hero)
				expect(hero.hp == hero.max_hp-definition.damage,definition.name+" hits on active boundary dir "+str(direction))
				hero.invincible = 0; boss.advance_action(definition.active+.002,hero)
				expect(hero.hp == hero.max_hp-definition.damage,definition.name+" cannot repeat one hit dir "+str(direction))
				hero.invincible = 0; boss.advance_action(definition.recovery,hero)
				expect(hero.hp == hero.max_hp-definition.damage and boss.action.is_empty(),definition.name+" recovery adds no damage dir "+str(direction))
				isolate(); boss = spawn("boss",Vector2(850,900),"dujun")
				reset_target(boss.position+Vector2.from_angle(direction+PI)*72)
				boss.action = world.new_action("enemy",definition,direction)
				# Skip tracking: this is a target outside an already locked red
				# sector, not a new aim at the action's start.
				boss.action.t = definition.windup*.6
				boss.advance_action(definition.windup*.4+.01,hero)
				expect(hero.hp == hero.max_hp,definition.name+" does not hit behind its locked sector dir "+str(direction))

	isolate(); boss = spawn("boss",Vector2(1000,900),"dujun")
	for move_index in range(3):
		boss.attack_count = move_index; boss.sequence = []; boss.action = {}; boss.start_action(hero)
		expect(boss.action.def.name in ["钩锁探身","双轮重斧 · 起斩","撼地断营"],"first phase cycles its three explicit attacks")
	boss.hp = boss.max_hp*.49; boss.action = {}; boss.sequence = []; boss.advance(.01)
	expect(boss.phase2 and is_equal_approx(boss.phase_time,1.1) and boss.action.is_empty(),"half health has a non-damaging phase transition")
	var phase_hp = boss.hp; boss.take_hit(10,0,0,"player",0)
	expect(boss.hp == phase_hp,"phase transition cannot be damaged or skipped")
	boss.advance(1.11)
	expect(not boss.action.is_empty() and boss.action.def.style == "rush","second phase opens with readable short charge")
	var rush_id = boss.action.id; boss.take_hit(1,0,0,"player",135)
	expect(boss.action.is_empty() and boss.sequence.is_empty() and boss.stun > 1,"real poise break cancels the entire new boss combo")
	isolate(); boss = spawn("boss",Vector2(1000,900),"dujun")
	var health = boss.hp; boss.take_hit(9999,0,0,"ally",0)
	expect(is_equal_approx(boss.hp,boss.max_hp*.22),"allies cannot finish dujun or bypass player kill floor")
	expect(health > boss.hp,"ally contribution remains finite and real")
	print("HANSHUI_ENEMY_VERIFY ",checks," checks; ",failures.size()," failures")
	world.queue_free(); await process_frame; await process_frame
	quit(0 if failures.is_empty() else 1)
