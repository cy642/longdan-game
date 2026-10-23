extends Node2D
## One owner for finite waves, escort checkpoints and the camp stratagem.
const Cart=preload("res://scripts/grain_cart.gd")
const HuangzhongSupport=preload("res://scripts/huangzhong_support.gd")
var world
var support
var spawned: Dictionary={}
var waiting: Array=[]
var cart
var points: Array=[]
var stops: Array=[]
var stuck=0.0
var retreat_time=0.0
var best_left=4.0
var fire_clock=0.0
var fire_targets: Array=[]
var roster_maximums: Dictionary={}
var cart_follow_radius=520.0
var cart_danger_radius=160.0
var gate_state: String:
	get: return str(world.state.tactics.get("gate","PREPARE"))
	set(value): world.state.tactics.gate=value

func setup(game) -> void:
	world=game
	if world.stage=="hs_grain":
		var marker=world.actors.get_node_or_null("hs_huangzhong")
		if marker:
			support=HuangzhongSupport.new(); support.name="HuangzhongSupport"; add_child(support); support.setup(world,marker)
	if world.stage=="hs_return":
		var config=world.definition.tactics
		points=config.waypoints; stops=config.stops
		cart=Cart.new(); cart.world=world; cart.name="GrainCart"
		cart.cruise_speed=float(config.get("cart_speed",112.0))
		cart.catchup_speed=maxf(cart.cruise_speed,float(config.get("cart_catchup_speed",164.0)))
		cart_follow_radius=float(config.get("cart_follow_radius",520.0))
		cart_danger_radius=float(config.get("cart_danger_radius",160.0))
		var index=clampi(int(world.state.tactics.get("escort_index",0)),0,points.size()-1)
		cart.position=point(points[index]); world.actors.add_child(cart)
		if world.state.flags.cart: cart.position=point(points.back())
	elif world.stage=="hs_camp":
		restore_gate()
	elif world.stage=="hs_river":
		restore_roster()
	if world.stage not in ["hs_return","hs_camp"]: next_main(true)

func point(p) -> Vector2:
	return Vector2(p[0],p[1])

func main_groups() -> Array:
	return world.definition.get("main_groups",[])

func main_clear() -> bool:
	for id in main_groups():
		if not world.state.cleared.has(world.stage+":"+id): return false
	return true

func living_count() -> int:
	var count=0
	for enemy in world.enemies:
		if enemy.body_alive(): count+=1
	return count

func units_for(id: String) -> Array:
	for group in world.definition.groups:
		if group.id==id: return group.units
	return []

func request_group(id: String, units: Array=[], immediate: bool=false) -> void:
	if spawned.has(id) or world.state.cleared.has(world.stage+":"+id): return
	for row in waiting:
		if row.id==id: return
	var source=units_for(id) if units.is_empty() else units
	if source.is_empty(): return
	waiting.append({"id":id,"units":source.duplicate(true),"left":0.0 if immediate else 1.2,"warned":immediate,"initial":immediate,"near_hint":false})

func spawn_pending(dt: float) -> void:
	if waiting.is_empty(): return
	var row=waiting[0]
	if not row.warned:
		row.warned=true; world.fx.floater(Vector2(row.units[0][1],row.units[0][2]),"敌军将至",Color("e9b78f"))
	row.left-=dt
	if row.left>0 or living_count()+row.units.size()>8: return
	if not row.initial:
		for u in row.units:
			if world.hero.position.distance_to(Vector2(u[1],u[2]))<160:
				if not row.near_hint: row.near_hint=true; world.toast("敌军来向已标记，退开入口再迎击。")
				return
	spawned[row.id]=true; waiting.pop_front()
	for i in range(row.units.size()):
		var u=row.units[i]
		var roster_item: Dictionary={}
		if row.id=="gate_roster":
			for item in world.state.tactics.get("roster",[]):
				if item.id=="pursuer_"+str(i): roster_item=item; break
			if not roster_item.is_empty() and roster_item.hp<=0: continue
		var enemy=world.spawn_enemy(u[0],Vector2(u[1],u[2]),row.id)
		enemy.cooldown=maxf(enemy.cooldown,.8); enemy.stun=.6
		if str(row.id).begins_with("gate_"): enemy.alerted=true
		if row.id=="gate_roster":
			enemy.set_meta("roster_id","pursuer_"+str(i))
			if not roster_item.is_empty(): enemy.hp=minf(enemy.max_hp,roster_item.hp)
			enemy.set_meta("withdrawing",not world.state.tactics.get("volley_spent",false)); enemy.set_meta("retreat_target",Vector2(1480,460+i*52))

