extends SceneTree
## Accelerated production-world acceptance checks. Encounters are defeated
## through Enemy.take_hit; this verifies progression/recovery, not human
## difficulty, first-play duration, art quality or frame-rate targets.
const Game = preload("res://scripts/world.gd")
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
var save_fingerprints: Dictionary = {}
var maximum_living = 0

func _initialize() -> void: call_deferred("run")
func expect(condition: bool,message: String) -> void:
	checks += 1
	if not condition: failures.append(message); push_error("FAIL: "+message)
func settle() -> void:
	await process_frame; await physics_frame; await physics_frame
func fingerprints() -> Dictionary:
	var output: Dictionary = {}
	for path in [Campaign.SAVE_PATH,Campaign.LEGACY_PATH]:
		output[path] = FileAccess.get_file_as_bytes(path).hex_encode().sha256_text() if FileAccess.file_exists(path) else "absent"
	return output
func pump(dt: float = .02) -> void:
	if world.mode != "playing": return
	world.tactics.advance(dt)
	maximum_living = maxi(maximum_living,world.tactics.living_count())
	expect(world.tactics.living_count() <= 8,"finite-wave live enemy cap in "+world.stage)
func kill_live(group: String = "") -> void:
	for enemy in world.enemies.duplicate():
		if enemy.body_alive() and (group.is_empty() or enemy.group_id == group):
			enemy.take_hit(10000,(enemy.position-world.hero.position).angle(),0,"player",0,true)
func end_dialogue() -> void:
	if world.mode == "dialog": world.choose_route("continue")
func trigger_from_safe_distance(units: Array) -> void:
	var center = Vector2(units[0][1],units[0][2])
	for offset in [Vector2(0,250),Vector2(-250,0),Vector2(250,0),Vector2(0,-250),Vector2(-180,180),Vector2(180,-180)]:
		var candidate = center+offset
		if world.terrain.blocked(candidate,20): continue
		var safe = true
		for unit in units:
			if candidate.distance_to(Vector2(unit[1],unit[2])) < 180: safe = false
		if safe: world.hero.position = candidate; return
	expect(false,"encounter has a safe nearby trigger position")
func enter(stage: String,at: Vector2 = Vector2.INF) -> void:
	world.mode = "playing"; world.enter_stage(stage,at); world.ui.hide_overlay(); await settle()
func fresh(level: String = "normal") -> void:
	world.start_game(level,2); end_dialogue(); world.ui.hide_overlay(); await settle()
	expect(world.state.chapter == 2 and world.stage == "hs_forest","fresh chapter-two entrance")
func use(id: String) -> bool:
	var object = world.object_by_id(id)
	expect(not object.is_empty(),"interaction exists: "+id)
	if object.is_empty(): return false
	world.mode = "playing"; world.hero.position = Vector2(object.x,object.y)
	var accepted = world.interact()
	if not world.pending_stage.is_empty(): world._physics_process(0)
	await settle()
	return accepted
func clear_main() -> void:
	var director = world.tactics
	for group in director.main_groups():
		if world.state.cleared.has(world.stage+":"+group): continue
		var units = director.units_for(group)
		if units.is_empty(): expect(false,"main encounter has units: "+group); continue
		trigger_from_safe_distance(units)
		for step in range(5):
			pump(1.3 if step > 0 else .01)
			if director.spawned.has(group): break
		expect(director.spawned.has(group),"proximity actually spawns "+world.stage+":"+group)
		kill_live(group); pump(.01)
		expect(world.state.cleared.has(world.stage+":"+group),"actual enemy defeat clears "+group)
	expect(director.main_clear(),"all main encounters completed in "+world.stage)
func clear_optional(group: String) -> void:
	var units = world.tactics.units_for(group)
	trigger_from_safe_distance(units)
	for step in range(6):
		pump(1.3)
		if world.tactics.spawned.has(group): break
	expect(world.tactics.spawned.has(group),"optional group actually spawns: "+group)
	kill_live(group); pump(.01)
