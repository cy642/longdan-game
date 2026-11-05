extends RefCounted

# Each articulated part becomes one vertex-painted surface. Instances of the
# same character share all meshes and the material, including their weapons.
var vertices := PackedVector3Array()
var normals := PackedVector3Array()
var colors := PackedColorArray()
static var paint: StandardMaterial3D
var inked := false
var textured_positions := PackedVector3Array()
var textured_normals := PackedVector3Array()
var textured_uv := PackedVector2Array()
var textured_tint := PackedColorArray()
static var illustrated: StandardMaterial3D
static var ink_material: StandardMaterial3D
static var atlas_material: StandardMaterial3D
const HAIR := Vector2(0,0)
const SILVER := Vector2(1,0)
const WEAVE := Vector2(0,1)
const SILK := Vector2(1,1)

func _atlas_uv(tile: Vector2, local: Vector2, hair_sheet: bool) -> Vector2:
	var coord := local.clamp(Vector2.ZERO,Vector2.ONE)
	if tile == HAIR and not hair_sheet:
		# The square contains several locks. Each sculpted lock takes a single
		# broad highlight, so the bang reads as one brushstroke at game scale.
		coord.x = lerpf(.25,.48,coord.x)
	return (tile + Vector2(.012,.012) + coord*.976)*.5

func painted_grid(points: Array, width: int, height: int, tile: Vector2, outward: Vector3, hair_sheet := false) -> void:
	# Contiguous rows, edges included. Curvature and grazing-angle light come from
	# the model, while the illustrated pigment remains anchored to its surface.
	var start := textured_positions.size()
	for row in height-1:
		for col in width-1:
			var a := row*width+col
			var order := [a,a+1,a+width,a+1,a+width+1,a+width]
			if (points[a+1]-points[a]).cross(points[a+width]-points[a]).dot(outward) > 0:
				order = [a,a+width,a+1,a+1,a+width,a+width+1]
			for idx: int in order:
				var x := idx%width
				var y := floori(float(idx)/width)
				var du: Vector3 = points[y*width+mini(width-1,x+1)]-points[y*width+maxi(0,x-1)]
				var dv: Vector3 = points[mini(height-1,y+1)*width+x]-points[maxi(0,y-1)*width+x]
				var normal := du.cross(dv).normalized()
				if normal.dot(outward)<0:
					normal = -normal
				textured_positions.append(points[idx])
				textured_normals.append(normal if normal.length_squared()>.1 else outward.normalized())
				textured_uv.append(_atlas_uv(tile,Vector2(float(x)/(width-1),float(y)/(height-1)),hair_sheet))
				textured_tint.append(Color("#c6d4e2") if tile == HAIR else Color.WHITE)
	assert(textured_positions.size() > start)

func _ink() -> StandardMaterial3D:
	if ink_material == null:
		ink_material = StandardMaterial3D.new()
		ink_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		ink_material.cull_mode = BaseMaterial3D.CULL_FRONT
		ink_material.grow = true
		ink_material.grow_amount = .0038
		ink_material.albedo_color = Color("#48374a")
	return ink_material

func triangle(a: Vector3, b: Vector3, c: Vector3, outward: Vector3, color: Color) -> void:
	var normal := (b-a).cross(c-a)
	if normal.length_squared() < 0.0000000001:
		return
	normal = normal.normalized()
	if normal.dot(outward) < 0.0:
		var swap := b
		b = c
		c = swap
		normal = -normal
	# Godot front faces use clockwise winding.
	for point: Vector3 in [a, c, b]:
		vertices.append(point)
		normals.append(normal)
		colors.append(color)