func next_main(immediate: bool=false) -> void:
	if world.stage=="hs_river" and not roster_clear(): return
	for id in main_groups():
		if world.state.cleared.has(world.stage+":"+id): continue
		if spawned.has(id): return
		var units=units_for(id)
		if units.is_empty(): return
		if immediate or world.hero.position.distance_to(Vector2(units[0][1],units[0][2]))<540: request_group(id,[],immediate)
		return

func check_groups() -> void:
	for id in spawned:
		var key=world.stage+":"+id
		if not world.state.cleared.has(key) and not world.group_alive(id):
			world.state.cleared.append(key); world.save_progress()

func advance(dt: float) -> void:
	if is_instance_valid(support): support.advance(dt)
	spawn_pending(dt); check_groups()
	if world.stage=="hs_return": advance_cart(dt)
	elif world.stage=="hs_camp": advance_gate(dt)
	else: next_main()
	for group in world.definition.groups:
		if group.id in main_groups(): continue
		if group.units.size()>0 and world.hero.position.distance_to(Vector2(group.units[0][1],group.units[0][2]))<340: request_group(group.id)
	if world.stage=="hs_river" and not world.state.flags.beacon:
		fire_clock+=dt
		if fire_clock>=9 and world.group_alive():
			fire_clock=0
			var p=world.hero.position+Vector2(0,-8)
			world.fx.add("fire_warning",p,1.3,{"radius":62.0}); fire_targets.append({"pos":p,"left":1.3})
	for target in fire_targets:
		target.left-=dt
		if target.left<=0:
			world.fx.add("explosion",target.pos,.35,{"radius":62.0}); world.sound.play_cue("ignite")
			if world.hero.position.distance_to(target.pos)<62+world.hero.radius: world.hero.take_damage(14)
	fire_targets=fire_targets.filter(func(target): return target.left>0)

func advance_cart(dt: float) -> void:
	if not is_instance_valid(cart) or not cart.body_alive() or world.state.flags.cart: return
	var index=clampi(int(world.state.tactics.get("escort_index",0)),0,points.size()-1)
	# Only the next uncleared roadblock can activate. Zhao Yun may clear it
	# ahead of the cart; the cart still cannot cross its route checkpoint.
	for stop in stops:
		if world.state.cleared.has(world.stage+":"+str(stop.group)): continue
		var units=units_for(str(stop.group))
		if index>=int(stop.index) or not units.is_empty() and world.hero.position.distance_to(Vector2(units[0][1],units[0][2]))<420:
			request_group(str(stop.group))
		if index>=int(stop.index):
			stuck=0; return
		break
	if index>=points.size()-1:
		world.state.flags.cart=true; world.state.record("粮车穿过乱石归途，撤军平安归营。")
		world.toast("粮车已到营门，靠近军旗按 E 进营。"); world.save_progress(); return
	if world.hero.position.distance_to(cart.position)>cart_follow_radius or world.nearest_enemy(cart.position,cart_danger_radius):
		stuck=0; return
	var next=point(points[index+1])
	if cart.position.distance_to(next)<7:
		world.state.tactics.escort_index=index+1
		if index+1>=3 and not world.state.tactics.get("cart_checkpoint",false):
			world.state.tactics.cart_checkpoint=true; cart.hp=cart.max_hp
			world.state.checkpoint={"stage":world.stage,"x":cart.position.x-55,"y":cart.position.y+65,"encounter":""}
			world.toast("已通过第一道路障，粮车检查点已保存。")
		world.save_progress(); return
	# Catch up only while the player is ahead along this leg, never when
	# Zhao Yun doubles back for the wounded or stands behind the cart.
	var lead=(world.hero.position-cart.position).dot((next-cart.position).normalized())
	var speed=lerpf(cart.cruise_speed,cart.catchup_speed,clampf((lead-120)/220,0,1))
	var distance=cart.travel(next,dt,speed)
	var was_stuck=stuck>3
	stuck=stuck+dt if distance<dt else 0
	if stuck>3 and not was_stuck: world.toast("粮车受阻，靠近按 E 复位到最近安全路点。")

