extends SceneTree
## Exercise the real native terrain/navigation; --bake uses the GPU renderer once.
const Terrain=preload("res://scripts/terrain.gd")
const Layout=preload("res://scripts/hanshui_layout.gd")
var failures: Array=[]
var checks=0
var bake=false

class MapWorld extends Node2D:
	var actors=Node2D.new()
	var props: Array=[]
	var stage=""
	var state={"chapter":2,"flags":{"supplies":true},"tactics":{"gate":"PROBE_1"}}
	var mode="menu"
	var camera=Camera2D.new()
	func _ready() -> void:
		add_child(actors); add_child(camera)

func _initialize() -> void:
	call_deferred("run")

func expect(value: bool, message: String) -> void:
	checks+=1
	if not value: failures.append(message); push_error(message)

func point(values: Array) -> Vector2:
	return Vector2(values[0],values[1])

func walkable(terrain, target: Vector2, origin: Vector2, label: String) -> void:
	expect(not terrain.blocked(target,18),label+" has clear feet")
	var path: PackedVector2Array=terrain.find_path(origin,target,18)
	expect(path.size()>0 and path[-1].distance_to(target)<62,label+" has a navigable route")

func run() -> void:
	bake="--bake" in OS.get_cmdline_user_args()
	if bake and DisplayServer.get_name()=="headless":
		push_error("Bake requires the graphical compatibility renderer"); quit(1); return
	Terrain.baking=true
	Layout.baking=bake
	var parsed=JSON.parse_string(FileAccess.get_file_as_string("res://data/chapter2.json"))
	expect(parsed is Dictionary,"chapter two JSON is a dictionary")
	if not parsed is Dictionary: quit(1); return
	var data: Dictionary=parsed.StageDefinition
	expect(data.size()==6 and parsed.order.size()==6,"six chapter-two regions")
	var known=["scout","crossbow","ironshield","sword","spear","shield","archer"]
	var all_groups={}
	var world=MapWorld.new(); root.add_child(world)
	var viewport=SubViewport.new(); viewport.size=Vector2i(1600,1100)
	viewport.transparent_bg=false; viewport.render_target_update_mode=SubViewport.UPDATE_DISABLED
	if bake: root.add_child(viewport)
	for id in parsed.order:
		world.stage=id
		var definition: Dictionary=Layout.apply_layout(data[id],id)
		var twice: Dictionary=Layout.apply_layout(definition,id)
		expect(twice.roads.size()==definition.roads.size() and twice.map_details.solids.size()==definition.map_details.solids.size(),id+" repeated layout is idempotent")
		var terrain=Terrain.new(); terrain.world=world; world.add_child(terrain); terrain.build(definition)
		await process_frame; await physics_frame
		var origin=point(definition.spawn)
		walkable(terrain,origin,origin,id+" spawn")
		for slot in range(3):
			var ally_spawn=origin+Vector2(-65+(slot-1)*48,65+(slot%2)*24)
			walkable(terrain,ally_spawn,origin,id+" companion spawn "+str(slot))
		for obj in definition.objects:
			walkable(terrain,Vector2(obj.x,obj.y),origin,id+":"+obj.id)
			if obj.kind=="exit": expect(data.has(obj.to),id+":"+obj.id+" destination exists")
		for group in definition.groups:
			expect(not all_groups.has(group.id),"unique group "+group.id); all_groups[group.id]=true
			for unit in group.units:
				expect(unit[0] in known,group.id+" unit type is supported")
				walkable(terrain,Vector2(unit[1],unit[2]),origin,group.id+" "+unit[0])
		for solid in definition.map_details.solids:
			if solid.has("rect"):
				var r=solid.rect; var center=Vector2(r[0]+r[2]*.5,r[1]+r[3]*.5)
				expect(terrain.blocked(center,0),id+" solid matches collision/navigation")
		for water in definition.layout.water:
			var sample=Vector2(water[0]+water[2]*.5,water[1]+water[3]*.5)
			expect(terrain.blocked(sample,0),id+" visible water is impassable")
		if id=="hs_return":
			var route: Array=definition.tactics.waypoints
			var clear_route=true
			for i in range(1,route.size()):
				var a=point(route[i-1]); var b=point(route[i]); var count=maxi(1,int(ceil(a.distance_to(b)/8.0)))
				for n in range(count+1):
					if terrain.blocked(a.lerp(b,float(n)/count),28): clear_route=false
			expect(clear_route,"grain cart radius 28 clears every route segment")
			for p in [[330,800],[330,560],[680,500],[1480,490],[1480,240]]:
				walkable(terrain,point(p),origin,"return flank "+str(p))
			expect(not terrain.line_clear(Vector2(550,610),Vector2(550,800),2),"stone wall blocks projectiles")
		if id=="hs_camp":
			for p in definition.tactics.guard_points: walkable(terrain,point(p),origin,"camp guard point")
			for p in definition.tactics.probe_entries: walkable(terrain,point(p),origin,"camp probe entry")
			for y in range(470,651,30): expect(not terrain.blocked(Vector2(1000,y),28),"240px open gate clears bodies")
			expect(not terrain.line_clear(Vector2(920,300),Vector2(1100,300),2),"camp wall blocks arrows")
			await swept_body(world,Vector2(910,300),Vector2(250,0),true,"native collision stops a dash at the camp wall")
			await swept_body(world,Vector2(910,560),Vector2(250,0),false,"native collision permits a dash through the open gate")
			world.state.tactics.gate="PREPARE"
			var closed_terrain=Terrain.new(); closed_terrain.world=world
			world.add_child(closed_terrain); closed_terrain.build(definition)
			await physics_frame
			expect(closed_terrain.blocked(Vector2(1000,560),16),"closed gate fills the collision gap")
			expect(not closed_terrain.line_clear(Vector2(910,560),Vector2(1120,560),2),"closed gate blocks arrows")
			await swept_body(world,Vector2(910,560),Vector2(250,0),true,"native closed gate blocks a dash")
			closed_terrain.open_camp_gate()
			expect(not closed_terrain.blocked(Vector2(1000,560),16),"opening removes gate from navigation immediately")
			expect(closed_terrain.line_clear(Vector2(910,560),Vector2(1120,560),2),"opening restores the arrow route immediately")
			await swept_body(world,Vector2(910,560),Vector2(250,0),false,"native opening restores body passage immediately")
			closed_terrain.open_camp_gate()
			expect(closed_terrain.gate_geometry.is_empty(),"opening twice is harmless")
			closed_terrain.queue_free(); await process_frame
			world.state.tactics.gate="PROBE_1"
		if id=="hs_river":
			for p in [[600,420],[600,680],[1040,760],[1040,500]]: walkable(terrain,point(p),origin,"river alternate route")
			expect(not terrain.line_clear(Vector2(1440,700),Vector2(1540,700),16),"riverbank blocks a swept crossing")
			await swept_body(world,Vector2(1410,800),Vector2(220,0),true,"native collision stops a dash at the riverbank")
		if bake:
			world.remove_child(terrain); viewport.add_child(terrain)
			viewport.render_target_update_mode=SubViewport.UPDATE_ONCE
			await process_frame; await process_frame; await RenderingServer.frame_post_draw
			var image=viewport.get_texture().get_image(); image.convert(Image.FORMAT_RGB8)
			expect(image.save_png("res://assets/maps/"+id+".png")==OK,"baked "+id)
			print("BAKED_HANSHUI ",id," 1600x1100")
			world.remove_child(world.actors); viewport.add_child(world.actors)
			viewport.render_target_update_mode=SubViewport.UPDATE_ONCE
			await process_frame; await process_frame; await RenderingServer.frame_post_draw
			var preview=viewport.get_texture().get_image()
			preview.save_png(ProjectSettings.globalize_path("res://../.qa/hanshui-map-preview-"+id+".png"))
			viewport.remove_child(world.actors); world.add_child(world.actors)
			viewport.remove_child(terrain)
		else: world.remove_child(terrain)
		terrain.queue_free()
		for node in world.actors.get_children(): world.actors.remove_child(node); node.queue_free()
		await process_frame
	world.queue_free()
	if bake:
		await bake_props(viewport,data)
		viewport.queue_free()
	else: viewport.free()
	await process_frame
	print("HANSHUI_LAYOUT_VERIFY ",checks," checks; ",failures.size()," failures")
	quit(0 if failures.is_empty() else 1)

