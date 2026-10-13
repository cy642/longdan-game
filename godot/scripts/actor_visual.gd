extends Node2D
## Frames exclude neighboring sprites and retain a stable head scale and boot pivot.
const FrameTexture = preload("res://scripts/frame_texture.gd")
const WALK = [12, 2, 0, 2, 4, 6, 8, 10]
const WINDUP = [12, 2, 0, 2, 12, 10, 8, 10]
const STRIKE = [5, 3, 1, 3, 5, 7, 9, 7]
const WINDUP_FLIP = [false, true, false, false, true, true, false, false]
const STRIKE_FLIP = [false, false, false, true, true, true, false, false]
static var atlas_data: Dictionary = {}
static var frames: Dictionary = {}
var actor
var body: Sprite2D
var current_scale = 1.0
var last_frame: Array=[]
var baby_visible=false
# Enemy frames remain the original painted pixels. A small skinned grid bends
# the upper-body/weapon silhouette and supporting legs separately, keeping feet planted.
const POSE_KEYS = ["lean", "crouch", "arm", "reach", "stride", "lift", "guard"]
static var enemy_rigs: Dictionary = {}
var rig: Polygon2D
var rig_data: Dictionary = {}
var last_rig_pose: Dictionary = {}
var last_rig_gait = -1.0
var animation_time = 0.0
var pose_delta = 0.0
var move_blend = 0.0
var displayed_pose: Dictionary = neutral_pose()
var action_entry_pose: Dictionary = neutral_pose()
var last_action_id = -1
var reaction_start = -10.0
var reaction_direction = 0.0
var reaction_blocked = false
var reaction_pose: Dictionary = neutral_pose()
var death_start = -1.0
var death_pose: Dictionary = neutral_pose()
var death_direction = 1.0

static func neutral_pose() -> Dictionary:
	return {"lean":0.0, "crouch":0.0, "arm":0.0, "reach":0.0, "stride":0.0, "lift":0.0, "guard":0.0}

static func blend_pose(from: Dictionary, to: Dictionary, weight: float) -> Dictionary:
	var result = {}
	for key in POSE_KEYS: result[key] = lerpf(from[key], to[key], clampf(weight, 0, 1))
	return result

static func pose_ease(value: float) -> float:
	var t = clampf(value, 0, 1)
	return t * t * (3.0 - 2.0 * t)

func advance_time(dt: float) -> void:
	animation_time += dt
	pose_delta = dt

func react_to_hit(direction: float, blocked: bool, lethal: bool) -> void:
	reaction_start = animation_time
	reaction_direction = direction
	reaction_blocked = blocked
	reaction_pose = displayed_pose.duplicate()
	if lethal and death_start < 0:
		death_start = animation_time
		death_pose = displayed_pose.duplicate()
		death_direction = 1.0 if cos(direction) >= 0 else -1.0


static func prepare() -> void:
	if not frames.is_empty(): return
	atlas_data = JSON.parse_string(FileAccess.get_file_as_string("res://data/atlas.json"))
	for key in atlas_data:
		var atlas = load(atlas_data[key].file)
		var textures: Array = []
		for frame in atlas_data[key].frames:
			textures.append(FrameTexture.create(atlas, frame))
		frames[key] = textures

func _ready() -> void:
	prepare()
	body = Sprite2D.new(); body.centered = false
	add_child(body); update_pose()

func set_frame(key: String, index: int, flip: bool, hero: bool, height: float = 62) -> void:
	var frame=[key,index,flip,hero,height]
	if frame==last_frame: return
	last_frame=frame
	var meta = atlas_data[key].frames[index]
	body.texture = frames[key][index]
	current_scale = 26.0 / float(meta.head_height) if hero else height / float(meta.region[3])
	# The pivot always remains on the ground; spear tips cannot change body scale.
	body.position = Vector2(-meta.anchor[0], -meta.anchor[1]) * current_scale
	body.scale = Vector2.ONE * current_scale
	if flip:
		body.scale.x = -current_scale
		body.position.x = meta.anchor[0] * current_scale

