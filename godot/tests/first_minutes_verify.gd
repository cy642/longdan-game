extends SceneTree
## First-play guidance uses real world/UI/input paths with memory-only saves.
## No player save is read, overwritten, restored, or removed by this suite.
const Game = preload("res://scripts/world.gd")
const Campaign = preload("res://scripts/campaign.gd")
class MemoryCampaign extends Campaign:
	func read_save() -> Dictionary: return last_save.duplicate(true)
	func save() -> bool:
		last_save = snapshot(); return true

var world
var checks = 0
var failures: Array = []

func _initialize() -> void: call_deferred("run")
func expect(value: bool, message: String) -> void:
	checks += 1
	if not value: failures.append(message); push_error("FIRST_MINUTES: " + message)
func settle() -> void:
	await process_frame; await physics_frame; await physics_frame
func button_containing(fragment: String) -> Button:
	for candidate in world.ui.overlay.find_children("*", "Button", true, false):
		if candidate.text.contains(fragment): return candidate
	return null
func at_object(id: String) -> Vector2:
	var object = world.object_by_id(id)
	return Vector2(object.x, object.y)
func fresh_mountain() -> void:
	world.detach_tactics(false); world.state = MemoryCampaign.new()
	world.start_game("normal", 1)
func clear_mountain() -> void:
	for enemy in world.enemies:
		enemy.hp = 0; enemy.collision_layer = 0; enemy.action = {}; enemy.sequence = []
	world.check_groups()
func input_key(key: Key) -> void:
	var event = InputEventKey.new(); event.keycode = key; event.pressed = true
	world._unhandled_input(event)
	event = InputEventKey.new(); event.keycode = key; event.pressed = false
	world._input(event)

func defeat_rescue_guards() -> void:
	for enemy in world.enemies:
		if enemy.body_alive() and enemy.group_id.begins_with("rescue"):
			enemy.take_hit(10000,0,0,"player",0,true)

func begin_rescue_check() -> void:
	fresh_mountain(); world.choose_route("continue")
	world.state.flags.healer=true; world.state.flags.temple=true; world.state.flags.sword=true
	world.enter_stage("house",Vector2(1090,560),false); await settle()
	for enemy in world.enemies:
		if enemy.body_alive(): enemy.take_hit(10000,0,0,"player",0,true)
	world.hero.position=at_object("adou"); world.interact(); world.choose_route("rescue")
	expect(world.mode=="playing" and not world.rescue.is_empty() and world.rescue.wave==1,"actual well interaction starts the two-wave rescue")

func rescue_finish_checks() -> void:
	await begin_rescue_check()
	world.advance_rescue(.2)
	expect(not world.state.flags.mother and world.rescue.wave==1 and world.rescue_remaining()==3,"first live wave cannot be skipped by the faster rescue finish")
	defeat_rescue_guards(); world.advance_rescue(1.49)
	expect(world.rescue.wave==1 and not world.state.flags.mother,"first-wave pause never awards the rescue")
	world.advance_rescue(.02)
	expect(world.rescue.wave==2 and world.rescue_remaining()==3,"first-wave pause still produces the complete second wave")
	defeat_rescue_guards(); world.advance_rescue(.6)
	var progress=world.rescue.progress; var gap=world.rescue.gap
	expect(progress<20 and not world.state.flags.mother,"fast clear retains a brief visible medical finish")
	world.pause("pause"); world._physics_process(30)
	expect(world.rescue.progress==progress and world.rescue.gap==gap and not world.state.flags.mother,"pause freezes the real rescue finish instead of awarding it")
	world.resume(); world.advance_rescue(.59)
	expect(not world.state.flags.mother,"rescue does not complete before the short finish delay")
	world.advance_rescue(.02)
	expect(world.mode=="dialog" and world.rescue.is_empty() and world.state.flags.mother and world.state.flags.house,"both actual waves plus the short finish rescue Mi Lady without waiting twenty seconds")
	expect(world.state.checkpoint.encounter=="" and world.state.checkpoint.stage=="house","fast rescue writes the completed well checkpoint")
	var history_count=world.state.history.size(); world.advance_rescue(30)
	expect(world.state.history.size()==history_count,"completed rescue cannot award its history again")
	# Failure is checked at the same final gap, not only at encounter start.
	await begin_rescue_check()
	defeat_rescue_guards(); world.advance_rescue(1.6)
	defeat_rescue_guards(); world.advance_rescue(.6)
	progress=world.rescue.progress; gap=world.rescue.gap
	world.hero.invincible=0; world.hero.take_damage(10000,99101)
	world._physics_process(30)
	expect(world.mode=="defeat" and not world.state.flags.mother and world.rescue.progress==progress and world.rescue.gap==gap,"Zhao Yun's defeat cannot advance a pending rescue finish")
	world.retry(); await settle()
	expect(world.mode=="playing" and world.rescue.wave==1 and world.rescue_remaining()==3 and world.state.flags.healer and world.state.flags.adou,"retry after a late rescue failure keeps prior rescues and restarts both waves")
	defeat_rescue_guards(); world.advance_rescue(1.6)
	defeat_rescue_guards(); world.advance_rescue(.6)
	world.rescue.healer.take_damage(10000); world.advance_rescue(1)
	expect(world.mode=="defeat" and not world.state.flags.mother,"healer loss takes priority over elapsed final recovery time")

