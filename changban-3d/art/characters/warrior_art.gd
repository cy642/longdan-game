extends RefCounted

const Brush := preload("res://art/characters/mesh_brush.gd")
const HERO_EYE := preload("res://art/characters/zhaoyun_eye.svg")
const INK := Color("#28344a")
const LEATHER := Color("#5a3733")
const SKIN := Color("#f2bd94")
const BROWN := Color("#854833")
const COPPER := Color("#bc7548")
const GOLD := Color("#edc47f")
const MILK := Color("#e7edf1")
const HEAD_SCALE := 1.18
const F := Vector3.FORWARD
var kind: String
var coat: Color
var cloth: Color
var bright: Color
var iron: Color
var rim: Color
var pen: Brush
static var eye_materials := {}

func _init(who: String) -> void:
	kind = who
	match kind:
		"hero":
			coat = Color("#303c68"); cloth = Color("#2064ac"); bright = Color("#52c4ed")
			iron = Color("#939fbd"); rim = Color("#eff1f5")
		"shield":
			coat = Color("#374848"); cloth = Color("#a15c37"); bright = Color("#db9f55")
			iron = Color("#6e8279"); rim = Color("#c4b493")
		"commander":
			coat = Color("#412e3b"); cloth = Color("#922f39"); bright = Color("#dd5b4b")
			iron = Color("#5b5262"); rim = GOLD
		_:
			coat = Color("#345150"); cloth = Color("#527867"); bright = Color("#a7bba0")
			iron = Color("#74898b"); rim = Color("#c0c8b5")

func build(part: String) -> ArrayMesh:
	pen = Brush.new()
	pen.inked = kind == "hero"
	var side := -1.0 if part.ends_with("_l") else 1.0
	if part.begins_with("thigh"): thigh(side)
	elif part.begins_with("shin"): shin(side)
	elif part.begins_with("foot"): foot(side)
	elif part.begins_with("arm"): arm(side)
	elif part.begins_with("wrist"): wrist(side)
	else:
		match part:
			"body": body()
			"head": head()
			"scarf": scarf()
			"weapon": weapon()
			"shield": shield()
	if part == "head" and kind == "hero":
		for i in pen.vertices.size():
			pen.vertices[i] *= HEAD_SCALE
		for i in pen.textured_positions.size():
			pen.textured_positions[i] *= HEAD_SCALE
	var mesh := pen.bake()
	if part == "head":
		add_painted_eyes(mesh)
	return mesh

func profile(center: Vector3, rings: Array, color: Color, sides := 12) -> void:
	pen.turned(center,rings,color,maxi(18,sides) if kind=="hero" else sides,kind=="hero")

func front(points: Array, relief: float, color: Color) -> void:
	pen.panel(points,F,relief,color)

func thigh(s: float) -> void:
	profile(Vector3.ZERO,[Vector4(-.31,.087,.1,0),Vector4(-.20,.123,.128,0),Vector4(-.04,.153,.148,0),Vector4(.035,.10,.12,0)],coat)
	# Overlapping outer tassets protect the hip without hiding leg separation.
	var outside := Vector3(s*.8,0,-.7).normalized()
	for layer in 2:
		var y := -.065-layer*.083
		var edge := .128-layer*.002
		pen.panel([Vector3(s*.005,y,-.126),Vector3(s*edge,y+.025,-.09),
			Vector3(s*(edge+.018),y-.052,.065),Vector3(s*(edge+.008),y-.125,-.023),
			Vector3(s*.045,y-.094,-.143)],outside,.019,rim if layer == 0 else iron)

func shin(s: float) -> void:
	profile(Vector3.ZERO,[Vector4(-.235,.086,.093,0),Vector4(-.17,.082,.085,0),Vector4(-.045,.093,.092,0)],LEATHER)
	profile(Vector3.ZERO,[Vector4(-.252,.092,.096,0),Vector4(-.125,.106,.101,0),Vector4(-.021,.102,.099,0)],iron)
	front([Vector3(-.075,-.025,-.065),Vector3(0,.038,-.108),Vector3(.082,-.038,-.069),
		Vector3(.062,-.16,-.087),Vector3(s*.012,-.241,-.105),Vector3(-.062,-.17,-.085)],.028,rim)
	pen.blade([Vector3(0,-.029,-.13),Vector3(s*.01,-.111,-.142),Vector3(s*.01,-.19,-.116)],
		[.013,.01,.001],Vector3.RIGHT,F,iron)

	if kind == "hero":
		curved_plate(.082,.056,-.087,.056,-.018,-.219,Vector3.FORWARD,Brush.SILVER)

