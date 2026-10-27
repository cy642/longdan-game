extends "res://tests/chencang_performance.gd"
## Native rendering load fixtures for the first-chapter slice. Source AI and
## hitboxes run normally, but durability is extended; this is not balance QA.
const CASES=["village","house","bridge"]
const LOADS={"village":6,"house":8,"bridge":1}
const LABELS={"village":"6 enemies, 3 idle companions and real player contact","house":"actual first rescue wave plus 5 staged enemies, healer and 3 active companions","bridge":"native Zhang He half-health transition and phase-two combat"}
var quality_draws=0

func observe_render() -> void: quality_draws+=1

func safe_point(point: Vector2) -> Vector2:
	if not world.terrain.blocked(point,18): return point
	var grid=world.terrain.grid; var best=INF; var selected=point
	for y in range(grid.region.position.y,grid.region.end.y):
		for x in range(grid.region.position.x,grid.region.end.x):
			var cell=Vector2i(x,y)
			if grid.is_point_solid(cell): continue
			var at: Vector2=grid.get_point_position(cell); var distance=at.distance_squared_to(point)
			if distance>=best or world.terrain.blocked(at,18): continue
			best=distance; selected=at
	if best==INF: errors.append("no safe native staging point near "+str(point))
	return selected

func live_count() -> int:
	var count=0
	for enemy in world.enemies:
		if is_instance_valid(enemy) and enemy.body_alive(): count+=1
	return count

func setup_scenario(id: String) -> void:
	world.detach_tactics(false); world.state.reset("normal",1); world.load_chapter(1)
	world.state.flags.mountain=true
	if id in ["house","bridge"]:
		world.state.flags.civilians=true; world.state.flags.healer=true
		world.state.flags.temple=true; world.state.flags.sword=true
	if id=="bridge":
		world.state.flags.adou=true; world.state.flags.house=true
		world.state.flags.motherDecision=true; world.state.flags.committed=true; world.state.flags.supplies=true
	for group in world.definitions[id].groups: world.state.cleared.append(id+":"+str(group.id))
	var origin: Vector2={"village":Vector2(850,850),"house":Vector2(1040,640),"bridge":Vector2(900,550)}[id]
	world.mode="playing"; world.hero.reset_combat(); world.enter_stage(id,origin,false); world.ui.hide_overlay()
	world.hero.position=safe_point(origin); world.hero.max_hp=100000; world.hero.hp=100000
	world.hero.rage=100; initial_positions.clear()
	if id=="village":
		add_combatants(["sword","shield","spear","sword","archer","archer"],[Vector2(925,850),Vector2(980,900),Vector2(800,720),Vector2(730,870),Vector2(1070,760),Vector2(1010,650)],"qa_quality_village")
	elif id=="house":
		world.start_rescue()
		world.rescue.healer.max_hp=100000; world.rescue.healer.hp=100000
		for enemy in world.enemies:
			if enemy.body_alive():
				enemy.hp=100000; enemy.max_hp=100000
				initial_positions[enemy.get_instance_id()]=enemy.position
		add_combatants(["sword","shield","spear","sword","archer"],[Vector2(1105,650),Vector2(950,680),Vector2(920,560),Vector2(1080,760),Vector2(1270,720)],"qa_quality_rescue_pressure")
	else:
		world.begin_boss("zhanghe")
		world.boss.max_hp=2000000; world.boss.hp=900000
		world.hero.position=safe_point(world.boss.position+Vector2(-120,60))
		initial_positions[world.boss.get_instance_id()]=world.boss.position
	for ally in world.allies: ally.max_hp=100000; ally.hp=100000
	world.keyboard_attack_held=true; world.mouse_attack_held=false; world.mouse_aim=false
	world.camera.zoom=Vector2.ONE*1.15; world.camera.position=world.hero.position; world.camera.reset_smoothing()
	world.state.checkpoint={"stage":id,"x":world.hero.position.x,"y":world.hero.position.y,"encounter":"rescue" if id=="house" else "zhanghe" if id=="bridge" else ""}