func run() -> void:
	world = Game.new(); world.state = MemoryCampaign.new(); world.test_mode = true
	root.add_child(world); world.set_process(false); world.set_physics_process(false)
	await settle()
	# Restore production save call sites only after the injected state exists.
	# MemoryCampaign overrides both save and read_save, including title/start flow.
	world.test_mode = false
	fresh_mountain()
	expect(world.mode == "dialog", "new first chapter opens its authored introduction")
	expect(world.ui.toast_text.text == world.definition.tutorial and world.ui.toast_left > 0,
		"zone tutorial survives stage_changed and waits behind the introduction")
	var pending_tutorial = world.ui.toast_left
	world.ui.refresh(12)
	expect(is_equal_approx(world.ui.toast_left, pending_tutorial) and not world.ui.toast_text.visible,
		"reading the introduction cannot consume a hidden tutorial")
	world.ui.first_choice.pressed.emit()
	expect(world.mode == "playing", "actual introduction button starts play")
	world.ui.refresh(.2)
	expect(world.ui.toast_text.visible and is_equal_approx(world.ui.toast_left, pending_tutorial - .2),
		"tutorial countdown begins only when visible in play")
	for mode in ["pause", "map"]:
		world.pause(mode)
		var before = world.ui.toast_left
		world.ui.refresh(6)
		expect(is_equal_approx(world.ui.toast_left, before) and not world.ui.toast_text.visible,
			"hidden tutorial freezes in " + mode)
		world.resume(); world.ui.refresh(.1)
		expect(world.ui.toast_text.visible and is_equal_approx(world.ui.toast_left, before - .1),
			"tutorial continues after " + mode)
	world.enter_stage("village", Vector2.INF, false)
	expect(world.ui.toast_text.text == world.definition.tutorial and world.ui.toast_left > 0,
		"later zone tutorial replaces the previous one without being cleared")

	fresh_mountain(); world.choose_route("continue")
	var first_guard = world.first_guard(["m1"])
	expect(is_instance_valid(first_guard) and world.mission().pos == first_guard.position,
		"first encounter remains the objective while its enemy is alive")
	clear_mountain()
	expect(world.state.flags.mountain and world.mission().pos == at_object("campMountain"),
		"first cleared mountain points an untrained player at the real camp")
	world.hero.position = at_object("toVillage")
	expect(not world.object_blocked(world.object_by_id("toVillage")),
		"camp recommendation does not lock the exit")
	expect(world.interact() and world.pending_stage.get("id", "") == "village",
		"player may actually choose to leave without visiting camp")
	world.pending_stage = {}
	world.hero.position = at_object("campMountain")
	world.state.seen.append("old-story-marker")
	expect(world.interact() and world.mode == "camp", "actual E interaction opens first camp")
	expect(world.state.seen.has("camp:mountain") and world.state.seen.has("old-story-marker"),
		"camp visit appends its marker without replacing existing story history")
	expect(world.state.last_save.get("seen", []).has("camp:mountain"),
		"the real camp save captures the visit marker before leaving")
	expect(is_instance_valid(world.ui.first_choice) and world.ui.first_choice.text.contains("连锋"),
		"first camp keyboard focus introduces a concrete battle art")
	world.toast("营火说明保留")
	var camp_toast = world.ui.toast_left
	world.ui.refresh(6)
	expect(is_equal_approx(world.ui.toast_left, camp_toast), "camp decisions freeze hidden notification time")
	var keep = button_containing("继续前行")
	expect(keep != null, "base style remains an explicit camp choice")
	if keep: keep.pressed.emit()
	expect(world.mode == "playing" and world.state.battle_art == "", "keeping the base style genuinely resumes")
	expect(world.mission().pos == at_object("toVillage"),
		"camp guidance respects a player's deliberate base-style choice")

	# Simulate an old v2 record: existing seen history is authoritative and the
	# optional battle_art field may be absent from both active and chapter records.
	var old = world.state.snapshot()
	old.erase("battle_art"); old.chapters["1"].erase("battle_art")
	var old_seen = old.seen.duplicate()
	world.state = MemoryCampaign.new()
	expect(Campaign.valid(old) and world.state.restore(old), "older record with visit history remains valid")
	world.enter_stage("mountain", Vector2.INF, false)
	expect(world.state.seen == old_seen and world.state.battle_art == "", "old story and camp history survives restore")
	expect(world.mission().pos == at_object("toVillage"), "restored base-style camp visit does not repeat its guidance")
	world.state.seen.erase("camp:mountain"); world.state.battle_art = "counter"
	expect(world.mission().pos == at_object("toVillage"), "an existing battle art needs no first-camp detour")
	world.hero.position = at_object("campMountain"); world.interact()
	expect(world.ui.first_choice.text.contains("继续前行"), "experienced camp visits focus the continue action")
	world.ui.first_choice.pressed.emit()
	world.state.battle_art = ""; world.hero.position = at_object("campMountain"); world.interact()
	var art_choice = world.ui.first_choice
	expect(art_choice.text.contains("连锋"), "unchosen style has an actionable default choice")
	art_choice.pressed.emit()
	expect(world.mode == "playing" and world.state.battle_art == "assault",
		"the focused battle-art button really equips and resumes")

	# Action feedback must explain rejected input, without changing resources,
	# replacing normal input buffering, or flooding a newer notification.
	var hero = world.hero
	hero.reset_combat(); hero.qi = 0; hero.spear_spirit = 3
	world.toast("原提示")
	var reason = hero.unavailable_reason("dash")
	expect(not reason.is_empty() and reason.contains("气力"), "dash rejection exposes its resource reason")
	expect(hero.qi == 0 and hero.dash_cd == 0 and hero.action.is_empty() and world.ui.toast_text.text == "原提示",
		"querying availability has no action, resource, or message side effects")
	var serial = world.serial
	input_key(KEY_SPACE)
	expect(hero.dash_left == 0 and hero.qi == 0 and world.serial == serial,
		"rejected real dash input cannot start or spend anything")
	expect(world.ui.toast_text.text.contains("气力") and hero.feedback_left > 0,
		"rejected input gives visible resource feedback")
	world.toast("另一条战报")
	input_key(KEY_SPACE)
	expect(world.ui.toast_text.text == "另一条战报", "repeat rejected input cannot overwrite a newer message during throttle")
	hero.advance(.76, Vector2.ZERO, false, INF)
	input_key(KEY_SPACE)
	expect(world.ui.toast_text.text.contains("气力"), "rejected input can explain itself again after the finite throttle")

	hero.reset_combat(); hero.qi = 100; hero.dash_cd = .5
	world.ui.refresh(0)
	expect(not hero.unavailable_reason("dash").is_empty(), "dash cooldown has an availability reason")
	expect(world.ui.skills.dash.text.contains("s") or world.ui.skills.dash.text.contains("冷却"),
		"dash button communicates its actual cooldown")
	hero.dash_cd = 0; hero.qi = 0; world.ui.refresh(0)
	expect(world.ui.skills.dash.text.contains("气"), "dash button communicates insufficient qi")
	for blocked_by in ["cooldown", "qi"]:
		hero.reset_combat(); hero.spear_spirit = 3
		hero.sweep_cd = .5 if blocked_by == "cooldown" else 0
		hero.qi = 100 if blocked_by == "cooldown" else 29
		world.ui.refresh(0)
		expect(not world.ui.art_text.text.contains("已就绪"), "full spirit does not falsely claim readiness during " + blocked_by)
		var before_qi = hero.qi
		input_key(KEY_Q)
		expect(hero.action.is_empty() and hero.spear_spirit == 3 and hero.qi == before_qi,
			"unavailable empowered Q preserves all stored resources during " + blocked_by)
	hero.reset_combat(); hero.spear_spirit = 3; world.ui.refresh(0)
	expect(hero.unavailable_reason("sweep").is_empty(), "charged Q is available when the real requirements are met")

	hero.reset_combat(); hero.position = Vector2(850, 900)
	hero.request("attack", Vector2.ZERO, 0)
	hero.action.t = hero.action.def.windup + hero.action.def.active + hero.action.def.recovery - .06
	world.toast("保留合法缓冲说明")
	var qi_before_buffer = hero.qi
	expect(hero.request("sweep", Vector2.ZERO, 0) and hero.buffer.get("kind", "") == "sweep",
		"Q in the final recovery window still enters the production input buffer")
	expect(world.ui.toast_text.text == "保留合法缓冲说明" and hero.feedback_left == 0 and hero.qi == qi_before_buffer,
		"accepted buffering neither reports an error nor spends qi early")
	hero.advance_action(.07); hero.consume_buffer(0)
	expect(hero.action.get("key", "") == "sweep" and hero.buffer.is_empty() and hero.qi == qi_before_buffer - 30,
		"buffered Q starts after recovery and spends exactly once")
	hero.consume_buffer(0)
	expect(hero.qi == qi_before_buffer - 30, "a consumed buffer cannot charge again")

	await rescue_finish_checks()
	print("FIRST_MINUTES_VERIFY ", checks, " checks; ", failures.size(), " failures")
	world.queue_free(); await process_frame
	quit(0 if failures.is_empty() else 1)