func gate_ready(hidden: bool) -> void:
	await fresh(); world.state.flags.huangzhong = true; world.state.flags.cart = true
	await enter("hs_camp",Vector2(640,360))
	if hidden:
		world.set_command("hold")
		for step in range(480):
			for ally in world.allies: ally.advance(1.0/60)
			if step % 30 == 29: await physics_frame
		var alive = 0; var tucked = 0
		for ally in world.allies:
			if ally.body_alive():
				alive += 1
				if world.tactics.hide_area().has_point(ally.position): tucked += 1
		expect(alive > 0 and alive == tucked,"three allies navigate into the real hidden guard area")
	else: world.set_command("follow")
	await use("hs_gate")
	expect(world.tactics.gate_state == "PROBE_1","opening camp gate begins first finite probe")
	expect(bool(world.state.tactics.get("deception_ok",false)) == hidden,"deception follows actual soldier preparation")
func beat_probes() -> void:
	for group in ["gate_probe1","gate_probe2"]:
		for step in range(5):
			pump(1.3)
			if world.tactics.spawned.has(group): break
		expect(world.group_alive(group),"camp probe is an actual living encounter: "+group)
		kill_live(group); pump(.01)
	expect(world.tactics.gate_state == "WITHDRAW","two defeated probes enter withdrawal")
	world.hero.position = Vector2(820,500)
	for step in range(100):
		pump(.05)
		for enemy in world.enemies:
			if enemy.body_alive(): enemy.advance(.05)
		if world.tactics.gate_state in ["BEST_WINDOW","LATE_WINDOW"]: break
	expect(world.tactics.gate_state == "BEST_WINDOW","living retreat roster reaches best-window line through navigation")
func roster_hp() -> Dictionary:
	var result: Dictionary = {}
	for enemy in world.enemies:
		if enemy.has_meta("roster_id"): result[str(enemy.get_meta("roster_id"))] = enemy.hp
	return result
func saved_roster_hp() -> Dictionary:
	var result: Dictionary = {}
	for enemy in world.state.tactics.get("roster",[]): result[str(enemy.id)] = enemy.hp
	return result
func escort_until(index_goal: int = 999) -> void:
	var ticks = 0
	while not world.state.flags.cart and int(world.state.tactics.get("escort_index",0)) < index_goal and ticks < 4000:
		var cart = world.tactics.cart
		world.hero.position = cart.position+Vector2(-55,60)
		kill_live()
		pump(.05); ticks += 1
		if world.mode != "playing": break
	expect(ticks < 4000 and world.mode == "playing","cart follows cleared collision route without waiting forever")

func campaign_contracts() -> void:
	var state = Campaign.new()
	var legacy = state.run_snapshot(); legacy.erase("chapter"); legacy.erase("tactics")
	legacy["version"] = 1; legacy["engine"] = "godot"
	legacy.checkpoint = {"stage":"village","x":880.0,"y":540.0,"encounter":""}
	legacy.flags.civilians = true; legacy.flags.healer = true; legacy.history = ["旧档已救医者"]
	expect(Campaign.valid(legacy) and state.restore(legacy),"real v1 snapshot restores into the new campaign")
	expect(state.chapter == 1 and state.flags.healer and state.checkpoint.stage == "village","v1 migration retains first-chapter progress")
	var original = state.run_snapshot()
	state.switch_chapter(2,"story",true); state.flags.wounded = true
	state.checkpoint = {"stage":"hs_return","x":720.0,"y":580.0,"encounter":""}
	state.tactics = {"escort_index":3,"cart_checkpoint":true}
	var hanshui = state.run_snapshot()
	state.switch_chapter(1)
	expect(state.run_snapshot() == original,"switching to chapter one restores its own exact progress")
	state.switch_chapter(2)
	expect(state.run_snapshot() == hanshui,"switching back restores separate tactics, difficulty and flags")
	var snapshot = state.snapshot(); var reloaded = Campaign.new()
	expect(snapshot.version == 2 and snapshot.chapters.size() == 2 and reloaded.restore(snapshot),"v2 serializes and validates both chapter records")
	var roundtrip = JSON.parse_string(JSON.stringify(snapshot))
	expect(Campaign.valid(roundtrip),"v2 validates after actual JSON number and dictionary roundtrip")
	if not Campaign.valid(roundtrip):
		print("SAVE_ROUNDTRIP_DIAGNOSTIC version=",roundtrip.version," version_in=",roundtrip.version in [1,2]," run_valid=",Campaign.valid_run(roundtrip,int(roundtrip.chapter))," chapters=",roundtrip.chapters.keys())
	reloaded.switch_chapter(1)
	expect(reloaded.run_snapshot() == original,"serialized two-chapter save preserves the migrated first chapter")
	var corrupt = snapshot.duplicate(true); corrupt.tactics.roster = [{"id":"same","kind":"scout","hp":70},{"id":"same","kind":"scout","hp":70}]
	expect(not Campaign.valid(corrupt),"duplicate pursuit identity is rejected on load")
	corrupt = snapshot.duplicate(true); corrupt.checkpoint.stage = "bridge"
	expect(not Campaign.valid(corrupt),"chapter-two save cannot load a chapter-one checkpoint")
	corrupt = snapshot.duplicate(true); corrupt.flags.huilan = true
	expect(not Campaign.valid(corrupt),"unearned chapter reward cannot be restored")
	corrupt = snapshot.duplicate(true); corrupt.chapters["1"].chapter = 2
	expect(not Campaign.valid(corrupt),"nested record cannot claim a chapter different from its record key")

