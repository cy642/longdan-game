extends SceneTree
## Run production nodes with real Godot physics, using an isolated test save.
const Game=preload("res://scripts/world.gd")
const Campaign=preload("res://scripts/campaign.gd")
const Scenery=preload("res://scripts/scenery.gd")
var world
var failures: Array=[]
var checks=0

func _initialize() -> void:
	call_deferred("run")

func expect(condition: bool,message: String) -> void:
	checks+=1
	if not condition: failures.append(message); push_error("FAIL: "+message)

func settle() -> void:
	await process_frame
	await physics_frame
	await physics_frame

func region(id: String,p: Vector2) -> void:
	world.mode="playing"; world.hero.reset_combat(); world.enter_stage(id,p,false); world.ui.hide_overlay()
	await settle()

func clear_enemies() -> void:
	for enemy in world.enemies: enemy.hp=0; enemy.collision_layer=0; enemy.action={}
	world.check_groups()

func texture_covers(texture: Texture2D, point: Vector2) -> bool:
	if texture is AtlasTexture: return Rect2(Vector2.ZERO, texture.get_size()).has_point(point)
	var arrays = texture.mesh.surface_get_arrays(0)
	var vertices = arrays[Mesh.ARRAY_VERTEX]; var indices = arrays[Mesh.ARRAY_INDEX]
	for i in range(0, indices.size(), 3):
		if Geometry2D.is_point_in_polygon(point, PackedVector2Array([Vector2(vertices[indices[i]].x, vertices[indices[i]].y), Vector2(vertices[indices[i+1]].x, vertices[indices[i+1]].y), Vector2(vertices[indices[i+2]].x, vertices[indices[i+2]].y)])): return true
	return false

