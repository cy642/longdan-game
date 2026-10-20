extends "res://tests/hanshui_flow_verify.gd"
## Real world/physics checks for the convoy's active clearing route and
## actionable camp objectives. No invulnerability or real save writes.

func convoy_pacing() -> void:
	await fresh(); await enter("hs_return")
	var director=world.tactics; var cart=director.cart
	expect(cart.cruise_speed==112 and cart.catchup_speed==164 and director.cart_follow_radius==520,"production convoy reads the chapter pacing settings")
	var beginning=cart.position
	pump(.01); pump(1.3)
	expect(world.group_alive("hs_r1") and cart.position==beginning,"uncleared first roadblock holds the real cart")
	expect(not director.spawned.has("hs_r2") and not director.spawned.has("hs_r3"),"initial convoy never spawns later roadblocks together")
	world.hero.position=Vector2(1160,490); pump(.1)
	expect(not director.spawned.has("hs_r2") and not director.spawned.has("hs_r3") and cart.position==beginning,"running past unresolved combat cannot activate later roadblocks or move the cart")
	world.hero.position=Vector2(260,880)
	kill_live("hs_r1"); pump(.01)
	var index=int(world.state.tactics.get("escort_index",0))
	world.hero.position=Vector2(720,810)
	var before=cart.position
	pump(.1)
	expect(cart.position.distance_to(before)>12 and cart.position.distance_to(before)<=16.41,"safe convoy accelerates toward a leading player without exceeding catch-up speed")
	pump(1.3)
	expect(director.spawned.has("hs_r2") and world.group_alive("hs_r2"),"player reaching the next roadblock activates it before the cart arrives")
	expect(index==0 and int(world.state.tactics.get("escort_index",0))<2,"early encounter does not advance cart checkpoint")
	expect(not director.spawned.has("hs_r3"),"second encounter cannot also activate the third")
	# The active roadblock remains authoritative even with Zhao Yun forward.
	cart.position=director.point(director.points[2]); world.state.tactics.escort_index=2
	before=cart.position; pump(.2)
	expect(cart.position==before and not world.state.flags.cart,"cart cannot cross an uncleared active roadblock")
	expect(director.mission().text.contains("路障未清"),"held convoy explains the uncleared roadblock")
	kill_live("hs_r2"); pump(.01)
	world.hero.position=Vector2(130,950); before=cart.position
	pump(.3)
	var report=director.mission()
	expect(cart.position==before,"detouring far away for rescue parks the convoy")
	expect(report.title=="粮车等待接应" and report.pos==cart.position,"distant player receives a return-to-cart objective")
	expect(world.mode=="playing" and world.state.cleared.has("hs_return:hs_r2"),"detours do not fail the run or erase cleared combat")
	# A real enemy beside the cart overrides ordinary follow movement.
	world.hero.position=cart.position+Vector2(-70,75)
	var blocker=world.spawn_enemy("scout",cart.position+Vector2(80,0),"pacing_blocker")
	before=cart.position; pump(.2); report=director.mission()
	expect(cart.position==before and report.pos==blocker.position and report.text.contains("车旁有敌军"),"nearby live enemy parks convoy and becomes the objective")
	blocker.take_hit(10000,0,0,"player",0,true); pump(.01)
	# Moving behind the wagon keeps its cruise speed, without turning toward
	# the player or teleporting it back to an old point.
	before=cart.position; world.hero.position=cart.position+Vector2(0,180)
	pump(.1)
	expect(cart.position.distance_to(before)>11.1 and cart.position.distance_to(before)<11.3,"player behind cart uses cruise speed along its route")
	expect(not world.state.flags.cart,"cleared combat alone never awards cart completion")
	# Stress the highest requested speed against an actual native wall.
	var wall=StaticBody2D.new(); wall.collision_layer=1; wall.position=cart.position+Vector2(50,0)
	var shape=CollisionShape2D.new(); var rectangle=RectangleShape2D.new(); rectangle.size=Vector2(12,260)
	shape.shape=rectangle; wall.add_child(shape); world.add_child(wall); await settle()
	before=cart.position; cart.travel(before+Vector2(500,0),3,9999)
	expect(cart.position.x<=before.x+16.1,"catch-up travel still respects native terrain collision")
	wall.queue_free(); await settle()
	# Complete with the production checkpoints, encounters and collision.
	escort_until()
	expect(world.state.flags.cart and director.main_clear(),"faster convoy still completes all three roadblocks and its full route")

func camp_objectives() -> void:
	await fresh(); await enter("hs_camp",Vector2(640,360))
	var director=world.tactics
	var report=director.mission()
	expect(report.text.contains("正面破围"),"camp preparation discloses the viable direct route")
	world.set_command("hold")
	for i in range(world.allies.size()):
		world.allies[i].position=Vector2(300+i*45,800)
	world.allies[0].position=director.point(world.definition.tactics.guard_points[0])
	report=director.mission()
	expect(report.title.contains("1 / 3") and report.pos==Vector2(930,560),"partial hiding shows actual ready count and the next gate destination")
	for i in range(world.allies.size()): world.allies[i].position=director.point(world.definition.tactics.guard_points[i])
	report=director.mission()
	expect(report.title.contains("3 / 3") and report.text.contains("按 E 开门"),"fully hidden formation explains how to begin")
	await use("hs_gate"); pump(1.3)
	report=director.mission()
	expect(report.title.contains("余 2 人") and report.text.contains("两次"),"first probe displays real enemy count and the two-slash tell")
	world.state.tactics.deception_ok=false; report=director.mission()
	expect(report.text.contains("藏兵已暴露"),"lost concealment is visible before the drum decision")
	kill_live("gate_probe1"); pump(.01); pump(1.3)
	report=director.mission()
	expect(report.title.contains("2 / 2") and report.text.contains("侧背"),"second probe has a distinct shield-counter instruction")
	kill_live("gate_probe2"); pump(.01)
	report=director.mission()
	expect(report.pos==Vector2(820,500) and report.text.contains("4 秒"),"withdrawal directs the player back to the drum before its timing window")
	director.gate_state="BEST_WINDOW"; director.best_left=3.4
	report=director.mission()
	expect(report.text.contains("普通齐射"),"exposed stratagem does not promise a perfect volley")
	world.state.tactics.deception_ok=true; report=director.mission()
	expect(report.title.contains("3.4"),"concealed golden window keeps its live countdown")
	for ally in world.allies: ally.hp=0
	director.gate_state="PREPARE"; report=director.mission()
	expect(report.title=="正面破围" and report.pos==Vector2(930,560),"allies lost remains a clear playable gate objective")

func run() -> void:
	save_fingerprints=fingerprints()
	world=MemoryWorld.new(); world.test_mode=true; world.state=MemoryCampaign.new()
	root.add_child(world); world.set_physics_process(false); world.set_process(false)
	await settle(); world.ui.hide_overlay()
	await convoy_pacing(); await camp_objectives()
	expect(fingerprints()==save_fingerprints,"pacing checks never rewrite player saves")
	print("HANSHUI_PACING_VERIFY ",checks," checks; ",failures.size()," failures; maximum live enemies ",maximum_living)
	world.queue_free(); await process_frame; await process_frame
	quit(0 if failures.is_empty() else 1)