func update_pose() -> void:
	if body == null: return
	var hero = actor.faction == "hero"
	var direction = posmod(int(round(actor.facing / (PI / 4))), 8)
	position = Vector2.ZERO; rotation = 0; scale = Vector2.ONE; modulate = Color.WHITE
	if hero:
		if actor.hp <= 0:
			set_frame("hero", 7, cos(actor.facing) >= 0, true)
		elif not actor.action.is_empty() and actor.action.key != "heal":
			var a = actor.action; var def = a.def
			var active_pose = a.t >= def.windup and a.t < def.windup + def.active + def.recovery * .55
			set_frame("attack", STRIKE[direction] if active_pose else WINDUP[direction], STRIKE_FLIP[direction] if active_pose else WINDUP_FLIP[direction], true)
			# Actor movement already moves the boots and shadow together. A second
			# visual-only lunge detached the feet from their ground contact.
			if a.key in ["sweep", "sword", "thrust2"]:
				rotation = sin(a.t / (def.windup + def.active + def.recovery) * TAU) * .065
		else:
			var step = int(actor.walk_distance / actor.HERO_STEP_DISTANCE) % 2 if actor.moving else 0
			set_frame("walk", WALK[direction] + step, direction == 1, true)
			# No idle vertical bob: planted boots remain at the same ground position.
			rotation = sin(actor.walk_distance / 18) * .022 if actor.moving else 0
			if actor.dash_left > 0: rotation = -.08
	else:
		var key = "units"; var index = 1
		match actor.kind:
			"spear": index = 2
			"archer": index = 3
			"shield": key = "chapter"; index = 0
			"elite": key = "chapter"; index = 1
			"boss": key = "chapter"; index = 2 if actor.boss_id == "zhanghe" else 7
			"ally": key = "chapter"; index = 5 + (int(actor.walk_distance / 32) % 2 if actor.moving else 0)
			"healer": key = "chapter"; index = 3
			"mother": key = "chapter"; index = 4
			"civil": index = 5 + int(actor.uid % 3)
		set_frame(key, index, cos(actor.facing) >= 0, false, 84 if actor.kind in ["boss", "elite"] else 58 if actor.kind in ["civil", "healer", "mother"] else 65)
		if actor.faction == "enemy":
			update_enemy_pose(key, index)
		elif actor.hp <= 0:
			rotation = -.95; position.y = 5; modulate.a = maxf(0, .28 * (1 - actor.dead_time / 10))
		elif actor.moving:
			rotation = sin(actor.walk_distance / 18) * .035
			position.y = -absf(sin(actor.walk_distance / 20)) * .7

	if actor.hurt_flash > 0:
		if actor.faction != "enemy": modulate = Color(1.4, 1.2, 1.0, .85)
		elif actor.hp > 0: modulate = Color(1.3, 1.13, 1.0, modulate.a)
	var carrying=actor.faction=="hero" and actor.world.state.flags.adou
	if carrying!=baby_visible:
		baby_visible=carrying; queue_redraw()

func _draw() -> void:
	if actor == null: return
	if actor.faction == "hero" and actor.world.state.flags.adou:
		draw_circle(Vector2(-13, -34), 5, Color("f4ddbc"))
		draw_circle(Vector2(-13, -39), 3, Color("f2c9a5"))

