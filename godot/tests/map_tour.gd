extends Node
## Developer tour: production movement/collision, no combat gates or player saves.
const Game = preload("res://scripts/world.gd")
const Campaign = preload("res://scripts/campaign.gd")
class MemoryCampaign extends Campaign:
	func read_save() -> Dictionary: return {}
	func save() -> bool: return true
var world
var regions = ["mountain", "village", "temple", "house", "fork", "bridge"]
var heading: Label
var shown_stage = ""

func _ready() -> void:
	world = Game.new()
	world.test_mode = true
	world.state = MemoryCampaign.new()
	add_child(world)
	var layer = CanvasLayer.new()
	layer.layer = 40
	add_child(layer)
	var panel = PanelContainer.new()
	panel.position = Vector2(335,16)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style = StyleBoxFlat.new()
	style.bg_color = Color("193c38")
	style.content_margin_left = 12
	style.content_margin_right = 12
	style.content_margin_top = 8
	style.content_margin_bottom = 8
	panel.add_theme_stylebox_override("panel",style)
	layer.add_child(panel)
	heading = Label.new()
	heading.add_theme_font_override("font",world.ui.font)
	heading.add_theme_font_size_override("font_size",14)
	panel.add_child(heading)
	select_region(0)

func select_region(index: int) -> void:
	world.state.reset()
	for key in world.state.flags: world.state.flags[key] = true
	for id in regions:
		for group in world.definitions[id].groups:
			world.state.cleared.append(id+":"+str(group.id))
	world.mode = "playing"
	world.pending_stage = {}
	world.hero.reset_combat()
	world.enter_stage(regions[index],Vector2.INF,false)
	world.ui.hide_overlay()
	refresh_heading()

func refresh_heading() -> void:
	shown_stage = world.stage
	heading.text = "地图巡游 · " + world.definition.name + "\nF1–F6 切换区域 · M 军图 · 不保存进度"

func _process(_delta: float) -> void:
	if world and heading and shown_stage != world.stage: refresh_heading()

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.physical_keycode>=KEY_F1 and event.physical_keycode<=KEY_F6:
			select_region(event.physical_keycode-KEY_F1)
			get_viewport().set_input_as_handled()
