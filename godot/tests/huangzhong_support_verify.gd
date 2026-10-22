extends SceneTree
## Real production World, Enemy and Interactable nodes; memory-only saves.
const Campaign = preload("res://scripts/campaign.gd")
class MemoryCampaign extends Campaign:
	func read_save() -> Dictionary: return last_save.duplicate(true)
	func save() -> bool:
		last_save = snapshot(); durable = true; return true
class MemoryWorld extends "res://scripts/world.gd":
	func save_progress() -> void: state.save()
var world
var support
var marker
var checks = 0
var failures: Array = []

func _initialize() -> void: call_deferred("run")
func expect(condition: bool,message: String) -> void:
	checks += 1
	if not condition: failures.append(message); push_error("FAIL: "+message)
func settle() -> void:
	await process_frame; await physics_frame; await physics_frame
func fingerprints() -> Dictionary:
	var output: Dictionary = {}
	for path in [Campaign.SAVE_PATH,Campaign.LEGACY_PATH]:
		output[path] = FileAccess.get_file_as_bytes(path).hex_encode().sha256_text() if FileAccess.file_exists(path) else "absent"
	return output
func clear_test_enemies() -> void:
	for enemy in world.enemies:
		enemy.hp = 0; enemy.collision_layer = 0
	support.cancel(); support.cooldown = 0
func enemy_at(p: Vector2,kind: String = "scout",group: String = "hs_g2"):
	var target = world.spawn_enemy(kind,p,group)
	target.facing = 0
	return target
func fire_to_end() -> void:
	for i in range(80): support.advance(1.0/60)
func barrier(p: Vector2) -> StaticBody2D:
	var body = StaticBody2D.new(); body.collision_layer = 1
	var shape = CollisionShape2D.new(); shape.shape = RectangleShape2D.new(); shape.shape.size = Vector2(28,130)
	body.add_child(shape); body.position = p; world.add_child(body)
	return body

