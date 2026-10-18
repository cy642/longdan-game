extends "res://scripts/world.gd"
## Manual desktop QA uses an isolated profile and never writes player progress.
func _init() -> void:
	test_mode=true
	state.save_path="user://longdan-manual-qa.json"

func _ready() -> void:
	super._ready()
	get_window().title="龙胆：逆命三国 · 开发试玩"
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--qa-stage="):
			var id=arg.trim_prefix("--qa-stage=")
			state.reset("normal",2); load_chapter(2); hero.reset_combat()
			mode="playing"; enter_stage(id); ui.hide_overlay()
			if id=="hs_camp":
				hero.position=Vector2(650,460); set_command("hold")

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		print("MANUAL_KEY physical=",event.physical_keycode," logical=",event.keycode," mode=",mode)
	super._input(event)
