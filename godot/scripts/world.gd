extends Node2D
## Chapter orchestration; gameplay runs entirely in native Godot scenes.
const Campaign = preload("res://scripts/campaign.gd")
const Hero = preload("res://scenes/hero.tscn")
const Enemy = preload("res://scenes/enemy.tscn")
const Companion = preload("res://scripts/companion.gd")
const Terrain = preload("res://scripts/terrain.gd")
const Effects = preload("res://scripts/effects.gd")
const Sound = preload("res://scripts/sound.gd")
const Interface = preload("res://scripts/interface.gd")
const Interactable = preload("res://scripts/interactable.gd")
var state = Campaign.new()
var definitions: Dictionary = {}
var attacks: Dictionary = {}
var stage = "mountain"
var definition: Dictionary = {}
var mode = "menu"
var actors: Node2D
var terrain
var fx
var sound
var ui
var hero
var enemies: Array = []
var allies: Array = []
var civilians: Array = []
var props: Array = []
var arrows: Array = []
var loot: Array = []
var boss
var active_boss = ""
var rescue: Dictionary = {}
var command = "follow"
var camera: Camera2D
var shake = 0.0
var hit_stop = 0.0
var serial = 0
var mouse_aim = false
var mouse_attack_held = false
var keyboard_attack_held = false
var rng = RandomNumberGenerator.new()
var pending_stage: Dictionary = {}
var test_mode = false
var performance_report=false
var performance_warmup=1.0
var performance_elapsed=0.0
var performance_frames: Array=[]
var performance_draws: Array=[]
var performance_previous_tick=0

func _ready() -> void:
	rng.seed = 82713
	var data = JSON.parse_string(FileAccess.get_file_as_string("res://data/chapter1.json"))
	definitions = data.StageDefinition; attacks = data.AttackDefinition
	setup_input()
	actors = Node2D.new(); actors.name = "Actors"; actors.y_sort_enabled = true; add_child(actors)
	hero = Hero.instantiate(); hero.name = "ZhaoYun"; hero.world = self; hero.max_hp = 200; hero.hp = 200
	actors.add_child(hero)
	fx = Effects.new(); fx.name = "CombatEffects"; fx.world = self; fx.z_index = 5; add_child(fx)
	sound = Sound.new(); sound.name = "Audio"; sound.muted=test_mode; add_child(sound)
	camera = Camera2D.new(); camera.name = "FollowCamera"; camera.zoom = Vector2(1.15,1.15)
	camera.limit_left = 0; camera.limit_top = 0; camera.limit_right = 1600; camera.limit_bottom = 1100
	add_child(camera); camera.make_current()
	enter_stage("mountain",Vector2(190,910),false)
	ui = Interface.new(); ui.name = "Interface"; ui.world = self; add_child(ui)
	ui.show_menu()
	get_window().focus_exited.connect(on_focus_lost)
	# Optional QA modes are explicit local launch arguments, never shipped UI controls.
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--capture="): call_deferred("capture_scene",arg.trim_prefix("--capture="))
		elif arg=="--smoke": call_deferred("smoke_exit")
		elif arg=="--perf-report": performance_report=true

func setup_input() -> void:
	var keys = {"move_left":[KEY_A,KEY_LEFT],"move_right":[KEY_D,KEY_RIGHT],"move_up":[KEY_W,KEY_UP],"move_down":[KEY_S,KEY_DOWN],"attack":[KEY_J],"dash":[KEY_SPACE,KEY_K],"sweep":[KEY_Q],"sword":[KEY_R],"heal":[KEY_F],"interact":[KEY_E],"pause":[KEY_ESCAPE],"map":[KEY_M],"follow":[KEY_1],"hold":[KEY_2],"charge":[KEY_3],"fullscreen":[KEY_F11]}
	for action in keys:
		if InputMap.has_action(action): continue
		InputMap.add_action(action)
		for key in keys[action]:
			var event = InputEventKey.new(); event.physical_keycode = key; InputMap.action_add_event(action,event)
	for action in ["mouse_attack","mouse_sweep"]:
		if not InputMap.has_action(action): InputMap.add_action(action)
		var event = InputEventMouseButton.new(); event.button_index = MOUSE_BUTTON_LEFT if action=="mouse_attack" else MOUSE_BUTTON_RIGHT
		InputMap.action_add_event(action,event)

func movement_input() -> Vector2:
	return Input.get_vector("move_left","move_right","move_up","move_down")

func aim_direction() -> float:
	return (get_global_mouse_position()-hero.position).angle() if mouse_aim else INF

