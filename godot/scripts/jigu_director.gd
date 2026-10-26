extends Node2D
## Finite encounters and player-issued retreat orders for Jigu. All transient
## warnings restart on entry; durable progress lives in ordinary chapter flags.
const SPAWN_WARNING = 1.2
const LIVE_LIMIT = 8
const TASK_TEXT = {
	"jg_banner":["号旗已夺，崖台箭阵停止。","赵云夺下崖台号旗，敌方箭阵失去号令。"],
	"jg_dispatch":["军报已收回，石门第二波少一名弩兵。","失落军报被找回，石门侧翼弩兵先行撤走。"],
	"jg_front":["前队已撤，沿栈道去第二面军旗。","赵云在第一面集结旗下发令，前队沿栈道撤出。"],
	"jg_rear":["两队已撤，前往石门收拢后军。","第二道撤令已下，后队穿过断崖栈道。"],
	"jg_rearguard":["石门追兵已退，后军向危桥转移。","两波追兵被击退，石门后军得以收拢。"],
	"jg_supplies":["辎重归队，谷口营火可多领一份行军药。","辎重兵与药械归队，为谷口决战留下一次补给。"],
	"jg_last_guard":["末队归来，前往谷口决战。","赵云留桥击退追兵，将最后一队军士接回。"]
}
var world
var cart = null
var spawned: Dictionary = {}
var waiting: Array = []
var arrow_clock = 0.0
var arrow_warnings: Array = []
var ranged_hazard_hold = 0.0
var volleys_fired = 0
var march_signals: Array = []
var bridge_effect_left = 0.0

func arrival_notice() -> String:
	return "追兵将至"

func setup(game) -> void:
	world = game; z_index = 9
	spawned.clear(); waiting.clear(); arrow_warnings.clear(); arrow_clock = 0; ranged_hazard_hold = 0
	next_main(true)
	if world.stage == "jg_bridge" and flag("jg_bridge_held") and not group_cleared("jg_bridge_extra"):
		request_group("jg_bridge_extra")

func flag(key: String) -> bool:
	if key.is_empty(): return true
	if key == "bridge_resolved": return flag("jg_bridge_cut") or flag("jg_bridge_held") and flag("jg_last_guard")
	return bool(world.state.flags.get(key,false))

func main_groups() -> Array:
	return world.definition.get("main_groups",[])

func group_definition(id: String) -> Dictionary:
	for group in world.definition.get("groups",[]):
		if group.id == id: return group
	return {}

func group_cleared(id: String) -> bool:
	return world.state.cleared.has(world.stage+":"+id)

func main_clear() -> bool:
	for id in main_groups():
		if not group_cleared(str(id)): return false
	return true

func living_count() -> int:
	var count = 0
	for enemy in world.enemies:
		if is_instance_valid(enemy) and enemy.body_alive(): count += 1
	return count

func units_for(id: String) -> Array:
	var group = group_definition(id)
	var result: Array = group.get("units",[]).duplicate(true)
	if group.has("reduce_if") and flag(str(group.reduce_if)):
		for i in range(result.size()):
			if str(result[i][0]) == str(group.get("reduce_kind","crossbow")):
				result.remove_at(i); break
	return result

func request_group(id: String) -> void:
	if spawned.has(id) or group_cleared(id): return
	var definition = group_definition(id)
	if definition.is_empty() or not flag(str(definition.get("need",""))): return
	for row in waiting:
		if row.id == id: return
	var units = units_for(id)
	if units.is_empty(): return
	waiting.append({"id":id,"units":units,"left":SPAWN_WARNING,"warned":false,"near_hint":false})

func next_main(first: bool = false) -> void:
	for id in main_groups():
		if group_cleared(str(id)): continue
		if spawned.has(id): return
		var units = units_for(str(id))
		if not units.is_empty() and (first or world.hero.position.distance_to(Vector2(units[0][1],units[0][2])) < 560):
			request_group(str(id))
		return

