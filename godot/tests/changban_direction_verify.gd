extends SceneTree
const Game=preload("res://scripts/world.gd")
const Campaign=preload("res://scripts/campaign.gd")
const Spacing=preload("res://scripts/changban_combat.gd")
class MemoryCampaign extends Campaign:
	func read_save() -> Dictionary: return {}
	func save() -> bool: return true
var world
var checks=0
var failures: Array=[]
func _initialize() -> void: call_deferred("run")
func expect(value: bool,message: String) -> void:
	checks+=1
	if not value: failures.append(message); push_error("CHANGBAN_DIRECTION: "+message)
func fresh(id: String="mountain") -> void:
	world.start_game("normal",1); world.choose_route("continue")
	if id!="mountain": world.enter_stage(id,Vector2(700,900),false)
	for enemy in world.enemies: enemy.hp=0; enemy.collision_layer=0
	for ally in world.allies: ally.hp=0
	world.hero.hp=200; world.hero.invincible=0
	await process_frame; await physics_frame; await physics_frame
func blocked_pair() -> Array:
	for shape in world.terrain.geometry:
		var rect: Rect2=shape.rect
		if rect.size.x>300 or rect.size.x<60 or rect.size.y<40: continue
		var center=rect.get_center()
		for offset in [-60,0,60]:
			var a=Vector2(rect.position.x-45,center.y+offset)
			var b=Vector2(rect.end.x+45,center.y+offset)
			if not Rect2(40,40,1520,1020).has_point(a) or not Rect2(40,40,1520,1020).has_point(b): continue
			if a.distance_to(b)<420 and not world.terrain.blocked(a,16) and not world.terrain.blocked(b,16) and not world.terrain.line_clear(a,b,0): return [a,b]
	return []
func run() -> void:
	world=Game.new(); world.test_mode=true; world.state=MemoryCampaign.new(); root.add_child(world)
	world.set_process(false); world.set_physics_process(false)
	await process_frame
	await fresh()
	expect(world.ui.scene_heading.text=="长坂 · 枪起乱军","new chapter has its own opening stamp")
	var before=world.state.snapshot().duplicate(true)
	world.ui.refresh(.3)
	expect(world.mode=="playing" and world.ui.scene_stamp.visible,"stamp never locks play or opens a dialog")
	var remaining=world.ui.scene_stamp_left
	world.pause("pause"); world.ui.refresh(3)
	expect(world.ui.scene_stamp_left==remaining and not world.ui.scene_stamp.visible,"pause hides and freezes stamp")
	world.resume(); world.ui.refresh(.1)
	expect(world.ui.scene_stamp_left<remaining,"resume continues stamp")
	world.ui.scene_stamp_left=0
	world.chapter_direction.enter(world)
	expect(world.ui.scene_stamp_left==0,"same-session revisit does not repeat the chapter heading")
	world.state.flags.civilians=true
	world.chapter_direction.advance(.1)
	expect(world.ui.scene_heading.text=="荒村得救","actual rescue flag produces a result beat")
	expect(world.state.seen==before.seen and world.state.cleared==before.cleared,"presentation does not write encounter progress")
	world.start_game("normal",2); world.choose_route("continue")
	expect(not is_instance_valid(world.chapter_presentation) and world.ui.scene_stamp_left==0,"later chapters have no Changban layer or caption")
	await fresh("village")
	var pair=blocked_pair()
	expect(pair.size()==2,"test uses a real blocked lane around an authored building")
	if pair.size()==2:
		world.hero.position=pair[1]
		var archer=world.spawn_enemy("archer",pair[0],"qa_lane")
		archer.alerted=true; archer.cooldown=0
		world.combat_pacing.left=0
		await physics_frame
		expect(not Spacing.attack_lane(archer,world.hero),"a building obstructs a real archer")
		archer.advance(.016)
		expect(archer.action.is_empty() and world.arrows.is_empty(),"occluded archer seeks an angle instead of firing into the wall")
		expect(world.combat_pacing.left==0,"blocked ranged lane does not steal another enemy's turn")
		archer.hp=0; archer.collision_layer=0
	# A clear-road encounter uses the same production attack definitions.
	world.hero.position=Vector2(300,900)
	var spear=world.spawn_enemy("spear",Vector2(440,900),"qa_spacing")
	expect(world.terrain.line_clear(spear.position,world.hero.position,16),"spacing fixture is on a clear road")
	spear.alerted=true; spear.cooldown=5
	for i in range(60): spear.advance(1.0/60)
	expect(spear.position.distance_to(world.hero.position)>80,"waiting spearman retains spear distance instead of collapsing onto hero")
	spear.cooldown=0; world.combat_pacing.left=0
	for i in range(60):
		spear.advance(1.0/60)
		if not spear.action.is_empty(): break
	expect(not spear.action.is_empty(),"spacing still allows the spear soldier to attack")
	var left=world.spawn_enemy("sword",Vector2(445,895),"qa_shoulders")
	var right=world.spawn_enemy("sword",Vector2(445,905),"qa_shoulders")
	var left_goal=Spacing.spacing_point(left,world.hero)
	var right_goal=Spacing.spacing_point(right,world.hero)
	expect((left_goal.y-world.hero.position.y)*(right_goal.y-world.hero.position.y)<0,"two close fighters use opposite shoulders regardless of engine object IDs")
	world.pause("pause")
	var clock=world.chapter_presentation.clock
	world._physics_process(.5)
	expect(world.chapter_presentation.clock==clock,"presentation stops with paused combat")
	world.resume(); world.hit_stop=.1; world._physics_process(.016)
	expect(world.chapter_presentation.clock==clock,"hit-stop also freezes the scene accents")
	world.hit_stop=0; world.hero.hp=0; world.mode="defeat"
	world._physics_process(.5)
	expect(world.chapter_presentation.clock==clock,"death leaves no moving battle vignette")
	world.queue_free(); await process_frame
	print("CHANGBAN_DIRECTION_VERIFY ",checks," checks; ",failures.size()," failures")
	quit(0 if failures.is_empty() else 1)
