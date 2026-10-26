extends SceneTree
## Real Chencang navigation and collision; optional --require-baked also checks
## the shipped cache path and that no excluded painting originals are loaded.
const Terrain=preload("res://scripts/terrain.gd")
const Layout=preload("res://scripts/chencang_layout.gd")
const SourceProps=preload("res://scripts/painted_props.gd")
const Ground=preload("res://scripts/painted_ground.gd")
var checks=0
var failures: Array=[]
var require_baked=false
class MapWorld extends Node2D:
	var actors=Node2D.new()
	var props: Array=[]
	var stage=""
	var definition: Dictionary={}
	var state={"chapter":4,"flags":{"cc_beacon_out":false},"tactics":{}}
	var mode="menu"
	var camera=Camera2D.new()
	var hero=Node2D.new()
	func _ready() -> void: add_child(actors); add_child(camera); add_child(hero)

func _initialize() -> void: call_deferred("run")
func expect(value: bool,message: String) -> void:
	checks+=1
	if not value: failures.append(message); push_error(message)
func p(value) -> Vector2: return Vector2(value[0],value[1])
func reachable(terrain,target: Vector2,origin: Vector2,label: String) -> void:
	expect(not terrain.blocked(target,18),label+" clear feet")
	var path=terrain.find_path(origin,target,18)
	expect(not path.is_empty() and path[-1].distance_to(target)<62,label+" reachable")
func route(terrain,values: Array,label: String) -> void:
	var clear=true
	for i in range(1,values.size()):
		var a=p(values[i-1]); var b=p(values[i]); var steps=maxi(1,int(ceil(a.distance_to(b)/10)))
		for n in range(steps+1):
			if terrain.blocked(a.lerp(b,float(n)/steps),18): clear=false
	expect(clear,label+" continuous radius-18 path")

func run() -> void:
	require_baked="--require-baked" in OS.get_cmdline_user_args()
	Terrain.baking=not require_baked
	var data=JSON.parse_string(FileAccess.get_file_as_string("res://data/chapter4.json"))
	expect(data is Dictionary,"chapter four JSON object")
	if not data is Dictionary: quit(1); return
	var defs: Dictionary=data.StageDefinition; expect(defs.size()==6 and data.order.size()==6,"six city regions")
	var world=MapWorld.new(); root.add_child(world)
	var group_ids={}; var object_ids={}; var cached_props=0
	for id in data.order:
		world.stage=id; world.definition=Layout.apply_layout(defs[id],id)
		expect(Layout.apply_layout(world.definition,id)==world.definition,id+" idempotent layout")
		var terrain=Terrain.new(); terrain.world=world; world.add_child(terrain); terrain.build(world.definition)
		await process_frame; await physics_frame
		var origin=p(world.definition.spawn)
		reachable(terrain,origin,origin,id+" spawn")
		for slot in range(3): reachable(terrain,origin+Vector2(-65+(slot-1)*48,65+slot%2*24),origin,id+" companion "+str(slot))
		for object in world.definition.objects:
			expect(not object_ids.has(object.id),"unique object "+object.id); object_ids[object.id]=true
			reachable(terrain,Vector2(object.x,object.y),origin,id+":"+object.id)
			if object.kind=="exit":
				expect(defs.has(object.to),object.id+" valid exit")
				if data.order.find(object.to)>data.order.find(id): reachable(terrain,Vector2(object.x-55,object.y+70),origin,object.id+" return landing")
		for group in world.definition.groups:
			expect(not group_ids.has(group.id),"unique group "+group.id); group_ids[group.id]=true
			expect(group.units.size()<=4,"finite small group "+group.id)
			for unit in group.units:
				expect(unit[0] in ["sword","spear","scout","crossbow","ironshield"],group.id+" existing combat kind")
				reachable(terrain,Vector2(unit[1],unit[2]),origin,group.id+":"+unit[0])
		for solid in world.definition.map_details.solids:
			var r=solid.rect; expect(terrain.blocked(Vector2(r[0]+r[2]*.5,r[1]+r[3]*.5),0),id+" solid is blocked")
		for road in world.definition.roads: route(terrain,road,id+" authored road")
		if id=="cc_street":
			expect(world.definition.route_groups.front==["cc_s_front"] and world.definition.route_groups.flank==["cc_s_flank1","cc_s_flank2"],"street routes preserve group contract")
			expect(not terrain.line_clear(Vector2(610,540),Vector2(930,540),2),"central block stops shots across the two routes")
			await swept(world,Vector2(600,540),Vector2(220,0),true,"street central house stops dash")
			await swept(world,Vector2(980,780),Vector2(0,-160),false,"street east lane permits dash")
		if id=="cc_bastion":
			var side=Vector2(1360,890); reachable(terrain,side,origin,"craftsman side gate")
			for slot in range(3): reachable(terrain,side+Vector2(-65+(slot-1)*48,65+slot%2*24),side,"side gate companion "+str(slot))
			for object in world.definition.objects: reachable(terrain,Vector2(object.x,object.y),side,"side entry to "+object.id)
			for group in world.definition.groups:
				for unit in group.units: reachable(terrain,Vector2(unit[1],unit[2]),side,"side entry to "+group.id)
		if id=="cc_final":
			var center=Vector2(1000,460)
			for target in [Vector2(855,550),Vector2(1090,425),Vector2(1110,500)]: reachable(terrain,target,origin,"warden feet")
			for i in range(24): reachable(terrain,center+Vector2(cos(i*TAU/24)*310,sin(i*TAU/24)*215),origin,"warden orbit "+str(i))
		if require_baked:
			expect(terrain.ground_texture!=null,id+" uses baked ground")
			for node in world.actors.get_children():
				if node is Layout:
					cached_props+=1; expect(node.rendered_prop!=null,id+" cached "+str(node.item.kind))
					if node.item.get("beacon",false):
						expect(node.beacon_on,"unclaimed beacon initially burning")
						world.state.flags.cc_beacon_out=true; node._process(.016)
						expect(not node.beacon_on,"claim flag switches beacon flame off")
						world.state.flags.cc_beacon_out=false
		world.remove_child(terrain); terrain.queue_free()
		for node in world.actors.get_children(): world.actors.remove_child(node); node.queue_free()
		await process_frame
	expect(group_ids.size()==15,"fifteen fixed encounter groups")
	if require_baked:
		expect(Layout.prop_frames.size()==6,"six independent city architecture frames")
		expect(cached_props>20,"city uses cached architecture throughout")
		expect(not Layout.sources_loaded and not SourceProps.loaded and not Ground.checked,"runtime never loaded excluded art originals")
	world.queue_free(); await process_frame
	print("CHENCANG_LAYOUT_VERIFY ",checks," checks; ",failures.size()," failures; require_baked=",require_baked)
	quit(0 if failures.is_empty() else 1)

func swept(world,at: Vector2,motion: Vector2,blocked: bool,label: String) -> void:
	var body=CharacterBody2D.new(); body.position=at; body.collision_layer=2; body.collision_mask=1
	var circle=CircleShape2D.new(); var shape=CollisionShape2D.new(); circle.radius=16; shape.shape=circle; body.add_child(shape)
	world.add_child(body); await physics_frame
	var collision=body.move_and_collide(motion)
	expect((collision!=null)==blocked,label)
	body.queue_free(); await process_frame