func spawn_pending(dt: float) -> void:
	if world.mode != "playing" or not world.active_boss.is_empty() or waiting.is_empty(): return
	var row = waiting[0]
	if not row.warned:
		row.warned = true
		world.fx.floater(Vector2(row.units[0][1],row.units[0][2]),arrival_notice(),Color("efbd97"))
		# Never consume a brand-new warning in the same long frame that shows it.
		return
	row.left = maxf(0,row.left-maxf(0,dt))
	if row.left > 0 or living_count()+row.units.size() > LIVE_LIMIT: return
	for unit in row.units:
		if world.hero.position.distance_to(Vector2(unit[1],unit[2])) < 160:
			if not row.near_hint:
				row.near_hint = true; world.toast("追兵来路已标记，退开入口再迎击。")
			return
	waiting.pop_front(); spawned[row.id] = true
	for unit in row.units:
		var enemy = world.spawn_enemy(unit[0],Vector2(unit[1],unit[2]),row.id)
		enemy.cooldown = maxf(enemy.cooldown,.8); enemy.stun = .6
		if world.stage == "jg_rearguard" or row.id == "jg_bridge_extra": enemy.alerted = true

func check_groups() -> void:
	if world.mode != "playing": return
	for id in spawned:
		if not group_cleared(str(id)) and not world.group_alive(str(id)):
			world.state.cleared.append(world.stage+":"+str(id)); world.save_progress()

func advance(dt: float) -> void:
	if world.mode != "playing": return
	if not world.active_boss.is_empty():
		arrow_warnings.clear(); arrow_clock = 0; ranged_hazard_hold = 0; queue_redraw(); return
	var step = maxf(0,dt)
	spawn_pending(step); check_groups(); next_main()
	for id in world.definition.get("optional_groups",[]):
		var group = group_definition(str(id)); var units = units_for(str(id))
		if group.get("manual",false) or units.is_empty(): continue
		if world.hero.position.distance_to(Vector2(units[0][1],units[0][2])) < 340: request_group(str(id))
	advance_arrow_array(step)
	for cue in march_signals: cue.left -= step
	march_signals = march_signals.filter(func(cue): return cue.left > 0)
	bridge_effect_left = maxf(0,bridge_effect_left-step)
	queue_redraw()

func active_main_fight() -> bool:
	for id in main_groups():
		if world.group_alive(str(id)): return true
	return false

func ranged_hazard_active() -> bool:
	# A telegraphed array owns the ranged pressure slot through release and a
	# short travel window. Pausing freezes this reservation with its warning.
	return not arrow_warnings.is_empty() or ranged_hazard_hold > 0

func ranged_action_busy() -> bool:
	for enemy in world.enemies:
		if is_instance_valid(enemy) and enemy.body_alive() and enemy.is_ranged() and not enemy.action.is_empty(): return true
	return false

func advance_arrow_array(dt: float) -> void:
	if world.mode != "playing": return
	if world.stage != "jg_signal" or flag("jg_banner") or not world.active_boss.is_empty():
		arrow_warnings.clear(); arrow_clock = 0; ranged_hazard_hold = 0; return
	var step = maxf(0,dt)
	ranged_hazard_hold = maxf(0,ranged_hazard_hold-step)
	if not active_main_fight():
		arrow_warnings.clear(); arrow_clock = 0; return
	var config: Dictionary = world.definition.get("tactics",{})
	var pending: Array = []
	for warning in arrow_warnings:
		warning.left -= step
		if warning.left > 0: pending.append(warning); continue
		var attack = world.new_action("jigu_arrow_array",{"damage":float(config.get("arrow_damage",12))},warning.dir)
		# fire_arrow and advance_arrows remain the sole projectile/hit path.
		world.fire_arrow({"position":warning.origin-Vector2(0,-8)},attack)
		volleys_fired += 1
		ranged_hazard_hold = .75
	arrow_warnings = pending
	var interval = float(config.get("arrow_interval",7.0))
	arrow_clock = minf(interval,arrow_clock+step)
	if arrow_clock < interval or ranged_hazard_active() or ranged_action_busy(): return
	arrow_clock = 0
	var duration = maxf(1.2,float(config.get("arrow_warning",1.2)))
	for point in config.get("arrow_origins",[]):
		var origin = Vector2(point[0],point[1])
		if origin.distance_to(world.hero.position) > 780: continue
		var ray = PhysicsRayQueryParameters2D.create(origin,world.hero.position,1)
		if not world.get_world_2d().direct_space_state.intersect_ray(ray).is_empty(): continue
		arrow_warnings.append({"origin":origin,"dir":(world.hero.position-origin).angle(),"left":duration,"total":duration})
	if not arrow_warnings.is_empty(): world.fx.floater(world.hero.position,"箭阵锁向 · 侧闪避开",Color("efb28f"))

