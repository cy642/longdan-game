extends Node3D

const WarriorArt := preload("res://art/characters/warrior_art.gd")
const UPPER := .249
const LOWER := .198 # palm centre, measured from the elbow in the wrist mesh
const THIGH := .33
const CALF := .215
const ANKLE_HEIGHT := .110
const GAIT_RATE := .76
const STANCE := .42
const CYCLE_DISTANCE := TAU / (5.3 * GAIT_RATE)
static var mesh_library: Dictionary = {}
var kind := ""
var rig: Node3D
var body: Node3D
var head: Node3D
var silk: Node3D
var steel: Node3D
var shield: Node3D
var thighs: Array[Node3D] = []
var shins: Array[Node3D] = []
var feet: Array[Node3D] = []
var arms: Array[Node3D] = []
var gait := 0.0
var stance_anchors: Array[Vector3] = [Vector3.ZERO, Vector3.ZERO]
var stance_locked: Array[bool] = [false,false]
var previous_position := Vector3.ZERO
var wrists: Array[Node3D] = []

func configure(who: String) -> void:
	if who == kind and rig != null:
		return
	if rig != null:
		remove_child(rig)
		rig.queue_free()
		thighs.clear()
		shins.clear()
		feet.clear()
		arms.clear()
		wrists.clear()
		shield = null
	kind = who
	gait = 0.0
	stance_locked = [false,false]
	previous_position = global_position if is_inside_tree() else Vector3.ZERO
	if not mesh_library.has(kind):
		var sculpt := WarriorArt.new(kind)
		var parts := {}
		for id: String in ["thigh_l","thigh_r","shin_l","shin_r","foot_l","foot_r","arm_l","arm_r","wrist_l","wrist_r","body","head","scarf","weapon"]:
			parts[id] = sculpt.build(id)
		if kind == "shield":
			parts["shield"] = sculpt.build("shield")
		mesh_library[kind] = parts
	rig = Node3D.new()
	rig.name = "Articulation"
	add_child(rig)
	var size_factor := 1.16 if kind == "commander" else (1.0 if kind == "hero" else .94)
	rig.scale = Vector3.ONE * size_factor
	body = part("body",rig,Vector3(0,.70,0))
	head = part("head",body,Vector3(0,.539,-.006))
	silk = part("scarf",body,Vector3(0,.49,.147))
	steel = part("weapon",body,Vector3.ZERO)
	if kind == "shield":
		shield = part("shield",body,Vector3.ZERO)
	for i in 2:
		var s := -1.0 if i == 0 else 1.0
		var suffix := "_l" if i == 0 else "_r"
		var leg := part("thigh"+suffix,rig,Vector3(s*.155,.655,0))
		thighs.append(leg)
		var shin := part("shin"+suffix,leg,Vector3.DOWN*THIGH)
		shins.append(shin)
		feet.append(part("foot"+suffix,shin,Vector3.DOWN*CALF))
		var arm := part("arm"+suffix,body,Vector3(s*.313,.421,-.002))
		arms.append(arm)
		wrists.append(part("wrist"+suffix,arm,Vector3(0,-UPPER,0)))
	pose("idle",0,0,0)

func part(id: String, parent: Node3D, offset: Vector3) -> Node3D:
	var joint := MeshInstance3D.new()
	joint.name = id
	joint.mesh = mesh_library[kind][id]
	joint.position = offset
	parent.add_child(joint)
	return joint

# Two-link arm solve in cuirass coordinates. The weapon is driven by the actual
# dominant wrist, and the support hand seeks a second position on the shaft.
func reach(index: int, target: Vector3, pole: Vector3) -> Vector3:
	var arm := arms[index]
	var hand := wrists[index]
	var ray := target-arm.position
	var axis := ray.normalized()
	var distance := clampf(ray.length(),.045,UPPER+LOWER-.001)
	var elbow_plane := (pole-axis*pole.dot(axis)).normalized()
	var along := (UPPER*UPPER-LOWER*LOWER+distance*distance)/(2.0*distance)
	var side := sqrt(maxf(0,UPPER*UPPER-along*along))
	var elbow := axis*along+elbow_plane*side
	var wrist := axis*distance
	arm.quaternion = Quaternion(Vector3.DOWN,elbow.normalized())
	hand.quaternion = arm.quaternion.inverse()*Quaternion(Vector3.DOWN,(wrist-elbow).normalized())
	return arm.position+wrist


