extends SceneTree
## Opt-in native renderer sample, never an automated balance playthrough.
## Run with -- --label=<fresh-label>; earlier evidence cannot be overwritten.
const Game=preload("res://scripts/world.gd")
const Campaign=preload("res://scripts/campaign.gd")
const SCENARIOS=["cc_beacon","cc_bastion","cc_final"]
const EXPECTED_ENEMIES={"cc_beacon":6,"cc_bastion":4,"cc_final":1}
const NAMES={"cc_beacon":"6 enemies, 3 allies and a real warned arrow array","cc_bastion":"4 mixed enemies navigating courtyard walls and 3 allies","cc_final":"warden phase 2 duel"}
class MemoryCampaign extends Campaign:
	func read_save() -> Dictionary: return {}
	func save() -> bool: return true
var world
var report_path=""
var label=""
var errors: Array=[]
var initial_positions: Dictionary={}

func _initialize() -> void: call_deferred("run")

func percentile(values: Array,fraction: float) -> float:
	var sorted=values.duplicate(); sorted.sort()
	return float(sorted[mini(sorted.size()-1,int((sorted.size()-1)*fraction))])

func save_fingerprints() -> Dictionary:
	var result: Dictionary={}
	for path in [Campaign.SAVE_PATH,Campaign.LEGACY_PATH]:
		result[path]=FileAccess.get_file_as_bytes(path).hex_encode().sha256_text() if FileAccess.file_exists(path) else "absent"
	return result

func safe_point(point: Vector2) -> Vector2:
	if not world.terrain.blocked(point,18): return point
	var cell=world.terrain.nearest_cell(point)
	return Vector2(cell.x*40+20,cell.y*40+20)

func add_combatants(kinds: Array,points: Array,group: String) -> void:
	for index in range(kinds.size()):
		var enemy=world.spawn_enemy(kinds[index],safe_point(points[index]),group)
		# Only durability and the initial staging delay change. Production AI,
		# attack definitions, collider, speed and animation remain untouched.
		enemy.hp=100000; enemy.max_hp=100000; enemy.alerted=true; enemy.cooldown=.6+index*.08
		initial_positions[enemy.get_instance_id()]=enemy.position

func setup_scenario(id: String) -> void:
	world.detach_tactics(false); world.state.reset("normal",4); world.load_chapter(4)
	for flag in ["cc_breach","cc_route_front","cc_street_done","cc_warehouse"]: world.state.flags[flag]=true
	world.state.flags.cc_beacon_out=id!="cc_beacon"
	world.state.flags.cc_courtyard=id=="cc_final"; world.state.flags.cc_committed=id=="cc_final"
	# Suppress authored arrival queues so this bounded rendering fixture has
	# exactly the stated live load; the beacon actors retain a real main group
	# and therefore engage the production array scheduler and ranged slot.
	for group in world.definitions[id].groups: world.state.cleared.append(id+":"+str(group.id))
	var origin: Vector2={"cc_beacon":Vector2(1180,550),"cc_bastion":Vector2(890,610),"cc_final":Vector2(855,550)}[id]
	world.mode="playing"; world.hero.reset_combat(); world.enter_stage(id,origin,false); world.ui.hide_overlay()
	world.hero.position=safe_point(origin); world.hero.max_hp=100000; world.hero.hp=100000; world.hero.rage=100
	for ally in world.allies: ally.max_hp=100000; ally.hp=100000
	initial_positions.clear()
	if id=="cc_beacon":
		add_combatants(["scout","ironshield","crossbow","spear","sword","crossbow"],[Vector2(1050,510),Vector2(1335,520),Vector2(1390,440),Vector2(990,625),Vector2(1120,800),Vector2(1405,620)],"cc_b2")
		# At 7.8/8 seconds the real telegraph wins the ranged slot before the
		# staged crossbows can aim. Its full 1.25-second warning is still used.
		world.tactics.arrow_clock=7.8
	elif id=="cc_bastion":
		add_combatants(["ironshield","scout","spear","crossbow"],[Vector2(540,820),Vector2(920,760),Vector2(1040,600),Vector2(1120,450)],"qa_chencang_walls")
	else:
		world.begin_boss("warden")
		# Production Enemy.advance must perform its own half-health transition.
		# No phase flag, attack index or timer is assigned by the benchmark.
		world.boss.max_hp=2000000; world.boss.hp=900000
		initial_positions[world.boss.get_instance_id()]=world.boss.position
	world.keyboard_attack_held=true
	world.camera.zoom=Vector2.ONE*1.15; world.camera.position=world.hero.position; world.camera.reset_smoothing()