func task_object(task: String) -> Dictionary:
	for object in world.definition.get("objects",[]):
		if object.get("task","") == task: return object
	return {}

func object_blocked(object: Dictionary) -> bool:
	if not flag(str(object.get("need",""))) or not flag(str(object.get("need_secondary",""))): return true
	if object.has("group") and not group_cleared(str(object.group)): return true
	var task = str(object.get("task",""))
	if task == "bridge_choice":
		return not flag("jg_front") or not flag("jg_rear") or not flag("jg_rearguard") or not main_clear()
	if task in ["jg_banner","jg_rearguard"] and not main_clear(): return true
	if task == "jg_rearguard" and not flag("jg_rear"): return true
	if task == "jg_last_guard" and not flag("jg_bridge_held"): return true
	if object.get("kind","") in ["boss","finish"]: return not main_clear()
	if object.get("kind","") == "exit" and not str(object.get("id","")).begins_with("jg_back"):
		return not main_clear()
	return false

func interaction_text(object: Dictionary) -> String:
	if object.is_empty(): return ""
	var task = str(object.get("task",""))
	if task == "bridge_choice" and (flag("jg_bridge_cut") or flag("jg_bridge_held")): return "退路已定 · 沿当前军令前进"
	if TASK_TEXT.has(task) and flag(task): return "此处已完成 · 继续进军"
	if object_blocked(object):
		if object.get("need","") == "bridge_resolved": return "先完成桥头决定与接应"
		if object.get("need","") == "jg_front": return "先到第一面军旗按 E 发令"
		if object.get("need","") == "jg_rear": return "先完成两次撤军军令"
		if object.get("need","") == "jg_bridge_held": return "留桥后方可接应末队"
		return "先完成当前目标 · 跟随金色指引"
	return str(object.get("label","靠近按 E"))

func save_task_checkpoint() -> void:
	world.state.checkpoint = {"stage":world.stage,"x":world.hero.position.x,"y":world.hero.position.y,"encounter":""}
	world.save_progress()

func interact_object(object: Dictionary) -> bool:
	var task = str(object.get("task",""))
	if task != "bridge_choice" and not TASK_TEXT.has(task): return false
	if world.mode != "playing": return false
	if object_blocked(object): world.toast(interaction_text(object)); return false
	if task == "bridge_choice":
		if flag("jg_bridge_cut") or flag("jg_bridge_held"):
			world.toast(interaction_text(object)); return true
		world.dialog("断索危桥 · 退路由你定","前后两队与石门后军已经撤出。桥西仍有最后一队军士，也有追兵。\n\n断索能截掉一名谷口弩兵；留桥须再打两名追兵，随后接回末队。\n\n确认后将向谷口收尾，不能再返回前区补军报或辎重。",[
			{"text":"断索截敌","detail":"减少谷口一名弩兵，直接进入决战准备。","route":"jigu:cut"},
			{"text":"留桥接应","detail":"击退两名追兵，再按 E 接回末队。","route":"jigu:hold"},
			{"text":"先回头整备","detail":"保留当前进度，尚不决定退路。","route":"continue"}],"赵云 · 断后军令")
		return true
	if flag(task): world.toast("此处已经完成，沿军旗继续前进。"); return true
	world.state.flags[task] = true
	world.state.record(TASK_TEXT[task][1]); world.toast(TASK_TEXT[task][0])
	var p = Vector2(object.x,object.y)
	world.fx.add("rally",p,.7,{"radius":65.0}); world.sound.play_cue("phase")
	if task == "jg_banner": arrow_warnings.clear(); arrow_clock = 0; ranged_hazard_hold = 0
	if task in ["jg_front","jg_rear","jg_rearguard","jg_last_guard"]:
		# A brief pennant/departure cue, not a second escort or hidden NPC timer.
		march_signals.append({"pos":p,"left":1.1})
	var marker = world.actors.get_node_or_null(str(object.id))
	if marker: marker.queue_redraw()
	save_task_checkpoint(); next_main(); queue_redraw(); return true

