extends SceneTree
## Reproducible native-rendered QA. Scenario placement is explicit; gameplay
## orders, HUD refresh, bow windup and arrow collision use production code.
const Game = preload("res://scripts/world.gd")
const Campaign = preload("res://scripts/campaign.gd")
class MemoryCampaign extends Campaign:
	func read_save() -> Dictionary: return last_save.duplicate(true)
	func save() -> bool:
		last_save = snapshot(); durable = true; return true
var world
var failures: Array = []
var captured = 0
var missing: Dictionary = {}

func _initialize() -> void: call_deferred("run")
func expect(condition: bool,message: String) -> void:
	if not condition: failures.append(message); push_error(message)
func fingerprints() -> Dictionary:
	var output: Dictionary = {}
	for path in [Campaign.SAVE_PATH,Campaign.LEGACY_PATH]:
		output[path] = FileAccess.get_file_as_bytes(path).hex_encode().sha256_text() if FileAccess.file_exists(path) else "absent"
	return output
func inspect_labels(node: Node) -> void:
	if node is Label or node is Button:
		for c in node.text:
			if c.unicode_at(0) > 127 and not world.ui.font.has_char(c.unicode_at(0)): missing[c] = true
	for child in node.get_children(): inspect_labels(child)
func capture(label: String) -> void:
	world.camera.position = world.hero.position; world.camera.force_update_scroll()
	world.ui.support_clock = 0; world.ui.refresh(.016)
	world.hero.update_visual(); world.fx.queue_redraw()
	await process_frame; await process_frame; await RenderingServer.frame_post_draw
	inspect_labels(world.ui.root)
	var path = ProjectSettings.globalize_path("res://../.qa/polish-"+label+".png")
	expect(root.get_texture().get_image().save_png(path) == OK,"capture failed: "+label)
	captured += 1
	print("POLISH_CAPTURE ",label," toast=",world.ui.toast_text.text," support=",world.ui.support_text.text)

func run() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("Use graphical Godot for UI review."); quit(1); return
	root.size = Vector2i(1280,720)
	var saved = fingerprints()
	world = Game.new(); world.test_mode = true; world.state = MemoryCampaign.new(); root.add_child(world)
	world.set_process(false); world.set_physics_process(false)
	if root.focus_exited.is_connected(world.on_focus_lost): root.focus_exited.disconnect(world.on_focus_lost)
	await process_frame
	world.start_game("normal",1)
	if world.mode == "dialog": world.choose_route("continue")
	world.ui.hide_overlay(); world.mode = "playing"
	await capture("mountain-entry")
	world.hero.add_spear_spirit(3); world.hero.qi = 12
	expect(not world.hero.request("sweep",Vector2.ZERO,0),"low-qi request should be declined")
	expect(world.hero.spear_spirit == 3,"failed Q must retain full spirit")
	await capture("low-qi-full-spirit")
	# Clear by the real defeat path so the existing camp becomes available.
	for enemy in world.enemies.duplicate():
		if enemy.body_alive(): enemy.take_hit(10000,0,0,"player",0,true)
	var camp: Dictionary = {}
	for object in world.definition.objects:
		if object.kind == "camp": camp = object; break
	expect(not camp.is_empty(),"first mountain camp exists")
	world.hero.position = Vector2(camp.x,camp.y); world.interact()
	expect(world.mode == "camp" and world.ui.first_choice.text.begins_with("连锋"),"first camp defaults keyboard focus to 连锋")
	await capture("first-camp")
	world.ui.first_choice.pressed.emit()
	expect(world.state.battle_art == "assault","default first-camp action equips 连锋")
	world.load_chapter(2); world.state.reset("normal",2); world.mode = "playing"
	world.enter_stage("hs_grain",Vector2(1080,410),false); world.ui.hide_overlay()
	for enemy in world.enemies:
		enemy.hp = 0; enemy.collision_layer = 0; enemy.visible = false
	var target = world.spawn_enemy("crossbow",Vector2(1000,360),"hs_g2")
	target.start_action(world.hero); target.update_visual()
	var support = world.tactics.support
	await physics_frame; await physics_frame
	await capture("huangzhong-ready")
	world.set_command("charge")
	expect(support.draw_left > 0,"real charge command starts draw")
	support.advance(.19)
	await capture("huangzhong-draw")
	support.advance(.20)
	expect(support.arrow_left > 0 and target.hp == target.max_hp,"capture a real flying arrow before its hit")
	await capture("huangzhong-arrow")
	support.advance(.20); target.update_visual(); world.fx.advance(.04)
	expect(target.hp < target.max_hp and target.stun > 0,"native support arrow landed and briefly interrupted")
	await capture("huangzhong-impact")
	expect(fingerprints() == saved,"preview must never change real player saves")
	print("POLISH_PREVIEW ",captured," captures; ",failures.size()," failures; missing-font-characters=",missing.keys())
	world.queue_free(); await process_frame; quit(0 if failures.is_empty() else 1)
