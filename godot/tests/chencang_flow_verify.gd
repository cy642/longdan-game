extends "res://tests/jigu_flow_verify.gd"
## Accelerated production encounters and E interactions, not a human balance
## playthrough. Shared harness owns memory-only persistence and real defeats.

func expect(value: bool, message: String) -> void:
	checks += 1
	if not value: failures.append(message); push_error("CHENCANG_FLOW: "+message)

func fresh(level: String = "normal") -> void:
	world.detach_tactics(false); world.state = MemoryCampaign.new()
	world.start_game(level,4); end_dialogue(); await settle()
	expect(world.state.chapter==4 and world.stage=="cc_outer" and world.tactics.name=="ChencangDirector","fresh fourth chapter opens its real director")

func resume_snapshot() -> void:
	var data = JSON.parse_string(JSON.stringify(world.state.snapshot()))
	expect(Campaign.valid(data),"actual fourth-chapter JSON snapshot validates")
	world.detach_tactics(false); world.state = MemoryCampaign.new(); world.state.last_save = data
	expect(world.continue_game(4),"new Campaign resumes fourth chapter without disk writes")
	end_dialogue(); await settle()

func freeze_and_retry(label: String) -> void:
	var stage = world.stage; var flags = world.state.flags.duplicate()
	for mode in ["pause","map"]:
		world.pause(mode)
		var pending = world.tactics.waiting.duplicate(true); var cleared = world.state.cleared.duplicate()
		var clock = world.tactics.arrow_clock; var warnings = world.tactics.arrow_warnings.duplicate(true)
		world.tactics.advance(30); world.tactics.spawn_pending(30); world.tactics.check_groups(); world._physics_process(30)
		expect(world.tactics.waiting==pending and world.state.cleared==cleared and world.tactics.arrow_clock==clock and world.tactics.arrow_warnings==warnings,label+": "+mode+" freezes encounters and hazards")
		world.resume()
	world.hero.invincible=0; world.hero.take_damage(10000,91000+checks)
	expect(world.mode=="defeat",label+": actual damage reaches defeat overlay")
	var pending=world.tactics.waiting.duplicate(true); var clock=world.tactics.arrow_clock
	world.tactics.advance(30); world._physics_process(30)
	expect(world.tactics.waiting==pending and world.tactics.arrow_clock==clock,label+": defeat freezes queued danger")
	world.retry(); await settle()
	expect(world.mode=="playing" and world.stage==stage and world.state.flags==flags,label+": retry retains stage and earned task flags")
	expect(world.hero.hp==world.hero.max_hp and world.tactics.arrow_warnings.is_empty() and world.arrows.is_empty(),label+": retry resets health and discards transient arrows")

func select_street(front: bool) -> void:
	expect(not world.tactics.main_clear() and world.tactics.waiting.is_empty() and not world.group_alive(),"unselected route is neither cleared nor populated")
	expect(world.object_blocked(world.object_by_id("cc_to_store")),"unselected street cannot reach warehouse")
	world.tactics.request_group("cc_s_front"); world.tactics.request_group("cc_s_flank1"); world.tactics.request_group("cc_s_flank2")
	pump(20)
	expect(world.tactics.waiting.is_empty() and world.tactics.spawned.is_empty(),"unselected route rejects explicit requests for both enemy lines")
	expect(await use("cc_route_choice") and world.mode=="dialog","actual E opens both route choices")
	world.choose_route("continue")
	expect(not world.state.flags.cc_route_front and not world.state.flags.cc_route_flank,"cancelling observation leaves route undecided")
	await use("cc_route_choice"); world.choose_route("chencang:front" if front else "chencang:flank")
	expect(world.state.flags.cc_route_front==front and world.state.flags.cc_route_flank!=front,"dialogue chooses exactly one route")
	var saved=world.state.snapshot().duplicate(true)
	expect(not world.tactics.choose_route(not front) and world.state.snapshot()==saved,"repeated choice cannot change route or restart waves")
	var other=["cc_s_flank1","cc_s_flank2"] if front else ["cc_s_front"]
	for id in other: world.tactics.request_group(id)
	for row in world.tactics.waiting: expect(not other.has(row.id),"unchosen route never joins pending arrivals")
	await freeze_and_retry("street chosen")
	await resume_snapshot()
	expect(world.state.flags.cc_route_front==front and world.state.flags.cc_route_flank!=front,"route survives JSON restore")
	await clear_main()
	expect(not world.state.flags.cc_street_done and world.object_blocked(world.object_by_id("cc_to_store")),"killing route guards still requires the player's final order")
	await use("cc_front_banner" if front else "cc_flank_winch")
	expect(world.state.flags.cc_street_done,"real selected route object completes street")
	for id in other: expect(not world.tactics.spawned.has(id),"unchosen group was never spawned: "+id)

