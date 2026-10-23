extends SceneTree
## Opt-in native GPU sample. Use -- --label=<new-label>; prior evidence is
## never overwritten. Sustained combat fixtures measure rendering cost only.
const Game = preload("res://scripts/world.gd")
const Campaign = preload("res://scripts/campaign.gd")
const SCENARIOS = ["jg_signal","jg_bridge","jg_final"]
const NAMES = {"jg_signal":"6 enemies, 3 allies and a warned arrow array","jg_bridge":"4 bridge pursuers and 3 allies","jg_final":"vanguard phase 2 duel"}
class MemoryCampaign extends Campaign:
	func read_save() -> Dictionary: return {}
	func save() -> bool: return true
var world
var report_path = ""
var label = ""
var errors: Array = []

func _initialize() -> void: call_deferred("run")

func percentile(values: Array, fraction: float) -> float:
	var sorted = values.duplicate(); sorted.sort()
	return float(sorted[mini(sorted.size()-1,int((sorted.size()-1)*fraction))])

func save_fingerprints() -> Dictionary:
	var result: Dictionary = {}
	for path in [Campaign.SAVE_PATH,Campaign.LEGACY_PATH]:
		result[path] = FileAccess.get_file_as_bytes(path).hex_encode().sha256_text() if FileAccess.file_exists(path) else "absent"
	return result

func safe_point(p: Vector2) -> Vector2:
	if not world.terrain.blocked(p,18): return p
	var cell = world.terrain.nearest_cell(p)
	return Vector2(cell.x*40+20,cell.y*40+20)

func add_combatants(kinds: Array, origin: Vector2, group: String) -> void:
	var offsets = [Vector2(-130,-40),Vector2(155,-30),Vector2(210,-110),Vector2(-190,75),Vector2(140,115),Vector2(225,100)]
	for i in range(kinds.size()):
		var enemy = world.spawn_enemy(kinds[i],safe_point(origin+offsets[i]),group)
		enemy.hp = 100000; enemy.max_hp = 100000; enemy.alerted = true; enemy.cooldown = .6+i*.08

func setup_scenario(id: String) -> void:
	world.detach_tactics(false); world.state.reset("normal",3); world.load_chapter(3)
	for flag in ["jg_front","jg_rear","jg_rearguard"]: world.state.flags[flag] = true
	world.state.flags.jg_bridge_held = id in ["jg_bridge","jg_final"]
	world.state.flags.jg_last_guard = world.state.flags.jg_bridge_held
	world.state.flags.jg_banner = id != "jg_signal"
	for group in world.definitions[id].groups: world.state.cleared.append(id+":"+str(group.id))
	var origin: Vector2 = {"jg_signal":Vector2(1125,520),"jg_bridge":Vector2(850,570),"jg_final":Vector2(855,550)}[id]
	world.mode = "playing"; world.hero.reset_combat(); world.enter_stage(id,origin,false); world.ui.hide_overlay()
	world.hero.position = safe_point(origin)
	world.hero.max_hp = 100000; world.hero.hp = 100000; world.hero.rage = 100
	for ally in world.allies: ally.max_hp = 100000; ally.hp = 100000
	if id == "jg_signal":
		add_combatants(["scout","ironshield","crossbow","spear","sword","crossbow"],origin,"jg_s2")
		world.tactics.arrow_clock = 6.4
	elif id == "jg_bridge":
		add_combatants(["scout","spear","crossbow","ironshield"],origin,"qa_bridge_performance")
	else:
		world.begin_boss("vanguard")
		world.boss.max_hp = 2000000; world.boss.hp = 900000
	world.keyboard_attack_held = true
	world.camera.position = world.hero.position; world.camera.reset_smoothing()

func choose_report_path() -> bool:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--label="): label = arg.trim_prefix("--label=")
	var valid = RegEx.new(); valid.compile("^[A-Za-z0-9][A-Za-z0-9_-]{0,63}$")
	if valid.search(label) == null:
		push_error("Supply -- --label=<new-label> using 1-64 letters, digits, underscores or hyphens."); return false
	report_path = ProjectSettings.globalize_path("res://../.qa/jigu-performance-"+label+".json")
	if FileAccess.file_exists(report_path):
		push_error("Refusing to overwrite earlier performance evidence: "+report_path); return false
	return true

