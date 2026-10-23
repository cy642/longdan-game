extends RefCounted

const MANIFEST_PATH = "res://art_source/painted/props-manifest.json"
const ALPHA_FLOOR = 4.0 / 255.0
static var loaded = false
static var available = false
static var frames: Dictionary = {}
static var sheets: Dictionary = {}
static var textures: Dictionary = {}

static func _load_sources() -> bool:
	if loaded: return available
	loaded = true
	var path = ProjectSettings.globalize_path(MANIFEST_PATH)
	if not FileAccess.file_exists(path):
		push_error("Painted prop manifest is missing: " + path)
		return false
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not parsed is Dictionary or int(parsed.get("version", 0)) != 1:
		push_error("Painted prop manifest is invalid")
		return false
	frames = parsed.get("frames", {})
	for name in parsed.get("sheets", {}):
		var image = Image.new()
		var source = ProjectSettings.globalize_path(str(parsed.sheets[name]))
		if image.load(source) != OK:
			push_error("Painted prop source is missing: " + source)
			return false
		image.convert(Image.FORMAT_RGBA8)
		sheets[name] = image
	available = not frames.is_empty() and not sheets.is_empty()
	return available

static func _frame_texture(key: String) -> Texture2D:
	if textures.has(key): return textures[key]
	if not _load_sources() or not frames.has(key): return null
	var frame: Dictionary = frames[key]
	var image: Image = sheets.get(str(frame.get("sheet", "")))
	if image == null: return null
	var box: Array = frame.source_rect
	var left = int(box[0]); var top = int(box[1]); var width = int(box[2]); var height = int(box[3])
	var seed: Array = frame.source_seed
	var seed_x = int(seed[0]) - left; var seed_y = int(seed[1]) - top
	if left < 0 or top < 0 or width <= 0 or height <= 0 or left + width > image.get_width() or top + height > image.get_height() or seed_x < 0 or seed_x >= width or seed_y < 0 or seed_y >= height:
		push_error("Painted prop crop is outside its source: " + key)
		return null
	var count = width * height
	var mask = PackedByteArray(); mask.resize(count)
	for y in range(height):
		for x in range(width):
			if image.get_pixel(left + x, top + y).a >= ALPHA_FLOOR: mask[y * width + x] = 1
	var start = seed_y * width + seed_x
	if mask[start] == 0:
		push_error("Painted prop component seed is transparent: " + key)
		return null
	var visited = PackedByteArray(); visited.resize(count)
	var queue = PackedInt32Array(); queue.resize(count)
	var first = 0; var last = 1
	queue[0] = start; visited[start] = 1
	var isolated = Image.create_empty(width, height, false, Image.FORMAT_RGBA8)
	isolated.fill(Color.TRANSPARENT)
	while first < last:
		var index = queue[first]; first += 1
		var x = index % width; var y = int(index / width)
		isolated.set_pixel(x, y, image.get_pixel(left + x, top + y))
		for ny in range(maxi(0, y - 1), mini(height - 1, y + 1) + 1):
			for nx in range(maxi(0, x - 1), mini(width - 1, x + 1) + 1):
				var neighbour = ny * width + nx
				if mask[neighbour] == 0 or visited[neighbour] != 0: continue
				visited[neighbour] = 1; queue[last] = neighbour; last += 1
	if last < 1000:
		push_error("Painted prop component is unexpectedly small: " + key)
		return null
	var texture = ImageTexture.create_from_image(isolated)
	textures[key] = texture
	return texture

static func _paint(canvas: Node2D, key: String, target_width: float, target_foot: Vector2, variant: int = 0, tint: Color = Color.WHITE) -> bool:
	var texture = _frame_texture(key)
	if texture == null: return false
	var frame: Dictionary = frames[key]
	var base_width = float(frame.source_footprint_width)
	if base_width <= 0 or target_width <= 0: return false
	var scales = [1.0, .96, 1.04, .99]
	var turns = [0.0, .016, -.018, .012]
	var index = posmod(variant, 4)
	var scale = target_width / base_width * float(scales[index])
	var facing = -1.0 if index in [1, 3] else 1.0
	var foot = Vector2(frame.source_foot[0], frame.source_foot[1])
	canvas.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	canvas.draw_set_transform(target_foot, float(turns[index]), Vector2(facing * scale, scale))
	canvas.draw_texture_rect(texture, Rect2(-foot, texture.get_size()), false, tint)
	canvas.draw_set_transform(Vector2.ZERO)
	return true