func _input(event: InputEvent) -> void:
	# Releases must also clear input when the pointer ends over a UI control.
	if event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_LEFT and not event.pressed:
		mouse_attack_held=false
	if event is InputEventKey and event.physical_keycode==KEY_J and not event.pressed:
		keyboard_attack_held=false

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.echo: return
	if event.is_action_pressed("fullscreen"):
		toggle_fullscreen(); get_viewport().set_input_as_handled(); return
	if event.is_action_pressed("pause"):
		if mode in ["pause","map"]: resume()
		elif mode=="playing": pause("pause")
		elif mode=="dialog": ui.focus_choice()
		get_viewport().set_input_as_handled(); return
	if event.is_action_pressed("map"):
		if mode=="map": resume()
		elif mode=="playing": pause("map")
		get_viewport().set_input_as_handled(); return
	if mode!="playing": return
	if event is InputEventMouseMotion:
		mouse_aim = true
	if event is InputEventKey and event.pressed and event.physical_keycode in [KEY_W,KEY_A,KEY_S,KEY_D,KEY_UP,KEY_DOWN,KEY_LEFT,KEY_RIGHT,KEY_J]:
		mouse_aim = false
	if event.is_action_pressed("mouse_attack") or event.is_action_pressed("mouse_sweep"): mouse_aim = true
	if event.is_action_pressed("attack") or event.is_action_pressed("mouse_attack"):
		if event.is_action_pressed("mouse_attack"): mouse_attack_held=true
		else: keyboard_attack_held=true
		hero.request("attack",movement_input(),aim_direction())
	elif event.is_action_pressed("dash"):
		hero.request("dash",movement_input(),aim_direction())
	elif event.is_action_pressed("sweep") or event.is_action_pressed("mouse_sweep"):
		hero.request("sweep",movement_input(),aim_direction())
	elif event.is_action_pressed("sword"):
		hero.request("sword",movement_input(),aim_direction())
	elif event.is_action_pressed("heal"): hero.request("heal")
	elif event.is_action_pressed("interact"): interact()
	elif event.is_action_pressed("follow"): set_command("follow")
	elif event.is_action_pressed("hold"): set_command("hold")
	elif event.is_action_pressed("charge"): set_command("charge")

func _physics_process(dt: float) -> void:
	if not pending_stage.is_empty():
		var request = pending_stage; pending_stage = {}; enter_stage(request.id,request.get("pos",Vector2.INF))
	if mode!="playing": return
	if hit_stop>0 and not fx.soft:
		hit_stop = maxf(0,hit_stop-dt); return
	state.time += dt
	hero.advance(dt,movement_input(),keyboard_attack_held or mouse_attack_held,aim_direction())
	if mode!="playing": return
	for ally in allies: ally.advance(dt)
	for civil in civilians: civil.advance(dt)
	for enemy in enemies:
		if mode!="playing": break
		enemy.advance(dt)
	if mode!="playing": return
	advance_arrows(dt); advance_props(dt); advance_rescue(dt); advance_loot(dt)
	fx.advance(dt)

func _process(dt: float) -> void:
	if not is_instance_valid(hero): return
	var target = hero.position
	if active_boss!="" and is_instance_valid(boss): target=target.lerp(boss.position,.28)
	camera.position = camera.position.lerp(target,1-exp(-12*dt))
	shake = maxf(0,shake-dt*18)
	camera.offset = Vector2(rng.randf_range(-shake,shake),rng.randf_range(-shake,shake)) if not fx.soft and mode=="playing" else Vector2.ZERO
	if ui: ui.refresh(dt)
	if performance_report:
		if mode=="playing": measure_performance()
		else: performance_previous_tick=0

func measure_performance() -> void:
	# Opt-in QA output only; no overlay or frame monitor runs during normal play.
	var now=Time.get_ticks_usec()
	if performance_previous_tick==0:
		performance_previous_tick=now; return
	# Godot clamps process delta after stalls; wall-clock intervals reveal them.
	var dt=(now-performance_previous_tick)/1000000.0; performance_previous_tick=now
	performance_warmup-=dt
	if performance_warmup>0: return
	performance_elapsed+=dt; performance_frames.append(dt*1000)
	performance_draws.append(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
	if performance_elapsed<5: return
	performance_frames.sort(); performance_draws.sort()
	print("LONGDAN_PERF ",JSON.stringify({"stage":stage,"samples":performance_frames.size(),"median_ms":performance_frames[int(performance_frames.size()*.5)],"p95_ms":performance_frames[int(performance_frames.size()*.95)],"draw_calls":performance_draws[int(performance_draws.size()*.5)],"fps":Performance.get_monitor(Performance.TIME_FPS)}))
	performance_report=false

func on_focus_lost() -> void:
	hero.buffer = {}; clear_input()
	if mode=="playing": pause("pause")

func toggle_fullscreen() -> void:
	var full = DisplayServer.window_get_mode()==DisplayServer.WINDOW_MODE_FULLSCREEN
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED if full else DisplayServer.WINDOW_MODE_FULLSCREEN)

func pause(kind: String) -> void:
	hero.buffer = {}; mode = kind; clear_input(); ui.show_pause(kind)

func resume() -> void:
	if mode not in ["pause","map"]: return
	mode="playing"; hero.buffer={}; clear_input(); ui.hide_overlay()

