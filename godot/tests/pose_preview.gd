extends Node2D
## Visual review of production sprites, using no combat or player save.
const Hero = preload("res://scripts/hero.gd")
var state = {"flags": {"adou": false}}

func _ready() -> void:
	RenderingServer.set_default_clear_color(Color("304b46"))
	var font = load("res://assets/fonts/NotoSansSC-Regular.otf")
	var directions = ["E", "SE", "S", "SW", "W", "NW", "N", "NE"]
	for row in range(4):
		for direction in range(8):
			var hero = Hero.new(); hero.world = self; hero.hp = 200
			hero.position = Vector2(90 + direction * 158, 170 + row * 172)
			hero.scale = Vector2.ONE * 1.35; hero.facing = direction * PI / 4
			hero.moving = row == 1; hero.walk_distance = hero.HERO_STEP_DISTANCE + 1 if row == 1 else 0
			if row >= 2:
				hero.action = {"key": "thrust1", "dir": hero.facing, "t": .06 if row == 2 else .2, "def": {"windup": .13, "active": .15, "recovery": .2}}
			add_child(hero); hero.update_visual()
			var label = Label.new(); label.position = hero.position + Vector2(-62, 14)
			label.size.x = 124; label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			label.add_theme_font_override("font", font); label.add_theme_font_size_override("font_size", 15)
			label.text = ["Idle", "Walk", "Windup", "Strike"][row] + " · " + directions[direction]
			add_child(label)
	queue_redraw()

func _draw() -> void:
	for row in range(4):
		for direction in range(8):
			var p = Vector2(90 + direction * 158, 170 + row * 172)
			draw_line(p + Vector2(-55, 0), p + Vector2(55, 0), Color(.7, .86, .65, .25), 1)
			draw_line(p + Vector2(0, -5), p + Vector2(0, 5), Color(.7, .86, .65, .25), 1)
