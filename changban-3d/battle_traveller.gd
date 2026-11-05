extends Node3D

const Brush := preload("res://art/characters/mesh_brush.gd")
const INDIGO := Color("#364856")
const INDIGO_LIGHT := Color("#596972")
const CLOAK := Color("#b07a47")
const HEM := Color("#dfb779")
const HAIR := Color("#443539")
const SKIN := Color("#e4b48f")
const INK := Color("#544147")
const FACE := Vector3(0,1.165,-0.023)
const FACE_COURSES := [
	Vector4(.014,.068,.087,-.007),Vector4(.062,.151,.142,-.011),Vector4(.13,.203,.171,-.013),
	Vector4(.201,.225,.185,-.012),Vector4(.297,.222,.182,.001),Vector4(.364,.193,.154,.011),
	Vector4(.40,.128,.118,.022),
]
static var pieces := {}

var cloth := Node3D.new()
var boots: Array[MeshInstance3D] = []
var arms: Array[MeshInstance3D] = []
var child_bundle := Node3D.new()
var gait := 0.0
var carrying := 1.0

func _ready() -> void:
	if pieces.is_empty():
		pieces["body"] = _body()
		pieces["baby"] = _baby()
		pieces["boot"] = _boot()
		pieces["left"] = _arm(-1.0)
		pieces["right"] = _arm(1.0)
	add_child(cloth)
	_piece(cloth,"body",Vector3.ZERO)
	for s: float in [-1.0,1.0]:
		arms.append(_piece(cloth,"left" if s < 0 else "right",Vector3(s*.287,.983,-.016)))
		boots.append(_piece(self,"boot",Vector3(s*.129,.14,-.033)))
	child_bundle.name = "襁褓中的阿斗"
	cloth.add_child(child_bundle)
	child_bundle.position = Vector3(.025,.87,-.245)
	child_bundle.rotation.z = -.64
	_piece(child_bundle,"baby",Vector3.ZERO)

func _piece(parent: Node3D, id: String, at: Vector3) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.mesh = pieces[id]
	parent.add_child(node)
	node.position = at
	return node

func _body() -> ArrayMesh:
	var p := Brush.new()
	p.inked = true
	p.turned(Vector3.ZERO,[Vector4(.21,.33,.217,.012),Vector4(.37,.314,.211,.01),Vector4(.62,.253,.177,0),Vector4(.79,.229,.16,0),Vector4(1,.29,.182,0),Vector4(1.095,.17,.14,0)],INDIGO,22,true)
	for j in range(11):
		var angle := TAU*j/11.0
		var rad := Vector3(sin(angle),0,-cos(angle))
		var tangent := Vector3(cos(angle),0,sin(angle))
		p.blade([rad*.227+Vector3.UP*.74,rad*.268+Vector3.UP*.52,rad*.311+Vector3.UP*.35,rad*.332+Vector3.UP*.225],
			[.003,.014,.023,.009],tangent,rad,INDIGO_LIGHT if j%2 else Color("#283c4b"))
	p.turned(Vector3.ZERO,[Vector4(.711,.251,.18,0),Vector4(.751,.249,.182,0),Vector4(.775,.245,.172,0)],Color("#744d36"),20)
	p.turned(Vector3.ZERO,[Vector4(1.09,.087,.080,-.02),Vector4(1.173,.090,.076,-.018),Vector4(1.22,.078,.07,-.018)],SKIN,18,true)
	_shawl(p)
	_face(p)
	_wrap(p)
	return p.bake()

