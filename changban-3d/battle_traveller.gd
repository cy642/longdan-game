extends Node3D

# A travelling villager with a tied reed pack, a loose flax hood and a hem
# shaped into alternating pleats. The player can recognize the ochre shawl
# against the soldiers' plate even when viewing the party from behind.
var cloth := Node3D.new()
var boots: Array[MeshInstance3D] = []
var child_bundle := Node3D.new()
var gait := 0.0
var materials := {}

func _ready() -> void:
	add_child(cloth)
	_shell(cloth, [[0.23,0.33,0.22],[0.35,0.30,0.20],[0.71,0.25,0.18],[0.96,0.29,0.19]], Color("48564d"), true)
	_shell(cloth, [[0.72,0.24,0.18],[0.75,0.255,0.19],[0.83,0.26,0.188]], Color("553d33"), false)
	_shell(cloth, [[0.84,0.39,0.24],[0.90,0.38,0.24],[1.09,0.29,0.19],[1.16,0.16,0.16]], Color("ad763c"), true)
	_round(cloth, Vector3(0,1.29,0.026), Vector3(0.225,0.252,0.205), Color("a47747"))
	_round(cloth, Vector3(0,1.27,-0.10), Vector3(0.168,0.19,0.145), Color("d2a580"))
	_round(cloth, Vector3(0,1.425,-0.03), Vector3(0.209,0.112,0.19), Color("b28857"))
	for s in [-1.0,1.0]:
		_round(cloth, Vector3(s * 0.071,1.295,-0.229), Vector3(0.017,0.018,0.013), Color("483629"))
		_round(cloth, Vector3(s * 0.306,0.82,-0.008), Vector3(0.087,0.145,0.103), Color("756343"))
		_round(cloth, Vector3(s * 0.30,0.69,-0.055), Vector3(0.072,0.076,0.074), Color("bd9474"))
		boots.append(_round(self, Vector3(s * 0.133,0.14,-0.033), Vector3(0.09,0.13,0.15), Color("423c35")))
	var pack := _round(cloth, Vector3(0.10,0.88,0.219), Vector3(0.206,0.245,0.152), Color("89704e"))
	pack.rotation.z = -0.22
	_round(cloth, Vector3(0.045,1.08,0.23), Vector3(0.09,0.077,0.067), Color("675239"))
	_round(cloth, Vector3(0.12,1.085,0.24), Vector3(0.060,0.068,0.08), Color("aa855d"))

	_bundle()

func _bundle() -> void:
	child_bundle.name = "襁褓中的阿斗"
	cloth.add_child(child_bundle)
	child_bundle.position = Vector3(0.025, 0.87, -0.237)
	child_bundle.rotation.z = -0.64
	_round(child_bundle, Vector3(0,-0.055,0), Vector3(0.168,0.233,0.136), Color("c98938"))
	_round(child_bundle, Vector3(0.001,0.125,0.013), Vector3(0.171,0.164,0.136), Color("e4b15d"))
	_round(child_bundle, Vector3(0.0,0.139,-0.058), Vector3(0.118,0.117,0.096), Color("f4c098"))
	_round(child_bundle, Vector3(0.0,0.240,-0.054), Vector3(0.071,0.044,0.055), Color("5b392f"))
	for s in [-1.0,1.0]:
		var eye := _round(child_bundle, Vector3(s * 0.044,0.147,-0.147), Vector3(0.026,0.006,0.005), Color("694637"))
		eye.rotation.z = s * 0.12
	_round(child_bundle, Vector3(0.0,0.104,-0.141), Vector3(0.013,0.006,0.006), Color("ba746a"))
	var hem := _round(child_bundle, Vector3(0.007,-0.018,-0.104), Vector3(0.157,0.033,0.036), Color("f2c678"))
	hem.rotation.z = -0.48
	var knot := _round(child_bundle, Vector3(-0.083,-0.077,-0.112), Vector3(0.055,0.036,0.035), Color("9c462d"))
	knot.rotation.z = -0.4

func _mat(color: Color) -> StandardMaterial3D:
	if not materials.has(color):
		var mat := StandardMaterial3D.new()
		mat.albedo_color = color
		mat.roughness = 0.94
		mat.cull_mode = BaseMaterial3D.CULL_DISABLED
		materials[color] = mat
	return materials[color]

func _round(parent: Node3D, at: Vector3, radii: Vector3, color: Color) -> MeshInstance3D:
	var mesh := SphereMesh.new()
	mesh.radial_segments = 12
	mesh.rings = 5
	var piece := MeshInstance3D.new()
	piece.mesh = mesh
	piece.material_override = _mat(color)
	piece.position = at
	piece.scale = radii * 2.0
	parent.add_child(piece)
	return piece

func _shell(parent: Node3D, loops: Array, color: Color, pleat: bool) -> void:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for ring in range(loops.size() - 1):
		for j in 20:
			for offset in [[0,0],[0,1],[1,1],[0,0],[1,1],[1,0]]:
				var row: Array = loops[ring + int(offset[0])]
				var index: int = j + int(offset[1])
				var a := TAU * index / 20.0
				var fold := 1.0 if not pleat or index % 2 else 0.94
				surface.add_vertex(Vector3(sin(a) * row[1] * fold, row[0], cos(a) * row[2] * fold))
	surface.generate_normals()
	var piece := MeshInstance3D.new()
	piece.mesh = surface.commit()
	piece.material_override = _mat(color)
	parent.add_child(piece)

func advance(dt: float, speed: float) -> void:
	gait += dt * (2.0 + 2.4 * speed)
	var stride := clampf(speed / 3.0, 0.0, 1.0)
	cloth.position.y = absf(sin(gait)) * 0.034 * stride
	cloth.rotation.z = sin(gait) * stride * 0.046
	for i in boots.size():
		var step := sin(gait + i * PI)
		boots[i].position.y = 0.14 + maxf(0.0, step) * 0.075 * stride
		boots[i].position.z = -0.033 - 0.105 * step * stride
