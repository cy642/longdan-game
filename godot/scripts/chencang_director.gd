extends "res://scripts/jigu_director.gd"
## Chencang owns its tasks and route rules. The proven finite queue, spawn
## warnings and ranged reservation primitives are shared with Jigu.
const CC_TASKS = {
	"cc_breach":["关旗已夺，沿砖道登上烽台。","赵云夺下外城关旗，打开了夜袭的第一段进路。"],
	"cc_beacon_out":["烽火已熄，楼台箭阵停止。","赵云熄灭烽火，切断楼台箭阵的号令。"],
	"cc_orders":["调令已收，前往仓院。","赵云从烽台西厢取回守军调令。"],
	"cc_street_done":["内街已通，前往仓院。","赵云沿选定路线打通内街，守军阵容出现了缺口。"],
	"cc_warehouse":["械库已封存，前往瓮城。","赵云夺下仓院，封存了守军的兵械。"],
	"cc_workers":["工匠获救，仓院东侧小门可通往瓮城后侧。","工匠从仓院获救，打开了瓮城东南的侧门与整备路线。"],
	"cc_courtyard":["内城军旗已控，鼓楼就在前方。","赵云穿过瓮城，守军退向鼓楼。"]
}
var arrays_started = 0

func arrival_notice() -> String:
	return "守军将至"

func setup(game) -> void:
	world=game; z_index=9
	spawned.clear(); waiting.clear(); arrow_warnings.clear(); arrow_clock=0
	ranged_hazard_hold=0; arrays_started=0; volleys_fired=0
	next_main(true)

func flag(key: String) -> bool:
	return key.is_empty() or bool(world.state.flags.get(key,false))

func main_groups() -> Array:
	if world.stage=="cc_street":
		if flag("cc_route_front"): return world.definition.route_groups.front
		if flag("cc_route_flank"): return world.definition.route_groups.flank
		return []
	var result: Array=world.definition.get("main_groups",[]).duplicate()
	if world.stage=="cc_store" and (not flag("cc_orders") or flag("cc_reserve_called")):
		result.append("cc_w_reserve")
	return result

func main_clear() -> bool:
	if world.stage=="cc_street" and not flag("cc_route_front") and not flag("cc_route_flank"): return false
	for id in main_groups():
		if not group_cleared(str(id)): return false
	return true

func units_for(id: String) -> Array:
	var group=group_definition(id)
	var result: Array=group.get("units",[]).duplicate(true)
	if id=="cc_c2":
		var kind=str(group.get("route_reduce",{}).get("front" if flag("cc_route_front") else "flank",""))
		for i in range(result.size()):
			if str(result[i][0])==kind: result.remove_at(i); break
	return result

func request_group(id: String) -> void:
	if id=="cc_w_reserve" and flag("cc_orders") and not flag("cc_reserve_called"): return
	var group=group_definition(id)
	if group.has("after_group") and not group_cleared(str(group.after_group)): return
	if id=="cc_w_reserve" and not group_cleared("cc_w2"): return
	if world.stage=="cc_street" and id not in main_groups(): return
	super.request_group(id)

func spawn_pending(dt: float) -> void:
	if flag("cc_orders") and not flag("cc_reserve_called"):
		waiting=waiting.filter(func(row): return row.id!="cc_w_reserve")
	var reserve_existed=spawned.has("cc_w_reserve")
	super.spawn_pending(dt)
	if not reserve_existed and spawned.has("cc_w_reserve"):
		world.state.flags.cc_reserve_called=true
		world.state.record("仓院援军已经到场，之后补取调令不会让这支守军消失。")
		world.save_progress()

