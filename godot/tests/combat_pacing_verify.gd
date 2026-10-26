extends SceneTree
## Deterministic pacing plus real production-world scheduling. Combat actions
## and physics are not mocked; memory-only Campaign prevents player-save IO.
const Pacing = preload("res://scripts/combat_pacing.gd")
const Enemy = preload("res://scripts/enemy.gd")
const Game = preload("res://scripts/world.gd")
const Campaign = preload("res://scripts/campaign.gd")
class MemoryCampaign extends Campaign:
	func read_save() -> Dictionary: return {}
	func save() -> bool: return true
const STAGES = [
	"mountain","village","temple","house","fork","bridge",
	"hs_forest","hs_grain","hs_return","hs_camp","hs_river","hs_final",
	"jg_fog","jg_signal","jg_pass","jg_rearguard","jg_bridge","jg_final",
	"cc_outer","cc_beacon","cc_street","cc_store","cc_bastion","cc_final"
]
const GAPS = [.90,.80,.70,.62,.56,.50,.48,.46,.44,.42,.40,.38,.37,.36,.35,.34,.33,.32,.31,.30,.29,.28,.27,.26]
const RESTS = [.45,.42,.39,.36,.33,.30,.30,.29,.28,.27,.26,.25,.25,.25,.25,.25,.25,.25,.25,.25,.25,.25,.25,.25]
const BOSSES = ["xiahou","zhanghe","dujun","vanguard","warden"]
const BOSS_RESTS = [.34,.28,.24,.21,.18]
var checks = 0
var failures: Array = []
var world

func _initialize() -> void: call_deferred("run")
func expect(condition: bool, message: String) -> void:
	checks += 1
	if not condition: failures.append(message); push_error("COMBAT_PACING: "+message)
func settle() -> void:
	await process_frame; await physics_frame; await physics_frame
func fingerprints() -> Dictionary:
	var result: Dictionary = {}
	for path in [Campaign.SAVE_PATH,Campaign.LEGACY_PATH]:
		result[path]=FileAccess.get_file_as_bytes(path).hex_encode().sha256_text() if FileAccess.file_exists(path) else "absent"
	return result

func fresh(level: String="normal",stage: String="mountain") -> void:
	world.state.reset(level,1); world.load_chapter(1); world.mode="playing"
	world.hero.max_hp=240 if level=="story" else 200; world.hero.reset_combat()
	world.enter_stage(stage,Vector2(850,900),false); world.ui.hide_overlay(); world.clear_input()
	for enemy in world.enemies:
		enemy.hp=0; enemy.collision_layer=0; enemy.action={}; enemy.sequence=[]
	world.arrows.clear(); world.active_boss=""; world.boss=null; world.hit_stop=0; world.fx.soft=false
	for ally in world.allies: ally.hp=0
	await settle()

func spawn(kind: String,offset: Vector2,boss_id: String=""):
	var enemy=world.spawn_enemy(kind,world.hero.position+offset,"pacing-acceptance",boss_id)
	enemy.cooldown=0; enemy.stun=0; enemy.alerted=true
	return enemy

func attack_snapshot() -> Dictionary:
	var chapter = JSON.parse_string(FileAccess.get_file_as_string("res://data/chapter1.json"))
	return {"standard":chapter.AttackDefinition.duplicate(true),"boss":Enemy.BOSS_MOVES.duplicate(true),"scout":Enemy.SCOUT_CHAIN.duplicate(true),"crossbow":Enemy.CROSSBOW_ATTACK.duplicate(true),"ironshield":Enemy.IRONSHIELD_ATTACK.duplicate(true)}