# Return a continuous pose at every boundary of the existing damage windows.
# This function never advances the action or changes collision/hit timing.
func sample_enemy_action(a: Dictionary) -> Dictionary:
	var d = a.def
	var spear = actor.kind == "spear" or actor.boss_id == "zhanghe"
	var archer = actor.kind == "archer"
	var shield = actor.kind in ["shield", "elite"]
	var sweep = float(d.get("arc", 0)) > 1.5
	var loaded = neutral_pose()
	loaded.merge({"lean":.105, "crouch":2.4, "arm":.30 if not spear else .12, "reach":3.0, "guard":.45 if shield else 0.0}, true)
	var strike = neutral_pose()
	strike.merge({"lean":-.16, "crouch":1.2, "arm":-.38 if spear else -.48, "reach":-4.5 if spear else -3.0, "guard":1.0 if shield else 0.0}, true)
	var follow = strike.duplicate()
	follow.lean = -.09
	follow.arm = -.50 if sweep else -.28 if spear else -.52
	follow.reach *= .7
	follow.crouch = 2.0
	if archer:
		loaded.merge({"lean":.07, "crouch":.9, "arm":-.12, "reach":-2.5}, true)
		strike.merge({"lean":.11, "crouch":1.0, "arm":.15, "reach":1.5}, true)
		follow = strike.duplicate()
	# A small elevation adjustment follows the same locked direction as the hitbox.
	var elevation = sin(a.dir) * .12
	loaded.arm += elevation
	strike.arm += elevation
	follow.arm += elevation
	if a.t < d.windup:
		return blend_pose(neutral_pose(), loaded, pose_ease(a.t / (d.windup * .82)))
	if a.t < d.windup + d.active:
		var t = (a.t - d.windup) / d.active
		return blend_pose(loaded, strike, pose_ease(t / .42)) if t < .42 else blend_pose(strike, follow, pose_ease((t - .42) / .58))
	var recovery = (a.t - d.windup - d.active) / maxf(.001, d.recovery)
	# Hold the follow-through briefly, then visibly release back into guard.
	return blend_pose(follow, neutral_pose(), pose_ease((recovery - .12) / .88))

func update_enemy_pose(key: String, index: int) -> void:
	if rig == null:
		build_enemy_rig(key, index)
	body.visible = false
	rig.scale = Vector2(-1 if cos(actor.facing) >= 0 else 1, 1) * current_scale
	var can_walk = actor.moving and actor.action.is_empty() and actor.hp > 0 and actor.stun <= 0
	move_blend = move_toward(move_blend, 1.0 if can_walk else 0.0, pose_delta * 11.0)
	pose_delta = 0.0
	var pose = neutral_pose()
	var gait = actor.walk_distance / 15.0
	pose.stride = sin(gait) * 4.2 * move_blend
	pose.lift = 2.8 * move_blend
	pose.lean = sin(gait) * .024 * move_blend
	pose.arm = -sin(gait) * .09 * move_blend
	pose.crouch = absf(sin(gait)) * .65 * move_blend
	if not actor.action.is_empty():
		var a = actor.action
		if int(a.get("id", 0)) != last_action_id:
			last_action_id = int(a.get("id", 0))
			action_entry_pose = displayed_pose.duplicate()
		pose = blend_pose(action_entry_pose, sample_enemy_action(a), pose_ease(a.t / minf(.12, a.def.windup * .3)))
	else:
		last_action_id = -1
	if actor.stun > 0 or actor.get("phase_time") > 0:
		var braced = neutral_pose()
		braced.crouch = 4.0
		braced.lean = .08
		braced.arm = -.18
		braced.guard = -.45
		var brace_weight = pose_ease(actor.stun / .3)
		if actor.get("phase_time") > 0:
			brace_weight = pose_ease(minf((1.35 - actor.phase_time) / .2, actor.phase_time / .3))
		pose = blend_pose(pose, braced, brace_weight * .8)
	var since_hit = animation_time - reaction_start
	if since_hit < .3 and actor.hp > 0:
		# First preserve the interrupted pose, then absorb the impulse and settle.
		pose = blend_pose(reaction_pose, pose, pose_ease(since_hit / .18))
		var kick = sin(clampf(since_hit / .28, 0, 1) * PI) * exp(-since_hit * 5)
		var local_sign = -1.0 if (cos(reaction_direction) >= 0) == (cos(actor.facing) >= 0) else 1.0
		pose.lean += local_sign * kick * (.10 if reaction_blocked else .27)
		pose.crouch += kick * (1.5 if reaction_blocked else 4.0)
		pose.arm += kick * (.12 if reaction_blocked else -.22)
	if actor.hp <= 0:
		if death_start < 0:
			death_start = animation_time - actor.dead_time
			death_pose = displayed_pose.duplicate()
			death_direction = 1.0 if cos(actor.facing) < 0 else -1.0
		var fall = pose_ease(actor.dead_time / .46)
		var fallen = neutral_pose()
		fallen.crouch = 5.0; fallen.arm = -.4
		pose = blend_pose(death_pose, fallen, fall)
		rotation = death_direction * 1.32 * fall
		position.y = 4.0 * fall
		modulate.a = lerpf(1.0, .42, pose_ease((actor.dead_time - .55) / .6)) * clampf(1.0 - maxf(0, actor.dead_time - 1.5) / 8.5, 0, 1)
	displayed_pose = pose
	deform_enemy_rig(pose, gait)

