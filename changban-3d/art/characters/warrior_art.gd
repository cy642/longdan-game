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
const F := Vector3.FORWARD
var kind: String
var coat: Color
var cloth: Color
var bright: Color
var iron: Color
var rim: Color
var pen: Brush
static var eye_paint: StandardMaterial3D

func _init(who: String) -> void:
	kind = who
	match kind:
		"hero":
			coat = Color("#304679"); cloth = Color("#1776bb"); bright = Color("#56bde9")
			iron = Color("#a9b9d1"); rim = MILK
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
	var side := -1.0 if part.ends_with("_l") else 1.0
	if part.begins_with("thigh"): thigh(side)
	elif part.begins_with("shin"): shin(side)
	elif part.begins_with("arm"): arm(side)
	elif part.begins_with("wrist"): wrist(side)
	else:
		match part:
			"body": body()
			"head": head()
			"scarf": scarf()
			"weapon": weapon()
			"shield": shield()
	var mesh := pen.bake()
	if part == "head" and kind == "hero":
		add_hero_eyes(mesh)
	return mesh

func profile(center: Vector3, rings: Array, color: Color, sides := 12) -> void:
	pen.turned(center,rings,color,sides)

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
	# Toe projects forward; welt and sole sit on y=0 in the rest pose.
	profile(Vector3.ZERO,[Vector4(-.325,.105,.17,-.047),Vector4(-.287,.105,.178,-.053),
		Vector4(-.245,.092,.151,-.036),Vector4(-.17,.082,.085,0),Vector4(-.045,.093,.092,0)],LEATHER)
	profile(Vector3.ZERO,[Vector4(-.322,.106,.172,-.051),Vector4(-.295,.107,.176,-.051)],INK)
	profile(Vector3.ZERO,[Vector4(-.252,.092,.096,0),Vector4(-.125,.106,.101,0),Vector4(-.021,.102,.099,0)],iron)
	front([Vector3(-.075,-.025,-.065),Vector3(0,.038,-.108),Vector3(.082,-.038,-.069),
		Vector3(.062,-.16,-.087),Vector3(s*.012,-.241,-.105),Vector3(-.062,-.17,-.085)],.028,rim)
	pen.blade([Vector3(0,-.029,-.13),Vector3(s*.01,-.111,-.142),Vector3(s*.01,-.19,-.116)],
		[.013,.01,.001],Vector3.RIGHT,F,iron)

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

func wrist(_s: float) -> void:
	profile(Vector3.ZERO,[Vector4(-.166,.07,.066,0),Vector4(-.112,.082,.084,0),
		Vector4(-.018,.09,.09,0),Vector4(.032,.072,.077,0)],iron)
	profile(Vector3.ZERO,[Vector4(-.149,.078,.077,0),Vector4(-.124,.084,.083,0)],rim)
	pen.oval(Vector3(0,-.198,-.01),Vector3(.079,.082,.073),SKIN)

func head() -> void:
	pen.turned(Vector3.ZERO,[Vector4(.026,.085,.132,-.015),Vector4(.07,.184,.202,-.018),
		Vector4(.149,.273,.249,-.018),Vector4(.245,.325,.267,-.008),Vector4(.359,.332,.271,0),
		Vector4(.455,.308,.256,.008),Vector4(.526,.246,.222,.016),Vector4(.565,.157,.157,.025)],SKIN,20,true)
	for s: float in [-1.0,1.0]:
		pen.oval(Vector3(s*.31,.244,.005),Vector3(.061,.085,.05),SKIN)
		if kind != "hero":
			eye(s)
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

func add_hero_eyes(mesh: ArrayMesh) -> void:
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
				var x := side*lerpf(.040,.258,u)
				var y := lerpf(.360,.139,v)
				verts.append(cheek_surface(x,y))
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
	if eye_paint == null:
		eye_paint = StandardMaterial3D.new()
		eye_paint.albedo_texture = HERO_EYE
		eye_paint.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		eye_paint.roughness = 1.0
		eye_paint.metallic_specular = 0.0
		eye_paint.texture_repeat = false
	mesh.surface_set_material(mesh.get_surface_count()-1,eye_paint)

func face_point(x: float,y: float,inset: float) -> Vector3:
	# Most of the painted eye is laid across the curvature of the cheek.
	var cheek := .275 if y > .209 else .266
	return Vector3(x,y,-.007-cheek*sqrt(maxf(.06,1.0-pow(x/.326,2)))-inset)

