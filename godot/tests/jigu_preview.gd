extends SceneTree
## Controlled production scenes, not a complete playthrough. Every state is
## memory-only; output labels are append-only so comparisons retain evidence.
const Game=preload("res://scripts/world.gd")
const Campaign=preload("res://scripts/campaign.gd")
const Layout=preload("res://scripts/jigu_layout.gd")
class MemoryCampaign extends Campaign:
	func read_save() -> Dictionary: return {}
	func save() -> bool: return true
var world
var label=""
var captures: Array=[]
var failures: Array=[]
var requested_hero=Vector2.ZERO
const VIEWS={
	"jg_fog":Vector2(900,590),"jg_signal":Vector2(1010,560),
	"jg_pass":Vector2(840,550),"jg_rearguard":Vector2(1040,690),
	"jg_bridge":Vector2(1180,570),"jg_final":Vector2(950,640)
}

func _initialize() -> void: call_deferred("run")
func expect(value: bool,message: String) -> void:
	if not value: failures.append(message); push_error("JIGU_PREVIEW: "+message)

func place_camera(at: Vector2) -> void:
	world.camera.position=at; world.camera.zoom=Vector2.ONE*1.15
	world.camera.reset_smoothing(); world.camera.force_update_scroll()

func safe_feet(context: String) -> bool:
	var origin=Vector2(world.definition.spawn[0],world.definition.spawn[1])
	if not world.terrain.blocked(world.hero.position,world.hero.radius) and not world.terrain.find_path(origin,world.hero.position,world.hero.radius).is_empty(): return true
	var requested: Vector2=world.hero.position
	var best=INF; var selected=Vector2.INF
	var grid=world.terrain.grid; var region: Rect2i=grid.region
	for y in range(region.position.y,region.end.y):
		for x in range(region.position.x,region.end.x):
			var cell=Vector2i(x,y)
			if grid.is_point_solid(cell): continue
			var p: Vector2=grid.get_point_position(cell); var distance=requested.distance_squared_to(p)
			if distance>=best or world.terrain.blocked(p,world.hero.radius): continue
			if world.terrain.find_path(origin,p,world.hero.radius).is_empty(): continue
			best=distance; selected=p
	if not selected.is_finite(): expect(false,context+" no safe reachable feet"); return false
	world.hero.position=selected; place_camera(selected)
	print("JIGU_PREVIEW_SAFE_PLACEMENT ",context," requested=",requested," actual=",selected)
	return true

func physical_feet_clear() -> bool:
	var shape=CircleShape2D.new(); shape.radius=world.hero.radius
	var query=PhysicsShapeQueryParameters2D.new(); query.shape=shape
	query.transform=Transform2D(0,world.hero.position); query.collision_mask=1
	return world.get_world_2d().direct_space_state.intersect_shape(query,1).is_empty()

func enter(id: String,at: Vector2,clear_main=false) -> void:
	world.load_chapter(3); world.state.reset("normal",3)
	var index=Campaign.CHAPTER_STAGES[3].find(id)
	if index>=2: world.state.flags.jg_banner=true
	if index>=3: world.state.flags.jg_front=true; world.state.flags.jg_rear=true
	if index>=4: world.state.flags.jg_rearguard=true
	if index>=5: world.state.flags.jg_bridge_cut=true
	if clear_main:
		for group in world.definitions[id].main_groups: world.state.cleared.append(id+":"+str(group))
	world.mode="playing"; world.hero.reset_combat(); world.enter_stage(id,at,false); world.ui.hide_overlay()
	requested_hero=at; safe_feet(id)
	world.hero.facing=PI/4; world.hero.update_visual(); place_camera(world.hero.position)
	await process_frame; await physics_frame; await physics_frame
	if not clear_main:
		world.tactics.spawn_pending(0); world.tactics.spawn_pending(1.3)
		for enemy in world.enemies: enemy.update_visual()

func capture(name: String,scenario: String) -> void:
	if not safe_feet(name): return
	world.camera.force_update_scroll(); world.ui.support_clock=0; world.ui.refresh(.016)
	world.hero.update_visual(); world.fx.queue_redraw(); world.tactics.queue_redraw()
	await create_timer(.25).timeout
	await process_frame; await physics_frame; await process_frame; await RenderingServer.frame_post_draw
	var clear=not world.terrain.blocked(world.hero.position,world.hero.radius)
	var physical=physical_feet_clear()
	expect(clear and physical,name+" hero feet outside real terrain collision")
	var path=ProjectSettings.globalize_path("res://../.qa/jigu-"+label+"-"+name+".png")
	if FileAccess.file_exists(path): expect(false,"refusing existing image "+path); return
	expect(root.get_texture().get_image().save_png(path)==OK,"save "+name)
	var boss={}
	if is_instance_valid(world.boss):
		boss={"id":world.boss.boss_id,"phase2":world.boss.phase2,"hp":world.boss.hp,"style":world.boss.action.get("def",{}).get("style",""),"action_time":world.boss.action.get("t",0)}
	captures.append({"name":name,"scenario":scenario,"image":path,"stage":world.stage,"mode":world.mode,
		"hero":[world.hero.position.x,world.hero.position.y],"requested_hero":[requested_hero.x,requested_hero.y],
		"feet_clear":clear,"physical_feet_clear":physical,"viewport":[root.size.x,root.size.y],"zoom":world.camera.zoom.x,
		"camera":[world.camera.get_screen_center_position().x,world.camera.get_screen_center_position().y],
		"live_enemies":world.tactics.living_count(),"arrow_warnings":world.tactics.arrow_warnings.size(),
		"flags":world.state.flags.duplicate(),"boss":boss})
	print("JIGU_CAPTURE ",name," ",path)