func choose_report_path() -> bool:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--label="): label=arg.trim_prefix("--label=")
	var valid=RegEx.new(); valid.compile("^[A-Za-z0-9][A-Za-z0-9_-]{0,63}$")
	if valid.search(label)==null:
		push_error("Supply -- --label=<fresh-label> using 1-64 letters, digits, underscores or hyphens."); return false
	report_path=ProjectSettings.globalize_path("res://../.qa/chencang-performance-"+label+".json")
	if FileAccess.file_exists(report_path):
		push_error("Refusing to overwrite earlier performance evidence: "+report_path); return false
	return true

func living_allies() -> int:
	var count=0
	for ally in world.allies:
		if is_instance_valid(ally) and ally.body_alive(): count+=1
	return count

func sample_scenario(id: String) -> Dictionary:
	setup_scenario(id)
	await create_timer(.8).timeout
	var frames: Array=[]; var draws: Array=[]; var objects: Array=[]
	var process_times: Array=[]; var physics_times: Array=[]; var alive: Array=[]; var allies: Array=[]
	var scenario_errors: Array=[]; var attack_ids: Dictionary={}; var boss_styles: Dictionary={}
	var warning_frames=0; var warning_minimum=INF; var phase2_frames=0; var non_playing_frames=0
	var initial_live=world.tactics.living_count(); var fired_at_start=world.tactics.volleys_fired
	var initial_arrays=world.tactics.arrays_started; var maximum_displacement=0.0
	var start=Time.get_ticks_usec(); var previous=start
	while Time.get_ticks_usec()-start<3200000:
		await process_frame
		var now=Time.get_ticks_usec(); frames.append((now-previous)/1000.0); previous=now
		draws.append(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
		objects.append(Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME))
		# Godot publishes these peak monitors roughly once per second. Their
		# sampled percentiles can retain warmup/entry work; unlike frames above,
		# they are NOT per-frame durations and must not be converted into FPS.
		process_times.append(Performance.get_monitor(Performance.TIME_PROCESS)*1000)
		physics_times.append(Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS)*1000)
		alive.append(world.tactics.living_count()); allies.append(living_allies())
		if world.mode!="playing": non_playing_frames+=1
		if not world.tactics.arrow_warnings.is_empty():
			warning_frames+=1
			for warning in world.tactics.arrow_warnings: warning_minimum=minf(warning_minimum,float(warning.total))
		for enemy in world.enemies:
			if not enemy.body_alive(): continue
			if initial_positions.has(enemy.get_instance_id()): maximum_displacement=maxf(maximum_displacement,enemy.position.distance_to(initial_positions[enemy.get_instance_id()]))
			if not enemy.action.is_empty():
				attack_ids[enemy.action.id]=true
				if enemy.boss_id=="warden" and enemy.phase2: boss_styles[str(enemy.action.def.get("style",""))]=true
		if is_instance_valid(world.boss) and world.boss.phase2 and world.boss.phase_time<=0: phase2_frames+=1
	var result={"stage":id,"scenario":NAMES[id],"frames":frames.size(),"mode":world.mode,"valid":false,"expected_active_enemies":EXPECTED_ENEMIES[id],"initial_active_enemies":initial_live,"non_playing_frames":non_playing_frames,"enemy_attack_actions_observed":attack_ids.size(),"maximum_enemy_displacement":maximum_displacement,"errors":scenario_errors}
	if frames.size()<2:
		scenario_errors.append("too few frames for a valid sample")
	else:
		result.merge({"median_ms":percentile(frames,.5),"p95_ms":percentile(frames,.95),"max_ms":percentile(frames,1.0),"draw_calls":percentile(draws,.5),"draw_calls_p95":percentile(draws,.95),"draw_calls_max":percentile(draws,1.0),"render_objects":percentile(objects,.5),"process_ms":percentile(process_times,.5),"process_p95_ms":percentile(process_times,.95),"physics_ms":percentile(physics_times,.5),"physics_p95_ms":percentile(physics_times,.95),"minimum_active_enemies":percentile(alive,0),"median_active_enemies":percentile(alive,.5),"peak_active_enemies":percentile(alive,1.0),"minimum_living_allies":percentile(allies,0),"sample_elapsed_seconds":(Time.get_ticks_usec()-start)/1000000.0})
		if result.minimum_active_enemies!=EXPECTED_ENEMIES[id] or result.peak_active_enemies!=EXPECTED_ENEMIES[id]: scenario_errors.append("actual live load did not retain the specified enemy count")
		if result.minimum_living_allies!=3: scenario_errors.append("expected three living allies throughout sample")
		if result.draw_calls_p95<=0: scenario_errors.append("renderer reported no draw calls")
	if world.mode!="playing" or non_playing_frames>0: scenario_errors.append("gameplay stopped during sample")
	if attack_ids.is_empty(): scenario_errors.append("sample did not observe any actual enemy attack action")
	if id=="cc_beacon":
		result.merge({"array_projectiles_fired":world.tactics.volleys_fired,"array_projectiles_fired_during_sample":world.tactics.volleys_fired-fired_at_start,"arrays_started":world.tactics.arrays_started,"arrays_started_before_sample":initial_arrays,"array_warning_frames":warning_frames,"minimum_warning_seconds":warning_minimum if is_finite(warning_minimum) else null})
		if world.tactics.volleys_fired-fired_at_start<=0: scenario_errors.append("beacon sample did not include actual array projectile release")
		if warning_frames==0 or warning_minimum<1.25: scenario_errors.append("beacon sample did not observe the complete-duration real warning")
		if world.tactics.arrays_started>3 or world.tactics.volleys_fired>6: scenario_errors.append("finite beacon array budget was exceeded")
	elif id=="cc_bastion":
		result["courtyard_wall_present"]=world.terrain.blocked(Vector2(720,780),18)
		if not result.courtyard_wall_present or maximum_displacement<8: scenario_errors.append("wall encounter did not retain its obstacle and moving combat load")
	else:
		result.merge({"boss_id":world.boss.boss_id if is_instance_valid(world.boss) else "","phase2":world.boss.phase2 if is_instance_valid(world.boss) else false,"active_phase2_frames":phase2_frames,"phase2_action_styles":boss_styles.keys()})
		if result.boss_id!="warden" or not result.phase2 or phase2_frames==0 or boss_styles.is_empty(): scenario_errors.append("Warden never entered active phase-two combat")
	result.valid=scenario_errors.is_empty()
	for message in scenario_errors: errors.append(id+": "+message)
	return result