func foot(s: float) -> void:
	# The ankle hinge is .215 below the knee. The sole rests .110 below it.
	var leather := Color("#3e465f") if kind == "hero" else LEATHER
	profile(Vector3.ZERO,[Vector4(-.110,.087,.146,-.052),Vector4(-.094,.103,.163,-.058),
		Vector4(-.066,.10,.167,-.068),Vector4(-.036,.092,.153,-.063),Vector4(.012,.085,.112,-.027),
		Vector4(.062,.078,.086,0)],leather)
	profile(Vector3.ZERO,[Vector4(-.109,.089,.15,-.053),Vector4(-.095,.104,.165,-.058)],INK)
	if kind == "hero":
		pen.turned(Vector3(0,-.016,-.085),[Vector4(-.075,.083,.126,-.021),Vector4(-.052,.102,.137,-.015),
			Vector4(-.020,.098,.11,-.005),Vector4(.025,.071,.055,-.004)],iron,18,true)
		pen.blade([Vector3(s*.086,-.067,-.134),Vector3(s*.078,-.042,-.174),Vector3(0,-.066,-.226)],
			[.008,.012,.003],Vector3.UP,Vector3.FORWARD,rim)

# Raised, fitted plates and embroidered cloth share the illustrated atlas. The
# lateral curvature is explicit so contours survive an orbit of the camera.
func curved_plate(top_half: float, bottom_half: float, z: float, bow: float, top: float, bottom: float, out: Vector3, tile: Vector2) -> void:
	var grid := []
	for iy in 9:
		var v := float(iy)/8.0
		for ix in 13:
			var u := float(ix)/6.0-1.0
			var x := lerpf(top_half,bottom_half,v)*u
			var y := lerpf(top,bottom,v) + .035*u*u*(v-.5)
			grid.append(Vector3(x,y,z) + out*bow*(1.0-u*u))
	pen.painted_grid(grid,13,9,tile,out)

func body() -> void:
	profile(Vector3.ZERO,[Vector4(-.091,.265,.177,.018),Vector4(.035,.272,.171,.01),
		Vector4(.11,.221,.155,0),Vector4(.24,.258,.175,0),Vector4(.39,.34,.204,0),
		Vector4(.47,.315,.174,0),Vector4(.51,.146,.128,0)],coat)
	# The whole breastplate is curved; rim, collar, and etched wings wrap it.
	pen.turned(Vector3.ZERO,[Vector4(.195,.24,.17,-.003),Vector4(.265,.268,.197,-.004),
		Vector4(.392,.329,.22,0),Vector4(.443,.3,.193,0)],iron,14,kind == "hero")
	# Backplate seams and the shoulder harness read from the combat camera.
	for s: float in [-1.,1.]:
		var out := Vector3(s*.2,0,1)
		pen.panel([Vector3(s*.027,.392,.205),Vector3(s*.209,.418,.145),
			Vector3(s*.239,.349,.123),Vector3(s*.137,.292,.195),Vector3(s*.051,.279,.204)],out,.017,rim)
		pen.blade([Vector3(s*.214,.418,.161),Vector3(s*.148,.338,.207),
			Vector3(s*.049,.292,.226)],[.015,.012,.004],Vector3.RIGHT,out,iron)
	for s: float in [-1.0,1.0]:
		front([Vector3(s*.014,.285,-.207),Vector3(s*.182,.414,-.177),Vector3(s*.269,.423,-.135),
			Vector3(s*.226,.329,-.166),Vector3(s*.102,.239,-.199)],.023,rim)
		pen.blade([Vector3(s*.037,.299,-.229),Vector3(s*.154,.349,-.222),Vector3(s*.217,.399,-.168)],
			[.009,.011,.001],Vector3.UP,F,INK)
	profile(Vector3.ZERO,[Vector4(.125,.234,.171,0),Vector4(.169,.247,.181,0),Vector4(.187,.244,.176,0)],rim)
	profile(Vector3.ZERO,[Vector4(.033,.265,.183,.002),Vector4(.118,.238,.171,.002)],cloth)
	front([Vector3(-.064,.079,-.18),Vector3(0,.133,-.166),Vector3(.064,.079,-.18),Vector3(0,.025,-.184)],.016,GOLD)
	# Layered, tapered robe panels in front and behind; bent hinges move the legs below.
	for dir: float in [-1.0,1.0]:
		var out := Vector3(0,0,dir)
		var z := .173*dir
		pen.panel([Vector3(-.177,.038,z),Vector3(.178,.038,z),Vector3(.174,-.177,z*1.13),
			Vector3(.059,-.31,z*1.2),Vector3(-.151,-.226,z*1.13)],out,.022,coat)
		pen.blade([Vector3(-.166,.021,z*1.07),Vector3(-.14,-.215,z*1.18),Vector3(.059,-.305,z*1.23)],
			[.014,.011,.004],Vector3.RIGHT,out,rim)
		pen.blade([Vector3(.006,-.065,z*1.16),Vector3(.008,-.159,z*1.25),Vector3(.05,-.228,z*1.26)],
			[.024,.038,.001],Vector3.RIGHT,out,cloth)
	profile(Vector3(0,.483,0),[Vector4(.0,.169,.14,0),Vector4(.056,.16,.138,0),Vector4(.091,.112,.11,0)],cloth)
	pen.oval(Vector3(0,.559,0),Vector3(.105,.107,.095),SKIN)
	if kind == "hero":
		for zsign: float in [-1,1]:
			var out := Vector3.BACK*zsign
			curved_plate(.24,.168,.162*zsign,.086,.419,.195,out,Brush.SILVER)
			curved_plate(.177,.20,.19*zsign,.053,.05,-.295,out,Brush.WEAVE)
		# Crossed collar with a leather binding; the flap sits above the sash.
		pen.blade([Vector3(-.149,.469,-.117),Vector3(-.088,.409,-.217),Vector3(.056,.329,-.235)],
			[.023,.019,.003],Vector3.RIGHT,F,cloth)

