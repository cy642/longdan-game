extends SceneTree
## Version-neutral motion study. Run this external script with either checkout's
## --path. Only common production World/Hero methods are used, no new rig API.
## Four live characters use actual movement/action ticks; positions are recentered
## to comparison cells after each tick. This isolates pose motion from camera/map
## changes and does not claim to be a gameplay or enemy-hit recording.
const Game=preload("res://scripts/world.gd")
const Campaign=preload("res://scripts/campaign.gd")
const HeroScene=preload("res://scenes/hero.tscn")
const DT=.05
const FRAME_COUNT=140
class MemoryCampaign extends Campaign:
	func read_save() -> Dictionary: return {}
	func save() -> bool: return true
class FlatTerrain extends Node2D:
	func blocked(_point: Vector2,_radius: float=0) -> bool: return false
	func line_clear(_from: Vector2,_to: Vector2,_radius: float=0) -> bool: return true
class Backdrop extends Node2D:
	func _draw() -> void:
		draw_rect(Rect2(0,0,1280,720),Color("203a3f"))
		for x in range(4):
			draw_rect(Rect2(x*320+12,112,296,420),Color("29464a"))
			draw_line(Vector2(x*320+46,400),Vector2(x*320+274,400),Color("88a89c",.4),1)
			draw_line(Vector2(x*320+160,390),Vector2(x*320+160,410),Color("88a89c",.7),1)
var world
var actors: Array=[]
var labels: Array=[]
var phase_label: Label
var total_displacement: Array=[]
var action_counts: Array=[]
var frames: Array=[]
var failures: Array=[]
var label=""
var output_root=""
var diagonal=false
var folder=""

func _initialize() -> void: call_deferred("run")
func fail(message: String) -> void: failures.append(message); push_error("HERO_MOTION_PREVIEW: "+message)
func caption(text: String,at: Vector2,size: int=20) -> Label:
	var node=Label.new(); node.text=text; node.position=at
	node.add_theme_font_override("font",load("res://assets/fonts/NotoSansSC-Regular.otf"))
	node.add_theme_font_size_override("font_size",size); root.add_child(node)
	return node
func save_fingerprints() -> Dictionary:
	var result={}
	for path in [Campaign.SAVE_PATH,Campaign.LEGACY_PATH]:
		result[path]=FileAccess.get_file_as_bytes(path).hex_encode().sha256_text() if FileAccess.file_exists(path) else "absent"
	return result
func phase(frame: int) -> String:
	if frame<60: return "WALK / distance-driven gait"
	if frame<72: return "STOP / settle on the planted boots"
	if frame<110: return "SPEAR / three real production attacks"
	if frame<122: return "DASH / real movement and landing"
	return "RECOVER / return to the original stance"

