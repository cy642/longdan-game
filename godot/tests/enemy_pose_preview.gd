extends Node2D
## Source-pixel articulation review, isolated from combat, audio and player saves.
## Space switches the contact sheet/live sequence. Left/right mirror the poses.
const Enemy = preload("res://scripts/enemy.gd")
const UNITS = [["sword", "", "Swordsman"], ["spear", "", "Spearman"], ["archer", "", "Archer"], ["shield", "", "Shield"], ["elite", "", "Captain"], ["boss", "xiahou", "Xiahou En"], ["boss", "zhanghe", "Zhang He"]]
const PHASES = ["Guard", "Stride", "Anticipate", "Release", "Follow-through", "Recover", "Hit", "Fall"]
var attacks: Dictionary
var sheet: Node2D
var live: Node2D
var live_units: Array = []
var sample_units: Array = []
var clock = 0.0
var face = 0.0
var animated = false
var state = {"flags":{"adou":false}}
var font: Font
var caption: Label

func _ready() -> void:
	RenderingServer.set_default_clear_color(Color("263e3b"))
	attacks = JSON.parse_string(FileAccess.get_file_as_string("res://data/chapter1.json")).AttackDefinition
	font = ThemeDB.fallback_font
	label_at("Enemy action study  |  original atlas pixels + articulated interpolation", Vector2(18, 13), 23)
	label_at("Space: live / sheet     Left / Right: facing     R: restart     No combat or save writes", Vector2(18, 44), 15)
	sheet = Node2D.new(); add_child(sheet)
	live = Node2D.new(); add_child(live); live.hide()
	for column in range(PHASES.size()): label_at(PHASES[column], Vector2(142 + column * 141, 73), 14, sheet)
	for row in range(UNITS.size()):
		var unit = UNITS[row]
		label_at(unit[2], Vector2(15, 115 + row * 86), 15, sheet)
		for column in range(PHASES.size()):
			var enemy = make_enemy(unit, Vector2(183 + column * 141, 166 + row * 86), sheet)
			sample_units.append(enemy)
			sample(enemy, column)
		var enemy = make_enemy(unit, Vector2(110 + row * 170, 363), live)
		enemy.scale = Vector2.ONE * 1.7
		live_units.append(enemy)
		label_at(unit[2], enemy.position + Vector2(-60, 69), 18, live)
	caption = label_at("", Vector2(42, 495), 23, live)
	label_at("A planted origin stays on each cross. Stride uses opposite legs; attack and recoil bend the upper body.", Vector2(42, 555), 17, live)
	label_at("All windup / active / recovery durations are the unchanged production definitions.", Vector2(42, 588), 17, live)
	queue_redraw()

func label_at(text: String, p: Vector2, size: int, parent: Node = self) -> Label:
	var label = Label.new(); label.text = text; label.position = p
	label.add_theme_font_override("font", font); label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", Color("e4ddbd"))
	parent.add_child(label)
	return label

func make_enemy(unit: Array, p: Vector2, parent: Node):
	var enemy = Enemy.new(); enemy.world = self; enemy.kind = unit[0]; enemy.boss_id = unit[1]
	enemy.hp = 100; enemy.position = p; enemy.facing = face
	parent.add_child(enemy)
	return enemy

func definition(enemy) -> Dictionary:
	if enemy.kind == "boss": return Enemy.BOSS_MOVES[enemy.boss_id][0][0]
	return attacks["arrow" if enemy.kind == "archer" else "spear" if enemy.kind == "spear" else "shield" if enemy.kind in ["shield", "elite"] else "cut"]

func action_at(enemy, t: float) -> void:
	enemy.action = {"id":1, "key":"enemy", "dir":enemy.facing, "t":t, "def":definition(enemy)}

func reset_sample(enemy) -> void:
	enemy.hp = 100; enemy.dead_time = 0; enemy.stun = 0; enemy.hurt_flash = 0
	enemy.moving = false; enemy.action = {}; enemy.facing = face
	enemy.visual.death_start = -1; enemy.visual.reaction_start = -10
	enemy.visual.last_action_id = -1; enemy.visual.move_blend = 0
	enemy.visual.displayed_pose = enemy.visual.neutral_pose()
	enemy.visual.action_entry_pose = enemy.visual.neutral_pose()

func sample(enemy, column: int) -> void:
	reset_sample(enemy)
	var d = definition(enemy)
	match column:
		1:
			enemy.moving = true; enemy.walk_distance = 18
			enemy.visual.move_blend = 1.0
		2: action_at(enemy, d.windup * .9)
		3: action_at(enemy, d.windup + d.active * .42)
		4: action_at(enemy, d.windup + d.active)
		5: action_at(enemy, d.windup + d.active + d.recovery * .62)
		6:
			enemy.visual.react_to_hit(PI, false, false)
			enemy.visual.advance_time(.09); enemy.hurt_flash = .05
		7:
			enemy.visual.react_to_hit(0, false, true)
			enemy.hp = 0; enemy.dead_time = .4
	enemy.update_visual()

func show_live(value: bool) -> void:
	animated = value; sheet.visible = not value; live.visible = value
	clock = 0; queue_redraw()

func sample_live(time: float) -> void:
	for enemy in live_units:
		reset_sample(enemy)
		var d = definition(enemy)
		var action_start = 1.05
		var action_end = action_start + d.windup + d.active + d.recovery
		var loop_end = 6.5
		var t = fposmod(time, loop_end)
		if t < action_start:
			enemy.moving = true; enemy.walk_distance = t * 95
			enemy.visual.move_blend = minf(t * 8, 1)
		elif t < action_end:
			action_at(enemy, t - action_start)
		elif t < action_end + .45:
			enemy.visual.react_to_hit(PI, false, false)
			enemy.visual.advance_time(t - action_end)
			enemy.stun = maxf(0, .3 - (t - action_end))
		elif t > 4.65:
			enemy.visual.react_to_hit(0, false, true)
			enemy.hp = 0; enemy.dead_time = t - 4.65
		enemy.update_visual()
	caption.text = "Continuous loop: approach -> anticipation -> strike -> recovery -> hit -> fall  |  %.2f s" % fposmod(time, 6.5)

func _process(dt: float) -> void:
	if animated:
		clock += dt
		sample_live(clock)

func _unhandled_key_input(event: InputEvent) -> void:
	if not event.is_pressed() or event.is_echo(): return
	if event.keycode == KEY_SPACE: show_live(not animated)
	if event.keycode == KEY_R: clock = 0
	if event.keycode in [KEY_LEFT, KEY_RIGHT]:
		face = PI if event.keycode == KEY_LEFT else 0.0
		for i in range(sample_units.size()): sample(sample_units[i], i % PHASES.size())

func _draw() -> void:
	var color = Color(.72, .86, .68, .25)
	var points: Array = []
	if animated:
		for enemy in live_units: points.append(enemy.position)
	else:
		for enemy in sample_units: points.append(enemy.position)
	for p in points:
		draw_line(p + Vector2(-48,0),p + Vector2(48,0),color,1)
		draw_line(p + Vector2(0,-5),p + Vector2(0,5),color,1)
