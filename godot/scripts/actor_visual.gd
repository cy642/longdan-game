extends Node2D
## Atlas regions use a stable head scale and boot anchor in every direction.
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

static func prepare() -> void:
	if not frames.is_empty(): return
	atlas_data = JSON.parse_string(FileAccess.get_file_as_string("res://data/atlas.json"))
	for key in atlas_data:
		var atlas = load(atlas_data[key].file)
		var textures: Array = []
		for frame in atlas_data[key].frames:
			var texture = AtlasTexture.new(); texture.atlas = atlas
			var r = frame.region; texture.region = Rect2(r[0], r[1], r[2], r[3]); texture.filter_clip = true
			textures.append(texture)
		frames[key] = textures

func _ready() -> void:
	prepare()
	body = Sprite2D.new(); body.centered = false
	add_child(body); update_pose()

func set_frame(key: String, index: int, flip: bool, hero: bool, height: float = 62) -> void:
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
			var progress = clampf((a.t - def.windup) / def.active, 0, 1)
			var settle = 1 - clampf((a.t - def.windup - def.active) / def.recovery, 0, 1)
			position = Vector2.from_angle(a.dir) * sin(progress * PI * .5) * 5 * settle
			if a.key in ["sweep", "sword", "thrust2"]:
				rotation = sin(a.t / (def.windup + def.active + def.recovery) * TAU) * .065
		else:
			var step = int(actor.walk_distance / 32) % 2 if actor.moving else 0
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
		if actor.hp <= 0:
			rotation = -.95; position.y = 5; modulate.a = maxf(0, .28 * (1 - actor.dead_time / 10))
		elif not actor.action.is_empty():
			var a = actor.action; var def = a.def
			var pull = clampf(a.t / def.windup, 0, 1)
			var active = a.t >= def.windup and a.t < def.windup + def.active
			var settle = 1 - clampf((a.t - def.windup - def.active) / def.recovery, 0, 1)
			position = -Vector2.from_angle(a.dir) * 7 * pull if a.t < def.windup else Vector2.from_angle(a.dir) * 10 * settle
			rotation = -.12 * pull if a.t < def.windup else .16 * settle
			scale = Vector2(1.04, .96) if a.t < def.windup else Vector2(.97, 1.03) if active else Vector2.ONE
		elif actor.moving:
			rotation = sin(actor.walk_distance / 18) * .035
			# Foot cadence is proportional to distance, with minimal vertical motion.
			position.y = -absf(sin(actor.walk_distance / 20)) * .7
		elif actor.stun > .2:
			rotation = sin(Time.get_ticks_msec() * .016) * .07
	if actor.hurt_flash > 0: modulate = Color(1.4, 1.2, 1.0, .85)
	queue_redraw()

func _draw() -> void:
	if actor == null: return
	if actor.faction == "hero" and actor.world.state.flags.adou:
		draw_circle(Vector2(-13, -34), 5, Color("f4ddbc"))
		draw_circle(Vector2(-13, -39), 3, Color("f2c9a5"))
