extends SceneTree
## Native contact sheets of production Enemy/ActorVisual nodes. Memory campaign,
## stopped simulation, no damage, no custom equipment and no player save access.
const Game = preload("res://scripts/world.gd")
const Campaign = preload("res://scripts/campaign.gd")
const Enemy = preload("res://scripts/enemy.gd")
const Roster = preload("res://scripts/enemy_roster.gd")
const DISPLAY_SCALE = 1.30
const ROWS = [
	[["cb_sword","mountain","sword","","m1"],["cb_spear","mountain","spear","","m2"],["cb_archer","mountain","archer","","m3"],["cb_shield","mountain","shield","","m3"],["cb_elite","fork","elite","","elite"],["cb_village","village","sword","","v1"]],
	[["hs_sword","hs_forest","sword","","hs_f2"],["hs_spear","hs_forest","spear","","hs_f1"],["hs_scout","hs_forest","scout","","hs_f1"],["hs_crossbow","hs_forest","crossbow","","hs_f2"],["hs_ironshield","hs_grain","ironshield","","hs_g1"],["hs_beacon","hs_grain","crossbow","","hs_beacon_guard"]],
	[["jg_sword","jg_fog","sword","","jg_f2"],["jg_spear","jg_fog","spear","","jg_f1"],["jg_scout","jg_fog","scout","","jg_f1"],["jg_crossbow","jg_fog","crossbow","","jg_f2"],["jg_ironshield","jg_fog","ironshield","","jg_f2"],["jg_signal","jg_signal","crossbow","","jg_s2"]],
	[["boss_xiahou","temple","boss","xiahou","boss"],["boss_zhanghe","bridge","boss","zhanghe","boss"],["boss_dujun","hs_final","boss","dujun","boss"],["boss_vanguard","jg_final","boss","vanguard","boss"]]
]
const PHASES = ["idle-left","walk-left","windup-left","strike-left","idle-right"]
class MemoryCampaign extends Campaign:
	func read_save() -> Dictionary: return {}
	func save() -> bool: return true
var world
var label = ""
var failures: Array = []
var captures: Array = []
var samples: Array = []
var font: Font
var annotations: Node2D
var heading: Label

func _initialize() -> void: call_deferred("run")
func expect(ok: bool,message: String) -> void:
	if not ok: failures.append(message); push_error("ENEMY_ROSTER_PREVIEW: "+message)
func output_path(suffix: String) -> String:
	return ProjectSettings.globalize_path("res://../.qa/enemy-roster-"+label+"-"+suffix)
func caption(text: String,point: Vector2,size: int = 15,width: float = 200) -> Label:
	var node = Label.new(); node.text = text; node.position = point
	node.size = Vector2(width,28); node.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	node.add_theme_font_override("font",font); node.add_theme_font_size_override("font_size",size)
	node.add_theme_color_override("font_color",Color("e7dfc3")); annotations.add_child(node)
	return node
func reference(at: Vector2) -> void:
	var line = Line2D.new(); line.width = 1.0; line.default_color = Color(.64,.82,.72,.48)
	line.points = PackedVector2Array([at+Vector2(-65,0),at+Vector2(65,0)]); annotations.add_child(line)
	var center = Line2D.new(); center.width = 1.0; center.default_color = Color(.88,.62,.40,.7)
	center.points = PackedVector2Array([at+Vector2(0,-5),at+Vector2(0,5)]); annotations.add_child(center)

