extends Node3D

# All meshes are small original geometry. Warning arcs are fixed to the
# enemy's committed direction, so what the player sees is what can hit.
var particles: Array[Dictionary] = []
var flashes: Array[Dictionary] = []
var spark_mesh := PrismMesh.new()
var materials := {}

func _ready() -> void:
	spark_mesh.size = Vector3(0.069, 0.19, 0.052)

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
			part.scale = Vector3.ONE * (1.0 + 0.14 * pulse.age / pulse.life)