func profile_contracts() -> void:
	var pacing = Pacing.new()
	for level in ["normal","story"]:
		var previous_gap = INF; var previous_rest = INF
		for index in range(STAGES.size()):
			pacing.configure(STAGES[index],level)
			var profile = pacing.profile()
			var gap = float(GAPS[index])+(.20 if level=="story" else 0.0)
			var rest = float(RESTS[index])+(.12 if level=="story" else 0.0)
			var label = STAGES[index]+" "+level
			expect(profile.stage==STAGES[index] and profile.difficulty==level and profile.known_stage,label+" selects its explicit region profile")
			expect(is_equal_approx(pacing.gap,gap) and is_equal_approx(profile.gap,gap),label+" uses the authored shared start interval")
			expect(is_equal_approx(profile.post_chain_rest,rest),label+" exposes the authored full-chain rest")
			expect(pacing.gap<previous_gap,label+" increases pressure gradually instead of reversing the chapter gradient")
			if index>0: expect(previous_gap-pacing.gap<=.100001,label+" has no abrupt inter-region or inter-chapter jump")
			expect(rest<=previous_rest+.000001,label+" never unexpectedly slows the ordinary post-chain progression")
			for kind in ["sword","spear","archer","shield","elite","scout","crossbow","ironshield"]:
				expect(is_equal_approx(pacing.post_chain_rest(kind,""),rest),label+" keeps "+kind+" on the regional rest policy")
			previous_gap=pacing.gap; previous_rest=rest
			var exposed = pacing.profile(); exposed.gap=999; exposed.left=999
			expect(is_equal_approx(pacing.gap,gap) and pacing.left==0,label+" profile inspection cannot mutate the live clock")
		var previous_boss = INF
		for index in range(BOSSES.size()):
			var rest = float(BOSS_RESTS[index])+(.12 if level=="story" else 0.0)
			expect(is_equal_approx(pacing.post_chain_rest("boss",BOSSES[index]),rest),BOSSES[index]+" "+level+" uses its own full-chain rest")
			expect(rest<previous_boss,BOSSES[index]+" "+level+" follows a gradual boss progression")
			previous_boss=rest
		pacing.configure("not-a-published-map",level)
		expect(not pacing.profile().known_stage and is_equal_approx(pacing.gap,.90+(.20 if level=="story" else 0.0)),"unknown editor stage uses explicit conservative fallback")

func token_contracts() -> void:
	var pacing = Pacing.new()
	for level in ["normal","story"]:
		for stage in STAGES:
			pacing.configure(stage,level)
			var label = stage+" "+level
			expect(pacing.left==0 and pacing.claim(),label+" first eligible chain can begin immediately")
			expect(is_equal_approx(pacing.left,pacing.gap),label+" successful claim starts one interval")
			for attempt in range(3): expect(not pacing.claim(),label+" same-frame competitors cannot claim another start")
			var before = pacing.left
			pacing.advance(-10); pacing.advance(0)
			expect(pacing.left==before,label+" zero/negative dt cannot move the clock backwards or unlock it")
			pacing.advance(NAN); pacing.advance(INF)
			expect(pacing.left==before,label+" invalid external dt never poisons the clock")
			pacing.advance(pacing.gap*.4)
			expect(is_equal_approx(pacing.left,pacing.gap*.6) and not pacing.claim(),label+" partial elapsed time still blocks the next chain")
			pacing.advance(pacing.gap*.6+.000001)
			expect(pacing.left==0 and pacing.claim() and not pacing.claim(),label+" elapsed interval releases exactly one fresh start")
			pacing.advance(10000)
			expect(pacing.left==0 and pacing.claim() and not pacing.claim(),label+" long dt never accumulates a backlog of attack tokens")
			var clock = pacing.left
			for boss in BOSSES: pacing.post_chain_rest("boss",boss)
			expect(pacing.left==clock,label+" querying boss or recovery timing never consumes shared starts")
			pacing.configure(stage,level)
			expect(pacing.left==0 and pacing.claim(),label+" entering/retrying a region clears the previous clock")
		pacing.configure("mountain",level); pacing.claim(); pacing.configure("cc_final",level)
		expect(pacing.left==0 and is_equal_approx(pacing.gap,.26+(.20 if level=="story" else 0.0)),level+" switching chapters takes the new profile without old waiting time")