func title_screen() -> void:
	save_progress(); hero.buffer={}; mode="menu"; ui.show_menu()

func start_game(difficulty: String = "normal") -> void:
	state.reset(difficulty); hero.max_hp=240 if difficulty=="story" else 200; hero.reset_combat()
	mode="playing"; enter_stage("mountain",Vector2(190,910)); ui.hide_overlay()
	dialog("长坂 · 记忆醒来","战鼓将你唤醒。你成了赵子龙，醒在长坂溃军之间。\n\n你记得独骑救主，也记得有人永远留在了这片火里。\n\n这一回，长枪在你手中。",[{"text":"握枪起身","detail":"沿山道学会出枪、闪避与破盾。","route":"continue"}],"赵云 · 心声")

func continue_game() -> bool:
	var saved = state.read_save()
	if saved.is_empty() or not state.restore(saved): return false
	ui.run_started=true
	hero.max_hp=240 if state.difficulty=="story" else 200; hero.reset_combat(); mode="playing"
	var cp = state.checkpoint.duplicate(); enter_stage(cp.stage,Vector2(cp.x,cp.y),false); state.checkpoint=cp
	ui.hide_overlay()
	if state.complete:
		mode="ending"; ui.show_report(state.build_report()); return true
	if cp.encounter=="rescue" and not state.flags.mother: start_rescue()
	elif cp.encounter=="xiahou" and not state.flags.temple or cp.encounter=="zhanghe" and not state.flags.boss: begin_boss(cp.encounter)
	toast("已从最近营火或入口继续，完成的命运选择都还在。")
	return true

func enter_stage(id: String, spawn: Vector2 = Vector2.INF, checkpoint: bool = true) -> void:
	hero.buffer={}; hero.action={}; hero.dash_left=0; hero.invincible=.6
	stage=id; definition=definitions[id]; active_boss=""; boss=null; rescue={}; arrows=[]; loot=[]; enemies=[]; allies=[]; civilians=[]; props=[]
	for child in actors.get_children():
		if child==hero: continue
		actors.remove_child(child); child.queue_free()
	if terrain:
		remove_child(terrain); terrain.queue_free()
	for original in definition.get("props",[]):
		var prop = original.duplicate(true); prop.spent=state.cleared.has(id+":"+prop.group); prop.fuse=-1.0; props.append(prop)
	terrain=Terrain.new(); terrain.name="Region"; terrain.world=self; terrain.z_index=-5; add_child(terrain); terrain.build(definition)
	for object in definition.objects:
		var marker=Interactable.new(); marker.world=self; marker.data=object; marker.position=Vector2(object.x,object.y); marker.name=object.id
		actors.add_child(marker)
	hero.position = Vector2(definition.spawn[0],definition.spawn[1]) if not spawn.is_finite() else spawn
	hero.moving=false; hero.walk_distance=0; hero.update_visual()
	for group in definition.groups:
		if state.cleared.has(stage+":"+group.id) or group.has("unless") and state.flags[group.unless]: continue
		for unit in group.units: spawn_enemy(unit[0],Vector2(unit[1],unit[2]),group.id)
	for i in range(3):
		var ally=Companion.new(); ally.name="Squad"+str(i+1); ally.world=self; ally.slot=i
		ally.position=hero.position+Vector2(-65+(i-1)*48,65+(i%2)*24); actors.add_child(ally); allies.append(ally)
	if stage=="bridge":
		if state.flags.civilians:
			for i in range(3): spawn_civil("civil",hero.position+Vector2(-45+i*25,65),i)
		if state.flags.mother: spawn_civil("mother",hero.position+Vector2(-50,100),3)
	fx.entries=[]; fx.labels=[]; hit_stop=0; shake=0
	camera.position=hero.position; camera.reset_smoothing()
	if checkpoint:
		state.checkpoint={"stage":id,"x":hero.position.x,"y":hero.position.y,"encounter":""}; save_progress()
	if mode!="menu": toast(definition.tutorial)
	if ui: ui.stage_changed()

func spawn_enemy(kind: String, p: Vector2, group: String = "extra", boss_name: String = ""):
	var unit=Enemy.instantiate(); unit.world=self; unit.group_id=group; unit.configure(kind,boss_name); unit.position=p
	unit.name="Enemy_"+kind; actors.add_child(unit); enemies.append(unit)
	return unit

func spawn_civil(kind: String, p: Vector2, slot: int):
	var unit=Companion.new(); unit.world=self; unit.kind=kind; unit.position=p; unit.slot=slot; unit.max_hp=100; unit.hp=100
	actors.add_child(unit); civilians.append(unit)
	return unit

func new_action(key: String, data: Dictionary, direction: float) -> Dictionary:
	serial+=1
	return {"id":serial,"key":key,"def":data.duplicate(),"dir":direction,"t":0.0,"hits":[],"fired":false,"travel":0.0}