func choose_bridge(cut: bool) -> bool:
	if world.stage != "jg_bridge" or world.mode not in ["playing","dialog"]: return false
	if flag("jg_bridge_cut") or flag("jg_bridge_held"): return false
	var object = task_object("bridge_choice")
	if object.is_empty() or object_blocked(object): return false
	world.state.flags["jg_bridge_cut" if cut else "jg_bridge_held"] = true
	if cut:
		world.state.record("赵云斩断危桥绳索，截住一股追兵，谷口少一名弩兵。")
		world.toast("断索截敌，谷口少一名弩兵。沿东岸前往决战。"); bridge_effect_left = 1.0
		world.sound.play_cue("swing")
	else:
		world.state.record("赵云选择留桥接应，亲自迎击桥西最后一队追兵。")
		world.toast("留桥接应！击退桥西两名追兵，再到东岸军旗按 E。"); request_group("jg_bridge_extra")
		world.sound.play_cue("phase")
	save_task_checkpoint()
	var marker = world.actors.get_node_or_null(str(object.id))
	if marker: marker.queue_redraw()
	queue_redraw(); return true

func claim_supplies() -> bool:
	if world.stage != "jg_final" or not flag("jg_supplies") or flag("jg_supply_claimed"): return false
	world.hero.potions = mini(4,world.hero.potions+1); world.state.flags.jg_supply_claimed = true
	world.state.record("谷口营火领取了辎重的一次行军药补给。")
	world.toast("辎重补给已领取 · 行军药 %d / 4"%world.hero.potions); world.save_progress(); return true

func command_changed(order: String) -> String:
	if order == "hold": return "随军守住当前安全位置；赵云可前出切弩兵，清路后到军旗按 E。"
	return ""

func capture_roster() -> void:
	pass

func support_status() -> Dictionary:
	return {"visible":false,"ready":false,"cooldown":0.0,"text":""}

func request_support() -> bool:
	return false

func combat_tip(id: String) -> String:
	var kinds: Array = []
	for enemy in world.enemies:
		if enemy.body_alive() and enemy.group_id == id and not kinds.has(enemy.kind): kinds.append(enemy.kind)
	var bridge_fight = id in ["jg_b1","jg_bridge_extra"]
	if "crossbow" in kinds:
		return "桥面先侧闪弩箭，趁两发后的装填间隙切近。" if bridge_fight else "沿石壁侧路切近弩兵，等整套收招后还击。"
	if "ironshield" in kinds:
		return "桥面留出侧闪空间，绕到铁盾侧背再出枪。" if bridge_fight else "绕铁盾侧背，等冲撞收势后再还击。"
	if "scout" in kinds and "spear" in kinds:
		return "桥面留出侧闪空间；避开双刀连斩与直线枪刺，等收招再反击。" if bridge_fight else "双刀会连斩两次；侧闪避开直线枪刺，在收招时反击。"
	if "scout" in kinds: return "留出闪避空间，等双刀两次连斩结束再反击。"
	if "spear" in kinds: return "侧闪避开直线枪刺，趁敌军收枪时切近反击。"
	return "留出闪避空间，看清敌军出手，等收招时还击。"

func combat_mission(id: String, title: String) -> Dictionary:
	var enemy = world.first_guard([id])
	if enemy: return {"title":title,"text":combat_tip(id),"pos":enemy.position}
	var units = units_for(id); var p = world.hero.position
	if not units.is_empty(): p = Vector2(units[0][1],units[0][2])
	var text = "沿军路靠近前方追兵，先看清来向再出枪。"
	for row in waiting:
		if row.id == id:
			text = "退开标记入口，留出追兵来路，再迎击。" if row.near_hint else "追兵来向已标记，准备迎击。"
	return {"title":title,"text":text,"pos":p}

func object_mission(task: String, title: String, text: String) -> Dictionary:
	var object = task_object(task)
	return {"title":title,"text":text,"pos":Vector2(object.get("x",world.hero.position.x),object.get("y",world.hero.position.y))}

