extends RefCounted
## Persistent chapter state. Runtime combat and animations belong to the scene.
const FLAGS = ["mountain", "civilians", "healer", "temple", "sword", "adou", "house", "mother", "motherDecision", "supplies", "elite", "boss", "committed"]
const SAVE_PATH = "user://longdan-godot-v2.json"
const LEGACY_PATH = "user://longdan-godot-v1.json"
const HANSHUI_FLAGS = ["huangzhong", "wounded", "beacon", "cart", "dujun", "deception", "volley", "huilan"]
const CHAPTER_STAGES = {1:["mountain", "village", "temple", "house", "fork", "bridge"], 2:["hs_forest", "hs_grain", "hs_return", "hs_camp", "hs_river", "hs_final"]}
var chapter = 1
var chapters: Dictionary = {}
var rewards={"huilan":false}
var tactics: Dictionary = {}
var flags: Dictionary = {}
var cleared: Array = []
var seen: Array = []
var history: Array = []
var difficulty = "normal"
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
	flags.clear()
	for key in FLAGS:
		flags[key] = false
	for key in HANSHUI_FLAGS: flags[key] = false
	if chapter == 2: flags.sword = true; flags.temple = true
	tactics = {}
	cleared = []; seen = []; history = []
	checkpoint = {"stage": "mountain", "x": 190.0, "y": 910.0, "encounter": ""}
	if chapter == 2: checkpoint = {"stage":"hs_forest", "x":200.0, "y":900.0, "encounter":""}
	route = "bridge"; time = 0.0; kills = 0; precision_count = 0; complete = false

func record(message: String) -> void:
	if not history.has(message):
		history.append(message)

func run_snapshot() -> Dictionary:
	return {"chapter":chapter, "difficulty":difficulty, "checkpoint":checkpoint.duplicate(true), "flags":flags.duplicate(), "cleared":cleared.duplicate(), "seen":seen.duplicate(), "history":history.duplicate(), "route":route, "time":time, "kills":kills, "precision_count":precision_count, "complete":complete, "tactics":tactics.duplicate(true)}

func snapshot() -> Dictionary:
	var data = run_snapshot()
	var records = chapters.duplicate(true); records[str(chapter)] = data.duplicate(true)
	data.merge({"version":2, "engine":"godot", "chapters":records,"rewards":rewards.duplicate()})
	return data

func switch_chapter(chapter_id: int, level: String = "normal", fresh: bool = false) -> void:
	chapters[str(chapter)] = run_snapshot()
	var saved: Dictionary = chapters.get(str(chapter_id),{}).duplicate(true)
	reset(level,chapter_id)
	if not fresh and not saved.is_empty(): restore_run(saved)
	if chapter_id==2 and rewards.huilan: tactics.huilan_equipped=true

func chapter_record(chapter_id: int) -> Dictionary:
	return run_snapshot() if chapter_id == chapter else chapters.get(str(chapter_id),{}).duplicate(true)

static func valid(data: Variant) -> bool:
	if not data is Dictionary or data.get("engine") != "godot":
		return false
	var schema=data.get("version")
	if not (schema is int or schema is float) or not is_finite(float(schema)) or float(schema)!=int(schema) or int(schema) not in [1,2]: return false
	if not valid_run(data, int(data.get("chapter",1))): return false
	if data.version == 2:
		if not data.get("chapters") is Dictionary or data.chapters.size()>2: return false
		if not data.get("rewards",{"huilan":false}) is Dictionary or not data.get("rewards",{"huilan":false}).get("huilan") is bool: return false
		for key in data.chapters:
			if key not in ["1","2"] or not valid_run(data.chapters[key],int(key)): return false
	return true

static func valid_run(data: Variant, chapter_id: int) -> bool:
	if not data is Dictionary or not CHAPTER_STAGES.has(chapter_id): return false
	if data.has("chapter"):
		var stored=data.chapter
		if not (stored is int or stored is float) or not is_finite(float(stored)) or float(stored)!=chapter_id: return false
	if not data.get("difficulty") in ["normal", "story"]:
		return false
	var cp = data.get("checkpoint")
	if not cp is Dictionary or not cp.get("stage") in CHAPTER_STAGES[chapter_id]:
		return false
	for axis in ["x", "y"]:
		var value = cp.get(axis)
		if not (value is float or value is int) or not is_finite(float(value)) or value < 0 or value > (1600 if axis == "x" else 1100):
			return false
	if not cp.get("encounter", "") in (["", "xiahou", "zhanghe", "rescue"] if chapter_id == 1 else ["", "dujun"]):
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
	if not data.get("complete") is bool or (data.complete and not (f.boss and f.adou if chapter_id == 1 else f.dujun)):
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