func route(front: bool, side_routes: bool, level: String = "normal") -> void:
	await fresh(level); await freeze_and_retry("outer")
	expect(world.tactics.cart==null and not world.tactics.support_status().visible,"new chapter does not activate escort actors")
	await clear_main(); expect(await use("cc_breach"),"E captures outer banner")
	await use("cc_to_beacon"); expect(world.stage=="cc_beacon","real outer exit reaches beacon")
	await freeze_and_retry("beacon"); await clear_main()
	if side_routes:
		await clear_group("cc_orders_guard"); await use("cc_orders")
		expect(world.state.flags.cc_orders and not world.state.flags.cc_reserve_called,"early orders are earned before reserve arrival")
	expect(await use("cc_beacon") and world.state.flags.cc_beacon_out,"E extinguishes beacon")
	await use("cc_to_street"); await select_street(front)
	await use("cc_to_store"); expect(world.stage=="cc_store","selected route joins same warehouse")
	await freeze_and_retry("store")
	if side_routes:
		await clear_group("cc_workers_guard"); await use("cc_workers")
		expect(world.state.flags.cc_workers,"real optional guard fight frees workers")
		expect(world.object_blocked(world.object_by_id("cc_worker_gate")),"workers cannot open a shortcut before warehouse main objective")
	await clear_main(); await use("cc_warehouse")
	expect(world.state.flags.cc_warehouse,"warehouse requires actual selected main encounters")
	expect(world.state.flags.cc_reserve_called!=side_routes,"only non-intercepted reserve actually arrives")
	expect(not world.object_blocked(world.object_by_id("cc_to_bastion")),"ordinary warehouse exit remains available with or without workers")
	await use("cc_worker_gate" if side_routes else "cc_to_bastion")
	expect(world.stage=="cc_bastion","both warehouse exits reach bastion")
	var spawn=Vector2(1360,890) if side_routes else Vector2(220,900)
	expect(world.hero.position.is_equal_approx(spawn) and not world.terrain.blocked(spawn,world.hero.radius),"chosen exit lands at its exact safe ground point")
	await freeze_and_retry("bastion")
	var kinds=[]
	for unit in world.tactics.units_for("cc_c2"): kinds.append(unit[0])
	expect(kinds.size()==3 and not kinds.has("ironshield" if front else "crossbow") and kinds.has("crossbow" if front else "ironshield"),"route removes precisely its promised bastion defender")
	await clear_main(); await use("cc_courtyard"); await use("cc_to_final")
	expect(world.stage=="cc_final","bastion real order opens final approach")
	await freeze_and_retry("final approach"); await clear_main()
	expect(await use("cc_warden") and world.mode=="dialog" and not world.state.flags.cc_committed,"boss E opens confirmation without prematurely locking visits")
	world.choose_route("continue")
	expect(world.active_boss.is_empty() and not world.state.flags.cc_committed and not world.object_blocked(world.object_by_id("cc_back_bastion")),"cancelled challenge preserves the return exit")
	await use("cc_warden"); world.choose_route("warden:commit")
	expect(world.state.flags.cc_committed and world.active_boss=="warden" and world.boss.boss_id=="warden","explicit confirmation starts actual Warden duel")
	expect(world.boss.max_hp==(1260 if level=="story" else 1500) and world.tactics.living_count()==1,"new duel uses authored health and no ordinary enemy pile-on")
	expect(world.object_blocked(world.object_by_id("cc_back_bastion")),"confirmed duel closes backtracking")
	await freeze_and_retry("warden duel")
	expect(world.active_boss=="warden" and world.boss.hp==world.boss.max_hp,"duel retry restarts full-health actual boss")
	world.boss.take_hit(10000,0,0,"player",0,true)
	expect(world.state.flags.cc_boss and not world.state.complete and world.mode=="dialog","actual boss defeat records victory but still awaits collection")
	end_dialogue()
	expect(await use("cc_finish") and world.mode=="ending" and world.state.complete,"real final E opens fourth-chapter war report")
	expect(world.state.build_report().chapter==4 and Campaign.valid(JSON.parse_string(JSON.stringify(world.state.snapshot()))),"full route produces valid fourth-chapter report and save")
	expect(not world.finish(),"repeated finish is harmless")
	var report=world.state.build_report().duplicate(true)
	world.title_screen(); expect(world.continue_game(4),"completed fourth chapter can reopen")
	expect(world.mode=="ending" and world.state.build_report()==report,"Continue preserves exact existing fourth report")