func mission() -> Dictionary:
	if world.stage == "jg_pass":
		if not group_cleared("jg_p1"): return combat_mission("jg_p1","第一段栈道 · 清开撤路")
		if not flag("jg_front"): return object_mission("jg_front","第一队等待军令","第一面集结旗按 E，亲自发令撤军。")
		if not group_cleared("jg_p2"): return combat_mission("jg_p2","前队已撤 · 清第二段")
		if not flag("jg_rear"): return object_mission("jg_rear","第二队等待军令","第二面集结旗按 E，两次撤令都由你下达。")
	else:
		for id in main_groups():
			if not group_cleared(str(id)):
				var title = "击退旗台守军" if world.stage == "jg_signal" else "石门追击 · 1 / 2" if id == "jg_r1" else "石门追击 · 2 / 2" if id == "jg_r2" else "清开谷口前哨" if world.stage == "jg_final" else "清开崖侧军路"
				return combat_mission(str(id),title)
	if world.stage == "jg_signal" and not flag("jg_banner"): return object_mission("jg_banner","夺旗破弩","靠近号旗按 E，停掉崖台箭阵。")
	if world.stage == "jg_rearguard" and not flag("jg_rearguard"): return object_mission("jg_rearguard","石门追兵已退","到军旗按 E 收拢后军，再前往危桥。")
	if world.stage == "jg_bridge":
		if not flag("jg_bridge_cut") and not flag("jg_bridge_held"): return object_mission("bridge_choice","断索还是留桥","东岸桥柱按 E。决定前仍可回头补支线。")
		if flag("jg_bridge_held") and not flag("jg_last_guard"):
			if not group_cleared("jg_bridge_extra"): return combat_mission("jg_bridge_extra","留桥接应 · 击退最后追兵")
			return object_mission("jg_last_guard","桥头已清 · 接回末队","东岸军旗按 E 接应，末队归来后前往谷口。")
	var desired = "boss" if world.stage == "jg_final" and not flag("jg_boss") else "finish" if world.stage == "jg_final" else "exit"
	for object in world.definition.get("objects",[]):
		if object.kind == desired and not str(object.id).begins_with("jg_back"):
			return {"title":"玄甲先锋 · 最后一战" if desired == "boss" else "收军 · 箕谷战报" if desired == "finish" else "沿军旗继续撤出","text":"营火整备后，靠近按 E。" if desired == "boss" else "靠近军旗按 E。","pos":Vector2(object.x,object.y)}
	return {"title":"跟随撤军路线","text":"沿石路前行，寻找下一面军旗。","pos":world.hero.position}

func _draw() -> void:
	if not world or world.mode not in ["playing","pause","map"]: return
	for warning in arrow_warnings:
		var origin: Vector2 = warning.origin
		var end = origin+Vector2.from_angle(warning.dir)*840
		var ray = PhysicsRayQueryParameters2D.create(origin,end,1)
		var hit = world.get_world_2d().direct_space_state.intersect_ray(ray)
		if not hit.is_empty(): end = hit.position
		var progress = 1-warning.left/warning.total
		draw_line(origin,end,Color(.8,.2,.14,.13),32,true)
		draw_line(origin,end,Color(.94,.32,.18,.65+.3*progress),1.8,true)
		draw_circle(origin,4+progress*3,Color("f7bc7d"))
	for cue in march_signals:
		var elapsed = 1.1-float(cue.left)
		for i in range(3):
			var p: Vector2 = cue.pos+Vector2(-35+i*23,-22-elapsed*48)
			var tint = Color(.78,.88,.72,float(cue.left)/1.1*.7)
			draw_line(p,p+Vector2(0,-19),tint,2,true)
			draw_colored_polygon(PackedVector2Array([p+Vector2(0,-19),p+Vector2(13,-15),p+Vector2(0,-10)]),tint)
	if bridge_effect_left > 0:
		var object = task_object("bridge_choice")
		var center = Vector2(object.get("x",1200),object.get("y",490))
		var elapsed = 1-bridge_effect_left
		for side in [-1,1]:
			var start = center+Vector2(side*12,-16)
			draw_line(start,start+Vector2(side*38,elapsed*55),Color(.78,.65,.42,bridge_effect_left),3,true)
