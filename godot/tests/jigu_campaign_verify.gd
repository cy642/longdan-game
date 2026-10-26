extends SceneTree
## Production chapter buttons, JSON persistence and Hero Q selection. All files
## use dedicated test names; the ordinary player v1/v2 paths are never written.
const Campaign = preload("res://scripts/campaign.gd")
class TestWorld extends "res://scripts/world.gd":
	var save_calls = 0
	func save_progress() -> void:
		if is_instance_valid(tactics): tactics.capture_roster()
		save_calls += 1; state.save()
var world
var checks = 0
var failures: Array = []
var files: Array = []
var serial = 0
var original_files: Dictionary = {}

func _initialize() -> void: call_deferred("run")
func expect(ok: bool,message: String) -> void:
	checks += 1
	if not ok: failures.append(message); push_error("JIGU_CAMPAIGN: "+message)
func settle() -> void:
	await process_frame; await physics_frame; await physics_frame
func fingerprints() -> Dictionary:
	var result: Dictionary = {}
	for path in [Campaign.SAVE_PATH,Campaign.LEGACY_PATH]:
		result[path] = FileAccess.get_file_as_bytes(path).hex_encode().sha256_text() if FileAccess.file_exists(path) else "absent"
	return result
func same_json(a: Dictionary,b: Dictionary) -> bool:
	return JSON.parse_string(JSON.stringify(a)) == JSON.parse_string(JSON.stringify(b))
func text_tree(node: Node) -> String:
	if not is_instance_valid(node): return ""
	var result = node.text+"\n" if node is Label or node is BaseButton else ""
	for child in node.get_children(): result += text_tree(child)
	return result
func button_named(node: Node,text: String):
	if node is Button and node.text == text: return node
	for child in node.get_children():
		var found = button_named(child,text)
		if found: return found
	return null
func chapter_picker(node: Node):
	if node is OptionButton and node.item_count == 4 and node.get_item_text(2).contains("箕谷"): return node
	for child in node.get_children():
		var found = chapter_picker(child)
		if found: return found
	return null
func fresh_state() -> void:
	world.detach_tactics(false); world.state = Campaign.new(); serial += 1
	world.state.save_path = "user://longdan-jigu-campaign-"+str(OS.get_process_id())+"-"+str(serial)+".json"
	files.append(world.state.save_path)
func save_disk(data: Dictionary,path: String) -> void:
	var file = FileAccess.open(path,FileAccess.WRITE)
	expect(file != null,"isolated fixture file opens")
	if file:
		file.store_string(JSON.stringify(data)); file.close()
func disk_snapshot() -> Dictionary:
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(world.state.save_path))
	expect(parsed is Dictionary and Campaign.valid(parsed),"actual serialized v2 disk file validates")
	return parsed if parsed is Dictionary else {}
func reload(chapter_id: int) -> void:
	var path = world.state.save_path
	world.detach_tactics(false); world.state = Campaign.new(); world.state.save_path = path
	expect(world.continue_game(chapter_id),"new Campaign reads requested chapter from disk")
	await settle()

func complete_hanshui(level: String = "normal",unlock: bool = true) -> Dictionary:
	fresh_state(); world.state.reset("normal",1)
	world.state.flags.temple = true; world.state.flags.sword = true
	world.state.flags.adou = true; world.state.flags.boss = true; world.state.complete = true
	world.state.history = ["长坂既有战报必须保留。"]; world.state.kills = 27
	world.state.checkpoint = {"stage":"bridge","x":1100.0,"y":340.0,"encounter":""}
	world.state.chapters["1"] = world.state.run_snapshot().duplicate(true)
	world.state.reset(level,2); world.state.battle_art = "counter"
	world.state.flags.dujun = true; world.state.flags.deception = unlock
	world.state.flags.huangzhong = true; world.state.flags.cart = true; world.state.flags.wounded = true
	world.state.history = ["汉水既有战报必须保留。"]; world.state.kills = 38
	world.state.time = 905.5; world.state.precision_count = 7
	world.load_chapter(2); world.enter_stage("hs_final",Vector2(780,850),false)
	world.state.checkpoint = {"stage":"hs_final","x":780.0,"y":850.0,"encounter":""}
	world.mode = "playing"
	expect(world.finish(),"production chapter-two finish opens the handoff report")
	expect(world.ui.first_choice.text == "继续征程 · 箕谷断后","second report exposes the third chapter action")
	expect(world.state.rewards.huilan == unlock,"chapter-two clear unlocks Huilan only when earned")
	return world.state.run_snapshot().duplicate(true)

