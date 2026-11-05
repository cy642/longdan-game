extends Control

signal primary_pressed
signal secondary_pressed
signal sound_pressed

const TEXT := preload("res://art/ui/longdan-sans.otf")
const DISPLAY := preload("res://art/ui/longdan-serif.otf")
const PAPER := Color("#fff1d3")
const GOLD := Color("#edc98c")
const MUTED := Color("#d3d4bd")
const INK := Color("#152725")

var menu := Control.new()
var hud := Control.new()
var chapter: Label
var title: Label
var story: Label
var primary: Button
var secondary: Button
var sound: Button
var menu_footer: Label
var objective: Label
var location: Label
var vital: ColorRect
var hp_value: Label
var threat: Control
var foe_name: Label
var foe_bar: ColorRect
var feedback: Label
var marker: Label
var ability_title: Label
var ability_fill: ColorRect
var return_tip: Label
var last_hp := 1.0

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for part in [hud, menu]:
		add_child(part)
		part.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		part.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build_hud()
	_build_menu()

func _label(parent: Control, value: String, at: Vector2, size_px: int, color: Color, display := false) -> Label:
	var label := Label.new()
	label.text = value
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_override("font", DISPLAY if display else TEXT)
	label.add_theme_font_size_override("font_size", size_px)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_shadow_color", Color(0.035,0.06,0.06,0.76))
	label.add_theme_constant_override("shadow_offset_x", 1)
	label.add_theme_constant_override("shadow_offset_y", 2)
	parent.add_child(label)
	label.position = at
	return label

func _rect(parent: Control, at: Vector2, extent: Vector2, tint: Color) -> ColorRect:
	var item := ColorRect.new()
	parent.add_child(item)
	item.mouse_filter = Control.MOUSE_FILTER_IGNORE
	item.position = at
	item.size = extent
	item.color = tint
	return item

func _wash(parent: Control, at: Vector2, extent: Vector2, colors: PackedColorArray, vertical := false) -> void:
	var grad := Gradient.new()
	var stops := PackedFloat32Array()
	for i in colors.size():
		stops.append(float(i) / float(colors.size()-1))
	grad.offsets = stops
	grad.colors = colors
	var image := GradientTexture2D.new()
	image.gradient = grad
	image.width = 256 if not vertical else 2
	image.height = 2 if not vertical else 256
	image.fill_to = Vector2.DOWN if vertical else Vector2.RIGHT
	var band := TextureRect.new()
	band.texture = image
	band.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	band.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(band)
	band.position = at
	band.size = extent

func _button(parent: Control, at: Vector2, big: bool) -> Button:
	var button := Button.new()
	button.add_theme_font_override("font", DISPLAY if big else TEXT)
	button.add_theme_font_size_override("font_size", 23 if big else 16)
	button.add_theme_color_override("font_color", PAPER)
	button.add_theme_color_override("font_hover_color", Color.WHITE)
	button.add_theme_color_override("font_focus_color", Color.WHITE)
	for state in ["normal","hover","pressed","focus"]:
		var style := StyleBoxFlat.new()
		if state == "focus":
			style.draw_center = false
			style.border_color = Color(GOLD, 0.85)
			style.set_border_width_all(1)
		else:
			style.bg_color = Color("#813f2e") if big else Color(0.07,0.12,0.11,0.66)
			if state != "normal":
				style.bg_color = style.bg_color.lightened(0.15)
			style.border_color = Color(GOLD, 0.8 if big else 0.4)
			style.border_width_left = 3 if big else 1
			style.border_width_bottom = 1
		style.content_margin_left = 18
		style.content_margin_right = 18
		button.add_theme_stylebox_override(state, style)
	parent.add_child(button)
	button.position = at
	button.size = Vector2(216, 54) if big else Vector2(142, 40)
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	return button

func _build_menu() -> void:
	var shade := Color(0.06,0.11,0.11,0.97)
	_wash(menu, Vector2.ZERO, Vector2(790,720), PackedColorArray([shade, Color(0.06,0.11,0.11,0.85), Color(0.06,0.11,0.11,0.0)]))
	_wash(menu, Vector2(0,584), Vector2(1280,136), PackedColorArray([Color(INK,0),Color(INK,0.74)]), true)
	_rect(menu, Vector2(70,57), Vector2(4,22), Color("#c15b42"))
	_label(menu, "龙胆  /  逆命三国", Vector2(85,52),18, PAPER, true)
	chapter = _label(menu, "", Vector2(70,192), 19, GOLD)
	title = _label(menu, "", Vector2(62,215), 86, PAPER, true)
	_rect(menu, Vector2(72,349), Vector2(64,2), GOLD)
	story = _label(menu, "", Vector2(71,371), 22, PAPER)
	story.add_theme_constant_override("line_spacing", 5)
	primary = _button(menu, Vector2(72,516), true)
	primary.pressed.connect(func(): primary_pressed.emit())
	secondary = _button(menu, Vector2(72,586), false)
	secondary.pressed.connect(func(): secondary_pressed.emit())
	sound = _button(menu, Vector2(229,586), false)
	sound.pressed.connect(func(): sound_pressed.emit())
	menu_footer = _label(menu, "", Vector2(72,662), 15, MUTED)