func run() -> void:
	if DisplayServer.get_name()=="headless": fail("Use the graphical renderer; --check-only can validate parsing."); quit(1); return
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--label="): label=arg.trim_prefix("--label=")
		elif arg.begins_with("--output-root="): output_root=arg.trim_prefix("--output-root=")
		elif arg=="--diagonal": diagonal=true
	var valid=RegEx.new(); valid.compile("^[A-Za-z0-9][A-Za-z0-9_-]{0,63}$")
	if valid.search(label)==null: fail("Supply a fresh plain --label."); quit(1); return
	if output_root.is_empty(): output_root=ProjectSettings.globalize_path("res://../.qa")
	folder=output_root.path_join("hero-motion-"+label)
	if DirAccess.dir_exists_absolute(folder): fail("Refusing to overwrite an existing motion capture folder."); quit(1); return
	if DirAccess.make_dir_recursive_absolute(folder)!=OK: fail("Cannot create capture folder."); quit(1); return
	var fingerprints=save_fingerprints()
	root.size=Vector2i(1280,720); root.content_scale_size=Vector2i(1280,720)
	world=Game.new(); world.test_mode=true; world.state=MemoryCampaign.new(); root.add_child(world)
	world.set_process(false); world.set_physics_process(false)
	world.set_process_input(false); world.set_process_unhandled_input(false); world.set_process_unhandled_key_input(false)
	if root.focus_exited.is_connected(world.on_focus_lost): root.focus_exited.disconnect(world.on_focus_lost)
	world.mode="playing"; world.state.flags.sword=true; world.ui.root.visible=false
	world.active_boss=""; world.boss=null; world.rescue={}; world.arrows=[]; world.loot=[]; world.props=[]
	world.enemies=[]; world.allies=[]; world.civilians=[]
	for child in world.actors.get_children():
		if child!=world.hero: world.actors.remove_child(child); child.queue_free()
	world.remove_child(world.terrain); world.terrain.queue_free()
	world.terrain=FlatTerrain.new(); world.add_child(world.terrain)
	world.fx.visible=false; world.sound.muted=true
	world.camera.position=Vector2(640,360); world.camera.zoom=Vector2.ONE
	world.camera.limit_left=-100000; world.camera.limit_top=-100000; world.camera.limit_right=100000; world.camera.limit_bottom=100000
	world.camera.position_smoothing_enabled=false; world.camera.reset_smoothing(); world.camera.force_update_scroll()
	var backdrop=Backdrop.new(); backdrop.z_index=-100; root.add_child(backdrop)
	caption("ZHAO YUN / PRODUCTION MOTION STUDY",Vector2(34,22),27)
	caption("Four directions · original source density, displayed at 1.7x · fixed 20 Hz simulation",Vector2(34,62),17)
	phase_label=caption("",Vector2(34,567),24)
	caption("Pose comparison only: real Hero.advance; empty physical stage; motion recentered per cell; no player saves.",Vector2(34,650),16)
	var names=["E","S","W","N"] if not diagonal else ["SE","SW","NW","NE"]
	for i in range(4):
		var hero=world.hero if i==0 else HeroScene.instantiate()
		if i>0: hero.world=world; world.actors.add_child(hero)
		hero.max_hp=200; hero.reset_combat(); hero.rage=100
		hero.facing=i*PI/2+(PI/4 if diagonal else 0); hero.position=Vector2(i*320+160,400); hero.scale=Vector2.ONE*1.7
		hero.update_visual(); actors.append(hero); action_counts.append(0); total_displacement.append(0.0)
		caption(names[i],Vector2(i*320+28,127),24)
		labels.append(caption("",Vector2(i*320+28,469),16))
	await process_frame; await physics_frame; await physics_frame
	for frame in range(FRAME_COUNT):
		var row={"frame":frame,"time":frame*DT,"phase":phase(frame),"actors":[]}
		phase_label.text=phase(frame)+"     %.2f s"%(frame*DT)
		for i in range(4):
			var hero=actors[i]; var heading=i*PI/2+(PI/4 if diagonal else 0); var direction=Vector2.from_angle(heading)
			if frame>=72 and frame<110 and hero.action.is_empty() and action_counts[i]<3:
				if hero.request("attack",Vector2.ZERO,heading): action_counts[i]+=1
			if frame==110 and not hero.request("dash",direction,heading): fail("direction %d could not start its real dash"%i)
			var move=direction if frame<60 else Vector2.ZERO
			var before: Vector2=hero.position
			hero.advance(DT,move,false,heading)
			var travelled=hero.position.distance_to(before); total_displacement[i]+=travelled
			hero.position=Vector2(i*320+160,400)
			var action_key="idle" if hero.action.is_empty() else str(hero.action.key)
			labels[i].text="%s  |  travel %.0f\n%s:%d"%[action_key,total_displacement[i],hero.visual.last_frame[0],hero.visual.last_frame[1]]
			row.actors.append({"direction":heading,"step_distance":hero.walk_distance,"travel":travelled,
				"action":action_key,"action_t":hero.action.get("t",0.0),"dash_left":hero.dash_left,"painting":hero.visual.last_frame.duplicate()})
		world.fx.advance(DT); world.hit_stop=0; world.shake=0
		await process_frame; await RenderingServer.frame_post_draw
		var file=folder.path_join("frame-%03d.png"%frame)
		if root.get_texture().get_image().save_png(file)!=OK: fail("Cannot save "+file)
		frames.append(row)
	for i in range(4):
		if action_counts[i]!=3: fail("direction %d did not execute all three attacks"%i)
		if total_displacement[i]<650: fail("direction %d did not use actual walking and dash displacement"%i)
		if not actors[i].action.is_empty() or actors[i].dash_left>0: fail("direction %d did not return to rest"%i)
	if save_fingerprints()!=fingerprints: fail("Player save fingerprint changed.")
	var manifest=FileAccess.open(folder.path_join("manifest.json"),FileAccess.WRITE)
	if manifest==null: fail("Cannot save manifest.")
	else:
		manifest.store_string(JSON.stringify({"label":label,"renderer":RenderingServer.get_video_adapter_name(),"frames":frames,
			"dt":DT,"count":FRAME_COUNT,"failures":failures,"scope":"Four production heroes on an empty stage, recentered to cells after each real advance. No combat enemies or map comparison. Not a full playthrough.","player_saves":"MemoryCampaign no reads/writes; fingerprints unchanged"},"  ")); manifest.close()
	print("HERO_MOTION_PREVIEW ",frames.size()," frames; ",failures.size()," failures; output=",folder)
	world.queue_free(); await process_frame; quit(0 if failures.is_empty() else 1)
