extends "res://tests/combat_loop_verify.gd"
## Real buffered input, hitboxes and PCM routing. No player saves or GPU.
const AudioChecks = preload("res://tests/audio_verify.gd")

func reset_sample() -> void:
	isolate()
	world.fx.entries.clear(); world.fx.labels.clear(); world.hit_stop=0
	world.sound.last_contact.clear()
	for channel in world.sound.channels: channel.stop(); channel.stream=null

func contacts() -> Array:
	return world.fx.entries.filter(func(entry): return entry.type=="contact")

func contact_voices() -> int:
	var count=0
	for channel in world.sound.channels:
		for key in world.sound.cache:
			if str(key).begins_with("contact_") and channel.stream==world.sound.cache[key]: count+=1
	return count

func select_attack(key: String) -> void:
	if key=="thrust3": hero.combo=2; hero.combo_left=1
	if key=="counter": hero.counter_left=1
	hero.request("sweep" if key=="sweep" else "attack",Vector2.ZERO,0)

func run() -> void:
	AudioServer.add_bus()
	var audio_bus=AudioServer.bus_count-1
	AudioServer.set_bus_name(audio_bus,"SilentFeedbackQA"); AudioServer.set_bus_mute(audio_bus,true)
	world=Game.new(); world.test_mode=true; world.state=MemoryCampaign.new(); root.add_child(world)
	world.set_process(false); world.set_physics_process(false)
	await settle(); hero=world.hero
	for channel in world.sound.channels: channel.bus="SilentFeedbackQA"
	world.sound.footstep_channel.bus="SilentFeedbackQA"
	# World.test_mode intentionally starts muted; enable its production route
	# only after every player has been moved to the inaudible QA bus.
	world.sound.muted=false
	var definitions=world.attacks.duplicate(true)

	# Both ordinary physics rates and one long frame must preserve the same
	# accepted deliberate tap. The following action is started once only.
	for step in [1.0/30,1.0/60,1.0/120,.2]:
		reset_sample(); select_attack("thrust1")
		var d=hero.action.def
		hero.action.t=d.windup+d.active+d.recovery-.06
		expect(hero.request("attack",Vector2.ZERO,0),"late combo tap accepted at step "+str(step))
		for tick in range(30):
			hero.advance(step,Vector2.ZERO,false,INF)
			if hero.action.get("key","")=="thrust2": break
		expect(hero.action.get("key","")=="thrust2" and hero.buffer.is_empty(),"late combo is consumed once across ready boundary at "+str(step))
		expect(hero.combo==2,"queued tap does not repeat into a third attack at "+str(step))
	reset_sample(); select_attack("thrust1")
	hero.action.t=hero.action.def.windup+hero.action.def.active-.06; hero.qi=20
	expect(hero.request("dash",Vector2.LEFT,0),"late active-window dodge is accepted")
	expect(not hero.request("sweep",Vector2.ZERO,0) and hero.buffer.get("kind","")=="dash","no-qi Q preserves queued dodge")
	hero.advance(.10,Vector2.RIGHT,true,0)
	expect(hero.dash_left>0 and absf(angle_difference(hero.dash_dir,PI))<.001,"held J cannot steal buffered left dodge")
	expect(hero.action.is_empty() and hero.buffer.is_empty(),"dodge takes over only after the active strike ends")

	# If cooldown ends inside a strike's active window, wait for its end. The
	# native attack still hits; a dash must never erase an unpaid active frame.
	reset_sample(); var target=spawn(); await settle(); select_attack("thrust1")
	hero.action.t=.06; hero.dash_cd=.07
	expect(hero.request("dash",Vector2.LEFT,0),"cooldown/active overlap can queue its first legal boundary")
	hero.advance(.16,Vector2.ZERO,false,0)
	expect(target.hp==target.max_hp-25 and hero.dash_left>0,"queued dodge preserves real strike damage before canceling recovery")
	reset_sample(); select_attack("thrust1")
	hero.action.t=.30; hero.request("attack",Vector2.ZERO,0); hero.buffer.left=.03
	hero.advance(.2,Vector2.ZERO,false,0)
	expect(hero.action.is_empty() and hero.buffer.is_empty() and hero.combo==1,"already-expired input cannot revive at a later ready point")
	reset_sample(); hero.dash_cd=.08; var start=hero.position
	expect(hero.request("dash",Vector2.RIGHT,0),"dodge can queue near cooldown completion")
	hero.advance(.12,Vector2.ZERO,false,0)
	expect(absf(hero.position.distance_to(start)-555*.04)<.01,"cooldown-buffered dodge moves only after its actual ready boundary")
	reset_sample(); hero.sweep_cd=.08
	hero.request("sweep",Vector2.ZERO,0); hero.advance(.12,Vector2.ZERO,false,0)
	expect(hero.action.get("key","")=="sweep" and is_equal_approx(hero.action.t,.04),"cooldown-buffered Q cannot borrow the earlier frame's windup time")

	reset_sample(); select_attack("thrust1"); hero.action.t=.36
	hero.request("attack",Vector2.ZERO,0)
	var left=float(hero.buffer.left); var time=float(hero.action.t)
	world.hit_stop=.06; world._physics_process(.03)
	expect(is_equal_approx(hero.buffer.left,left) and is_equal_approx(hero.action.t,time),"real world hit-stop freezes both animation time and accepted buffer")
	world.pause("pause")
	expect(hero.buffer.is_empty(),"pause discards pending deliberate input")
	world.resume(); hero.advance(.2,Vector2.ZERO,false,0)
	expect(hero.combo==1,"resuming cannot replay the cleared buffer")

	# Every style below comes through real Hero.attack_hits and Enemy.take_hit.
	for row in [["thrust1","sword","light"],["thrust3","sword","heavy"],["counter","sword","counter"],["thrust1","shield","guard"],["sweep","shield","break"]]:
		reset_sample(); var enemy=spawn(row[1]); enemy.facing=PI; await settle()
		select_attack(row[0]); hero.advance_action(hero.action.def.windup+.025)
		var marks=contacts()
		expect(enemy.hp<enemy.max_hp,"real contact damages target for "+row[2])
		expect(marks.size()==1 and marks[0].info.style==row[2],"actual hit produces one "+row[2]+" mark")
		expect(world.fx.entries.filter(func(entry): return entry.type=="impact").is_empty(),"new contact replaces generic duplicate impact for "+row[2])
		expect(contact_voices()==1,"one contact audio voice for "+row[2])
		if row[2]=="break":
			var damage_labels=world.fx.labels.filter(func(entry): return entry.text=="42")
			expect(enemy.combat_status()=="shield" and damage_labels.size()==1,"real shield break keeps persistent status and one damage number")
			expect(world.fx.labels.filter(func(entry): return entry.text=="破盾").is_empty(),"persistent shield plate replaces duplicate break shout")
			if damage_labels.size()==1:
				var bounds=world.fx.floater_bounds(damage_labels[0].pos,damage_labels[0].text)
				expect(not bounds.intersects(world.fx.enemy_header_bounds(enemy).grow(3)),"real Q damage number clears shield plate and HP band")
		if row[2]=="guard":
			var text_labels=world.fx.labels.filter(func(entry): return entry.text in ["盾挡","6"])
			expect(text_labels.size()==2,"guard cue and reduced damage remain separately readable")
			if text_labels.size()==2:
				expect(not world.fx.floater_bounds(text_labels[0].pos,text_labels[0].text).intersects(world.fx.floater_bounds(text_labels[1].pos,text_labels[1].text)),"same-contact shield and damage labels do not overlap")
			var labels_before=world.fx.labels.size(); world.fx.floater(enemy.position,"盾挡")
			expect(world.fx.labels.size()==labels_before,"near-simultaneous duplicate guard text is suppressed")
		hero.advance_action(.02)
		expect(contacts().size()==1 and contact_voices()==1,"same hitbox cannot replay contact across active frames for "+row[2])
	reset_sample(); select_attack("thrust3"); hero.advance_action(.4)
	expect(contacts().is_empty() and contact_voices()==0,"empty heavy swing has a whoosh but no contact or impact audio")
	reset_sample(); var first=spawn(); spawn("sword",Vector2(945,920)); spawn("sword",Vector2(955,880)); await settle()
	select_attack("sweep"); hero.advance_action(.22)
	expect(contacts().size()==3 and contact_voices()==1,"three hitboxes create three local marks but only one primary voice")
	reset_sample(); var guard=spawn("shield"); guard.facing=PI; var poised=spawn(); poised.stagger=poised.stagger_max-1; await settle()
	select_attack("thrust1")
	guard.take_hit(25,0,0,"player",10)
	poised.take_hit(25,0,0,"player",10)
	expect(contacts().size()==2 and contacts()[0].info.style=="guard" and contacts()[1].info.style=="break","a later poise break upgrades a preceding guard contact")
	expect(contact_voices()==2 and hero.action.get("contact_upgraded",false),"one action permits one meaningful contact upgrade")
	var count=contacts().size(); hero.contact_feedback(guard,0,0,false,false,false,false)
	expect(contacts().size()==count,"zero-damage callbacks create no false hit confirmation")
	world.fx.soft=true; hero.contact_feedback(guard,0,1,false,false,false,false)
	expect(contacts().size()==count+1,"soft-effects mode retains meaningful contact confirmation")
	world.fx.soft=false
	reset_sample(); var ally_target=spawn(); await settle()
	ally_target.take_hit(5,0,0,"ally",1)
	expect(ally_target.hp==ally_target.max_hp-5 and contacts().is_empty() and contact_voices()==0,"ally damage retains its quieter path without player contact effects")
	ally_target.take_hit(5,0,0,"environment",1)
	expect(contacts().is_empty() and world.fx.entries.filter(func(entry): return entry.type=="impact").size()==1,"environment damage keeps its existing non-player impact")

	# Silence the actual AudioStreamPlayers while measuring their source PCM.
	var audio_checks=AudioChecks.new(); var hashes: Dictionary={}
	for key in ["contact_light","contact_heavy","contact_counter","contact_guard","contact_break"]:
		var stream=world.sound.cache[key]; var stats=audio_checks.statistics(stream)
		hashes[stream.data.hex_encode().sha256_text()]=true
		expect(stream.data.decode_s16(0)==0 and abs(stream.data.decode_s16(stream.data.size()-2))<16,"contact cue has no edge click: "+key)
		expect(stats.rms>.003 and stats.rms<.13,"contact signal is present and below aggressive noise level: "+key)
		var maximum=0
		for i in range(stream.data.size()/2): maximum=maxi(maximum,absi(stream.data.decode_s16(i*2)))
		expect(maximum<15000,"contact cue stays below half-scale PCM peak: "+key)
	expect(hashes.size()==5,"five cues have genuinely different PCM")
	world.sound.last_contact.clear()
	expect(world.sound.play_contact("contact_light") and not world.sound.play_contact("contact_light"),"duplicate same-frame contact voices are suppressed")
	expect(world.sound.play_contact("contact_break"),"a guard-break accent remains available after a light contact")
	world.sound.muted=true
	expect(not world.sound.play_contact("contact_heavy"),"muting also blocks contact feedback")
	reset_sample(); hero.facing=0; hero.request("dash",Vector2.RIGHT,0); hero.update_visual()
	world.fx.ghost(hero)
	var ghost=world.fx.entries.back(); var mesh: Mesh=ghost.info.get("mesh")
	expect(mesh!=null and ghost.type=="ghost","dash afterimage captures the actual articulated mesh")
	if mesh:
		var captured=mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX].duplicate()
		hero.position+=Vector2(20,0); hero.walk_distance+=28; hero.update_visual()
		expect(mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]==captured,"moving hero cannot deform an already captured afterimage")
		var saved_position=ghost.info.transform.origin
		expect(saved_position.distance_to(hero.position)>10,"afterimage retains its captured world position")
	world.fx.soft=true; var effects_before=world.fx.entries.size(); world.fx.ghost(hero)
	expect(world.fx.entries.size()==effects_before,"soft-effects mode avoids mesh afterimage allocation")
	expect(world.attacks==definitions,"input and presentation changes never rewrite attack definitions")
	print("COMBAT_FEEDBACK_VERIFY ",checks," checks; ",failures.size()," failures")
	audio_checks.free(); world.queue_free(); await process_frame; await process_frame
	await create_timer(.12).timeout; AudioServer.remove_bus(audio_bus)
	quit(0 if failures.is_empty() else 1)
