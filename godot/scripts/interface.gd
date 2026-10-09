extends CanvasLayer
const MapView=preload("res://scripts/map_view.gd")
var world
var root: Control
var hud: Control
var overlay: Control
var font: Font
var hp_bar: ProgressBar
var qi_bar: ProgressBar
var rage_bar: ProgressBar
var hp_text: Label
var region_text: Label
var mission_title: Label
var mission_text: Label
var save_text: Label
var command_text: Label
var action_text: Label
var interact_text: Label
var toast_text: Label
var toast_left=0.0
var mini_map
var map_clock=0.0
var boss_panel: Control
var boss_title: Label
var boss_bar: ProgressBar
var boss_poise: ProgressBar
var rescue_bar: ProgressBar
var rescue_text: Label
var skills: Dictionary={}
var first_choice: Button
var marker: Control
var marker_label: Label
var run_started=false
var theme_resource: Theme

func _ready() -> void:
	layer=20; font=load("res://assets/fonts/NotoSansSC-Regular.otf")
	root=Control.new(); root.name="Root"; root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); root.mouse_filter=Control.MOUSE_FILTER_IGNORE; add_child(root)
	theme_resource=Theme.new(); theme_resource.default_font=font; theme_resource.default_font_size=16
	theme_resource.set_color("font_color","Label",Color("e3e6d1"))
	for state_name in ["normal","hover","pressed","focus"]:
		var style=box("1d3938" if state_name=="normal" else "345651" if state_name=="hover" else "45665c","d6bc7d" if state_name=="focus" else "60766a")
		style.content_margin_left=18; style.content_margin_right=18; style.content_margin_top=12; style.content_margin_bottom=12
		theme_resource.set_stylebox(state_name,"Button",style)
	theme_resource.set_color("font_color","Button",Color("e9e4cd")); theme_resource.set_color("font_hover_color","Button",Color("fff0bb"))
	root.theme=theme_resource
	build_hud()

func box(fill: String="122a2d",border: String="526960") -> StyleBoxFlat:
	var style=StyleBoxFlat.new(); style.bg_color=Color(fill); style.bg_color.a=.94
	style.border_color=Color(border); style.set_border_width_all(1); style.set_corner_radius_all(5)
	style.content_margin_left=16; style.content_margin_right=16; style.content_margin_top=12; style.content_margin_bottom=12
	return style

func label(text: String,parent: Node,font_size: int=16,color: String="e3e6d1") -> Label:
	var node=Label.new(); node.text=text; node.add_theme_font_size_override("font_size",font_size); node.add_theme_color_override("font_color",Color(color)); parent.add_child(node)
	return node

func panel(parent: Node) -> PanelContainer:
	var node=PanelContainer.new(); node.add_theme_stylebox_override("panel",box()); parent.add_child(node); return node

func column(parent: Node,separation: int=10) -> VBoxContainer:
	var node=VBoxContainer.new(); node.add_theme_constant_override("separation",separation); parent.add_child(node); return node

func button(text: String,parent: Node,callback: Callable) -> Button:
	var node=Button.new(); node.text=text; node.custom_minimum_size=Vector2(0,46); parent.add_child(node); node.pressed.connect(callback); return node

func bar(parent: Node,color: String,height: int=9) -> ProgressBar:
	var node=ProgressBar.new(); node.show_percentage=false; node.max_value=100; node.custom_minimum_size=Vector2(0,height)
	var background=StyleBoxFlat.new(); background.bg_color=Color("091b1e"); background.set_corner_radius_all(3)
	var fill=StyleBoxFlat.new(); fill.bg_color=Color(color); fill.set_corner_radius_all(3)
	node.add_theme_stylebox_override("background",background); node.add_theme_stylebox_override("fill",fill); parent.add_child(node); return node

func dock(node: Control,preset: int,offsets: Rect2) -> void:
	node.set_anchors_and_offsets_preset(preset)
	node.offset_left=offsets.position.x; node.offset_top=offsets.position.y; node.offset_right=offsets.end.x; node.offset_bottom=offsets.end.y

