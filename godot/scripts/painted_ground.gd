extends RefCounted
## Bake-only painterly materials. The shipped map remains one RGB ground image.
## The source is loaded dynamically, never preloaded from the excluded art folder.
const SOURCE="res://art_source/painted/materials-source.png"
const DRY=0
const MUD=1
const SLATE=2
const PAVING=3
const GRASS=4
const LITTER=5
static var checked=false
static var tiles: Array=[]
static var averages=PackedVector3Array()
static var paint_shader: Shader
const SHADER_CODE="""
shader_type canvas_item;
render_mode unshaded;
uniform vec2 world_phase = vec2(0.0);
uniform vec3 average_colors[6];
varying vec2 ground_position;
varying vec4 primitive_color;
void vertex() {
	ground_position = VERTEX;
	primitive_color = COLOR;
}
vec2 mirror_tile(vec2 p) {
	return clamp(1.0 - abs(mod(p, 2.0) - 1.0), vec2(0.001), vec2(0.999));
}
void fragment() {
	// Ordinary vector annotations still use this canvas, with the white 1x1
	// default texture. Only the explicit material meshes enter the paint path.
	if (TEXTURE_PIXEL_SIZE.x > 0.5) {
		COLOR = primitive_color;
	} else {
		int kind = int(clamp(floor(UV.x + 0.5), 0.0, 5.0));
		float span = 390.0;
		if (kind == 2) { span = 420.0; }
		if (kind == 3) { span = 285.0; }
		if (kind == 4 || kind == 5) { span = 440.0; }
		vec2 p = ground_position + world_phase;
		vec2 q = p / span;
		// Mirror repeat closes an imperfect source edge without rectangular
		// seams. A second broad sample breaks obvious repeated diamonds.
		vec2 q2 = vec2(p.x * 0.917 - p.y * 0.399, p.x * 0.399 + p.y * 0.917) / (span * 1.37) + vec2(1.83, 0.37);
		vec3 a = texture(TEXTURE, mirror_tile(q)).rgb;
		vec3 b = texture(TEXTURE, mirror_tile(q2)).rgb;
		float mixture = 0.23 + 0.10 * sin(p.x * 0.0043 + sin(p.y * 0.0037));
		vec3 paint = mix(a, b, mixture);
		vec3 result = primitive_color.rgb + (paint - average_colors[kind]) * UV.y;
		COLOR = vec4(clamp(result, vec3(0.035), vec3(0.965)), primitive_color.a);
	}
}
"""

static func available() -> bool:
	if checked: return tiles.size()==6
	checked=true
	if not FileAccess.file_exists(SOURCE): return false
	var sheet=Image.new()
	if sheet.load(SOURCE)!=OK or sheet.get_size()!=Vector2i(1536,1024):
		push_warning("Painted materials need the original 1536x1024 six-cell sheet.")
		return false
	for index in range(6):
		var cell=sheet.get_region(Rect2i(index%3*512,int(index/3)*512,512,512))
		var mean=Vector3.ZERO
		for y in range(16,512,32):
			for x in range(16,512,32):
				var c=cell.get_pixel(x,y); mean+=Vector3(c.r,c.g,c.b)
		averages.append(mean/256.0)
		cell.generate_mipmaps()
		tiles.append(ImageTexture.create_from_image(cell))
	paint_shader=Shader.new(); paint_shader.code=SHADER_CODE
	return true

static func _bind(canvas: Node2D, stage: String) -> void:
	if canvas.has_meta("painted_ground_material"): return
	var material=ShaderMaterial.new(); material.shader=paint_shader
	var seed_value=absi(stage.hash())
	material.set_shader_parameter("world_phase",Vector2(seed_value%719,(seed_value/23)%631))
	material.set_shader_parameter("average_colors",averages)
	canvas.material=material
	canvas.texture_filter=CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	canvas.set_meta("painted_ground_material",true)
	canvas.set_meta("painted_ground_meshes",{})

static func ground_kind(stage: String) -> int:
	return {"temple":GRASS,"bridge":MUD,"hs_forest":LITTER,"hs_return":SLATE,"hs_river":MUD}.get(stage,DRY)

static func road_kind(stage: String) -> int:
	return MUD if stage in ["hs_forest","hs_river"] else DRY

static func surface_kind(kind: String) -> int:
	if kind in ["flagstone","cobbles"]: return PAVING
	if kind=="stone": return SLATE
	return DRY

static func paint(canvas: Node2D, polygon: PackedVector2Array, kind: int, tone: Color, stage: String, feather=12.0, strength=.62) -> bool:
	if polygon.size()<3 or not available(): return false
	_bind(canvas,stage)
	var cache: Dictionary=canvas.get_meta("painted_ground_meshes")
	var key=hash([polygon,kind,tone,feather,strength])
	if not cache.has(key): cache[key]=_mesh(polygon,kind,tone,feather,strength)
	var mesh=cache[key]
	if mesh==null: return false
	canvas.draw_mesh(mesh,tiles[kind])
	return true

static func circle(canvas: Node2D, at: Vector2, radius: float, kind: int, tone: Color, stage: String, feather=10.0, strength=.58) -> bool:
	var polygon=PackedVector2Array()
	for i in range(40): polygon.append(at+Vector2.from_angle(i*TAU/40)*radius)
	return paint(canvas,polygon,kind,tone,stage,feather,strength)

static func _mesh(polygon: PackedVector2Array,kind: int,tone: Color,feather: float,strength: float):
	var triangles=Geometry2D.triangulate_polygon(polygon)
	if triangles.is_empty(): return null
	var stack: Array=[]
	for i in range(0,triangles.size(),3): stack.append([polygon[triangles[i]],polygon[triangles[i+1]],polygon[triangles[i+2]]])
	var vertices=PackedVector3Array(); var colors=PackedColorArray(); var uvs=PackedVector2Array()
	while not stack.is_empty():
		var tri: Array=stack.pop_back()
		var a: Vector2=tri[0]; var b: Vector2=tri[1]; var c: Vector2=tri[2]
		var lengths=[a.distance_squared_to(b),b.distance_squared_to(c),c.distance_squared_to(a)]
		var longest=0
		if lengths[1]>lengths[longest]: longest=1
		if lengths[2]>lengths[longest]: longest=2
		# Fine triangles exist only during the offline bake. Their alpha comes
		# from distance to the ORIGINAL outline, so no geometry grows outward.
		if feather>0 and lengths[longest]>576.0:
			var p: Vector2=tri[longest]; var q: Vector2=tri[(longest+1)%3]; var r: Vector2=tri[(longest+2)%3]
			var mid=(p+q)*.5
			stack.append([p,mid,r]); stack.append([mid,q,r]); continue
		for p in [a,b,c]:
			var alpha=1.0
			if feather>0:
				var distance=INF
				for j in range(polygon.size()):
					distance=minf(distance,p.distance_to(Geometry2D.get_closest_point_to_segment(p,polygon[j],polygon[(j+1)%polygon.size()])))
				alpha=clampf(distance/feather,0,1); alpha=alpha*alpha*(3-2*alpha)
			vertices.append(Vector3(p.x,p.y,0)); colors.append(Color(tone,tone.a*alpha)); uvs.append(Vector2(kind,strength))
	var arrays=[]; arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX]=vertices; arrays[Mesh.ARRAY_COLOR]=colors; arrays[Mesh.ARRAY_TEX_UV]=uvs
	var mesh=ArrayMesh.new(); mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
	return mesh
