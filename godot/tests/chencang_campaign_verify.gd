extends "res://tests/jigu_campaign_verify.gd"
## Real chapter/report buttons and isolated JSON files. Previous chapter
## fixtures use the existing harness; no ordinary player save is written.

func expect(ok: bool,message: String) -> void:
	checks+=1
	if not ok: failures.append(message); push_error("CHENCANG_CAMPAIGN: "+message)

func fresh_state() -> void:
	world.detach_tactics(false); world.state=Campaign.new(); serial+=1
	world.state.save_path="user://longdan-chencang-campaign-"+str(OS.get_process_id())+"-"+str(serial)+".json"
	files.append(world.state.save_path)

func completed_third(level: String="normal",unlock: bool=true) -> Dictionary:
	complete_hanshui(level,unlock)
	world.detach_tactics(false); world.state.switch_chapter(3,level,true)
	world.state.battle_art="counter"; world.state.tactics.huilan_equipped=unlock
	for key in ["jg_banner","jg_dispatch","jg_front","jg_rear","jg_rearguard","jg_supplies","jg_bridge_held","jg_last_guard","jg_boss","jg_supply_claimed"]: world.state.flags[key]=true
	world.state.history=["箕谷末队同归，已有战报不可被下一章覆盖。"]
	world.state.kills=41; world.state.time=822.75; world.state.precision_count=8
	world.load_chapter(3); world.enter_stage("jg_final",Vector2(1110,360),false)
	world.state.checkpoint={"stage":"jg_final","x":1110.0,"y":360.0,"encounter":""}; world.mode="playing"
	expect(world.finish() and world.mode=="ending","real third-chapter completion opens report")
	expect(world.ui.first_choice.text=="继续征程 · 陈仓夜袭","third report exposes actual fourth-chapter continuation")
	return world.state.run_snapshot().duplicate(true)

func earlier_records() -> Dictionary:
	var result={}
	for chapter in [1,2,3]: result[str(chapter)]=world.state.chapter_record(chapter).duplicate(true)
	return result

func same_earlier(before: Dictionary) -> bool:
	for chapter in [1,2,3]:
		if not same_json(before[str(chapter)],world.state.chapter_record(chapter)): return false
	return true

func fresh_transition(level: String,unlock: bool) -> void:
	var third=completed_third(level,unlock); var previous=earlier_records(); await settle()
	world.keyboard_attack_held=true; world.hero.buffer={"kind":"attack"}
	world.ui.first_choice.emit_signal("pressed")
	expect(world.mode=="dialog" and world.state.chapter==3,"fresh fourth chapter shows story handoff first")
	expect(text_tree(world.ui.overlay).contains("架空"),"handoff explains fictional Chencang premise")
	expect(not world.keyboard_attack_held and world.hero.buffer.is_empty(),"handoff clears held combat input")
	var saves=world.save_calls
	expect(not world.continue_journey() and world.save_calls==saves,"double report activation does not restart transition")
	expect(world.state.run_snapshot()==third,"story handoff leaves third record untouched")
	world.ui.first_choice.emit_signal("pressed"); await settle()
	expect(world.state.chapter==4 and world.stage=="cc_outer" and world.mode=="playing" and world.tactics.name=="ChencangDirector","actual report button enters fourth-chapter city gate")
	expect(world.state.difficulty==level and world.hero.max_hp==(240 if level=="story" else 200),"fresh fourth chapter inherits difficulty")
	expect(world.state.battle_art=="counter" and world.state.rewards.huilan==unlock and world.state.tactics.get("huilan_equipped",false)==unlock,"fresh fourth chapter inherits battle art and earned Huilan")
	expect(same_earlier(previous),"handoff preserves all three previous records")
	var fourth=world.state.run_snapshot().duplicate(true); saves=world.save_calls
	world.choose_route("journey:chencang")
	expect(not world.enter_next_chapter() and not world.continue_journey() and world.state.run_snapshot()==fourth and world.save_calls==saves,"stale transition cannot restart fourth chapter")
	var disk=disk_snapshot()
	expect(disk.chapter==4 and disk.chapters.size()==4,"actual disk contains four independent chapter records")
	await reload(4)
	expect(same_json(world.state.run_snapshot(),fourth) and same_earlier(previous),"new Campaign disk round-trip preserves fourth and all prior chapters")
	for equipped in [true,false]:
		world.state.tactics.huilan_equipped=equipped; world.hero.reset_combat(); world.hero.invincible=0; world.hero.spear_spirit=0
		expect(world.hero.perform("sweep",Vector2.ZERO,0) and world.hero.action.key==("huilan" if unlock and equipped else "sweep"),"fourth-chapter real Q honors unlock and explicit equip choice")
	world.hero.reset_combat()