func arm(s: float) -> void:
	profile(Vector3.ZERO,[Vector4(-.244,.083,.092,0),Vector4(-.13,.097,.10,0),
		Vector4(-.022,.119,.116,0),Vector4(.026,.087,.088,0)],coat)
	for i in 3:
		var y := .025-i*.058
		var w := .160+i*.005
		pen.turned(Vector3(s*.01,y,0),[Vector4(-.075,w,.132,0),Vector4(-.052,w*.97,.131,0),
			Vector4(-.006,w*.79,.115,0),Vector4(.032,w*.41,.08,0)],iron if i%2 == 0 else rim,14,kind == "hero")
	# Ridge crest lies outside the pauldron and reads from either camera side.
	var out := Vector3(s,0,-.28).normalized()
	pen.panel([Vector3(s*.133,.069,-.066),Vector3(s*.158,.057,.04),
		Vector3(s*.177,-.023,.105),Vector3(s*.156,-.121,-.007),Vector3(s*.161,-.042,-.104)],out,.024,rim)
	pen.blade([Vector3(s*.163,.03,-.072),Vector3(s*.194,-.004,-.022),Vector3(s*.165,-.078,.04)],
		[.008,.013,.003],Vector3.FORWARD,out,cloth)
	if kind == "hero":
		# Enamel shoulder cap spans the front and outer flank of each pauldron.
		var grid := []
		for iy in 9:
			var v := float(iy)/8.0
			for ix in 15:
				var a := lerpf(-1.12,1.17,float(ix)/14)
				var radius := .166 - .045*(1-v)*(1-v)
				grid.append(Vector3(s*(.014+radius*cos(a)),.065-.199*v+.035*cos(a)*(1-v),radius*sin(a)))
		pen.painted_grid(grid,15,9,Brush.SILVER,Vector3(s,0,0))

func wrist(s: float) -> void:
	profile(Vector3.ZERO,[Vector4(-.166,.07,.066,0),Vector4(-.112,.082,.084,0),
		Vector4(-.018,.09,.09,0),Vector4(.032,.072,.077,0)],iron)
	profile(Vector3.ZERO,[Vector4(-.149,.078,.077,0),Vector4(-.124,.084,.083,0)],rim)
	if kind != "hero":
		pen.oval(Vector3(0,-.198,-.01),Vector3(.079,.082,.073),SKIN)
		return
	# A palm in a fingerless gauntlet, with bent knuckles around the grip.
	pen.oval(Vector3(0,-.189,.003),Vector3(.066,.071,.052),coat,14)
	for j in 4:
		var off := -.048+j*.031
		pen.oval(Vector3(off,-.218+.009*absf(j-1.5),-.033),Vector3(.022,.038,.032),SKIN,12)
	pen.oval(Vector3(-s*.048,-.193,-.042),Vector3(.029,.050,.031),Color("#efbe99"),12)
	curved_plate(.067,.055,-.063,.028,.013,-.136,F,Brush.SILVER)

