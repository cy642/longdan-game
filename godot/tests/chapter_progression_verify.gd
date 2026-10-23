extends SceneTree
## Exercise production report buttons, chapter nodes and actual JSON round-trips.
## Every write is isolated; player v1/v2 files are fingerprinted, never restored.
const Campaign=preload("res://scripts/campaign.gd")
class TestWorld extends "res://scripts/world.gd":
	var save_calls=0
	func save_progress() -> void:
		if is_instance_valid(tactics): tactics.capture_roster()
		save_calls+=1; state.save()
var world
var checks=0
var failures: Array=[]
var files: Array=[]
var user_before: Dictionary={}
var serial=0

func _initialize() -> void: call_deferred("run")
func expect(condition: bool,message: String) -> void:
	checks+=1
	if not condition: failures.append(message); push_error("FAIL: "+message)
func settle() -> void:
	await process_frame; await physics_frame; await physics_frame
func fingerprints() -> Dictionary:
	var result: Dictionary={}
	for path in [Campaign.SAVE_PATH,Campaign.LEGACY_PATH]:
		result[path]=FileAccess.get_file_as_bytes(path).hex_encode().sha256_text() if FileAccess.file_exists(path) else "absent"
	return result
func text_tree(node: Node) -> String:
	if not is_instance_valid(node): return ""
	var result=node.text+"\n" if node is Label or node is BaseButton else ""
	for child in node.get_children(): result+=text_tree(child)
	return result
func same_json(a: Dictionary,b: Dictionary) -> bool:
	# JSON round-trips integer fields as float. Normalize both reports through
	# the same parser while still comparing every field and numeric value.
	return JSON.parse_string(JSON.stringify(a))==JSON.parse_string(JSON.stringify(b))
func new_campaign() -> void:
	world.detach_tactics(false)
	world.state=Campaign.new()
	serial+=1
	world.state.save_path="user://longdan-progression-"+str(OS.get_process_id())+"-"+str(serial)+".json"
	files.append(world.state.save_path)
func complete_first(level: String="normal") -> Dictionary:
	new_campaign()
	world.start_game(level,1); world.choose_route("continue")
	world.state.flags.temple=true; world.state.flags.sword=true
	world.state.flags.adou=true; world.state.flags.boss=true
	world.state.flags.civilians=true; world.state.flags.healer=true
	world.state.flags.mother=true; world.state.flags.supplies=true
	world.state.kills=31; world.state.precision_count=6
	world.state.battle_art="counter"
	world.state.time=711; world.state.record("长坂归营，母子同归。")
	world.enter_stage("bridge",Vector2(820,560),false); world.mode="playing"
	world.state.checkpoint={"stage":"bridge","x":820.0,"y":560.0,"encounter":""}
	expect(world.finish(),"first chapter completes through production finish()")
	expect(world.mode=="ending" and world.state.complete,"completion opens report")
	expect(world.ui.first_choice.text=="继续征程 · 汉水孤营","first report prioritizes next chapter")
	expect(world.state.durable,"isolated first report is durable")
	expect(not world.finish(),"repeated completion cannot duplicate report")
	return world.state.build_report().duplicate(true)
func disk_snapshot() -> Dictionary:
	var contents=JSON.parse_string(FileAccess.get_file_as_string(world.state.save_path))
	expect(contents is Dictionary and Campaign.valid(contents),"actual disk JSON validates")
	return contents if contents is Dictionary else {}
func reload_from_disk(chapter_id: int) -> void:
	var path=world.state.save_path
	world.detach_tactics(false); world.state=Campaign.new(); world.state.save_path=path
	expect(world.continue_game(chapter_id),"fresh Campaign resumes saved chapter from disk")
	await settle()