# Place both skin contact points on the shaft while keeping them reachable.
# The allowable rear grip is the intersection of the two shoulder reach spheres.
func _two_hand_grip(wanted: Vector3, forward: Vector3, spacing: float) -> Vector3:
	var a := arms[1].position
	var b := arms[0].position - forward * spacing
	var separation := a.distance_to(b)
	var axis := (b-a) / separation
	var center := (a+b)*0.5
	var radius := UPPER+LOWER-.004
	var half := separation*.5
	var axial := clampf((wanted-center).dot(axis), half-radius, radius-half)
	var side := wanted-center-axis*((wanted-center).dot(axis))
	var allowed := sqrt(maxf(0.0, radius*radius-pow(half+absf(axial),2)))
	return center + axis*axial + side.limit_length(allowed)

# Returns ankle x/y/z and pitch. Stance travels backwards at the speed of the
# actor. Swing clears the ground and arrives heel first for the next contact.
func _foot_target(i: int, cycle: float, travelled: float, coil: float, drive: float, sweep: float, evade: float) -> Vector4:
	var side := -1.0 if i == 0 else 1.0
	var u := fposmod(cycle / TAU + i*.5, 1.0)
	var half_span := CYCLE_DISTANCE*STANCE*.5
	var z: float
	var rise := 0.0
	var pitch: float
	if u < STANCE:
		z = -half_span + CYCLE_DISTANCE*u
		var stance_ratio := u/STANCE
		pitch = .18*(1.0-smoothstep(0,.24,stance_ratio)) - .43*smoothstep(.59,1.0,stance_ratio)
	else:
		var swing := (u-STANCE)/(1.0-STANCE)
		var travel := smoothstep(0.0,1.0,swing)
		z = lerpf(half_span,-half_span,travel)
		z += .104*sin(TAU*swing)*(1.0-travel)
		rise = .169*pow(sin(PI*swing),1.35)
		pitch = lerpf(-.43,.18,smoothstep(.12,.81,swing))
	var x := side*(.159 + .018*gait + .026*rise)
	z = lerpf(side*.055,z,gait)
	rise *= gait
	pitch *= gait
	if i == 0:
		z -= .185*drive + .046*sweep
		rise += coil*.064
		pitch += .10*coil
	else:
		z += .102*drive + .048*sweep
		pitch -= .35*drive
		rise += .025*drive
	x += side*(.032*coil+.053*drive+.07*evade)
	var contact_z := .123 if pitch >= 0 else -.217
	# Rotate about the heel or toe at ground level instead of the ankle centre.
	var sole := -ANKLE_HEIGHT*cos(pitch)-contact_z*sin(pitch)
	# Keep the planted sole reference fixed across the heel-to-toe pivot switch.
	var pivot := Vector3(x,0,z)
	if gait > .88 and u < STANCE and travelled > .0001 and travelled < .23 and is_inside_tree():
		if not stance_locked[i]:
			stance_anchors[i] = to_global(pivot*rig.scale.x)
			stance_locked[i] = true
		var held := to_local(stance_anchors[i])/rig.scale.x
		var correction := Vector2(held.x-pivot.x,held.z-pivot.z).limit_length(.13)
		pivot.x += correction.x
		pivot.z += correction.y
	else:
		stance_locked[i] = false
	var ankle_z := pivot.z + contact_z - (contact_z*cos(pitch)-ANKLE_HEIGHT*sin(pitch))
	return Vector4(pivot.x,rise-sole,ankle_z,pitch)