func restore_gate() -> void:
	if gate_state!="PREPARE" and world.terrain.has_method("open_camp_gate"): world.terrain.open_camp_gate()
	if gate_state!="PREPARE" and world.state.tactics.get("deception_ok",false):
		world.command="hold"
		var guards=world.definition.tactics.guard_points
		for i in range(world.allies.size()):
			world.allies[i].position=point(guards[i]); world.allies[i].home=point(guards[i])
	match gate_state:
		"PROBE_1": request_group("gate_probe1",[["scout",1480,460],["scout",1480,540]],true)
		"PROBE_2": request_group("gate_probe2",[["ironshield",1480,660],["spear",1480,580]],true)
		"WITHDRAW","BEST_WINDOW","LATE_WINDOW":
			gate_state="WITHDRAW"
			if world.state.tactics.get("roster",[]).is_empty(): create_roster()
			else: restore_roster(true)
		"COUNTER_BEST","COUNTER_LATE","COUNTER_DIRECT": restore_roster()
	if gate_state in ["PROBE_1","PROBE_2"] and world.state.tactics.get("extra_used",false) and not world.state.cleared.has("hs_camp:gate_extra"):
		request_group("gate_extra",[["sword",1480,660],["scout",1480,740]])

func open_gate() -> bool:
	if gate_state!="PREPARE": world.toast("营门已开，照当前军令行动。"); return false
	var hidden=0; var living=0
	for ally in world.allies:
		if ally.body_alive():
			living+=1
			if hide_area().has_point(ally.position): hidden+=1
	world.state.tactics.deception_ok=hidden>0 and hidden==living and world.command=="hold"
	gate_state="PROBE_1"; world.state.checkpoint={"stage":"hs_camp","x":900.0,"y":560.0,"encounter":""}
	if world.terrain.has_method("open_camp_gate"): world.terrain.open_camp_gate()
	request_group("gate_probe1",[["scout",1480,460],["scout",1480,540]])
	world.toast("藏兵计成。赵云守门迎两次试探，随后回鼓台反击。" if world.state.tactics.deception_ok else "转为正面破围：击退两次试探，再擂鼓或追击。")
	world.save_progress(); return true

func hide_area() -> Rect2:
	var a=world.definition.get("tactics",{}).get("hide_area",[480,240,300,240])
	return Rect2(a[0],a[1],a[2],a[3])

func request_support() -> bool:
	return support.request() if is_instance_valid(support) else false

func support_status() -> Dictionary:
	return support.status() if is_instance_valid(support) else {"visible":false,"ready":false,"cooldown":0.0,"text":""}

func command_changed(order: String) -> String:
	if world.stage!="hs_camp": return ""
	if order=="hold" and gate_state=="PREPARE":
		var flag=world.object_by_id("hs_hideflag")
		if world.hero.position.distance_to(Vector2(flag.get("x",640),flag.get("y",360)))<170:
			var guards=world.definition.tactics.get("guard_points",[[560,320],[640,340],[700,400]])
			for i in range(world.allies.size()): world.allies[i].home=point(guards[i]); world.allies[i].path=[]
			return "随军前往青旗藏兵。留意任务中的就位人数，随后到营门按 E。"
	if order!="hold" and gate_state in ["PROBE_1","PROBE_2","WITHDRAW","BEST_WINDOW"]: world.state.tactics.deception_ok=false
	return ""