func prepare_store() -> void:
	await fresh()
	await clear_main(); await use("cc_breach"); await use("cc_to_beacon")
	await clear_main(); await use("cc_beacon"); await use("cc_to_street")
	await select_street(true); await use("cc_to_store")
	await clear_group("cc_w1"); await clear_group("cc_w2")

func reserve_contracts() -> void:
	await prepare_store()
	world.tactics.request_group("cc_w_reserve")
	expect(not world.state.flags.cc_reserve_called,"queueing warning never claims reserve arrival")
	# Return through the actual two exits while the queued reinforcements have
	# not spawned. Retrieve the orders with the real optional fight and E.
	await use("cc_back_street"); await use("cc_back_beacon")
	await clear_group("cc_orders_guard"); await use("cc_orders")
	expect(world.state.flags.cc_orders and not world.state.flags.cc_reserve_called,"real backtrack can intercept still-unarrived reserve")
	await use("cc_to_street"); await use("cc_to_store")
	expect(not world.tactics.main_groups().has("cc_w_reserve"),"timely orders remove only the unarrived reserve requirement")
	world.tactics.request_group("cc_w_reserve"); pump(10)
	expect(not world.group_alive("cc_w_reserve") and world.tactics.main_clear(),"timely return does not spawn or falsely require cancelled reserve")
	await prepare_store(); await spawn_group("cc_w_reserve")
	expect(world.state.flags.cc_reserve_called and live_group_size("cc_w_reserve")==2,"actual two-person arrival persists the called flag")
	await use("cc_back_street"); await use("cc_back_beacon")
	await clear_group("cc_orders_guard"); await use("cc_orders")
	expect(world.state.flags.cc_orders and world.state.flags.cc_reserve_called,"late real orders retain reserve arrival history")
	await use("cc_to_street"); await use("cc_to_store")
	expect(world.tactics.main_groups().has("cc_w_reserve") and not world.tactics.main_clear(),"late orders cannot erase uncleared arrived reserve")
	await spawn_group("cc_w_reserve"); expect(live_group_size("cc_w_reserve")==2,"return restores the finite arrived reserve encounter")
	await resume_snapshot(); await clear_group("cc_w_reserve")
	expect(world.tactics.main_clear(),"late-orders reserve remains completable after reload")

func start_arrow_test() -> void:
	await fresh(); world.state.flags.cc_breach=true; await enter("cc_beacon")
	await clear_group("cc_b1"); await spawn_group("cc_b2")
	world.arrows.clear(); world.hero.reset_combat(); world.hero.invincible=0; world.hero.position=Vector2(1180,550)
	world.tactics.arrow_clock=0; world.tactics.arrow_warnings.clear(); world.tactics.arrays_started=0; world.tactics.volleys_fired=0; world.tactics.ranged_hazard_hold=0
	world.tactics.advance_arrow_array(3.99)
	expect(world.tactics.arrow_warnings.is_empty(),"first beacon array grants at least four seconds observation")
	world.tactics.advance_arrow_array(4.02)
	expect(world.tactics.arrow_warnings.size()>0 and world.tactics.arrow_warnings.size()<=2 and world.arrows.is_empty(),"real beacon array warns at most two locked lanes before fire")
	for warning in world.tactics.arrow_warnings: expect(warning.left>=1.25,"every array line begins with full 1.25-second warning")