func build_hud() -> void:
	hud=Control.new(); hud.name="BattleHUD"; hud.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); hud.mouse_filter=Control.MOUSE_FILTER_IGNORE; root.add_child(hud)
	var stats=panel(hud); stats.name="HeroStatus"; dock(stats,Control.PRESET_TOP_LEFT,Rect2(22,20,290,150))
	var v=column(stats,5); var row=HBoxContainer.new(); v.add_child(row)
	label("赵子龙",row,21,"eae1bc"); var spacer=Control.new(); spacer.size_flags_horizontal=Control.SIZE_EXPAND_FILL; row.add_child(spacer)
	hp_text=label("200 / 200",row,14,"b8c7b7"); hp_bar=bar(v,"bdd2af",11)
	label("气力",v,12,"a1c9cc"); qi_bar=bar(v,"74b7c3",6)
	label("战意 · 青釭",v,12,"d5bc7c"); rage_bar=bar(v,"d0b678",5)
	var objective=panel(hud); objective.name="Mission"; dock(objective,Control.PRESET_TOP_RIGHT,Rect2(-370,20,348,128))
	v=column(objective,7); region_text=label("一 · 记忆醒来",v,12,"a3b8a5"); mission_title=label("枪起长坂",v,21,"ead29b")
	mission_text=label("",v,14,"cbd0ba"); mission_text.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART; mission_text.custom_minimum_size.x=306
	var map_panel=panel(hud); dock(map_panel,Control.PRESET_BOTTOM_RIGHT,Rect2(-232,-227,210,203))
	v=column(map_panel,3); mini_map=MapView.new(); mini_map.world=world; mini_map.custom_minimum_size=Vector2(175,121); v.add_child(mini_map)
	label("M 军图    Esc 暂停",v,12,"a8bba7"); save_text=label("进度已保存",v,11,"93af9f")
	var bottom=panel(hud); dock(bottom,Control.PRESET_CENTER_BOTTOM,Rect2(-348,-99,696,78))
	row=HBoxContainer.new(); row.add_theme_constant_override("separation",9); bottom.add_child(row)
	for entry in [["attack","J / 左键","龙枪三式"],["dash","空格 / K","闪避"],["sweep","Q / 右键","横扫破阵"],["sword","R","青釭断势"],["heal","F","行军药"],["interact","E","交互"]]:
		var key=entry[0]; var skill=Button.new(); skill.text=entry[1]+"\n"+entry[2]; skill.focus_mode=Control.FOCUS_NONE
		skill.custom_minimum_size=Vector2(97,50); skill.add_theme_font_size_override("font_size",13)
		var style=box("203b3a","466258"); style.content_margin_left=5; style.content_margin_right=5; style.content_margin_top=5; style.content_margin_bottom=5
		skill.add_theme_stylebox_override("normal",style); row.add_child(skill); skills[key]=skill
		skill.pressed.connect(func():
			if world.mode!="playing": return
			if key=="interact": world.interact()
			else: world.hero.request(key,world.movement_input()))
	command_text=label("",hud,13,"c9d0b4"); dock(command_text,Control.PRESET_BOTTOM_LEFT,Rect2(25,-76,290,28))
	action_text=label("",hud,13,"b4e1d6"); action_text.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER; dock(action_text,Control.PRESET_CENTER_BOTTOM,Rect2(-320,-129,640,25))
	interact_text=label("",hud,17,"f3d99d"); interact_text.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER; dock(interact_text,Control.PRESET_CENTER_BOTTOM,Rect2(-380,-166,760,28))
	toast_text=label("",hud,15,"efe3bc"); toast_text.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	toast_text.add_theme_color_override("font_shadow_color",Color("132b2b")); toast_text.add_theme_constant_override("shadow_outline_size",5)
	dock(toast_text,Control.PRESET_CENTER_TOP,Rect2(-435,175,870,40)); toast_text.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	boss_panel=panel(hud); dock(boss_panel,Control.PRESET_CENTER_TOP,Rect2(-220,22,440,75)); v=column(boss_panel,5)
	boss_title=label("",v,18,"ead2b2"); boss_title.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER; boss_bar=bar(v,"d6977e",8); boss_poise=bar(v,"d0ba77",3)
	rescue_text=label("",hud,14,"c3dfbc"); rescue_text.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	dock(rescue_text,Control.PRESET_CENTER_TOP,Rect2(-270,113,540,26))
	rescue_bar=bar(hud,"a9cdad",6); dock(rescue_bar,Control.PRESET_CENTER_TOP,Rect2(-160,146,320,6))
	marker=Control.new(); marker.mouse_filter=Control.MOUSE_FILTER_IGNORE; hud.add_child(marker)
	marker_label=label("◆",marker,19,"f5d184"); marker_label.mouse_filter=Control.MOUSE_FILTER_IGNORE