func main_route(level: String = "normal") -> void:
	await fresh(level)
	expect(world.definitions.size() == 6,"chapter two loads exactly six regions")
	expect(not world.tactics.main_clear(),"unspawned main encounters are not counted as cleared")
	var exit = world.object_by_id("hs_to_grain")
	expect(world.object_blocked(exit),"first exit cannot bypass unspawned main encounters")
	clear_main(); await use("hs_to_grain")
	expect(world.stage == "hs_grain","forest exit really loads northern grain road")
	clear_main(); await use("hs_huangzhong"); end_dialogue()
	expect(world.state.flags.huangzhong,"actual Huang Zhong meeting is recorded")
	var history_count = world.state.history.size()
	await use("hs_huangzhong"); end_dialogue()
	expect(world.state.flags.huangzhong and world.state.history.size() == history_count,"Huang Zhong meeting cannot duplicate a reward")
	if level != "story":
		clear_optional("hs_beacon_guard"); await use("hs_beacon"); end_dialogue()
		expect(world.state.flags.beacon,"beacon side route destroys fire-arrow supply")
	await use("hs_to_return")
	expect(world.stage == "hs_return" and is_instance_valid(world.tactics.cart),"escort begins with actual native grain cart")
	if level != "story":
		clear_optional("hs_wounded"); await use("hs_zhangzhu"); end_dialogue()
		expect(world.state.flags.wounded,"Zhang Zhu and wounded side encounter completes through interaction")
	var cart = world.tactics.cart; cart.take_damage(10,991); var health = cart.hp
	expect(not cart.take_damage(10,991) and cart.hp == health,"one real enemy attack cannot damage cart twice")
	var wall = StaticBody2D.new(); wall.collision_layer = 1; wall.position = cart.position+Vector2(50,0)
	var shape = CollisionShape2D.new(); var rectangle = RectangleShape2D.new(); rectangle.size = Vector2(12,260)
	shape.shape = rectangle; wall.add_child(shape); world.add_child(wall); await settle()
	var before = cart.position; cart.travel(before+Vector2(300,0),3)
	expect(cart.position.x <= before.x+16.1,"cart cannot move through native camp/rock collision")
	wall.queue_free(); await settle(); cart.position = before
	world.tactics.stuck = 4; world.tactics.interact_object(world.object_by_id("hs_cart"))
	expect(cart.hp == health,"manual stuck recovery preserves cart HP")
	escort_until(3)
	expect(world.state.tactics.get("cart_checkpoint",false) and world.state.checkpoint.stage == "hs_return","first completed roadblock writes cart checkpoint")
	var cleared = world.state.cleared.duplicate(); var index = int(world.state.tactics.escort_index)
	cart.take_damage(9999,992)
	expect(world.mode == "defeat","actual cart destruction creates recoverable defeat")
	world.retry(); await settle()
	expect(world.stage == "hs_return" and world.tactics.cart.hp == 160 and int(world.state.tactics.escort_index) == index,"cart retry restores last route point with full durability")
	for key in cleared: expect(world.state.cleared.has(key),"cart retry retains completed encounter "+key)
	expect(world.state.flags.huangzhong and (level == "story" or world.state.flags.wounded and world.state.flags.beacon),"cart failure preserves completed rescue and side routes")
	escort_until()
	expect(world.state.flags.cart,"complete convoy path records safe camp arrival")
	await use("hs_to_camp")
	expect(world.stage == "hs_camp","escort gate actually transitions into camp")
	world.hero.position = Vector2(640,360); world.set_command("hold")
	for step in range(720):
		for ally in world.allies: ally.advance(1.0/60)
		if step % 30 == 29: await physics_frame
	for ally in world.allies:
		expect(world.tactics.hide_area().has_point(ally.position),"camp arrival soldiers can navigate from southwest entrance into hiding")
		if not world.tactics.hide_area().has_point(ally.position): print("HIDING_NAV_DIAGNOSTIC pos=",ally.position," home=",ally.home," path=",ally.path)
	await use("hs_gate"); await beat_probes()
	var before_volley = roster_hp(); var window = world.tactics.best_left
	world.pause("pause")
	for tick in range(150): world._physics_process(.2)
	expect(is_equal_approx(world.tactics.best_left,window),"30 seconds paused does not consume tactical window")
	world.resume(); await use("hs_drum")
	expect(world.state.flags.deception and world.state.tactics.volley_spent,"prepared on-time drum resolves best tactic exactly once")
	var after_volley = roster_hp()
	for enemy in world.enemies:
		if enemy.has_meta("roster_id"):
			var id = str(enemy.get_meta("roster_id"))
			expect(is_equal_approx(enemy.hp,maxf(enemy.max_hp*.22,before_volley[id]-35)),"strong volley uses one finite hit for "+id)
	for repeat in range(10): await use("hs_drum")
	expect(roster_hp() == after_volley,"E repeats cannot replay volley damage")
	world.title_screen(); expect(world.continue_game(2),"second chapter can continue from its real memory snapshot")
	end_dialogue(); await settle()
	expect(world.state.tactics.volley_spent and saved_roster_hp() == after_volley,"continuing after drum preserves consumed volley and pursuit HP")
	await use("hs_to_river")
	expect(world.stage == "hs_river" and roster_hp() == after_volley,"same pursuit identities and HP move into river map without copies")
	if level == "story":
		await use("hs_back_camp")
		expect(world.stage == "hs_camp" and roster_hp() == after_volley,"returning to camp preserves each wounded pursuer without new reinforcements")
		await use("hs_back_return")
		expect(world.stage == "hs_return" and not world.group_alive("hs_r1") and not world.group_alive("hs_r2") and not world.group_alive("hs_r3"),"backtracking does not replay completed convoy roadblocks")
		clear_optional("hs_wounded"); await use("hs_zhangzhu"); end_dialogue()
		expect(world.state.flags.wounded,"missed Zhang Zhu rescue remains completable after river arrival")
		await use("hs_back_grain")
		expect(world.stage == "hs_grain","backtracking reaches original northern supply side road")
		clear_optional("hs_beacon_guard"); await use("hs_beacon"); end_dialogue()
		expect(world.state.flags.beacon,"missed beacon can be completed after the camp stratagem")
		await use("hs_to_return"); await use("hs_to_camp"); await use("hs_to_river")
		expect(world.stage == "hs_river" and roster_hp() == after_volley,"forward route resumes same pursuit HP after multiple backtracking maps")
	kill_live("river_roster"); pump(.02); clear_main()
	await use("hs_to_final")
	if world.mode == "dialog":
		world.choose_route("hanshuiFinal")
		if not world.pending_stage.is_empty(): world._physics_process(0)
		await settle()
	expect(world.stage == "hs_final","river pursuit leads to real dujun final region")
	clear_main(); await use("hs_dujun")
	if world.mode == "dialog": world.choose_route("bossStart:dujun")
	expect(world.active_boss == "dujun" and world.boss.boss_id == "dujun","final interaction starts original two-phase dujun boss")
	world.hero.invincible = 0; world.hero.take_damage(9999,885)
	expect(world.mode == "defeat","dujun duel uses normal failure handling")
	world.retry(); await settle()
	expect(world.active_boss == "dujun" and world.boss.hp == world.boss.max_hp,"dujun retry recreates a full live boss at duel checkpoint")
	world.boss.take_hit(10000,0,0,"player",0,true); end_dialogue()
	expect(world.state.flags.dujun and world.active_boss.is_empty(),"defeating dujun records the chapter-specific boss outcome")
	await use("hs_finish")
	expect(world.state.complete and world.mode == "ending","six-region main route reaches actual chapter-two ending")
	expect(world.state.flags.huilan,"best-tactic chapter clear earns Huilan once")
	var history_after = world.state.history.duplicate()
	expect(not world.finish() and world.state.history == history_after,"ending cannot duplicate completion rewards")
	expect(Campaign.valid(world.state.snapshot()),"fully played chapter produces a valid v2 save")
	var report = world.state.build_report()
	expect(report.chapter == 2 and report.changes == 3,"chapter-two war report records rescue, beacon and best tactic")
	world.title_screen(); expect(world.continue_game(2),"completed chapter can reopen through Continue")
	expect(world.mode == "ending" and world.state.complete and world.state.build_report() == report,"Continue of completed chapter opens saved war report without restarting gameplay")
	expect(world.state.rewards.huilan,"earned Huilan lives outside the replayed chapter flags")
	world.start_game("normal",2); end_dialogue()
	expect(not world.state.complete and not world.state.flags.huilan and world.state.rewards.huilan,"chapter replay resets its run while preserving permanent unlocked skill")
	expect(world.state.tactics.get("huilan_equipped",false),"earned variant is equipped for second-chapter replay")
	var variant_qi = world.hero.qi; var variant_medicine = world.hero.potions
	world.hero.request("sweep",Vector2.ZERO,0)
	expect(world.hero.action.get("key","") == "huilan","replayed Q actually starts the earned Huilan attack")
	expect(is_equal_approx(world.hero.qi,variant_qi-30) and is_equal_approx(world.hero.sweep_cd,3.4) and world.hero.potions == variant_medicine,"Huilan keeps original Q qi/cooldown budget and does not consume medicine")
	expect(not world.hero.request("sweep",Vector2.ZERO,0) and is_equal_approx(world.hero.qi,variant_qi-30),"Huilan cannot double-spend or restart while its own attack is active")
	world.start_game("normal",1); end_dialogue()
	world.hero.request("sweep",Vector2.ZERO,0)
	expect(world.state.chapter == 1 and world.state.rewards.huilan and world.hero.action.get("key","") == "sweep","first-chapter replay retains global reward but uses its own original skills")

