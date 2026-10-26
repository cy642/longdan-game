extends SceneTree
## Controlled production scenes, not a full manual playthrough. The campaign
## stays in memory; filenames are append-only and game input is disabled.
const Game=preload("res://scripts/world.gd")
const Campaign=preload("res://scripts/campaign.gd")
const Layout=preload("res://scripts/chencang_layout.gd")
class MemoryCampaign extends Campaign:
	func read_save() -> Dictionary: return {}
	func save() -> bool: return true
var world
var label=""
var captures: Array=[]
var failures: Array=[]
var requested_hero=Vector2.ZERO
const VIEWS={
	"cc_outer":{"hero":Vector2(800,810),"camera":Vector2(600,610)},
	"cc_beacon":{"hero":Vector2(1020,500),"camera":Vector2(1100,340)},
	"cc_street":{"hero":Vector2(1040,760),"camera":Vector2(800,610)},
	"cc_store":{"hero":Vector2(850,850),"camera":Vector2(900,650)},
	"cc_bastion":{"hero":Vector2(1080,750),"camera":Vector2(1000,560)},
	"cc_final":{"hero":Vector2(1040,640),"camera":Vector2(1100,460)}
}
const NAMES=["cc_outer","cc_beacon","cc_street","cc_store","cc_bastion","cc_final","beacon-lit","beacon-out","beacon-arrow-warning","street-choice","street-front","street-flank","workers-side-entry","warden-sector","warden-circle","warden-phase2"]

func _initialize() -> void: call_deferred("run")
func expect(value: bool,message: String) -> void:
	if not value: failures.append(message); push_error("CHENCANG_PREVIEW: "+message)

func place_camera(at: Vector2) -> void:
	world.camera.position=at; world.camera.zoom=Vector2.ONE*1.15
	world.camera.reset_smoothing(); world.camera.force_update_scroll()

func safe_feet(context: String) -> bool:
	var origin=Vector2(world.definition.spawn[0],world.definition.spawn[1])
	if not world.terrain.blocked(world.hero.position,world.hero.radius) and not world.terrain.find_path(origin,world.hero.position,world.hero.radius).is_empty(): return true
	var requested: Vector2=world.hero.position
	var best=INF; var selected=Vector2.INF; var grid=world.terrain.grid
	var region: Rect2i=grid.region
	for y in range(region.position.y,region.end.y):
		for x in range(region.position.x,region.end.x):
			var cell=Vector2i(x,y)
			if grid.is_point_solid(cell): continue
			var p: Vector2=grid.get_point_position(cell); var distance=requested.distance_squared_to(p)
			if distance>=best or world.terrain.blocked(p,world.hero.radius): continue
			if world.terrain.find_path(origin,p,world.hero.radius).is_empty(): continue
			best=distance; selected=p
	if not selected.is_finite(): expect(false,context+" has no safe reachable feet"); return false
	world.hero.position=selected; place_camera(selected)
	print("CHENCANG_PREVIEW_SAFE_PLACEMENT ",context," requested=",requested," actual=",selected)
	return true

func physical_feet_clear() -> bool:
	var shape=CircleShape2D.new(); shape.radius=world.hero.radius
	var query=PhysicsShapeQueryParameters2D.new(); query.shape=shape
	query.transform=Transform2D(0,world.hero.position); query.collision_mask=1
	return world.get_world_2d().direct_space_state.intersect_shape(query,1).is_empty()

func materialize_queue() -> void:
	# The actual queue sees its warning first; no manually spawned mock units.
	world.tactics.spawn_pending(0); world.tactics.spawn_pending(2.0)
	for enemy in world.enemies: enemy.update_visual()

func enter(id: String,at: Vector2,options: Dictionary={}) -> void:
	world.load_chapter(4); world.state.reset("normal",4)
	var index=Campaign.CHAPTER_STAGES[4].find(id)
	if index>=1: world.state.flags.cc_breach=true
	if index>=2: world.state.flags.cc_beacon_out=true
	if index>=3: world.state.flags.cc_route_front=true; world.state.flags.cc_street_done=true
	if index>=4: world.state.flags.cc_warehouse=true
	if index>=5: world.state.flags.cc_courtyard=true
	for key in options.get("flags",{}):
		expect(str(key).begins_with("cc_"),"scenario overrides only chapter-four flags")
		world.state.flags[key]=options.flags[key]
	if options.get("clear_main",false):
		var groups: Array=world.definitions[id].main_groups.duplicate()
		if id=="cc_street": groups=world.definitions[id].route_groups.front if world.state.flags.cc_route_front else world.definitions[id].route_groups.flank if world.state.flags.cc_route_flank else []
		if id=="cc_store" and (not world.state.flags.cc_orders or world.state.flags.cc_reserve_called): groups.append("cc_w_reserve")
		for group in groups: world.state.cleared.append(id+":"+str(group))
	for group in options.get("cleared",[]): world.state.cleared.append(id+":"+str(group))
	world.mode="playing"; world.hero.reset_combat(); world.enter_stage(id,at,false); world.ui.hide_overlay()
	requested_hero=at; safe_feet(id)
	world.state.checkpoint={"stage":id,"x":world.hero.position.x,"y":world.hero.position.y,"encounter":""}
	expect(Campaign.valid(world.state.snapshot()),id+" initial scenario is a valid chapter-four save")
	for key in Campaign.JIGU_FLAGS: expect(not world.state.flags[key],id+" does not borrow Jigu progress")
	world.hero.facing=PI/4; world.hero.update_visual(); place_camera(world.hero.position)
	await process_frame; await process_frame; await physics_frame; await physics_frame
	if not options.get("clear_main",false): materialize_queue()