func arrow_contracts() -> void:
	await start_arrow_test()
	var director=world.tactics; var hp=world.hero.hp; var warning=director.arrow_warnings.duplicate(true)
	for mode in ["pause","map"]:
		world.pause(mode); director.advance(30); director.advance_arrow_array(30); world._physics_process(30)
		expect(director.arrow_warnings==warning and world.arrows.is_empty() and world.hero.hp==hp,mode+" freezes real beacon warnings and damage")
		world.resume()
	director.advance_arrow_array(1.24)
	expect(world.arrows.is_empty(),"beacon array cannot fire one hundredth before complete warning")
	world.hero.position=Vector2(1020,550); director.advance_arrow_array(.02)
	expect(not world.arrows.is_empty(),"warning expiry emits actual projectiles")
	for tick in range(110): world.advance_arrows(.02)
	expect(world.hero.hp==hp,"moving off locked lanes dodges actual array projectiles")
	await start_arrow_test(); hp=world.hero.hp; director=world.tactics; director.advance_arrow_array(1.26)
	for tick in range(110): world.advance_arrows(.02)
	expect(world.hero.hp<hp,"staying on warned lane causes actual damage")
	await start_arrow_test(); hp=world.hero.hp; director=world.tactics
	var wall=StaticBody2D.new(); wall.collision_layer=1; wall.position=Vector2(1290,450)
	var shape=CollisionShape2D.new(); var rectangle=RectangleShape2D.new(); rectangle.size=Vector2(20,400)
	shape.shape=rectangle; wall.add_child(shape); world.add_child(wall); await settle()
	director.advance_arrow_array(1.26)
	for tick in range(110): world.advance_arrows(.02)
	expect(world.hero.hp==hp,"real wall collision blocks already-aimed beacon arrows")
	wall.queue_free(); await settle()
	await start_arrow_test(); director=world.tactics
	for tick in range(8):
		director.advance_arrow_array(1.26); world.arrows.clear(); director.advance_arrow_array(8.01)
	expect(director.arrays_started==3 and director.volleys_fired<=6 and director.volleys_fired>0,"beacon permits only three finite arrays of at most two arrows")
	await start_arrow_test(); director=world.tactics; var fired=director.volleys_fired
	kill_group("cc_b2"); pump(.01); await use("cc_beacon")
	expect(world.state.flags.cc_beacon_out and director.arrow_warnings.is_empty(),"real E extinguishes and clears unfired array")
	director.advance_arrow_array(100)
	expect(director.volleys_fired==fired and world.arrows.is_empty(),"extinguished beacon never rearms")
	await start_arrow_test(); director=world.tactics; warning=director.arrow_warnings.duplicate(true)
	world.hero.invincible=0; world.hero.take_damage(10000,92001); director.advance(100)
	expect(director.arrow_warnings==warning and world.arrows.is_empty(),"death freezes an active array warning")
	world.retry(); await settle()
	expect(world.tactics.arrow_warnings.is_empty() and world.tactics.arrays_started==0 and world.arrows.is_empty(),"retry grants a clean finite array budget without stale shots")

func arrow_slot_contracts() -> void:
	await start_arrow_test(); var director=world.tactics
	director.arrow_warnings.clear(); director.ranged_hazard_hold=0; director.arrow_clock=7.99
	var bow=null
	for enemy in world.enemies:
		if enemy.body_alive() and enemy.kind=="crossbow" and enemy.group_id=="cc_b2": bow=enemy; break
	expect(bow!=null,"actual beacon crossbow participates in shared ranged slot")
	if bow==null: return
	bow.stun=0; bow.cooldown=0; bow.start_action(world.hero); director.advance_arrow_array(.02)
	expect(director.arrow_warnings.is_empty(),"array waits while crossbow aims")
	bow.advance_action(.90,world.hero); bow.advance_action(.26,world.hero)
	expect(world.arrows.size()==2,"array arbitration preserves both real crossbow shots")
	director.advance_arrow_array(.40)
	expect(director.arrow_warnings.is_empty(),"array waits through crossbow reload")
	bow.advance_action(1.50,world.hero); world.arrows.clear(); director.advance_arrow_array(.01)
	expect(not director.arrow_warnings.is_empty() and not bow.ranged_slot_available(),"released ranged slot opens full array warning and blocks another crossbow start")
	bow.cooldown=0; bow.advance(.01); expect(bow.action.is_empty(),"ordinary AI cannot aim under array telegraph")
	director.advance_arrow_array(1.26)
	expect(is_equal_approx(director.ranged_hazard_hold,.75) and not bow.ranged_slot_available(),"actual release reserves bounded projectile travel time")
	director.advance_arrow_array(.76); expect(bow.ranged_slot_available(),"crossbow slot returns after travel reservation")

func run() -> void:
	save_before=fingerprints()
	world=MemoryWorld.new(); world.test_mode=true; world.state=MemoryCampaign.new()
	root.add_child(world); world.set_physics_process(false); world.set_process(false); await settle(); world.ui.hide_overlay()
	await route(true,true); await route(false,false); await route(true,false,"story")
	await reserve_contracts(); await arrow_contracts(); await arrow_slot_contracts()
	expect(fingerprints()==save_before,"fourth-chapter acceptance never rewrites player save files")
	print("CHENCANG_FLOW_VERIFY ",checks," checks; ",failures.size()," failures; maximum_live=",maximum_living)
	world.queue_free(); await process_frame; await process_frame; quit(0 if failures.is_empty() else 1)
