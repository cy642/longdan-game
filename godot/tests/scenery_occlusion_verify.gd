extends SceneTree
## Real-world legal feet, foreground rock overlap and reversible local fading.
const Game=preload("res://scripts/world.gd")
const Campaign=preload("res://scripts/campaign.gd")
class MemoryCampaign extends Campaign:
	func read_save() -> Dictionary: return {}
	func save() -> bool: return true
var checks=0
var failures: Array=[]

func _initialize() -> void: call_deferred("run")
func expect(ok: bool, label: String) -> void:
	checks+=1
	if not ok: failures.append(label); push_error("OCCLUSION_FAIL "+label)

func run() -> void:
	var game=Game.new(); game.test_mode=true; game.state=MemoryCampaign.new()
	root.add_child(game); game.set_process(false); game.set_physics_process(false)
	await process_frame
	game.state.reset("normal",2); game.load_chapter(2); game.mode="playing"
	game.enter_stage("hs_return",Vector2(200,900),false); game.ui.hide_overlay()
	await process_frame; await physics_frame
	var rock
	for node in game.actors.get_children():
		if node.get_script()==load("res://scripts/hanshui_layout.gd"):
			node.set_process(false)
			if node.item.kind=="rockwall" and rock==null: rock=node
	expect(rock!=null,"real return map has a physical rockwall prop")
	if rock==null: game.queue_free(); quit(1); return
	expect(rock.rendered_prop!=null,"test uses the imported prop atlas")
	var r=rock.item.rect
	var found=Vector2.INF
	var query=PhysicsShapeQueryParameters2D.new(); query.collision_mask=1
	var circle=CircleShape2D.new(); circle.radius=game.hero.radius; query.shape=circle
	for side in [-1,1]:
		for y in range(int(r[1])+8,int(r[1]+r[3])-8,8):
			var x=r[0]-game.hero.radius-2 if side<0 else r[0]+r[2]+game.hero.radius+2
			var p=Vector2(x,y)
			if game.terrain.blocked(p,game.hero.radius): continue
			query.transform=Transform2D(0,p)
			if not game.get_world_2d().direct_space_state.intersect_shape(query,1).is_empty(): continue
			game.hero.position=p; rock.rendered_prop.modulate.a=1; rock._process(1)
			if rock.rendered_prop.modulate.a<.99: found=p; break
		if found.is_finite(): break
	expect(found.is_finite(),"a legal ground position really has its upper body covered by the rock atlas")
	if found.is_finite():
		query.transform=Transform2D(0,found)
		expect(game.get_world_2d().direct_space_state.intersect_shape(query,1).is_empty(),"selected feet are clear in the real physics server")
		expect(not game.terrain.blocked(found,game.hero.radius),"selected feet are clear in native navigation geometry")
		game.hero.position=found; rock.rendered_prop.modulate.a=1
		rock._process(.1)
		expect(rock.rendered_prop.modulate.a>.26 and rock.rendered_prop.modulate.a<1,"occlusion fades smoothly")
		rock._process(1)
		expect(is_equal_approx(rock.rendered_prop.modulate.a,.26),"only the covering rock reaches 26 percent opacity")
		var frozen=rock.rendered_prop.modulate.a
		game.mode="paused"; game.hero.position=Vector2(200,900); rock._process(1)
		expect(is_equal_approx(rock.rendered_prop.modulate.a,frozen),"pause freezes occlusion transition")
		game.mode="playing"; rock._process(1)
		expect(is_equal_approx(rock.rendered_prop.modulate.a,1),"moving away restores full opacity")
		game.hero.position=Vector2(r[0]+r[2]*.5,r[1]+r[3]+game.hero.radius+5); rock._process(1)
		expect(is_equal_approx(rock.rendered_prop.modulate.a,1),"standing in front leaves the rock opaque")
		print("SCENERY_OCCLUSION_LEGAL_POINT ",found," rock_rect=",r)
	game.queue_free(); await process_frame
	print("SCENERY_OCCLUSION_VERIFY ",checks," checks; ",failures.size()," failures")
	quit(0 if failures.is_empty() else 1)