func eye(s: float) -> void:
	var upper := .288 if kind == "hero" else .277
	var lower := .161 if kind == "hero" else .193
	var shape := [
		face_point(s*.053,upper-.028,.012),face_point(s*.133,upper+.035,.012),
		face_point(s*.221,upper+.031,.012),face_point(s*.252,upper+.021,.012),
		face_point(s*.219,lower+.005,.012),face_point(s*.146,lower-.007,.012),
		face_point(s*.081,lower+.023,.012)]
	front(shape,.003,INK)
	front([face_point(s*.063,upper-.031,.019),face_point(s*.142,upper+.017,.019),
		face_point(s*.221,upper+.019,.019),face_point(s*.211,lower+.009,.019),
		face_point(s*.15,lower+.002,.019),face_point(s*.09,lower+.027,.019)],.004,MILK)
	var iris := Color("#228dbd") if kind == "hero" else Color("#936d42")
	iris_patch(s,(upper+lower)*.5+.008,.048,(upper-lower)*.48,iris,.027)
	iris_patch(s,(upper+lower)*.5+.018,.024,(upper-lower)*.34,INK,.034)
	var glint := face_point(s*.136,(upper+lower)*.5+.032,.041)
	pen.oval(glint,Vector3(.011,.013,.005),Color.WHITE,8)
	pen.blade([face_point(s*.045,upper+.035,.014),face_point(s*.147,upper+.08,.014),face_point(s*.247,upper+.069,.012)],
		[.008,.019,.003],Vector3.UP,F,BROWN if kind == "hero" else INK)

func iris_patch(s: float,y: float,rx: float,ry: float,color: Color,inset: float) -> void:
	var points := []
	for i in 12:
		var a := TAU*i/12.0
		points.append(face_point(s*.151+rx*cos(a),y+ry*sin(a),inset))
	front(points,.001,color)

func hair() -> void:
	# Blue cloth appears between the fringe and eyebrows, with a high trailing knot.
	profile(Vector3.ZERO,[Vector4(.354,.343,.284,0),Vector4(.413,.347,.275,0),Vector4(.448,.334,.274,0)],cloth,20)
	pen.turned(Vector3.ZERO,[Vector4(.402,.347,.291,.018),Vector4(.487,.354,.291,.037),
		Vector4(.562,.313,.272,.056),Vector4(.624,.253,.218,.068),Vector4(.652,.127,.122,.081),
		Vector4(.659,.031,.028,.081)],BROWN,20,true)
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
				[.072,.097,.087,.047,.001],axis,Vector3(s,.05,.13),BROWN.darkened(.048*j))
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
			Vector3.RIGHT,Vector3(0,.12,-1),BROWN.lightened(.042*(i%3)))
		if i == 1 or i == 3:
			pen.lock([root.lerp(joint,.33)+F*.05,root.lerp(joint,.64)+F*.055,root.lerp(joint,.82)+F*.051],
				[.001,.009,.001],Vector3.RIGHT,F,COPPER)
	# Crown strands fan from the left part into a swept outer contour.
	for j in 3:
		var dz := j*.076
		pen.lock([Vector3(-.207,.558,-.091+dz),Vector3(-.118,.631,-.091+dz),
			Vector3(.021,.674,-.07+dz),Vector3(.159,.667,-.041+dz),
			Vector3(.281,.623,.007+dz),Vector3(.347-j*.012,.587+j*.018,.056+dz)],
			[.067,.09,.095,.082,.044,.001],Vector3.FORWARD,Vector3.UP,BROWN.lightened(.028*(2-j)))
	pen.lock([Vector3(-.147,.586,.104),Vector3(-.073,.658,.13),Vector3(.024,.693,.174),
		Vector3(.111,.722,.216),Vector3(.158,.753,.267)],
		[.065,.076,.067,.033,.001],Vector3.FORWARD,Vector3.UP,BROWN.darkened(.07))
	# Fan-shaped layered nape and band knot remain visible from the chase camera.
	for j in 6:
		var x := -.245+j*.095
		pen.lock([Vector3(x*.83,.545,.236),Vector3(x*.97,.43,.285),Vector3(x,.356,.293),
			Vector3(x*1.09,.226,.28),Vector3(x*1.12,.145+absf(x)*.18,.252)],
			[.052,.078,.068,.042,.001],Vector3.RIGHT,Vector3.BACK,BROWN.darkened(.04*(j%3)))
	pen.oval(Vector3(-.158,.363,.29),Vector3(.107,.063,.058),bright)
	pen.blade([Vector3(-.15,.368,.30),Vector3(-.232,.33,.35),Vector3(-.29,.254,.302)],
		[.041,.04,.003],Vector3.RIGHT,Vector3.BACK,cloth)

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
		var out := Vector3.BACK
		# A split silk scarf streaming behind the silver cuirass.
		pen.blade([Vector3(-.065,0,0),Vector3(-.16,-.044,.135),Vector3(-.181,-.147,.276),
			Vector3(-.262,-.266,.407),Vector3(-.283,-.31,.548)],
			[.103,.135,.141,.092,.002],Vector3.RIGHT,out,cloth)
		pen.blade([Vector3(.02,-.014,.003),Vector3(.066,-.085,.147),Vector3(.036,-.201,.286),
			Vector3(.123,-.286,.387)],[.075,.085,.074,.002],Vector3.RIGHT,out,bright)
		pen.blade([Vector3(-.129,-.069,.174),Vector3(-.17,-.153,.301),Vector3(-.25,-.242,.397)],
			[.005,.018,.002],Vector3.RIGHT,out,bright)
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
