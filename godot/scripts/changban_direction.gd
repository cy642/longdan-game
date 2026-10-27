extends RefCounted
## Small, interrupt-free narrative beats. No combat gating or save mutations.
const INTRO = {
	"mountain":["长坂 · 枪起乱军","先稳住脚下，再寻失散的人"],
	"village":["荒村 · 火里有人","巷口是追兵，西院还有求救声"],
	"temple":["破庙 · 一剑开路","残碑之后，青釭仍在敌将手中"],
	"house":["井畔 · 改写诀别","记忆中的结局，尚未发生"],
	"fork":["粮道 · 自择进退","绕入粮营，可断桥头箭援"],
	"bridge":["北桥 · 一人断后","让身后的人先走"]}
const LESSONS={"m1":"刀手抬刀后会锁定来向，侧闪再还枪。","m2":"枪兵留着距离；先避枪尖，再切近刀手。","m3":"盾挡正面轻枪；绕背，或用 Q 打开盾势。","v1":"弓手藏在盾后；借屋角避箭，再近身切断后排。"}
const RESULTS={"civilians":["荒村得救","医者归队，井畔多了一种可能"],"temple":["青釭归手","战意蓄满后，以 R 断势"],"mother":["这次，她活下来了","救下的人，将与你同行到桥头"],"supplies":["粮火断援","北桥的弓手已经失去补给"]}
var world
var spoken: Dictionary={}
var previous_flags: Dictionary={}
var observed_stage=""

func reset() -> void:
	spoken.clear(); previous_flags.clear(); observed_stage=""

func enter(game) -> void:
	world=game; observed_stage=world.stage
	previous_flags=world.state.flags.duplicate()
	if world.state.chapter!=1 or not INTRO.has(observed_stage): return
	var key="region:"+observed_stage
	if not spoken.has(key):
		spoken[key]=true
		world.ui.show_scene_stamp(INTRO[observed_stage][0],INTRO[observed_stage][1],3.4)

func advance(_dt: float) -> void:
	if not is_instance_valid(world) or world.mode!="playing" or world.state.chapter!=1: return
	for flag in RESULTS:
		var now=bool(world.state.flags.get(flag,false))
		if now and not bool(previous_flags.get(flag,false)):
			world.ui.show_scene_stamp(RESULTS[flag][0],RESULTS[flag][1],3.8)
		previous_flags[flag]=now
	if not world.active_boss.is_empty() or world.ui.toast_left>0: return
	for enemy in world.enemies:
		if not enemy.body_alive() or not LESSONS.has(enemy.group_id): continue
		var key="lesson:"+enemy.group_id
		if not spoken.has(key) and enemy.position.distance_to(world.hero.position)<310:
			spoken[key]=true; world.toast(LESSONS[enemy.group_id]); return