func advance_gate(dt: float) -> void:
	if gate_state in ["PROBE_1","PROBE_2"]:
		if not world.state.tactics.get("extra_used",false):
			for enemy in world.enemies:
				if enemy.body_alive() and enemy.group_id.begins_with("gate_probe") and enemy.position.x<1000:
					world.state.tactics.extra_used=true; request_group("gate_extra",[["sword",1480,660],["scout",1480,740]])
					for ally in world.allies:
						if ally.body_alive(): ally.set_meta("intercept",enemy); ally.set_meta("intercept_left",3.0); break
					world.toast("敌军越过门线！随军牵制，击退补救小队即可稳住。"); world.save_progress(); break
		if gate_state=="PROBE_1" and world.state.cleared.has("hs_camp:gate_probe1"):
			gate_state="PROBE_2"; request_group("gate_probe2",[["ironshield",1480,660],["spear",1480,580]])
			world.toast("试探 1 / 2 已退。下一波盾枪，绕盾侧背；结束后回鼓台。"); world.save_progress()
		elif gate_state=="PROBE_2" and world.state.cleared.has("hs_camp:gate_probe2") and (not world.state.tactics.get("extra_used",false) or world.state.cleared.has("hs_camp:gate_extra")):
			gate_state="WITHDRAW"; create_roster(); world.save_progress(); world.toast("两波已退！立即回鼓台，金圈亮起后有 4 秒战机。")
		if world.state.tactics.get("deception_ok",false):
			var present=0
			for ally in world.allies:
				if ally.body_alive():
					present+=1
					if not hide_area().has_point(ally.position) and float(ally.get_meta("intercept_left",0.0))<=0: world.state.tactics.deception_ok=false
			if present==0: world.state.tactics.deception_ok=false
			for enemy in world.enemies:
				if enemy.body_alive() and hide_area().has_point(enemy.position): world.state.tactics.deception_ok=false
	elif gate_state=="WITHDRAW":
		var arrived=true; var found=false
		for enemy in world.enemies:
			if not enemy.body_alive() or not enemy.has_meta("roster_id"): continue
			found=true
			if enemy.position.x<1430: arrived=false
		# Warning/spawn safety can pause a queued wave while Zhao Yun stands
		# in its lane. Only visible retreating soldiers consume retreat time.
		if found: retreat_time+=dt
		if found and arrived:
			gate_state="BEST_WINDOW"; best_left=4.0; world.toast("战机已至！金色鼓台亮起，按 E 擂鼓反击。")
		elif retreat_time>7: gate_state="LATE_WINDOW"; world.toast("敌阵已散，仍可擂鼓或直接追击。")
		elif not found and waiting.is_empty(): resolve_counter("DIRECT")
	elif gate_state=="BEST_WINDOW":
		best_left-=dt
		if best_left<=0: gate_state="LATE_WINDOW"; world.toast("最佳战机已过，仍可擂鼓或直接追击。")
	if gate_state in ["WITHDRAW","BEST_WINDOW","LATE_WINDOW"]:
		if world.hero.position.x>1500: resolve_counter("DIRECT")
		for enemy in world.enemies:
			if enemy.has_meta("roster_id") and enemy.hp<enemy.max_hp-.01:
				resolve_counter("DIRECT"); break

func create_roster() -> void:
	var units=[["ironshield",1320,460],["scout",1320,640],["crossbow",1410,480],["crossbow",1410,620]]
	if world.state.tactics.get("roster",[]).is_empty():
		var roster: Array=[]
		for i in range(units.size()):
			roster.append({"id":"pursuer_"+str(i),"kind":units[i][0],"hp":roster_max_hp(units[i][0])})
		world.state.tactics.roster=roster
	request_group("gate_roster",units)

func roster_max_hp(kind: String) -> float:
	if not roster_maximums.has(kind):
		# Configure without entering the scene tree, using the same enemy
		# balance/difficulty source as actual spawns; never duplicate HP tables.
		var unit=world.Enemy.instantiate(); unit.world=world; unit.configure(kind)
		roster_maximums[kind]=unit.max_hp; unit.free()
	return float(roster_maximums[kind])

func restore_roster(withdrawing: bool=false) -> void:
	var i=0
	for item in world.state.tactics.get("roster",[]):
		if item.hp<=0: continue
		var p=Vector2(1320,460+i*60) if world.stage=="hs_camp" else Vector2(620+i*80,760-i*10)
		var enemy=world.spawn_enemy(item.kind,p,"gate_roster" if withdrawing else "river_roster")
		enemy.hp=minf(enemy.max_hp,item.hp); enemy.cooldown=1; enemy.set_meta("roster_id",item.id)
		if withdrawing: enemy.set_meta("withdrawing",true); enemy.set_meta("retreat_target",Vector2(1480,460+i*52))
		i+=1
	if i>0: spawned["gate_roster" if withdrawing else "river_roster"]=true

func capture_roster() -> void:
	if world.stage not in ["hs_camp","hs_river"]: return
	# Keep identities not yet materialized by the safe-spawn queue. Without
	# this merge an immediate camp-to-river transition could erase pursuers.
	var roster: Array=world.state.tactics.get("roster",[]).duplicate(true)
	for enemy in world.enemies:
		if not enemy.has_meta("roster_id"): continue
		var entry={"id":enemy.get_meta("roster_id"),"kind":enemy.kind,"hp":maxf(0,enemy.hp)}
		var index=-1
		for i in range(roster.size()):
			if roster[i].id==entry.id: index=i; break
		if index>=0: roster[index]=entry
		else: roster.append(entry)
	if not roster.is_empty(): world.state.tactics.roster=roster