func make_sheet() -> void:
	annotations = Node2D.new(); annotations.z_index = 20; root.add_child(annotations)
	font = load("res://assets/fonts/NotoSansSC-Regular.otf")
	heading = caption("",Vector2(18,10),23,1244)
	var names = ["长坂 · 追兵与巷战","汉水 · 营军与辎重","箕谷 · 山阵与号旗","独立将领 · 双剑 / 长枪 / 钩斧 / 长戟"]
	var feet = [217.0,428.0,639.0,898.0]
	var row_titles = [47.0,258.0,469.0,704.0]
	for row in range(ROWS.size()):
		caption(names[row],Vector2(14,row_titles[row]),15,1252)
		for column in range(ROWS[row].size()):
			var entry: Array = ROWS[row][column]
			world.stage = entry[1]; world.state.chapter = 3 if world.stage.begins_with("jg_") else 2 if world.stage.begins_with("hs_") else 1
			var enemy = Enemy.new(); enemy.world = world; enemy.group_id = entry[4]
			enemy.configure(entry[2],entry[3]); enemy.facing = PI
			var x = 110.0+column*210.0 if row < 3 else 170.0+column*310.0
			enemy.position = Vector2(x,feet[row]); enemy.scale = Vector2.ONE*DISPLAY_SCALE
			world.actors.add_child(enemy); world.enemies.append(enemy)
			expect(enemy.visual_profile.id == entry[0],entry[0]+" resolves from actual region/kind/group")
			var visual = enemy.visual
			expect(visual.rig != null and not visual.body.visible,entry[0]+" uses production articulated renderer")
			expect(visual.last_frame.size() >= 2 and visual.last_frame[0] == enemy.visual_profile.atlas and visual.last_frame[1] == enemy.visual_profile.index,entry[0]+" uses new independent atlas rather than legacy fallback")
			expect(visual.get("enemy_equipment") == null,entry[0]+" has no overlaid legacy equipment")
			samples.append({"enemy":enemy,"expected":entry[0],"stage":entry[1],"group":entry[4]})
			reference(enemy.position)
			caption(enemy.display_name,enemy.position+Vector2(-100,9),15)
			caption(entry[0],enemy.position+Vector2(-100,28),11)
	caption("统一展示倍率 ×1.30 · 细线为脚底原点 · 实际原画与连续姿态 / 左右镜像",Vector2(12,943),12,1256)
	expect(samples.size() == 22,"all eighteen soldiers and four commanders are represented")

func sample_pose(entry: Dictionary,phase: String) -> void:
	var enemy = entry.enemy; var visual = enemy.visual
	enemy.hp = enemy.max_hp; enemy.dead_time = 0; enemy.stun = 0; enemy.hurt_flash = 0
	enemy.phase_time = 0; enemy.phase2 = false; enemy.sequence = []; enemy.action = {}
	enemy.moving = false; enemy.walk_distance = 0; enemy.facing = 0.0 if phase == "idle-right" else PI
	visual.death_start = -1; visual.reaction_start = -10; visual.move_blend = 0
	visual.last_action_id = -1; visual.displayed_pose = visual.neutral_pose(); visual.action_entry_pose = visual.neutral_pose()
	if phase == "walk-left":
		enemy.moving = true; enemy.walk_distance = 18; visual.move_blend = 1.0
	elif phase in ["windup-left","strike-left"]:
		# Build an actual attack via Enemy.start_action. Only its pose clock is
		# sampled; no hit simulation or cosmetic replacement weapon is used.
		enemy.attack_count = 2 if enemy.boss_id in ["dujun","vanguard"] else 0
		world.hero.position = enemy.position+Vector2(-120,0)
		enemy.start_action(world.hero)
		var definition: Dictionary = enemy.action.def
		enemy.action.t = definition.windup*.90 if phase == "windup-left" else definition.windup+definition.active*.42
		# The bow's active window is a single release; a crossbow contains two
		# distinct recoil pulses. Capture the actual first pulse, not its reset.
		if enemy.kind == "crossbow" and phase == "strike-left": enemy.action.t = definition.windup+.045
	enemy.update_visual()
	expect(visual.position.is_zero_approx() and visual.scale == Vector2.ONE,entry.expected+" "+phase+" retains foot origin and body root scale")