func hide_overlay() -> void:
	if is_instance_valid(overlay):
		root.remove_child(overlay); overlay.queue_free(); overlay=null
	first_choice=null; hud.visible=true

func overlay_base() -> VBoxContainer:
	hide_overlay(); overlay=Control.new(); overlay.name="Overlay"; overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); root.add_child(overlay)
	var shade=ColorRect.new(); shade.color=Color(.035,.09,.105,.88); shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); overlay.add_child(shade)
	var center=CenterContainer.new(); center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); overlay.add_child(center)
	var container=panel(center); container.custom_minimum_size=Vector2(680,0)
	var scroll=ScrollContainer.new(); scroll.custom_minimum_size=Vector2(640,540); scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED
	container.add_child(scroll)
	var v=column(scroll,12); v.size_flags_horizontal=Control.SIZE_EXPAND_FILL; v.custom_minimum_size.x=640
	v.size_flags_vertical=Control.SIZE_SHRINK_BEGIN
	v.minimum_size_changed.connect(func(): resize_overlay.call_deferred(scroll,v))
	resize_overlay.call_deferred(scroll,v)
	return v

func resize_overlay(scroll: ScrollContainer,content: VBoxContainer) -> void:
	if not is_instance_valid(scroll) or not is_instance_valid(content): return
	scroll.custom_minimum_size.y=clampf(content.get_combined_minimum_size().y,140,maxf(180,root.size.y-140))

func show_menu() -> void:
	var v=overlay_base(); hud.visible=false
	var parent=v.get_parent().get_parent()
	parent.custom_minimum_size=Vector2(1050,570)
	var portrait=TextureRect.new(); portrait.texture=load("res://assets/zhaoyun-reference.png"); portrait.expand_mode=TextureRect.EXPAND_IGNORE_SIZE; portrait.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	portrait.mouse_filter=Control.MOUSE_FILTER_IGNORE
	dock(portrait,Control.PRESET_CENTER_RIGHT,Rect2(-480,-246,355,492)); overlay.add_child(portrait)
	v.custom_minimum_size.x=640
	label("LONGDAN  /  CHAPTER ONE",v,13,"94bcb4")
	label("龙胆：逆命三国",v,42,"f0e1bc")
	label("重生之我在三国当赵子龙",v,18,"b4c8b4")
	label("第一章 · 长坂逆命",v,23,"dbbf83")
	var intro=label("重走长坂，夺剑救主。\n\n枪在你手中，记忆里的诀别也能改写。",v,17,"bdccbb"); intro.custom_minimum_size.y=94
	var difficulty=OptionButton.new(); difficulty.add_item("征战 · 看破枪势，亲自开路"); difficulty.add_item("叙事 · 更宽容的伤害与闪避"); difficulty.custom_minimum_size=Vector2(490,40); v.add_child(difficulty)
	var saved=world.state.read_save()
	if not saved.is_empty():
		var continue_button=button("查看长坂战报" if saved.complete else "继续逆命",v,func(): world.continue_game())
		continue_button.custom_minimum_size.x=490; first_choice=continue_button
	var begin=button("开始新征程",v,func(): confirm_start("story" if difficulty.selected==1 else "normal"))
	begin.custom_minimum_size.x=490
	if not first_choice: first_choice=begin
	label("WASD 移动  ·  J / 左键出枪  ·  空格闪避  ·  Q 破阵",v,13,"a5b8a8")
	label("F11 全屏    |    电脑版试玩 · 第一章完整流程",v,12,"7e9d96")
	# Leave the portrait its own space inside the large panel.
	v.custom_minimum_size.x=580; v.size_flags_horizontal=Control.SIZE_SHRINK_BEGIN
	parent.add_theme_stylebox_override("panel",box("122c30","526c62"))
	first_choice.grab_focus()

