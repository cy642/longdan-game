extends SceneTree
## Actual third-chapter collision/navigation, independent of campaign state.
const Terrain=preload("res://scripts/terrain.gd")
const Layout=preload("res://scripts/jigu_layout.gd")
const Hanshui=preload("res://scripts/hanshui_layout.gd")
var checks=0
var failures: Array=[]
class MapWorld extends Node2D:
	var actors=Node2D.new()
	var props: Array=[]
	var stage=""
	var definition: Dictionary={}
	var state={"chapter":3,"flags":{"supplies":true},"tactics":{}}
	var mode="menu"
	var camera=Camera2D.new()
	func _ready() -> void:
		add_child(actors); add_child(camera)

func _initialize() -> void: call_deferred("run")
func expect(value: bool,message: String) -> void:
	checks+=1
	if not value: failures.append(message); push_error(message)
func p(values) -> Vector2: return Vector2(values[0],values[1])
func reachable(terrain,target: Vector2,origin: Vector2,label: String) -> void:
	expect(not terrain.blocked(target,18),label+" has clear feet")
	var path=terrain.find_path(origin,target,18)
	expect(not path.is_empty() and path[-1].distance_to(target)<62,label+" reachable")

func run() -> void:
	Terrain.baking=true
	var data=JSON.parse_string(FileAccess.get_file_as_string("res://data/chapter3.json"))
	expect(data is Dictionary,"chapter three is a JSON object")
	if not data is Dictionary: quit(1); return
	var definitions: Dictionary=data.StageDefinition
	expect(data.order.size()==6 and definitions.size()==6,"six Jigu maps")
	var world=MapWorld.new(); root.add_child(world)
	var group_ids={}; var object_ids={}
	var manifest=JSON.parse_string(FileAccess.get_file_as_string("res://assets/maps/hanshui_props.json"))
	for id in data.order:
		world.stage=id; world.definition=Layout.apply_layout(definitions[id],id)
		var twice=Layout.apply_layout(world.definition,id)
		expect(twice==world.definition,id+" layout idempotent")
		var terrain=Terrain.new(); terrain.world=world; world.add_child(terrain); terrain.build(world.definition)
		await process_frame; await physics_frame
		var origin=p(world.definition.spawn)
		reachable(terrain,origin,origin,id+" spawn")
		for slot in range(3):
			reachable(terrain,origin+Vector2(-65+(slot-1)*48,65+(slot%2)*24),origin,id+" ally "+str(slot))
		for object in world.definition.objects:
			expect(not object_ids.has(object.id),"unique object "+object.id); object_ids[object.id]=true
			reachable(terrain,Vector2(object.x,object.y),origin,id+":"+object.id)
			if object.kind=="exit":
				expect(definitions.has(object.to),object.id+" destination exists")
				# World returns beside the forward exit in the target region.
				if data.order.find(object.to)>data.order.find(id): reachable(terrain,Vector2(object.x-55,object.y+70),origin,id+" backtrack landing")
		for group in world.definition.groups:
			expect(not group_ids.has(group.id),"unique group "+group.id); group_ids[group.id]=true
			expect(group.units.size()<=8,"bounded group "+group.id)
			for unit in group.units:
				expect(unit[0] in ["scout","crossbow","ironshield","sword","spear","shield","archer"],group.id+" known enemy")
				reachable(terrain,Vector2(unit[1],unit[2]),origin,group.id+":"+str(unit[0]))
		for decor in world.definition.layout.decor:
			expect(manifest.has(Hanshui.frame_key(decor)),id+" reuses existing illustration frame "+Hanshui.frame_key(decor))
		for solid in world.definition.map_details.solids:
			if solid.has("rect"):
				var r=solid.rect; expect(terrain.blocked(Vector2(r[0]+r[2]*.5,r[1]+r[3]*.5),0),id+" solid matches collision")
		for bounds in world.definition.layout.get("chasms",[]):
			var area=Rect2(bounds[0],bounds[1],bounds[2],bounds[3])
			expect(terrain.blocked(area.get_center(),0),id+" painted chasm is impassable")
		for bounds in world.definition.layout.get("bridges",[]):
			var area=Rect2(bounds[0],bounds[1],bounds[2],bounds[3]); var center=area.get_center()
			for offset in [-65,0,65]:
				var a=Vector2(area.position.x-20,center.y+offset); var b=Vector2(area.end.x+20,center.y+offset)
				expect(terrain.line_clear(a,b,18),id+" crossing has three clear lanes "+str(offset))
				reachable(terrain,a,origin,id+" left bridge landing")
				reachable(terrain,b,origin,id+" right bridge landing")
			var edge=Vector2(center.x,area.position.y+45)
			await swept_body(world,edge,Vector2(0,-150),id+" dash cannot leave chasm edge")
		if id=="jg_final":
			var arena=world.definition.arena; var middle=Vector2(arena.x,arena.y)
			for target in [middle+Vector2(-145,90),middle+Vector2(90,-35),Vector2(1110,500)]: reachable(terrain,target,origin,id+" boss/return feet")
			for i in range(24): reachable(terrain,middle+Vector2(cos(i*TAU/24)*310,sin(i*TAU/24)*215),origin,"Boss perimeter "+str(i))
		world.remove_child(terrain); terrain.queue_free()
		for node in world.actors.get_children(): world.actors.remove_child(node); node.queue_free()
		await process_frame
	expect(group_ids.size()==13,"thirteen finite Jigu groups")
	world.queue_free(); await process_frame
	print("JIGU_LAYOUT_VERIFY ",checks," checks; ",failures.size()," failures")
	quit(0 if failures.is_empty() else 1)

func swept_body(world,at: Vector2, motion: Vector2,label: String) -> void:
	var body=CharacterBody2D.new(); body.position=at; body.collision_layer=2; body.collision_mask=1
	var shape=CollisionShape2D.new(); var circle=CircleShape2D.new(); circle.radius=16; shape.shape=circle; body.add_child(shape)
	world.add_child(body); await physics_frame
	var collision=body.move_and_collide(motion)
	expect(collision!=null,label)
	body.queue_free(); await process_frame