func gate_alternatives() -> void:
	await gate_ready(true); await beat_probes(); pump(4.1)
	expect(world.tactics.gate_state == "LATE_WINDOW","missed gold window stays recoverable")
	var hp = roster_hp(); await use("hs_drum")
	expect(not world.state.flags.deception and world.state.flags.volley,"late drum gives ordinary route, not the best reward")
	for enemy in world.enemies:
		if enemy.has_meta("roster_id"): expect(is_equal_approx(enemy.hp,maxf(enemy.max_hp*.22,hp[str(enemy.get_meta("roster_id"))]-18)),"late volley has weaker one-time damage")
	await use("hs_to_river")
	expect(world.stage == "hs_river","missed timing still permits river progression")
	await gate_ready(false); await beat_probes(); await use("hs_drum")
	expect(not world.state.flags.deception and world.state.flags.volley,"no soldier commands still permits ordinary drum route")
	await use("hs_to_river"); expect(world.stage == "hs_river","unprepared camp route never softlocks")
	await gate_ready(false); await beat_probes()
	world.hero.position = Vector2(1501,560); pump(.01)
	expect(world.tactics.gate_state == "COUNTER_DIRECT" and not world.state.flags.volley,"direct pursuit is a valid route without drum damage")
	await use("hs_to_river"); expect(world.stage == "hs_river","direct pursuit also loads river combat")
	await gate_ready(true)
	for ally in world.allies: ally.hp = 0
	await beat_probes(); await use("hs_drum")
	expect(not world.state.flags.deception and world.state.tactics.volley_spent,"all soldiers down still leaves a player-completable camp route")
	await gate_ready(false)
	for step in range(3): pump(1.3)
	var first = world.first_guard(["gate_probe1"]); first.position = Vector2(990,560); pump(.02)
	expect(world.state.tactics.extra_used,"one real gate-line breach requests finite remedy")
	for step in range(3): pump(1.3)
	var extra_count = 0
	for enemy in world.enemies:
		if enemy.group_id == "gate_extra": extra_count += 1
	expect(extra_count == 2,"remedy wave contains exactly two units")
	kill_live("gate_probe1"); kill_live("gate_extra"); pump(.01)
	expect(world.tactics.gate_state == "PROBE_2","breach does not reset completed first probe")
	world.hero.invincible = 0; world.hero.take_damage(9999,998); world.retry(); await settle()
	expect(world.state.tactics.extra_used and world.state.cleared.has("hs_camp:gate_probe1"),"death retains consumed remedy and first probe completion")
	for step in range(3): pump(1.3)
	expect(not world.group_alive("gate_probe1") and not world.group_alive("gate_extra") and world.group_alive("gate_probe2"),"retry creates only unfinished second probe")
	await fresh(); world.state.flags.cart = true; world.state.flags.huangzhong = true
	await enter("hs_camp",Vector2(640,360)); world.set_command("hold")
	world.allies[0].position = Vector2(640,360); world.allies[1].position = Vector2(860,560); world.allies[2].position = Vector2(900,600)
	await use("hs_gate")
	expect(not world.state.tactics.get("deception_ok",false),"one hidden soldier does not conceal two exposed living soldiers")
	await gate_ready(true)
	world.allies[0].position = Vector2(900,560); pump(.01)
	expect(not world.state.tactics.get("deception_ok",false),"a living hidden soldier leaving cover exposes the stratagem")
	await gate_ready(false); await beat_probes(); await use("hs_drum")
	var old_roster = saved_roster_hp()
	expect(old_roster.size() == 4,"replay isolation case starts with a real four-member pursuit roster")
	world.start_game("normal",2); end_dialogue()
	expect(world.stage == "hs_forest" and world.state.tactics.get("roster",[]).is_empty(),"starting fresh in camp cannot leak old live roster into the new run")
	expect(world.state.tactics.get("gate","PREPARE") == "PREPARE","new chapter always resets stratagem state")