static func attack_hits(origin: Vector2, target: Vector2, data: Dictionary, direction: float, radius: float = 0) -> bool:
	return origin.distance_to(target)<=data.range+radius and absf(angle_difference(direction,(target-origin).angle()))<=data.arc

func melee_targets(origin, data: Dictionary, direction: float, mask: int) -> Array:
	# Physics broad phase respects the actual actor collision shapes.
	var query=PhysicsShapeQueryParameters2D.new(); var circle=CircleShape2D.new(); circle.radius=data.range+24
	query.shape=circle; query.transform=Transform2D(0,origin.position); query.collision_mask=mask
	var results=get_world_2d().direct_space_state.intersect_shape(query,64)
	var targets: Array=[]
	for result in results:
		var target=result.collider
		if target in enemies and target.body_alive() and attack_hits(origin.position,target.position,data,direction,target.radius): targets.append(target)
	return targets

func nearest_enemy(p: Vector2, radius: float):
	var target=null; var best=radius
	for enemy in enemies:
		if not enemy.body_alive() or active_boss!="" and enemy!=boss: continue
		var distance=p.distance_to(enemy.position)
		if distance<best: best=distance; target=enemy
	return target

func combat_friends() -> Array:
	var friends: Array=[hero]
	if active_boss!="": return friends
	if squad_active(): friends.append_array(allies)
	if not rescue.is_empty(): friends.append(rescue.healer)
	return friends

func nearest_friend(p: Vector2, radius: float):
	var target=null; var best=radius
	for friend in combat_friends():
		if not friend.body_alive(): continue
		var distance=p.distance_to(friend.position)
		if distance<best: best=distance; target=friend
	return target

func attackers_count() -> int:
	var count=0
	for enemy in enemies:
		if enemy.body_alive() and enemy.kind!="archer" and not enemy.action.is_empty() and enemy.action.t<enemy.action.def.windup+enemy.action.def.active: count+=1
	return count

func camera_impact(strength: float) -> void:
	shake=maxf(shake,strength)

func fire_arrow(origin, a: Dictionary) -> void:
	arrows.append({"id":a.id,"pos":origin.position+Vector2(0,-8),"dir":a.dir,"damage":a.def.damage,"life":2.1})

func advance_arrows(dt: float) -> void:
	var live: Array=[]
	for arrow in arrows:
		var previous=arrow.pos; var end=previous+Vector2.from_angle(arrow.dir)*400*minf(dt,arrow.life)
		arrow.life-=dt
		var query=PhysicsRayQueryParameters2D.create(previous,end,1)
		if not get_world_2d().direct_space_state.intersect_ray(query).is_empty(): continue
		var hit=false
		for friend in combat_friends():
			if friend.body_alive() and friend.position.distance_to(Geometry2D.get_closest_point_to_segment(friend.position,previous,end))<friend.radius+8:
				friend.take_damage(arrow.damage,arrow.id); hit=true; break
		arrow.pos=end
		if not hit and arrow.life>0: live.append(arrow)
	arrows=live

func advance_props(dt: float) -> void:
	for prop in props:
		if prop.spent or prop.fuse<0: continue
		prop.fuse-=dt
		if prop.fuse>0: continue
		prop.fuse=-1; prop.spent=true
		if prop.has("body") and is_instance_valid(prop.body): prop.body.collision_layer=0; prop.body.queue_free()
		prop.graphic.queue_redraw(); terrain.build_grid()
		var p=Vector2(prop.x,prop.y); fx.add("explosion",p,.65,{"radius":prop.blastRadius}); sound.play_cue("explosion"); camera_impact(5)
		for enemy in enemies:
			if enemy.body_alive() and p.distance_to(enemy.position)<=prop.blastRadius+enemy.radius: enemy.take_hit(85,(enemy.position-p).angle(),190,"environment",48,true)
		for friend in combat_friends():
			if friend.body_alive() and p.distance_to(friend.position)<=prop.blastRadius+friend.radius: friend.take_damage(28)

func advance_loot(dt: float) -> void:
	var remaining: Array=[]
	for item in loot:
		item.life-=dt
		if hero.position.distance_to(item.pos)<35 and hero.hp<hero.max_hp:
			var amount=minf(18,hero.max_hp-hero.hp); hero.hp+=amount
			fx.floater(hero.position,"+"+str(int(ceil(amount)))+" 体力",Color("b7e9c4")); fx.add("heal",hero.position,.45,{"radius":36.0}); sound.play_cue("heal")
		elif item.life>0: remaining.append(item)
	loot=remaining

func squad_active() -> bool:
	return active_boss=="" and (not rescue.is_empty() or stage=="bridge" and not state.flags.boss)

func set_command(order: String) -> void:
	command=order
	for ally in allies: ally.home=ally.position; ally.path=[]
	toast({"follow":"随军集合 · 随你掩护","hold":"随军守点 · 固守当前位置","charge":"随军冲阵 · 牵制前方敌军"}[order] if squad_active() else "随军待命，在井畔营救与桥头突围时掩护你。")

