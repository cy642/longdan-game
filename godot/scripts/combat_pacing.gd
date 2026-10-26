extends RefCounted
## One shared non-boss chain start per interval. The caller advances this clock
## only during playing physics, after pause/hit-stop guards. No saved state.
const REGIONS = {
	"mountain":[.90,.45],"village":[.80,.42],"temple":[.70,.39],
	"house":[.62,.36],"fork":[.56,.33],"bridge":[.50,.30],
	"hs_forest":[.48,.30],"hs_grain":[.46,.29],"hs_return":[.44,.28],
	"hs_camp":[.42,.27],"hs_river":[.40,.26],"hs_final":[.38,.25],
	"jg_fog":[.37,.25],"jg_signal":[.36,.25],"jg_pass":[.35,.25],
	"jg_rearguard":[.34,.25],"jg_bridge":[.33,.25],"jg_final":[.32,.25],
	"cc_outer":[.31,.25],"cc_beacon":[.30,.25],"cc_street":[.29,.25],
	"cc_store":[.28,.25],"cc_bastion":[.27,.25],"cc_final":[.26,.25]
}
const BOSS_REST = {"xiahou":.34,"zhanghe":.28,"dujun":.24,"vanguard":.21,"warden":.18}
var stage = "mountain"
var difficulty = "normal"
var gap = .90
var left = 0.0
var _regular_rest = .45

func configure(stage_id: String, level: String) -> void:
	stage = stage_id
	difficulty = "story" if level=="story" else "normal"
	# Conservative opening-region values keep editor/unknown-map fixtures safe.
	var settings: Array = REGIONS.get(stage_id,REGIONS.mountain)
	gap = float(settings[0])+(.20 if difficulty=="story" else 0.0)
	_regular_rest = float(settings[1])
	left = 0.0

func advance(dt: float) -> void:
	if not is_finite(dt): return
	left = maxf(0.0,left-maxf(0.0,dt))

func claim() -> bool:
	if left>0: return false
	left = gap
	return true

func post_chain_rest(kind: String, boss_id: String = "") -> float:
	var base = float(BOSS_REST.get(boss_id,.34)) if kind=="boss" else _regular_rest
	return base+(.12 if difficulty=="story" else 0.0)

func profile() -> Dictionary:
	return {"stage":stage,"difficulty":difficulty,"known_stage":REGIONS.has(stage),"gap":gap,"left":left,"post_chain_rest":post_chain_rest("sword")}