func build_enemy_rig(key: String, index: int) -> void:
	var cache_key = key + ":" + str(index)
	if not enemy_rigs.has(cache_key):
		var meta = atlas_data[key].frames[index]
		var width = float(meta.region[2]); var height = float(meta.region[3])
		var xs: Array = []; var ys: Array = []
		var head_bounds = enemy_head_bounds()
		var safe_head = head_bounds.grow(.04)
		# Only the pelvis/legs need dense rows; the painted upper silhouette is
		# rigid. Add exact exclusion boundaries so neighboring atlas fragments
		# remain clipped without paying for a dense full-sprite mesh each tick.
		for x in range(9): xs.append(width * x / 8.0)
		for y in [0.0, .25, .5, .625, .66, .70, .78, .86, .93, 1.0]: ys.append(height * y)
		var holes: Array[Rect2] = []
		for excluded in meta.get("exclude", []):
			var hole = Rect2(excluded[0], excluded[1], excluded[2], excluded[3])
			holes.append(hole)
			for x in [hole.position.x, hole.end.x]:
				if not xs.has(x): xs.append(x)
			for y in [hole.position.y, hole.end.y]:
				if not ys.has(y): ys.append(y)
		for x in [safe_head.position.x * width, safe_head.end.x * width]:
			if x > 0 and x < width and not xs.has(x): xs.append(x)
		for y in [safe_head.position.y * height, safe_head.end.y * height]:
			if y > 0 and y < height and not ys.has(y): ys.append(y)
		xs.sort(); ys.sort()
		var rest = PackedVector2Array(); var uv = PackedVector2Array()
		var weights: Array = []; var polygons: Array[PackedInt32Array] = []
		var head_indices = PackedInt32Array(); var weapon_indices = PackedInt32Array()
		var anchor = Vector2(meta.anchor[0], meta.anchor[1])
		for y in ys:
			for x in xs:
				var p = Vector2(x, y); var n = p / Vector2(width, height)
				rest.append(p - anchor)
				uv.append(p + Vector2(meta.region[0], meta.region[1]))
				var protected = safe_head.grow(.0001).has_point(n)
				var weapon = enemy_weapon_region(n)
				if head_bounds.has_point(n): head_indices.append(rest.size() - 1)
				if weapon: weapon_indices.append(rest.size() - 1)
				var lower = 0.0 if weapon else pose_ease((n.y - .70) / .25)
				var upper = 1.0 if protected or weapon else 1 - pose_ease((n.y - .66) / .33)
				weights.append(Vector4(upper, 0, lower, pose_ease((n.x - .38) / .22)))
		for y in range(ys.size() - 1):
			for x in range(xs.size() - 1):
				var mid = Vector2((xs[x]+xs[x+1])*.5, (ys[y]+ys[y+1])*.5)
				var excluded = false
				for hole in holes:
					if hole.has_point(mid): excluded = true; break
				if excluded: continue
				var i = y * xs.size() + x
				polygons.append(PackedInt32Array([i, i + 1, i + xs.size() + 1, i + xs.size()]))
		enemy_rigs[cache_key] = {"rest":rest, "uv":uv, "weights":weights, "head_indices":head_indices, "weapon_indices":weapon_indices, "polygons":polygons, "height":height, "hip":Vector2(width*.52,height*.73)-anchor, "texture":load(atlas_data[key].file)}
	rig_data = enemy_rigs[cache_key]
	rig = Polygon2D.new()
	rig.name = "ArticulatedEnemy"
	rig.texture = rig_data.texture
	rig.polygon = rig_data.rest
	rig.uv = rig_data.uv
	rig.polygons = rig_data.polygons
	add_child(rig)