func group_alive(id: String = "") -> bool:
	for enemy in enemies:
		if enemy.body_alive() and (id=="" or enemy.group_id==id): return true
	return false

func check_groups() -> void:
	for group in definition.groups:
		var key=stage+":"+group.id
		if not state.cleared.has(key) and not group_alive(group.id):
			state.cleared.append(key); save_progress()
	if stage=="mountain" and not group_alive() and not state.flags.mountain:
		state.flags.mountain=true; toast("山道已清，到前方营火补药后再进荒村。"); save_progress()
	if squad_active() and not group_alive() and rescue.is_empty():
		for ally in allies: ally.hp=ally.max_hp

func object_by_id(id: String) -> Dictionary:
	for object in definition.objects:
		if object.id==id: return object
	return {}

func nearest_object() -> Dictionary:
	if mode!="playing" or active_boss!="" or not rescue.is_empty(): return {}
	var best=100.0; var target: Dictionary={}
	for object in definition.objects:
		if object.id=="civilians" and state.flags.civilians or object.id=="xiahouGate" and state.flags.temple or object.id=="zhangheGate" and state.flags.boss or object.id=="adou" and state.flags.house and (state.flags.mother or state.flags.committed): continue
		var distance=hero.position.distance_to(Vector2(object.x,object.y))
		if distance<best: best=distance; target=object
	return target

func object_blocked(object: Dictionary) -> bool:
	if object.has("need") and not state.flags[object.need]: return true
	if object.has("group") and group_alive(object.group): return true
	if object.id=="toTemple":
		for enemy in enemies:
			if enemy.body_alive() and enemy.group_id!="vRescue": return true
	if object.id=="zhangheGate" and group_alive(): return true
	return false

func interaction_text(object: Dictionary) -> String:
	if object.is_empty(): return ""
	if object_blocked(object):
		if object.has("need") and not state.flags[object.need]: return {"mountain":"先清开山道","temple":"先击败夏侯恩","house":"先安置阿斗与糜夫人","boss":"先击退张郃"}[object.need]
		return "先击退守军 · 跟随金色指引"
	if object.kind=="camp": return "休整 · 补满体力与行军药"
	if object.id=="supplies": return "粮营已毁" if state.flags.supplies else "点火焚粮" if state.flags.elite else "挑战盾阵校尉"
	if object.id=="adou" and state.flags.adou: return "请医者营救糜夫人" if state.flags.healer else "井畔还有一人 · 寻找医者"
	return object.label

func interact() -> bool:
	var object=nearest_object()
	if object.is_empty(): return false
	if object.kind=="camp":
		for enemy in enemies:
			if enemy.body_alive() and enemy.alerted and enemy.position.distance_to(Vector2(object.x,object.y))<350:
				toast("先击退附近敌军，再休整。"); return false
		hero.hp=hero.max_hp; hero.qi=100; hero.potions=3; hero.action={}; hero.buffer={}
		for ally in allies: ally.hp=ally.max_hp
		state.checkpoint={"stage":stage,"x":object.x,"y":object.y+35,"encounter":""}; save_progress(); sound.play_cue("heal")
		fx.add("heal",hero.position,.8,{"radius":65.0}); toast("营火记住了你的来路，体力与三份行军药已补满。"); return true
	if object_blocked(object): toast(interaction_text(object)); return false
	if object.kind=="exit":
		if object.to=="bridge" and not state.flags.committed:
			dialog("渡桥前 · 最后的回望","前往北桥后，曹军将截断返回旧宅的路。\n\n"+("糜夫人已安置妥当。" if state.flags.mother else "糜夫人仍在井畔，你还可以回去尝试救她。")+"\n"+("粮营已毁，桥头弓阵将撤走。" if state.flags.supplies else "曹军粮草尚在，桥头弓阵仍会拦路。"),[{"text":"整军渡桥","detail":"随军掩护突围，赵云断后单挑张郃。","route":"commit"},{"text":"再回头看一眼","detail":"留在粮道，补完救援和焚粮。","route":"continue"}],"赵云 · 军令")
		else:
			var spawn=Vector2.INF
			if object.id=="shortcut": spawn=Vector2(1325,215)
			elif object.id.begins_with("back"):
				for exit in definitions[object.to].objects:
					if exit.get("to")==stage and not exit.id.begins_with("back"): spawn=Vector2(exit.x-55,exit.y+70); break
			pending_stage={"id":object.to,"pos":spawn}
		return true
	if object.id=="civilians":
		state.flags.civilians=true; state.flags.healer=true; state.route="bridge"
		state.record("荒村医者与三名百姓获救，随军护送百姓先行撤往北桥。")
		dialog("荒村 · 悬壶未尽","医者：将军若还要找人，我随你走。伤重之人，也不该只剩等死。\n\n赵云：乡亲随军先走。医者，待我找到夫人，再请你救命。",[{"text":"请医者随行","detail":"解锁井畔营救糜夫人的机会。","route":"continue"}],"医者"); save_progress(); return true
	if object.kind=="boss": prepare_boss("xiahou" if object.id=="xiahouGate" else "zhanghe"); return true
	if object.id=="adou":
		state.flags.adou=true
		dialog("井畔 · 这一次不必赴死","你抱起阿斗，糜夫人倚在井边。\n\n糜夫人：子龙，带着孩子走吧，莫让我们误了你。\n\n你记得她没能走出长坂。"+("\n身后的医者已经赶来：让我试试，尚有一线生机。" if state.flags.healer else "\n若能找到荒村医者，或许还能救她。"),[{"text":"护住井畔，请医者救人" if state.flags.healer else "回荒村寻找医者","detail":"保护医者，击退两波追兵。" if state.flags.healer else "经破庙侧门返回荒村，回来后再救夫人。","route":"rescue" if state.flags.healer else "findHealer"},{"text":"先护阿斗撤离","detail":"渡桥前仍可以回头。","route":"leaveMother"}],"糜夫人"); save_progress(); return true
	if object.id=="supplies":
		if state.flags.supplies: return false
		if not state.flags.elite:
			if not group_alive("elite"): spawn_enemy("elite",Vector2(1280,765),"elite"); toast("盾阵校尉：粮营重地，休想再进！横扫破盾或绕后出枪。")
			return true
		state.flags.supplies=true; state.record("曹军粮营被焚，北桥弓阵撤回救火，东侧道打开。")
		toast("粮营起火！北桥弓阵撤走，侧道已开。"); sound.play_cue("victory"); save_progress(); return true
	if object.kind=="finish": return finish()
	return false