func head() -> void:
	pen.turned(Vector3.ZERO,[Vector4(.026,.085,.132,-.015),Vector4(.07,.184,.202,-.018),
		Vector4(.149,.273,.249,-.018),Vector4(.245,.325,.267,-.008),Vector4(.359,.332,.271,0),
		Vector4(.455,.308,.256,.008),Vector4(.526,.246,.222,.016),Vector4(.565,.157,.157,.025)],SKIN,20,true)
	# Modelled skin tone graduates from warm temples to lit cheeks and chin.
	var complexion := Color("#ffe0c5") if kind=="hero" else Color("#e8c4a1")
	for i in pen.vertices.size():
		var p := pen.vertices[i]
		var shade := smoothstep(.15,.48,p.y)*.34 + smoothstep(-.23,.18,p.z)*.34
		var blush := exp(-pow((absf(p.x)-.203)/.087,2)-pow((p.y-.175)/.057,2)) * smoothstep(.00,.19,-p.z)
		pen.colors[i] = complexion.lerp(Color("#bd8e80"),shade).lerp(Color("#e79987"),blush*.48)
	for s: float in [-1.0,1.0]:
		pen.oval(Vector3(s*.31,.244,.005),Vector3(.061,.085,.05),SKIN)
	if kind == "hero":
		face_mark([Vector2(-.014,.195),Vector2(-.008,.18),Vector2(.005,.178),Vector2(.015,.184),
			Vector2(.004,.181)],Color("#ba8771"))
		face_mark([Vector2(-.041,.12),Vector2(-.016,.124),Vector2(.009,.122),Vector2(.043,.115),
			Vector2(.018,.116),Vector2(-.011,.118)],Color("#845c52"))
		hair()
	else:
		var nz := -.279
		front([Vector3(-.018,.204,nz+.013),Vector3(.018,.199,nz+.012),Vector3(0,.177,nz)],.010,Color("#e4a881"))
		pen.blade([Vector3(-.036,.121,-.245),Vector3(.004,.118,-.255),Vector3(.043,.129,-.244)],
			[.002,.007,.001],Vector3.UP,F,Color("#855749"))
		helm()
		if kind == "commander":
			for s: float in [-1,1]:
				pen.lock([Vector3(s*.014,.143,-.255),Vector3(s*.048,.147,-.259),
					Vector3(s*.089,.127,-.233),Vector3(s*.122,.137,-.219)],
					[.005,.015,.011,.002],Vector3.UP,F,Color("#624437"))
			pen.lock([Vector3(0,.076,-.22),Vector3(0,.058,-.207),Vector3(.008,.025,-.188)],
				[.025,.032,.002],Vector3.RIGHT,F,Color("#63463a"))

func cheek_surface(x: float, y: float) -> Vector3:
	var low := Vector4(.149,.273,.249,-.018)
	var high := Vector4(.245,.325,.267,-.008)
	if y < .149:
		high = low
		low = Vector4(.07,.184,.202,-.018)
	elif y >= .245:
		low = high
		high = Vector4(.359,.332,.271,0)
	var course := low.lerp(high,clampf((y-low.x)/(high.x-low.x),0,1))
	return Vector3(x,y,course.w-course.z*sqrt(maxf(.01,1.0-pow(x/course.y,2)))-.002)

func face_mark(line: Array, ink: Color) -> void:
	var points := []
	for pt: Vector2 in line:
		points.append(cheek_surface(pt.x,pt.y))
	pen.panel(points,F,.0004,ink)

