extends SceneTree
## Rebuild painted landmarks at the original logical anchors and physics sizes.
const Paint=preload("res://scripts/painted_props.gd")
class Art extends Node2D:
	var id=""
	var width=100.0
	var foot=Vector2.ZERO
	func _draw() -> void:
		if not Paint.draw_named(self,id,foot,width): push_error("Missing painted landmark: "+id)

func _initialize() -> void: call_deferred("run")
func render(viewport: SubViewport) -> void:
	viewport.render_target_update_mode=SubViewport.UPDATE_ONCE
	await process_frame; await process_frame; await RenderingServer.frame_post_draw

func run() -> void:
	if DisplayServer.get_name()=="headless": push_error("Landmark baking requires the graphical renderer."); quit(1); return
	var manifest=JSON.parse_string(FileAccess.get_file_as_string("res://assets/props/landmarks.json"))
	var viewport=SubViewport.new(); viewport.transparent_bg=true
	viewport.render_target_update_mode=SubViewport.UPDATE_DISABLED; root.add_child(viewport)
	for id in ["altar","stela","grain_rack","lantern"]:
		var frame=manifest.props[id]
		viewport.size=Vector2i(frame.image_size[0],frame.image_size[1])
		var art=Art.new(); art.id=id
		art.width={"altar":114.0,"stela":46.0,"grain_rack":104.0,"lantern":27.0}[id]
		art.foot=Vector2(0,5)
		art.position=Vector2(frame.anchor_px[0],frame.anchor_px[1]); art.scale=Vector2.ONE*2
		viewport.add_child(art); await render(viewport)
		var image=viewport.get_texture().get_image(); var used=image.get_used_rect()
		if used.size==Vector2i.ZERO or used.position.x<=0 or used.position.y<=0 or used.end.x>=image.get_width() or used.end.y>=image.get_height():
			push_error("Painted landmark clipping: "+id); quit(1); return
		if image.save_png(frame.image)!=OK: push_error("Could not write "+id); quit(1); return
		frame["source_frame"]=id
		frame["anchor_note"]="Painted source ground contact is placed at the retained logical anchor; existing physics metadata is unchanged."
		var file=FileAccess.open("res://assets/props/"+id+".json",FileAccess.WRITE); file.store_string(JSON.stringify(frame,"  ")+"\n"); file.close()
		art.queue_free(); await process_frame
		print("BAKED_PAINTED_LANDMARK ",id)
	manifest["renderer"]="image_gen illustrated sources / Godot 4.7.2 bake"
	manifest["source"]="res://art_source/painted/props-manifest.json"
	manifest.erase("samples")
	manifest["camera"]="Oblique top-down illustrated props, source foot anchor aligned to the original gameplay origin"
	var output=FileAccess.open("res://assets/props/landmarks.json",FileAccess.WRITE); output.store_string(JSON.stringify(manifest,"  ")+"\n"); output.close()
	var extras={}; var cells=[["gateway_126","gateway",126.0],["gateway_152","gateway",152.0],["gateway_212","gateway",212.0],["well_hoist","well",92.0]]
	var cell=Vector2i(448,384); var anchor=Vector2(224,326)
	viewport.size=Vector2i(cell.x*cells.size(),cell.y)
	for i in range(cells.size()):
		var art=Art.new(); art.id=cells[i][1]; art.width=cells[i][2]; art.position=Vector2(i*cell.x,0)+anchor
		# The interaction origin is the centre of the well ring, not its front rim.
		if art.id=="well": art.foot=Vector2(0,25)
		viewport.add_child(art)
	await render(viewport)
	var atlas=viewport.get_texture().get_image()
	for i in range(cells.size()):
		var local=atlas.get_region(Rect2i(i*cell.x,0,cell.x,cell.y)).get_used_rect()
		if local.size==Vector2i.ZERO or local.position.x<=0 or local.position.y<=0 or local.end.x>=cell.x or local.end.y>=cell.y:
			push_error("Painted marker clipping: "+str(cells[i][0])); quit(1); return
		extras[cells[i][0]]={"region":[i*cell.x+local.position.x,local.position.y,local.size.x,local.size.y],"anchor":[anchor.x-local.position.x,anchor.y-local.position.y]}
	if atlas.save_png("res://assets/props/painted_markers.png")!=OK: push_error("Cannot write marker atlas"); quit(1); return
	output=FileAccess.open("res://assets/props/painted_markers.json",FileAccess.WRITE); output.store_string(JSON.stringify(extras,"  ")+"\n"); output.close()
	print("BAKED_PAINTED_MARKERS ",extras.size())
	viewport.queue_free(); await process_frame; quit()