func run() -> void:
	var saved = fingerprints()
	world = MemoryWorld.new(); world.test_mode = true; world.state = MemoryCampaign.new()
	root.add_child(world); world.set_physics_process(false); world.set_process(false)
	await settle(); world.start_game("normal",2)
	world.mode = "playing"; world.ui.hide_overlay(); world.enter_stage("hs_grain")
	await settle(); support = world.tactics.support; marker = world.actors.get_node("hs_huangzhong")
	expect(is_instance_valid(support) and is_instance_valid(marker),"real grain-road director owns support and the existing Huang Zhong marker")
	expect(marker.get_child_count() == 1 and marker.get_child(0) is Sprite2D,"reuse portrait without adding a blocking NPC body")
	clear_test_enemies()
	var point = marker.position+Vector2(-150,75)
	world.hero.position = point+Vector2(-60,35)
	var target = enemy_at(point)
	await settle()
	expect(support.line_clear(marker.position,target.position),"actual north grain-road encounter has clear arrow geometry")
	var before = target.hp
	for i in range(8): support.advance(1.0)
	expect(target.hp == before and support.shots_fired == 0,"standing in range never triggers automatic damage or firing")
	expect(world.tactics.support_status().ready,"ready status reflects eligible close main encounter")
	target.start_action(world.hero)
	expect(world.tactics.request_support(),"actual director request begins a single support shot")
	expect(target.hp == before and support.draw_left > 0,"request has a real bow windup before damage")
	support.advance(.14)
	expect(marker.support_tension > .4 and marker.support_tension < .6,"existing marker visibly draws the bow over time")
	var draw_before = support.draw_left; var cooldown_before = support.cooldown
	world.mode = "pause"; support.advance(20)
	expect(support.draw_left == draw_before and support.cooldown == cooldown_before,"pause freezes draw and cooldown")
	expect(not world.tactics.request_support(),"pause cannot request another shot")
	world.mode = "playing"; fire_to_end()
	expect(is_equal_approx(target.hp,before-10),"one real swept arrow deals only ten ally damage")
	expect(support.shots_fired == 1 and support.hits_landed == 1,"single press produces one arrow and one hit")
	expect(target.action.is_empty() and target.stun >= .32 and target.stagger == 24,"one clean hit interrupts the sequence and gives a brief opening")
	expect(not world.tactics.request_support(),"repeat command during cooldown cannot spam arrows")
	expect(world.tactics.support_status().cooldown > 0 and "秒" in world.tactics.support_status().text,"HUD status exposes the actual cooldown")
	support.advance(6)
	expect(world.tactics.support_status().ready and support.shots_fired == 1,"cooldown expiration readies but never auto-fires")

	# Shield-facing is still the Enemy's native shield/poise contract.
	clear_test_enemies(); target = enemy_at(point,"ironshield"); target.facing = (marker.position-point).angle()
	await settle(); before = target.hp; target.start_action(world.hero); target.facing = (marker.position-point).angle()
	expect(world.tactics.request_support(),"frontal iron shield is an eligible mainline target")
	fire_to_end()
	expect(is_equal_approx(target.hp,before-2.4),"native shield reduces support damage")
	expect(not target.action.is_empty() and target.stun == 0,"support does not erase an iron shield's frontal attack")

	# The floor is checked both at selection and real impact, without healing.
	clear_test_enemies(); target = enemy_at(point); target.hp = target.max_hp*.22+1
	await settle(); expect(world.tactics.request_support(),"weak but above-floor guard can receive one arrow")
	fire_to_end()
	expect(is_equal_approx(target.hp,target.max_hp*.22) and target.body_alive(),"support cannot kill or damage below the 22-percent ally floor")
	support.advance(6); before = target.hp
	expect(not world.tactics.request_support() and target.hp == before,"floor-health guard cannot be farmed for repeated stun")
	target.hp = 2; support.advance(6)
	expect(not world.tactics.request_support() and target.hp == 2,"already low health never heals to the ally floor")

	clear_test_enemies(); target = enemy_at(point,"crossbow","hs_beacon_guard")
	await settle(); before = target.hp
	expect(not world.tactics.request_support() and support.cooldown == 0,"optional beacon guards are outside support scope and rejected requests cost no cooldown")
	target.group_id = "hs_g2"; world.active_boss = "dujun"
	expect(not world.tactics.support_status().visible and not world.tactics.request_support(),"active boss blocks support entirely")
	world.active_boss = ""; world.hero.position = Vector2(190,900)
	expect(not world.tactics.support_status().ready and not world.tactics.request_support(),"distant player cannot call a remote autonomous battle")
	world.hero.position = point+Vector2(-60,35)
	var wall = barrier(marker.position.lerp(point,.5)); await settle()
	expect(not world.tactics.request_support() and "遮挡" in world.tactics.support_status().text,"real terrain-body occlusion blocks selection and is explained")
	wall.queue_free(); await settle()
	expect(world.tactics.request_support(),"removing actual obstruction permits a shot")
	wall = barrier(marker.position.lerp(point,.5)); await settle(); fire_to_end()
	expect(target.hp == before,"an obstacle appearing after aim blocks the flying arrow")
	wall.queue_free(); await settle()

	clear_test_enemies(); target = enemy_at(point); await settle()
	before = target.hp; expect(world.tactics.request_support(),"shot can begin before the guard dodges")
	target.position += Vector2(0,95); fire_to_end()
	expect(target.hp == before,"locked aim does not home onto a soldier who moved aside")

	clear_test_enemies(); target = enemy_at(point); await settle()
	world.set_command("follow"); world.set_command("hold")
	expect(support.draw_left == 0,"real follow/hold orders never trigger Huang Zhong")
	world.set_command("charge")
	expect(support.draw_left > 0,"production charge command actually invokes the support owner")
	fire_to_end()
	for id in world.definition.main_groups: world.state.cleared.append(world.stage+":"+id)
	expect("按 E" in world.tactics.support_status().text and not world.tactics.support_status().ready,"cleared encounter directs the player to the existing rescue interaction")
	for id in world.definition.main_groups: world.state.cleared.erase(world.stage+":"+id)

	clear_test_enemies(); target = enemy_at(point); await settle(); before = target.hp
	expect(world.tactics.request_support(),"support starts normally before the rescue flag is set")
	world.state.flags.huangzhong = true; fire_to_end()
	expect(target.hp == before and support.arrow_left == 0 and support.draw_left == 0,"rescuing Huang Zhong cancels pending draw and shot")
	expect(not world.tactics.support_status().visible and not world.tactics.request_support(),"rescued NPC stops support without adding mandatory progress")
	world.state.flags.huangzhong = false
	for stage in ["hs_return","hs_camp","hs_river","hs_final"]:
		world.enter_stage(stage); await settle()
		expect(not world.tactics.support_status().visible and not world.tactics.request_support(),"support is absent from "+stage)
	expect(fingerprints() == saved,"support verification preserves real v1 and v2 player saves")
	print("HUANGZHONG_SUPPORT_VERIFY ",checks," checks; ",failures.size()," failures")
	world.queue_free(); await process_frame; await process_frame
	quit(0 if failures.is_empty() else 1)
