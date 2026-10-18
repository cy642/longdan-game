extends CharacterBody2D
## Damage and movement use native collision; route control belongs to the director.
var world
var hp=160.0
var max_hp=160.0
var radius=28.0
var uid=0
var last_hit=-1

func _ready() -> void:
	uid=get_instance_id(); collision_layer=8; collision_mask=1
	var shape=CollisionShape2D.new(); var circle=CircleShape2D.new(); circle.radius=radius
	shape.shape=circle; add_child(shape)

func body_alive() -> bool:
	return hp>0 and not is_queued_for_deletion()

func take_damage(amount: float, attack_id: int=-1) -> bool:
	if hp<=0 or attack_id>=0 and last_hit==attack_id: return false
	last_hit=attack_id; hp=maxf(0,hp-amount*(.7 if world.state.difficulty=="story" else 1.0))
	queue_redraw(); world.fx.floater(position,"粮车 -"+str(int(amount)),Color("efc496"))
	if hp<=0: world.defeat("粮车损毁","重试从最近通过的路障开始，车的耐久补满。")
	return true

func travel(target: Vector2, dt: float) -> float:
	var previous=position; var offset=target-position
	if offset.length()>.1: move_and_collide(offset.normalized()*minf(offset.length(),72*dt))
	return position.distance_to(previous)

func _draw() -> void:
	draw_set_transform(Vector2(0,9),0,Vector2(1,.35)); draw_circle(Vector2.ZERO,41,Color(.04,.13,.14,.24)); draw_set_transform(Vector2.ZERO)
	for x in [-32,32]:
		draw_circle(Vector2(x,0),12,Color("4c4a3d")); draw_arc(Vector2(x,0),8,0,TAU,16,Color("aa8c55"),3,true)
	draw_rect(Rect2(-34,-25,68,38),Color("886c43")); draw_rect(Rect2(-34,-25,68,38),Color("b49862"),false,3)
	for row in range(2):
		for i in range(3):
			var p=Vector2(-23+i*22,-28-row*15)
			draw_circle(p,12,Color("c0b078")); draw_arc(p,10,0,PI,12,Color("837149"),2,true)
	for x in [-25,25]: draw_line(Vector2(x,4),Vector2(x,34),Color("8d7149"),4,true)
	if hp<max_hp:
		draw_rect(Rect2(-35,-69,70,5),Color("293c35")); draw_rect(Rect2(-35,-69,70*hp/max_hp,5),Color("d3bd80"))