func confirm_start(difficulty: String) -> void:
	if not run_started and world.state.read_save().is_empty():
		run_started=true; world.start_game(difficulty); return
	var previous=world.mode
	var v=overlay_base()
	label("开始新的征程？",v,27,"efdeb3")
	paragraph("新征程将替换当前进度与战报。",v)
	first_choice=button("取消，保留当前进度",v,func():
		if previous=="menu": show_menu()
		elif previous=="ending": show_report(world.state.build_report())
		else: world.mode="pause"; show_pause("pause"))
	button("开始新征程",v,func(): run_started=true; world.start_game(difficulty))
	first_choice.grab_focus()

func paragraph(text: String,parent: Node) -> Label:
	var node=label(text,parent,17,"cdd4bf"); node.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART; node.custom_minimum_size.x=620
	node.add_theme_constant_override("line_spacing",7); return node

func show_dialog(title: String,text: String,choices: Array,speaker: String) -> void:
	var v=overlay_base(); label(speaker,v,13,"a2c2b6"); label(title,v,28,"ebd5a3"); paragraph(text,v)
	for choice in choices:
		var route=choice.route
		var choice_button=button(choice.text+"\n"+choice.detail,v,func(): world.choose_route(route))
		choice_button.add_theme_font_size_override("font_size",16)
		if first_choice==null: first_choice=choice_button
	label("Tab 切换选项 · Enter 确认",v,12,"8faa9a")
	focus_choice()

func focus_choice() -> void:
	if is_instance_valid(first_choice): first_choice.grab_focus()

func show_pause(kind: String) -> void:
	var v=overlay_base(); label("军图 · "+world.definition.name if kind=="map" else "长枪暂歇",v,28,"ecd6aa")
	if kind=="map":
		var map=MapView.new(); map.world=world; map.large=true; map.custom_minimum_size=Vector2(630,365); v.add_child(map)
		label("金圈是当前目标 · 红点是敌军 · 青点是赵云",v,13,"b0c5b2")
	else:
		paragraph("WASD / 方向键移动，J / 左键接龙枪三式。\n空格 / K 闪避，精准闪避后可接回马枪。\nQ / 右键横扫破盾，R 青釭断势，F 服药。\nE 救援、休整、前进；1 / 2 / 3 发布军令。",v)
		var effects=CheckButton.new(); effects.text="柔和特效 · 减少震屏和顿帧"; effects.button_pressed=world.fx.soft; effects.toggled.connect(func(value): world.fx.soft=value); v.add_child(effects)
		var footsteps=CheckButton.new(); footsteps.text="脚步声 · 轻声落脚"; footsteps.button_pressed=world.sound.footsteps_enabled; footsteps.toggled.connect(func(value): world.sound.footsteps_enabled=value); v.add_child(footsteps)
		var mute=CheckButton.new(); mute.text="静音"; mute.button_pressed=world.sound.muted; mute.toggled.connect(func(value): world.sound.muted=value); v.add_child(mute)
	first_choice=button("继续前行",v,func(): world.resume())
	if kind!="map":
		var row=HBoxContainer.new(); v.add_child(row)
		button("全屏 / 窗口",row,func(): world.toggle_fullscreen())
		button("回到标题",row,func(): world.title_screen())
		button("重开征程",row,func(): confirm_start(world.state.difficulty))
	focus_choice()

func show_defeat(title: String,text: String) -> void:
	var v=overlay_base(); label(title,v,30,"e8b69a"); paragraph(text,v)
	label("已完成的救援、夺剑和遭遇仍会保留。",v,14,"abbfa9")
	first_choice=button("重新握枪",v,func(): world.retry()); button("回到标题",v,func(): world.title_screen()); focus_choice()