func dialog(title: String, text: String, choices: Array, speaker: String) -> void:
	hero.buffer={}; clear_input(); mode="dialog"; ui.show_dialog(title,text,choices,speaker)

func choose_route(route: String) -> void:
	if mode!="dialog": return
	mode="playing"; ui.hide_overlay(); clear_input()
	if route=="commit": state.flags.committed=true; pending_stage={"id":"bridge"}
	elif route=="rescue": start_rescue()
	elif route=="findHealer": state.route="healer"; toast("原路回破庙，从侧门回荒村；救出医者后再来井畔。")
	elif route=="leaveMother":
		state.flags.house=true; state.flags.motherDecision=true; state.route="bridge"
		state.record("你先护住阿斗，井畔仍有一个未尽的承诺。")
	elif route.begins_with("bossStart:"): begin_boss(route.trim_prefix("bossStart:"))
	save_progress()

func prepare_boss(id: String) -> void:
	state.checkpoint={"stage":stage,"x":hero.position.x,"y":hero.position.y,"encounter":id}
	if state.seen.has(id): begin_boss(id); return
	state.seen.append(id)
	var text="夏侯恩：这柄青釭，专斩来将。\n\n赵云：剑是好剑。只是今日，我要借它开一条生路。\n\n快剑有第二招，重斩则须晚一点避。" if id=="xiahou" else "随军护送百姓先行上桥。\n\n张郃：赵子龙！你能救几人，便能挡几枪？\n\n赵云：他们走得多远，我便守到多远。\n\n随军撤向桥北，赵云独自断后。"
	dialog("破庙 · 青釭在谁手" if id=="xiahou" else "北桥 · 谁来断后",text,[{"text":"入阵","detail":"观察敌将起手，等整套连招收完再反击。","route":"bossStart:"+id}],"夏侯恩" if id=="xiahou" else "张郃"); save_progress()

func begin_boss(id: String) -> void:
	hero.buffer={}; hero.action={}; active_boss=id; arrows=[]
	for enemy in enemies:
		if enemy.body_alive(): enemy.hp=0; enemy.collision_layer=0
	var arena=definition.arena
	hero.position=Vector2(arena.x-145,arena.y+90); hero.invincible=.8
	boss=spawn_enemy("boss",Vector2(arena.x+90,arena.y-35),"boss",id); boss.cooldown=1.1
	for i in range(allies.size()):
		allies[i].position=Vector2(1270+(i-1)*22,165+i*20) if id=="zhanghe" else Vector2(400+i*26,850)
	for i in range(civilians.size()): civilians[i].position=Vector2(1270+(20 if i%2 else -20),260-i*28)
	toast("夏侯恩 · 等第二剑收招再反击。" if id=="xiahou" else "张郃 · 三连突后才有长破绽。"); save_progress()

