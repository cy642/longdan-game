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
	field = Battle.new()
	root.add_child(field)
	_shield_and_dodge()
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
