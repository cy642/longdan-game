extends SceneTree
## Chencang-only offline bake, with no campaign startup or player-save access.
const Terrain=preload("res://scripts/terrain.gd")
const Layout=preload("res://scripts/chencang_layout.gd")
var failures: Array=[]
class MapWorld extends Node2D:
	var actors=Node2D.new()
	var props: Array=[]
	var stage=""
	var definition: Dictionary={}
	var state={"chapter":4,"flags":{"cc_beacon_out":false},"tactics":{}}
	var mode="menu"
	var camera=Camera2D.new()
	func _ready() -> void: add_child(actors); add_child(camera)

func _initialize() -> void: call_deferred("run")
func rendered() -> void:
	await process_frame; await process_frame; await RenderingServer.frame_post_draw
func fail(message: String) -> void:
	failures.append(message); push_error(message)

func run() -> void:
	if DisplayServer.get_name()=="headless": fail("Chencang baking requires the graphical compatibility renderer."); quit(1); return
	var data=JSON.parse_string(FileAccess.get_file_as_string("res://data/chapter4.json"))
	if not data is Dictionary or data.StageDefinition.size()!=6: fail("Expected six Chencang maps."); quit(1); return
	if not Layout.load_sources(): quit(1); return
	Terrain.baking=true; Layout.baking=true
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://assets/maps"))
	var viewport=SubViewport.new(); viewport.transparent_bg=true; viewport.render_target_update_mode=SubViewport.UPDATE_DISABLED; root.add_child(viewport)
	await bake_props(viewport)
	if not failures.is_empty(): quit(1); return
	var world=MapWorld.new(); root.add_child(world)
	viewport.size=Vector2i(1600,1100); viewport.transparent_bg=false
	for id in data.order:
		world.stage=id; world.definition=Layout.apply_layout(data.StageDefinition[id],id)
		var terrain=Terrain.new(); terrain.world=world; world.add_child(terrain); terrain.build(world.definition)
		world.remove_child(terrain); viewport.add_child(terrain)
		viewport.render_target_update_mode=SubViewport.UPDATE_ONCE; await rendered()
		var image=viewport.get_texture().get_image(); image.convert(Image.FORMAT_RGB8)
		if image.save_png("res://assets/maps/"+id+".png")!=OK: fail("save "+id)
		else: print("BAKED_CHENCANG ",id," 1600x1100")
		viewport.remove_child(terrain); terrain.queue_free()
		for child in world.actors.get_children(): world.actors.remove_child(child); child.queue_free()
		await process_frame
	world.queue_free(); viewport.queue_free(); await process_frame
	print("CHENCANG_BAKE 6 grounds; 6 prop frames; ",failures.size()," failures")
	quit(0 if failures.is_empty() else 1)

func bake_props(viewport: SubViewport) -> void:
	var kinds=["city_gate","beacon_tower","warehouse","drum_tower","wall_segment","supply_crates"]
	var cell=Vector2i(512,512); var anchor=Vector2(256,450)
	viewport.size=Vector2i(1536,1024)
	var manifest={}
	for i in range(kinds.size()):
		var kind: String=kinds[i]; var width=120.0 if kind=="supply_crates" else 240.0 if kind=="beacon_tower" else 300.0
		var origin=Vector2(i%3*cell.x,int(i/3)*cell.y)
		var node=Layout.new(); node.layer="landmark"; node.item={"kind":kind,"width":width}; node.position=origin+anchor; viewport.add_child(node)
		manifest[kind]={"region":[int(origin.x),int(origin.y),cell.x,cell.y],"anchor":[anchor.x,anchor.y],"baked_width":width}
		if kind=="beacon_tower":
			var source: Dictionary=Layout.source_frames[kind]
			if not source.has("source_fire"): fail("beacon original needs an inspected brazier anchor"); continue
			var fire=Vector2(source.source_fire[0]-source.source_foot[0],source.source_fire[1]-source.source_foot[1])*width/float(source.source_footprint_width)
			manifest[kind].fire_anchor=[fire.x,fire.y]
	viewport.render_target_update_mode=SubViewport.UPDATE_ONCE; await rendered()
	var atlas=viewport.get_texture().get_image()
	for kind in manifest:
		var frame: Dictionary=manifest[kind]; var region=Rect2i(frame.region[0],frame.region[1],cell.x,cell.y)
		var used=atlas.get_region(region).get_used_rect()
		if used.size==Vector2i.ZERO or used.position.x<=0 or used.position.y<=0 or used.end.x>=cell.x or used.end.y>=cell.y:
			fail("clipped or empty Chencang frame: "+kind); continue
		frame.region=[region.position.x+used.position.x,region.position.y+used.position.y,used.size.x,used.size.y]
		frame.anchor=[anchor.x-used.position.x,anchor.y-used.position.y]
	if failures.is_empty():
		if atlas.save_png("res://assets/maps/chencang_props.png")!=OK: fail("save Chencang atlas")
		var file=FileAccess.open("res://assets/maps/chencang_props.json",FileAccess.WRITE); file.store_string(JSON.stringify(manifest,"  ")); file.close()
		print("BAKED_CHENCANG_PROPS 6 frames ",viewport.size)
	for child in viewport.get_children(): viewport.remove_child(child); child.queue_free()
	await process_frame