func add_painted_eyes(mesh: ArrayMesh) -> void:
	# Paint hugs the actual cheek profile. Both eyes share a single small
	# illustrated texture, with a mirrored upper lid and a clipped iris.
	var verts := PackedVector3Array()
	var norms := PackedVector3Array()
	var uv := PackedVector2Array()
	var indices := PackedInt32Array()
	const COLUMNS := 10
	const ROWS := 5
	for side: float in [-1.0,1.0]:
		var base := verts.size()
		for row in ROWS+1:
			var v := float(row)/ROWS
			for column in COLUMNS+1:
				var u := float(column)/COLUMNS
				var x := side*lerpf(.022,.286,u)
				var y := lerpf(.369,.115,v)
				if kind != "hero":
					x = side*lerpf(.035,.267,u)
					y = lerpf(.332,.147,v)
				verts.append(cheek_surface(x,y)*(HEAD_SCALE if kind=="hero" else 1.0))
				var dx := cheek_surface(x+.001,y)-cheek_surface(x-.001,y)
				var dy := cheek_surface(x,y+.001)-cheek_surface(x,y-.001)
				norms.append(dy.cross(dx).normalized())
				uv.append(Vector2(u,v))
				if row < ROWS and column < COLUMNS:
					var a := base+row*(COLUMNS+1)+column
					var b := a+1
					var c := a+COLUMNS+1
					var d := c+1
					if side > 0:
						indices.append_array([a,c,b,b,c,d])
					else:
						indices.append_array([a,b,c,b,d,c])
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = norms
	arrays[Mesh.ARRAY_TEX_UV] = uv
	arrays[Mesh.ARRAY_INDEX] = indices
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
	if not eye_materials.has(kind):
		var eye_paint := ShaderMaterial.new()
		eye_paint.shader = preload("res://art/characters/hero_gaze.gdshader")
		eye_paint.set_shader_parameter("drawing",HERO_EYE)
		eye_paint.set_shader_parameter("amber",0.0 if kind == "hero" else 1.0)
		eye_paint.set_shader_parameter("offset",{"hero":0.0,"guard":.9,"shield":2.7,"commander":1.9}[kind])
		eye_materials[kind] = eye_paint
	mesh.surface_set_material(mesh.get_surface_count()-1,eye_materials[kind])