func _hip_drop(i: int, target: Vector4, local_rotation: Basis) -> float:
	var hip := local_rotation*thighs[i].position + rig.position/rig.scale.x
	var side := Vector2(target.x-hip.x,target.z-hip.z)
	var reach_length := THIGH+CALF-.0015
	var vertical := sqrt(maxf(.0001, reach_length*reach_length-side.length_squared()))
	return maxf(0.0,hip.y-target.y-vertical)

func _plant(i: int, target: Vector4, local_rotation: Basis) -> void:
	var leg := thighs[i]
	var shin := shins[i]
	var ankle := Vector3(target.x,target.y,target.z) - rig.position/rig.scale.x
	var ray := local_rotation.inverse()*ankle-leg.position
	var axis := ray.normalized()
	var distance := clampf(ray.length(), .12, THIGH+CALF-.001)
	var pole := Vector3(-.09 if i == 0 else .09,0,-1)
	var bend := (pole-axis*pole.dot(axis)).normalized()
	var along := (THIGH*THIGH-CALF*CALF+distance*distance)/(2.0*distance)
	var knee := axis*along+bend*sqrt(maxf(0,THIGH*THIGH-along*along))
	var upper_q := Quaternion(Vector3.DOWN,knee.normalized())
	var lower_q := Quaternion(Vector3.DOWN,(axis*distance-knee).normalized())
	leg.quaternion = upper_q
	shin.quaternion = upper_q.inverse()*lower_q
	var boot_frame := Basis(Vector3.UP, .052 if i == 0 else -.052) * Basis(Vector3.RIGHT,target.w)
	feet[i].basis = Basis(lower_q).inverse()*local_rotation.inverse()*boot_frame

func _pulse(t: float, start: float, peak: float, hold: float, finish: float) -> float:
	return smoothstep(start,peak,t)*(1.0-smoothstep(hold,finish,t))

