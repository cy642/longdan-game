extends Node3D

const WarriorArt := preload("res://art/characters/warrior_art.gd")
const UPPER := .249
const LOWER := .206
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
var arms: Array[Node3D] = []
var wrists: Array[Node3D] = []

func configure(who: String) -> void:
	if who == kind and rig != null:
		return
	if rig != null:
		remove_child(rig)
		rig.queue_free()
		thighs.clear()
		shins.clear()
		arms.clear()
		wrists.clear()
		shield = null
	kind = who
	if not mesh_library.has(kind):
		var sculpt := WarriorArt.new(kind)
		var parts := {}
		for id: String in ["thigh_l","thigh_r","shin_l","shin_r","arm_l","arm_r","wrist_l","wrist_r","body","head","scarf","weapon"]:
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
		shins.append(part("shin"+suffix,leg,Vector3(0,-.33,0)))
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

# Authored action phase is normalized, while gait is a distance-driven phase in
# radians. There is no private clock, allowing hit-stop to freeze the whole pose.
func pose(action: String, phase: float, walk_phase: float, moving: float) -> void:
	if rig == null:
		return
	var t := clampf(phase,0,1)
	var stride := clampf(moving,0,1)
	var step := sin(walk_phase)*stride
	var bounce := (1.0-cos(2.0*walk_phase))*.013*stride
	var winding := 0.0
	var strike := 0.0
	var follow := 0.0
	var hurt := 0.0
	var evade := 0.0
	var fallen := 0.0
	var heavy := action == "heavy"
	if action == "attack" or heavy:
		# Anticipation, full extension and recovery are three distinct silhouettes.
		# Peak extension coincides with the actual combat contact, including the
		# commander's short release after his longer heavy wind-up.
		var contact := .49 if heavy and kind == "hero" else .38
		var release := contact-.133
		winding = smoothstep(.0,release,t)*(1.0-smoothstep(release,contact,t))
		strike = smoothstep(release,contact,t)*(1.0-smoothstep(.58,.96,t))
		follow = smoothstep(.52,.69,t)*(1.0-smoothstep(.72,1.0,t))
	elif action == "hurt":
		hurt = sin(PI*t)
	elif action == "dodge":
		evade = sin(PI*t)
	elif action == "down":
		fallen = smoothstep(.0,.89,t)
	var weight := stride*.014 + winding*.052 + strike*.057 + evade*.20
	var size_factor := rig.scale.x
	rig.position = Vector3(.018*step, -weight+bounce, -strike*.063+hurt*.047)*size_factor
	# A falling character rolls onto their side as the root lowers to the ground.
	rig.rotation = Vector3(-.14*fallen,.0,-1.43*fallen)
	rig.position.y += fallen*.17*size_factor
	body.position = Vector3(.017*step,.70+bounce,-.015*stride)
	body.rotation = Vector3(-.065*stride+.14*winding-.25*strike+.21*hurt-.33*evade,
		-.047*step+.44*winding-.47*strike-.10*follow,.04*step+.09*winding-.12*strike-.23*evade)
	head.rotation = Vector3(-body.rotation.x*.51-.061*strike+.08*hurt,-body.rotation.y*.62,-body.rotation.z*.48)
	silk.rotation = Vector3(-.09*stride-.29*winding+.31*strike+.057*sin(walk_phase*2)*stride,
		.08*step-.18*strike,.085*step+.14*winding)
	for i in 2:
		var s := -1.0 if i == 0 else 1.0
		var travel := step*s
		var lift := maxf(0,cos(walk_phase)*s)*stride
		thighs[i].rotation = Vector3(travel*.61+lift*.19 + (winding*.32-strike*.38)*s + evade*.53,
			-.04*s*(stride+strike),s*(.035+strike*.115+evade*.18))
		shins[i].rotation.x = -lift*.62-stride*.085-winding*.15-strike*.15-evade*.90
	var grip := Vector3(.094,.210,-.229) + Vector3(.028*step, bounce, -.026*stride)
	grip += Vector3(.135,.034,.219)*winding + Vector3(-.052,.067,-.157)*strike
	grip += Vector3(.04,.062,.017)*hurt + Vector3(.113,-.075,.065)*evade
	var tilt := .43+stride*.12+winding*.28-strike*.23-evade*.13
	var yaw := .80+.053*step+winding*.46-strike*.40+follow*.14
	if kind == "shield":
		grip.x += .07
		tilt += .41
		yaw -= .81
	if heavy:
		yaw += winding*.72-follow*.69
		tilt += winding*.50-strike*.12
	steel.rotation = Vector3(tilt,yaw,-.47+strike*.79)
	steel.position = reach(1,grip,Vector3(.82,-.76,.24))
	var foregrip := steel.position + steel.basis*Vector3(0,0,-.36)
	if kind == "shield":
		foregrip = Vector3(-.292,.17+strike*.042,-.197-strike*.067)
	var left_hand := reach(0,foregrip,Vector3(-.83,-.78,.19))
	if shield != null:
		shield.position = left_hand+Vector3(0,.10,.016)
		shield.rotation = Vector3(-.18+.09*strike,-.16+.18*winding,.12)
