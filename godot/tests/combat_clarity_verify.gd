extends SceneTree
## Production hits/actions must drive readable windows without changing balance.
const Game = preload("res://scripts/world.gd")
const Campaign = preload("res://scripts/campaign.gd")
const Enemy = preload("res://scripts/enemy.gd")
class MemoryCampaign extends Campaign:
	func read_save() -> Dictionary: return {}
	func save() -> bool: return true
var world
var checks = 0
var failures: Array = []

func _initialize() -> void: call_deferred("run")
func expect(ok: bool, message: String) -> void:
	checks += 1
	if not ok: failures.append(message); push_error("COMBAT_CLARITY: "+message)
func settle() -> void:
	await process_frame; await physics_frame; await physics_frame
func clear_enemies() -> void:
	for enemy in world.enemies:
		enemy.hp = 0; enemy.collision_layer = 0; enemy.action = {}; enemy.sequence = []
	world.active_boss = ""; world.boss = null; world.arrows.clear()
	world.fx.entries.clear(); world.fx.labels.clear(); world.props.clear()
	world.hero.reset_combat(); world.hero.position = Vector2(850,900)
	world.mode = "playing"; world.ui.hide_overlay(); world.clear_input()
func spawn(kind: String = "sword", boss_id: String = ""):
	var enemy = Enemy.new(); enemy.world = world; enemy.position = Vector2(945,900)
	enemy.group_id = "clarity-qa"; enemy.configure(kind,boss_id)
	enemy.max_hp = 3000; enemy.hp = 3000; enemy.cooldown = 10
	world.actors.add_child(enemy); world.enemies.append(enemy)
	return enemy

func caption(message: String, at: Vector2, size: int = 18) -> void:
	var label = Label.new(); label.text = message; label.position = at
	label.add_theme_font_size_override("font_size",size)
	label.add_theme_color_override("font_color",Color("dce9d7"))
	world.add_child(label)

func capture_contact_sheet() -> void:
	if DisplayServer.get_name() == "headless":
		expect(false,"contact sheet requires a real renderer"); return
	root.size = Vector2i(1280,960)
	RenderingServer.set_default_clear_color(Color("314b47"))
	# The logic-only Q variant checks select chapter 2 without replacing the
	# map. Restore chapter 1 before any old chapter-1 marker can render.
	world.state.chapter = 1
	clear_enemies(); world.ui.hide(); world.terrain.hide(); world.camera.enabled = false
	for actor in world.actors.get_children():
		if actor != world.hero: actor.queue_free()
	world.enemies.clear(); world.allies.clear(); world.civilians.clear(); world.loot.clear()
	if root.focus_exited.is_connected(world.on_focus_lost): root.focus_exited.disconnect(world.on_focus_lost)
	await settle()
	caption("COMBAT CLARITY  |  production actors, status clocks and attack effects",Vector2(32,20),26)
	caption("Stable retaliation",Vector2(110,100),22)
	caption("Poise broken: chase window",Vector2(460,100),22)
	caption("Shield broken: distinct state",Vector2(870,100),22)
	var guard = spawn("scout"); guard.position = Vector2(210,300); guard.take_hit(1,0,0,"player",20)
	guard.stun = 0; guard.hit_interrupt_guard = .43; guard.hurt_flash = 0
	guard.start_action(world.hero); guard.action.t = .2; guard.action.dir = .3; guard.facing = .3; guard.update_visual()
	var broken = spawn("ironshield"); broken.position = Vector2(630,300)
	broken.take_hit(1,0,0,"player",broken.stagger_max,true)
	broken.hurt_flash = 0; broken.stun = .9; broken.poise_break_left = .9; broken.update_visual()
	var shield = spawn("ironshield"); shield.position = Vector2(1060,300)
	shield.take_hit(1,0,0,"player",0,true); shield.hurt_flash = 0; shield.update_visual()
	caption("Damage still lands; light hits cannot erase retaliation.",Vector2(32,385),16)
	caption("Only a real poise break shows this clock.",Vector2(450,385),16)
	caption("The broken shield has its own timer.",Vector2(870,385),16)
	caption("NORMAL Q",Vector2(60,480),23)
	caption("FULL-SPIRIT Q  |  hollow cyan / gold arcs",Vector2(690,480),23)
	world.fx.entries.clear(); world.fx.labels.clear()
	world.state.chapter = 1; world.state.rewards.huilan = false; world.state.tactics.huilan_equipped = false
	world.hero.position = Vector2(250,710); world.hero.facing = 0; world.hero.request("sweep",Vector2.ZERO,0)
	world.hero.advance_action(world.hero.action.def.windup+.012); world.hero.update_visual()
	var charged = load("res://scripts/hero.gd").new(); charged.world = world
	charged.position = Vector2(890,710); world.actors.add_child(charged)
	charged.spear_spirit = 3; charged.request("sweep",Vector2.ZERO,0)
	charged.advance_action(charged.action.def.windup+.012); charged.update_visual()
	for at in [Vector2(450,710),Vector2(1090,710)]:
		var warning = spawn("spear"); warning.position = at; warning.facing = PI
		warning.start_action(world.hero); warning.action.dir = PI; warning.action.t = warning.action.def.windup*.82
		warning.hp -= 12; warning.stagger = 25; warning.update_visual()
	world.fx.labels.clear(); world.fx.queue_redraw()
	caption("The red enemy sector remains visible through both cosmetic effects.",Vector2(215,870),23)
	await process_frame; await process_frame; await RenderingServer.frame_post_draw
	expect(root.get_texture().get_image().save_png("res://../.qa/combat-clarity-contact.png") == OK,"native combat clarity contact sheet saved")
	print("COMBAT_CLARITY_CAPTURE res://../.qa/combat-clarity-contact.png")