func actual_staggering() -> void:
	for level in ["normal","story"]:
		await fresh(level)
		var first=spawn("sword",Vector2(60,0)); var second=spawn("sword",Vector2(0,60))
		world._physics_process(.01)
		expect(not first.action.is_empty() and second.action.is_empty(),level+" two actual nearby melee enemies cannot begin on the same world tick")
		var claimed=world.combat_pacing.left
		expect(is_equal_approx(claimed,.90+(.20 if level=="story" else 0.0)),level+" actual first attack consumes the correct regional interval")
		world._physics_process(.1)
		expect(is_equal_approx(world.combat_pacing.left,claimed-.1),level+" world advances one clock per tick, not once per enemy")
		expect(second.action.is_empty(),level+" second real enemy remains blocked during the interval")
		world._physics_process(claimed-.1+.00001)
		expect(not second.action.is_empty(),level+" second real enemy starts after elapsed shared interval")
		expect(is_equal_approx(first.max_hp,72*(.84 if level=="story" else 1.0)),level+" pacing does not change ordinary enemy health")
		var original=world.attacks.cut
		expect(second.action.def==original,level+" staggered start retains original windup, active, damage, range and recovery")
	await fresh("story"); var later=spawn("sword",Vector2(60,0)); var waiting=spawn("sword",Vector2(0,60))
	world._physics_process(.01); world._physics_process(.91)
	expect(not later.action.is_empty() and waiting.action.is_empty(),"story retains its extra .20-second start gap after the normal opening gap has elapsed")
	world._physics_process(.20)
	expect(not waiting.action.is_empty(),"story's wider opening eventually releases the next attack")

func actual_combo_and_recovery() -> void:
	for level in ["normal","story"]:
		await fresh(level)
		var scout=spawn("scout",Vector2(60,0)); scout.advance(0)
		expect(not scout.action.is_empty() and scout.sequence.size()==1,level+" actual scout claims one start for its whole two-hit chain")
		var first_id=scout.action.id; var clock=world.combat_pacing.left
		var first: Dictionary=scout.action.def; var first_duration=first.windup+first.active+first.recovery
		scout.advance_action(first_duration+.02,world.hero)
		expect(not scout.action.is_empty() and scout.action.id!=first_id and scout.action.def.style=="dual_return" and is_equal_approx(scout.action.t,.02),level+" scout enters its second strike with frame overflow and no inserted pause")
		expect(world.combat_pacing.left==clock and scout.sequence.is_empty() and is_equal_approx(scout.cooldown,.01),level+" internal combo link neither claims another shared turn nor applies post-chain rest")
		var second: Dictionary=scout.action.def
		scout.advance_action(second.windup+second.active+second.recovery-scout.action.t+.001,world.hero)
		expect(scout.action.is_empty() and is_equal_approx(scout.cooldown,.45+(.12 if level=="story" else 0.0)),level+" only completed full chain receives the regional post-chain rest")
		await fresh(level)
		var soldier=spawn("sword",Vector2(60,0)); soldier.advance(0)
		var move: Dictionary=soldier.action.def
		soldier.advance_action(move.windup+move.active+move.recovery+.001,world.hero)
		var rest=.45+(.12 if level=="story" else 0.0)
		expect(soldier.action.is_empty() and is_equal_approx(soldier.cooldown,rest),level+" ordinary chain receives its full local rest")
		world.combat_pacing.advance(10); soldier.advance(rest-.001)
		expect(soldier.action.is_empty() and world.combat_pacing.left==0,level+" local recovery still blocks attack even if shared turn is free")
		soldier.advance(.002)
		expect(not soldier.action.is_empty() and world.combat_pacing.left>0,level+" completed rest allows one fresh chain and consumes its shared turn")

func actual_slot_limits() -> void:
	await fresh()
	var first=spawn("spear",Vector2(65,0)); var second=spawn("spear",Vector2(0,65)); var third=spawn("sword",Vector2(-65,0))
	first.start_action(world.hero); second.start_action(world.hero); third.advance(0)
	expect(world.attackers_count()==2 and third.action.is_empty() and world.combat_pacing.left==0,"existing two-melee cap rejects a third without stealing a shared start")
	first.action={}; first.cooldown=2; third.advance(0)
	expect(not third.action.is_empty() and world.attackers_count()==2,"one released melee slot still permits the next eligible enemy")
	await fresh()
	var bow=spawn("archer",Vector2(240,0)); var crossbow=spawn("crossbow",Vector2(280,0))
	bow.start_action(world.hero); bow.action.t=bow.action.def.windup+bow.action.def.active+.2
	crossbow.advance(0)
	expect(crossbow.action.is_empty() and world.combat_pacing.left==0,"existing single-ranged slot stays occupied through reload without spending a turn")
	bow.advance_action(bow.action.def.recovery,world.hero); crossbow.advance(0)
	expect(not crossbow.action.is_empty() and world.combat_pacing.left>0,"finishing reload releases the existing ranged slot and permits one shared start")

