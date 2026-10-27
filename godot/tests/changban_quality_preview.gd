extends "res://tests/map_identity_preview.gd"
## Eleven explicitly staged production scenes. No player input, saves or
## automatic battle stepping; accelerated defeats are labeled in the manifest.
const NAMES=["opening","third-thrust","shield-break","precision-counter","village-before","village-after","temple-sword","house-rescue","fork-before","fork-after","zhanghe-phase2"]
var quality_draws=0

func observe_render() -> void: quality_draws+=1

func camera_at(at: Vector2) -> void:
	world.camera.position=at; world.camera.zoom=Vector2.ONE*1.15
	world.camera.reset_smoothing(); world.camera.force_update_scroll()

func scene(id: String, at: Vector2, live_groups: Array=[], flags: Dictionary={}) -> void:
	world.detach_tactics(false); world.state.reset("normal",1); world.load_chapter(1)
	var index=Campaign.CHAPTER_STAGES[1].find(id)
	world.state.flags.mountain=index>0
	if index>=3: world.state.flags.temple=true; world.state.flags.sword=true
	if index>=4:
		world.state.flags.adou=true; world.state.flags.house=true; world.state.flags.motherDecision=true
	if id=="bridge": world.state.flags.committed=true
	for key in flags: world.state.flags[key]=flags[key]
	for group in world.definitions[id].groups:
		if str(group.id) not in live_groups: world.state.cleared.append(id+":"+str(group.id))
	world.mode="playing"; world.hero.reset_combat(); world.chapter_direction.reset()
	world.enter_stage(id,at,false); world.ui.hide_overlay(); world.clear_input()
	requested_hero=at; ensure_safe_feet(id)
	world.state.checkpoint={"stage":id,"x":world.hero.position.x,"y":world.hero.position.y,"encounter":""}
	world.hero.facing=-PI/4; world.hero.update_visual(); camera_at(world.hero.position)
	world.chapter_presentation.advance(.4); world.ui.refresh(.4)
	await process_frame; await physics_frame; await physics_frame
	expect(Campaign.valid(world.state.snapshot()),id+" fixture has valid campaign state")

func pair(kind: String) -> Variant:
	var origin: Vector2=world.hero.position
	for offset in [Vector2.ZERO,Vector2(0,-80),Vector2(-80,0),Vector2(0,80)]:
		var at=origin+offset; var target=at+Vector2(85,0)
		if world.terrain.blocked(at,16) or world.terrain.blocked(target,16) or not world.terrain.line_clear(at,target,0): continue
		world.hero.position=at; world.hero.facing=0; requested_hero=at
		var enemy=world.spawn_enemy(kind,target,"quality-contact"); enemy.facing=PI; enemy.update_visual()
		camera_at(at+Vector2(45,-25)); await physics_frame; await physics_frame
		return enemy
	expect(false,"no clear native contact pair near fixture origin")
	return null

func near_object(id: String) -> void:
	var object=world.object_by_id(id); expect(not object.is_empty(),"authored object "+id+" exists")
	if object.is_empty(): return
	world.hero.position=Vector2(object.x,object.y)+Vector2(0,42); requested_hero=world.hero.position
	ensure_safe_feet(id); world.hero.update_visual()
	expect(world.hero.position.distance_to(Vector2(object.x,object.y))<100,id+" is within real E distance")

func defeat_group(group: String) -> void:
	for enemy in world.enemies.duplicate():
		if enemy.body_alive() and (group.is_empty() or enemy.group_id==group):
			enemy.take_hit(enemy.hp+1000,0,0,"player",0,true)

func end_dialogue() -> void:
	if world.mode=="dialog": world.choose_route("continue")

func advance_presentation(seconds: float) -> void:
	world.chapter_presentation.advance(seconds); world.chapter_direction.advance(seconds)
	world.ui.refresh(.4)