func verify_fresh(level: String) -> void:
	var report=complete_first(level)
	await settle()
	var report_scroll=world.ui.first_choice.get_parent().get_parent()
	expect(report_scroll.get_global_rect().encloses(world.ui.first_choice.get_global_rect()),"primary report action is visible inside scroll viewport")
	var first_run=world.state.run_snapshot().duplicate(true)
	world.keyboard_attack_held=true; world.hero.buffer={"kind":"attack"}
	world.ui.first_choice.emit_signal("pressed")
	expect(world.mode=="dialog" and world.state.chapter==1,"first report leads to military transition")
	expect(text_tree(world.ui.overlay).contains("十一年后"),"transition explains historical time jump")
	expect(not world.keyboard_attack_held and world.hero.buffer.is_empty(),"transition clears held combat input")
	var save_calls=world.save_calls
	expect(not world.continue_journey(),"double report activation ignored during transition")
	expect(world.save_calls==save_calls,"ignored activation causes no save or reset")
	expect(world.state.run_snapshot()==first_run,"transition leaves first report intact")
	world.ui.first_choice.emit_signal("pressed")
	await settle()
	expect(world.state.chapter==2 and world.stage=="hs_forest" and world.mode=="playing","military transition enters actual Hanshui forest")
	expect(is_instance_valid(world.tactics) and world.enemies.size()>0,"second chapter director and actual enemies exist")
	expect(world.state.difficulty==level and world.hero.max_hp==(240 if level=="story" else 200),"first arrival inherits selected difficulty")
	expect(world.state.battle_art=="counter","first arrival inherits chosen battle art")
	expect(world.state.chapter_record(1)==first_run,"first chapter result archived without reset")
	expect(world.state.flags.sword and not world.state.complete,"fresh Hanshui begins with Qinggang")
	var next_snapshot=world.state.snapshot().duplicate(true)
	save_calls=world.save_calls
	world.choose_route("journey:hanshui")
	expect(not world.enter_next_chapter() and not world.continue_journey(),"repeated transition rejected after entry")
	expect(world.state.snapshot()==next_snapshot and world.save_calls==save_calls,"repeated transition does not reset progress or write")
	var disk=disk_snapshot()
	expect(disk.chapter==2 and disk.chapters["1"].complete,"disk contains active second chapter and completed first")
	await reload_from_disk(1)
	expect(same_json(world.state.build_report(),report),"first chapter report survives process-style reload")
	world.ui.first_choice.emit_signal("pressed"); await settle()
	expect(world.mode=="playing" and world.state.chapter==2 and world.stage=="hs_forest","existing fresh checkpoint resumes without another military transition")

func install_second(completed: bool) -> Dictionary:
	world.state.switch_chapter(2,"normal",true)
	world.state.battle_art="assault"
	world.state.flags.huangzhong=true; world.state.flags.cart=true
	world.state.flags.wounded=true; world.state.flags.beacon=true
	world.state.cleared=["hs_forest:forest_main"]
	world.state.history=["汉水既有征程不可重置。"]; world.state.kills=17
	world.state.precision_count=3; world.state.time=237.5
	world.state.tactics={"escort_index":2,"cart_hp":91,"gate":"PREPARE"}
	world.state.checkpoint={"stage":"hs_return","x":275.0,"y":870.0,"encounter":""}
	if completed:
		world.state.flags.dujun=true; world.state.flags.deception=true; world.state.flags.huilan=true
		world.state.rewards.huilan=true; world.state.complete=true
		world.state.tactics.huilan_equipped=false
		world.state.checkpoint={"stage":"hs_final","x":780.0,"y":850.0,"encounter":""}
	var record=world.state.run_snapshot().duplicate(true)
	expect(world.state.save(),"existing second chapter written to isolated disk")
	await reload_from_disk(1)
	return record

func verify_existing(completed: bool) -> void:
	var first_report=complete_first("story")
	var second=await install_second(completed)
	var first_run=world.state.run_snapshot().duplicate(true)
	world.ui.first_choice.emit_signal("pressed"); await settle()
	expect(world.state.chapter==2,"handoff selects existing second chapter")
	expect(world.state.difficulty=="normal" and world.hero.max_hp==200,"existing second chapter retains its own difficulty")
	expect(world.state.battle_art=="assault","existing second chapter retains its independent battle art")
	expect(world.state.checkpoint==second.checkpoint and world.stage==second.checkpoint.stage,"existing exact checkpoint survives handoff")
	expect(world.state.kills==17 and world.state.precision_count==3 and world.state.time==237.5,"existing battle statistics survive")
	expect(world.state.flags.wounded and world.state.flags.beacon and world.state.history==second.history,"existing side quests and history survive")
	expect(world.state.tactics.get("cart_hp")==91 and world.state.tactics.get("escort_index")==2,"existing escort state survives")
	expect(world.state.chapter_record(1)==first_run,"handoff preserves completed first chapter")
	if completed:
		expect(world.mode=="ending" and world.state.complete,"completed second chapter opens its report")
		expect(world.ui.first_choice.text=="继续征程 · 箕谷断后","completed Hanshui offers the now-playable third chapter")
		expect(world.state.rewards.huilan,"permanent reward survives existing completed handoff")
		expect(not world.state.tactics.get("huilan_equipped",true),"handoff preserves player's explicitly disabled Huilan variant")
	else:
		expect(world.mode=="playing" and not world.state.complete,"unfinished second chapter resumes playable scene")
	expect(not text_tree(world.ui.overlay).contains("开始新的征程？"),"handoff never invokes destructive restart confirmation")
	var disk=disk_snapshot()
	expect(disk.chapters["1"].complete and disk.chapter==2,"both chapter records written together")
	await reload_from_disk(1)
	expect(same_json(world.state.build_report(),first_report),"completed first report still matches after second handoff")