# phase is the normalized action phase. Idle receives the simulation's breath
# clock in radians. walk_phase accumulates travelled distance.
func pose(action: String, phase: float, walk_phase: float, moving: float) -> void:
	if rig == null:
		return
	var dt := clampf(get_physics_process_delta_time(), .001,.05)
	gait = lerpf(gait,clampf(moving,0,1),1.0-exp(-16.0*dt))
	var here := global_position if is_inside_tree() else previous_position
	var travelled := here.distance_to(previous_position)
	previous_position = here
	var cycle := walk_phase*GAIT_RATE
	var step := sin(cycle)*gait
	var t := clampf(phase,0,1)
	var breath := sin(phase) * (1.0-gait) if action == "idle" else 0.0
	var coil := 0.0
	var drive := 0.0
	var sweep := 0.0
	var return_turn := 0.0
	var high := 0.0
	var heavy := action == "heavy"
	match action:
		"attack","heavy","riposte":
			var contact := .49 if heavy and kind=="hero" else (.37 if action=="riposte" else .38)
			var launch := contact-(.21 if heavy else .16)
			coil = _pulse(t,0.0,launch*.85,launch,contact)
			drive = _pulse(t,launch,contact,contact+.055,.96)
			return_turn = _pulse(t,contact+.05,contact+.20,contact+.22,1.0)
			if heavy:
				high = coil*.40 - drive*.18
			elif action == "riposte":
				coil *= .66
				high = -.32*coil + .10*drive
		"dragon":
			# Cross the body with the first sweep, gather low, then thrust upward.
			coil = _pulse(t,0.0,.16,.18,.34) + _pulse(t,.40,.51,.54,.64)*.70
			sweep = _pulse(t,.16,.34,.36,.54)
			drive = _pulse(t,.52,.64,.69,.98)
			high = .20*coil - .29*sweep + .52*drive
			return_turn = _pulse(t,.66,.77,.8,1.0)
	var evade := sin(PI*t) if action=="dodge" else 0.0
	var hurt := sin(PI*t) if action=="hurt" else 0.0
	var fallen := smoothstep(0,.90,t) if action=="down" else 0.0
	var load := drive + .68*sweep
	var dip := .044 + .049*gait + .055*coil + .068*load + .15*evade
	var transfer := cos(cycle-.32)*gait
	rig.position = Vector3(-.032*transfer-.030*load,-dip+.016*cos(2*cycle-.5)*gait,
			-.034*gait+.064*coil-.092*load+.047*hurt)*rig.scale.x
	rig.rotation = Vector3(0.0,.080*step+.15*coil-.19*drive-.39*sweep,0.0)
	var pelvis_basis := Basis(Vector3.UP,rig.rotation.y)
	var left := _foot_target(0,cycle,travelled,coil,drive,sweep,evade)
	var right := _foot_target(1,cycle,travelled,coil,drive,sweep,evade)
	rig.position.y -= maxf(_hip_drop(0,left,pelvis_basis),_hip_drop(1,right,pelvis_basis))*rig.scale.x
	_plant(0,left,pelvis_basis)
	_plant(1,right,pelvis_basis)
	rig.rotation.z -= 1.42*fallen
	rig.rotation.x -= .14*fallen
	rig.position.y += fallen*.15*rig.scale.x
	body.position = Vector3(-.015*transfer,.70+.008*breath+.011*sin(cycle*2)*gait,-.015*gait)
	body.rotation = Vector3(-.12*gait+.17*coil-.32*drive-.13*sweep+.20*hurt-.38*evade,
			-.205*step+.43*coil-.36*drive-.67*sweep+.09*return_turn,
			.047*transfer+.11*coil-.13*drive-.16*sweep-.23*evade)
	head.rotation = Vector3(-body.rotation.x*.68-.03*drive+.07*hurt,-body.rotation.y*.70,-body.rotation.z*.64)
	silk.rotation = Vector3(-.24*gait+.08*sin(cycle*2-.72)*gait-.39*coil+.31*drive+.19*sweep+.035*breath,
			-.09*step-.28*sweep-.13*drive,.10*transfer+.17*coil-.12*sweep)
	var grip := Vector3(.092,.205,-.187)+Vector3(.025*step,.013*sin(2*cycle-.6)*gait+.007*breath,-.036*gait)
	grip += Vector3(.092,.030,.215)*coil + Vector3(-.115,.064,-.195)*drive
	grip += Vector3(-.105,.032,-.12)*sweep + Vector3(.043,.08,.04)*hurt + Vector3(.11,-.072,.06)*evade
	var tilt := .36 + .10*gait+.27*coil-.29*drive+high-.14*evade
	var swivel := .85+.11*step+.52*coil-.43*drive-.87*sweep+.19*return_turn
	if heavy:
		swivel += .62*coil-.18*return_turn
	if kind=="shield":
		grip.x += .065
		tilt += .39
		swivel -= .8
	steel.rotation = Vector3(tilt,swivel,-.38+.58*drive+.64*sweep)
	# The waist drives the thrust, but the hands level the point at the mark.
	# Otherwise the forward bow of the torso drives the heavy tip into the dirt.
	if drive > 0 and kind != "shield":
		var aim_up := .33 if action == "dragon" else (.13 if heavy else .08)
		var line := Basis.looking_at(Vector3(-.07,aim_up,-1).normalized(), Vector3.UP)
		var edge_roll := -.21 if heavy else .22
		var local_line := body.basis.inverse()*pelvis_basis.inverse()*line*Basis(Vector3.BACK,edge_roll)
		steel.basis = steel.basis.slerp(local_line,drive)
	var forward := -steel.basis.z
	var spacing := .26 + .036*coil - .076*drive
	if kind!="shield":
		grip = _two_hand_grip(grip,forward,spacing)
	steel.position = reach(1,grip,Vector3(.82,-.76,.24))
	var foregrip := steel.position + forward*spacing
	if kind=="shield":
		foregrip = Vector3(-.292,.17+drive*.042,-.197-drive*.067)
	var left_hand := reach(0,foregrip,Vector3(-.83,-.78,.19))
	if shield != null:
		shield.position = left_hand+Vector3(0,.10,.016)
		shield.rotation = Vector3(-.18+.09*drive,-.16+.18*coil,.12)
