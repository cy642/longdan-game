extends Node3D

# All meshes are small original geometry. Warning arcs are fixed to the
# enemy's committed direction, so what the player sees is what can hit.
var particles: Array[Dictionary] = []
var flashes: Array[Dictionary] = []
var spark_mesh := PrismMesh.new()
var materials := {}
var brush_meshes := {}
var blade_history: Array[Dictionary] = []
var blade_mesh := ImmediateMesh.new()

func _ready() -> void:
	spark_mesh.size = Vector3(0.069, 0.19, 0.052)
	var trail := _mesh(self, blade_mesh, Color.WHITE)
	var pigment := ink(Color.WHITE).duplicate() as StandardMaterial3D
	pigment.vertex_color_use_as_albedo = true
	pigment.vertex_color_is_srgb = true
	pigment.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	trail.material_override = pigment

func trace_blade(tip: Vector3, edge: Vector3, tint: Color, dt: float, cutting: bool) -> void:
	const LIFE := 0.095
	for sample in blade_history:
		sample.age += dt
	while not blade_history.is_empty() and blade_history[0].age >= LIFE:
		blade_history.pop_front()
	var local_tip := to_local(tip)
	if cutting and (blade_history.is_empty() or local_tip.distance_squared_to(blade_history.back().tip) > 0.0004):
		blade_history.append({"tip":local_tip,"edge":to_local(edge),"age":0.0})
	blade_mesh.clear_surfaces()
	if blade_history.size() < 2:
		return
	blade_mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLE_STRIP)
	for sample in blade_history:
		var strength: float = 1.0-sample.age/LIFE
		blade_mesh.surface_set_color(Color(tint,0.65*strength))
		blade_mesh.surface_add_vertex(sample.tip)
		blade_mesh.surface_set_color(Color(tint,0.08*strength))
		blade_mesh.surface_add_vertex(sample.edge)
	blade_mesh.surface_end()

func ink(color: Color) -> StandardMaterial3D:
	if materials.has(color):
		return materials[color]
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	if color.a < 1.0:
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	materials[color] = material
	return material

func _arc(inner: float, outer: float, half_angle: float) -> ArrayMesh:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var slices := 32
	for i in slices:
		var a := lerpf(-half_angle, half_angle, i / float(slices))
		var b := lerpf(-half_angle, half_angle, (i + 1) / float(slices))
		var va := Vector3(sin(a), 0.0, -cos(a))
		var vb := Vector3(sin(b), 0.0, -cos(b))
		for p in [va * inner, va * outer, vb * outer, va * inner, vb * outer, vb * inner]:
			surface.add_vertex(p)
	return surface.commit()

func _mesh(parent: Node3D, geo: Mesh, color: Color) -> MeshInstance3D:
	var part := MeshInstance3D.new()
	part.mesh = geo
	part.material_override = ink(color)
	part.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(part)
	return part

func warning(radius: float, half_angle: float, boss: bool) -> Node3D:
	var cue := Node3D.new()
	add_child(cue)
	var fill := Color(0.97, 0.38, 0.15, 0.18)
	var border := Color(1.0, 0.68, 0.31, 0.76)
	if boss:
		fill = Color(0.95, 0.18, 0.11, 0.21)
		border = Color(1.0, 0.49, 0.25, 0.88)
	_mesh(cue, _arc(0.10, radius, half_angle), fill)
	_mesh(cue, _arc(radius - 0.063, radius, half_angle), border).position.y = 0.006
	return cue

func contact(at: Vector3, direction: Vector3, color: Color, heavy: bool) -> void:
	var count := 9 if heavy else 6
	for i in count:
		var part := _mesh(self, spark_mesh, color if i % 3 else Color("fff3c3"))
		part.position = at
		var angle := i * TAU / count + 0.31
		var velocity := Vector3(cos(angle), 0.5 + 0.24 * (i % 4), sin(angle)) * (1.8 + 0.27 * (i % 3)) + direction * 1.3
		part.quaternion = Quaternion(Vector3.UP, velocity.normalized())
		particles.append({"node": part, "v": velocity, "age": 0.0, "life": 0.20 + 0.025 * (i % 3)})

func strike(at: Vector3, facing: float, heavy: bool, color: Color = Color("c8f4fa")) -> void:
	var part := _mesh(self, _arc(1.28, 1.38 if heavy else 1.34, 0.98 if heavy else 0.52), color)
	part.position = at + Vector3.UP * 0.91
	part.rotation = Vector3(0.12 if heavy else -0.17, facing, -0.22)
	flashes.append({"node": part, "age": 0.0, "life": 0.12 if heavy else 0.09})

func dragon_coil(at: Vector3, facing: float) -> void:
	_brush("gather", at, facing, 0.29)

func dragon_cut(at: Vector3, facing: float, sweep: bool) -> void:
	_brush("crescent" if sweep else "lance", at, facing, 0.28 if sweep else 0.34)

func dragon_impact(at: Vector3, facing: float) -> void:
	_brush("impact", at, facing, 0.32)
	# The crest opens across the target's shoulder line, visible even when the
	# thrust points directly into the camera's line of sight.
	for i in 4:
		var side := -1.0 if i % 2 == 0 else 1.0
		var offset := Vector3(side*(0.30+0.07*i),0.12+0.04*i,0.06).rotated(Vector3.UP,facing)
		var v := Vector3(side*(1.9+0.15*i),1.35+0.23*i,-0.50).rotated(Vector3.UP,facing)
		var shard := _mesh(self, spark_mesh, Color("e8ffff") if i<2 else Color("70cad8"))
		shard.position = at + offset
		shard.quaternion = Quaternion(Vector3.UP,v.normalized())
		particles.append({"node":shard,"v":v,"age":0.0,"life":0.21+0.025*i})