func capture(name: String, scenario: String="controlled production fixture") -> void:
	if not ensure_safe_feet(name): return
	# Frozen capture fixtures do not get the normal Enemy.advance. Finish a
	# short real death animation for accelerated defeats, then refresh every
	# enemy pose so a dead officer cannot remain standing in an after-shot.
	for enemy in world.enemies:
		if not is_instance_valid(enemy): continue
		if enemy.hp<=0 and enemy.dead_time<.72: enemy.advance(.72-enemy.dead_time)
		enemy.update_visual()
	world.hero.update_visual(); world.ui.refresh(.016); world.fx.queue_redraw()
	world.camera.force_update_scroll()
	await create_timer(.18).timeout; await process_frame; await process_frame
	await physics_frame
	var before_draw=quality_draws; var wait_started=Time.get_ticks_msec()
	while quality_draws==before_draw and Time.get_ticks_msec()-wait_started<5000: await process_frame
	if quality_draws==before_draw:
		expect(false,name+" had no rendered frame within five seconds; check minimized window"); return
	var physical=native_feet_clear(); var clear=not world.terrain.blocked(world.hero.position,world.hero.radius)
	expect(physical and clear,name+" real feet collision clear")
	var path=ProjectSettings.globalize_path("res://../.qa/changban-quality-"+label+"-"+name+".png")
	if FileAccess.file_exists(path): expect(false,"refusing existing capture "+path); return
	expect(root.get_texture().get_image().save_png(path)==OK,"saved "+name)
	var marks: Array=[]
	for effect in world.fx.entries:
		if effect.type=="contact": marks.append(str(effect.info.style))
	var gains: Array=[]
	for emitter in world.chapter_presentation.emitters: gains.append({"kind":emitter.kind,"gain":emitter.gain})
	var boss_info={}
	if is_instance_valid(world.boss): boss_info={"id":world.boss.boss_id,"phase2":world.boss.phase2,"attack":world.boss.action.get("def",{}).get("name","")}
	captured.append({"name":name,"scenario":scenario,"image":path,"stage":world.stage,"mode":world.mode,
		"hero":[world.hero.position.x,world.hero.position.y],"requested_hero":[requested_hero.x,requested_hero.y],
		"feet_clear":clear,"physical_feet_clear":physical,"valid_campaign":Campaign.valid(world.state.snapshot()),
		"hero_action":world.hero.action.get("key",""),"contact_styles":marks,"precision_count":world.state.precision_count,
		"scene_stamp":world.ui.scene_heading.text if world.ui.scene_stamp.visible else "",
		"flags":world.state.flags.duplicate(),"presentation_gains":gains,"boss":boss_info,
		"camera":[world.camera.get_screen_center_position().x,world.camera.get_screen_center_position().y],"zoom":1.15,"viewport":[1280,720],"window_mode":DisplayServer.window_get_mode(),"focused":root.has_focus(),"rendered_frames":quality_draws})
	print("CHANGBAN_QUALITY_CAPTURE ",name," ",path)