func boss_defeated(enemy) -> void:
	active_boss=""; arrows=[]; hero.action={}; hero.invincible=1
	for ally in allies: ally.hp=ally.max_hp
	if enemy.boss_id=="xiahou":
		state.flags.temple=true; state.flags.sword=true; hero.rage=100
		state.checkpoint={"stage":"temple","x":1090.0,"y":550.0,"encounter":""}
		state.record("夏侯恩败于破庙，赵云夺得青釭剑，荒村侧门打开。")
		dialog("青釭入手 · 路已不同","你收起青釭剑，重新握紧长枪。\n\n新招「青釭断势」已习得：战意满时，按 R 拔剑打出高破势一击。\n\n西侧门直回荒村，东路通向井畔。",[{"text":"持剑前行","detail":"井畔还有人在等你。","route":"continue"}],"赵云")
	else:
		state.flags.boss=true; state.checkpoint={"stage":"bridge","x":1100.0,"y":340.0,"encounter":""}
		state.record("北桥枪阵被破，张郃退去，赵云守住了队伍的撤离。")
		dialog("张郃退兵 · 生路在前","张郃收枪：今日一战，来日再讨。\n\n桥上，随军挥旗示意。阿斗平安，前方就是刘备的队伍。\n\n沿木桥向北，在桥头会合。",[{"text":"收枪渡桥","detail":"你这一回救下的人，都在桥北等你。","route":"continue"}],"张郃")
	sound.play_cue("victory"); save_progress()

func start_rescue() -> void:
	if not state.flags.healer or state.flags.mother: return
	state.flags.adou=true; state.flags.house=false
	state.checkpoint={"stage":"house","x":1030.0,"y":570.0,"encounter":"rescue"}
	var healer=spawn_civil("healer",Vector2(1090,465),7)
	rescue={"wave":1,"progress":0.0,"gap":0.0,"healer":healer}
	command="hold"
	for i in range(allies.size()):
		allies[i].hp=allies[i].max_hp; allies[i].position=Vector2(1000+i*75,530); allies[i].home=allies[i].position
	spawn_rescue_wave(); toast("保护医者！两波追兵从井畔两侧赶来，随军守点，你来切断敌军。"); save_progress()

func spawn_rescue_wave() -> void:
	for unit in [["sword",765,505],["spear",1330,550],["sword" if rescue.wave==1 else "archer",1170,705]]:
		var enemy=spawn_enemy(unit[0],Vector2(unit[1],unit[2]),"rescue"+str(rescue.wave)); enemy.alerted=true

func rescue_remaining() -> int:
	var count=0
	for enemy in enemies:
		if enemy.body_alive() and enemy.group_id.begins_with("rescue"): count+=1
	return count

func advance_rescue(dt: float) -> void:
	if rescue.is_empty(): return
	rescue.progress=minf(20,rescue.progress+dt)
	if rescue.healer.hp<=0: defeat("井畔营救受阻","医者没能完成施救。重试会保留阿斗与已救百姓。"); return
	if rescue_remaining()==0:
		rescue.gap+=dt
		if rescue.wave==1 and rescue.gap>1.5:
			rescue.wave=2; rescue.gap=0; spawn_rescue_wave(); toast("第二波追兵来了，护住井畔！")
		elif rescue.wave==2 and rescue.progress>=20:
			state.flags.mother=true; state.flags.house=true; state.flags.motherDecision=true; rescue={}
			state.checkpoint={"stage":"house","x":1090.0,"y":540.0,"encounter":""}
			state.record("你护住井畔医者，糜夫人被救上担架，记忆中的诀别被改写。")
			dialog("井畔逆命 · 她活下来了","医者：血止住了。快，抬她走。\n\n糜夫人：子龙……孩子呢？\n\n赵云：孩子在，夫人也在。这回，一个都不会落下。",[{"text":"向粮道出发","detail":"随军护送担架先行，你带阿斗继续断后。","route":"continue"}],"糜夫人"); save_progress()

func defeat(title: String, text: String) -> void:
	if mode!="playing": return
	hero.buffer={}; mode="defeat"; ui.show_defeat(title,text); save_progress()

func retry() -> void:
	if mode!="defeat": return
	var cp=state.checkpoint.duplicate(); hero.reset_combat(); mode="playing"
	enter_stage(cp.stage,Vector2(cp.x,cp.y),false); state.checkpoint=cp; ui.hide_overlay()
	if cp.encounter=="rescue": start_rescue()
	elif cp.encounter in ["xiahou","zhanghe"]: begin_boss(cp.encounter)
	toast("重新握枪，已完成的救援和夺剑仍在。"); save_progress()

func finish() -> bool:
	if mode!="playing" or stage!="bridge" or not state.flags.adou or not state.flags.boss or state.complete: return false
	state.complete=true; mode="ending"; hero.buffer={}; ui.show_report(state.build_report()); sound.play_cue("victory"); save_progress()
	return true

func first_guard(groups: Array):
	for group in groups:
		for enemy in enemies:
			if enemy.body_alive() and enemy.group_id==group: return enemy
	return null