func capture(name: String,scenario: String) -> void:
	if not safe_feet(name): return
	world.camera.force_update_scroll(); world.ui.support_clock=0; world.ui.refresh(.016)
	world.hero.update_visual(); world.fx.queue_redraw(); world.tactics.queue_redraw()
	# process_frame is emitted before child _process; wait two actual frames
	# before reading beacon state. Combat/queue stepping remains frozen.
	await process_frame; await process_frame; await create_timer(.25).timeout
	await physics_frame; await process_frame; await RenderingServer.frame_post_draw
	var physical=physical_feet_clear(); var clear=not world.terrain.blocked(world.hero.position,world.hero.radius)
	var valid=Campaign.valid(world.state.snapshot())
	expect(clear and physical,name+" feet clear actual terrain collision")
	expect(valid,name+" state passes Campaign.valid")
	var path=ProjectSettings.globalize_path("res://../.qa/chencang-"+label+"-"+name+".png")
	if FileAccess.file_exists(path): expect(false,"refusing existing image "+path); return
	expect(root.get_texture().get_image().save_png(path)==OK,"save "+name)
	var boss={}; var beacons: Array=[]
	if is_instance_valid(world.boss):
		var action: Dictionary=world.boss.action
		boss={"id":world.boss.boss_id,"phase2":world.boss.phase2,"hp":world.boss.hp,"style":action.get("def",{}).get("style",""),"shape":action.get("def",{}).get("hit_shape","sector"),"time":action.get("t",0)}
	for node in world.actors.get_children():
		if node is Layout and node.item.get("beacon",false): beacons.append({"node":str(node.name),"burning":node.beacon_on,"cached":node.rendered_prop!=null})
	captures.append({"name":name,"scenario":scenario,"image":path,"stage":world.stage,"mode":world.mode,
		"hero":[world.hero.position.x,world.hero.position.y],"requested_hero":[requested_hero.x,requested_hero.y],
		"feet_clear":clear,"physical_feet_clear":physical,"valid_campaign":valid,
		"camera":[world.camera.get_screen_center_position().x,world.camera.get_screen_center_position().y],"zoom":world.camera.zoom.x,"viewport":[root.size.x,root.size.y],
		"live_enemies":world.tactics.living_count(),"arrow_warnings":world.tactics.arrow_warnings.size(),"flags":world.state.flags.duplicate(),"beacons":beacons,"boss":boss})
	print("CHENCANG_CAPTURE ",name," ",path)

func begin_warden() -> void:
	await enter("cc_final",Vector2(630,745),{"clear_main":true})
	expect(world.interact(),"warden challenge uses real interaction")
	expect(world.mode=="dialog","warden commitment dialog appears")
	world.choose_route("warden:commit")
	expect(world.active_boss=="warden" and world.state.flags.cc_committed,"real commit starts warden and records gate")
	expect(Campaign.valid(world.state.snapshot()),"warden encounter checkpoint is valid")
	place_camera(Vector2(1100,460))

