extends SceneTree
## Accelerated real-world acceptance, not a human difficulty or duration test.
## Real Enemy.take_hit, interactions, chapter saves and projectile collision are
## used; all persistence is memory-only in an externally isolated QA profile.
const Campaign = preload("res://scripts/campaign.gd")
class MemoryCampaign extends Campaign:
	func read_save() -> Dictionary: return last_save.duplicate(true)
	func save() -> bool:
		last_save = snapshot(); durable = true; return true
class MemoryWorld extends "res://scripts/world.gd":
	func save_progress() -> void:
		if is_instance_valid(tactics): tactics.capture_roster()
		state.save()
var world
var checks = 0
var failures: Array = []
var maximum_living = 0
var save_before: Dictionary = {}

func _initialize() -> void: call_deferred("run")
func expect(value: bool, message: String) -> void:
	checks += 1
	if not value: failures.append(message); push_error("JIGU_FLOW: "+message)
func settle() -> void:
	await process_frame; await physics_frame; await physics_frame
func fingerprints() -> Dictionary:
	var result: Dictionary = {}
	for path in [Campaign.SAVE_PATH,Campaign.LEGACY_PATH]:
		result[path] = FileAccess.get_file_as_bytes(path).hex_encode().sha256_text() if FileAccess.file_exists(path) else "absent"
	return result
func end_dialogue() -> void:
	if world.mode == "dialog": world.choose_route("continue")
func fresh(level: String = "normal") -> void:
	world.detach_tactics(false); world.state = MemoryCampaign.new()
	world.start_game(level,3); end_dialogue(); await settle()
	expect(world.state.chapter == 3 and world.stage == "jg_fog" and is_instance_valid(world.tactics),"fresh Jigu opens actual fog region and director")
func enter(stage: String, at: Vector2 = Vector2.INF) -> void:
	world.mode = "playing"; world.enter_stage(stage,at); world.ui.hide_overlay(); await settle()
func pump(dt: float = .1) -> void:
	world.tactics.advance(dt)
	maximum_living = maxi(maximum_living,world.tactics.living_count())
	expect(world.tactics.living_count() <= 8,"finite active-enemy cap in "+world.stage)
func kill_group(id: String = "") -> void:
	for enemy in world.enemies.duplicate():
		if enemy.body_alive() and (id.is_empty() or enemy.group_id == id):
			enemy.take_hit(10000,0,0,"player",0,true)
func trigger_safe(units: Array) -> void:
	var origin = Vector2(units[0][1],units[0][2])
	for radius in [230,280,330,390]:
		for direction in range(16):
			var candidate = origin+Vector2.from_angle(TAU*direction/16.0)*radius
			if world.terrain.blocked(candidate,world.hero.radius): continue
			var safe = true
			for unit in units:
				if candidate.distance_to(Vector2(unit[1],unit[2])) < 180: safe = false
			if safe: world.hero.position = candidate; return
	expect(false,"encounter has safe warning distance in "+world.stage)
func spawn_group(id: String) -> void:
	trigger_safe(world.tactics.units_for(id))
	for tick in range(80):
		pump(.1)
		if world.tactics.spawned.has(id): break
	expect(world.tactics.spawned.has(id) and world.group_alive(id),"real finite wave spawns: "+world.stage+":"+id)
func clear_group(id: String) -> void:
	if world.tactics.group_cleared(id): return
	await spawn_group(id); kill_group(id); pump(.01)
	expect(world.tactics.group_cleared(id),"actual defeats clear "+id)
func clear_main() -> void:
	for id in world.tactics.main_groups(): await clear_group(str(id))
	expect(world.tactics.main_clear(),"all main encounters cleared in "+world.stage)
func use(id: String) -> bool:
	var object = world.object_by_id(id)
	expect(not object.is_empty(),"authored interaction exists: "+id)
	if object.is_empty(): return false
	world.hero.position = Vector2(object.x,object.y)
	var result = world.interact()
	if not world.pending_stage.is_empty(): world._physics_process(0)
	await settle()
	return result
func resume_snapshot() -> void:
	var data = JSON.parse_string(JSON.stringify(world.state.snapshot()))
	expect(Campaign.valid(data),"actual JSON snapshot validates")
	world.detach_tactics(false); world.state = MemoryCampaign.new(); world.state.last_save = data
	expect(world.continue_game(3),"fresh Campaign restores third chapter from serialized state")
	end_dialogue(); await settle()