static func draw_named(canvas: Node2D, id: String, target_foot: Vector2, footprint_width: float, tint: Color = Color.WHITE) -> bool:
	return _paint(canvas, id, footprint_width, target_foot, 0, tint)

static func draw_scenery(canvas: Node2D, data: Dictionary) -> bool:
	if data.get("kind", "") == "tree" and data.has("species"):
		var species = str(data.species)
		if not frames.has(species) and not _load_sources(): return false
		if not frames.has(species): return false
		return _paint(canvas, species, float(frames[species].target_footprint_width), Vector2.ZERO, int(data.seed))
	if data.get("kind", "") == "rock":
		return _paint(canvas, "small_rock", float(data.size) * 2.0, Vector2.ZERO, int(data.get("paint_variant", 0)))
	var kind = str(data.get("kind", "")); var stage = str(data.get("style_id", ""))
	var key = ""
	if kind == "hut": key = "intact_house"
	elif kind == "ruin": key = "temple_hall" if stage == "temple" else "damaged_house"
	elif kind == "tent": key = "tent_blue" if stage in ["hs_camp", "hs_final"] else "tent_warm"
	if key.is_empty(): return false
	return _paint(canvas, key, float(data.w), Vector2(0, float(data.h) * .5))

static func draw_hanshui(canvas: Node2D, item: Dictionary) -> bool:
	var kind = str(item.get("kind", ""))
	if kind == "bamboo":
		return _paint(canvas, "bamboo", float(item.get("size", 90)) * 98.0 / 90.0, Vector2.ZERO)
	if not item.has("rect"): return false
	var width = float(item.rect[2])
	if kind == "rockwall": return _paint(canvas, "ridge_wide" if width >= 230 else "ridge_short", width, Vector2.ZERO)
	if kind == "lowwall": return _lowwall(canvas, width, float(item.rect[3]))
	if kind == "grainstack": return _paint(canvas, "grain_rack", width, Vector2.ZERO)
	if kind == "boatframe": return _paint(canvas, "boatframe", width, Vector2.ZERO)
	if kind == "palisade": return _palisade(canvas, width, float(item.rect[3]))
	return false

static func _lowwall(canvas: Node2D, width: float, height: float) -> bool:
	if _frame_texture("ridge_short") == null: return false
	if width >= height:
		return _paint(canvas, "ridge_short", width, Vector2.ZERO)
	# A north-south low wall uses three overlapping stones along the original
	# solid strip. Each painted contact stays inside its old rectangular anchor.
	var segments = 3
	for index in range(segments):
		var foot = Vector2(-3.0 if index % 2 == 0 else 3.0, -height + height * float(index + 1) / segments)
		_paint(canvas, "ridge_short", width * 1.04, foot, index)
	return true

static func _palisade(canvas: Node2D, width: float, height: float) -> bool:
	if width > height:
		if _frame_texture("palisade_strip") == null: return false
		var count = maxi(1, ceili(width / 115.0))
		var step = width / count
		for index in range(count):
			var foot = Vector2(-width * .5 + step * (index + .5), 0)
			draw_named(canvas, "palisade_strip", foot, step * 1.05)
	else:
		if _frame_texture("single_stake") == null: return false
		# The north-south stockade occupies a real solid strip. Keep its visual
		# fill inside that footprint instead of leaving a transparent lane between
		# two isolated posts; the painted logs provide the detailed outer surface.
		canvas.draw_rect(Rect2(-width * .5, -height, width, height), Color("48372b"))
		var columns = 5
		var rows = maxi(2, ceili((height - 45.0) / 29.0) + 1)
		var first_y = -height + 42.0
		for row in range(rows):
			var y = lerpf(first_y, -10.0, float(row) / float(rows - 1))
			for column in range(columns):
				var x = -width * .5 + width * (float(column) + .5) / columns
				var stagger = 5.0 if column % 2 else 0.0
				draw_named(canvas, "single_stake", Vector2(x, y + stagger), width / columns * 1.35)
		# Tied crossbeams bind the staggered timbers into one substantial wall.
		for row in range(maxi(1, ceili(height / 76.0))):
			var y = -height + 49.0 + row * 76.0
			if y > -18.0: break
			canvas.draw_line(Vector2(-width * .5 + 5, y), Vector2(width * .5 - 5, y + 2), Color("594331"), 7.0, true)
			canvas.draw_line(Vector2(-width * .5 + 6, y - 2), Vector2(width * .5 - 6, y), Color("bd9769", .62), 1.6, true)
	return true