func hair() -> void:
	# Blue cloth appears between the fringe and eyebrows, with a high trailing knot.
	profile(Vector3.ZERO,[Vector4(.354,.343,.284,0),Vector4(.413,.347,.275,0),Vector4(.448,.334,.274,0)],cloth,20)
	pen.turned(Vector3.ZERO,[Vector4(.402,.347,.291,.018),Vector4(.487,.354,.291,.037),
		Vector4(.562,.313,.272,.056),Vector4(.624,.253,.218,.068),Vector4(.652,.127,.122,.081),
		Vector4(.659,.031,.028,.081)],BROWN,20,true)
	paint_crown()
	# The lower cap hugs the occiput and stops behind the cheeks. Folded nape
	# locks overlap it; the small blue bow sits above the hair at the collar.
	profile(Vector3(0,0,.092),[Vector4(.106,.133,.12,.04),Vector4(.17,.263,.183,.017),
		Vector4(.277,.311,.199,.014),Vector4(.387,.327,.217,.009),
		Vector4(.505,.307,.196,.001)],BROWN.darkened(.22),14)
	for s: float in [-1.0,1.0]:
		var axis := Vector3(s*.57,0,-.82)
		for j in 4:
			var z := -.144+j*.096
			var start := Vector3(s*.235,.55-j*.025,z)
			var mid := Vector3(s*(.326+j*.009),.418-j*.029,z+.052)
			var tip := Vector3(s*(.317+j*.019),.217+j*.009,z+.147)
			pen.lock([start,start.lerp(mid,.57)+Vector3(s*.014,.006,0),mid,mid.lerp(tip,.65),tip],
				[.072,.097,.087,.047,.001],axis,Vector3(s,.05,.13),BROWN.darkened(.048*j),true)
	# Forelocks sweep in a single direction; the asymmetric contour defines the hero.
	var locks := [
		[Vector3(-.18,.58,-.112),Vector3(-.255,.474,-.202),Vector3(-.301,.309,-.155)],
		[Vector3(-.088,.612,-.10),Vector3(-.164,.48,-.24),Vector3(-.192,.332,-.241)],
		[Vector3(-.07,.617,-.096),Vector3(.022,.492,-.265),Vector3(.126,.321,-.271)],
		[Vector3(.015,.601,-.085),Vector3(.126,.49,-.24),Vector3(.263,.363,-.206)],
		[Vector3(.102,.579,-.068),Vector3(.231,.495,-.178),Vector3(.348,.389,-.117)]]
	for i in locks.size():
		var path: Array = locks[i]
		var root: Vector3 = path[0]
		var joint: Vector3 = path[1]
		var tip: Vector3 = path[2]
		pen.lock([root,root.lerp(joint,.55)+Vector3(0,.012,-.009),joint,
			joint.lerp(tip,.59)+Vector3(.008,0,-.004),tip],[.072,.106,.093,.054,.001],
			Vector3.RIGHT,Vector3(0,.12,-1),BROWN.lightened(.042*(i%3)),true)
		if i == 1 or i == 3:
			pen.lock([root.lerp(joint,.33)+F*.05,root.lerp(joint,.64)+F*.055,root.lerp(joint,.82)+F*.051],
				[.001,.009,.001],Vector3.RIGHT,F,COPPER)
	# Crown strands fan from the left part into a swept outer contour.
	for j in 3:
		var dz := j*.076
		pen.lock([Vector3(-.207,.558,-.091+dz),Vector3(-.118,.631,-.091+dz),
			Vector3(.021,.674,-.07+dz),Vector3(.159,.667,-.041+dz),
			Vector3(.281,.623,.007+dz),Vector3(.347-j*.012,.587+j*.018,.056+dz)],
			[.067,.09,.095,.082,.044,.001],Vector3.FORWARD,Vector3.UP,BROWN.lightened(.028*(2-j)),true)
	pen.lock([Vector3(-.147,.586,.104),Vector3(-.073,.658,.13),Vector3(.024,.693,.174),
		Vector3(.111,.722,.216),Vector3(.158,.753,.267)],
		[.065,.076,.067,.033,.001],Vector3.FORWARD,Vector3.UP,BROWN.darkened(.07),true)
	# Fan-shaped layered nape and band knot remain visible from the chase camera.
	for j in 6:
		var x := -.245+j*.095
		pen.lock([Vector3(x*.83,.545,.236),Vector3(x*.97,.43,.285),Vector3(x,.356,.293),
			Vector3(x*1.09,.226,.28),Vector3(x*1.12,.145+absf(x)*.18,.252)],
			[.052,.078,.068,.042,.001],Vector3.RIGHT,Vector3.BACK,BROWN.darkened(.04*(j%3)),true)
	# Long, swept tufts break the round outline in three-quarter and rear view.
	for s: float in [-1,1]:
		for j in 3:
			var y := .53 - j*.098
			pen.lock([Vector3(s*.20,y+.045,.12),Vector3(s*.30,y+.025,.19),
				Vector3(s*.363,y-.014,.26),Vector3(s*(.44-j*.018),y+.004,.32),
				Vector3(s*(.505-j*.031),y+.052,.36)],[.052,.091,.079,.047,.002],
				Vector3.UP,Vector3(s*.65,0,.76),BROWN.darkened(.10),true)
	pen.oval(Vector3(-.158,.363,.29),Vector3(.107,.063,.058),bright)
	pen.blade([Vector3(-.15,.368,.30),Vector3(-.232,.33,.35),Vector3(-.29,.254,.302)],
		[.041,.04,.003],Vector3.RIGHT,Vector3.BACK,cloth)

func paint_crown() -> void:
	# Comb the top into a side part and down the occiput. The large rear
	# surface has its own continuous paint, beneath the pointed outer hair.
	var rows := [
		Vector4(.675,.030,.030,.082),Vector4(.665,.141,.143,.082),
		Vector4(.636,.259,.233,.071),Vector4(.575,.323,.283,.058),
		Vector4(.491,.363,.301,.042),Vector4(.411,.356,.304,.023),
		Vector4(.351,.344,.296,.033),Vector4(.294,.32,.271,.060)]
	for quadrant in 4:
		var points := []
		var middle := (quadrant+.5)*PI/2
		var outward := Vector3(sin(middle),.48,cos(middle)).normalized()
		for iy in rows.size():
			var r: Vector4 = rows[iy]
			var v := float(iy)/(rows.size()-1)
			for ix in 13:
				var a := (quadrant+float(ix)/12.0)*PI/2
				var angle := a+.42*(1-v)*(1-v)
				var h := r.x+.01*cos(a*3)*v
				# On the brow side the cap ends above the blue headband.
				h += maxf(0.0,-cos(angle))*.113*smoothstep(.63,1,v)
				points.append(Vector3(sin(angle)*r.y,h,cos(angle)*r.z+r.w))
		pen.painted_grid(points,13,rows.size(),Brush.HAIR,outward,true)

