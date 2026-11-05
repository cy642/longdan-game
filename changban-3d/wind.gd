extends MultiMeshInstance3D

# One batched layer of wind-borne chaff across the playable valley.
const COUNT := 38
var time := 0.0
var seeds := PackedVector3Array()
var smoke := MultiMesh.new()
const SMOKE_COUNT := 16

func _ready() -> void:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for v in [Vector3(-0.068,0,0),Vector3(0.015,0.015,-0.026),Vector3(0.08,0,0),Vector3(-0.068,0,0),Vector3(0.08,0,0),Vector3(0.012,-0.009,0.028)]:
		surface.set_normal(Vector3.UP)
		surface.add_vertex(v)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color("#ddb274")
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	var leaves := MultiMesh.new()
	leaves.transform_format = MultiMesh.TRANSFORM_3D
	leaves.mesh = surface.commit()
	leaves.mesh.surface_set_material(0,mat)
	leaves.instance_count = COUNT
	multimesh = leaves
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	custom_aabb = AABB(Vector3(-16,-1,-35),Vector3(32,9,57))
	var rng := RandomNumberGenerator.new()
	rng.seed = 208
	for i in COUNT:
		seeds.append(Vector3(rng.randf_range(0,28),rng.randf_range(0,6),rng.randf_range(-32,20)))
	# Rising from the broken roof beside the well, in one translucent batch.
	var soot := ShaderMaterial.new()
	soot.shader = preload("res://art/landscape/embers.gdshader")
	var quad := QuadMesh.new()
	quad.material = soot
	smoke.transform_format = MultiMesh.TRANSFORM_3D
	smoke.use_colors = true
	smoke.mesh = quad
	smoke.instance_count = SMOKE_COUNT
	var plume := MultiMeshInstance3D.new()
	plume.multimesh = smoke
	plume.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	plume.custom_aabb = AABB(Vector3(-13,1,-6),Vector3(11,12,9))
	add_child(plume)
	_process(0)

func _process(dt: float) -> void:
	time += dt
	for i in COUNT:
		var start := seeds[i]
		var x := fposmod(start.x+time*1.35,28.0)-14.0
		var y := 0.12+fposmod(start.y-time*0.21,6.0)
		var z := start.z+0.45*sin(time*0.75+start.x)
		var basis := Basis.from_euler(Vector3(time*1.7+start.z,time+start.y,start.x+time*1.37))
		multimesh.set_instance_transform(i,Transform3D(basis,Vector3(x,y,z)))
	for i in SMOKE_COUNT:
		var age := fposmod(time*0.115 + float(i)/SMOKE_COUNT,1.0)
		var at := Vector3(-10.25 + age*4.3,1.8 + age*7.2,-2.35 + cos(i*1.6)*0.56 + age*0.4)
		var size_factor := 1.08 + age*2.7
		smoke.set_instance_transform(i,Transform3D(Basis.from_scale(Vector3.ONE*size_factor),at))
		smoke.set_instance_color(i,Color(1,1,1,sin(age*PI)))