func run() -> void:
	if DisplayServer.get_name()=="headless":
		push_error("Jigu preview requires the actual graphical renderer."); quit(1); return
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--label="): label=arg.trim_prefix("--label=")
	if label.is_empty() or label!=label.validate_filename():
		push_error("Supply a fresh plain --label, for example jigu-v1."); quit(1); return
	var manifest=ProjectSettings.globalize_path("res://../.qa/jigu-"+label+"-manifest.json")
	if FileAccess.file_exists(manifest): push_error("Refusing existing Jigu preview manifest."); quit(1); return
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://../.qa"))
	root.size=Vector2i(1280,720)
	world=Game.new(); world.test_mode=true; world.state=MemoryCampaign.new(); root.add_child(world)
	world.set_process(false); world.set_physics_process(false)
	if root.focus_exited.is_connected(world.on_focus_lost): root.focus_exited.disconnect(world.on_focus_lost)
	await process_frame
	for id in VIEWS:
		await enter(id,VIEWS[id])
		expect(world.tactics.living_count()>0,id+" finite real enemy group visible")
		await capture(id,"authored map with real actors, production 1.15 zoom")
	await enter("jg_signal",Vector2(1020,600))
	world.tactics.arrow_clock=7.0; world.tactics.advance_arrow_array(0)
	expect(not world.tactics.arrow_warnings.is_empty(),"signal creates real collision-checked arrow warning")
	await capture("signal-arrow-warning","actual pending locked arrow array before the banner is seized")
	await enter("jg_bridge",Vector2(1200,535),true)
	expect(world.interact(),"bridge interaction opens choice")
	expect(world.mode=="dialog","bridge choice uses production dialog")
	await capture("bridge-choice","two route consequences and optional return in the real dialog")
	await enter("jg_bridge",Vector2(1200,535),true)
	world.interact(); world.choose_route("jigu:hold")
	world.tactics.spawn_pending(0); world.tactics.spawn_pending(1.3)
	expect(world.state.flags.jg_bridge_held and world.tactics.living_count()==2,"hold bridge spawns exactly two real pursuers")
	world.hero.position=Vector2(650,570); requested_hero=world.hero.position; place_camera(Vector2(800,570))
	for enemy in world.enemies:
		enemy.stun=0; enemy.update_visual()
	await capture("bridge-hold","player returns along the retained bridge to meet the finite extra group")
	await enter("jg_bridge",Vector2(1200,535),true)
	world.interact(); world.choose_route("jigu:cut")
	place_camera(Vector2(950,570))
	# process_frame is emitted before Node._process. Two bounded frames let
	# the production prop observe the new flag before checking its texture.
	await process_frame; await process_frame
	var ropes=world.actors.get_node_or_null("Jigu_rope_posts")
	expect(ropes!=null and ropes.cut_variant and ropes.rendered_prop!=null,"cut decision swaps permanent baked rope variant")
	if ropes!=null:
		expect(Layout.prop_frames.has("rope_posts_680_220_cut"),"cut rope frame is present in exported atlas")
		if ropes.rendered_prop!=null and Layout.prop_frames.has("rope_posts_680_220_cut"):
			var frame: Dictionary=Layout.prop_frames["rope_posts_680_220_cut"]
			var expected=Rect2(frame.region[0],frame.region[1],frame.region[2],frame.region[3])
			expect(ropes.rendered_prop.texture is AtlasTexture and ropes.rendered_prop.texture.region==expected,"actual drawn atlas region is the permanent severed rope frame")
	await capture("bridge-cut","severed rope gaps and hanging ends persist; the deck and collision remain stable")
	await enter("jg_final",Vector2(1000,460),true)
	world.begin_boss("vanguard"); world.boss.attack_count=2
	world.boss.start_action(world.hero); world.boss.advance_action(.48,world.hero); world.boss.update_visual()
	place_camera(Vector2(1000,460))
	expect(world.boss.action.get("def",{}).get("style","")=="vanguard_sweep","phase one real delayed sweep")
	await capture("vanguard-phase1","real first-phase delayed sweep windup with production telegraph")
	await enter("jg_final",Vector2(1000,460),true)
	world.begin_boss("vanguard"); world.boss.hp=world.boss.max_hp*.49; world.boss.advance(.01)
	expect(world.boss.phase2,"half-health transition triggered through enemy advance")
	world.fx.entries=[]; world.fx.labels=[]
	world.boss.phase_time=0; world.boss.stun=0; world.boss.cooldown=0
	world.boss.start_action(world.hero)
	var first: Dictionary=world.boss.action.def
	world.boss.advance_action(first.windup+first.active+first.recovery+.22,world.hero)
	world.boss.update_visual(); place_camera(Vector2(1000,460))
	expect(world.boss.action.get("def",{}).get("style","")=="vanguard_return","phase two reaches actual follow-up sweep")
	await capture("vanguard-phase2","real second-phase charge chain enters its delayed returning sweep")
	var file=FileAccess.open(manifest,FileAccess.WRITE)
	expect(file!=null,"manifest writable")
	if file:
		file.store_string(JSON.stringify({"label":label,"renderer":RenderingServer.get_video_adapter_name(),"captures":captures,"failures":failures,"player_saves":"MemoryCampaign: no reads or writes","method":"controlled production scenes, not full interactive playthrough"},"  ",true)); file.close()
	print("JIGU_PREVIEW ",captures.size()," captures; ",failures.size()," failures")
	world.queue_free(); await process_frame
	quit(0 if failures.is_empty() else 1)