func helm() -> void:
	if kind == "guard":
		profile(Vector3.ZERO,[Vector4(.349,.397,.339,0),Vector4(.402,.33,.29,.008),
			Vector4(.528,.199,.19,.018),Vector4(.61,.058,.065,.014)],iron,14)
	else:
		profile(Vector3.ZERO,[Vector4(.347,.344,.29,0),Vector4(.404,.344,.293,.008),
			Vector4(.507,.292,.248,.015),Vector4(.559,.183,.161,.021),Vector4(.591,.055,.071,.029)],iron,14)
	var brim := .434 if kind == "guard" else .359
	profile(Vector3.ZERO,[Vector4(.338,brim,.317,0),Vector4(.36,brim,.321,0),Vector4(.393,.339,.296,0)],rim,14)
	for s: float in [-1.,1.]:
		var out := Vector3(s,0,-.48)
		pen.panel([Vector3(s*.29,.375,-.136),Vector3(s*.347,.363,.095),
			Vector3(s*.346,.192,.131),Vector3(s*.262,.096,-.064),Vector3(s*.268,.239,-.157)],out,.027,iron)
		pen.blade([Vector3(s*.294,.329,-.142),Vector3(s*.29,.233,-.151),Vector3(s*.271,.116,-.078)],
			[.008,.01,.002],Vector3.RIGHT,out,rim)
	# Forehead crest and nape plates over a dark padded coif.
	front([Vector3(-.055,.377,-.303),Vector3(0,.505,-.248),Vector3(.061,.378,-.299),Vector3(0,.325,-.32)],.016,rim)
	profile(Vector3(0,0,.113),[Vector4(.115,.245,.15,.019),Vector4(.189,.287,.180,.02),Vector4(.367,.309,.193,.02)],coat)
	for tier in 3:
		var y := .324-tier*.065
		for j in 5:
			var a := (j-2)*.42
			var out := Vector3(sin(a),.0,cos(a))
			var crossbar := Vector3(cos(a),0,-sin(a))*.067
			var at := Vector3(sin(a)*.294,y,cos(a)*.206+.113)
			pen.panel([at-crossbar,at+crossbar,at+crossbar+Vector3.DOWN*.051,
				at+Vector3.DOWN*.084,at-crossbar+Vector3.DOWN*.051],out,.013,iron.darkened(.06*tier))
	if kind == "commander":
		for s: float in [-1.,1.]:
			pen.blade([Vector3(s*.14,.501,.057),Vector3(s*.239,.664,.105),
				Vector3(s*.291,.754,.226),Vector3(s*.314,.744,.382),Vector3(s*.355,.64,.495)],
				[.045,.067,.061,.044,.002],Vector3.RIGHT,Vector3.UP,bright)
	elif kind == "guard":
		pen.blade([Vector3(0,.547,.02),Vector3(0,.638,.054),Vector3(.015,.653,.178)],
			[.04,.043,.002],Vector3.RIGHT,Vector3.UP,cloth)
	else:
		pen.oval(Vector3(0,.563,.026),Vector3(.057,.054,.057),GOLD)

func scarf() -> void:
	if kind == "hero":
		pen.oval(Vector3(-.023,0,.037),Vector3(.123,.071,.082),cloth,16)
		# Two bias-cut tails twist away from the knot and the baby's shoulder.
		for strand in 2:
			var rows := []
			for iy in 17:
				var t := float(iy)/16.0
				var center := Vector3(-.03,-.01,.05)
				if strand == 0:
					center += Vector3(-.50*t+.08*sin(t*TAU),-.14*t-.19*sin(t*PI*.85),.69*t)
				else:
					center += Vector3(.06*sin(t*PI)-.28*t,-.33*t-.085*sin(t*PI),.57*t)
				var breadth := (.076+.094*sin(t*PI))*(1.0-smoothstep(.65,1,t)*.98)
				var across := Vector3(.91,.04+.47*t,.13*sin(t*PI)).normalized()
				for ix in 7:
					var u := float(ix)/3.0-1
					var fold := Vector3(0,.045*cos(u*PI+t*2),.03*(1-u*u))*sin(t*PI)
					rows.append(center+across*breadth*u+fold)
			pen.painted_grid(rows,7,17,Brush.SILK,Vector3(0,1,1))
	elif kind == "commander":
		for s: float in [-1.,1.]:
			pen.blade([Vector3(s*.12,-.005,0),Vector3(s*.203,-.253,.12),
				Vector3(s*.28,-.527,.21),Vector3(s*.32,-.78,.27)],
				[.156,.171,.155,.09],Vector3.RIGHT,Vector3.BACK,cloth)
			pen.blade([Vector3(s*.238,-.051,.044),Vector3(s*.332,-.331,.158),Vector3(s*.388,-.76,.27)],
				[.01,.012,.004],Vector3.RIGHT,Vector3.BACK,GOLD)
	else:
		pen.blade([Vector3.ZERO,Vector3(.032,-.166,.069),Vector3(.083,-.308,.10)],
			[.09,.071,.004],Vector3.RIGHT,Vector3.BACK,cloth)