func bake() -> ArrayMesh:
	var mesh := ArrayMesh.new()
	if vertices.is_empty():
		return mesh
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_COLOR] = colors
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	if paint == null:
		paint = StandardMaterial3D.new()
		paint.vertex_color_use_as_albedo = true
		paint.vertex_color_is_srgb = true
		paint.roughness = 0.72
		paint.metallic_specular = 0.37
	if inked:
		if illustrated == null:
			illustrated = paint.duplicate() as StandardMaterial3D
			illustrated.roughness = .88
			illustrated.metallic_specular = .12
			illustrated.next_pass = _ink()
		mesh.surface_set_material(0,illustrated)
	else:
		mesh.surface_set_material(0,paint)
	if not textured_positions.is_empty():
		var overlay := []
		overlay.resize(Mesh.ARRAY_MAX)
		overlay[Mesh.ARRAY_VERTEX] = textured_positions
		overlay[Mesh.ARRAY_NORMAL] = textured_normals
		overlay[Mesh.ARRAY_TEX_UV] = textured_uv
		overlay[Mesh.ARRAY_COLOR] = textured_tint
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,overlay)
		if atlas_material == null:
			atlas_material = StandardMaterial3D.new()
			atlas_material.albedo_texture = preload("res://art/characters/zhaoyun-pigment.png")
			atlas_material.vertex_color_use_as_albedo = true
			atlas_material.vertex_color_is_srgb = true
			atlas_material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
			atlas_material.cull_mode = BaseMaterial3D.CULL_DISABLED
			atlas_material.roughness = .87
			atlas_material.metallic_specular = .14
		mesh.surface_set_material(mesh.get_surface_count()-1,atlas_material)
	return mesh

# Courses specify height, horizontal radius, front-to-back radius and Z offset.
# Stacked courses give faces, helm rims, greaves and cuirasses their own profile.
func turned(center: Vector3, courses: Array, color: Color, sides := 12, smooth_curve := false) -> void:
	var previous: Array[Vector3] = []
	var previous_normals: Array[Vector3] = []
	for i in courses.size():
		var r: Vector4 = courses[i]
		var ring: Array[Vector3] = []
		var current_normals: Array[Vector3] = []
		for j in sides:
			var angle := TAU * (float(j)+0.5) / sides
			ring.append(center + Vector3(sin(angle)*r.y, r.x, -cos(angle)*r.z+r.w))
			if smooth_curve:
				var before: Vector4 = courses[maxi(0,i-1)]
				var after: Vector4 = courses[mini(courses.size()-1,i+1)]
				var delta := after-before
				var up_tangent := Vector3(sin(angle)*delta.y,delta.x,-cos(angle)*delta.z+delta.w)
				var side_tangent := Vector3(cos(angle)*r.y,0,sin(angle)*r.z)
				current_normals.append(up_tangent.cross(side_tangent).normalized())
		if i == 0 or i == courses.size()-1:
			var middle := center + Vector3(0,r.x,r.w)
			var up := Vector3.DOWN if i == 0 else Vector3.UP
			for j in sides:
				triangle(middle, ring[j], ring[(j+1)%sides], up, color)
		if i > 0:
			for j in sides:
				var next := (j+1)%sides
				if smooth_curve:
					for p in [previous[j],previous[next],ring[next],previous[j],ring[next],ring[j]]:
						vertices.append(p)
						colors.append(color)
					for n in [previous_normals[j],previous_normals[next],current_normals[next],previous_normals[j],current_normals[next],current_normals[j]]:
						normals.append(n)
					continue
				var centerline := center+Vector3(0,0,r.w)
				var radial := (ring[j]+ring[next])*0.5-centerline
				radial.y = 0
				triangle(previous[j], previous[next], ring[next], radial, color)
				triangle(previous[j], ring[next], ring[j], radial, color)
		previous = ring
		previous_normals = current_normals

func oval(center: Vector3, size: Vector3, color: Color, sides := 10) -> void:
	var courses := []
	for j in 8:
		var angle := -PI*0.5 + PI*j/7.0
		var radius := maxf(0.035,cos(angle))
		courses.append(Vector4(size.y*sin(angle),size.x*radius,size.z*radius,0))
	turned(center,courses,color,sides)