func verify_fresh_transition(level: String,unlock: bool) -> void:
	var second = complete_hanshui(level,unlock); await settle()
	var first = world.state.chapter_record(1).duplicate(true)
	world.keyboard_attack_held = true; world.hero.buffer = {"kind":"attack"}
	world.ui.first_choice.emit_signal("pressed")
	expect(world.mode == "dialog" and world.state.chapter == 2,"fresh third chapter first displays its story handoff")
	expect(text_tree(world.ui.overlay).contains("游戏演绎"),"new chapter handoff identifies its fictional treatment")
	expect(not world.keyboard_attack_held and world.hero.buffer.is_empty(),"handoff clears held combat input")
	var saves = world.save_calls
	expect(not world.continue_journey() and world.save_calls == saves,"repeated report activation during transition is harmless")
	expect(world.state.run_snapshot() == second,"story transition preserves second chapter record")
	world.ui.first_choice.emit_signal("pressed"); await settle()
	expect(world.state.chapter == 3 and world.stage == "jg_fog" and world.mode == "playing","real report button enters Jigu fog checkpoint")
	expect(is_instance_valid(world.tactics) and world.tactics.name == "JiguDirector","third chapter owns its real finite encounter director")
	expect(world.state.difficulty == level and world.hero.max_hp == (240 if level == "story" else 200),"new chapter inherits difficulty")
	expect(world.state.battle_art == "counter","new chapter inherits selected battle art")
	expect(world.state.rewards.huilan == unlock and world.state.tactics.get("huilan_equipped",false) == unlock,"new chapter inherits earned Huilan availability")
	expect(world.state.chapter_record(1) == first and world.state.chapter_record(2) == second,"both earlier chapter records survive transition byte-for-field")
	var third = world.state.run_snapshot().duplicate(true); saves = world.save_calls
	expect(not world.enter_next_chapter() and not world.continue_journey(),"repeated transition API cannot restart chapter three")
	world.choose_route("journey:jigu")
	expect(world.state.run_snapshot() == third,"repeated stale transition route does not reset Jigu")
	var disk = disk_snapshot()
	expect(disk.chapters.size() == 3 and disk.chapter == 3,"actual disk contains all three independent chapter records")
	expect(same_json(disk.chapters["1"],first) and same_json(disk.chapters["2"],second),"disk retains both earlier results")
	await reload(3)
	expect(same_json(world.state.run_snapshot(),third),"fresh process-style disk reload retains exact third chapter run")
	verify_q(unlock)

func verify_q(unlocked: bool) -> void:
	for equipped in [true,false]:
		world.state.tactics.huilan_equipped = equipped
		world.hero.reset_combat(); world.hero.invincible = 0; world.hero.spear_spirit = 0
		expect(world.hero.perform("sweep",Vector2.ZERO,0),"chapter-three Q produces a real action")
		expect(world.hero.action.key == ("huilan" if unlocked and equipped else "sweep"),"chapter-three Q honors both unlock and player's on/off choice")
	world.hero.reset_combat()

func install_jigu(completed: bool) -> Dictionary:
	world.detach_tactics(false); world.state.switch_chapter(3,"normal",true)
	world.state.battle_art = "assault"; world.state.history = ["箕谷已有进度不可被汉水按钮重置。"]
	world.state.kills = 19; world.state.precision_count = 4; world.state.time = 333.75
	world.state.flags.jg_banner = true; world.state.flags.jg_dispatch = true; world.state.flags.jg_front = true
	world.state.tactics = {"huilan_equipped":false}
	world.state.cleared = ["jg_fog:jg_fog_scout","jg_signal:jg_signal_guard"]
	world.state.checkpoint = {"stage":"jg_pass","x":620.0,"y":760.0,"encounter":""}
	if completed:
		world.state.flags.jg_rear = true; world.state.flags.jg_rearguard = true
		world.state.flags.jg_bridge_held = true; world.state.flags.jg_last_guard = true
		world.state.flags.jg_boss = true; world.state.flags.jg_supplies = true; world.state.complete = true
		world.state.checkpoint = {"stage":"jg_final","x":1110.0,"y":360.0,"encounter":""}
	var result = world.state.run_snapshot().duplicate(true)
	expect(world.state.save(),"existing third chapter fixture is written to actual disk")
	await reload(2)
	return result

