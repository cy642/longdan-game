extends Node2D
## Lightweight, deterministic scenery motion. No physics, RNG shared with combat,
## save state, fullscreen haze, or input. The baked ground remains the base layer.
const REDRAW_STEP = 1.0 / 24.0
var world
var stage_id = ""
var clock = 0.0
var redraw_left = 0.0
var leaves: Array = []
var ripples: Array = []
var reeds: Array = []

func configure(game, region: String, tree_positions: Array, seed_value: int) -> void:
	world = game
	stage_id = region
	var random = RandomNumberGenerator.new()
	random.seed = seed_value + 10391
	# Keep foliage at the edges of existing trees, away from main combat space.
	for i in range(mini(tree_positions.size(), 14)):
		var tree: Dictionary = tree_positions[(i * 7) % tree_positions.size()]
		leaves.append({"origin":tree.pos + Vector2(-28,-28), "phase":random.randf(), "speed":random.randf_range(.045,.075), "size":random.randf_range(2.0,3.6)})
	if region == "bridge":
		for i in range(38):
			var right_bank = i >= 32
			var x = random.randf_range(1405,1560) if right_bank else random.randf_range(38,1115)
			ripples.append({"origin":Vector2(x,random.randf_range(48,263)), "phase":random.randf(), "width":random.randf_range(12,31), "right":right_bank})
		for x in range(65,1120,74): reeds.append(Vector2(x,304+sin(x*.02)*5))
		for x in range(1430,1555,74): reeds.append(Vector2(x,304+sin(x*.02)*5))
	queue_redraw()

func _process(delta: float) -> void:
	if not is_instance_valid(world) or world.mode != "playing": return
	clock += delta
	redraw_left -= delta
	if redraw_left <= 0:
		redraw_left = REDRAW_STEP
		queue_redraw()

func leaf_position(leaf: Dictionary, at_time: float) -> Vector2:
	var t = fposmod(leaf.phase + at_time * leaf.speed,1.0)
	return leaf.origin + Vector2(t*76.0, t*47.0 + sin(t*TAU*1.4 + leaf.phase*TAU)*9.0)

func river_position(ripple: Dictionary, at_time: float) -> Vector2:
	var start = 1405.0 if ripple.right else 38.0
	var width = 155.0 if ripple.right else 1077.0
	return Vector2(start + fposmod(ripple.origin.x-start+at_time*7.0,width),ripple.origin.y)

func visible_bounds() -> Rect2:
	if not is_instance_valid(world) or not is_instance_valid(world.camera): return Rect2(0,0,1600,1100)
	var extent: Vector2 = world.get_viewport_rect().size / world.camera.zoom
	return Rect2(world.camera.get_screen_center_position()-extent*.5,extent).grow(80)

func _draw() -> void:
	var bounds = visible_bounds()
	var water_light = PackedVector2Array()
	var water_shade = PackedVector2Array()
	var reed_lines = PackedVector2Array()
	for ripple in ripples:
		var p = river_position(ripple,clock)
		if not bounds.has_point(p): continue
		var pulse = .5 + .5*sin(clock*1.4+ripple.phase*TAU)
		var width = ripple.width*(.6+.4*pulse)
		# Never draw a wake across the bridge deck or on the banks.
		var limit = 1575.0 if ripple.right else 1140.0
		var end = minf(p.x+width,limit)
		water_light.append(p); water_light.append(Vector2(end,p.y-1))
		water_shade.append(p+Vector2(4,4)); water_shade.append(Vector2(maxf(p.x+4,minf(end-2,limit)),p.y+4))
	for base in reeds:
		if not bounds.has_point(base): continue
		var bend = sin(clock*1.25+base.x*.02)*3.0
		for stem in range(3):
			var root = base+Vector2(stem*3-3,0)
			var tip = root+Vector2((stem-1)*4+bend,-21-stem*4)
			var middle = root.lerp(tip,.55)+Vector2(-bend*.45,0)
			reed_lines.append(root); reed_lines.append(middle)
			reed_lines.append(middle); reed_lines.append(tip)
	# Batch same-material strokes. On software/Web renderers this avoids a
	# separate retained canvas draw for every tiny glint and reed segment.
	if not water_light.is_empty(): draw_multiline(water_light,Color(.64,.80,.70,.17),1.3,true)
	if not water_shade.is_empty(): draw_multiline(water_shade,Color(.43,.65,.61,.08),1,true)
	if not reed_lines.is_empty(): draw_multiline(reed_lines,Color(.35,.46,.31,.70),1.1,true)
	for leaf in leaves:
		var p = leaf_position(leaf,clock)
		if not bounds.has_point(p): continue
		var t = fposmod(leaf.phase+clock*leaf.speed,1.0)
		var alpha = sin(t*PI)*.54
		var angle = sin(clock*2.1+leaf.phase*TAU)*.7+.4
		var s = leaf.size
		var axis = Vector2.from_angle(angle)*s
		var cross = axis.orthogonal()*.38
		draw_colored_polygon(PackedVector2Array([p-axis,p+cross,p+axis,p-cross]),Color(.70,.69,.39,alpha))
		draw_line(p-axis*.6,p+axis*.75,Color(.86,.79,.49,alpha*.6),.7,true)
