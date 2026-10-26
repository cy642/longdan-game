extends RefCounted
## Persistent chapter state. Runtime combat and animations belong to the scene.
const FLAGS = ["mountain", "civilians", "healer", "temple", "sword", "adou", "house", "mother", "motherDecision", "supplies", "elite", "boss", "committed"]
const SAVE_PATH = "user://longdan-godot-v2.json"
const LEGACY_PATH = "user://longdan-godot-v1.json"
const HANSHUI_FLAGS = ["huangzhong", "wounded", "beacon", "cart", "dujun", "deception", "volley", "huilan"]
const JIGU_FLAGS = ["jg_banner","jg_dispatch","jg_front","jg_rear","jg_rearguard","jg_supplies","jg_bridge_cut","jg_bridge_held","jg_last_guard","jg_boss","jg_supply_claimed"]
const CHENCANG_FLAGS = ["cc_breach","cc_beacon_out","cc_orders","cc_route_front","cc_route_flank","cc_street_done","cc_reserve_called","cc_warehouse","cc_workers","cc_courtyard","cc_committed","cc_boss"]
const CHAPTER_STAGES = {1:["mountain", "village", "temple", "house", "fork", "bridge"], 2:["hs_forest", "hs_grain", "hs_return", "hs_camp", "hs_river", "hs_final"], 3:["jg_fog","jg_signal","jg_pass","jg_rearguard","jg_bridge","jg_final"], 4:["cc_outer","cc_beacon","cc_street","cc_store","cc_bastion","cc_final"]}
const CHAPTER_NAMES = {1:"长坂逆命",2:"汉水孤营",3:"箕谷断后",4:"陈仓夜袭"}
const BATTLE_ARTS = {
	"assault":{"name":"连锋","detail":"第三枪命中积 2 格枪势。适合打满三式，再用强化横扫破阵。"},
	"counter":{"name":"游龙","detail":"精准闪避积 2 格枪势，回马枪命中回 12 气力。适合闪避反击。"}
}
var chapter = 1
var chapters: Dictionary = {}
var rewards={"huilan":false}
var tactics: Dictionary = {}
var flags: Dictionary = {}
var cleared: Array = []
var seen: Array = []
var history: Array = []
var difficulty = "normal"
var battle_art = ""
var checkpoint = {"stage": "mountain", "x": 190.0, "y": 910.0, "encounter": ""}
var route = "bridge"
var time = 0.0
var kills = 0
var precision_count = 0
var complete = false
var durable = true
var last_save: Dictionary = {}
var save_path = SAVE_PATH

func _init() -> void:
	reset()

func reset(level: String = "normal", chapter_id: int = 1) -> void:
	chapter = chapter_id
	difficulty = "story" if level == "story" else "normal"
	battle_art = ""
	flags.clear()
	for key in FLAGS:
		flags[key] = false
	for key in HANSHUI_FLAGS: flags[key] = false
	for key in JIGU_FLAGS: flags[key] = false
	for key in CHENCANG_FLAGS: flags[key] = false
	if chapter >= 2: flags.sword = true; flags.temple = true
	tactics = {}
	cleared = []; seen = []; history = []
	checkpoint = {"stage": "mountain", "x": 190.0, "y": 910.0, "encounter": ""}
	if chapter == 2: checkpoint = {"stage":"hs_forest", "x":200.0, "y":900.0, "encounter":""}
	if chapter == 3: checkpoint = {"stage":"jg_fog", "x":220.0, "y":900.0, "encounter":""}
	if chapter == 4: checkpoint = {"stage":"cc_outer", "x":220.0, "y":900.0, "encounter":""}
	route = "bridge"; time = 0.0; kills = 0; precision_count = 0; complete = false

func record(message: String) -> void:
	if not history.has(message):
		history.append(message)

func run_snapshot() -> Dictionary:
	return {"chapter":chapter, "difficulty":difficulty, "battle_art":battle_art, "checkpoint":checkpoint.duplicate(true), "flags":flags.duplicate(), "cleared":cleared.duplicate(), "seen":seen.duplicate(), "history":history.duplicate(), "route":route, "time":time, "kills":kills, "precision_count":precision_count, "complete":complete, "tactics":tactics.duplicate(true)}

func snapshot() -> Dictionary:
	var data = run_snapshot()
	var records = chapters.duplicate(true); records[str(chapter)] = data.duplicate(true)
	data.merge({"version":2, "engine":"godot", "chapters":records,"rewards":rewards.duplicate()})
	return data