func _shawl(p) -> void:
	# Pleats are wider across the shoulders and gather at the collar. The hem
	# hangs in a long point behind her and splits higher over the cradling hands.
	const SIDES := 32
	var rows := [[],[],[],[]]
	for i in SIDES+1:
		var a := TAU*i/SIDES
		var toward_front := cos(a)
		var hem_height := .69 + .13*toward_front - .10*absf(sin(a+0.43)) + .035*cos(a*3)
		for row in 4:
			var depth: float = [0.0,.30,.68,1.0][row]
			var y: float = lerpf(1.145,hem_height,depth)
			var fold := depth*.019*(sin(a*9.0)+.45*sin(a*5+.61))
			var flare := 1.0-pow(1.0-depth,4.6)
			var rad_x := lerpf(.164,.353,flare)+fold
			var rad_z := lerpf(.132,.223,flare)+fold
			rows[row].append(Vector3(sin(a)*rad_x,y,-cos(a)*rad_z+.014))
	for row in 3:
		for i in SIDES:
			var radial := Vector3(sin((i+.5)*TAU/SIDES),0,-cos((i+.5)*TAU/SIDES))
			var tone := CLOAK.darkened(.055*(1.0+sin(i*1.68)))
			p.triangle(rows[row][i],rows[row+1][i],rows[row+1][i+1],radial,tone)
			p.triangle(rows[row][i],rows[row+1][i+1],rows[row][i+1],radial,tone)
			if row == 2:
				var a: Vector3 = rows[3][i]+radial*.002
				var b: Vector3 = rows[3][i+1]+radial*.002
				p.triangle(a,b,b+Vector3.UP*.018,radial,HEM)
				p.triangle(a,b+Vector3.UP*.018,a+Vector3.UP*.018,radial,HEM)
	# Overlapping indigo collar and a wood clasp define the diagonal wrap.
	for s: float in [-1,1]:
		p.lock([Vector3(s*.13,1.126,-.09),Vector3(s*.10,1.058,-.153),Vector3(-s*.038,.955,-.19),Vector3(-s*.18,.862,-.161)],
			[.035,.040,.029,.006],Vector3.RIGHT,Vector3.FORWARD,INDIGO_LIGHT if s<0 else INDIGO)
	p.oval(Vector3(.075,.929,-.213),Vector3(.038,.023,.012),HEM)
	# A cross-body satchel replaces the round sack; its flap and strap read from behind.
	var out := Vector3(.22,0,1).normalized()
	p.turned(Vector3(.118,.717,.228),[Vector4(-.177,.106,.046,0),Vector4(-.12,.142,.078,0),Vector4(.09,.139,.083,0),Vector4(.16,.102,.066,0)],Color("#785d48"),16,true)
	p.panel([Vector3(-.004,.806,.291),Vector3(.25,.814,.286),Vector3(.237,.738,.305),Vector3(.13,.697,.317),Vector3(.012,.744,.301)],out,.009,Color("#997453"))
	p.blade([Vector3(-.136,1.125,.069),Vector3(-.175,1.007,.181),Vector3(-.031,.876,.233),Vector3(.135,.765,.29)], [.027,.028,.024,.017],Vector3.RIGHT,out,Color("#6d513e"))

func _face_point(x: float, y: float) -> Vector3:
	var profile: Vector4 = FACE_COURSES[0]
	for i in range(1,FACE_COURSES.size()):
		var upper: Vector4 = FACE_COURSES[i]
		if y <= upper.x:
			profile = profile.lerp(upper,inverse_lerp(profile.x,upper.x,y))
			break
		profile = upper
	return FACE + Vector3(x,y,profile.w-profile.z*sqrt(maxf(.05,1.0-pow(x/profile.y,2)))-.003)

func _face(p) -> void:
	p.turned(FACE,FACE_COURSES,SKIN,26,true)
	for s: float in [-1.0,1.0]:
		p.oval(FACE+Vector3(s*.213,.165,-.008),Vector3(.038,.055,.039),SKIN)
		var left := _face_point(s*.038,.174)
		var top := _face_point(s*.102,.202)
		var corner := _face_point(s*.161,.187)
		var under := _face_point(s*.101,.150)
		p.panel([left,top,corner,under],Vector3.FORWARD,.005,Color("#ece0c8"))
		var iris := _face_point(s*.094,.174)+Vector3.FORWARD*.009
		p.oval(iris,Vector3(.021,.023,.007),Color("#624c40"),14)
		p.oval(iris+Vector3(-.004,.008,-.007),Vector3(.006,.006,.002),Color("#f5edda"),10)
		p.blade([left+Vector3.FORWARD*.004,top+Vector3.FORWARD*.006,corner+Vector3.FORWARD*.004],[.002,.008,.002],Vector3.UP,Vector3.FORWARD,INK)
		p.blade([_face_point(s*.037,.242),_face_point(s*.093,.245),_face_point(s*.17,.231)],[.006,.009,.002],Vector3.UP,Vector3.FORWARD,HAIR)
		p.blade([_face_point(s*.109,.134),_face_point(s*.14,.136),_face_point(s*.16,.139)],[.001,.004,.001],Vector3.UP,Vector3.FORWARD,Color("#c88f78"))
	var nose := _face_point(0,.15)
	p.panel([nose+Vector3(-.015,.026,0),nose+Vector3(.016,.023,0),nose+Vector3(.018,-.019,.004),nose+Vector3(-.015,-.012,.003)],Vector3.FORWARD,.019,Color("#d8a17e"))
	p.blade([_face_point(-.038,.086),_face_point(.001,.091),_face_point(.038,.085)],[.002,.006,.001],Vector3.UP,Vector3.FORWARD,Color("#975e58"))