func mission() -> Dictionary:
	if active_boss!="":
		return {"title":boss.display_name+" · 单挑","text":"看清起手，等整套连招结束再反击。精准闪避可接回马枪。","pos":boss.position}
	if not rescue.is_empty():
		return {"title":"守住井畔 · 第 "+str(rescue.wave)+" / 2 波","text":"医者体力 "+str(int(ceil(rescue.healer.hp)))+" · 剩余追兵 "+str(rescue_remaining()),"pos":rescue.healer.position}
	var object: Dictionary={}; var guard=null; var title=""; var text=""
	match stage:
		"mountain":
			guard=first_guard(["m1","m2","m3"]); object=object_by_id("toVillage")
			title={"m1":"枪起长坂","m2":"识破枪势","m3":"破盾开路"}.get(guard.group_id,"枪起长坂") if guard else "营火与前路"
			text="击退剑兵，J / 左键接三式。" if guard and guard.group_id=="m1" else "看红区，空格 / K 闪避后反击。" if guard and guard.group_id=="m2" else "Q / 右键破盾，或借油车破阵。" if guard else "营火可补药并保存进度，之后前往荒村。"
		"village":
			var seeking=state.route=="healer" and not state.flags.healer
			guard=first_guard(["vRescue"] if seeking else ["v1","v2","v3"])
			object=object_by_id("civilians" if seeking else "toTemple")
			title="寻访医者" if seeking else "清开荒村主路" if guard else "穿过荒村"
			text="击退西巷守军，靠近医者按 E 救人。" if seeking else "清开主路；西巷医者与百姓可以救援。" if guard else "北面通向破庙，西巷救援仍可完成。"
		"temple":
			guard=first_guard(["t1"]) if not state.flags.temple else null
			object=object_by_id("shortcut" if state.flags.temple and state.route=="healer" and not state.flags.healer else "toHouse" if state.flags.temple else "xiahouGate")
			title="侧门已开" if state.flags.temple else "破庙夺剑"; text="东路通井畔，西侧门直回荒村。" if state.flags.temple else "清开庙外守军，营火休整后独挑夏侯恩。"
		"house":
			guard=first_guard(["h1","h2"]) if not state.flags.adou else null
			object=object_by_id("backTemple" if state.route=="healer" and not state.flags.healer else "toFork" if state.flags.house else "adou")
			title="护主向北" if state.flags.house else "井畔还有一人" if state.flags.adou else "寻回阿斗"; text="夫人已获救，继续前往粮道。" if state.flags.mother else "请医者救下夫人，渡桥前仍可以回头。" if state.flags.adou else "击退井畔守军，靠近旧宅按 E。"
		"fork":
			guard=first_guard(["f1"]); object=object_by_id("toBridge"); title="粮道抉择"; text="北路通桥头；东营可挑战校尉，焚粮撤走弓阵。"
		"bridge":
			guard=first_guard(["b1","bArchers"]); object=object_by_id("exit" if state.flags.boss else "zhangheGate")
			title="渡桥重逢" if state.flags.boss else "一枪断后"; text="沿木桥向北，与刘备会合。" if state.flags.boss else "随军掩护突围，清开桥头后独挑张郃。"
	return {"title":title,"text":text,"pos":guard.position if guard else Vector2(object.get("x",hero.position.x),object.get("y",hero.position.y))}

func toast(message: String) -> void:
	if ui: ui.toast(message)

func clear_input() -> void:
	mouse_attack_held=false; keyboard_attack_held=false
	for key in InputMap.get_actions(): Input.action_release(key)

func save_progress() -> void:
	if test_mode: return
	state.save()

func smoke_exit() -> void:
	await get_tree().process_frame
	print("GODOT_SMOKE_OK regions=",definitions.size()," atlases=",hero.visual.frames.size())
	get_tree().quit()

func capture_scene(scene: String) -> void:
	test_mode=true
	if scene=="dialog": start_game()
	elif scene=="report":
		state.flags.adou=true; state.flags.boss=true; state.flags.mother=true; state.flags.healer=true; state.flags.civilians=true; state.flags.supplies=true
		mode="ending"; ui.show_report(state.build_report())
	elif scene!="menu":
		mode="playing"; ui.hide_overlay()
		var target="temple" if scene=="boss" else scene if scene in ["village","house","fork","bridge"] else "mountain"
		var p=Vector2(330,495) if scene=="village" else Vector2(1090,545) if scene=="house" else Vector2(1280,775) if scene=="fork" else Vector2(850,560) if scene=="bridge" else Vector2(700,570) if scene=="boss" else Vector2(740,615)
		enter_stage(target,p,false)
		if scene=="boss": begin_boss("xiahou")
		elif scene=="attack":
			hero.request("attack",Vector2.ZERO,-.6); hero.advance_action(.11); hero.update_visual(); fx.queue_redraw(); set_physics_process(false)
	await get_tree().process_frame
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var image=get_viewport().get_texture().get_image()
	image.save_png("res://../.qa/godot-"+scene+".png")
	print("CAPTURE_OK ",scene)
	get_tree().quit()