func switch_chapter(chapter_id: int, level: String = "normal", fresh: bool = false) -> void:
	var carried_art=battle_art if complete and chapter_id==chapter+1 else ""
	chapters[str(chapter)] = run_snapshot()
	var saved: Dictionary = chapters.get(str(chapter_id),{}).duplicate(true)
	reset(level,chapter_id)
	if not fresh and not saved.is_empty(): restore_run(saved)
	elif saved.is_empty(): battle_art=carried_art
	if chapter_id>=2 and rewards.huilan and (fresh or saved.is_empty()): tactics.huilan_equipped=true

func battle_art_name() -> String:
	return BATTLE_ARTS[battle_art].name if BATTLE_ARTS.has(battle_art) else "基础枪法"

func chapter_record(chapter_id: int) -> Dictionary:
	return run_snapshot() if chapter_id == chapter else chapters.get(str(chapter_id),{}).duplicate(true)

static func valid(data: Variant) -> bool:
	if not data is Dictionary or data.get("engine") != "godot":
		return false
	var schema=data.get("version")
	if not (schema is int or schema is float) or not is_finite(float(schema)) or float(schema)!=int(schema) or int(schema) not in [1,2]: return false
	if not valid_run(data, int(data.get("chapter",1))): return false
	if data.version == 2:
		if not data.get("chapters") is Dictionary or data.chapters.size()>4: return false
		if not data.get("rewards",{"huilan":false}) is Dictionary or not data.get("rewards",{"huilan":false}).get("huilan") is bool: return false
		for key in data.chapters:
			if key not in ["1","2","3","4"] or not valid_run(data.chapters[key],int(key)): return false
	return true

static func valid_run(data: Variant, chapter_id: int) -> bool:
	if not data is Dictionary or not CHAPTER_STAGES.has(chapter_id): return false
	if data.has("chapter"):
		var stored=data.chapter
		if not (stored is int or stored is float) or not is_finite(float(stored)) or float(stored)!=chapter_id: return false
	if not data.get("difficulty") in ["normal", "story"]:
		return false
	# Optional in older v1/v2 saves. Unknown values never become runtime bonuses.
	if not data.get("battle_art","") in ["","assault","counter"]: return false
	var cp = data.get("checkpoint")
	if not cp is Dictionary or not cp.get("stage") in CHAPTER_STAGES[chapter_id]:
		return false
	for axis in ["x", "y"]:
		var value = cp.get(axis)
		if not (value is float or value is int) or not is_finite(float(value)) or value < 0 or value > (1600 if axis == "x" else 1100):
			return false
	if not cp.get("encounter", "") in ({1:["", "xiahou", "zhanghe", "rescue"],2:["", "dujun"],3:["", "vanguard"],4:["", "warden"]}[chapter_id]):
		return false
	var f = data.get("flags")
	if not f is Dictionary:
		return false
	for key in FLAGS:
		if not f.get(key) is bool:
			return false
	if chapter_id == 1 and (f.sword != f.temple or (f.mother and not (f.adou and f.healer)) or (f.boss and not f.adou) or (f.committed and not f.adou)):
		return false
	if chapter_id == 2:
		for key in HANSHUI_FLAGS:
			if not f.get(key) is bool: return false
		if not f.sword or not f.temple or f.huilan and not (f.dujun and f.deception): return false
		if not valid_tactics(data.get("tactics",{})): return false
	if chapter_id == 3:
		for key in JIGU_FLAGS:
			if not f.get(key) is bool: return false
		if not f.sword or not f.temple or not valid_tactics(data.get("tactics",{})): return false
		if f.jg_rear and not f.jg_front or f.jg_rearguard and not f.jg_rear: return false
		if f.jg_bridge_cut and f.jg_bridge_held: return false
		if (f.jg_bridge_cut or f.jg_bridge_held) and not f.jg_rearguard: return false
		if f.jg_last_guard and not f.jg_bridge_held: return false
		if f.jg_boss and not (f.jg_bridge_cut or f.jg_bridge_held and f.jg_last_guard): return false
		if f.jg_supply_claimed and not f.jg_supplies: return false
	if chapter_id == 4:
		for key in CHENCANG_FLAGS:
			if not f.get(key) is bool: return false
		if not f.sword or not f.temple or not valid_tactics(data.get("tactics",{})): return false
		if f.cc_beacon_out and not f.cc_breach or f.cc_orders and not f.cc_breach: return false
		if f.cc_route_front and f.cc_route_flank: return false
		if (f.cc_route_front or f.cc_route_flank) and not f.cc_beacon_out: return false
		if f.cc_street_done and not (f.cc_route_front or f.cc_route_flank): return false
		if (f.cc_reserve_called or f.cc_warehouse or f.cc_workers) and not f.cc_street_done: return false
		if f.cc_courtyard and not f.cc_warehouse or f.cc_committed and not f.cc_courtyard: return false
		if f.cc_boss and not f.cc_committed: return false
		if cp.get("encounter","")=="warden" and (cp.stage!="cc_final" or not f.cc_committed or f.cc_boss): return false
	for key in ["cleared", "seen", "history"]:
		if not data.get(key) is Array or data[key].size() > 100:
			return false
		for entry in data[key]:
			if not entry is String or entry.length() > 500:
				return false
	for key in ["time", "kills", "precision_count"]:
		var value = data.get(key)
		if not (value is float or value is int) or not is_finite(float(value)) or value < 0 or value > 10000000:
			return false
	if not data.get("complete") is bool or (data.complete and not (f.boss and f.adou if chapter_id == 1 else f.dujun if chapter_id == 2 else f.jg_boss if chapter_id == 3 else f.cc_boss)):
		return false
	return true

