extends "res://scripts/actor.gd"
var slot = 0
var attack_cd = 0.0

func _init() -> void:
	faction = "ally"; kind = "ally"; radius = 12; hp = 140; max_hp = 140

func advance(dt: float) -> void:
	tick_common(dt); attack_cd = maxf(0, attack_cd - dt)
	if hp <= 0 or world.active_boss != "" or kind == "healer":
		update_visual(); return
	var active = world.squad_active()
	var target = world.nearest_enemy(position, 270 if world.command == "charge" else 170) if active and kind == "ally" else null
	var destination = world.hero.position + Vector2(-65 + (slot - 1) * 48, 65 + (slot % 2) * 24)
	if kind in ["civil", "mother"]:
		destination = Vector2(1270 + (18 if slot % 2 else -18), 145 + slot * 22) if world.state.flags.boss else world.hero.position + Vector2(-80 + (slot % 3 - 1) * 24, 90 + int(slot / 3) * 32)
	elif active and world.command == "hold": destination = home
	if target and (world.command != "hold" or position.distance_to(home) < 140):
		destination = target.position
		if position.distance_to(target.position) < 62 and attack_cd <= 0:
			facing = (target.position - position).angle(); attack_cd = 1.8
			target.take_hit(3.5,facing,8,"ally",2)
			world.fx.add("ally",position,.18,{"dir":facing,"radius":58.0,"arc":.5})
	if position.distance_to(destination) > (44 if target else 30): navigate(destination, 215 if position.distance_to(world.hero.position) > 340 else 166, dt)
	update_visual()

func take_damage(amount: float, _attack_id: int = -1) -> bool:
	if hp <= 0: return false
	amount *= .64 if world.state.difficulty == "story" else 1
	hp = maxf(0, hp - amount); hurt_flash = .2
	world.fx.floater(position,"-" + str(int(round(amount))),Color("efad98"))
	return true