func _build_hud() -> void:
	_wash(hud, Vector2(0,0), Vector2(1280,117), PackedColorArray([Color(INK,0.65), Color(INK,0)]), true)
	_wash(hud, Vector2(0,610), Vector2(1280,110), PackedColorArray([Color(INK,0), Color(INK,0.87)]), true)
	_rect(hud, Vector2(36,32), Vector2(3,59), GOLD)
	location = _label(hud, "", Vector2(51,27), 17, GOLD, true)
	objective = _label(hud, "", Vector2(50,54), 21, PAPER)
	_label(hud, "赵 云", Vector2(39,609), 27, PAPER, true)
	hp_value = _label(hud, "", Vector2(138,626), 14, MUTED)
	_rect(hud, Vector2(42,662), Vector2(206,9), Color(0.08,0.12,0.12,0.95))
	vital = _rect(hud, Vector2(45,664), Vector2(200,5), Color("#e4bd77"))
	_label(hud, "J  出枪     K  破阵     空格  闪身", Vector2(42,678), 14, MUTED)
	_rect(hud,Vector2(291,643),Vector2(1,43),Color(GOLD,.56))
	ability_title = _label(hud,"",Vector2(311,641),17,PAPER,true)
	_rect(hud,Vector2(312,678),Vector2(143,3),Color(INK,.83))
	ability_fill = _rect(hud,Vector2(312,678),Vector2(143,3),Color("#9ed7dd"))
	return_tip = _label(hud,"J  回马枪",Vector2(483,642),19,GOLD,true)
	_label(hud, "WASD  移动     右键拖动 / ← →  转镜头     Esc  暂停", Vector2(846,674), 15, PAPER)
	threat = Control.new()
	hud.add_child(threat)
	threat.position = Vector2(889,38)
	threat.mouse_filter = Control.MOUSE_FILTER_IGNORE
	foe_name = _label(threat, "", Vector2.ZERO,19,PAPER,true)
	foe_name.size.x = 344
	foe_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_rect(threat, Vector2(113,39), Vector2(231,6), Color(INK,0.85))
	foe_bar = _rect(threat, Vector2(114,40), Vector2(229,4), Color("#d48769"))
	feedback = _label(hud,"",Vector2(300,595),20,PAPER,true)
	feedback.size.x = 680
	feedback.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	marker = _label(hud, "◇", Vector2.ZERO, 23, GOLD)
	marker.add_theme_constant_override("outline_size", 3)
	marker.add_theme_color_override("font_outline_color", Color(INK,0.85))

func show_mode(mode: String, muted: bool) -> void:
	menu.visible = mode != "play"
	hud.visible = mode == "play"
	secondary.visible = mode == "pause" or mode == "won" or mode == "lost"
	sound.visible = mode == "pause"
	sound.text = "声音  ·  关" if muted else "声音  ·  开"
	menu_footer.text = "WASD  移动     J  出枪     K  重击     R  游龙回锋     空格  闪身     E  接应"
	match mode:
		"title":
			chapter.text = "荆州  /  建安十三年"
			title.text = "长坂坡"
			story.text = "尘烟里传来一声婴啼。\n赵云循声折返，村外已是曹军的枪阵。"
			primary.text = "开始游戏"
		"pause":
			chapter.text = "长坂坡  /  战中小憩"
			title.text = "暂歇"
			story.text = "按 R 横扫破盾，再送出第二枪。\n贴着敌锋闪身，按 J 可接回马枪。"
			primary.text = "继续战斗"
			secondary.text = "重新出战"
		"won":
			chapter.text = "第一关  /  渡口"
			title.text = "长坂破围"
			story.text = "阿斗在襁褓里睡着了，乡民也到了北岸。\n桥那头的喊杀声，终于远了。"
			primary.text = "再战长坂"
			secondary.text = "返回标题"
		"lost":
			chapter.text = "第一关  /  长坂坡"
			title.text = "力竭"
			story.text = "枪阵仍有破绽。\n侧闪避开枪尖，重击撬开盾面。"
			primary.text = "重新出战"
			secondary.text = "返回标题"
	if menu.visible:
		primary.grab_focus()

func update_battle(battle, camera: Camera3D, dt: float) -> void:
	location.text = ["长坂坡  /  山道","长坂坡  /  残村","长坂坡  /  渡桥","长坂坡  /  北岸","长坂坡"][clampi(battle.stage,0,4)]
	objective.text = battle.objective_text()
	feedback.text = battle.status_text()
	hp_value.text = "%d / %d" % [ceili(battle.hp), ceili(battle.hp_max)]
	last_hp = lerpf(last_hp, clampf(battle.hp / battle.hp_max,0.0,1.0), 1.0-exp(-12.0*dt))
	vital.size.x = 200.0 * last_hp
	var cooldown: float = battle.dragon_cooldown
	ability_title.text = "R  游龙回锋" if cooldown <= 0.0 else "游龙回锋  %.1f 秒" % cooldown
	ability_title.modulate = Color.WHITE if cooldown <= 0.0 else Color("#c6c4ad")
	ability_fill.size.x = 143 * clampf(1.0 - cooldown / battle.DRAGON_RECHARGE,0.0,1.0)
	return_tip.visible = battle.riposte_window > 0.0
	var foe: Dictionary = battle.enemy_status()
	threat.visible = not foe.is_empty()
	if threat.visible:
		foe_name.text = foe["name"]
		foe_bar.size.x = 229.0 * clampf(float(foe["health"]) / float(foe["max_health"]),0.0,1.0)
	var target: Vector3 = battle.objective_position()
	target.y += 2.8
	marker.visible = battle.stage in [1,3] and not camera.is_position_behind(target)
	if marker.visible:
		var projected := camera.unproject_position(target)
		marker.visible = Rect2(65,95,1150,480).has_point(projected)
		marker.position = projected - Vector2(12,19)
