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
var drift: Array = []
var theme = "changban_dust"
var leaf_color = Color("b4a568")
var reed_color = Color(.35,.46,.31,.70)
var water_color = Color(.64,.80,.70,.17)

func configure(game, region: String, tree_positions: Array, seed_value: int) -> void:
	world = game
	stage_id = region
	leaves.clear(); ripples.clear(); reeds.clear(); drift.clear()
	clock = 0.0; redraw_left = 0.0
	theme = "hanshui_mist" if region.begins_with("hs_") else "changban_dust"
	var hanshui = theme == "hanshui_mist"
	leaf_color = Color("8baaa1") if hanshui else Color("b4a568")
	reed_color = Color(.36,.52,.47,.76) if hanshui else Color(.35,.46,.31,.70)
	water_color = Color(.64,.82,.83,.26) if hanshui else Color(.64,.80,.70,.17)
	var random = RandomNumberGenerator.new()
	random.seed = seed_value + 10391
	# Keep foliage at the edges of existing trees, away from main combat space.
	for i in range(mini(tree_positions.size(), 8 if hanshui else 14)):
		var tree: Dictionary = tree_positions[(i * 7) % tree_positions.size()]
		leaves.append({"origin":tree.pos + Vector2(-28,-28), "phase":random.randf(), "speed":random.randf_range(.045,.075), "size":random.randf_range(2.0,3.6)})
	if hanshui:
		# Bamboo sheds narrow blue-green leaves; it must not reuse Changban's
		# ochre foliage just because the underlying terrain mood is "forest".
		for prop in world.definition.get("layout",{}).get("decor",[]):
			if prop.kind != "bamboo" or leaves.size() >= 14: continue
			var p = prop.position
			leaves.append({"origin":Vector2(p[0],p[1]-float(prop.get("size",90))*.65), "phase":random.randf(), "speed":random.randf_range(.045,.075), "size":4.0})
		_configure_hanshui_water(random)
	if region == "bridge":
		for i in range(38):
			var right_bank = i >= 32
			var x = random.randf_range(1405,1560) if right_bank else random.randf_range(38,1115)
			ripples.append({"origin":Vector2(x,random.randf_range(48,263)), "phase":random.randf(), "width":random.randf_range(12,31), "right":right_bank})
		for x in range(65,1120,74): reeds.append(Vector2(x,304+sin(x*.02)*5))
		for x in range(1430,1555,74): reeds.append(Vector2(x,304+sin(x*.02)*5))
	# Small local strokes only: no fullscreen tint, particle emitter or extra
	# transparent texture. These sit beneath actors and combat telegraphs.
	var drift_count = 12 if hanshui else (18 if region in ["village","house","fork"] else 10)
	for i in range(drift_count):
		var origin = Vector2(random.randf_range(85,1460),random.randf_range(95,1005))
		if tree_positions.size()>0 and i<mini(tree_positions.size(),6):
			origin=tree_positions[i].pos+Vector2(-35,18)
		drift.append({"origin":origin,"phase":random.randf(),"speed":random.randf_range(.025,.045),"width":random.randf_range(24,46) if hanshui else random.randf_range(2,5)})
	queue_redraw()

func _configure_hanshui_water(random: RandomNumberGenerator) -> void:
	for bounds in world.definition.get("layout",{}).get("water",[]):
		var area = Rect2(bounds[0],bounds[1],bounds[2],bounds[3])
		# Derive every animated wake from the same rectangle as water collision.
		# In particular hs_river has both a bottom shore and a narrow right shore.
		var inset = area.grow(-12)
		var count = mini(24,maxi(8,int(area.get_area()/10000.0)))
		for i in range(count):
			ripples.append({"origin":Vector2(random.randf_range(inset.position.x,inset.end.x),random.randf_range(inset.position.y,inset.end.y)), "area":inset, "phase":random.randf(), "width":random.randf_range(12,29), "right":false})
		if area.size.x > area.size.y:
			var y = area.position.y-4 if area.position.y>100 else area.end.y+15
			for x in range(int(area.position.x)+25,int(area.end.x)-16,86):
				if reeds.size()<32: reeds.append(Vector2(x,y))
		else:
			for y in range(int(area.position.y)+30,int(area.end.y)-16,100):
				if reeds.size()<32: reeds.append(Vector2(area.position.x-9,y))

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
	if ripple.has("area"):
		var area: Rect2 = ripple.area
		return Vector2(area.position.x+fposmod(ripple.origin.x-area.position.x+at_time*6.0,area.size.x),ripple.origin.y)
	var start = 1405.0 if ripple.right else 38.0
	var width = 155.0 if ripple.right else 1077.0
	return Vector2(start + fposmod(ripple.origin.x-start+at_time*7.0,width),ripple.origin.y)

func drift_position(mote: Dictionary, at_time: float) -> Vector2:
	var t = fposmod(mote.phase+at_time*mote.speed,1.0)
	return mote.origin+Vector2(t*88.0,sin(t*PI)*5.0 if theme=="hanshui_mist" else -t*42.0)

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
		var limit = ripple.area.end.x if ripple.has("area") else (1575.0 if ripple.right else 1140.0)
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
	if not water_light.is_empty(): draw_multiline(water_light,water_color,1.3,true)
	if not water_shade.is_empty(): draw_multiline(water_shade,Color(.43,.65,.61,.08),1,true)
	if not reed_lines.is_empty(): draw_multiline(reed_lines,reed_color,1.1,true)
	var drift_lines = PackedVector2Array()
	for mote in drift:
		var p = drift_position(mote,clock)
		if not bounds.has_point(p): continue
		var t = fposmod(mote.phase+clock*mote.speed,1.0)
		var span = float(mote.width)*sin(t*PI)
		if span<.35: continue
		drift_lines.append(p); drift_lines.append(p+Vector2(span,-.9 if theme=="hanshui_mist" else -span*.35))
	if not drift_lines.is_empty():
		draw_multiline(drift_lines,Color(.71,.85,.84,.16) if theme=="hanshui_mist" else Color(.67,.55,.37,.34),2.2 if theme=="hanshui_mist" else 1.2,true)
	for leaf in leaves:
		var p = leaf_position(leaf,clock)
		if not bounds.has_point(p): continue
		var t = fposmod(leaf.phase+clock*leaf.speed,1.0)
		var alpha = sin(t*PI)*.54
		var angle = sin(clock*2.1+leaf.phase*TAU)*.7+.4
		var s = leaf.size
		var axis = Vector2.from_angle(angle)*s
		var cross = axis.orthogonal()*(.19 if theme=="hanshui_mist" else .38)
		draw_colored_polygon(PackedVector2Array([p-axis,p+cross,p+axis,p-cross]),Color(leaf_color,alpha))
		draw_line(p-axis*.6,p+axis*.75,Color(leaf_color.lightened(.18),alpha*.6),.7,true)