func run() -> void:
	world=Game.new(); world.test_mode=true; root.add_child(world)
	world.set_physics_process(false); world.set_process(false)
	world.state.save_path="user://longdan-godot-test.json"
	await settle()
	expect(world.definitions.size()==6,"six regions imported")
	expect(world.hero.visual.frames.size()==5,"all character atlases are native resources")
	world.dialog("测试对白","握枪起身。",[{"text":"握枪起身","detail":"开始第一章","route":"continue"}],"赵云")
	await settle()
	expect(world.ui.first_choice.get_global_rect().size.y>=40 and world.ui.first_choice.get_global_rect().position.y<680,"dialogue choices have a visible layout")
	world.choose_route("continue")
	world.mode="playing"; world.ui.hide_overlay()
	var hero=world.hero
	var mouse_down=InputEventMouseButton.new(); mouse_down.button_index=MOUSE_BUTTON_LEFT; mouse_down.pressed=true
	world._unhandled_input(mouse_down); expect(world.mouse_attack_held,"only unhandled battlefield mouse down holds attack")
	var mouse_up=InputEventMouseButton.new(); mouse_up.button_index=MOUSE_BUTTON_LEFT; mouse_up.pressed=false
	world._input(mouse_up); expect(not world.mouse_attack_held,"mouse release over HUD clears held attack")
	world.mouse_attack_held=true; world.pause("pause")
	expect(not world.mouse_attack_held and hero.buffer.is_empty(),"pause clears combat input and buffered actions")
	world.resume(); hero.action={}
	# These pixels are from the neighboring upright spear inside the sideways frame.
	for index in [5, 13, 14, 15]:
		var meta = hero.visual.atlas_data.attack.frames[index]
		var hole = meta.exclude[0]
		expect(not texture_covers(hero.visual.frames.attack[index], Vector2(hole[0]+hole[2]*.5, hole[1]+hole[3]*.5)), "neighboring sprite is absent from attack frame " + str(index))
	expect(texture_covers(hero.visual.frames.attack[5], Vector2(242,134)), "side thrust retains its own connected spear head")
	expect(texture_covers(hero.visual.frames.attack[5], Vector2(92,85)), "side thrust retains Zhao Yun's face")
	for i in range(8):
		hero.facing=i*PI/4; hero.action={}; hero.update_visual(); var idle=hero.visual.body.texture
		var idle_meta=hero.visual.atlas_data.walk.frames[hero.visual.WALK[i]]
		expect(is_equal_approx(hero.visual.current_scale*idle_meta.head_height,26),"idle head scale direction "+str(i))
		hero.request("attack",Vector2.ZERO,hero.facing); hero.action.t=hero.action.def.windup+.01; hero.update_visual()
		expect(hero.visual.body.texture!=idle,"direction "+str(i)+" changes to a real attack pose")
		var index=hero.visual.STRIKE[i]; var meta=hero.visual.atlas_data.attack.frames[index]
		expect(is_equal_approx(hero.visual.current_scale*meta.head_height,26),"attack head scale direction "+str(i))
		expect(absf(hero.visual.body.position.y+meta.anchor[1]*hero.visual.current_scale)<.01,"attack feet anchor direction "+str(i))
		for phase in [hero.action.def.windup*.7, hero.action.def.windup+hero.action.def.active*.6, hero.action.def.windup+hero.action.def.active+hero.action.def.recovery*.4]:
			hero.action.t=phase; hero.update_visual()
			expect(hero.visual.position.is_zero_approx(), "boots and ground shadow stay together in direction " + str(i) + " phase " + str(phase))
	hero.action={}; hero.hp=100; hero.potions=3
	expect(hero.request("heal"),"medicine starts")
	hero.action.t=.94; hero.advance_action(.04)
	expect(is_equal_approx(hero.hp,185),"healing fires across a skipped active window")
	hero.advance_action(.03); expect(is_equal_approx(hero.hp,185),"medicine restores exactly once")
	hero.action={}; hero.hp=100; hero.invincible=0; hero.request("heal"); hero.take_damage(15,19)
	expect(hero.action.is_empty() and is_equal_approx(hero.hp,85),"damage interrupts medicine")
	hero.reset_combat(); hero.request("attack",Vector2.ZERO,0)
	hero.action.t=.01
	expect(not hero.request("attack",Vector2.ZERO,0),"early tap does not queue a free attack")
	hero.action.t=.34
	expect(hero.request("attack",Vector2.ZERO,0) and not hero.buffer.is_empty(),"late deliberate tap is buffered")
	hero.advance_action(.09); hero.consume_buffer(.02)
	expect(not hero.action.is_empty() and hero.action.key=="thrust2","buffer continues the combo once")
	hero.action.t=hero.action.def.windup+.01
	expect(not hero.perform("dash",Vector2.RIGHT,0),"active strike is not cancelled before its hit window")
	hero.action.t=hero.action.def.windup+hero.action.def.active+.01
	expect(hero.perform("dash",Vector2.RIGHT,0),"recovery allows responsive dodge cancel")
	var precision=world.state.precision_count; hero.take_damage(20,31); hero.take_damage(20,31)
	expect(world.state.precision_count==precision+1 and hero.hp==hero.max_hp,"precision dodge requires a real attack and counts once")

	await region("mountain",Vector2(850,900))
	var shield=world.spawn_enemy("shield",Vector2(930,900),"test")
	await settle(); shield.facing=PI; shield.start_action(hero); var active_id=shield.action.id
	shield.take_hit(25,0,65,"player",10)
	expect(not shield.action.is_empty() and shield.action.id==active_id and shield.stun==0,"frontal shield block preserves the enemy counterattack")
	shield.take_hit(42,0,205,"player",34,true)
	expect(shield.shield_broken>0 and shield.stun>0 and shield.action.is_empty(),"sweep breaks shield and creates a real opening")
	var victim=world.spawn_enemy("sword",Vector2(1010,900),"test")
	await settle()
	for i in range(100): victim.take_hit(3.5,0,8,"ally",0)
	expect(victim.hp>=victim.max_hp*.22-.001,"allies cannot finish an enemy alone")
	var hit_target=world.spawn_enemy("sword",Vector2(945,960),"test")
	hero.position=Vector2(850,960); hero.action={}; hero.dash_left=0
	await settle(); hero.request("attack",Vector2.ZERO,0); hero.advance_action(.08)
	expect(hit_target.hp==hit_target.max_hp,"native hitbox applies no windup damage")
	hero.advance_action(.05)
	expect(is_equal_approx(hit_target.hp,hit_target.max_hp-25),"native hitbox applies active-frame damage")
	hero.advance_action(.05)
	expect(is_equal_approx(hit_target.hp,hit_target.max_hp-25),"a strike cannot hit the same target twice")

	await region("village",Vector2(260,830))
	hero.move_ground(Vector2(400,0))
	expect(hero.position.x<322,"native continuous collision prevents crossing a house")
	var path=world.terrain.find_path(Vector2(260,830),Vector2(570,830),16)
	expect(path.size()>2,"Godot navigation finds a path around buildings")
	clear_enemies(); hero.position=Vector2(330,405)
	expect(world.interact() and world.state.flags.healer and world.state.flags.civilians,"optional village rescue changes persistent state")
	world.choose_route("continue")
	await region("temple",Vector2(600,660)); clear_enemies()
	world.prepare_boss("xiahou"); world.choose_route("bossStart:xiahou")
	await settle()
	expect(world.active_boss=="xiahou" and not world.squad_active(),"Xiahou duel excludes friendly damage")
	world.boss.take_hit(2000,0,0,"player",0)
	expect(world.state.flags.sword and world.state.flags.temple,"Xiahou defeat unlocks Qinggang")
	world.choose_route("continue")
	await region("house",Vector2(1090,470)); clear_enemies(); world.interact(); world.choose_route("rescue")
	expect(not world.rescue.is_empty() and world.rescue.wave==1,"healer route begins rescue wave one")
	world.rescue.healer.hp=0; world.advance_rescue(.02)
	expect(world.mode=="defeat","losing the healer fails the rescue")
	world.retry(); await settle()
	expect(world.mode=="playing" and world.rescue.wave==1 and world.state.flags.healer and world.state.flags.adou,"rescue retry restarts pursuers and preserves previous rescues")
	clear_enemies(); world.advance_rescue(1.6)
	expect(world.rescue.wave==2 and world.rescue_remaining()==3,"rescue spawns a second wave")
	world.rescue.progress=20; world.advance_rescue(.02)
	expect(not world.state.flags.mother,"healing progress alone cannot finish while pursuers live")
	clear_enemies(); world.advance_rescue(.02)
	expect(world.state.flags.mother and world.state.flags.house,"both waves cleared rewrite Mi Lady's fate")
	world.choose_route("continue")
	await region("fork",Vector2(1280,775)); clear_enemies(); world.interact()
	var elite=world.enemies.back(); expect(elite.kind=="elite","optional supply camp spawns elite")
	elite.take_hit(2000,0,0,"player",0,true); world.interact()
	expect(world.state.flags.supplies,"defeat then interaction burns supplies")
	await region("bridge",Vector2(1000,800))
	expect(not world.group_alive("bArchers") and not world.terrain.blocked(Vector2(1110,830),16),"burned supplies remove archers and open east path")
	clear_enemies(); world.prepare_boss("zhanghe"); world.choose_route("bossStart:zhanghe"); await settle()
	var general=world.boss; general.hp=general.max_hp*.49; general.advance(.01)
	expect(general.phase2 and general.phase_time>0,"Zhang He's second phase is telegraphed")
	general.phase_time=0; general.take_hit(3000,0,0,"player",0)
	world.choose_route("continue"); hero.position=Vector2(1270,340); hero.move_ground(Vector2(0,-235))
	expect(hero.position.y<140,"native bridge collision leaves the wooden crossing passable")
	expect(world.finish() and world.state.complete,"chapter ends after Adou and bridge boss")
	expect(world.state.build_report().changes==3,"complete route records all three changed fates")
	var data=world.state.snapshot(); expect(Campaign.valid(data),"completed save validates")
	var restored=Campaign.new(); expect(restored.restore(data) and restored.build_report().changes==3,"completed save reopens the report")
	var corrupt=data.duplicate(true); corrupt.checkpoint.x="broken"
	expect(not Campaign.valid(corrupt),"invalid coordinates rejected without a runtime error")
	var invalid=data.duplicate(true); invalid.flags.mother=true; invalid.flags.healer=false
	expect(not Campaign.valid(invalid),"inconsistent rescue flags rejected")
	world.state.save(); var disk=Campaign.new(); disk.save_path=world.state.save_path
	expect(not disk.read_save().is_empty(),"atomic native save reloads from disk")
	world.state.save_path="user://missing-directory/save.json"
	expect(not world.state.save() and not world.state.durable and not world.state.read_save().is_empty(),"save failure preserves a session fallback")
	DirAccess.remove_absolute("user://longdan-godot-test.json")

	world.state.reset(); world.ui.run_started=false
	await region("house",Vector2(1090,470)); clear_enemies(); world.interact(); world.choose_route("leaveMother")
	expect(world.state.flags.house and world.state.flags.adou and not world.state.flags.mother,"main story can proceed without optional healer rescue")
	world.state.flags.temple=true; world.state.flags.sword=true
	await region("bridge",Vector2(800,800)); expect(world.group_alive("bArchers"),"unburned supplies retain the bridge archers")

	await region("mountain",Vector2(1130,470))
	var oil=world.props[0]; oil.fuse=.01; var enemies_before=world.state.kills
	world.advance_props(.02)
	expect(oil.spent and oil.fuse<0 and oil.body.collision_layer==0,"oil explosion removes its physical obstacle once")
	world.advance_props(.1); expect(oil.spent,"oil cannot explode again")
	world.enter_stage("mountain",Vector2(1130,470),false)
	expect(not world.props[0].spent,"unfinished encounter restores oil cart on retry")
	expect(world.actors.has_node("campMountain"),"campfire has a visible interaction scene")
	await region("village",Vector2(330,500))
	expect(world.actors.get_node("civilians").people.size()==4,"village rescue characters are visible on the map")
	await region("house",Vector2(1090,540))
	expect(world.actors.get_node("adou").people.size()==1,"Mi Lady and the well have a visible story scene")
	world.state.flags.temple=false; world.state.flags.sword=false
	await region("temple",Vector2(600,660)); clear_enemies(); world.prepare_boss("xiahou"); world.choose_route("bossStart:xiahou")
	hero.hp=0; world.defeat("测试","重试"); world.retry(); await settle()
	expect(world.mode=="playing" and world.active_boss=="xiahou" and hero.hp==hero.max_hp and hero.potions==3,"duel retry restores hero and restarts the boss without intro")
	for id in world.definitions:
		await region(id,Vector2.INF)
		expect(not world.terrain.blocked(hero.position,hero.radius),"default spawn is navigable in "+id)
		expect(world.terrain.ground_texture!=null and world.terrain.ground_texture.get_size()==Vector2(1600,1100),"baked ground is present and aligned in "+id)
		var all_cached=true
		for item in world.actors.get_children():
			if item.get_script()==Scenery and item.data.kind!="oil" and item.cached_sprite==null: all_cached=false
		expect(all_cached,"trees, rocks and buildings use the shared atlas in "+id)
	var anchors_valid=true
	for frame in Scenery.manifest.values():
		if not Rect2(Vector2.ZERO,Vector2(frame.region[2],frame.region[3])).has_point(Vector2(frame.anchor[0],frame.anchor[1])): anchors_valid=false
	expect(Scenery.manifest.size()==33 and anchors_valid,"all trimmed atlas frames retain their ground anchor")

	print("GODOT_VERIFY ",checks," checks; ",failures.size()," failures")
	world.queue_free(); await process_frame; await process_frame
	quit(0 if failures.is_empty() else 1)