static func valid_tactics(t: Variant) -> bool:
	if not t is Dictionary or t.size()>24: return false
	if not t.get("gate", "PREPARE") in ["PREPARE","PROBE_1","PROBE_2","WITHDRAW","BEST_WINDOW","LATE_WINDOW","COUNTER_BEST","COUNTER_LATE","COUNTER_DIRECT","DONE"]: return false
	for key in ["deception_ok","extra_used","volley_spent","cart_checkpoint","huilan_equipped"]:
		if t.has(key) and not t[key] is bool: return false
	for key in ["escort_index","cart_hp"]:
		if t.has(key) and (not (t[key] is float or t[key] is int) or not is_finite(float(t[key])) or t[key]<0 or t[key]>200): return false
	var roster = t.get("roster",[])
	if not roster is Array or roster.size()>4: return false
	var ids: Array=[]
	for item in roster:
		if not item is Dictionary or not item.get("kind") in ["sword","spear","archer","shield","scout","crossbow","ironshield"]: return false
		if not item.get("id") is String or ids.has(item.id): return false
		ids.append(item.id)
		if not (item.get("hp") is float or item.get("hp") is int) or not is_finite(float(item.hp)) or item.hp<0 or item.hp>300: return false
	return true

func restore(data: Dictionary) -> bool:
	if not valid(data):
		return false
	chapters = data.get("chapters",{}).duplicate(true)
	rewards=data.get("rewards",{"huilan":false}).duplicate()
	restore_run(data)
	return true

func restore_run(data: Dictionary) -> void:
	reset(data.difficulty,int(data.get("chapter",1)))
	var base_flags = flags.duplicate()
	flags = data.flags.duplicate(); checkpoint = data.checkpoint.duplicate()
	for key in base_flags:
		if not flags.has(key): flags[key] = base_flags[key]
	cleared = data.cleared.duplicate(); seen = data.seen.duplicate(); history = data.history.duplicate()
	route = "healer" if data.get("route") == "healer" else "bridge"
	time = data.time; kills = int(data.kills); precision_count = int(data.precision_count); complete = data.complete
	tactics = data.get("tactics",{}).duplicate(true)
	battle_art = data.get("battle_art","")

func save() -> bool:
	last_save = snapshot()
	var temp = save_path + ".tmp"
	var file = FileAccess.open(temp, FileAccess.WRITE)
	if file == null:
		durable = false
		return false
	file.store_string(JSON.stringify(last_save))
	file.flush()
	var ok = file.get_error() == OK
	file.close()
	if ok:
		ok = DirAccess.rename_absolute(temp, save_path) == OK
	durable = ok
	return ok

func read_save() -> Dictionary:
	if not last_save.is_empty():
		return last_save.duplicate(true)
	var source = save_path
	if source == SAVE_PATH and not FileAccess.file_exists(source) and FileAccess.file_exists(LEGACY_PATH): source = LEGACY_PATH
	if not FileAccess.file_exists(source):
		return {}
	var file = FileAccess.open(source, FileAccess.READ)
	if file == null or file.get_length() > 250000:
		return {}
	var data = JSON.parse_string(file.get_as_text())
	return data if valid(data) else {}

