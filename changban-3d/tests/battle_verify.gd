extends SceneTree

const Battle := preload("res://battle.gd")
var field: Node3D
var failures := 0
var checks := 0

func _initialize() -> void:
	call_deferred("_verify")

func _check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		printerr("FAIL ", label)

func _verify() -> void:
	for action in ["move_left","move_right","move_forward","move_back","dodge","heavy","attack","dragon","interact"]:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
	field = Battle.new()
	root.add_child(field)
	_shield_and_dodge()
	_step_and_steer()
	_dragon_windows()
	_counter_window()
	await _skill_input()
	_handoff_and_crossing()
	field.queue_free()
	await process_frame
	await process_frame
	print("Battle regression: ", checks, " checks, ", failures, " failures")
	quit(1 if failures else 0)

func _shield_and_dodge() -> void:
	var guard = field.foes[0]
	var shield = field.foes[1]
	field.hero.position = shield.body.position + Vector3.BACK * 2.0
	field.hero.rotation.y = 0.0
	shield.body.rotation.y = PI
	var before: float = shield.health
	field._player_contact(false)
	_check(shield.health == before, "shield blocks frontal light thrust")
	field._player_contact(true)
	_check(shield.health < before and shield.guard_open > 0.0, "heavy breaks shield guard")
	field.hero.position = guard.body.position + Vector3.BACK * 1.2
	field._arm(guard, Vector3.BACK)
	_check(guard.cue != null and guard.state == "windup", "strike announces its arc before impact")
	field._advance_foe(guard, guard.duration)
	field._begin("dodge")
	var health: float = field.hp
	field._advance_foe(guard, 0.19)
	_check(guard.connected and field.hp == health, "timed dodge avoids attack")
	field.invincible = 0.0
	field.action = "idle"
	field._arm(guard, Vector3.BACK)
	field._advance_foe(guard, guard.duration)
	field._advance_foe(guard, 0.19)
	_check(field.hp < health, "unavoided committed attack deals damage")

func _step_and_steer() -> void:
	field.restart()
	field.move_dir = Vector3.LEFT
	var x: float = field.hero.position.x
	field._advance_hero(1.0/60.0)
	var start_step: float = x - field.hero.position.x
	_check(start_step > 0.0 and start_step < Battle.RUN_SPEED/60.0, "movement starts by transferring weight onto a step")
	for i in 12:
		field._advance_hero(1.0/60.0)
	field.move_dir = Vector3.ZERO
	for i in 8:
		field._advance_hero(1.0/60.0)
	_check(field.ground_velocity.is_zero_approx(), "released movement plants both feet promptly")
	field.hero.position = Vector3(6.8,0,14)
	field.move_dir = Vector3.RIGHT
	var walk_phase: float = field.stride
	for i in 15:
		field._advance_hero(1.0/60.0)
	_check(is_equal_approx(field.stride,walk_phase) and is_equal_approx(field.hero.position.x,6.8), "pressed against an edge cannot run the gait cycle")
	field.hero.rotation.y = 0
	field._begin("heavy")
	_check(field.hero.rotation.y == 0.0 and field.aim_to < -1.0, "spear turns into the wind-up instead of snapping")
	field._advance_hero(field.duration*0.15)
	_check(field.hero.rotation.y < -0.1 and field.hero.rotation.y > field.aim_to+0.1, "wind-up passes through an intermediate heading")

func _setup_skill_targets() -> void:
	field.restart()
	field.hero.position = Vector3.ZERO
	field.foes[0].body.position = Vector3(2.12,0,-1.12)
	field.foes[1].body.position = Vector3(0,0,-2.08)
	field.foes[1].body.rotation.y = PI

func _dragon_windows() -> void:
	_setup_skill_targets()
	var guard = field.foes[0]
	var shield = field.foes[1]
	field._begin("dragon")
	var length: float = field.duration
	_check(field.action == "dragon" and field.dragon_cooldown == Battle.DRAGON_RECHARGE, "skill spends its cooldown on cast")
	_check(field.invincible == 0.0, "dragon commits to its attack without free invulnerability")
	field._advance_hero(length * 0.32)
	_check(shield.health == shield.max_health and guard.health == guard.max_health, "dragon wind-up is safe")
	field._advance_hero(length * 0.03)
	_check(field.dragon_strokes == 1 and shield.guard_open > 0 and shield.health == shield.max_health-16, "first cut breaks a frontal shield")
	_check(guard.health == guard.max_health-16, "first cut sweeps a side target")
	field._advance_hero(length * 0.27)
	_check(shield.health == shield.max_health-16, "recovery between cuts cannot deal duplicate damage")
	_check(not field.fx.brush_meshes.has("impact"), "lateral cut cannot generate the return thrust's hit crest")
	field._advance_hero(length * 0.03)
	_check(field.dragon_strokes == 2 and shield.health == shield.max_health-39, "second thrust hits at its distinct contact")
	_check(field.hero.position.distance_to(shield.body.position) >= 1.35, "thrust maintains a visible shaft gap to the enemy")
	_check(guard.health == guard.max_health-16, "narrow thrust misses a lateral target")
	var actual_crests := 0
	for flash in field.fx.flashes:
		if flash.node.mesh == field.fx.brush_meshes.get("impact"):
			actual_crests += 1
	_check(actual_crests == 1, "one contacted enemy produces exactly one shoulder crest")
	field._advance_hero(length * 0.36)
	_check(field.action == "idle" and shield.health == shield.max_health-39, "recovery ends without bonus hits")
	field._queue("attack")
	field._queue("dragon")
	_check(field.pending == "attack" and not field._can_begin("dragon"), "cooling skill cannot erase a legal queued action")
	_setup_skill_targets()
	field._begin("dragon")
	field._advance_hero(field.duration)
	_check(field.dragon_strokes == 2 and field.foes[1].health == field.foes[1].max_health - 39, "both distinct contacts resolve across a large simulation step")
	field.restart()
	field.hero.position = Vector3(3.9,0,-18.0)
	field.hero.rotation.y = -PI/2
	field._begin("dragon")
	field._advance_hero(field.duration)
	_check(field.hero.position.x <= 4.001 and field.hero.position.y == 0, "dragon burst stays within bridge rails")
	_check(not field.fx.brush_meshes.has("impact"), "empty return thrust produces no hit crest")

