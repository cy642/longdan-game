extends SceneTree
## Production mesh/pose contract. No saves or GPU capture are required.
const Enemy = preload("res://scripts/enemy.gd")
const Roster = preload("res://scripts/enemy_roster.gd")
class ReviewState extends RefCounted:
	var chapter = 3
	var flags = {"adou":false}
class ReviewWorld extends Node2D:
	var state = ReviewState.new()
	var stage = "jg_final"
var checks = 0
var failures: Array = []

func _initialize() -> void: call_deferred("run")
func expect(ok: bool,message: String) -> void:
	checks += 1
	if not ok: failures.append(message); push_error("VANGUARD_VISUAL: "+message)
func pose_gap(a: Dictionary,b: Dictionary) -> float:
	var gap = 0.0
	for key in a: gap = maxf(gap,absf(a[key]-b[key]))
	return gap
func sample(enemy,definition: Dictionary,time: float,direction: float,id: int) -> Dictionary:
	enemy.facing = direction
	enemy.action = {"id":id,"key":"enemy","dir":direction,"t":time,"def":definition}
	return enemy.visual.sample_enemy_action(enemy.action)

func run() -> void:
	var review = ReviewWorld.new(); root.add_child(review)
	var enemy = Enemy.new(); enemy.world = review; enemy.kind = "boss"; enemy.boss_id = "vanguard"
	enemy.visual_profile=Roster.resolve(review.state.chapter,review.stage,enemy.kind,enemy.boss_id,enemy.group_id)
	review.add_child(enemy)
	var visual = enemy.visual
	expect(visual.enemy_equipment == null,"independently painted halberd and iron armor need no duplicate code attachment")
	expect(enemy.visual_profile.id == "boss_vanguard" and visual.last_frame[0] == "enemy_commanders" and visual.last_frame[1] == enemy.visual_profile.index,"vanguard selects its own painted commander frame")
	expect(visual.rig.get_parent() == visual and not visual.body.visible,"painted equipment mirrors and falls with the complete production rig")
	expect(not visual.rig_data.head_indices.is_empty() and not visual.rig_data.weapon_indices.is_empty(),"painted face and halberd protection cover real mesh vertices")
	var model_scale = visual.current_scale
	var original_bottom = -INF
	for index in range(visual.rig_data.rest.size()):
		if not visual.rig_data.weapon_indices.has(index): original_bottom = maxf(original_bottom,visual.rig_data.rest[index].y)
	enemy.moving = true; visual.move_blend = 1; enemy.walk_distance = 18; enemy.update_visual()
	var animated_bottom = -INF
	for index in range(visual.rig.polygon.size()):
		if not visual.rig_data.weapon_indices.has(index): animated_bottom = maxf(animated_bottom,visual.rig.polygon[index].y)
	expect(absf(animated_bottom-original_bottom)*model_scale < .7,"walking support boot stays on the ground")
	enemy.moving = false; visual.move_blend = 0
	var id = 100
	for direction in [0.0,PI*.5,PI,-PI*.5]:
		for chain in Enemy.BOSS_MOVES.vanguard:
			for definition in chain:
				id += 1
				var total = definition.windup+definition.active+definition.recovery
				for boundary in [definition.windup,definition.windup+definition.active,total]:
					var before = sample(enemy,definition,boundary-.00001,direction,id)
					var after = sample(enemy,definition,boundary+.00001,direction,id)
					expect(pose_gap(before,after) < .004,definition.name+" has continuous action boundary")
				expect(pose_gap(sample(enemy,definition,0,direction,id),visual.neutral_pose()) == 0,definition.name+" begins at guard")
				expect(pose_gap(sample(enemy,definition,total,direction,id),visual.neutral_pose()) < .0001,definition.name+" settles into guard")
				var windup = sample(enemy,definition,definition.windup*.9,direction,id)
				var active = sample(enemy,definition,definition.windup+definition.active*.42,direction,id)
				expect(pose_gap(windup,active) > .25,definition.name+" visibly winds up then releases")
				var prior: PackedVector2Array = []; var biggest_step = 0.0
				# Fixed 120 Hz sampling keeps this continuity limit independent of
				# how much deliberately long anticipation/recovery a move contains.
				var samples = int(ceil(total*120))
				for frame in range(samples+1):
					sample(enemy,definition,total*frame/samples,direction,id); enemy.update_visual()
					var points: PackedVector2Array = visual.rig.polygon
					var finite = true; var face_error = 0.0; var weapon_error = 0.0
					for point in points:
						if not point.is_finite(): finite = false
					var upper = visual.enemy_upper_transform(visual.displayed_pose)
					for index in visual.rig_data.head_indices:
						face_error = maxf(face_error,points[index].distance_to(upper*visual.rig_data.rest[index]))
					for index in visual.rig_data.weapon_indices:
						weapon_error = maxf(weapon_error,points[index].distance_to(upper*visual.rig_data.rest[index]))
					if not prior.is_empty():
						for index in range(points.size()): biggest_step = maxf(biggest_step,points[index].distance_to(prior[index])*model_scale)
					prior = points.duplicate()
					expect(finite and face_error < .001 and weapon_error < .001,definition.name+" keeps painted face and halberd shaft rigid")
					expect(visual.current_scale == model_scale and visual.position.is_zero_approx() and visual.scale == Vector2.ONE,definition.name+" retains fixed body scale and foot anchor")
					expect(weapon_error < .001 and visual.enemy_equipment == null,definition.name+" keeps painted crescent and shaft together without a second weapon")
				expect(biggest_step < 15.0,definition.name+" avoids single-frame mesh jumps: "+str(biggest_step))
	var sweep = Enemy.BOSS_MOVES.vanguard[2][0]; var returning = Enemy.BOSS_MOVES.vanguard[3][1]
	var first = sample(enemy,sweep,sweep.windup*.95,0,id+1)
	var second = sample(enemy,returning,returning.windup*.95,0,id+2)
	expect(first.arm > .3 and second.arm < -.3,"return sweep visibly loads from the opposite side")
	enemy.action = {}; visual.react_to_hit(0,false,true); enemy.hp = 0; enemy.dead_time = .46; enemy.update_visual()
	expect(absf(visual.rotation) > 1.0 and visual.rig.get_parent() == visual and visual.enemy_equipment == null,"death rotates complete painted body and halberd together")
	print("VANGUARD_VISUAL_VERIFY ",checks," checks; ",failures.size()," failures")
	review.queue_free(); await process_frame; await process_frame
	quit(0 if failures.is_empty() else 1)