func run() -> void:
	if DisplayServer.get_name()=="headless":
		push_error("Chencang performance requires the graphical compatibility renderer; use --check-only for parsing."); quit(1); return
	if not choose_report_path(): quit(1); return
	var fingerprints=save_fingerprints()
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	root.size=Vector2i(1280,720); Engine.max_fps=0
	world=Game.new(); world.test_mode=true; world.state=MemoryCampaign.new(); root.add_child(world)
	if world.get_window().focus_exited.is_connected(world.on_focus_lost): world.get_window().focus_exited.disconnect(world.on_focus_lost)
	await process_frame
	var results: Array=[]
	for id in SCENARIOS:
		var result=await sample_scenario(id); results.append(result); print("CHENCANG_GPU_PERF ",JSON.stringify(result))
	if save_fingerprints()!=fingerprints: errors.append("player save fingerprint changed")
	var report={"label":label,"status":"complete" if errors.is_empty() else "failed","renderer":RenderingServer.get_video_adapter_name(),"driver":RenderingServer.get_video_adapter_api_version(),"viewport":[1280,720],"camera_zoom":1.15,"vsync":false,"max_fps":0,"warmup_seconds":.8,"sample_seconds":3.2,"soft_effects":world.fx.soft,"results":results,"errors":errors,"scope":"Short native local hardware samples with extended-health sustained-combat fixtures. Not browser FPS, production enemy balance, human difficulty or first-play duration. MemoryCampaign performs no save reads or writes. A complete sample confirms fixture validity, not a target FPS threshold."}
	if FileAccess.file_exists(report_path):
		push_error("Refusing to overwrite report created during this run: "+report_path); errors.append("report path became occupied")
	else:
		DirAccess.make_dir_recursive_absolute(report_path.get_base_dir())
		var file=FileAccess.open(report_path,FileAccess.WRITE)
		if file==null: push_error("Cannot write performance report: "+report_path); errors.append("report write failed")
		else:
			file.store_string(JSON.stringify(report,"  ")); file.flush(); var write_error=file.get_error(); file.close()
			if write_error!=OK: push_error("Performance report write failed: "+str(write_error)); errors.append("report write failed")
			else: print("CHENCANG_GPU_PERF_REPORT ",report_path)
	world.keyboard_attack_held=false; world.queue_free()
	await process_frame; await process_frame; await create_timer(.12).timeout
	quit(0 if errors.is_empty() else 1)