func live_group_size(id: String) -> int:
	var count = 0
	for enemy in world.enemies:
		if enemy.body_alive() and enemy.group_id == id: count += 1
	return count

func finite_wave_contracts() -> void:
	await fresh()
	var director = world.tactics
	expect(director.cart == null and not director.support_status().visible and not director.request_support(),"chapter-three compatibility does not activate convoy or Huang Zhong")
	expect(not director.main_clear() and not world.group_alive(),"unspawned first wave never counts as cleared")
	director.check_groups()
	expect(world.state.cleared.is_empty(),"no phantom clear is written before spawn")
	for repeated in range(5): director.request_group("jg_f1")
	expect(director.waiting.size() == 1,"same pending group cannot be requested repeatedly")
	expect(not world.group_alive() and director.waiting[0].left >= 1.2,"region entry grants its full warning without consuming it behind the introduction")
	pump(.6)
	expect(not world.group_alive(),"partial warning cannot spawn the encounter early")
	var left = director.waiting[0].left
	world.pause("pause"); director.advance(30); director.spawn_pending(30); director.check_groups()
	expect(director.waiting[0].left == left and not world.group_alive(),"pause freezes warning, spawn and clears at their own entry points")
	world.resume()
	world.hero.position = Vector2(620,760); pump(2)
	expect(not world.group_alive() and director.waiting[0].near_hint,"standing in an arrival lane delays spawn with visible feedback")
	trigger_safe(director.units_for("jg_f1")); pump(.01)
	expect(live_group_size("jg_f1") == 2,"moving aside spawns the exact first-wave budget once")
	for repeated in range(5): director.request_group("jg_f1")
	expect(director.waiting.is_empty(),"spawned wave cannot be cloned")
	kill_group("jg_f1"); pump(.01)
	expect(world.state.cleared.count("jg_fog:jg_f1") == 1,"repeated clear evaluation is idempotent")
	await resume_snapshot()
	expect(world.tactics.group_cleared("jg_f1") and not world.group_alive("jg_f1"),"reload preserves completed first combat")
	await clear_group("jg_f2")
	expect(world.tactics.main_clear(),"queued second wave remains completable after reload")
	await fresh(); director = world.tactics
	var extras: Array = []
	for i in range(7): extras.append(world.spawn_enemy("sword",Vector2(900+i*32,850),"cap-fixture"))
	pump(2)
	expect(director.living_count() == 7 and not world.group_alive("jg_f1") and not director.group_cleared("jg_f1"),"capacity waits without partially spawning or falsely clearing a pending wave")
	extras[0].take_hit(10000,0,0,"player",0,true); pump(.01)
	expect(director.living_count() == 8 and live_group_size("jg_f1") == 2,"full pending wave fits exactly when the eight-enemy budget becomes available")

func camp_threat_contracts() -> void:
	await fresh()
	var camp = world.object_by_id("jg_fog_camp")
	var threat = world.spawn_enemy("scout",Vector2(camp.x+170,camp.y),"camp-threat-fixture")
	threat.alerted = true
	world.hero.hp = 85; world.hero.potions = 1; world.hero.qi = 22
	var checkpoint = world.state.checkpoint.duplicate(true)
	expect(world.object_blocked(camp),"alerted enemy near third-chapter camp prevents resting")
	expect(not await use("jg_fog_camp") and world.mode == "playing","threatened third-chapter camp rejects actual E interaction")
	expect(world.hero.hp == 85 and world.hero.potions == 1 and world.hero.qi == 22 and world.state.checkpoint == checkpoint,"blocked camp cannot silently refill resources or replace checkpoint")
	threat.take_hit(10000,0,0,"player",0,true)
	expect(await use("jg_fog_camp") and world.mode == "camp","defeating the real nearby threat makes camp usable again")
	expect(world.hero.hp == world.hero.max_hp and world.hero.potions == 3 and world.hero.qi == 100,"safe camp applies its normal recovery")
	world.resume()

