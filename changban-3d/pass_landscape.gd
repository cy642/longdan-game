extends Node3D
## Authored Changban geography. The playable road sits at y=0. River water is below
## the deck, so gameplay constrains movement to the bridge rails while crossing.
const PASS_SCENE: PackedScene = preload("res://art/landscape/ChangbanPass.glb")
const STANDARD_SHADER: Shader = preload("res://art/landscape/standard.gdshader")
const RIVER_SHADER: Shader = preload("res://art/landscape/river.gdshader")
const RIDGE_SHADER: Shader = preload("res://art/landscape/ridge.gdshader")


func _ready() -> void:
	var valley := PASS_SCENE.instantiate()
	add_child(valley)
	# Godot's glTF importer retains COLOR_0 arrays but can leave their albedo flag
	# disabled. Apply the painted vertex colours on the shared imported materials.
	var distant_paint := ShaderMaterial.new()
	distant_paint.shader = RIDGE_SHADER
	for node in valley.find_children("*", "MeshInstance3D", true, false):
		var mesh: Mesh = node.mesh
		for index in mesh.get_surface_count():
			var paint := mesh.surface_get_material(index) as BaseMaterial3D
			if paint and not paint.albedo_texture:
				paint.vertex_color_use_as_albedo = true
		if String(node.name).begins_with("Painted distant ridge"):
			node.material_override = distant_paint
			node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		elif String(node.name).begins_with("Terrain "):
			# The footpath receives tree and character shadows. Recasting its own
			# flat surface leaves repetitive stripes on grazing camera angles.
			node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# Each animated material covers a single static batch, regardless of flag count.
	var standards := valley.find_child("Cao army field colours", true, false) as MeshInstance3D
	var river := valley.find_child("Han tributary", true, false) as MeshInstance3D
	if standards:
		var original := standards.get_active_material(0) as BaseMaterial3D
		var silk := ShaderMaterial.new()
		silk.shader = STANDARD_SHADER
		silk.set_shader_parameter("woven_silk", original.albedo_texture)
		standards.material_override = silk
	if river:
		var water := ShaderMaterial.new()
		water.shader = RIVER_SHADER
		river.material_override = water
	# Only the camera queries layer two. These silhouettes keep an orbiting camera
	# out of roof tiles without making decorative grass or foliage snag the player.
	_camera_box("East village house", Vector3(9.4, 1.58, -0.35), Vector3(4.55, 3.16, 6.17))
	_camera_box("Burned house", Vector3(-10.55, 1.48, -1.7), Vector3(4.73, 2.96, 6.8))
	_camera_box("Western house", Vector3(-16.5, 1.67, 4.8), Vector3(3.82, 3.34, 5.35))
	_camera_box("Far eastern house", Vector3(16.4, 2.1, -4.75), Vector3(3.7, 3.35, 4.94))
	_camera_box("Well coping", Vector3(-5.35, 0.37, 1.2), Vector3(2.05, 0.74, 2.05))
	_camera_box("Handcart", Vector3(6.65, 0.54, 4.3), Vector3(1.45, 1.08, 1.70))


func _camera_box(label: String, center: Vector3, dimensions: Vector3) -> void:
	var body := StaticBody3D.new()
	body.name = label
	body.position = center
	body.collision_layer = 2
	body.collision_mask = 0
	var collision := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = dimensions
	collision.shape = box
	body.add_child(collision)
	add_child(body)
