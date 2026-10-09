extends SceneTree
## Compare the same desktop camera and live combat on the real rendering backend.
const Game=preload("res://scripts/world.gd")
var world

func _initialize() -> void:
	call_deferred("run")

func percentile(values: Array, fraction: float) -> float:
	values.sort()
	return values[mini(values.size()-1,int(values.size()*fraction))]

func run() -> void:
	if DisplayServer.get_name()=="headless":
		push_error("Use the graphical compatibility renderer to measure map rendering."); quit(1); return
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	root.size=Vector2i(1280,720); Engine.max_fps=0
	world=Game.new(); world.test_mode=true; root.add_child(world)
	await process_frame
	var label="baseline"
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--label="): label=arg.trim_prefix("--label=")
	var results=[]
	for scenario in [["mountain",Vector2(740,615)],["village",Vector2(330,495)],["bridge",Vector2(850,560)]]:
		world.mode="playing"; world.hero.reset_combat(); world.enter_stage(scenario[0],scenario[1],false); world.ui.hide_overlay()
		world.hero.hp=100000; world.hero.max_hp=100000; world.keyboard_attack_held=true
		for enemy in world.enemies: enemy.hp=100000; enemy.max_hp=100000
		await create_timer(.7).timeout
		var frames=[]; var draws=[]; var objects=[]; var process=[]; var physics=[]
		var start=Time.get_ticks_usec(); var previous=start
		while Time.get_ticks_usec()-start<2000000:
			await process_frame
			var now=Time.get_ticks_usec(); frames.append((now-previous)/1000.0); previous=now
			draws.append(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
			objects.append(Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME))
			process.append(Performance.get_monitor(Performance.TIME_PROCESS)*1000)
			physics.append(Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS)*1000)
		var result={"stage":scenario[0],"frames":frames.size(),"median_ms":percentile(frames,.5),"p95_ms":percentile(frames,.95),"draw_calls":percentile(draws,.5),"render_objects":percentile(objects,.5),"process_ms":percentile(process,.5),"physics_ms":percentile(physics,.5)}
		results.append(result); print("PERF ",JSON.stringify(result))
	var report={"label":label,"renderer":RenderingServer.get_video_adapter_name(),"viewport":[1280,720],"results":results}
	var file=FileAccess.open("res://../.qa/performance-"+label+".json",FileAccess.WRITE)
	file.store_string(JSON.stringify(report,"  ")); file.close()
	world.keyboard_attack_held=false; world.queue_free(); await process_frame; quit()
