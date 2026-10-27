extends SceneTree
## First-chapter ground only. Keeps all scenery atlases and later-chapter PNGs
## untouched; uses a small map world with no campaign reads, saves or gameplay.
const Terrain=preload("res://scripts/terrain.gd")
const Details=preload("res://scripts/map_details.gd")
const STAGES=["mountain","village","temple","house","fork","bridge"]
class MapWorld extends Node2D:
	var actors=Node2D.new()
	var props: Array=[]
	var stage=""
	var definition: Dictionary={}
	var state={"chapter":1,"flags":{"supplies":false},"tactics":{}}
	var mode="menu"
	var camera=Camera2D.new()
	func _ready() -> void: add_child(actors); add_child(camera)
var failures: Array=[]

func _initialize() -> void: call_deferred("run")
func rendered() -> void:
	await process_frame; await process_frame; await RenderingServer.frame_post_draw
func fail(message: String) -> void:
	failures.append(message); push_error(message)

func run() -> void:
	if DisplayServer.get_name()=="headless": fail("Changban bake needs the graphical compatibility renderer."); quit(1); return
	var data=JSON.parse_string(FileAccess.get_file_as_string("res://data/chapter1.json"))
	if not data is Dictionary or data.StageDefinition.size()!=6: fail("Expected six Changban regions."); quit(1); return
	Terrain.baking=true
	var viewport=SubViewport.new(); viewport.size=Vector2i(1600,1100); viewport.transparent_bg=false
	viewport.render_target_update_mode=SubViewport.UPDATE_DISABLED; root.add_child(viewport)
	var world=MapWorld.new(); root.add_child(world)
	for id in STAGES:
		world.stage=id; world.definition=Details.apply_layout(data.StageDefinition[id],id)
		world.props=[]
		for source in world.definition.get("props",[]):
			var prop=source.duplicate(true); prop.spent=false; prop.fuse=-1.0; world.props.append(prop)
		var terrain=Terrain.new(); terrain.world=world; world.add_child(terrain); terrain.build(world.definition)
		world.remove_child(terrain); viewport.add_child(terrain)
		viewport.render_target_update_mode=SubViewport.UPDATE_ONCE; await rendered()
		var image=viewport.get_texture().get_image(); image.convert(Image.FORMAT_RGB8)
		if image.save_png("res://assets/maps/"+id+".png")!=OK: fail("Cannot save "+id)
		else: print("BAKED_CHANGBAN ",id," 1600x1100")
		viewport.remove_child(terrain); terrain.queue_free()
		for child in world.actors.get_children(): world.actors.remove_child(child); child.queue_free()
		await process_frame
	world.queue_free(); viewport.queue_free(); await process_frame
	print("CHANGBAN_BAKE 6 grounds; ",failures.size()," failures; shared scenery atlases untouched")
	quit(0 if failures.is_empty() else 1)
