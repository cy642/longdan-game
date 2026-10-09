extends CharacterBody2D
## All actors share native ground collision and a foot-anchored visual.
const Visual = preload("res://scripts/actor_visual.gd")
var world
var visual
var faction = "enemy"
var kind = "sword"
var boss_id = ""
var group_id = ""
var display_name = ""
var hp = 100.0
var max_hp = 100.0
var radius = 14.0
var facing = 0.0
var speed = 100.0
var action: Dictionary = {}
var moving = false
var walk_distance = 0.0
var hurt_flash = 0.0
var stun = 0.0
var dead_time = 0.0
var knockback = Vector2.ZERO
var home = Vector2.ZERO
var path: PackedVector2Array = []
var path_clock = 0.0
var uid = 0
var shadow_alive=true

func _ready() -> void:
	uid = get_instance_id()
	collision_layer = 2 if faction == "hero" else 4 if faction == "enemy" else 8
	collision_mask = 1
	var shape = get_node_or_null("GroundCollision")
	if shape==null:
		shape=CollisionShape2D.new(); shape.name="GroundCollision"; add_child(shape)
	var circle = CircleShape2D.new(); circle.radius = radius
	shape.shape = circle
	visual = Visual.new(); visual.actor = self; add_child(visual)
	home = position
	add_to_group("combatants")

func move_ground(displacement: Vector2) -> float:
	var previous = position
	var collision = move_and_collide(displacement)
	if collision:
		move_and_collide(collision.get_remainder().slide(collision.get_normal()))
	if world and world.active_boss != "" and (faction == "hero" or boss_id != ""):
		var arena = world.definition.arena
		position.x = clampf(position.x, arena.x - arena.rx + radius, arena.x + arena.rx - radius)
		position.y = clampf(position.y, arena.y - arena.ry + radius, arena.y + arena.ry - radius)
	var distance = position.distance_to(previous)
	moving = distance > 0.025; walk_distance += distance
	return distance

func navigate(target: Vector2, pace: float, dt: float) -> void:
	var offset = target - position
	if offset.length() < 20: return
	facing = offset.angle()
	var moved = move_ground(offset.normalized() * pace * dt)
	path_clock -= dt
	if moved > pace * dt * .6 and path.is_empty(): return
	if path_clock <= 0:
		path = world.terrain.find_path(position, target, radius)
		path_clock = .55
	while not path.is_empty() and position.distance_to(path[0]) < 22:
		path.remove_at(0)
	if not path.is_empty():
		var direction = (path[0] - position).normalized()
		facing = direction.angle(); move_ground(direction * pace * dt)

func tick_common(dt: float) -> void:
	moving = false
	hurt_flash = maxf(0, hurt_flash - dt)
	stun = maxf(0, stun - dt)
	if hp <= 0:
		dead_time += dt
		return
	if knockback.length() > 1:
		move_ground(knockback * dt)
		knockback *= exp(-12 * dt)

func body_alive() -> bool:
	return hp > 0 and not is_queued_for_deletion()

func update_visual() -> void:
	if visual: visual.update_pose()
	if shadow_alive!=(hp>0):
		shadow_alive=hp>0; queue_redraw()

func _draw() -> void:
	# Cover both boots in the wider spear stance; the old narrow ellipse ended
	# before the planted foot and made the character appear to hover.
	draw_set_transform(Vector2(0,1 if faction=="hero" else 2),0,Vector2(1,.22 if faction=="hero" else .26))
	draw_circle(Vector2.ZERO,28 if faction=="hero" else 17,Color(.04,.16,.14,.22 if hp>0 else .08))
