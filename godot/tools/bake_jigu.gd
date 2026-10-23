extends SceneTree
## Offline third-chapter bake. Does not start the campaign or touch player saves.
const Terrain=preload("res://scripts/terrain.gd")
const Jigu=preload("res://scripts/jigu_layout.gd")
var errors: Array=[]
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

func rendered() -> void:
	await process_frame; await process_frame; await RenderingServer.frame_post_draw

func run() -> void:
	if DisplayServer.get_name()=="headless":
		push_error("Jigu baking requires the graphical compatibility renderer."); quit(1); return
	var data=JSON.parse_string(FileAccess.get_file_as_string("res://data/chapter3.json"))
	if not data is Dictionary or data.StageDefinition.size()!=6:
		push_error("Expected six Jigu regions."); quit(1); return
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://assets/maps"))
	Terrain.baking=true; Jigu.baking=true
	var viewport=SubViewport.new(); viewport.transparent_bg=true
	viewport.render_target_update_mode=SubViewport.UPDATE_DISABLED; root.add_child(viewport)
	await bake_props(viewport,data.StageDefinition)
	if not errors.is_empty(): quit(1); return
	var world=MapWorld.new(); root.add_child(world)
	viewport.size=Vector2i(1600,1100); viewport.transparent_bg=false
	for id in data.order:
		world.stage=id; world.definition=Jigu.apply_layout(data.StageDefinition[id],id)
		var terrain=Terrain.new(); terrain.world=world; world.add_child(terrain); terrain.build(world.definition)
		world.remove_child(terrain); viewport.add_child(terrain)
		viewport.render_target_update_mode=SubViewport.UPDATE_ONCE; await rendered()
		var image=viewport.get_texture().get_image(); image.convert(Image.FORMAT_RGB8)
		if image.save_png("res://assets/maps/"+id+".png")!=OK: errors.append("save "+id)
		else: print("BAKED_JIGU ",id," 1600x1100")
		viewport.remove_child(terrain); terrain.queue_free()
		for child in world.actors.get_children(): world.actors.remove_child(child); child.queue_free()
		await process_frame
	world.queue_free(); viewport.queue_free(); await process_frame
	print("JIGU_BAKE ",6-errors.size()," grounds; ",errors.size()," failures")
	quit(0 if errors.is_empty() else 1)

func bake_props(viewport: SubViewport, definitions: Dictionary) -> void:
	var items: Array=[]; var seen={}
	for id in definitions:
		for item in definitions[id].layout.get("jigu_props",[]):
			var key=Jigu.frame_key(item)
			if seen.has(key): continue
			seen[key]=true; items.append({"key":key,"item":item})
			if id=="jg_bridge" and item.kind=="rope_posts":
				var cut=item.duplicate(true); cut.cut=true
				items.append({"key":Jigu.frame_key(cut),"item":cut})
	var cell=Vector2i(768,448); var anchor=Vector2(384,340); var columns=2
	viewport.size=Vector2i(cell.x*columns,cell.y*int(ceil(items.size()/float(columns))))
	var manifest={}
	for i in range(items.size()):
		var origin=Vector2(i%columns*cell.x,int(i/columns)*cell.y)
		var node=Jigu.new(); node.layer="landmark"; node.item=items[i].item
		node.position=origin+anchor; viewport.add_child(node)
		manifest[items[i].key]={"region":[int(origin.x),int(origin.y),cell.x,cell.y],"anchor":[anchor.x,anchor.y]}
	viewport.render_target_update_mode=SubViewport.UPDATE_ONCE; await rendered()
	var atlas=viewport.get_texture().get_image()
	for key in manifest:
		var frame=manifest[key]; var region=Rect2i(frame.region[0],frame.region[1],cell.x,cell.y)
		var used=atlas.get_region(region).get_used_rect()
		if used.size==Vector2i.ZERO or used.position.x<=0 or used.position.y<=0 or used.end.x>=cell.x or used.end.y>=cell.y:
			errors.append("clipped or empty frame "+key); push_error(errors.back()); continue
		frame.region=[region.position.x+used.position.x,region.position.y+used.position.y,used.size.x,used.size.y]
		frame.anchor=[anchor.x-used.position.x,anchor.y-used.position.y]
	if errors.is_empty():
		if atlas.save_png("res://assets/maps/jigu_props.png")!=OK: errors.append("save jigu props")
		var file=FileAccess.open("res://assets/maps/jigu_props.json",FileAccess.WRITE)
		file.store_string(JSON.stringify(manifest,"  ")); file.close()
		print("BAKED_JIGU_PROPS ",items.size()," frames ",viewport.size)
	for child in viewport.get_children(): viewport.remove_child(child); child.queue_free()
	await process_frame
