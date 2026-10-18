extends SceneTree
## Actual chapter/world nodes, interaction routing and forward/backward spawn audit.
const Campaign=preload("res://scripts/campaign.gd")
class MemoryCampaign extends Campaign:
	func read_save() -> Dictionary: return last_save.duplicate(true)
	func save() -> bool:
		last_save=snapshot(); durable=true; return true
class MemoryWorld extends "res://scripts/world.gd":
	func save_progress() -> void:
		if is_instance_valid(tactics): tactics.capture_roster()
		state.save()
var world
var checks=0
var failures: Array=[]

func _initialize() -> void: call_deferred("run")
func expect(condition: bool,label: String) -> void:
	checks+=1
	if not condition: failures.append(label); push_error(label)
func settle() -> void:
	await process_frame; await physics_frame; await physics_frame
func completed_chapter() -> void:
	world.state.reset("normal",2); world.load_chapter(2)
	for flag in ["huangzhong","wounded","beacon","cart"]: world.state.flags[flag]=true
	world.state.tactics={"gate":"COUNTER_DIRECT","volley_spent":true,"roster":[]}
	for region in world.definitions:
		for group in world.definitions[region].groups: world.state.cleared.append(region+":"+str(group.id))
func enter(id: String) -> void:
	world.mode="playing"; world.enter_stage(id,Vector2.INF,false); world.ui.hide_overlay(); await settle()
func assert_spawn(label: String) -> void:
	expect(not world.terrain.blocked(world.hero.position,world.hero.radius),label+" hero has clear feet")
	for ally in world.allies: expect(not world.terrain.blocked(ally.position,ally.radius),label+" ally has clear feet")
func use(id: String,destination: String) -> void:
	var object=world.object_by_id(id)
	expect(not object.is_empty(),"real interaction exists "+id)
	if object.is_empty(): return
	world.mode="playing"; world.hero.position=Vector2(object.x,object.y)
	expect(world.nearest_object().get("id","")==id,"nearest E target selects "+id)
	expect(world.interact(),"production interaction accepts "+id)
	if world.mode=="dialog" and destination=="hs_final": world.choose_route("hanshuiFinal")
	expect(not world.pending_stage.is_empty(),id+" schedules a stage transition")
	world._physics_process(0)
	await settle()
	expect(world.stage==destination,id+" enters "+destination)
	assert_spawn(id+" destination")

func run() -> void:
	world=MemoryWorld.new(); world.test_mode=true; world.state=MemoryCampaign.new(); root.add_child(world)
	world.set_process(false); world.set_physics_process(false)
	await settle(); completed_chapter()
	for region in world.definitions:
		await enter(region); assert_spawn(region+" initial")
		expect(world.tactics!=null and world.tactics.world==world,region+" binds real TacticDirector")
		for object in world.definition.objects:
			var node=world.actors.get_node_or_null(NodePath(str(object.id)))
			expect(is_instance_valid(node) and node.world==world,region+" creates bound object "+object.id)
			if node:
				var expected=world.tactics.cart.position if object.kind=="graincart" else Vector2(object.x,object.y)
				expect(node.position.distance_to(expected)<.1,object.id+" uses the actual layout/escort coordinate")
		if region=="hs_return": expect(is_instance_valid(world.tactics.cart) and not world.terrain.blocked(world.tactics.cart.position,28),"actual completed cart rests on clear ground")
	# Exercise the real E input selection and world pending-stage path both ways.
	await enter("hs_forest")
	await use("hs_to_grain","hs_grain")
	await use("hs_to_return","hs_return")
	await use("hs_to_camp","hs_camp")
	await use("hs_to_river","hs_river")
	await use("hs_to_final","hs_final")
	await use("hs_back_river","hs_river")
	await use("hs_back_camp","hs_camp")
	await use("hs_back_return","hs_return")
	await use("hs_back_grain","hs_grain")
	await use("hs_back_forest","hs_forest")
	await enter("hs_return")
	var shortcut=world.object_by_id("hs_wounded_to_camp")
	world.state.flags.wounded=false
	expect(world.object_blocked(shortcut),"return shortcut is locked before rescuing Zhang Zhu")
	world.state.flags.wounded=true; world.state.flags.cart=false
	expect(world.object_blocked(shortcut),"return shortcut cannot bypass the unfinished escort")
	world.state.flags.cart=true
	await use("hs_wounded_to_camp","hs_camp")
	expect(world.hero.position.distance_to(Vector2(480,570))<1,"shortcut arrives in the inner camp")
	await use("hs_back_wounded","hs_return")
	expect(world.hero.position.distance_to(Vector2(390,460))<1,"camp shortcut returns near Zhang Zhu")
	# Preserve carried identities/HP across the return path; nodes are not new kills.
	world.state.tactics.roster=[{"id":"layout_pursuer","kind":"scout","hp":31.0}]
	await enter("hs_river")
	expect(world.enemies.size()==1 and world.enemies[0].get_meta("roster_id","")=="layout_pursuer" and is_equal_approx(world.enemies[0].hp,31.0),"real river restores the carried pursuer")
	await use("hs_back_camp","hs_camp")
	expect(world.enemies.size()==1 and world.enemies[0].get_meta("roster_id","")=="layout_pursuer" and is_equal_approx(world.enemies[0].hp,31.0),"backtracking preserves pursuer identity and HP")
	world.queue_free(); await process_frame; await process_frame; await create_timer(.12).timeout
	print("HANSHUI_WORLD_LAYOUT_VERIFY ",checks," checks; ",failures.size()," failures")
	quit(0 if failures.is_empty() else 1)