func roster_clear() -> bool:
	for enemy in world.enemies:
		if enemy.body_alive() and enemy.has_meta("roster_id"): return false
	return true

func drum() -> bool:
	if gate_state=="PREPARE": world.toast("青旗按 2 藏兵，再到营门按 E 开门。"); return false
	if gate_state in ["PROBE_1","PROBE_2"]: world.toast("先击退两次试探，再等退军战机。"); return false
	if gate_state=="WITHDRAW": world.toast("敌军还在退却，等金圈亮起再擂鼓。"); return false
	if gate_state in ["BEST_WINDOW","LATE_WINDOW"]:
		resolve_counter("BEST" if gate_state=="BEST_WINDOW" and world.state.tactics.get("deception_ok",false) else "LATE"); return true
	world.toast("军令已下，反击只能发动一次。向河湾追击。"); return false

func resolve_counter(result: String) -> void:
	if world.state.tactics.get("volley_spent",false): return
	capture_roster()
	gate_state="COUNTER_"+result; world.state.tactics.volley_spent=true
	world.state.flags.deception=result=="BEST"; world.state.flags.volley=result!="DIRECT"
	if result!="DIRECT":
		for item in world.state.tactics.get("roster",[]):
			if item.hp>0: item.hp=minf(item.hp,maxf(roster_max_hp(item.kind)*.22,item.hp-(35 if result=="BEST" else 18)))
	for enemy in world.enemies:
		if not enemy.body_alive() or not enemy.has_meta("roster_id"): continue
		enemy.set_meta("withdrawing",false)
		if result!="DIRECT":
			for item in world.state.tactics.get("roster",[]):
				if item.id==enemy.get_meta("roster_id"): enemy.hp=minf(enemy.hp,item.hp); break
			enemy.stagger+=45 if result=="BEST" else 20; enemy.stun=.8
			world.fx.add("impact",enemy.position,.4,{"radius":42.0,"gold":true})
	world.sound.play_cue("drum" if result!="DIRECT" else "phase")
	world.fx.add("rally",Vector2(820,500),1.0,{"radius":180.0}); world.command="charge"
	world.state.record("空营震敌：藏兵守门，最佳时机擂鼓反击。" if result=="BEST" else "赵云率军正面破围。")
	capture_roster(); world.save_progress()
	world.toast("擂鼓反击！东门按 E 追向河湾，受创敌军状态保留。" if result!="DIRECT" else "正面破围，东门已开放。")

func interact_object(object: Dictionary) -> bool:
	match object.kind:
		"gate": return open_gate()
		"drum": return drum()
		"hideflag": world.set_command("hold"); return true
		"graincart":
			if is_instance_valid(cart) and stuck>3:
				cart.position=point(points[clampi(int(world.state.tactics.get("escort_index",0)),0,points.size()-1)]); stuck=0
				world.toast("粮车退回安全路点，耐久与已清遭遇保留。")
			else: world.toast(cart_mission().text)
			return true
	return false

