extends RefCounted
## Persistent chapter state. Runtime combat and animations belong to the scene.
const FLAGS = ["mountain", "civilians", "healer", "temple", "sword", "adou", "house", "mother", "motherDecision", "supplies", "elite", "boss", "committed"]
const SAVE_PATH = "user://longdan-godot-v1.json"
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

func reset(level: String = "normal") -> void:
	difficulty = "story" if level == "story" else "normal"
	flags.clear()
	for key in FLAGS:
		flags[key] = false
	cleared = []; seen = []; history = []
	checkpoint = {"stage": "mountain", "x": 190.0, "y": 910.0, "encounter": ""}
	route = "bridge"; time = 0.0; kills = 0; precision_count = 0; complete = false

func record(message: String) -> void:
	if not history.has(message):
		history.append(message)

func snapshot() -> Dictionary:
	return {"version": 1, "engine": "godot", "difficulty": difficulty, "checkpoint": checkpoint.duplicate(true), "flags": flags.duplicate(), "cleared": cleared.duplicate(), "seen": seen.duplicate(), "history": history.duplicate(), "route": route, "time": time, "kills": kills, "precision_count": precision_count, "complete": complete}

static func valid(data: Variant) -> bool:
	if not data is Dictionary or data.get("version") != 1 or data.get("engine") != "godot":
		return false
	if not data.get("difficulty") in ["normal", "story"]:
		return false
	var cp = data.get("checkpoint")
	if not cp is Dictionary or not cp.get("stage") in ["mountain", "village", "temple", "house", "fork", "bridge"]:
		return false
	for axis in ["x", "y"]:
		var value = cp.get(axis)
		if not (value is float or value is int) or not is_finite(float(value)) or value < 0 or value > (1600 if axis == "x" else 1100):
			return false
	if not cp.get("encounter", "") in ["", "xiahou", "zhanghe", "rescue"]:
		return false
	var f = data.get("flags")
	if not f is Dictionary:
		return false
	for key in FLAGS:
		if not f.get(key) is bool:
			return false
	if f.sword != f.temple or (f.mother and not (f.adou and f.healer)) or (f.boss and not f.adou) or (f.committed and not f.adou):
		return false
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
	if not data.get("complete") is bool or (data.complete and not (f.boss and f.adou)):
		return false
	return true

func restore(data: Dictionary) -> bool:
	if not valid(data):
		return false
	reset(data.difficulty)
	flags = data.flags.duplicate(); checkpoint = data.checkpoint.duplicate()
	cleared = data.cleared.duplicate(); seen = data.seen.duplicate(); history = data.history.duplicate()
	route = "healer" if data.get("route") == "healer" else "bridge"
	time = data.time; kills = int(data.kills); precision_count = int(data.precision_count); complete = data.complete
	return true

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
	if not FileAccess.file_exists(save_path):
		return {}
	var file = FileAccess.open(save_path, FileAccess.READ)
	if file == null or file.get_length() > 100000:
		return {}
	var data = JSON.parse_string(file.get_as_text())
	return data if valid(data) else {}

func build_report() -> Dictionary:
	var changes = int(flags.civilians) + int(flags.mother) + int(flags.supplies)
	var title = "长坂逆命 · 母子同归" if flags.mother else "一骑护众 · 仁心归来" if flags.civilians else "孤胆归来 · 命有未竟"
	var text = "刘备先接过阿斗，随后看见担架上的糜夫人。\n「子龙……你竟把她也带回来了。」\n\n记忆中的诀别没有发生。这一回，你让一个人活了下来。" if flags.mother else "刘备接过阿斗，伸手扶起浑身尘土的你。\n「子龙，今日全赖你了。」\n\n你护住了孩子，也记住了井畔未能兑现的承诺。长坂的命运，还有另一种写法。"
	var hints: Array = []
	if not flags.civilians: hints.append("荒村西巷：救出医者与三名百姓。")
	if not flags.mother: hints.append("井畔旧宅：请医者施救，护住两波追兵。")
	if not flags.supplies: hints.append("粮道东营：击败校尉后，再按 E 焚粮。")
	return {"title": title, "text": text, "changes": changes, "kills": kills, "precision": precision_count, "time": time, "hints": hints}