func camp_weapon_collision() -> void:
	await fresh(); await enter("hs_camp",Vector2(930,560))
	var target = world.spawn_enemy("sword",Vector2(1060,560),"weapon-wall-contract")
	await settle()
	var hp = target.hp
	world.hero.request("attack",Vector2.ZERO,0)
	world.hero.advance_action(world.hero.action.def.windup+.02)
	expect(target.hp == hp,"Zhao Yun's actual spear cannot hit an enemy through the shut native camp gate")
	world.hero.action = {}; await use("hs_gate")
	world.hero.request("attack",Vector2.ZERO,0)
	var damage = world.hero.action.def.damage
	world.hero.advance_action(world.hero.action.def.windup+.02)
	expect(is_equal_approx(target.hp,hp-damage),"opening that same gate permits the same real spear hit")
	world.hero.hp = 100; world.hero.qi = 10; world.hero.potions = 0
	var checkpoint = world.state.checkpoint.duplicate(true)
	var rested = await use("hs_camp_fire")
	expect(not rested and world.hero.hp == 100 and world.hero.qi == 10 and world.hero.potions == 0,"blocked camp fire cannot secretly refill resources during camp probes")
	expect(world.state.checkpoint == checkpoint,"blocked mid-probe rest cannot overwrite the tactical checkpoint")

func run() -> void:
	save_fingerprints = fingerprints(); campaign_contracts()
	world = MemoryWorld.new(); world.test_mode = true; world.state = MemoryCampaign.new()
	root.add_child(world); world.set_physics_process(false); world.set_process(false)
	await settle(); world.ui.hide_overlay()
	await main_route(); await main_route("story"); await gate_alternatives(); await camp_weapon_collision()
	for result in ["BEST","LATE"]:
		await gate_ready(true); await beat_probes()
		for enemy in world.enemies:
			if enemy.has_meta("roster_id"): enemy.hp=enemy.max_hp*.1
		var wounded_roster=roster_hp()
		world.tactics.resolve_counter(result)
		expect(roster_hp()==wounded_roster,"low-health retreating enemies never heal from "+result+" volley floor")
	expect(fingerprints() == save_fingerprints,"chapter-two acceptance never rewrites real v1 or v2 player saves")
	print("HANSHUI_FLOW_VERIFY ",checks," checks; ",failures.size()," failures; maximum live enemies ",maximum_living)
	world.queue_free(); await process_frame; await process_frame
	quit(0 if failures.is_empty() else 1)