func route(cut: bool, side_routes: bool, level: String = "normal") -> void:
	await fresh(level)
	expect(world.hero.battle_art() == "" and world.state.flags.sword,"direct third-chapter start keeps base moves and Qinggang")
	await clear_main(); await use("jg_to_signal")
	expect(world.stage == "jg_signal","fog exit loads signal cliff")
	expect(world.object_blocked(world.object_by_id("jg_to_pass")),"signal exit requires capturing banner")
	await clear_main()
	if side_routes: await clear_group("jg_dispatch_guard"); await use("jg_dispatch")
	await use("jg_banner")
	expect(world.state.flags.jg_banner and world.tactics.arrow_warnings.is_empty(),"banner capture records order and cancels unfired arrows")
	var history_count = world.state.history.size()
	world.tactics.interact_object(world.object_by_id("jg_banner"))
	expect(world.state.history.size() == history_count,"repeat banner interaction cannot duplicate reward/history")
	await use("jg_to_pass")
	expect(world.stage == "jg_pass","captured banner unlocks actual plank passage")
	world.tactics.request_group("jg_p2")
	for row in world.tactics.waiting: expect(row.id != "jg_p2","rear wave cannot be queued before first order")
	await clear_group("jg_p1")
	expect(not world.state.flags.jg_front and world.object_blocked(world.object_by_id("jg_to_rearguard")),"combat alone does not issue either evacuation order")
	await use("jg_front")
	expect(world.state.flags.jg_front and not world.state.flags.jg_rear and world.state.checkpoint.stage == "jg_pass","first actual E saves first evacuation order only")
	await resume_snapshot()
	expect(world.state.flags.jg_front and not world.state.flags.jg_rear and not world.group_alive("jg_p1"),"reloaded first order neither respawns first wave nor grants second order")
	await clear_group("jg_p2"); await use("jg_rear")
	expect(world.state.flags.jg_rear and not world.object_blocked(world.object_by_id("jg_to_rearguard")),"second E unlocks stonegate after its own battle")
	await use("jg_to_rearguard")
	await clear_group("jg_r1"); await spawn_group("jg_r2")
	expect(live_group_size("jg_r2") == (2 if side_routes else 3),"recovered dispatch really removes exactly one stonegate crossbow")
	kill_group("jg_r2"); pump(.01)
	if side_routes: await clear_group("jg_supply_guard"); await use("jg_supplies")
	await use("jg_rearguard")
	expect(world.state.flags.jg_rearguard,"stonegate requires actual rally interaction after two waves")
	await use("jg_to_bridge"); await clear_main()
	expect(not world.object_blocked(world.object_by_id("jg_back_rearguard")),"bridge decision still permits side-route backtracking beforehand")
	await use("jg_bridge_choice")
	expect(world.mode == "dialog" and not world.state.flags.jg_bridge_cut and not world.state.flags.jg_bridge_held,"bridge offers a decision without choosing automatically")
	world.choose_route("jigu:cut" if cut else "jigu:hold"); await settle()
	expect(world.state.flags.jg_bridge_cut == cut and world.state.flags.jg_bridge_held == not cut,"real dialogue selects exactly one bridge outcome")
	expect(world.object_blocked(world.object_by_id("jg_back_rearguard")),"confirmed bridge choice prevents backward reward farming")
	var saved = world.state.snapshot().duplicate(true)
	expect(not world.tactics.choose_bridge(not cut) and world.state.snapshot() == saved,"duplicate bridge choice cannot switch branch or duplicate waves")
	if not cut:
		expect(world.object_blocked(world.object_by_id("jg_to_final")),"hold route requires last guard before final exit")
		# Die before the extra wave appears: the saved choice must restore one
		# finite unfinished wave, not replay the bridge choice or old main group.
		world.hero.invincible = 0; world.hero.take_damage(10000,90201)
		expect(world.mode == "defeat","bridge hold failure is recoverable")
		world.retry(); await settle()
		expect(world.state.flags.jg_bridge_held and not world.group_alive("jg_b1"),"bridge retry retains held choice and cleared bridge guards")
		var count = 0
		for row in world.tactics.waiting:
			if row.id == "jg_bridge_extra": count += 1
		expect(count == 1,"retry queues one and only one outstanding extra wave")
		await spawn_group("jg_bridge_extra")
		expect(live_group_size("jg_bridge_extra") == 2,"holding bridge costs precisely two extra pursuers")
		kill_group("jg_bridge_extra"); pump(.01)
		expect(world.object_blocked(world.object_by_id("jg_to_final")),"killing extra pursuers still requires E to receive the last guard")
		await use("jg_last_guard")
		expect(world.state.flags.jg_last_guard,"actual east-bank E receives last guard")
	else:
		expect(not world.tactics.spawned.has("jg_bridge_extra") and world.tactics.waiting.is_empty(),"cut route never silently creates held-route pursuers")
	await use("jg_to_final")
	expect(world.stage == "jg_final","both bridge outcomes reach actual final region")
	await use("jg_final_camp")
	expect(world.mode == "camp" and world.hero.potions == (4 if side_routes else 3),"final camp applies exactly the authored optional one-medicine benefit")
	expect(world.state.flags.jg_supply_claimed == side_routes,"only recovered supplies can be claimed")
	var reward_history = world.state.history.duplicate()
	world.resume()
	expect(await use("jg_final_camp") and world.mode == "camp","second complete camp interaction remains usable")
	expect(world.hero.potions == (4 if side_routes else 3),"resting again preserves an unused fourth medicine without inventing one")
	expect(world.state.history == reward_history and world.state.flags.jg_supply_claimed == side_routes,"second camp visit does not duplicate the supply record or claim")
	world.hero.potions = 2
	expect(not world.tactics.claim_supplies() and world.hero.potions == 2,"spent/absent final supply cannot be claimed again")
	world.resume()
	expect(await use("jg_final_camp") and world.mode == "camp","spent medicine can still use normal camp recovery")
	expect(world.hero.potions == 3 and world.state.history == reward_history,"after consuming the extra medicine camp restores only three and never reissues the bonus")
	world.resume(); await spawn_group("jg_v1")
	expect(live_group_size("jg_v1") == (2 if cut else 3),"cut rope really removes one final crossbow and holding keeps it")
	kill_group("jg_v1"); pump(.01); await use("jg_vanguard")
	if world.mode == "dialog": world.choose_route("bossStart:vanguard")
	expect(world.active_boss == "vanguard" and world.boss.boss_id == "vanguard","final interaction starts the actual new boss")
	expect(world.tactics.living_count() == 1,"final duel starts with no ordinary enemies attacking alongside boss")
	world.hero.invincible = 0; world.hero.take_damage(10000,90202)
	world.retry(); await settle()
	expect(world.active_boss == "vanguard" and world.boss.hp == world.boss.max_hp,"boss retry restarts a live full-health vanguard")
	expect(world.state.flags.jg_bridge_cut == cut and world.state.flags.jg_dispatch == side_routes and world.state.flags.jg_supply_claimed == side_routes,"boss retry preserves bridge, dispatch and spent supplies")
	world.boss.take_hit(10000,0,0,"player",0,true); end_dialogue()
	expect(world.state.flags.jg_boss and world.active_boss.is_empty(),"actual vanguard defeat writes chapter-specific outcome")
	await use("jg_finish")
	expect(world.mode == "ending" and world.state.complete and world.state.build_report().chapter == 3,"full six-region route reaches Jigu war report")
	expect(Campaign.valid(JSON.parse_string(JSON.stringify(world.state.snapshot()))),"complete actual third chapter yields valid serialized save")
	expect(not world.finish(),"repeated finish cannot award another ending")
	var report = world.state.build_report().duplicate(true)
	world.title_screen(); expect(world.continue_game(3),"completed Jigu record can reopen")
	expect(world.mode == "ending" and world.state.build_report() == report,"Continue reopens exact existing third-chapter report")