func _wrap(p) -> void:
	# A skewed wrap leaves the forehead open below a thick folded indigo band.
	var crown := FACE+Vector3(0,0,.009)
	_nape(p,crown)
	p.turned(crown,[Vector4(.277,.229,.195,0),Vector4(.307,.24,.205,0),Vector4(.365,.234,.196,.009),Vector4(.416,.196,.17,.023),Vector4(.446,.115,.098,.03),Vector4(.453,.030,.040,.026)],INDIGO,24,true)
	for band in 2:
		var pts := []
		for i in 25:
			var a := TAU*i/24.0
			pts.append(crown+Vector3(sin(a)*(.235+band*.001),.286+band*.041+.024*sin(a-.35),-cos(a)*(.198+band*.001)))
		p.blade(pts, _widths(pts.size(),.011 if band==0 else .007),Vector3.UP,Vector3.FORWARD,INDIGO_LIGHT if band==0 else Color("#647679"))
	for s: float in [-1.0,1.0]:
		var rad := Vector3(s*.75,0,-.65).normalized()
		p.lock([FACE+Vector3(s*.151,.289,-.111),FACE+Vector3(s*.190,.248,-.099),FACE+Vector3(s*.20,.179,-.060),FACE+Vector3(s*.192,.145,-.041)],[.039,.042,.021,.002],Vector3.UP,rad,HAIR)
	for i in 3:
		var offset := float(i)*.084
		p.lock([FACE+Vector3(.101-offset,.311,-.141),FACE+Vector3(.069-offset,.284,-.175),FACE+Vector3(.011-offset,.257,-.17+absf(offset-.06)*.31)],
			[.025,.025,.002],Vector3.RIGHT,Vector3.FORWARD,HAIR if i%2==0 else Color("#594139"))
	# Knotted release ends give the head a clear silhouette at the back.
	p.oval(crown+Vector3(-.163,.267,.141),Vector3(.071,.056,.064),INDIGO_LIGHT)
	p.lock([crown+Vector3(-.15,.265,.155),crown+Vector3(-.102,.186,.212),crown+Vector3(-.134,.075,.231),crown+Vector3(-.19,-.065,.197)],
		[.040,.062,.057,.011],Vector3.RIGHT,Vector3.BACK,INDIGO)
	p.lock([crown+Vector3(-.157,.26,.15),crown+Vector3(-.218,.192,.136),crown+Vector3(-.249,.093,.104),crown+Vector3(-.244,.026,.064)],
		[.033,.043,.035,.006],Vector3.RIGHT,Vector3.LEFT,INDIGO_LIGHT)

func _nape(p, crown: Vector3) -> void:
	# The gathered hair lies between the bare cheek and the scarf knot. It tapers
	# down the nape towards a low bun, rather than exposing a flesh-coloured scalp.
	var previous := []
	for i in 29:
		var angle := deg_to_rad(62.0 + i*236.0/28.0)
		var back := clampf(-cos(angle)+.20,0.0,1.0)
		var radial := Vector3(sin(angle),0,-cos(angle))
		var row := [
			crown+radial*.001+Vector3(sin(angle)*.235,.289,-cos(angle)*.194),
			crown+Vector3(sin(angle)*.229,.201,-cos(angle)*.192),
			crown+Vector3(sin(angle)*.210,.134,-cos(angle)*.183),
			crown+Vector3(sin(angle)*lerpf(.201,.136,back),.126-back*.095,-cos(angle)*lerpf(.174,.144,back)),
		]
		if not previous.is_empty():
			var tone := HAIR.lightened(.045*(1.0+sin(angle*12.0)))
			for j in 3:
				p.triangle(previous[j],row[j],row[j+1],radial,tone)
				p.triangle(previous[j],row[j+1],previous[j+1],radial,tone)
		previous = row
	var bun := crown+Vector3(.035,.093,.177)
	p.turned(bun,[Vector4(-.069,.036,.043,.015),Vector4(-.049,.085,.064,.012),Vector4(.011,.116,.084,.01),Vector4(.065,.081,.055,.006),Vector4(.076,.037,.021,0)],HAIR,18,true)
	p.blade([bun+Vector3(-.085,.032,.036),bun+Vector3(-.023,.045,.079),bun+Vector3(.055,.024,.072),bun+Vector3(.089,-.009,.049)],[.003,.009,.008,.001],Vector3.UP,Vector3.BACK,Color("#715347"))

func _widths(count: int, width: float) -> Array:
	var out := []
	out.resize(count)
	out.fill(width)
	return out