func run() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("Jigu performance requires the graphical compatibility renderer."); quit(1); return
	if not choose_report_path(): quit(1); return
	var fingerprints = save_fingerprints()
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	root.size = Vector2i(1280,720); Engine.max_fps = 0
	world = Game.new(); world.test_mode = true; world.state = MemoryCampaign.new(); root.add_child(world)
	if world.get_window().focus_exited.is_connected(world.on_focus_lost):
		world.get_window().focus_exited.disconnect(world.on_focus_lost)
	await process_frame
	var results: Array = []
	for id in SCENARIOS:
		setup_scenario(id)
		await create_timer(.8).timeout
		var frames: Array = []; var draws: Array = []; var objects: Array = []
		var process_times: Array = []; var physics_times: Array = []; var alive: Array = []
		var start = Time.get_ticks_usec(); var previous = start
		while Time.get_ticks_usec()-start < 3200000:
			await process_frame
			var now = Time.get_ticks_usec(); frames.append((now-previous)/1000.0); previous = now
			draws.append(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
			objects.append(Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME))
			process_times.append(Performance.get_monitor(Performance.TIME_PROCESS)*1000)
			physics_times.append(Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS)*1000)
			alive.append(world.tactics.living_count())
		var result = {"stage":id,"scenario":NAMES[id],"frames":frames.size(),"mode":world.mode,"valid":world.mode=="playing" and not frames.is_empty()}
		if not frames.is_empty():
			result.merge({"median_ms":percentile(frames,.5),"p95_ms":percentile(frames,.95),"max_ms":percentile(frames,1.0),"draw_calls":percentile(draws,.5),"draw_calls_p95":percentile(draws,.95),"render_objects":percentile(objects,.5),"process_ms":percentile(process_times,.5),"physics_ms":percentile(physics_times,.5),"peak_active_enemies":percentile(alive,1.0)})
		if id == "jg_signal":
			result["array_projectiles_fired"] = world.tactics.volleys_fired
			if world.tactics.volleys_fired == 0: result.valid = false; errors.append("signal sample did not include the warned arrow array")
		if id == "jg_final":
			result["phase2"] = world.boss.phase2
			if not world.boss.phase2: result.valid = false; errors.append("vanguard never entered phase 2")
		if not result.valid: errors.append("incomplete scenario: "+id)
		results.append(result); print("JIGU_GPU_PERF ",JSON.stringify(result))
	if save_fingerprints() != fingerprints: errors.append("player save fingerprint changed")
	var report = {"label":label,"status":"complete" if errors.is_empty() else "failed","renderer":RenderingServer.get_video_adapter_name(),"driver":RenderingServer.get_video_adapter_api_version(),"viewport":[1280,720],"vsync":false,"max_fps":0,"warmup_seconds":.8,"sample_seconds":3.2,"soft_effects":world.fx.soft,"results":results,"errors":errors,"scope":"Short native local hardware samples with extended-health sustained-combat fixtures. Not browser FPS, production enemy balance, human difficulty or first-play duration. MemoryCampaign performs no save reads or writes."}
	if FileAccess.file_exists(report_path):
		push_error("Refusing to overwrite report created during this run: "+report_path); errors.append("report path became occupied")
	else:
		DirAccess.make_dir_recursive_absolute(report_path.get_base_dir())
		var file = FileAccess.open(report_path,FileAccess.WRITE)
		if file == null: push_error("Cannot write performance report: "+report_path); errors.append("report write failed")
		else:
			file.store_string(JSON.stringify(report,"  ")); file.close(); print("JIGU_GPU_PERF_REPORT ",report_path)
	world.keyboard_attack_held = false; world.queue_free()
	await process_frame; await process_frame; await create_timer(.12).timeout
	quit(0 if errors.is_empty() else 1)