func install_fourth(completed: bool) -> Dictionary:
	world.detach_tactics(false); world.state.switch_chapter(4,"normal",true)
	world.state.battle_art="assault"; world.state.tactics={"huilan_equipped":false}
	for key in ["cc_breach","cc_beacon_out","cc_route_flank","cc_street_done","cc_orders"]: world.state.flags[key]=true
	world.state.history=["陈仓已有侧巷进度，前三章按钮不得覆盖。"]
	world.state.kills=18; world.state.time=337.25; world.state.precision_count=5
	world.state.cleared=["cc_outer:cc_o1","cc_outer:cc_o2","cc_beacon:cc_b1","cc_beacon:cc_b2","cc_beacon:cc_orders_guard","cc_street:cc_s_flank1","cc_street:cc_s_flank2"]
	world.state.checkpoint={"stage":"cc_store","x":220.0,"y":900.0,"encounter":""}
	if completed:
		for key in ["cc_warehouse","cc_workers","cc_courtyard","cc_committed","cc_boss"]: world.state.flags[key]=true
		world.state.complete=true; world.state.checkpoint={"stage":"cc_final","x":1110.0,"y":500.0,"encounter":""}
	var record=world.state.run_snapshot().duplicate(true)
	expect(world.state.save(),"existing fourth-chapter fixture writes to dedicated test file")
	await reload(3)
	return record

func existing_transition(completed: bool) -> void:
	completed_third("story",true); var previous=earlier_records()
	var fourth=await install_fourth(completed)
	world.ui.first_choice.emit_signal("pressed"); await settle()
	expect(world.state.chapter==4 and world.stage==fourth.checkpoint.stage and same_json(world.state.run_snapshot(),fourth),"third report resumes exact existing fourth checkpoint or report")
	expect(world.mode==("ending" if completed else "playing") and world.state.difficulty=="normal" and world.hero.max_hp==200,"existing chapter retains its own difficulty and completion")
	expect(not world.state.tactics.huilan_equipped and world.state.battle_art=="assault","existing fourth chapter retains chosen art and disabled Huilan")
	expect(same_earlier(previous),"existing fourth handoff keeps all previous chapters intact")
	expect(not text_tree(world.ui.overlay).contains("开始新的征程？"),"resume never invokes a destructive restart")
	if completed:
		expect(world.ui.first_choice.text.begins_with("回到标题") and not text_tree(world.ui.overlay).contains("继续征程"),"only fourth chapter is the current final report")
		expect(not world.continue_journey() and not world.enter_next_chapter(),"final report does not invent chapter five")
	var disk=disk_snapshot()
	expect(same_json(disk.chapters["4"],fourth),"existing fourth archived record survives disk serialization")
	await reload(4)
	expect(same_json(world.state.run_snapshot(),fourth) and same_earlier(previous),"existing fourth state survives new-Campaign reload")

func fourth_picker(node: Node):
	if node is OptionButton and node.item_count==4 and node.get_item_text(3).contains("陈仓"): return node
	for child in node.get_children():
		var found=fourth_picker(child)
		if found: return found
	return null

func independent_replay() -> void:
	completed_third(); var previous=earlier_records()
	world.title_screen(); await settle(); var picker=fourth_picker(world.ui.overlay)
	expect(picker!=null,"title offers all four real chapter choices")
	if picker:
		picker.selected=3; picker.item_selected.emit(3)
		var begin=button_named(world.ui.overlay,"开始所选章节")
		expect(begin!=null,"independent fourth start button exists")
		if begin: begin.emit_signal("pressed")
	await settle()
	expect(world.state.chapter==4 and world.stage=="cc_outer" and world.mode=="dialog","title independently opens fourth-chapter introduction")
	expect(world.state.flags.sword and not world.state.complete and same_earlier(previous),"independent start equips Qinggang and preserves earlier records")
	world.choose_route("continue")
	for key in ["cc_breach","cc_beacon_out","cc_route_front","cc_street_done","cc_warehouse","cc_courtyard","cc_committed","cc_boss"]: world.state.flags[key]=true
	world.state.history=["待重玩的第四章战报。"]
	world.enter_stage("cc_final",Vector2(1110,500),false); world.mode="playing"
	world.state.checkpoint={"stage":"cc_final","x":1110.0,"y":500.0,"encounter":""}
	expect(world.finish(),"production fourth report offers replay")
	var replay=button_named(world.ui.overlay,"重玩这一章"); expect(replay!=null,"explicit fourth replay button exists")
	if replay: replay.emit_signal("pressed")
	expect(text_tree(world.ui.overlay).contains("其他章节的记录会保留"),"replay explains chapter-local scope")
	var confirm=button_named(world.ui.overlay,"开始新征程")
	if confirm: confirm.emit_signal("pressed")
	await settle()
	expect(world.state.chapter==4 and world.stage=="cc_outer" and not world.state.complete,"confirmed replay resets only fourth chapter")
	var any_progress=false
	for key in Campaign.CHENCANG_FLAGS: any_progress=any_progress or world.state.flags[key]
	expect(not any_progress and world.state.history.is_empty() and same_earlier(previous),"replay clears all fourth flags and leaves previous three records unchanged")
	expect(world.state.rewards.huilan,"replaying fourth retains account-wide Huilan reward")
	disk_snapshot()