func start_arrow_test() -> void:
	await fresh(); await enter("jg_signal")
	await clear_group("jg_s1"); await spawn_group("jg_s2")
	world.arrows.clear(); world.hero.reset_combat(); world.hero.invincible = 0; world.hero.position = Vector2(1180,550)
	world.tactics.arrow_clock = 0; world.tactics.arrow_warnings.clear()
	world.tactics.advance(7.01)
	expect(world.tactics.arrow_warnings.size() > 0 and world.arrows.is_empty(),"real signal battle locks a visible line before any projectile")

func arrow_contracts() -> void:
	await start_arrow_test()
	var director = world.tactics; var warned = director.arrow_warnings.duplicate(true); var hp = world.hero.hp
	world.pause("pause"); director.advance(30); world._physics_process(30)
	expect(director.arrow_warnings == warned and world.hero.hp == hp and world.arrows.is_empty(),"pause cannot advance queued array or inflict hidden damage")
	world.resume(); world.hero.position = Vector2(1020,550); director.advance(1.21)
	expect(not world.arrows.is_empty() and director.volleys_fired > 0,"elapsed visible warning creates actual production projectiles")
	for tick in range(110): world.advance_arrows(.02)
	expect(world.hero.hp == hp,"side movement after direction lock dodges the real arrows")
	await start_arrow_test(); director = world.tactics; hp = world.hero.hp
	director.advance(1.21)
	for tick in range(110): world.advance_arrows(.02)
	expect(world.hero.hp < hp,"remaining in the locked line receives actual arrow damage")
	await start_arrow_test(); director = world.tactics; hp = world.hero.hp
	var wall = StaticBody2D.new(); wall.collision_layer = 1; wall.position = Vector2(1290,450)
	var shape = CollisionShape2D.new(); var rectangle = RectangleShape2D.new(); rectangle.size = Vector2(20,400)
	shape.shape = rectangle; wall.add_child(shape); world.add_child(wall); await settle()
	director.advance(1.21)
	for tick in range(110): world.advance_arrows(.02)
	expect(world.hero.hp == hp,"a real terrain body inserted after locking blocks the arrows")
	wall.queue_free(); await settle()
	await start_arrow_test(); director = world.tactics
	var before = director.volleys_fired
	kill_group("jg_s2"); await use("jg_banner")
	expect(director.arrow_warnings.is_empty() and world.state.flags.jg_banner,"capturing the flag explicitly cancels unfired array entries")
	director.advance(60)
	expect(director.volleys_fired == before and world.arrows.is_empty(),"flag capture prevents all new array shots")
	await start_arrow_test(); director = world.tactics
	warned = director.arrow_warnings.duplicate(true)
	world.hero.invincible = 0; world.hero.take_damage(10000,90203)
	director.advance(30); world._physics_process(30)
	expect(world.mode == "defeat" and director.arrow_warnings == warned and world.arrows.is_empty(),"death does not fire pending arrows behind defeat overlay")
	world.retry(); await settle()
	expect(world.tactics.arrow_warnings.is_empty() and world.arrows.is_empty() and world.tactics.arrow_clock == 0,"retry discards transient arrow timers and grants fresh warning time")

