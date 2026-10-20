extends SceneTree
## Camp decisions and chapter-local builds use production UI/state, not player saves.
const Game=preload("res://scripts/world.gd")
const Campaign=preload("res://scripts/campaign.gd")
class MemoryCampaign extends Campaign:
	func read_save() -> Dictionary: return last_save.duplicate(true)
	func save() -> bool:
		last_save=snapshot(); return true
var checks=0
var failures=[]
var world

func _initialize() -> void: call_deferred("run")
func expect(value: bool, label: String) -> void:
	checks+=1
	if not value: failures.append(label); push_error("BATTLE_ART: "+label)

func run() -> void:
	world=Game.new(); world.test_mode=true; world.state=MemoryCampaign.new()
	root.add_child(world); world.set_process(false); world.set_physics_process(false)
	await process_frame
	# Exercise the save call path; the injected campaign can only save in memory.
	world.test_mode=false
	var state=world.state
	var old=state.snapshot()
	old.erase("battle_art"); old.chapters["1"].erase("battle_art")
	expect(Campaign.valid(old) and state.restore(old) and state.battle_art=="","older v2 saves load with the base style")
	var corrupt=state.snapshot(); corrupt.battle_art="unlimited"
	expect(not Campaign.valid(corrupt),"unknown style cannot enter runtime")
	corrupt=state.snapshot(); corrupt.chapters["1"].battle_art=42
	expect(not Campaign.valid(corrupt),"nested non-string style is rejected")
	for chapter in [1,2]:
		world.load_chapter(chapter); state.reset("normal",chapter)
		var stage="mountain" if chapter==1 else "hs_forest"
		for group in world.definitions[stage].groups: state.cleared.append(stage+":"+str(group.id))
		world.mode="playing"; world.hero.reset_combat(); world.enter_stage(stage,Vector2.INF,false); world.ui.hide_overlay()
		await process_frame; await physics_frame
		var camp={}
		for object in world.definition.objects:
			if object.kind=="camp": camp=object; break
		world.hero.position=Vector2(camp.x,camp.y)
		world.hero.hp=60; world.hero.qi=10; world.hero.potions=0; world.hero.spear_spirit=3
		world.keyboard_attack_held=true
		expect(world.interact() and world.mode=="camp","safe camp opens actual loadout panel in chapter "+str(chapter))
		expect(world.hero.hp==world.hero.max_hp and world.hero.potions==3 and world.hero.spear_spirit==0,"rest refills resources but never gives a free empowered attack")
		expect(not world.keyboard_attack_held,"camp clears held combat input")
		expect(is_instance_valid(world.ui.first_choice) and world.ui.first_choice.text.contains("继续前行"),"camp has an explicit keyboard-friendly exit")
		expect(not world.choose_battle_art("unknown") and world.mode=="camp","invalid camp choice does not close or change loadout")
		var before=state.time
		world._physics_process(.5)
		expect(state.time==before,"loadout selection freezes combat and encounter clocks")
		var id="assault" if chapter==1 else "counter"
		var choice_button: Button
		for candidate in world.ui.overlay.find_children("*","Button",true,false):
			if candidate.text.contains(state.BATTLE_ARTS[id].name+" ·"): choice_button=candidate; break
		expect(choice_button!=null,"camp renders the requested style button")
		if choice_button: choice_button.pressed.emit()
		expect(state.battle_art==id and world.mode=="playing","real camp button equips its own style and resumes")
		expect(state.last_save.get("battle_art","")==id,"chosen style is saved immediately")
		expect(not world.choose_battle_art("counter" if chapter==1 else "assault") and state.battle_art==id,"cannot swap a style during combat")
		world.hero.spear_spirit=3
		world.enter_stage(stage,Vector2.INF,false)
		expect(world.hero.spear_spirit==0 and state.battle_art==id,"zone entry clears short-term meter but retains chosen build")
		world.hero.position=Vector2(camp.x,camp.y); world.interact()
		var esc=InputEventKey.new(); esc.keycode=KEY_ESCAPE; esc.pressed=true
		world._unhandled_input(esc)
		expect(world.mode=="playing" and state.battle_art==id,"Escape exits rest without discarding the style")
		world.hero.hp=0; world.mode="playing"; world.defeat("test","test"); world.retry()
		expect(state.battle_art==id and world.hero.spear_spirit==0,"death/retry keeps build but resets meter")
	# Actual disk roundtrip uses an explicit QA path, including JSON's float numbers.
	var disk=Campaign.new()
	disk.save_path=ProjectSettings.globalize_path("res://../.qa/battle-art-save.json")
	disk.reset("normal",1); disk.battle_art="assault"
	expect(disk.save(),"style can be written through atomic save")
	var reopened=Campaign.new(); reopened.save_path=disk.save_path
	expect(reopened.restore(reopened.read_save()) and reopened.battle_art=="assault","style survives a real disk reload")
	var failed=Campaign.new(); failed.save_path=ProjectSettings.globalize_path("res://../.qa/missing-art-directory/no-save.json")
	failed.battle_art="counter"
	expect(not failed.save() and not failed.durable,"failed style save reports non-durable progress")
	expect(failed.read_save().battle_art=="counter","failed write retains current-session choice")
	print("BATTLE_ART_VERIFY ",checks," checks; ",failures.size()," failures")
	world.queue_free(); await process_frame
	quit(0 if failures.is_empty() else 1)
