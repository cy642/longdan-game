extends RefCounted
## Cut neighboring atlas fragments out of drawing geometry, keeping original pixels.

static func create(atlas: Texture2D, meta: Dictionary) -> Texture2D:
	var r = meta.region
	var exclusions: Array = meta.get("exclude", [])
	if exclusions.is_empty():
		var texture = AtlasTexture.new()
		texture.atlas = atlas; texture.region = Rect2(r[0], r[1], r[2], r[3])
		texture.filter_clip = true
		return texture
	var xs: Array = [0.0, float(r[2])]
	var ys: Array = [0.0, float(r[3])]
	var holes: Array[Rect2] = []
	for e in exclusions:
		var hole = Rect2(e[0], e[1], e[2], e[3])
		holes.append(hole)
		for x in [hole.position.x, hole.end.x]:
			if not xs.has(x): xs.append(x)
		for y in [hole.position.y, hole.end.y]:
			if not ys.has(y): ys.append(y)
	xs.sort(); ys.sort()
	var vertices = PackedVector2Array()
	var uv = PackedVector2Array()
	var indices = PackedInt32Array()
	var origin = Vector2(r[0], r[1])
	for y in range(ys.size() - 1):
		for x in range(xs.size() - 1):
			var midpoint = Vector2((xs[x] + xs[x+1]) * .5, (ys[y] + ys[y+1]) * .5)
			var clipped = false
			for hole in holes:
				if hole.has_point(midpoint): clipped = true; break
			if clipped: continue
			var first = vertices.size()
			for point in [Vector2(xs[x], ys[y]), Vector2(xs[x+1], ys[y]), Vector2(xs[x+1], ys[y+1]), Vector2(xs[x], ys[y+1])]:
				vertices.append(point); uv.append((origin + point) / atlas.get_size())
			indices.append_array(PackedInt32Array([first, first+1, first+2, first, first+2, first+3]))
	var arrays: Array = []; arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices; arrays[Mesh.ARRAY_TEX_UV] = uv; arrays[Mesh.ARRAY_INDEX] = indices
	var mesh = ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var texture = MeshTexture.new()
	texture.base_texture = atlas; texture.image_size = Vector2(r[2], r[3]); texture.mesh = mesh
	return texture