func save_contracts() -> void:
	var state = Campaign.new(); state.switch_chapter(3,"normal",true)
	var clean = state.snapshot()
	expect(Campaign.valid(clean),"fresh third chapter is a valid v2 record")
	for pair in [["jg_rear","jg_front"],["jg_rearguard","jg_rear"],["jg_bridge_cut","jg_rearguard"],["jg_last_guard","jg_bridge_held"],["jg_supply_claimed","jg_supplies"],["jg_boss","jg_bridge_cut"]]:
		var invalid = clean.duplicate(true); invalid.flags[pair[0]] = true
		expect(not Campaign.valid(invalid),"save rejects unearned flag "+pair[0])
	var invalid = clean.duplicate(true)
	for key in ["jg_front","jg_rear","jg_rearguard","jg_bridge_cut","jg_bridge_held"]: invalid.flags[key] = true
	expect(not Campaign.valid(invalid),"save rejects mutually exclusive bridge outcomes")
	invalid = clean.duplicate(true); invalid.checkpoint.stage = "hs_final"
	expect(not Campaign.valid(invalid),"third chapter cannot restore a Hanshui checkpoint")

func run() -> void:
	save_before = fingerprints(); save_contracts()
	world = MemoryWorld.new(); world.test_mode = true; world.state = MemoryCampaign.new()
	root.add_child(world); world.set_physics_process(false); world.set_process(false)
	await settle(); world.ui.hide_overlay()
	await finite_wave_contracts(); await camp_threat_contracts(); await arrow_contracts()
	await route(true,false); await route(false,true); await route(true,true,"story")
	expect(fingerprints() == save_before,"Jigu acceptance never rewrites player v1/v2 files")
	print("JIGU_FLOW_VERIFY ",checks," checks; ",failures.size()," failures; maximum live enemies ",maximum_living)
	world.queue_free(); await process_frame; await process_frame
	quit(0 if failures.is_empty() else 1)
