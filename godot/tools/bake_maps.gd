extends SceneTree
## Offline art bake: all PNG pixels are rendered from the native vector map sources.
const Game=preload("res://scripts/world.gd")
const Terrain=preload("res://scripts/terrain.gd")
const Scenery=preload("res://scripts/scenery.gd")

func _initialize() -> void:
	call_deferred("run")

func wait_render() -> void:
	await process_frame; await process_frame; await RenderingServer.frame_post_draw

func run() -> void:
	if DisplayServer.get_name()=="headless":
		push_error("Map baking needs the graphical compatibility renderer."); quit(1); return
	Terrain.baking=true; Scenery.baking=true
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://assets/maps"))
	var world=Game.new(); world.test_mode=true; root.add_child(world)
	world.set_process(false); world.set_physics_process(false)
	await process_frame
	var viewport=SubViewport.new(); viewport.size=Vector2i(1600,1100); viewport.transparent_bg=true
	viewport.render_target_update_mode=SubViewport.UPDATE_ONCE; root.add_child(viewport)
	for id in world.definitions:
		world.mode="playing"; world.enter_stage(id,Vector2.INF,false)
		world.remove_child(world.terrain); viewport.add_child(world.terrain)
		world.terrain.position=Vector2.ZERO; world.terrain.z_index=0; viewport.render_target_update_mode=SubViewport.UPDATE_ONCE
		await wait_render()
		var image=viewport.get_texture().get_image(); image.convert(Image.FORMAT_RGB8)
		var error=image.save_png("res://assets/maps/"+id+".png")
		if error!=OK: push_error("Could not write "+id); quit(1); return
		viewport.remove_child(world.terrain); world.add_child(world.terrain)
		print("BAKED_GROUND ",id," 1600x1100")
	world.queue_free(); await process_frame
	var items=[]
	for i in range(16): items.append({"key":"tree_"+str(i),"data":{"kind":"tree","size":40,"seed":718+i*53,"variant":.1 if i<4 else .7}})
	for i in range(4): items.append({"key":"rock_"+str(i),"data":{"kind":"rock","size":22+i*.2}})
	var definitions=JSON.parse_string(FileAccess.get_file_as_string("res://data/chapter1.json")).StageDefinition
	var seen={}
	for definition in definitions.values():
		for hut in definition.huts:
			var data={"kind":hut[4],"w":hut[2],"h":hut[3]}; var key=Scenery.frame_key(data)
			if not seen.has(key): items.append({"key":key,"data":data}); seen[key]=true
	var cell=Vector2i(320,320); var columns=6; var rows=int(ceil(items.size()/float(columns)))
	viewport.size=Vector2i(cell.x*columns,cell.y*rows)
	var manifest={}; var anchor=Vector2(145,200)
	for i in range(items.size()):
		var p=Vector2(i%columns*cell.x,int(i/columns)*cell.y); var item=Scenery.new(); item.data=items[i].data
		item.position=p+anchor; viewport.add_child(item)
		manifest[items[i].key]={"region":[int(p.x),int(p.y),cell.x,cell.y],"anchor":[anchor.x,anchor.y],"size":item.data.get("size",1)}
	viewport.render_target_update_mode=SubViewport.UPDATE_ONCE; await wait_render()
	var atlas=viewport.get_texture().get_image(); atlas.save_png("res://assets/maps/scenery.png")
	# Trim transparent quad margins without shifting the foot or occlusion origin.
	for key in manifest:
		var frame=manifest[key]; var rect=Rect2i(frame.region[0],frame.region[1],frame.region[2],frame.region[3])
		var used=atlas.get_region(rect).get_used_rect()
		if used.size.x>0 and used.size.y>0:
			frame.region=[rect.position.x+used.position.x,rect.position.y+used.position.y,used.size.x,used.size.y]
			frame.anchor=[anchor.x-used.position.x,anchor.y-used.position.y]
	var file=FileAccess.open("res://assets/maps/scenery.json",FileAccess.WRITE); file.store_string(JSON.stringify(manifest,"  ")); file.close()
	print("BAKED_SCENERY ",items.size()," frames ",viewport.size)
	viewport.queue_free(); await process_frame; quit()