func _counter_window() -> void:
	field.restart()
	var guard = field.foes[0]
	field.hero.position = guard.body.position + Vector3.BACK * 1.1
	field._arm(guard,Vector3.BACK)
	field._advance_foe(guard,guard.duration)
	field._begin("dodge")
	field.elapsed = 0.08
	field.hero.position.x += 1.2
	field._advance_foe(guard,0.19)
	_check(field.riposte_window > 0.0 and field.riposte_target == guard, "precise sidestep out of the committed arc opens return thrust")
	field._queue("attack")
	_check(field.pending == "attack" and field.pending_time >= field.duration-field.elapsed, "J can be buffered during the perfect dodge")
	field._advance_hero(field.duration)
	field._begin("attack")
	_check(field.action == "riposte" and field.riposte_window == 0.0, "J consumes the opening once")
	var old_hp: float = guard.health
	field._advance_hero(field.duration * 0.36)
	_check(guard.health == old_hp, "counter has a visible wind-up")
	field._advance_hero(field.duration * 0.02)
	_check(guard.health == old_hp-34, "counter turns back to the actual attacker and strikes")
	field._advance_hero(field.duration)
	field._begin("attack")
	_check(field.action == "attack", "following attack is regular")
	field.restart()
	guard = field.foes[0]
	field.hero.position = guard.body.position + Vector3.BACK * 1.2
	field._arm(guard,Vector3.BACK)
	field._advance_foe(guard,guard.duration)
	field._begin("dodge")
	field.elapsed = 0.21
	field._advance_foe(guard,0.19)
	_check(field.hp == field.hp_max and field.riposte_window == 0.0, "early roll is safe but lacks a precise opening")
	field.action = "idle"
	field.hero.position = guard.body.position + Vector3.FORWARD
	field._arm(guard,Vector3.BACK)
	field._advance_foe(guard,guard.duration)
	field._begin("dodge")
	field._advance_foe(guard,0.19)
	_check(field.riposte_window == 0.0, "outside enemy arc cannot generate a counter")

func _skill_input() -> void:
	field.restart()
	field.active = true
	await physics_frame
	Input.action_press("dragon")
	await physics_frame
	await physics_frame
	Input.action_release("dragon")
	_check(field.action == "dragon" and field.dragon_cooldown > 0.0, "mapped action casts skill in production physics loop")
	field.active = false
	var cooldown: float = field.dragon_cooldown
	var phase: float = field.elapsed
	field._physics_process(0.5)
	_check(field.dragon_cooldown == cooldown and field.elapsed == phase, "pause freezes cooldown and both cuts")
	field.active = true
	for i in field.foes.size():
		field.foes[i].body.position = Vector3(i*2,0,-10)
	for i in 448:
		field._physics_process(1.0 / 60.0)
	_check(field.dragon_cooldown > 0.0 and not field._can_begin("dragon"), "skill remains spent until recharge completes")
	for i in 4:
		field._physics_process(1.0 / 60.0)
	_check(field.dragon_cooldown == 0.0 and field._can_begin("dragon"), "skill re-arms in active time")
	field.active = false
	field.restart()
	_check(field.dragon_cooldown == 0.0 and field.riposte_window == 0.0 and field.action == "idle", "restart restores fresh skill state")

func _handoff_and_crossing() -> void:
	field.restart()
	var bundle: Node3D = field.refugee.child_bundle
	_check(bundle.get_parent() == field.refugee.cloth, "infant starts in the villager's arms")
	field.hero.position = field.refugee.position + Vector3.BACK * 0.8
	field._rescue()
	for i in 24:
		field._follow(1.0 / 60.0)
	_check(bundle.get_parent() == field.hero_model.body, "same infant reaches hero's moving torso")
	field.stage = 3
	field.hero.position = Vector3(0, 0, -24.1)
	field.refugee.position = Vector3(0.1, 0, -25.0)
	field._progress()
	_check(field.stage == 3, "hero must cross north lip")
	field.hero.position = Vector3(0, 0, -25.0)
	field.refugee.position = Vector3(0.1, 0, -22.45)
	field._progress()
	_check(field.stage == 3, "villager must physically cross north lip")
	var stopped: Vector3 = field.hero.position
	for i in 180:
		if field.stage == 4:
			break
		field._follow(1.0 / 60.0)
		field._progress()
	_check(field.stage == 4 and field.refugee.position.z < -24.2, "villager reaches bank without player moving farther")
	_check(field.hero.position.is_equal_approx(stopped), "hero may stop at exit marker")
	field.restart()
	_check(field.refugee.child_bundle.get_parent() == field.refugee.cloth and field.stage == 0, "retry restores infant and encounter")
