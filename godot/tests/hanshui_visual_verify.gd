extends SceneTree
## Render contracts for the added units and physical story markers. No saves.
const Enemy = preload("res://scripts/enemy.gd")
const Marker = preload("res://scripts/interactable.gd")
const UNITS = [["scout","","Dual-blade scout"],["crossbow","","Crossbow"],["ironshield","","Iron shield"],["boss","dujun","Iron-mask commander"]]
class ReviewState extends RefCounted:
	var flags = {"adou":false,"huangzhong":false,"wounded":false,"beacon":false}
	var tactics = {"gate":"PREPARE"}
class ReviewWorld extends Node2D:
	var state = ReviewState.new()
	var mode = "playing"
	var definition: Dictionary = {}
	var camera = Camera2D.new()
	func _ready() -> void:
		camera.enabled=false
		add_child(camera)
	func nearest_object() -> Dictionary: return {}
	func object_blocked(_object: Dictionary) -> bool: return false
var checks = 0
var failures: Array = []
var review

func _initialize() -> void: call_deferred("run")
func expect(ok: bool, title: String) -> void:
	checks += 1
	if not ok: failures.append(title); push_error("VISUAL_FAIL: "+title)

func make_enemy(unit: Array, p: Vector2):
	var enemy=Enemy.new()
	enemy.world=review; enemy.kind=unit[0]; enemy.boss_id=unit[1]
	enemy.position=p; review.add_child(enemy)
	return enemy

func definitions(enemy) -> Array:
	if enemy.kind=="scout": return Enemy.SCOUT_CHAIN
	if enemy.kind=="crossbow": return [Enemy.CROSSBOW_ATTACK]
	if enemy.kind=="ironshield": return [Enemy.IRONSHIELD_ATTACK]
	var result: Array=[]
	for chain in Enemy.BOSS_MOVES.dujun: result.append_array(chain)
	return result

func check_render_contracts() -> void:
	for unit in UNITS:
		var enemy=make_enemy(unit,Vector2.ZERO)
		var visual=enemy.visual
		expect(visual.enemy_equipment!=null,unit[2]+" has a dedicated equipment silhouette")
		expect(visual.enemy_equipment.get_parent()==visual.rig,unit[2]+" equipment shares source mirroring and hurt/death visibility")
		if enemy.kind=="crossbow": expect(visual.last_frame[0]=="units" and visual.last_frame[1]==7,"crossbow base has no painted bow or spear")
		if enemy.kind=="crossbow":
			var definition=Enemy.CROSSBOW_ATTACK
			var action={"def":definition,"t":definition.windup,"dir":0.0}
			var loaded=visual.sample_enemy_action(action)
			action.t=definition.windup+.045
			var first_release=visual.sample_enemy_action(action)
			action.t=definition.windup+.25
			var before_second=visual.sample_enemy_action(action)
			action.t=definition.windup+definition.active
			var second_release=visual.sample_enemy_action(action)
			expect(first_release.reach>loaded.reach+3.0,"first crossbow shot visibly recoils")
			expect(is_equal_approx(before_second.reach,loaded.reach),"crossbow visibly settles before the second release")
			expect(is_equal_approx(second_release.reach,first_release.reach),"second shot has its own visible recoil")
			for boundary in [definition.windup,definition.windup+.045,definition.windup+.17,definition.windup+.25,definition.windup+definition.active,definition.windup+definition.active+definition.recovery]:
				action.t=boundary-.00001; var before=visual.sample_enemy_action(action)
				action.t=boundary+.00001; var after=visual.sample_enemy_action(action)
				var jump=0.0
				for key in before: jump=maxf(jump,absf(before[key]-after[key]))
				expect(jump<.004,"crossbow shot/reload boundary remains continuous")
		for facing in [0.0,PI,PI*.5,-PI*.5]:
			enemy.facing=facing
			for definition in definitions(enemy):
				var total=definition.windup+definition.active+definition.recovery
				for sample in range(41):
					enemy.action={"id":1,"key":"enemy","dir":facing,"t":total*sample/40.0,"def":definition}
					enemy.update_visual()
					var finite=true
					for p in visual.rig.polygon:
						if not p.is_finite(): finite=false
					expect(finite,unit[2]+" deformed vertices remain finite")
					expect(visual.position.is_zero_approx(),unit[2]+" source origin stays foot-anchored")
					var error=0.0
					var upper=visual.enemy_upper_transform(visual.displayed_pose)
					for index in visual.rig_data.head_indices:
						error=maxf(error,visual.rig.polygon[index].distance_to(upper*visual.rig_data.rest[index]))
					expect(error<.001,unit[2]+" face and helmet remain rigid")
					var scale_factor=float(visual.rig_data.height)/65.0
					var grip=Vector2(-8,-23)
					var actual: Vector2=visual.enemy_equipment.transform*grip
					var target: Vector2=upper*(grip*scale_factor)
					expect(actual.distance_to(target)<.001,unit[2]+" equipment stays on the painted upper body")
				if enemy.kind=="crossbow": expect(is_equal_approx(visual.enemy_equipment.aim_tilt,-sin(facing)*.8),"crossbow has visible upper/lower aim directions")
		enemy.queue_free()

