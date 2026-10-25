extends RefCounted
## Authored silhouettes are independent of combat/save identities. Keep kind and
## boss_id authoritative for mechanics; a profile supplies only art and its name.
const ATLAS_PATH = "res://data/enemy_atlas.json"
const PROFILES = {
	"cb_sword":{"atlas":"enemy_changban","index":0,"name":"赤巾追刀手","height":76.0},
	"cb_spear":{"atlas":"enemy_changban","index":1,"name":"长坂矛卒","height":79.0},
	"cb_archer":{"atlas":"enemy_changban","index":2,"name":"山道猎弓手","height":73.0},
	"cb_shield":{"atlas":"enemy_changban","index":3,"name":"藤盾卫","height":73.0},
	"cb_elite":{"atlas":"enemy_changban","index":4,"name":"盾阵校尉","height":92.0},
	"cb_village":{"atlas":"enemy_changban","index":5,"name":"荒村斩刀手","height":78.0},
	"hs_sword":{"atlas":"enemy_hanshui","index":0,"name":"水营刀手","height":77.0},
	"hs_spear":{"atlas":"enemy_hanshui","index":1,"name":"营门枪卫","height":81.0},
	"hs_scout":{"atlas":"enemy_hanshui","index":2,"name":"潜林双刀客","height":72.0},
	"hs_crossbow":{"atlas":"enemy_hanshui","index":3,"name":"水营连弩手","height":75.0},
	"hs_ironshield":{"atlas":"enemy_hanshui","index":4,"name":"铁壁营卫","height":85.0},
	"hs_beacon":{"atlas":"enemy_hanshui","index":5,"name":"辎重强弩手","height":79.0},
	"jg_sword":{"atlas":"enemy_jigu","index":0,"name":"山隘刀兵","height":77.0},
	"jg_spear":{"atlas":"enemy_jigu","index":1,"name":"断路长矛手","height":83.0},
	"jg_scout":{"atlas":"enemy_jigu","index":2,"name":"攀崖双刃客","height":73.0},
	"jg_crossbow":{"atlas":"enemy_jigu","index":3,"name":"谷道劲弩手","height":76.0},
	"jg_ironshield":{"atlas":"enemy_jigu","index":4,"name":"山门重盾卫","height":87.0},
	"jg_signal":{"atlas":"enemy_jigu","index":5,"name":"崖台号旗弩手","height":78.0},
	"boss_xiahou":{"atlas":"enemy_commanders","index":0,"name":"夏侯恩","height":100.0},
	"boss_zhanghe":{"atlas":"enemy_commanders","index":1,"name":"张郃","height":109.0},
	"boss_dujun":{"atlas":"enemy_commanders","index":2,"name":"铁面督军","height":108.0},
	"boss_vanguard":{"atlas":"enemy_commanders","index":3,"name":"玄甲先锋","height":112.0}
}
const CHAPTER_KINDS = {
	1:{"sword":"cb_sword","spear":"cb_spear","archer":"cb_archer","shield":"cb_shield","elite":"cb_elite"},
	2:{"sword":"hs_sword","spear":"hs_spear","scout":"hs_scout","crossbow":"hs_crossbow","ironshield":"hs_ironshield"},
	3:{"sword":"jg_sword","spear":"jg_spear","scout":"jg_scout","crossbow":"jg_crossbow","ironshield":"jg_ironshield"}
}

static func resolve(chapter: int, stage: String, kind: String, boss: String = "", group: String = "") -> Dictionary:
	var id = ""
	if kind == "boss": id = "boss_" + boss
	elif chapter == 1 and stage == "village" and kind == "sword": id = "cb_village"
	elif chapter == 2 and stage == "hs_grain" and group == "hs_beacon_guard" and kind == "crossbow": id = "hs_beacon"
	elif chapter == 3 and stage == "jg_signal" and group == "jg_s2" and kind == "crossbow": id = "jg_signal"
	else: id = str(CHAPTER_KINDS.get(chapter,CHAPTER_KINDS[1]).get(kind,""))
	# Editors and combat fixtures can instantiate any combat kind on any map.
	# Resolve it to its actual authored family instead of falling back to old art.
	if not PROFILES.has(id):
		for family in [1,2,3]:
			if CHAPTER_KINDS[family].has(kind):
				id = CHAPTER_KINDS[family][kind]; break
	if not PROFILES.has(id): id = "cb_sword"
	var profile: Dictionary = PROFILES[id].duplicate(true)
	profile.id = id
	return profile