func swept_body(world: Node2D, at: Vector2, travel: Vector2, should_collide: bool, label: String) -> void:
	var body=CharacterBody2D.new(); body.collision_layer=0; body.collision_mask=1
	var collider=CollisionShape2D.new(); var circle=CircleShape2D.new(); circle.radius=16
	collider.shape=circle; body.add_child(collider); world.add_child(body); body.position=at
	await physics_frame
	var hit=body.move_and_collide(travel)
	expect((hit!=null)==should_collide,label)
	body.queue_free(); await process_frame

func bake_props(viewport: SubViewport, definitions: Dictionary) -> void:
	var entries: Array=[]; var seen={}
	for definition in definitions.values():
		for value in definition.layout.decor:
			var key=Layout.frame_key(value)
			if seen.has(key): continue
			seen[key]=true; entries.append({"key":key,"item":value})
	var cell=Vector2i(640,600); var columns=4; var rows=int(ceil(entries.size()/float(columns)))
	viewport.size=Vector2i(cell.x*columns,cell.y*rows); viewport.transparent_bg=true
	var anchor=Vector2(320,510); var manifest={}
	for i in range(entries.size()):
		var node=Layout.new(); node.layer="landmark"; node.item=entries[i].item
		var origin=Vector2(i%columns*cell.x,int(i/columns)*cell.y)
		node.position=origin+anchor; viewport.add_child(node)
		manifest[entries[i].key]={"region":[int(origin.x),int(origin.y),cell.x,cell.y],"anchor":[anchor.x,anchor.y]}
	viewport.render_target_update_mode=SubViewport.UPDATE_ONCE
	await process_frame; await process_frame; await RenderingServer.frame_post_draw
	var atlas=viewport.get_texture().get_image()
	expect(atlas.save_png("res://assets/maps/hanshui_props.png")==OK,"chapter two props atlas baked")
	for key in manifest:
		var frame=manifest[key]; var rect=Rect2i(frame.region[0],frame.region[1],frame.region[2],frame.region[3])
		var used=atlas.get_region(rect).get_used_rect()
		expect(used.size.x>0 and used.size.y>0,"nonempty atlas prop "+key)
		if used.size.x>0 and used.size.y>0:
			frame.region=[rect.position.x+used.position.x,rect.position.y+used.position.y,used.size.x,used.size.y]
			frame.anchor=[anchor.x-used.position.x,anchor.y-used.position.y]
	var file=FileAccess.open("res://assets/maps/hanshui_props.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(manifest,"  ")); file.close()
	print("BAKED_HANSHUI_PROPS ",entries.size()," frames")