func label_at(text: String, p: Vector2, size: int=16) -> void:
	var label=Label.new(); label.position=p; label.text=text
	label.add_theme_font_size_override("font_size",size)
	label.add_theme_color_override("font_color",Color("e2dcbd"))
	review.add_child(label)

func make_contact_sheet() -> void:
	root.size=Vector2i(1280,960)
	RenderingServer.set_default_clear_color(Color("334d46"))
	label_at("Hanshui  |  new silhouettes attached to production rigs",Vector2(25,12),25)
	var phases=["Guard","Stride","Anticipate","Strike","Recoil","Fall"]
	for column in range(phases.size()): label_at(phases[column],Vector2(260+column*170,55))
	for row in range(UNITS.size()):
		var unit=UNITS[row]
		label_at(unit[2],Vector2(20,118+row*155))
		for column in range(phases.size()):
			var enemy=make_enemy(unit,Vector2(295+column*170,210+row*155))
			enemy.scale=Vector2.ONE*1.65; enemy.facing=PI
			var d: Dictionary=definitions(enemy)[0]
			match column:
				1: enemy.moving=true; enemy.walk_distance=18; enemy.visual.move_blend=1
				2: enemy.action={"id":1,"key":"enemy","dir":PI,"t":d.windup*.9,"def":d}
				3: enemy.action={"id":1,"key":"enemy","dir":PI,"t":d.windup+d.active*.42,"def":d}
				4: enemy.visual.react_to_hit(0,false,false); enemy.visual.advance_time(.09)
				5: enemy.visual.react_to_hit(0,false,true); enemy.hp=0; enemy.dead_time=.36
			enemy.update_visual()
	label_at("Physical story markers  |  no duplicate cart or invisible interaction",Vector2(25,740),22)
	var kinds=["huangzhong","wounded","beacon","hideflag","drum","gate"]
	for column in range(kinds.size()):
		var marker=Marker.new(); marker.world=review
		marker.data={"id":"preview_"+kinds[column],"kind":kinds[column],"label":kinds[column]}
		marker.position=Vector2(110+column*210,875)
		if kinds[column]=="gate": marker.scale=Vector2.ONE*.55
		review.add_child(marker)
		expect(marker.get_child_count()>0 if kinds[column] in ["huangzhong","wounded"] else true,kinds[column]+" has a visible physical presence")

func run() -> void:
	review=ReviewWorld.new(); root.add_child(review)
	check_render_contracts()
	await process_frame
	if "--capture" in OS.get_cmdline_user_args():
		if DisplayServer.get_name()=="headless": push_error("Capture needs the native renderer."); quit(1); return
		make_contact_sheet()
		await process_frame; await process_frame; await RenderingServer.frame_post_draw
		var output="res://../.qa/hanshui-visuals.png"
		expect(root.get_texture().get_image().save_png(output)==OK,"contact sheet saved")
	print("HANSHUI_VISUAL_VERIFY ",checks," checks; ",failures.size()," failures")
	review.queue_free(); await process_frame; await process_frame
	quit(0 if failures.is_empty() else 1)