# Raised faceted cloth or metal patch. The chosen face normal also orients the
# bevel. Narrow ridge highlights give the shapes a readable illustrated edge.
func panel(points: Array, outside: Vector3, relief: float, color: Color) -> void:
	var center := Vector3.ZERO
	for p: Vector3 in points:
		center += p
	center = center/points.size() + outside.normalized()*relief
	for j in points.size():
		triangle(points[j],points[(j+1)%points.size()],center,outside,color)

func blade(path: Array, widths: Array, axis: Vector3, ridge: Vector3, color: Color) -> void:
	var previous: Array[Vector3] = []
	for i in path.size():
		var p: Vector3 = path[i]
		var w: float = widths[i]
		var ring: Array[Vector3] = [p-axis*w, p+ridge*w*0.45, p+axis*w, p-ridge*w*0.27]
		if i > 0:
			for j in 4:
				var next := (j+1)%4
				var outward: Vector3 = (ring[j]+ring[next])*0.5-p
				triangle(previous[j],previous[next],ring[next],outward,color)
				triangle(previous[j],ring[next],ring[j],outward,color)
		previous = ring

func lock(path: Array, widths: Array, across: Vector3, outside: Vector3, color: Color, pigment := false) -> void:
	# Rounded, flattened locks. Orient each cross-section along the actual
	# curve so the hair can sweep sideways without folding into a flat wedge.
	const SIDES := 12
	var prev: Array[Vector3] = []
	var prev_n: Array[Vector3] = []
	var painted := []
	for i in path.size():
		var at: Vector3 = path[i]
		var tangent: Vector3 = (path[mini(i+1,path.size()-1)]-path[maxi(i-1,0)]).normalized()
		var wide := (across-tangent*across.dot(tangent)).normalized()
		var raised := tangent.cross(wide).normalized()
		if raised.dot(outside) < 0.0:
			raised = -raised
		var w: float = widths[i]
		var ring: Array[Vector3] = []
		var ring_n: Array[Vector3] = []
		if pigment:
			# A curved front for each separate lock, down to its narrowing tip.
			for j in 9:
				var t := lerpf(-1.0,1.0,float(j)/8.0)
				var crest := sqrt(maxf(0.0,1.0-t*t))*.43
				painted.append(at + wide*t*w + raised*(crest*w+.0018))
		for j in SIDES:
			var a := TAU*j/SIDES
			ring.append(at + (wide*cos(a)+raised*sin(a)*.43)*w)
			ring_n.append((wide*cos(a)*.43+raised*sin(a)).normalized())
		if i > 0:
			for j in SIDES:
				var k := (j+1)%SIDES
				var order := [0,1,2,0,2,3]
				if (prev[k]-prev[j]).cross(ring[k]-prev[j]).dot(ring_n[j]+ring_n[k]) > 0:
					order = [0,2,1,0,3,2]
				var positions := [prev[j],prev[k],ring[k],ring[j]]
				var directions := [prev_n[j],prev_n[k],ring_n[k],ring_n[j]]
				for index: int in order:
					vertices.append(positions[index])
					normals.append(directions[index])
					colors.append(color)
		prev = ring
		prev_n = ring_n
	if pigment:
		painted_grid(painted,9,path.size(),HAIR,outside)

func shaft(a: Vector3, b: Vector3, ra: float, rb: float, color: Color, sides := 8) -> void:
	var along := (b-a).normalized()
	var axis := along.cross(Vector3.UP)
	if axis.length_squared() < 0.01:
		axis = along.cross(Vector3.RIGHT)
	axis = axis.normalized()
	var side := along.cross(axis)
	for j in sides:
		var d1 := axis*cos(TAU*j/sides)+side*sin(TAU*j/sides)
		var d2 := axis*cos(TAU*(j+1)/sides)+side*sin(TAU*(j+1)/sides)
		triangle(a+d1*ra,a+d2*ra,b+d2*rb,d1+d2,color)
		triangle(a+d1*ra,b+d2*rb,b+d1*rb,d1+d2,color)
		triangle(a,a+d1*ra,a+d2*ra,-along,color)
		triangle(b,b+d2*rb,b+d1*rb,along,color)