func mission() -> Dictionary:
	if world.stage=="hs_camp":
		var rows={
			"PREPARE":["计策 · 藏兵开门","青旗按 2 藏兵再开门；也可直接开门正面破围。",Vector2(640,360)],
			"PROBE_1":["门前压阵 · 1 / 2","双刀会连斩两次，整套落空后还击。",Vector2(1140,560)],
			"PROBE_2":["门前压阵 · 2 / 2","绕过盾兵侧背，避开直线枪刺。",Vector2(1140,560)],
			"WITHDRAW":["回鼓台 · 准备反击","敌军正在退却，先回鼓台；金圈亮后有 4 秒战机。",Vector2(820,500)],
			"BEST_WINDOW":["擂鼓反击 · %.1f 秒"%best_left,"鼓台按 E，下令弩阵齐射。",Vector2(820,500)],
			"LATE_WINDOW":["仍可反击","鼓台按 E，或越过东门直接追击。",Vector2(820,500)]}
		var row=rows.get(gate_state,["乘势追击","东门按 E 进入河湾，追兵状态会保留。",Vector2(1490,560)])
		if gate_state=="PREPARE":
			var hidden=0
			for ally in world.allies:
				if ally.body_alive() and hide_area().has_point(ally.position): hidden+=1
			var living=0
			for ally in world.allies:
				if ally.body_alive(): living+=1
			if living==0: row=["正面破围","随军已倒下，营门按 E；赵云仍可独自完成反击。",Vector2(930,560)]
			elif world.command=="hold":
				row=["藏兵就位 · %d / %d"%[hidden,living],"随军自行赶往青旗，赵云可先走向营门。",Vector2(930,560)]
				if hidden==living: row=["藏兵就位 · %d / %d"%[hidden,living],"营门按 E 开门，赵云亲自迎敌。",Vector2(930,560)]
		elif gate_state in ["PROBE_1","PROBE_2"]:
			var alive=living_count()
			if alive>0: row[0]+=" · 余 %d 人"%alive
			elif not waiting.is_empty(): row[1]="下一队来向已标记，保持距离迎击；别挡住入口。"
			if not world.state.tactics.get("deception_ok",false): row[1]+=" 藏兵已暴露，仍可正面破围。"
		elif gate_state=="BEST_WINDOW" and not world.state.tactics.get("deception_ok",false):
			row=["擂鼓反击","藏兵已暴露；鼓台按 E 普通齐射，或直接追击。",Vector2(820,500)]
		return {"title":row[0],"text":row[1],"pos":row[2]}
	if world.stage=="hs_return" and not world.state.flags.cart:
		return cart_mission()
	var guard=world.first_guard(main_groups())
	if not guard and world.stage=="hs_river": guard=world.first_guard(["river_roster"])
	if guard: return {"title":"接应黄忠" if world.stage=="hs_grain" else "清开汉水军路","text":"绕盾切弩兵，看清两发再切入。","pos":guard.position}
	for id in main_groups():
		if not world.state.cleared.has(world.stage+":"+id):
			var units=units_for(id)
			if not units.is_empty(): return {"title":"沿军路前进","text":"前方有追兵，1 / 2 / 3 发布军令。","pos":Vector2(units[0][1],units[0][2])}
	var next="hs_huangzhong" if world.stage=="hs_grain" and not world.state.flags.huangzhong else "hs_dujun" if world.stage=="hs_final" and not world.state.flags.dujun else ""
	var object=world.object_by_id(next)
	if object.is_empty():
		for candidate in world.definition.objects:
			if candidate.kind in ["exit","finish"] and not str(candidate.id).begins_with("back"): object=candidate; break
	return {"title":"铁营决战" if world.stage=="hs_final" else "继续进军","text":"靠近目标按 E。决战前可以回头完成支路。","pos":Vector2(object.get("x",world.hero.position.x),object.get("y",world.hero.position.y))}

func cart_mission() -> Dictionary:
	var index=clampi(int(world.state.tactics.get("escort_index",0)),0,points.size()-1)
	var cleared=0; var next_stop: Dictionary={}
	for stop in stops:
		if world.state.cleared.has(world.stage+":"+str(stop.group)): cleared+=1
		elif next_stop.is_empty(): next_stop=stop
	var title="护粮回营 · 清路 %d / %d"%[cleared,stops.size()]
	var health="粮车 %d / %d。 "%[int(cart.hp),int(cart.max_hp)]
	var nearby=world.nearest_enemy(cart.position,cart_danger_radius)
	if nearby:
		return {"title":title,"text":health+"车旁有敌军，先击退拦车追兵。","pos":nearby.position}
	if not next_stop.is_empty() and index>=int(next_stop.index):
		var guard=world.first_guard([str(next_stop.group)])
		var units=units_for(str(next_stop.group))
		var target=guard.position if guard else Vector2(units[0][1],units[0][2]) if not units.is_empty() else cart.position
		return {"title":title,"text":health+"前方路障未清，击退这队敌军即可继续。","pos":target}
	if world.hero.position.distance_to(cart.position)>cart_follow_radius:
		return {"title":"粮车等待接应","text":health+"你离队太远，返回粮车附近；已清路障保留。","pos":cart.position}
	if stuck>3:
		return {"title":"粮车受阻","text":health+"靠近粮车按 E 复位，耐久与清路进度保留。","pos":cart.position}
	if not next_stop.is_empty():
		var units=units_for(str(next_stop.group))
		if not units.is_empty():
			return {"title":title,"text":health+"可先去前方清路，粮车会沿安全路段追上。","pos":Vector2(units[0][1],units[0][2])}
	return {"title":"道路已清 · 护粮入营","text":health+"沿道路到营门，留在粮车附近即可加速跟进。","pos":point(points.back())}