func run() -> void:
	if DisplayServer.get_name()=="headless": push_error("Chencang preview requires the graphical renderer."); quit(1); return
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--label="): label=arg.trim_prefix("--label=")
	if label.is_empty() or label!=label.validate_filename(): push_error("Supply a fresh plain --label."); quit(1); return
	var manifest=ProjectSettings.globalize_path("res://../.qa/chencang-"+label+"-manifest.json")
	if FileAccess.file_exists(manifest): push_error("Refusing an existing preview manifest."); quit(1); return
	for name in NAMES:
		if FileAccess.file_exists(ProjectSettings.globalize_path("res://../.qa/chencang-"+label+"-"+name+".png")):
			push_error("Refusing a partially used preview label."); quit(1); return
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://../.qa"))
	root.size=Vector2i(1280,720)
	world=Game.new(); world.test_mode=true; world.state=MemoryCampaign.new(); root.add_child(world)
	world.set_process(false); world.set_physics_process(false)
	world.set_process_input(false); world.set_process_unhandled_input(false); world.set_process_unhandled_key_input(false)
	if root.focus_exited.is_connected(world.on_focus_lost): root.focus_exited.disconnect(world.on_focus_lost)
	await process_frame
	for id in VIEWS:
		await enter(id,VIEWS[id].hero); place_camera(VIEWS[id].camera)
		if id!="cc_street": expect(world.tactics.living_count()>0,id+" uses real queued enemy group")
		await capture(id,"authored city scene at production zoom with real actors and baked architecture")
	await enter("cc_beacon",Vector2(1190,465),{"clear_main":true}); place_camera(Vector2(1100,340))
	var beacon=world.actors.get_node_or_null("Chencang_beacon_tower")
	expect(beacon!=null and beacon.beacon_on and beacon.rendered_prop!=null,"real cached beacon starts lit")
	await capture("beacon-lit","completed guard fight, real brazier flame still burning before E")
	expect(world.interact(),"real E interaction extinguishes beacon")
	world.fx.advance(1.0)
	await process_frame; await process_frame
	expect(world.state.flags.cc_beacon_out and beacon!=null and not beacon.beacon_on,"actual beacon node stops fire after the saved flag changes")
	await capture("beacon-out","same camera after real E interaction; fire and smoke are off")
	await enter("cc_beacon",Vector2(1070,480)); place_camera(Vector2(1100,370))
	world.tactics.arrow_clock=8.0; world.tactics.advance_arrow_array(0)
	expect(not world.tactics.arrow_warnings.is_empty(),"actual collision-checked arrow array has visible pending warnings")
	await capture("beacon-arrow-warning","real locked arrow lanes, before the barrage releases")
	await enter("cc_street",Vector2(300,920)); place_camera(Vector2(650,650))
	expect(world.interact() and world.mode=="dialog","real route-choice dialog opens")
	await capture("street-choice","both route costs and downstream effects in production dialog")
	world.choose_route("chencang:front"); materialize_queue()
	expect(world.state.flags.cc_route_front and not world.state.flags.cc_route_flank and world.tactics.living_count()==3,"front route produces exactly the selected three guards")
	world.hero.position=Vector2(1040,855); requested_hero=world.hero.position; place_camera(Vector2(1100,650))
	await capture("street-front","actual east-street shield, spear and crossbow group after the choice")
	await enter("cc_street",Vector2(300,920)); world.interact(); world.choose_route("chencang:flank"); materialize_queue()
	expect(world.state.flags.cc_route_flank and not world.state.flags.cc_route_front and world.tactics.living_count()==2,"flank route produces only its first two guards")
	world.hero.position=Vector2(430,800); requested_hero=world.hero.position; place_camera(Vector2(580,580))
	await capture("street-flank","actual west alley first group; the second is not spawned early")
	await enter("cc_store",Vector2(1420,895),{"clear_main":true,"flags":{"cc_orders":true,"cc_workers":true,"cc_warehouse":true},"cleared":["cc_workers_guard"]})
	expect(world.interact(),"craftsman exit accepts the completed real task state")
	expect(world.pending_stage.get("id","")=="cc_bastion","craftsman exit queues the real next region")
	world._physics_process(0)
	await process_frame; await physics_frame; await physics_frame
	expect(world.stage=="cc_bastion" and world.hero.position.distance_to(Vector2(1360,890))<1,"actual exit dispatcher lands at the craftsman side gate")
	requested_hero=Vector2(1360,890); materialize_queue(); place_camera(Vector2(1180,760))
	await capture("workers-side-entry","real craftsman exit and eastern assembly camp, without bypassing courtyard groups")
	await begin_warden(); world.boss.attack_count=1; world.boss.start_action(world.hero); world.boss.advance_action(.52,world.hero); world.boss.update_visual()
	expect(world.boss.action.get("def",{}).get("style","")=="warden_sweep","real sector hammer windup")
	await capture("warden-sector","phase-one wide hammer windup with the real sector telegraph")
	await begin_warden(); world.boss.attack_count=2; world.boss.start_action(world.hero); world.boss.advance_action(.56,world.hero); world.boss.update_visual()
	expect(world.boss.action.get("def",{}).get("hit_shape","")=="circle" and world.boss.action.get("def",{}).get("style","")=="warden_quake","actual third move is the circle-impact attack")
	await capture("warden-circle","real circular ground-impact warning, before its actual hit frame")
	await begin_warden(); world.boss.hp=world.boss.max_hp*.49; world.boss.advance(.01)
	expect(world.boss.phase2,"actual half-health transition triggers")
	world.fx.advance(1.3); world.boss.phase_time=0; world.boss.stun=0; world.boss.cooldown=0
	world.boss.start_action(world.hero)
	var first: Dictionary=world.boss.action.def
	world.boss.advance_action(first.windup+first.active+first.recovery+.24,world.hero); world.boss.update_visual()
	expect(world.boss.action.get("def",{}).get("style","")=="warden_return","real second-phase chain reaches its delayed return")
	await capture("warden-phase2","actual advancing step followed by the second-phase delayed return")
	expect(captures.size()==NAMES.size(),"all sixteen planned scenes captured")
	var file=FileAccess.open(manifest,FileAccess.WRITE); expect(file!=null,"manifest writable")
	if file:
		file.store_string(JSON.stringify({"label":label,"renderer":RenderingServer.get_video_adapter_name(),"captures":captures,"failures":failures,"player_saves":"MemoryCampaign: no reads or writes","method":"controlled production scenes; not a complete manual playthrough"},"  ",true)); file.close()
	print("CHENCANG_PREVIEW ",captures.size()," captures; ",failures.size()," failures")
	world.queue_free(); await process_frame
	quit(0 if failures.is_empty() else 1)