func snapshot(phase: String) -> void:
	var titles = {"idle-left":"待机 · 左向","walk-left":"步行 · 左向","windup-left":"蓄势 · 左向","strike-left":"出手 · 左向","idle-right":"待机 · 右向镜像"}
	heading.text = "敌军原画实机验收 · "+titles[phase]+" · 18 兵 + 4 将"
	for entry in samples: sample_pose(entry,phase)
	await process_frame; await process_frame; await RenderingServer.frame_post_draw
	var image_path = output_path(phase+".png")
	expect(not FileAccess.file_exists(image_path),"capture path remains unused: "+phase)
	if FileAccess.file_exists(image_path): return
	var units: Array = []
	for entry in samples:
		var enemy = entry.enemy; var visual = enemy.visual
		var minimum = Vector2(INF,INF); var maximum = Vector2(-INF,-INF)
		for vertex in visual.rig.polygon:
			var point: Vector2 = visual.rig.get_global_transform()*vertex
			minimum = minimum.min(point); maximum = maximum.max(point)
		var bounds = Rect2(minimum,maximum-minimum)
		expect(Rect2(Vector2.ZERO,Vector2(1280,960)).encloses(bounds),entry.expected+" "+phase+" stays inside native viewport")
		units.append({"id":enemy.visual_profile.id,"name":enemy.display_name,"stage":entry.stage,"group":entry.group,
			"kind":enemy.kind,"boss":enemy.boss_id,"atlas":visual.last_frame[0],"frame":visual.last_frame[1],
			"profile_height":enemy.visual_profile.height,"model_scale":visual.current_scale,"display_scale":DISPLAY_SCALE,
			"foot_origin":[enemy.position.x,enemy.position.y],"visual_root_offset":[visual.position.x,visual.position.y],
			"facing":enemy.facing,"mesh_bounds":[bounds.position.x,bounds.position.y,bounds.size.x,bounds.size.y],
			"action":enemy.action.get("def",{}).get("name",""),"action_time":enemy.action.get("t",0),
			"legacy_equipment":visual.get("enemy_equipment") != null})
	var captured_image = root.get_texture().get_image()
	expect(captured_image.get_size() == Vector2i(1280,960),"capture has native 1280x960 pixels")
	var error = captured_image.save_png(image_path)
	expect(error == OK,"native contact sheet saves: "+phase)
	if error == OK: captures.append({"phase":phase,"image":image_path,"units":units})
	print("ENEMY_ROSTER_CAPTURE ",phase," ",image_path)

func run() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("Enemy roster preview requires the actual graphical renderer."); quit(1); return
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--label="): label = argument.trim_prefix("--label=")
	if label.is_empty() or label != label.validate_filename():
		push_error("Supply a fresh plain --label, for example enemy-art-v1."); quit(1); return
	var manifest_path = output_path("manifest.json")
	for suffix in ["manifest.json","idle-left.png","walk-left.png","windup-left.png","strike-left.png","idle-right.png"]:
		if FileAccess.file_exists(output_path(suffix)):
			push_error("Refusing to overwrite an existing roster capture; choose another label."); quit(1); return
	if not FileAccess.file_exists(Roster.ATLAS_PATH):
		push_error("New enemy atlas manifest is not ready. Generate and import it before visual acceptance."); quit(1); return
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://../.qa"))
	root.size = Vector2i(1280,960); root.content_scale_size = Vector2i(1280,960)
	RenderingServer.set_default_clear_color(Color("243a3c"))
	world = Game.new(); world.test_mode = true; world.state = MemoryCampaign.new(); root.add_child(world)
	world.set_physics_process(false); world.set_process(false); world.set_process_input(false); world.set_process_unhandled_input(false)
	if root.focus_exited.is_connected(world.on_focus_lost): root.focus_exited.disconnect(world.on_focus_lost)
	world.sound.muted = true; world.mode = "pause"; world.ui.hide(); world.fx.hide(); world.terrain.hide(); world.camera.enabled = false
	for actor in world.actors.get_children():
		if actor == world.hero: actor.hide()
		else: world.actors.remove_child(actor); actor.queue_free()
	world.enemies.clear(); world.allies.clear(); world.civilians.clear()
	await process_frame; await process_frame
	make_sheet()
	if failures.is_empty():
		for phase in PHASES: await snapshot(phase)
	var file = FileAccess.open(manifest_path,FileAccess.WRITE)
	expect(file != null,"preview manifest opens")
	if file:
		file.store_string(JSON.stringify({"label":label,"viewport":[1280,960],"display_scale":DISPLAY_SCALE,
			"renderer":RenderingServer.get_video_adapter_name(),"profile_count":samples.size(),"captures":captures,"failures":failures,
			"player_saves":"MemoryCampaign: read_save returns empty; save is a no-op","simulation":"world process/physics/input stopped; actual Enemy.start_action clocks sampled"},"  "))
		file.close()
	print("ENEMY_ROSTER_PREVIEW ",captures.size()," captures; ",samples.size()," profiles; ",failures.size()," failures")
	world.queue_free(); annotations.queue_free(); await process_frame; await process_frame
	quit(0 if failures.is_empty() else 1)