func legacy_fourth_fields() -> void:
	completed_third(); var old=world.state.snapshot().duplicate(true)
	for key in Campaign.CHENCANG_FLAGS: old.flags.erase(key)
	for record in old.chapters.values():
		for key in Campaign.CHENCANG_FLAGS: record.flags.erase(key)
	save_disk(old,world.state.save_path); await reload(3)
	expect(world.mode=="ending" and not world.state.flags.cc_breach and not world.state.flags.cc_boss,"old v2 third report without CC fields restores conservative defaults")
	world.ui.first_choice.emit_signal("pressed"); world.ui.first_choice.emit_signal("pressed"); await settle()
	expect(world.state.chapter==4 and world.stage=="cc_outer","old third report can enter new fourth chapter")
	disk_snapshot()
	# First-generation v1 has none of the later chapter flag families.
	var legacy=world.state.chapter_record(1).duplicate(true); legacy.merge({"version":1,"engine":"godot"})
	for key in Campaign.HANSHUI_FLAGS+Campaign.JIGU_FLAGS+Campaign.CHENCANG_FLAGS: legacy.flags.erase(key)
	legacy.erase("battle_art"); legacy.erase("tactics")
	save_disk(legacy,world.state.save_path); await reload(1)
	expect(world.state.complete and world.mode=="ending" and world.state.chapter==1,"original v1 remains readable after fourth-chapter expansion")
	expect(not world.state.flags.cc_breach and not world.state.flags.cc_boss and not world.state.rewards.huilan,"v1 migration never fabricates fourth progress or rewards")

func invalid_contracts() -> void:
	var state=Campaign.new(); state.reset("normal",4); var clean=state.snapshot()
	expect(Campaign.valid(clean),"fresh fourth chapter validates")
	for flag in Campaign.CHENCANG_FLAGS:
		var bad=clean.duplicate(true); bad.flags[flag]="yes"
		expect(not Campaign.valid(bad),"every fourth flag requires boolean: "+flag)
	for key in ["cc_beacon_out","cc_orders","cc_route_front","cc_route_flank","cc_street_done","cc_reserve_called","cc_warehouse","cc_workers","cc_courtyard","cc_committed","cc_boss"]:
		var bad=clean.duplicate(true); bad.flags[key]=true
		var restored=Campaign.new(); var before=restored.snapshot().duplicate(true)
		expect(not Campaign.valid(bad) and not restored.restore(bad) and restored.snapshot()==before,"unearned "+key+" rejected atomically")
	for key in ["cc_breach","cc_beacon_out","cc_route_front","cc_street_done","cc_warehouse","cc_courtyard","cc_committed","cc_boss"]: state.flags[key]=true
	state.complete=true; state.checkpoint={"stage":"cc_final","x":1110.0,"y":500.0,"encounter":""}
	var completed=state.snapshot(); expect(Campaign.valid(completed),"completed fourth fixture validates")
	var bad=completed.duplicate(true); bad.flags.cc_route_flank=true
	expect(not Campaign.valid(bad),"two selected routes are invalid")
	bad=completed.duplicate(true); bad.flags.cc_boss=false
	expect(not Campaign.valid(bad),"completion requires actual fourth boss flag")
	for encounter in ["vanguard","dujun","warden"]:
		bad=completed.duplicate(true); bad.checkpoint.encounter=encounter
		expect(not Campaign.valid(bad),"completed report rejects stale or foreign encounter "+encounter)
	bad=completed.duplicate(true); bad.checkpoint.stage="jg_final"
	expect(not Campaign.valid(bad),"fourth save rejects another chapter's region")
	bad=completed.duplicate(true); bad.chapters["5"]=bad.chapters["4"].duplicate(true)
	expect(not Campaign.valid(bad),"v2 rejects nonexistent fifth chapter")
	bad=completed.duplicate(true); bad.chapters["4"].flags.cc_courtyard=false
	expect(not Campaign.valid(bad),"invalid fourth archive is rejected even when active data is valid")
	bad=clean.duplicate(true); bad.checkpoint={"stage":"cc_final","x":900.0,"y":500.0,"encounter":"warden"}
	expect(not Campaign.valid(bad),"unconfirmed boss encounter cannot be restored")

func run() -> void:
	original_files=fingerprints()
	world=TestWorld.new(); world.test_mode=true
	world.state.save_path="user://longdan-chencang-campaign-empty-"+str(OS.get_process_id())+".json"
	root.add_child(world); world.set_physics_process(false); world.set_process(false); await settle()
	await fresh_transition("normal",true); await fresh_transition("story",false)
	await existing_transition(false); await existing_transition(true)
	await independent_replay(); await legacy_fourth_fields(); invalid_contracts()
	expect(fingerprints()==original_files,"ordinary player v1/v2 files are unchanged")
	world.queue_free(); await process_frame; await process_frame
	for path in files:
		if FileAccess.file_exists(path): DirAccess.remove_absolute(path)
		if FileAccess.file_exists(path+".tmp"): DirAccess.remove_absolute(path+".tmp")
	print("CHENCANG_CAMPAIGN_VERIFY ",checks," checks; ",failures.size()," failures")
	quit(0 if failures.is_empty() else 1)