func perfect_step(at: Vector3, facing: float) -> void:
	_brush("parry", at, facing, 0.24)

func return_thrust(at: Vector3, facing: float) -> void:
	_brush("counter", at, facing, 0.22)

func _brush(shape: String, at: Vector3, facing: float, life: float) -> void:
	if not brush_meshes.has(shape):
		brush_meshes[shape] = _build_brush(shape)
	var part := _mesh(self, brush_meshes[shape], Color.WHITE)
	var paint := ink(Color.WHITE).duplicate() as StandardMaterial3D
	paint.vertex_color_use_as_albedo = true
	paint.vertex_color_is_srgb = true
	paint.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	part.material_override = paint
	part.position = at
	part.rotation.y = facing
	flashes.append({"node":part,"age":0.0,"life":life,"paint":paint})

# The sweep has a translucent belly and a bright tapered cutting edge. The
# follow-up braids two strokes down the spear's axis and disappears at its tip.
func _build_brush(shape: String) -> ArrayMesh:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	const SEGMENTS := 40
	var is_line := shape == "lance" or shape == "counter"
	var bright := Color("#e8ffff") if shape != "counter" and shape != "parry" else Color("#fff3c2")
	var blue := Color("#168bae") if shape != "counter" and shape != "parry" else Color("#b57a32")
	for strand in 2:
		var last: Array[Vector3] = []
		for i in range(SEGMENTS + 1):
			var t := float(i) / float(SEGMENTS)
			var taper := pow(maxf(0.0, sin(t*PI)), 0.72)
			var center: Vector3
			var cross: Vector3
			if shape == "impact":
				var side := -1.0 if strand == 0 else 1.0
				center = Vector3.ZERO.bezier_interpolate(Vector3(side*0.50,0.03,0.12),Vector3(side*1.26,0.45,0.10),Vector3(side*0.72,0.87,-0.10),t)
				center *= 1.0 if strand == 0 else 0.81
				cross = Vector3(-side*0.055,0.12,0.04) * taper
			elif is_line:
				var twist := t * TAU * (0.74 if shape == "lance" else 0.45) + strand * PI
				var radius := (0.10 + 0.20*taper) * (1.0-t)
				center = Vector3(cos(twist)*radius, 0.78 + t*0.58 + sin(twist)*radius, -0.40 - 2.85*t)
				cross = Vector3(cos(twist+0.55),sin(twist+0.55),0.0) * taper * (0.095 if strand == 0 else 0.035)
			else:
				var arc := lerpf(1.56,-1.56,t)
				var radius := (2.26 + 0.23*taper) if shape == "crescent" else (0.83 + 0.16*taper)
				var height := 0.52 + 0.92*t + 0.12*taper if shape == "crescent" else 0.26 + t*0.67
				if shape == "gather":
					arc = lerpf(-2.2,1.0,t)
				if strand == 1:
					radius += 0.04 + sin(t*TAU*1.3)*0.15
					height -= 0.11 + sin(t*TAU)*0.14
				var radial := Vector3(sin(arc),0,-cos(arc))
				center = radial * radius + Vector3.UP * height
				cross = (radial * 0.09 + Vector3.UP * 0.13) * taper * (1.0 if strand == 0 else 0.30)
			var row: Array[Vector3] = [center-cross, center+cross*0.60, center+cross]
			if not last.is_empty():
				for lane in 2:
					var inner := Color(blue, 0.37) if lane == 0 else Color(bright, 0.94)
					var outer := Color(bright, 0.94) if lane == 0 else Color(bright, 0.13)
					for j in [0,1,2,0,2,3]:
						surface.set_color(inner if j in [0,3] else outer)
						match j:
							0: surface.add_vertex(last[lane])
							1: surface.add_vertex(last[lane+1])
							2: surface.add_vertex(row[lane+1])
							3: surface.add_vertex(row[lane])
			last = row
	return surface.commit()

func advance(dt: float) -> void:
	for i in range(particles.size() - 1, -1, -1):
		var p: Dictionary = particles[i]
		p.age += dt
		var part: Node3D = p.node
		if p.age >= p.life:
			part.queue_free()
			particles.remove_at(i)
			continue
		part.position += (p.v as Vector3) * dt
		p.v += Vector3.DOWN * (9.0 * dt)
		part.scale = Vector3.ONE * maxf(0.03, 1.0 - p.age / p.life)
	for i in range(flashes.size() - 1, -1, -1):
		var pulse: Dictionary = flashes[i]
		pulse.age += dt
		var part: Node3D = pulse.node
		if pulse.age >= pulse.life:
			part.queue_free()
			flashes.remove_at(i)
		else:
			var t: float = pulse.age / pulse.life
			if pulse.has("paint"):
				pulse.paint.albedo_color = Color(1.0,1.0,1.0,1.0-smoothstep(0.25,1.0,t))
				part.scale = Vector3.ONE * (1.0 + 0.055*t)
			else:
				part.scale = Vector3.ONE * (1.0 + 0.14*t)