func verify_existing_transition(completed: bool) -> void:
	var second = complete_hanshui("story",true)
	var first = world.state.chapter_record(1).duplicate(true)
	var third = await install_jigu(completed)
	world.ui.first_choice.emit_signal("pressed"); await settle()
	expect(world.state.chapter == 3 and world.stage == third.checkpoint.stage,"existing third chapter resumes its own region")
	expect(same_json(world.state.run_snapshot(),third),"existing third chapter restores exact checkpoint statistics flags art and Huilan choice")
	expect(world.state.difficulty == "normal" and world.hero.max_hp == 200,"existing chapter preserves its own difficulty")
	expect(world.mode == ("ending" if completed else "playing"),"existing completed save opens report and unfinished save opens gameplay")
	expect(same_json(world.state.chapter_record(1),first) and same_json(world.state.chapter_record(2),second),"existing checkpoint handoff preserves prior two chapters")
	expect(not text_tree(world.ui.overlay).contains("开始新的征程？"),"resuming a third chapter never invokes restart confirmation")
	if completed:
		expect(world.ui.first_choice.text=="继续征程 · 陈仓夜袭","completed third report exposes implemented fourth chapter")
		expect(not text_tree(world.ui.overlay).contains("第五章"),"third report does not advertise unimplemented chapters")
		expect(not world.enter_next_chapter(),"fourth chapter cannot start without its explicit story handoff")
	var disk = disk_snapshot()
	expect(same_json(disk.chapters["3"],third),"existing third chapter persists unchanged after handoff")
	await reload(3)
	expect(same_json(world.state.run_snapshot(),third),"three-chapter disk roundtrip preserves all active fields")

func verify_independent_and_replay() -> void:
	var second = complete_hanshui("normal",true); var first = world.state.chapter_record(1).duplicate(true)
	world.title_screen(); await settle()
	var picker = chapter_picker(world.ui.overlay)
	expect(picker != null,"title offers a real third chapter selector")
	if picker:
		picker.selected = 2; picker.item_selected.emit(2)
		var begin = button_named(world.ui.overlay,"开始所选章节")
		expect(begin != null,"independent chapter-three start action exists")
		if begin: begin.emit_signal("pressed")
	await settle()
	expect(world.state.chapter == 3 and world.stage == "jg_fog" and world.mode == "dialog","title starts an independent Jigu run with its introduction")
	expect(world.state.flags.sword and not world.state.complete,"independent third chapter has Qinggang and fresh progression")
	expect(same_json(world.state.chapter_record(1),first) and same_json(world.state.chapter_record(2),second),"independent start preserves both earlier records")
	world.choose_route("continue")
	world.state.flags.jg_banner = true; world.state.flags.jg_front = true; world.state.flags.jg_rear = true
	world.state.flags.jg_rearguard = true; world.state.flags.jg_bridge_cut = true; world.state.flags.jg_boss = true
	world.state.history = ["待重玩的第三章记录。"]
	world.enter_stage("jg_final",Vector2(1110,360),false); world.mode = "playing"
	world.state.checkpoint = {"stage":"jg_final","x":1110.0,"y":360.0,"encounter":""}
	expect(world.finish(),"real chapter-three completion opens final report")
	var replay = button_named(world.ui.overlay,"重玩这一章")
	expect(replay != null,"final report offers explicit replay")
	if replay: replay.emit_signal("pressed")
	expect(text_tree(world.ui.overlay).contains("其他章节的记录会保留"),"replay confirmation states its chapter-local scope")
	var confirm = button_named(world.ui.overlay,"开始新征程")
	if confirm: confirm.emit_signal("pressed")
	await settle()
	expect(world.state.chapter == 3 and world.stage == "jg_fog" and not world.state.complete,"confirmed replay restarts only third chapter")
	var any_progress = false
	for key in Campaign.JIGU_FLAGS:
		if world.state.flags[key]: any_progress = true
	expect(not any_progress and world.state.history.is_empty(),"replay clears all third chapter progress and history")
	expect(same_json(world.state.chapter_record(1),first) and same_json(world.state.chapter_record(2),second),"replay leaves both prior chapters unchanged")
	expect(world.state.rewards.huilan,"replay retains earned account-wide Huilan reward")
	disk_snapshot()