func shield() -> void:
	# Wrist-mounted shield with a convex boss, lacquered border and stamped ribs.
	var o := Vector3(-.105,-.13,-.095)
	var outline := [Vector3(-.187,.278,0),Vector3(.115,.33,0),Vector3(.229,.203,0),
		Vector3(.238,-.172,0),Vector3(.108,-.339,0),Vector3(-.176,-.274,0),Vector3(-.246,-.119,0)]
	for k in 2:
		var pts := []
		for p: Vector3 in outline:
			pts.append(o + p*(1.0-k*.104) + F*k*.023)
		front(pts,.069, rim if k == 0 else Color("#704435"))
	pen.oval(o+F*.086,Vector3(.095,.104,.042),GOLD)
	for s: float in [-1.,1.]:
		pen.blade([o+Vector3(0,.157*s,-.067),o+Vector3(.08*s,.222*s,-.059),o+Vector3(.105*s,.265*s,-.041)],
			[.011,.017,.002],Vector3.RIGHT,F,rim)

func weapon() -> void:
	if kind == "shield":
		pen.shaft(Vector3(0,0,.18),Vector3(0,0,-.15),.025,.025,LEATHER)
		pen.shaft(Vector3(-.086,0,-.15),Vector3(.086,0,-.15),.027,.027,GOLD)
		pen.blade([Vector3(0,0,-.153),Vector3(.005,0,-.451),Vector3(.018,0,-.679),Vector3(.091,.007,-.791)],
			[.042,.061,.054,.001],Vector3.RIGHT,Vector3.UP,rim)
		return
	var rear := .64 if kind == "hero" else .54
	var front_z := -1.38 if kind == "hero" else -1.17
	if kind == "commander":
		front_z = -1.71
	pen.shaft(Vector3(0,0,rear),Vector3(0,0,front_z),.024,.023,INK if kind == "hero" else LEATHER,10)
	pen.shaft(Vector3(0,0,rear+.105),Vector3(0,0,rear-.035),.007,.034,iron)
	for z: float in [-.98,-.88,-.30,-.20,.12,.18,.51]:
		pen.shaft(Vector3(0,0,z+.019),Vector3(0,0,z-.019),.027,.027,rim)
	pen.shaft(Vector3(0,0,front_z+.103),Vector3(0,0,front_z-.014),.041,.034,rim)
	for i in 5:
		var a := TAU*i/5.0
		var r := Vector3(sin(a),cos(a),0)
		pen.blade([r*.032+Vector3(0,0,front_z+.08),r*.072+Vector3(0,0,front_z+.181),
			r*.116+Vector3(0,-.045,front_z+.244)],[.02,.025,.001],r.cross(F),r,bright)
	# Silver edges and a raised blue central ridge make the blade legible in silhouette.
	var base := Vector3(0,0,front_z)
	var pts := [base+Vector3(0,0,-.405),base+Vector3(.081,0,-.115),base+Vector3(.052,0,-.052),
		base+Vector3(.025,0,0),base+Vector3(-.034,0,0),base+Vector3(-.083,0,-.115)]
	pen.panel(pts,Vector3.UP,.045,rim)
	pen.panel(pts,Vector3.DOWN,.031,iron)
	pen.blade([base+Vector3(0,.029,-.033),base+Vector3(0,.049,-.11),base+Vector3(0,.004,-.368)],
		[.012,.025,.001],Vector3.RIGHT,Vector3.UP,cloth)
	if kind == "commander":
		pen.blade([base+Vector3(-.004,0,.159),base+Vector3(-.134,0,.094),base+Vector3(-.214,0,-.052),
			base+Vector3(-.188,0,-.196)],[.031,.067,.055,.002],Vector3.RIGHT,Vector3.UP,rim)