func actual_freeze_and_reset() -> void:
	await fresh()
	var enemy=spawn("sword",Vector2(60,0)); world._physics_process(.01)
	var clock=world.combat_pacing.left; var action_time=enemy.action.t
	for mode in ["pause","map"]:
		world.pause(mode); world._physics_process(30)
		expect(world.combat_pacing.left==clock and enemy.action.t==action_time and not world.claim_enemy_attack_turn(),mode+" freezes real scheduling and pending attack")
		world.resume()
	world.hit_stop=.15; world._physics_process(.05)
	expect(world.combat_pacing.left==clock and enemy.action.t==action_time,"real hit stop freezes scheduling before enemy advancement")
	world._physics_process(.2)
	expect(world.hit_stop==0 and world.combat_pacing.left==clock,"the hit-stop release tick does not bank excess elapsed time")
	world._physics_process(.01)
	expect(is_equal_approx(world.combat_pacing.left,clock-.01),"the next ordinary physics tick resumes scheduling once")
	world.hero.invincible=0; world.hero.take_damage(10000,77101)
	clock=world.combat_pacing.left; action_time=enemy.action.t
	world._physics_process(30)
	expect(world.mode=="defeat" and world.combat_pacing.left==clock and enemy.action.t==action_time and not world.claim_enemy_attack_turn(),"actual defeat freezes both pacing and pending attacks")
	world.retry(); await settle()
	expect(world.mode=="playing" and world.combat_pacing.left==0,"real retry clears the old region's transient interval")
	world.combat_pacing.claim(); world.state.difficulty="story"; world.enter_stage("bridge",Vector2(850,900),false)
	expect(world.combat_pacing.left==0 and is_equal_approx(world.combat_pacing.gap,.70),"real region entry selects its new difficulty/profile and drops the previous clock")
	var saved=world.state.run_snapshot()
	expect(not saved.has("combat_pacing") and not saved.tactics.has("combat_pacing"),"transient attack clock does not enter chapter saves")

func actual_boss_bypass() -> void:
	for level in ["normal","story"]:
		await fresh(level,"temple")
		var boss=spawn("boss",Vector2(60,0),"xiahou"); boss.attack_count=1
		world.combat_pacing.claim(); var clock=world.combat_pacing.left
		boss.advance(0)
		expect(not boss.action.is_empty() and world.combat_pacing.left==clock,level+" boss begins while ordinary shared turn remains closed")
		var move: Dictionary=boss.action.def
		boss.advance_action(move.windup+move.active+move.recovery+.001,world.hero)
		var rest=.34+(.12 if level=="story" else 0.0)
		expect(boss.action.is_empty() and boss.sequence.is_empty() and is_equal_approx(boss.cooldown,rest),level+" boss receives only its own full-chain rest")
		boss.advance(rest+.001)
		expect(not boss.action.is_empty() and world.combat_pacing.left==clock,level+" next boss chain also bypasses ordinary claim without draining it")

func run() -> void:
	var before = attack_snapshot(); var saves=fingerprints()
	profile_contracts(); token_contracts()
	world=Game.new(); world.test_mode=true; world.state=MemoryCampaign.new()
	root.add_child(world); world.set_process(false); world.set_physics_process(false); await settle()
	await actual_staggering(); await actual_combo_and_recovery(); await actual_slot_limits(); await actual_freeze_and_reset(); await actual_boss_bypass()
	expect(attack_snapshot()==before,"pacing never mutates HP/damage/telegraph/active/lock-on attack definitions")
	expect(fingerprints()==saves,"pacing acceptance never changes player saves")
	print("COMBAT_PACING_VERIFY ",checks," checks; ",failures.size()," failures; regions=24 real_world_scheduling=true")
	world.queue_free(); await process_frame; await process_frame
	quit(0 if failures.is_empty() else 1)