func choose_report_path() -> bool:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--label="): label=arg.trim_prefix("--label=")
	var valid=RegEx.new(); valid.compile("^[A-Za-z0-9][A-Za-z0-9_-]{0,63}$")
	if valid.search(label)==null: push_error("Supply a fresh plain --label."); return false
	report_path=ProjectSettings.globalize_path("res://../.qa/changban-performance-"+label+".json")
	if FileAccess.file_exists(report_path): push_error("Refusing existing performance report."); return false
	return true

func sample_scenario(id: String) -> Dictionary:
	setup_scenario(id)
	await create_timer(.8).timeout
	var frames: Array=[]; var draws: Array=[]; var objects: Array=[]; var alive: Array=[]; var allies: Array=[]
	var process_times: Array=[]; var physics_times: Array=[]; var phase_names: Dictionary={}; var attacks_seen: Dictionary={}; var contacts_seen: Dictionary={}
	var issues: Array=[]; var contact_frames=0; var phase_frames=0; var non_playing=0; var maximum_displacement=0.0
	var healer_min=100000.0; var start=Time.get_ticks_usec(); var previous=start; var initial_live=live_count()
	var draws_before=quality_draws; var minimized=0; var focused_frames=0; var window_modes: Dictionary={}
	while Time.get_ticks_usec()-start<3200000:
		await process_frame
		var now=Time.get_ticks_usec(); frames.append((now-previous)/1000.0); previous=now
		var window_mode=DisplayServer.window_get_mode(); window_modes[str(window_mode)]=true
		if window_mode==DisplayServer.WINDOW_MODE_MINIMIZED: minimized+=1
		if root.has_focus(): focused_frames+=1
		draws.append(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)); objects.append(Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME))
		# These monitors publish roughly one-second peaks, not per-frame times.
		process_times.append(Performance.get_monitor(Performance.TIME_PROCESS)*1000); physics_times.append(Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS)*1000)
		alive.append(live_count()); allies.append(living_allies())
		if world.mode!="playing": non_playing+=1
		if not world.fx.entries.filter(func(entry): return entry.type=="contact").is_empty(): contact_frames+=1
		if int(world.hero.action.get("contact_rank",0))>0: contacts_seen[world.hero.action.id]=true
		for enemy in world.enemies:
			if not enemy.body_alive(): continue
			if initial_positions.has(enemy.get_instance_id()): maximum_displacement=maxf(maximum_displacement,enemy.position.distance_to(initial_positions[enemy.get_instance_id()]))
			if not enemy.action.is_empty():
				attacks_seen[enemy.action.id]=true
				if enemy.boss_id=="zhanghe" and enemy.phase2: phase_names[str(enemy.action.def.name)]=true
		if is_instance_valid(world.boss) and world.boss.phase2 and world.boss.phase_time<=0: phase_frames+=1
		if id=="house" and not world.rescue.is_empty(): healer_min=minf(healer_min,world.rescue.healer.hp)
	var rendered=quality_draws-draws_before
	var undersampled=frames.size()<60 or rendered<60
	var result={"stage":id,"scenario":LABELS[id],"frames":frames.size(),"rendered_frames":rendered,"minimum_required_samples":60,"undersampled":undersampled,"window_modes":window_modes.keys(),"minimized_frames":minimized,"focused_frames":focused_frames,"expected_active_enemies":LOADS[id],"initial_active_enemies":initial_live,"mode":world.mode,"non_playing_frames":non_playing,"contact_frames":contact_frames,"player_contact_actions":contacts_seen.size(),"enemy_attack_actions":attacks_seen.size(),"maximum_enemy_displacement":maximum_displacement,"errors":issues}
	if frames.size()<2: issues.append("too few frames")
	else:
		result.merge({"median_ms":percentile(frames,.5),"p95_ms":percentile(frames,.95),"max_ms":percentile(frames,1),"draw_calls":percentile(draws,.5),"draw_calls_p95":percentile(draws,.95),"draw_calls_max":percentile(draws,1),"render_objects":percentile(objects,.5),"process_ms":percentile(process_times,.5),"process_p95_ms":percentile(process_times,.95),"physics_ms":percentile(physics_times,.5),"physics_p95_ms":percentile(physics_times,.95),"minimum_active_enemies":percentile(alive,0),"median_active_enemies":percentile(alive,.5),"peak_active_enemies":percentile(alive,1),"minimum_living_allies":percentile(allies,0),"sample_elapsed_seconds":(Time.get_ticks_usec()-start)/1000000.0})
		if result.minimum_active_enemies!=LOADS[id] or result.peak_active_enemies!=LOADS[id]: issues.append("staged load changed during sample")
		if result.minimum_living_allies!=3: issues.append("expected three living companion actors")
		if result.draw_calls_p95<=0: issues.append("no rendered draw calls")
	if non_playing>0 or world.mode!="playing": issues.append("gameplay stopped")
	if undersampled: issues.append("undersampled: fewer than 60 process or actually rendered frames; not a normal-performance result")
	if minimized>0: issues.append("window minimized during sample; renderer sample invalid")
	if contact_frames==0 or contacts_seen.is_empty(): issues.append("sample did not observe real player contact")
	if attacks_seen.is_empty(): issues.append("sample did not observe enemy attack actions")
	if id=="house":
		result.merge({"rescue_active":not world.rescue.is_empty(),"rescue_wave":world.rescue.get("wave",0),"minimum_healer_hp":healer_min})
		if world.rescue.is_empty() or healer_min<=0: issues.append("real healer rescue was not active throughout sample")
	if id=="bridge":
		result.merge({"phase2":world.boss.phase2 if is_instance_valid(world.boss) else false,"active_phase2_frames":phase_frames,"phase2_attacks":phase_names.keys()})
		if not result.phase2 or phase_frames==0 or phase_names.is_empty(): issues.append("Zhang He did not perform actual phase-two combat")
	result.valid=issues.is_empty()
	for issue in issues: errors.append(id+": "+str(issue))
	return result