func advance_arrow_array(dt: float) -> void:
	if world.mode!="playing": return
	if world.stage!="cc_beacon" or flag("cc_beacon_out") or not world.active_boss.is_empty():
		arrow_warnings.clear(); arrow_clock=0; ranged_hazard_hold=0; return
	var step=maxf(0,dt); ranged_hazard_hold=maxf(0,ranged_hazard_hold-step)
	if not active_main_fight(): arrow_warnings.clear(); arrow_clock=0; return
	var config: Dictionary=world.definition.get("tactics",{})
	var pending: Array=[]
	for warning in arrow_warnings:
		warning.left-=step
		if warning.left>0: pending.append(warning); continue
		var attack=world.new_action("chencang_arrow_array",{"damage":float(config.get("arrow_damage",12))},warning.dir)
		world.fire_arrow({"position":warning.origin-Vector2(0,-8)},attack)
		volleys_fired+=1; ranged_hazard_hold=.75
	arrow_warnings=pending
	var interval=maxf(4.0,float(config.get("arrow_interval",8)))
	arrow_clock=minf(interval,arrow_clock+step)
	if arrays_started>=int(config.get("arrow_limit",3)) or arrow_clock<interval or ranged_hazard_active() or ranged_action_busy(): return
	var duration=maxf(1.25,float(config.get("arrow_warning",1.25)))
	for point in config.get("arrow_origins",[]):
		if arrow_warnings.size()>=2: break
		var origin=Vector2(point[0],point[1])
		if origin.distance_to(world.hero.position)>780: continue
		var ray=PhysicsRayQueryParameters2D.create(origin,world.hero.position,1)
		if not world.get_world_2d().direct_space_state.intersect_ray(ray).is_empty(): continue
		arrow_warnings.append({"origin":origin,"dir":(world.hero.position-origin).angle(),"left":duration,"total":duration})
	if not arrow_warnings.is_empty():
		arrays_started+=1; arrow_clock=0
		world.fx.floater(world.hero.position,"楼台箭路 · 沿墙侧闪",Color("efb28f"))

func object_blocked(object: Dictionary) -> bool:
	if not flag(str(object.get("need",""))) or not flag(str(object.get("need_secondary",""))): return true
	if str(object.get("id","")).begins_with("cc_back") and flag("cc_committed"): return true
	if object.has("group") and not group_cleared(str(object.group)): return true
	var task=str(object.get("task",""))
	if task=="route_choice": return not flag("cc_beacon_out")
	if task in ["cc_breach","cc_beacon_out","cc_street_done","cc_warehouse","cc_courtyard"] and not main_clear(): return true
	if object.get("kind","") in ["boss","finish"]: return not main_clear()
	if object.get("kind","")=="exit" and not str(object.get("id","")).begins_with("cc_back"): return not main_clear()
	return false

func interaction_text(object: Dictionary) -> String:
	var task=str(object.get("task",""))
	if task=="route_choice" and (flag("cc_route_front") or flag("cc_route_flank")): return "进路已定 · 沿军旗继续"
	if flag("cc_committed") and str(object.get("id","")).begins_with("cc_back"): return "鼓楼决战已开始 · 先收军旗"
	if object_blocked(object):
		if object.get("need_secondary","")=="cc_workers" or object.get("need","")=="cc_workers": return "先救出仓院工匠，开启侧门整备路线"
		return "先完成当前目标 · 跟随金色指引"
	if task=="cc_orders": return "取回调令 · 援军已到，仍须亲自击退" if flag("cc_reserve_called") else "取回调令 · 阻断仓院援军"
	return str(object.get("label","靠近按 E"))