func verify_legacy_v2() -> void:
	var report=complete_first()
	var old=world.state.snapshot()
	# Original v2 saves have no extra progression metadata. Older stage archives
	# may omit the optional tactics key; the completion hand-off must not need it.
	old.erase("progression"); old.erase("challenge")
	old.erase("tactics")
	old.erase("battle_art")
	old.chapters["1"]=old.chapters["1"].duplicate(true)
	old.chapters["1"].erase("tactics")
	old.chapters["1"].erase("battle_art")
	var file=FileAccess.open(world.state.save_path,FileAccess.WRITE)
	file.store_string(JSON.stringify(old)); file.close()
	await reload_from_disk(1)
	expect(same_json(world.state.build_report(),report),"original v2 completed report remains readable")
	world.ui.first_choice.emit_signal("pressed"); world.ui.first_choice.emit_signal("pressed")
	await settle()
	expect(world.state.chapter==2 and world.stage=="hs_forest","original v2 first clear can enter next chapter")
	expect(world.state.battle_art=="","legacy save without a battle art remains unselected")
	disk_snapshot()

func verify_failure_and_guards() -> void:
	new_campaign(); world.start_game()
	expect(not world.continue_journey() and not world.enter_next_chapter(),"unfinished first chapter cannot skip to next through handoff API")
	world.choose_route("journey:hanshui")
	expect(world.state.chapter==1,"forged route without completion cannot switch chapters")
	complete_first("story")
	var first_run=world.state.run_snapshot().duplicate(true)
	var missing="user://longdan-progression-missing-"+str(OS.get_process_id())+"-"+str(serial)
	expect(not DirAccess.dir_exists_absolute(missing),"failed-save fixture uses an absent parent directory")
	world.state.save_path=missing+"/save.json"
	world.save_progress()
	world.ui.show_report(world.state.build_report())
	expect(not world.state.durable,"intentional failed write reports non-durable state")
	expect(text_tree(world.ui.overlay).contains("战报仅本次有效"),"report never promises a failed save is durable")
	world.ui.first_choice.emit_signal("pressed"); world.ui.first_choice.emit_signal("pressed")
	await settle()
	expect(world.state.chapter==2 and world.stage=="hs_forest","save failure still permits session-only chapter transition")
	expect(not world.state.durable and not world.state.last_save.is_empty(),"failed new chapter save retains session backup")
	expect(world.state.chapter_record(1)==first_run,"failed save transition preserves first report in memory")
	expect(world.continue_game(1) and world.mode=="ending","session backup restores first report after failed disk writes")
	expect(text_tree(world.ui.overlay).contains("战报仅本次有效"),"restored session report retains failure status")

func verify_long_report_visibility() -> void:
	complete_first()
	world.state.flags.mother=false; world.state.flags.civilians=false; world.state.flags.supplies=false
	world.ui.show_report(world.state.build_report()); await settle()
	var scroll=world.ui.first_choice.get_parent().get_parent()
	expect(world.state.build_report().hints.size()==3,"long report fixture has all three replay hints")
	expect(scroll.get_global_rect().encloses(world.ui.first_choice.get_global_rect()),"next-chapter button remains visible with all replay hints")

func run() -> void:
	user_before=fingerprints()
	world=TestWorld.new(); world.test_mode=true
	# Set the isolated state before _ready so even the title cannot read a player file.
	world.state.save_path="user://longdan-progression-empty-"+str(OS.get_process_id())+".json"
	root.add_child(world); world.set_physics_process(false); world.set_process(false)
	await settle()
	await verify_fresh("normal"); await verify_fresh("story")
	await verify_existing(false); await verify_existing(true)
	await verify_legacy_v2(); await verify_failure_and_guards(); await verify_long_report_visibility()
	expect(fingerprints()==user_before,"real player v1/v2 save fingerprints are unchanged")
	world.queue_free(); await process_frame; await process_frame
	for path in files:
		if FileAccess.file_exists(path): DirAccess.remove_absolute(path)
		if FileAccess.file_exists(path+".tmp"): DirAccess.remove_absolute(path+".tmp")
	print("CHAPTER_PROGRESSION_VERIFY checks=",checks," failures=",failures.size())
	quit(0 if failures.is_empty() else 1)