func run() -> void:
	if DisplayServer.get_name()=="headless": push_error("Quality preview requires graphical rendering; use --check-only to parse."); quit(1); return
	label=""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--label="): label=arg.trim_prefix("--label=")
	var valid=RegEx.new(); valid.compile("^[A-Za-z0-9][A-Za-z0-9_-]{0,63}$")
	if valid.search(label)==null: push_error("Supply a fresh plain --label."); quit(1); return
	var manifest=ProjectSettings.globalize_path("res://../.qa/changban-quality-"+label+"-manifest.json")
	if FileAccess.file_exists(manifest): push_error("Refusing existing quality manifest."); quit(1); return
	for name in NAMES:
		if FileAccess.file_exists(ProjectSettings.globalize_path("res://../.qa/changban-quality-"+label+"-"+name+".png")):
			push_error("Refusing a partially used quality label."); quit(1); return
	root.size=Vector2i(1280,720)
	RenderingServer.frame_post_draw.connect(observe_render)
	world=Game.new(); world.test_mode=true; world.state=MemoryCampaign.new(); root.add_child(world)
	world.set_process(false); world.set_physics_process(false); world.set_process_input(false)
	world.set_process_unhandled_input(false); world.set_process_unhandled_key_input(false)
	if root.focus_exited.is_connected(world.on_focus_lost): root.focus_exited.disconnect(world.on_focus_lost)
	await process_frame
	await scene("mountain",Vector2(320,895),["m1","m2","m3"])
	expect(world.ui.scene_stamp.visible and world.ui.scene_stamp.modulate.a>.5,"opening stamp actually visible")
	await capture("opening","production entry stamp at .4 seconds; authored first encounters remain alive")
	await scene("mountain",Vector2(850,900)); var enemy=await pair("sword")
	if is_instance_valid(enemy):
		world.hero.combo=2; world.hero.combo_left=1; world.hero.request("attack",Vector2.ZERO,0)
		world.hero.advance_action(world.hero.action.def.windup+.025)
		expect(enemy.hp==enemy.max_hp-40,"third thrust produces its authored real damage")
		await capture("third-thrust","real third thrust and contact, no damage/timing override")
	await scene("mountain",Vector2(850,900)); enemy=await pair("shield")
	if is_instance_valid(enemy):
		world.hero.request("sweep",Vector2.ZERO,0); world.hero.advance_action(world.hero.action.def.windup+.025)
		expect(enemy.shield_broken>0 and enemy.hp==enemy.max_hp-42,"real Q breaks the facing shield")
		await capture("shield-break","real Q shield break with local confirmation and authored cost")
	await scene("mountain",Vector2(850,900)); enemy=await pair("sword")
	if is_instance_valid(enemy):
		enemy.start_action(world.hero); world.hero.invincible=0; world.hero.request("dash",Vector2.UP,0)
		enemy.advance_action(enemy.action.def.windup+.02,world.hero)
		expect(world.state.precision_count==1 and world.hero.hp==world.hero.max_hp,"actual enemy attack meets legitimate early dodge window")
		world.hero.advance(.23,Vector2.ZERO,false,0); world.hero.request("attack",Vector2.ZERO,0)
		expect(world.hero.action.get("key","")=="counter","precision opens actual counter action")
		world.hero.advance_action(world.hero.action.def.windup+.02)
		await capture("precision-counter","real early dodge against native enemy attack followed by counter; manually advanced scenario time")
	await scene("village",Vector2(520,570),["vRescue"]); camera_at(Vector2(500,470))
	await capture("village-before","authored rescue guards and local smoke before the actual rescue interaction")
	defeat_group("vRescue"); world.fx.entries.clear(); world.fx.labels.clear(); near_object("civilians")
	expect(world.interact(),"actual E opens rescued villagers dialogue"); end_dialogue(); advance_presentation(1.5)
	expect(world.state.flags.civilians and world.state.flags.healer,"production rescue sets both flags")
	camera_at(Vector2(500,470)); await capture("village-after","same camera after accelerated guard defeats and real E; smoke and relief follow saved flags")
	await scene("temple",Vector2(950,550)); world.begin_boss("xiahou")
	world.boss.take_hit(world.boss.hp+1000,0,0,"player",0,true); end_dialogue()
	world.fx.entries.clear(); world.fx.labels.clear(); advance_presentation(1.0)
	expect(world.state.flags.temple and world.state.flags.sword,"real boss defeat grants sword and stage flag")
	camera_at(Vector2(950,520)); await capture("temple-sword","accelerated production Xiahou defeat; real sword reward and local altar response")
	await scene("house",Vector2(1030,590),[],{"healer":true,"civilians":true})
	near_object("adou"); expect(world.interact(),"real Adou interaction starts choice")
	world.choose_route("rescue"); world.hero.position=Vector2(1040,640); requested_hero=world.hero.position
	expect(not world.rescue.is_empty() and world.rescue.wave==1,"actual healer rescue first wave exists")
	advance_presentation(.6); camera_at(Vector2(1070,525)); await capture("house-rescue","real rescue choice, healer and three first-wave enemies; no rescue completion shortcut")
	await scene("fork",Vector2(1190,850)); near_object("supplies")
	expect(world.interact() and world.group_alive("elite"),"real supply interaction spawns guarding officer")
	camera_at(Vector2(1150,720)); await capture("fork-before","supply compound and real officer before burning; prior normal guards pre-cleared in fixture")
	defeat_group("elite"); world.fx.entries.clear(); world.fx.labels.clear(); near_object("supplies")
	expect(world.interact() and world.state.flags.supplies,"real E ignites supplies after officer defeat")
	advance_presentation(1.7); camera_at(Vector2(1150,720)); await capture("fork-after","same camera after accelerated officer defeat and actual E burning event")
	await scene("bridge",Vector2(900,600),[],{"supplies":true}); world.begin_boss("zhanghe")
	world.boss.hp=world.boss.max_hp*.49; world.boss.advance(.01)
	expect(world.boss.phase2 and world.boss.phase_time>0,"native half-health transition occurs")
	# Choose the authored fourth pattern only after the real phase transition;
	# this is a pose fixture, not a performance/balance run.
	world.boss.advance(1.4); world.boss.action={}; world.boss.sequence=[]; world.boss.attack_count=3; world.boss.cooldown=0
	world.boss.start_action(world.hero); world.boss.advance_action(world.boss.action.def.windup*.62,world.hero)
	world.boss.update_visual(); world.fx.advance(.1); camera_at(Vector2(930,475))
	expect(not world.boss.action.is_empty() and world.boss.action.t<world.boss.action.def.windup,"phase-two red warning is still in real windup")
	await capture("zhanghe-phase2","native half-health transition then selected authored phase-two pattern at windup; controlled pose")
	expect(captured.size()==NAMES.size(),"all eleven scenarios captured")
	var file=FileAccess.open(manifest,FileAccess.WRITE); expect(file!=null,"manifest writable")
	if file:
		file.store_string(JSON.stringify({"label":label,"captures":captured,"failures":failures,"renderer":RenderingServer.get_video_adapter_name(),"player_saves":"MemoryCampaign: no reads or writes","scope":"Controlled production scenes with explicit initial progress and accelerated defeats. Not a manual playthrough or duration claim."},"  ",true)); file.close()
	print("CHANGBAN_QUALITY_PREVIEW ",captured.size()," captures; ",failures.size()," failures")
	world.queue_free(); await process_frame; quit(0 if failures.is_empty() else 1)