func _arm(s: float) -> ArrayMesh:
	var p := Brush.new()
	p.inked = true
	var elbow := Vector3(s*.046,-.136,-.065)
	var wrist := Vector3(-s*.101,-.15,-.214)
	p.shaft(Vector3.ZERO,elbow,.086,.077,CLOAK,12)
	p.shaft(elbow,wrist,.078,.052,INDIGO_LIGHT,12)
	p.shaft(elbow.lerp(wrist,.70),elbow.lerp(wrist,.88),.059,.056,Color("#85908c"),12)
	p.oval(wrist+Vector3(-s*.020,0,-.018),Vector3(.056,.042,.060),SKIN)
	return p.bake()

func _boot() -> ArrayMesh:
	var p := Brush.new()
	p.turned(Vector3.ZERO,[Vector4(-.139,.084,.145,-.021),Vector4(-.117,.091,.15,-.024),Vector4(-.066,.092,.148,-.021),Vector4(.014,.079,.094,.013),Vector4(.075,.083,.092,.02)],Color("#49423d"),16,true)
	p.turned(Vector3.ZERO,[Vector4(-.122,.092,.151,-.024),Vector4(-.106,.092,.151,-.024)],Color("#9f8865"),16,true)
	return p.bake()

func _baby() -> ArrayMesh:
	var p := Brush.new()
	p.inked = true
	p.turned(Vector3.ZERO,[Vector4(-.274,.051,.053,.012),Vector4(-.212,.118,.095,.011),Vector4(-.118,.155,.119,.004),Vector4(.007,.16,.132,0),Vector4(.098,.136,.116,0),Vector4(.146,.106,.096,.002)],Color("#bc8442"),22,true)
	var out := Vector3.FORWARD
	p.panel([Vector3(-.145,.044,-.08),Vector3(.113,.092,-.07),Vector3(.147,-.025,-.075),Vector3(-.097,-.168,-.094)],out,.032,Color("#e0b562"))
	p.blade([Vector3(-.139,.049,-.087),Vector3(-.012,.064,-.146),Vector3(.129,.091,-.071)],[.008,.011,.007],Vector3.UP,out,Color("#fae0a0"))
	p.panel([Vector3(-.121,-.074,-.10),Vector3(.149,-.025,-.077),Vector3(.102,-.169,-.085),Vector3(-.052,-.235,-.067)],out,.019,Color("#cc984f"))
	p.turned(Vector3(0,.155,.001),[Vector4(-.073,.136,.109,0),Vector4(.008,.15,.127,0),Vector4(.091,.143,.113,.012),Vector4(.139,.10,.086,.016),Vector4(.155,.052,.050,.016)],Color("#e7bf76"),18,true)
	var face := Vector3(0,.166,-.082)
	p.turned(face,[Vector4(-.086,.052,.048,0),Vector4(-.061,.088,.066,-.005),Vector4(.006,.111,.083,-.007),Vector4(.063,.105,.072,0),Vector4(.089,.073,.059,.004)],Color("#f2c39d"),20,true)
	for s: float in [-1.0,1.0]:
		p.blade([face+Vector3(s*.029,.008,-.087),face+Vector3(s*.055,.003,-.084),face+Vector3(s*.083,.012,-.066)],[.002,.005,.001],Vector3.UP,out,Color("#765451"))
		p.oval(face+Vector3(s*.074,-.016,-.070),Vector3(.018,.008,.004),Color("#df9e85"),12)
	p.lock([face+Vector3(.042,.079,-.037),face+Vector3(.006,.071,-.055),face+Vector3(-.028,.052,-.071)],[.014,.014,.001],Vector3.RIGHT,out,HAIR)
	p.blade([face+Vector3(-.014,-.038,-.080),face+Vector3(.004,-.042,-.081),face+Vector3(.02,-.036,-.078)],[.002,.004,.001],Vector3.UP,out,Color("#b17267"))
	p.lock([Vector3(-.142,-.045,-.09),Vector3(-.022,-.083,-.134),Vector3(.118,-.108,-.081)],[.012,.015,.009],Vector3.UP,out,Color("#9c5544"))
	return p.bake()

func advance(dt: float, speed: float) -> void:
	gait += dt*(2.0+2.4*speed)
	var stride := clampf(speed/3.0,0.0,1.0)
	cloth.position.y = absf(sin(gait))*.029*stride
	cloth.rotation.z = sin(gait)*stride*.036
	carrying = move_toward(carrying,1.0 if child_bundle.get_parent()==cloth else 0.0,dt*3.6)
	for i in boots.size():
		var step := sin(gait+i*PI)
		boots[i].position.y = .14+maxf(0.0,step)*.075*stride
		boots[i].position.z = -.033-.105*step*stride
		arms[i].rotation.x = (1.0-carrying)*(-.74+step*.16*stride)