func run() -> void:
	if DisplayServer.get_name()=="headless": push_error("Changban performance requires native graphics; use --check-only to parse."); quit(1); return
	if not choose_report_path(): quit(1); return
	var fingerprints=save_fingerprints()
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED); root.size=Vector2i(1280,720); Engine.max_fps=0
	RenderingServer.frame_post_draw.connect(observe_render)
	world=Game.new(); world.test_mode=true; world.state=MemoryCampaign.new(); root.add_child(world)
	world.set_process_input(false); world.set_process_unhandled_input(false); world.set_process_unhandled_key_input(false)
	if root.focus_exited.is_connected(world.on_focus_lost): root.focus_exited.disconnect(world.on_focus_lost)
	await process_frame
	var results: Array=[]
	for id in CASES:
		var result=await sample_scenario(id); results.append(result); print("CHANGBAN_GPU_PERF ",JSON.stringify(result))
	if save_fingerprints()!=fingerprints: errors.append("player save fingerprint changed")
	var report={"label":label,"status":"complete" if errors.is_empty() else "failed","renderer":RenderingServer.get_video_adapter_name(),"driver":RenderingServer.get_video_adapter_api_version(),"viewport":[1280,720],"camera_zoom":1.15,"vsync":false,"max_fps":0,"warmup_seconds":.8,"sample_seconds":3.2,"soft_effects":world.fx.soft,"results":results,"errors":errors,"monitor_semantics":"process/physics monitor values are repeated samples of roughly one-second peaks and can retain warmup work; not per-frame time or an FPS guarantee","scope":"Short native controlled fixtures with extended actor health, actual source AI/contact/rescue and native half-health phase transition. Three idle companion actors in village, active rescue allies in house, retreating companions at bridge. No balance, browser FPS or manual-duration claim; memory-only saves."}
	if FileAccess.file_exists(report_path): push_error("Report appeared during capture; refusing overwrite."); errors.append("report conflict")
	else:
		DirAccess.make_dir_recursive_absolute(report_path.get_base_dir())
		var file=FileAccess.open(report_path,FileAccess.WRITE)
		if file==null: errors.append("cannot write report")
		else: file.store_string(JSON.stringify(report,"  ")); file.flush(); file.close(); print("CHANGBAN_GPU_PERF_REPORT ",report_path)
	world.keyboard_attack_held=false; world.queue_free(); await process_frame; await process_frame; await create_timer(.12).timeout
	quit(0 if errors.is_empty() else 1)
