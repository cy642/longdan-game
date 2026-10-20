extends SceneTree
## Check production transforms across input states, independent of painted hair colors.
const Hero = preload("res://scripts/hero.gd")
class Fixture extends Node2D:
	var state = {"flags":{"adou":false}}
var checks = 0
var failures: Array = []

func _initialize() -> void: call_deferred("run")

func expect(condition: bool, message: String) -> void:
	checks += 1
	if not condition: failures.append(message); push_error("FAIL: " + message)

func run() -> void:
	var fixture = Fixture.new()
	root.add_child(fixture)
	var hero = Hero.new()
	hero.world = fixture
	fixture.add_child(hero)
	var visual = hero.visual
	var first_density = 0.0
	for direction in range(8):
		hero.facing = direction * PI / 4
		for state in ["idle", "step_a", "step_b", "windup", "strike", "recovery", "dash", "heal"]:
			hero.hp = 200; hero.action = {}; hero.dash_left = 0
			hero.moving = state in ["step_a", "step_b", "dash"]
			hero.walk_distance = hero.HERO_STEP_DISTANCE + 1 if state == "step_b" else 0
			if state in ["windup", "strike", "recovery", "heal"]:
				hero.action = {"key":"heal" if state == "heal" else "thrust1", "dir":hero.facing, "t":.06 if state == "windup" else .46 if state == "recovery" else .20, "def":{"windup":.13,"active":.15,"recovery":.2}}
			if state == "dash": hero.dash_left = .15
			hero.update_visual()
			var scale_xy = visual.body.scale.abs()
			if first_density == 0: first_density = scale_xy.x
			var description = state + " direction " + str(direction)
			expect(scale_xy.is_equal_approx(Vector2.ONE * first_density), description + " keeps identical x/y source density")
			expect(visual.scale.is_equal_approx(Vector2.ONE) and visual.position.is_zero_approx(), description + " adds no hidden size/height change")
			var meta = visual.atlas_data[visual.last_frame[0]].frames[visual.last_frame[1]]
			var boot = visual.body.transform * Vector2(meta.anchor[0], meta.anchor[1])
			expect(boot.length() < .001, description + " remains anchored at its own boot pivot, including mirrored poses")
	# Legacy injury art was drawn larger. Match anatomical source landmarks,
	# measured on the unmodified sheets, without stretching the whole death pose.
	hero.hp = 0; hero.action = {}; hero.update_visual()
	expect(visual.last_frame[0] == "hero" and visual.last_frame[1] == 7, "death still uses the authored reaction pose")
	var standing_head_core = 133.0 * first_density
	var fallen_head_core = 156.0 * visual.current_scale
	expect(absf(fallen_head_core - standing_head_core) / standing_head_core < .04, "legacy reaction head matches live head within four percent")
	expect(visual.current_scale < first_density, "larger legacy art does not enlarge Zhao Yun on death")
	# Hair-colored patch size is deliberately not a size input. This catches the
	# old bug even if source art gains highlights or changes hair direction.
	var saved_hair = visual.atlas_data.walk.frames[0].head_height
	visual.atlas_data.walk.frames[0].head_height = saved_hair * 2
	visual.last_frame = []
	visual.set_frame("walk", 0, false, true)
	expect(is_equal_approx(visual.current_scale, first_density), "hair recoloring cannot halve the whole character")
	visual.atlas_data.walk.frames[0].head_height = saved_hair
	fixture.queue_free()
	await process_frame
	print("HERO_SCALE_VERIFY ", checks, " checks; ", failures.size(), " failures")
	quit(0 if failures.is_empty() else 1)