func run() -> void:
	world = Game.new(); world.test_mode = true; world.state = MemoryCampaign.new()
	root.add_child(world); world.set_process(false); world.set_physics_process(false)
	await settle(); world.state.difficulty = "normal"
	clear_enemies(); var scout = spawn("scout"); await settle()
	expect(scout.combat_status() == "", "idle scouts have no warning clutter")
	scout.take_hit(1,0,0,"player",0)
	expect(scout.combat_status() == "", "initial hit stun is not mislabeled as stable retaliation")
	scout.advance(.13)
	expect(scout.combat_status() == "guard", "anti-interrupt label persists after the triggering floater")
	var first_ratio = scout.combat_status_remaining("guard")
	scout.start_action(world.hero); scout.advance_action(.1,world.hero)
	var id = scout.action.id; var timing = scout.action.t; var before_hp = scout.hp
	scout.take_hit(1,0,0,"player",0)
	expect(scout.combat_status() == "guard" and scout.action.id == id and scout.action.t == timing,"guard reads the real unchanged retaliation, including its original telegraph")
	expect(scout.hp == before_hp-1,"stable retaliation remains damageable")
	scout.advance(.1)
	expect(scout.combat_status_remaining("guard") < first_ratio,"guard countdown follows gameplay time")
	scout.action = {}; scout.sequence = []; scout.cooldown = 10; scout.advance(.5)
	expect(scout.combat_status() == "" and scout.hit_interrupt_guard == 0,"guard label disappears when light interrupts return")
	scout.stagger = scout.stagger_max-1; scout.take_hit(1,0,0,"player",2)
	expect(scout.combat_status() == "break" and is_equal_approx(scout.combat_status_remaining("break"),1),"real poise break begins a full visible counter window")
	scout.advance(.7)
	expect(scout.combat_status() == "break" and is_equal_approx(scout.combat_status_remaining("break"),.6/1.3),"break timer tracks actual remaining stun")
	scout.advance(.61)
	expect(scout.combat_status() != "break" and scout.stagger_shield > 0,"poise immunity after recovery is not presented as a counter window")
	scout.stun = .8
	expect(scout.combat_status() != "break","an unrelated later stun cannot reuse an expired poise-break label")
	scout.hp = 0
	expect(scout.combat_status() == "","dead enemies have no live combat status")

	clear_enemies(); var shield = spawn("ironshield"); await settle()
	shield.facing = PI; shield.take_hit(1,0,0,"player",2)
	expect(shield.combat_status() == "" and shield.stagger > 0,"blocked light hits fill poise without inventing a break")
	shield.take_hit(1,0,0,"player",0,true)
	expect(shield.combat_status() == "shield" and shield.poise_break_left == 0,"shield stun is labeled broken shield, not poise break")
	shield.set_meta("withdrawing",true)
	expect(shield.combat_status() == "","retreating soldiers hide stale combat badges")

	clear_enemies(); var boss = spawn("boss","dujun"); await settle()
	boss.phase_time = 1
	expect(boss.combat_status() == "phase","boss phase notice retains highest priority")
	boss.phase_time = 0; boss.take_hit(1,0,0,"player",boss.stagger_max)
	expect(boss.combat_status() == "break" and is_equal_approx(boss.poise_break_left,2.1),"boss break uses its actual longer duration")
	boss.advance(1)
	expect(is_equal_approx(boss.combat_status_remaining("break"),1.1/2.1),"boss countdown uses boss duration rather than soldier duration")
	boss.stun = 0; boss.poise_break_left = 0; boss.stagger_shield = 0
	boss.start_action(world.hero)
	boss.action.t = boss.action.def.windup + boss.action.def.active
	expect(boss.combat_status() == "recovery","final move recovery exposes the opening")
	boss.sequence = [{"placeholder":true}]
	expect(boss.combat_status() != "recovery","a combo gap never advertises a false opening")

	# Compare real action-generated payloads, cost and timings for both Qs.
	for key in ["sweep","huilan"]:
		for charged in [false,true]:
			clear_enemies(); world.state.chapter = 2 if key == "huilan" else 1
			world.state.rewards.huilan = key == "huilan"
			world.state.tactics.huilan_equipped = key == "huilan"
			world.hero.spear_spirit = 3 if charged else 0
			world.hero.request("sweep",Vector2.ZERO,0)
			var action = world.hero.action; var definition = action.def.duplicate(true)
			expect(action.key == key and world.hero.qi == 70,"cue does not change Q selection/cost: "+key+str(charged))
			world.hero.advance_action(definition.windup-.001)
			expect(world.fx.entries.is_empty(),"no cosmetic hit before real windup: "+key+str(charged))
			world.hero.advance_action(.002)
			var slashes = world.fx.entries.filter(func(entry): return entry.type == "slash")
			expect(slashes.size() == 1 and slashes[0].info.get("empowered",false) == charged,"one real action selects the correct charged/un-charged visual: "+key+str(charged))
			expect(slashes[0].info.radius == definition.range and slashes[0].info.arc == definition.arc,"visual extent uses this action's actual reach/arc: "+key+str(charged))
			expect(world.fx.entries.filter(func(entry): return entry.type == "rally").is_empty(),"empowerment no longer overlays a separate ground rally ring")
			world.hero.advance_action(.05)
			expect(world.fx.entries.filter(func(entry): return entry.type == "slash").size() == 1,"later physics ticks cannot duplicate the cue")
			expect(world.hero.action.def == definition,"visual routing leaves attack values unchanged")
	if "--capture" in OS.get_cmdline_user_args(): await capture_contact_sheet()
	print("COMBAT_CLARITY_VERIFY ",checks," checks; ",failures.size()," failures")
	world.queue_free(); await process_frame
	quit(0 if failures.is_empty() else 1)
