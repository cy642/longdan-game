extends SceneTree
## Explicit local GPU benchmark. It never enables a shipped performance overlay.
const Game=preload("res://scripts/world.gd")
var world

func _initialize() -> void:
	call_deferred("run")

func percentile(values: Array, fraction: float) -> float:
	values.sort()
	return float(values[mini(values.size()-1,int(values.size()*fraction))])

func safe_point(p: Vector2) -> Vector2:
	if not world.terrain.blocked(p,18): return p
	var cell=world.terrain.nearest_cell(p)
	return Vector2(cell.x*40+20,cell.y*40+20)

func add_combatants(kinds: Array, origin: Vector2) -> void:
	var offsets=[Vector2(-130,-40),Vector2(155,-30),Vector2(265,-105),Vector2(-200,75),Vector2(140,135),Vector2(260,120),Vector2(-245,-125),Vector2(25,-200)]
	for i in range(kinds.size()):
		var enemy=world.spawn_enemy(kinds[i],safe_point(origin+offsets[i]),"qa_performance")
		enemy.hp=100000; enemy.max_hp=100000; enemy.alerted=true; enemy.cooldown=.6+i*.08

func setup_scenario(id: String) -> void:
	world.state.reset("normal",2); world.load_chapter(2)
	world.state.flags.huangzhong=true; world.state.flags.cart=true; world.state.flags.beacon=true
	world.state.tactics={"gate":"COUNTER_DIRECT","volley_spent":true,"roster":[]}
	var origin={"hs_forest":Vector2(760,660),"hs_camp":Vector2(1170,560),"hs_river":Vector2(1000,750),"hs_final":Vector2(840,560)}[id]
	for group in world.definitions[id].groups: world.state.cleared.append(id+":"+str(group.id))
	world.mode="playing"; world.hero.reset_combat(); world.enter_stage(id,origin,false); world.ui.hide_overlay()
	world.hero.max_hp=100000; world.hero.hp=100000; world.hero.rage=100
	for ally in world.allies: ally.hp=100000; ally.max_hp=100000
	if id=="hs_forest": add_combatants(["scout","ironshield","crossbow","spear","scout","crossbow","sword","ironshield"],origin)
	elif id=="hs_camp": add_combatants(["ironshield","scout","crossbow","crossbow"],origin)
	elif id=="hs_river":
		world.state.tactics.roster=[{"id":"pursuer_0","kind":"ironshield","hp":100000.0},{"id":"pursuer_1","kind":"scout","hp":100000.0},{"id":"pursuer_2","kind":"crossbow","hp":100000.0},{"id":"pursuer_3","kind":"crossbow","hp":100000.0}]
		world.tactics.restore_roster()
		for enemy in world.enemies: enemy.hp=100000; enemy.max_hp=100000; enemy.alerted=true
	else:
		world.begin_boss("dujun")
		world.boss.max_hp=2000000; world.boss.hp=900000
	world.keyboard_attack_held=true
	world.camera.position=world.hero.position; world.camera.reset_smoothing()

func run() -> void:
	if DisplayServer.get_name()=="headless": push_error("Use the graphical compatibility renderer."); quit(1); return
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	root.size=Vector2i(1280,720); Engine.max_fps=0
	world=Game.new(); world.test_mode=true; root.add_child(world)
	world.state.save_path="user://longdan-hanshui-performance-qa.json"
	if world.get_window().focus_exited.is_connected(world.on_focus_lost): world.get_window().focus_exited.disconnect(world.on_focus_lost)
	await process_frame
	var results=[]
	for id in ["hs_forest","hs_camp","hs_river","hs_final"]:
		setup_scenario(id)
		await create_timer(.8).timeout
		var frames=[]; var draws=[]; var objects=[]; var process=[]; var physics=[]; var alive=[]
		var start=Time.get_ticks_usec(); var previous=start
		while Time.get_ticks_usec()-start<3200000:
			await process_frame
			var now=Time.get_ticks_usec(); frames.append((now-previous)/1000.0); previous=now
			draws.append(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
			objects.append(Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME))
			process.append(Performance.get_monitor(Performance.TIME_PROCESS)*1000)
			physics.append(Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS)*1000)
			alive.append(world.tactics.living_count())
		var result={"stage":id,"scenario":{"hs_forest":"8 enemies + 3 allies","hs_camp":"4 outside gate + 3 allies","hs_river":"4 carried pursuers + 3 allies","hs_final":"dujun phase 2"}[id],"frames":frames.size(),"median_ms":percentile(frames,.5),"p95_ms":percentile(frames,.95),"max_ms":percentile(frames,1.0),"draw_calls":percentile(draws,.5),"draw_calls_p95":percentile(draws,.95),"render_objects":percentile(objects,.5),"process_ms":percentile(process,.5),"physics_ms":percentile(physics,.5),"peak_active_enemies":percentile(alive,1.0),"mode":world.mode}
		results.append(result); print("HANSHUI_GPU_PERF ",JSON.stringify(result))
	var report={"renderer":RenderingServer.get_video_adapter_name(),"driver":RenderingServer.get_video_adapter_api_version(),"viewport":[1280,720],"vsync":false,"max_fps":0,"warmup_seconds":.8,"sample_seconds":3.2,"soft_effects":world.fx.soft,"results":results,"scope":"Native local hardware rendering; not browser or first-time play duration."}
	var file=FileAccess.open("res://../.qa/hanshui-performance.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(report,"  ")); file.close()
	world.keyboard_attack_held=false; world.queue_free()
	await process_frame; await process_frame; await create_timer(.12).timeout
	quit()