func show_report(report: Dictionary) -> void:
	var v=overlay_base(); label("第一章 · 长坂战报",v,13,"adc1ae"); label(report.title,v,28,"efd7a6"); paragraph(report.text,v)
	label("改写命运  "+str(report.changes)+" / 3     击退  "+str(report.kills)+"     精准闪避  "+str(report.precision),v,17,"b4d1bc")
	var row=HBoxContainer.new(); v.add_child(row)
	for entry in [[world.state.flags.civilians,"百姓获救"],[world.state.flags.mother,"糜夫人存活"],[world.state.flags.supplies,"粮道截断"]]:
		label(("✓ " if entry[0] else "○ ")+entry[1]+"   ",row,15,"d8c48d" if entry[0] else "819b91")
	if not report.hints.is_empty(): paragraph("另一种命运：\n"+"\n".join(report.hints),v)
	first_choice=button("回到标题 · 战报已保存",v,func(): world.title_screen())
	button("再走一次长坂",v,func(): confirm_start(world.state.difficulty)); focus_choice()

func toast(text: String) -> void:
	toast_text.text=text; toast_left=4.5

func stage_changed() -> void:
	toast_left=0; mini_map.queue_redraw()

func refresh(dt: float) -> void:
	if not world.hero: return
	var hero=world.hero; var playing=world.mode in ["playing","pause","map","dialog","defeat"]
	hud.visible=playing
	hp_text.text=str(int(ceil(hero.hp)))+" / "+str(int(hero.max_hp)); hp_bar.value=hero.hp/hero.max_hp*100
	qi_bar.value=hero.qi; rage_bar.value=hero.rage
	var mission=world.mission(); region_text.text=world.definition.chapter+" · "+world.definition.name
	mission_title.text=mission.title; mission_text.text=mission.text
	save_text.text="进度已保存" if world.state.durable else "仅本次有效 · 保存失败"
	command_text.text="随军："+{"follow":"集合","hold":"守点","charge":"冲阵"}[world.command]+"   1 / 2 / 3" if world.squad_active() else "随军待命 · 救援和桥头时掩护"
	skills.heal.text="F\n行军药 × "+str(hero.potions)
	skills.sweep.text="Q / 右键\n"+("横扫 "+("%.1f"%hero.sweep_cd)+"s" if hero.sweep_cd>.1 else "横扫破阵")
	skills.sword.text="R\n"+("战意 "+str(int(hero.rage))+"%" if world.state.flags.sword else "夺剑后解锁")
	var object=world.nearest_object(); interact_text.text="E  ·  "+world.interaction_text(object) if not object.is_empty() else ""
	action_text.text=""
	if not hero.action.is_empty() and hero.action.key=="heal": action_text.text="服药中 · 还需 "+("%.1f"%maxf(0,hero.action.def.windup-hero.action.t))+" 秒"
	elif hero.counter_left>0: action_text.text="精准闪避 · 出枪可接回马枪"
	elif not hero.action.is_empty(): action_text.text=hero.action.def.name+" · "+("蓄势" if hero.action.t<hero.action.def.windup else "出枪" if hero.action.t<hero.action.def.windup+hero.action.def.active else "收招 · 可闪避")
	toast_left=maxf(0,toast_left-dt); toast_text.visible=toast_left>0 and world.mode=="playing"; toast_text.modulate.a=minf(1,toast_left/.4)
	boss_panel.visible=world.active_boss!=""
	if boss_panel.visible and world.boss:
		var boss=world.boss; boss_title.text=boss.display_name+" · "+("枪势再起" if boss.phase2 else "青釭守将" if boss.boss_id=="xiahou" else "北桥断后")
		boss_bar.value=boss.hp/boss.max_hp*100; boss_poise.value=boss.stagger/boss.stagger_max*100
	rescue_bar.visible=not world.rescue.is_empty(); rescue_text.visible=rescue_bar.visible
	if rescue_bar.visible:
		rescue_bar.value=world.rescue.progress/20*100
		rescue_text.text="施救 "+str(int(world.rescue.progress/20*100))+"% · "+("还需击退追兵" if world.rescue.progress>=20 else "保护医者")
	var transformed=world.get_viewport().get_canvas_transform()*mission.pos
	var view=root.get_rect().size
	marker.visible=world.mode=="playing" and hero.position.distance_to(mission.pos)>105
	marker.position=Vector2(clampf(transformed.x,30,view.x-30),clampf(transformed.y,190,view.y-180))
	map_clock-=dt
	if map_clock<=0: mini_map.queue_redraw(); map_clock=.12