func verify_legacy() -> void:
	complete_hanshui("normal",true)
	var old = world.state.snapshot().duplicate(true)
	for key in Campaign.JIGU_FLAGS+Campaign.CHENCANG_FLAGS: old.flags.erase(key)
	for record in old.chapters.values():
		for key in Campaign.JIGU_FLAGS+Campaign.CHENCANG_FLAGS: record.flags.erase(key)
	old.erase("battle_art")
	for record in old.chapters.values(): record.erase("battle_art")
	save_disk(old,world.state.save_path)
	await reload(2)
	expect(world.state.chapter == 2 and world.mode == "ending","old two-chapter v2 without Jigu fields remains readable")
	expect(not world.state.flags.jg_banner and world.state.battle_art == "","missing newer fields receive conservative defaults")
	world.ui.first_choice.emit_signal("pressed"); world.ui.first_choice.emit_signal("pressed"); await settle()
	expect(world.state.chapter == 3 and world.stage == "jg_fog","old v2 completion can enter third chapter")
	disk_snapshot()
	var legacy = world.state.chapter_record(1).duplicate(true)
	legacy.merge({"version":1,"engine":"godot"})
	for key in Campaign.HANSHUI_FLAGS+Campaign.JIGU_FLAGS+Campaign.CHENCANG_FLAGS: legacy.flags.erase(key)
	legacy.erase("battle_art"); legacy.erase("tactics")
	save_disk(legacy,world.state.save_path); await reload(1)
	expect(world.state.chapter == 1 and world.state.complete and world.mode == "ending","old v1 report still restores after three-chapter expansion")
	expect(world.state.flags.has("jg_banner") and not world.state.flags.jg_banner and not world.state.rewards.huilan,"v1 migration fills new flags without fabricating rewards")

func verify_invalid_states() -> void:
	var state = Campaign.new(); state.reset("normal",3)
	state.flags.jg_banner = true; state.flags.jg_front = true; state.flags.jg_rear = true
	state.flags.jg_rearguard = true; state.flags.jg_bridge_cut = true; state.flags.jg_boss = true
	state.complete = true; state.checkpoint = {"stage":"jg_final","x":1110.0,"y":360.0,"encounter":""}
	var valid = state.snapshot(); expect(Campaign.valid(valid),"valid completed third chapter fixture passes")
	var cases = [
		{"name":"mutually exclusive bridge choices","flags":{"jg_bridge_held":true}},
		{"name":"last guard without retained bridge","flags":{"jg_last_guard":true}},
		{"name":"rear team without front team","flags":{"jg_front":false}},
		{"name":"stone gate before rear team","flags":{"jg_rear":false}},
		{"name":"bridge choice before rearguard","flags":{"jg_rearguard":false}},
		{"name":"completion without boss","flags":{"jg_boss":false}},
		{"name":"supply claimed without rescue","flags":{"jg_supply_claimed":true}},
		{"name":"nonboolean Jigu flag","flags":{"jg_banner":"yes"}}]
	for item in cases:
		var bad = valid.duplicate(true); bad.flags.merge(item.flags,true)
		expect(not Campaign.valid(bad),"rejects "+item.name)
		var restored = Campaign.new(); var before = restored.snapshot().duplicate(true)
		expect(not restored.restore(bad) and restored.snapshot() == before,"rejected "+item.name+" leaves current state untouched")
	var bad = valid.duplicate(true); bad.checkpoint.encounter = "dujun"
	expect(not Campaign.valid(bad),"third chapter rejects an encounter from another chapter")
	bad = valid.duplicate(true); bad.checkpoint.stage = "hs_final"
	expect(not Campaign.valid(bad),"third chapter rejects another chapter's checkpoint")
	bad = valid.duplicate(true); bad.chapters["5"] = bad.chapters["3"].duplicate(true)
	expect(not Campaign.valid(bad),"v2 rejects a nonexistent fifth chapter archive")
	bad = valid.duplicate(true); bad.chapters["3"].flags.jg_front = false
	expect(not Campaign.valid(bad),"invalid archived chapter is rejected even with valid active data")

func run() -> void:
	original_files = fingerprints()
	world = TestWorld.new(); world.test_mode = true
	world.state.save_path = "user://longdan-jigu-campaign-empty-"+str(OS.get_process_id())+".json"
	root.add_child(world); world.set_physics_process(false); world.set_process(false); await settle()
	await verify_fresh_transition("normal",true); await verify_fresh_transition("story",false)
	await verify_existing_transition(false); await verify_existing_transition(true)
	await verify_independent_and_replay(); await verify_legacy(); verify_invalid_states()
	expect(fingerprints() == original_files,"ordinary player v1/v2 file fingerprints remain unchanged")
	world.queue_free(); await process_frame; await process_frame
	for path in files:
		if FileAccess.file_exists(path): DirAccess.remove_absolute(path)
		if FileAccess.file_exists(path+".tmp"): DirAccess.remove_absolute(path+".tmp")
	print("JIGU_CAMPAIGN_VERIFY ",checks," checks; ",failures.size()," failures")
	quit(0 if failures.is_empty() else 1)