func build_report() -> Dictionary:
	if chapter == 4:
		var front=flags.cc_route_front
		var timely=flags.cc_orders and not flags.cc_reserve_called
		var branch="赵云从正门打破盾阵，瓮城少了一队重盾的支撑。" if front else "赵云沿侧巷扳下巷闸，瓮城的弩手未能得到接应。"
		return {"chapter":4,"title":"陈仓夜袭 · 正门破关" if front else "陈仓夜袭 · 暗巷截援","text":"烽台沉寂，鼓楼的重锤终于落地。\n\n"+branch+"\n"+("调令及时截下，仓院援军没能赶来。" if timely else "调令来迟，赵云亲自击退了仓院援军。" if flags.cc_orders else "仓院援军已被击退，守军调令仍留在西厢。")+"\n"+("工匠从西院获救，打开了通向瓮城的侧门。" if flags.cc_workers else "仓院西侧仍有未能接出的工匠。")+"\n\n这一夜，箕谷归来的军旗第一次主动插上城关。此段陈仓夜袭为本作架空演绎。","changes":int(flags.cc_orders)+int(flags.cc_workers),"kills":kills,"precision":precision_count,"time":time,"hints":([] if flags.cc_orders else ["烽台西厢：在仓院援军到场前取调令，可以截断这次增援。"])+([] if flags.cc_workers else ["仓院西侧：接出工匠，打开瓮城侧门与额外整备点。"])}
	if chapter == 3:
		var changes=int(flags.jg_dispatch)+int(flags.jg_supplies)+int(flags.jg_last_guard)
		return {"chapter":3,"title":"箕谷断后 · 末队同归" if flags.jg_last_guard else "箕谷断后 · 断桥截敌","text":"两队撤军已越过栈道，石门后的军旗重新收拢。\n\n"+("赵云留下危桥，亲自接回最后的军士。" if flags.jg_last_guard else "绳索断开，谷中的追兵被留在对岸。")+"\n玄甲先锋退去，赵云转身看向归队的将士：这一程，撤退也要走得有章法。\n\n"+("军报已带回。" if flags.jg_dispatch else "崖台还有未能带回的军报。")+("辎重药械也随军归来。" if flags.jg_supplies else "偏坡的辎重留在了谷中。"),"changes":changes,"kills":kills,"precision":precision_count,"time":time,"hints":([] if flags.jg_dispatch else ["崖台西侧：取回失落军报，削弱石门弩阵。"])+([] if flags.jg_supplies else ["石门偏坡：接应辎重兵，在谷口营火领取补给。"])+([] if flags.jg_last_guard else ["另一条路线：留桥接应，击退追兵后接回末队。"])}
	if chapter == 2:
		var changes = int(flags.wounded)+int(flags.beacon)+int(flags.deception)
		return {"chapter":2,"title":"汉水孤营 · 空营震敌" if flags.deception else "汉水孤营 · 正面破围", "text":"黄忠与撤军已归营，汉水追兵退去。\n\n"+("赵云放下鼓槌：退与进，都要握在我们手里。" if flags.deception else "赵云收枪：计策未尽，手中这杆枪仍可开路。")+"\n\n"+("张著和伤兵在营中向你行礼。" if flags.wounded else "营外还有未能接回的伤兵。")+("火箭辎重已毁，粮车平安进营。" if flags.beacon else "河湾仍留着曹军火箭的灼痕。"),"changes":changes,"kills":kills,"precision":precision_count,"time":time,"hints":([] if flags.wounded else ["乱石归途西侧：回救张著与伤兵。"])+([] if flags.beacon else ["北山粮道东岗：摧毁火箭辎重。"])+([] if flags.deception else ["孤营藏兵后开门，在金色鼓台战机擂鼓。"])}
	var changes = int(flags.civilians) + int(flags.mother) + int(flags.supplies)
	var title = "长坂逆命 · 母子同归" if flags.mother else "一骑护众 · 仁心归来" if flags.civilians else "孤胆归来 · 命有未竟"
	var text = "刘备先接过阿斗，随后看见担架上的糜夫人。\n「子龙……你竟把她也带回来了。」\n\n记忆中的诀别没有发生。这一回，你让一个人活了下来。" if flags.mother else "刘备接过阿斗，伸手扶起浑身尘土的你。\n「子龙，今日全赖你了。」\n\n你护住了孩子，也记住了井畔未能兑现的承诺。长坂的命运，还有另一种写法。"
	var hints: Array = []
	if not flags.civilians: hints.append("荒村西巷：救出医者与三名百姓。")
	if not flags.mother: hints.append("井畔旧宅：请医者施救，护住两波追兵。")
	if not flags.supplies: hints.append("粮道东营：击败校尉后，再按 E 焚粮。")
	return {"chapter":1, "title": title, "text": text, "changes": changes, "kills": kills, "precision": precision_count, "time": time, "hints": hints}