func interact_object(object: Dictionary) -> bool:
	if world.mode!="playing": return false
	var task=str(object.get("task",""))
	if task!="route_choice" and not CC_TASKS.has(task): return false
	if object_blocked(object): world.toast(interaction_text(object)); return false
	if task=="route_choice":
		if flag("cc_route_front") or flag("cc_route_flank"): return false
		world.dialog("城门内街 · 自选进路","正门较短，盾、矛与弩守在一处；侧巷较长，会先后遇到两支小队。\n\n破开正门后，瓮城少一名重盾；截住侧巷援兵后，瓮城少一名弩手。两条路都能到达仓院。\n\n确认后保留本次选择，重玩第四章可走另一线。",[
			{"text":"正门破阵","detail":"短路一战3人；瓮城第二波少一名重盾。","route":"chencang:front"},
			{"text":"侧巷截援","detail":"长路两战各2人；瓮城第二波少一名弩手。","route":"chencang:flank"},
			{"text":"先观察地形","detail":"暂不选择，沿墙角看看两条进路。","route":"continue"}],"赵云 · 夜袭军令")
		return true
	if flag(task): return false
	world.state.flags[task]=true; world.state.record(CC_TASKS[task][1]); world.toast(CC_TASKS[task][0])
	if task=="cc_beacon_out": arrow_warnings.clear(); arrow_clock=0; ranged_hazard_hold=0
	if task=="cc_orders": world.toast("调令来迟，已到场援军仍需击退。" if flag("cc_reserve_called") else "调令已截，仓院援军不会到场。")
	world.fx.add("rally",Vector2(object.x,object.y),.7,{"radius":55.0}); world.sound.play_cue("phase")
	var marker=world.actors.get_node_or_null(str(object.id))
	if marker: marker.queue_redraw()
	save_task_checkpoint(); next_main(); queue_redraw(); return true

func choose_route(front: bool) -> bool:
	if world.stage!="cc_street" or world.mode!="playing" or flag("cc_route_front") or flag("cc_route_flank"): return false
	var object=task_object("route_choice")
	if object.is_empty() or object_blocked(object): return false
	world.state.flags["cc_route_front" if front else "cc_route_flank"]=true
	world.state.record("赵云选择正门破阵，攻破重盾阵后削弱瓮城盾卫。" if front else "赵云选择侧巷截援，分两战清路后削弱瓮城弩兵。")
	world.toast("正门破阵 · 沿东侧短路，绕盾切弩。" if front else "侧巷截援 · 沿西侧长路，先清第一支小队。")
	save_task_checkpoint(); next_main(true); return true

func combat_tip(_id: String) -> String:
	return "利用墙角切近弩手，绕重盾侧背；等整套收招再还击。"

func combat_mission(id: String, title: String) -> Dictionary:
	var result = super.combat_mission(id,title)
	result.text = str(result.text).replace("追兵","守军").replace("军路","城街")
	return result

func command_changed(order: String) -> String:
	return "随军守住墙角；赵云绕侧近身，清场后亲自完成军令。" if order=="hold" else ""

func mission() -> Dictionary:
	if world.stage=="cc_street" and not flag("cc_route_front") and not flag("cc_route_flank"):
		return object_mission("route_choice","正门，还是侧巷","在入口军旗下按 E，选择这次夜袭的进路。")
	for id in main_groups():
		if not group_cleared(str(id)):
			var title="仓院援军 · 亲自击退" if id=="cc_w_reserve" else "侧巷截援 · 第二队" if id=="cc_s_flank2" else "正门破阵" if id=="cc_s_front" else "瓮城守军 · 收拢阵线" if world.stage=="cc_bastion" else "清开夜袭进路"
			return combat_mission(str(id),title)
	var task={"cc_outer":"cc_breach","cc_beacon":"cc_beacon_out","cc_street":"cc_street_done","cc_store":"cc_warehouse","cc_bastion":"cc_courtyard"}.get(world.stage,"")
	if task!="" and not flag(task):
		# Two street objects share the completed flag; only the chosen one is a target.
		for object in world.definition.objects:
			if object.get("task","")==task and flag(str(object.get("need",""))):
				return {"title":str(object.label),"text":"靠近按 E，亲自完成当前军令。","pos":Vector2(object.x,object.y)}
	var desired="boss" if world.stage=="cc_final" and not flag("cc_boss") else "finish" if world.stage=="cc_final" else "exit"
	for object in world.definition.objects:
		if object.kind==desired and not str(object.id).begins_with("cc_back") and not object.has("need_secondary"):
			return {"title":"镇关都尉 · 鼓楼决战" if desired=="boss" else "收旗 · 陈仓战报" if desired=="finish" else "沿城街继续夜袭","text":"先在营火整备，再靠近按 E。" if desired=="boss" else "靠近军旗按 E。","pos":Vector2(object.x,object.y)}
	return {"title":"寻找下一道军旗","text":"沿亮处城街前行。","pos":world.hero.position}
