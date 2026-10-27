extends RefCounted
## Chapter-one spacing only. Attack timing, target selection and shared turn
## limits remain owned by Enemy/CombatPacing. No new durable state.
const REGIONS = ["mountain","village","temple","house","fork","bridge"]

static func enabled(enemy) -> bool:
	return enemy.kind != "boss" and is_instance_valid(enemy.world) and str(enemy.world.get("stage")) in REGIONS

static func attack_lane(enemy, target) -> bool:
	if not enabled(enemy) or not enemy.is_ranged(): return true
	return enemy.world.terrain.line_clear(enemy.position,target.position,0)

static func spacing_point(enemy, target) -> Vector2:
	var away: Vector2=enemy.position-target.position
	var distance=away.length()
	if distance<.01: away=Vector2.LEFT
	else: away/=distance
	if enemy.is_ranged():
		if not attack_lane(enemy,target):
			# Try both shoulders of the obstacle. Never fire through a wall or
			# consume the ranged attack slot while still looking for a lane.
			var tangent=away.orthogonal()
			for offset in [110.0,-110.0,190.0,-190.0]:
				var point: Vector2=enemy.position+tangent*offset
				if not enemy.world.terrain.blocked(point,enemy.radius) and enemy.world.terrain.line_clear(point,target.position,0): return point
			return target.position+away*190
		if distance<205: return target.position+away*245
		if distance<390: return enemy.position
		return target.position+away*320
	if enemy.kind=="spear": return target.position+away*108
	# Close fighters approach separate shoulders instead of all occupying one
	# spot. Home positions keep the chosen side stable as their path updates.
	var anchor: Vector2=enemy.home-target.position
	if anchor.length_squared()<1: anchor=away
	var side=-1.0 if enemy.world.enemies.find(enemy)%2==0 else 1.0
	var angle=anchor.angle()+side*.36
	return target.position+Vector2.from_angle(angle)*(62 if enemy.kind=="sword" else 66)

static func advance_spacing(enemy, target, dt: float) -> bool:
	if not enabled(enemy): return false
	if not enemy.is_ranged() and enemy.position.distance_to(target.position)>270: return false
	var point=spacing_point(enemy,target)
	# A bad local shoulder must not strand an encounter behind a new prop.
	if enemy.world.terrain.blocked(point,enemy.radius): return false
	if enemy.position.distance_to(point)>24:
		enemy.navigate(point,enemy.speed*(.82 if enemy.is_ranged() else .88),dt)
		enemy.facing=(target.position-enemy.position).angle()
	return true