func enemy_head_bounds() -> Rect2:
	# These source-space rectangles protect the painted face and helmet as one
	# rigid piece. The grid also includes a margin around their edges, preventing
	# a weapon triangle from dragging neighboring facial pixels across the joint.
	match actor.kind:
		"sword": return Rect2(.13, .10, .69, .49)
		"spear": return Rect2(.24, .10, .67, .49)
		"archer": return Rect2(.26, .05, .63, .56)
		"shield": return Rect2(.18, .10, .57, .41)
		"elite": return Rect2(.18, .05, .41, .54)
		"boss": return Rect2(.20, .12, .49, .48) if actor.boss_id == "zhanghe" else Rect2(.19, .07, .56, .52)
	return Rect2(.15, .1, .7, .5)

func enemy_weapon_region(n: Vector2) -> bool:
	# The source spear crosses the painted face/arm. Rotating that strip alone
	# stretches the helmet or bends the shaft. Keep its silhouette rigid with
	# the upper body, including the portion extending below the belt.
	if actor.kind == "spear" or actor.boss_id == "zhanghe":
		var shaft_x = .03 + n.y * .31 if actor.boss_id == "zhanghe" else .045 + n.y * .49
		return absf(n.x - shaft_x) < .14
	if actor.kind == "archer": return n.x < .40 and n.y < .80
	return n.x < .34 and n.y > .24 and n.y < .73

func enemy_upper_transform(pose: Dictionary) -> Transform2D:
	var unit = float(rig_data.height) / 65.0
	var hip: Vector2 = rig_data.hip
	# Shoulder preparation/release moves the complete painted upper silhouette;
	# it is deliberately not advertised as newly drawn/separated arm frames.
	var turn = Transform2D(float(pose.lean + pose.arm * .18), Vector2.ZERO)
	turn.origin = hip - turn * hip + Vector2((pose.reach - pose.guard * .8) * unit, pose.crouch * unit)
	return turn

func deform_enemy_rig(pose: Dictionary, gait: float) -> void:
	if pose == last_rig_pose and (pose.lift == 0.0 or is_equal_approx(gait, last_rig_gait)): return
	last_rig_pose = pose.duplicate()
	last_rig_gait = gait
	var points: PackedVector2Array = rig_data.rest.duplicate()
	var unit = float(rig_data.height) / 65.0
	var upper = enemy_upper_transform(pose)
	var stride = float(pose.stride) * unit
	var lift = float(pose.lift) * unit
	var step = sin(gait)
	var walking = stride != 0.0 or lift != 0.0
	var weights: Array = rig_data.weights
	for i in range(points.size()):
		var p = points[i]
		var w: Vector4 = weights[i]
		if w.x == 1.0: p = upper * p
		elif w.x > 0.0: p = p.lerp(upper * p, w.x)
		# Opposing legs exchange support; only the swinging boot rises. No root bob.
		if walking and w.z > 0:
			var leg = w.w * 2.0 - 1.0
			p.x += stride * leg * w.z
			p.y -= maxf(0, step * leg) * lift * w.z
		points[i] = p
	rig.polygon = points
