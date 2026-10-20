extends Node2D
## Visual review of production sprites, using no combat or player save.
const Hero = preload("res://scripts/hero.gd")
const ROWS = ["Idle", "Walk", "Windup", "Strike", "Recovery", "Fallen"]
var state = {"flags": {"adou": false}}
var samples: Array = []

func _ready() -> void:
	RenderingServer.set_default_clear_color(Color("304b46"))
	var font = load("res://assets/fonts/NotoSansSC-Regular.otf")
	var directions = ["E", "SE", "S", "SW", "W", "NW", "N", "NE"]
	for row in range(ROWS.size()):
		for direction in range(8):
			var hero = Hero.new(); hero.world = self; hero.hp = 200
			hero.position = Vector2(82 + direction * 158, 150 + row * 174)
			hero.scale = Vector2.ONE * 1.35; hero.facing = direction * PI / 4
			hero.moving = row == 1; hero.walk_distance = hero.HERO_STEP_DISTANCE + 1 if row == 1 else 0
			if row in [2,3,4]:
				hero.action = {"key": "thrust1", "dir": hero.facing, "t": .06 if row == 2 else .46 if row == 4 else .2, "def": {"windup": .13, "active": .15, "recovery": .2}}
			if row == 5: hero.hp = 0
			add_child(hero); hero.update_visual()
			samples.append(hero)
			var label = Label.new(); label.position = hero.position + Vector2(-62, 14)
			label.size.x = 124; label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			label.add_theme_font_override("font", font); label.add_theme_font_size_override("font_size", 15)
			label.text = ROWS[row] + " · " + directions[direction]
			add_child(label)
	queue_redraw()

func _draw() -> void:
	for row in range(ROWS.size()):
		for direction in range(8):
			var p = Vector2(82 + direction * 158, 150 + row * 174)
			draw_line(p + Vector2(-55, 0), p + Vector2(55, 0), Color(.7, .86, .65, .25), 1)
			draw_line(p + Vector2(0, -5), p + Vector2(0, 5), Color(.7, .86, .65, .25), 1)
			draw_line(p + Vector2(-55, -135), p + Vector2(55, -135), Color(.7, .86, .65, .12), 1)
