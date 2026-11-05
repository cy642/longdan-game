extends SceneTree

const Warrior := preload("res://hero_visual.gd")
var checks := 0
var failures := 0

func _initialize() -> void:
	call_deferred("_run")

func _check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		print("FAIL motion: ", message)

func _sole_vertices(foot: MeshInstance3D) -> PackedVector3Array:
	var vertices := PackedVector3Array()
	for surface in foot.mesh.get_surface_count():
		var points: PackedVector3Array = foot.mesh.surface_get_arrays(surface)[Mesh.ARRAY_VERTEX]
		for point in points:
			if point.y < -.085:
				vertices.append(point)
	return vertices

func _low(foot: MeshInstance3D, vertices: PackedVector3Array) -> float:
	var bottom := INF
	for point in vertices:
		bottom = minf(bottom,(foot.global_transform*point).y)
	return bottom

func _walk(model, actor: Node3D) -> void:
	var soles := [_sole_vertices(model.feet[0]),_sole_vertices(model.feet[1])]
	_check(not soles[0].is_empty() and not soles[1].is_empty(),"both boot meshes have outsoles")
	var previous: Array[Vector3] = [Vector3.ZERO,Vector3.ZERO]
	var planted: Array[bool] = [false,false]
	var floor_error := 0.0
	var skid := 0.0
	var clearance := 0.0
	var samples := 0
	var distance := 0.0
	for frame in 540:
		distance += 4.7/240.0
		actor.position.z = -distance
		var walk_phase := distance*5.3
		model.pose("idle",frame/240.0,walk_phase,1)
		if frame < 60:
			continue
		for i in 2:
			var u := fposmod(walk_phase*Warrior.GAIT_RATE/TAU+i*.5,1.0)
			var foot: MeshInstance3D = model.feet[i]
			var low := _low(foot,soles[i])
			floor_error = maxf(floor_error,-low)
			clearance = maxf(clearance,low)
			var flat := u > .12 and u < .21
			if flat and planted[i]:
				skid = maxf(skid,foot.global_position.distance_to(previous[i]))
				samples += 1
			planted[i] = flat
			previous[i] = foot.global_position
	_check(samples >= 35 and skid < .008,"stationary midstance in world space, skid %.4f / %d samples" % [skid,samples])
	_check(floor_error < .012 and clearance > .13,"floor error %.4f; swing clearance %.4f" % [floor_error,clearance])
	print("Gait: %d stance pairs, drift %.5f m, floor penetration %.5f m, swing height %.3f m" % [samples,skid,floor_error,clearance])

func _tip(model) -> Vector3:
	return model.steel.global_transform*Vector3(0,0,-1.785)

func _actions(model) -> void:
	var max_grip_error := 0.0
	var extension: Dictionary = {}
	for action: String in ["attack","heavy","riposte","dragon","dodge","hurt","down"]:
		var before: Vector3
		for frame in 121:
			model.pose(action,frame/120.0,0,0)
			if frame == 0:
				before = _tip(model)
			var palm: Vector3 = model.wrists[0].global_transform * Vector3(0,-.198,-.01)
			var grip: Vector3 = model.steel.to_local(palm)
			max_grip_error = maxf(max_grip_error,Vector2(grip.x,grip.y).length())
			_check(grip.is_finite() and model.feet[1].global_position.is_finite(),"finite grip and boot")
			if frame in [41,77] and action == "dragon":
				extension[frame] = _tip(model)
			if (frame == 46 and action=="attack") or (frame == 59 and action=="heavy") or (frame == 45 and action=="riposte"):
				_check(_tip(model).z < before.z-.24,"forward tip on " +action)
				_check(absf(_tip(model).x) < .18 and _tip(model).y > .87, "tip meets the centred torso on "+action)
				_check(model.feet[0].global_position.z+.12 < model.feet[1].global_position.z,"lead-foot lunge on "+action)
	_check(max_grip_error < .022,"offhand grip follows shaft, error %.4f" % max_grip_error)
	var first: Vector3 = extension[41]
	var second: Vector3 = extension[77]
	_check(first.distance_to(second) > .70 and second.y>first.y+.32,"distinct sweep and rising thrust")
	print("Max palm distance from shaft %.4f m; sweep and rising thrust: " % max_grip_error, first," -> ",second)

func _run() -> void:
	var actor := Node3D.new()
	root.add_child(actor)
	var model := Warrior.new()
	actor.add_child(model)
	model.configure("hero")
	_walk(model,actor)
	for i in 30:
		model.pose("idle",0,0,0)
	_actions(model)
	print("Motion regression: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
