class_name Enemy
extends CharacterBody2D
## Base commune des ennemis des salles : vie, brûlure de la Chaleur, plaies de l'Entaille,
## ferraille laissée à la mort. Les ennemis morts ne reviennent qu'en rechargeant la salle.

@export var max_hp := 6
@export var scrap_drop := 3
@export var contact_damage := 1

var hp := 6
var facing := -1
var dead := false
var body_size := Vector2(30, 30)

var _flash := 0.0
var _burn := 0.0
var _burn_tick := 0.0
var _wounds := 0
var _wound_timer := 0.0
var _bleed := 0.0
var _bleed_tick := 0.0


func _ready() -> void:
	hp = max_hp
	add_to_group("hittable")
	z_index = 4


func _tick_status(delta: float) -> void:
	_flash = maxf(_flash - delta, 0.0)
	if _burn > 0.0:
		_burn -= delta
		_burn_tick -= delta
		if _burn_tick <= 0.0:
			_burn_tick = 0.5
			_damage(1, false)
			Game.inst.fx.sparks(position + Vector2(randf_range(-10, 10), -10), 3, Color(1.0, 0.55, 0.15), 120.0, -200.0, 0.5)
	if _wounds > 0:
		_wound_timer -= delta
		if _wound_timer <= 0.0:
			_wounds = 0
	if _bleed > 0.0:
		_bleed -= delta
		_bleed_tick -= delta
		if _bleed_tick <= 0.0:
			_bleed_tick = 0.4
			_damage(1, false)
			Game.inst.fx.sparks(position, 4, Color(0.6, 0.05, 0.05), 160.0, 1200.0, 0.5)


## Applique les effets communs d'un coup de Wendel. Renvoie false si l'ennemi est déjà mort.
func _apply_hit(info: Dictionary) -> bool:
	if dead:
		return false
	if info.get("burn", false):
		_burn = 2.0
		_burn_tick = 0.5
	if info.get("entaille", false):
		_wounds += 1
		_wound_timer = 3.0
		if _wounds >= 5:
			_wounds = 0
			_bleed = 3.0
			_bleed_tick = 0.2
			Game.inst.fx.text(position + Vector2(0, -50), "Saignée !", Color(0.9, 0.2, 0.2), 18)
	_damage(info.damage, true)
	return true


func _damage(amount: int, popup: bool) -> void:
	if dead:
		return
	hp -= amount
	_flash = 0.08
	if popup:
		Game.inst.fx.text(position + Vector2(randf_range(-10, 10), -body_size.y * 0.5 - 14), str(amount), Color(1, 1, 1), 16)
	if hp <= 0:
		_die()


func _die() -> void:
	dead = true
	hp = 0
	_burn = 0.0
	_bleed = 0.0
	collision_layer = 0
	remove_from_group("hittable")
	Sfx.play("coup_lourd", 0.0, 0.8)
	_on_death()
	if scrap_drop > 0:
		World.scrap += scrap_drop
		Game.inst.fx.text(position + Vector2(0, -40), "+%d ferraille" % scrap_drop, Color(0.85, 0.8, 0.7), 14)


## À surcharger : effets visuels de la mort.
func _on_death() -> void:
	Game.inst.fx.sparks(position, 24, Color(0.6, 0.05, 0.05), 340.0, 1200.0, 0.8)
	queue_free()


## Contact : toucher l'ennemi blesse Wendel.
func _touch_player() -> void:
	var p := Game.inst.player
	if dead or not is_instance_valid(p) or p.is_dead():
		return
	if get_hurt_rect().intersects(p.get_hurt_rect()):
		p.receive_attack(self, contact_damage)


func get_hurt_rect() -> Rect2:
	return Rect2(position - body_size * 0.5, body_size)


func _body_color(base: Color) -> Color:
	if _flash > 0.0:
		return Color(1, 1, 1)
	if _burn > 0.0:
		return base.lerp(Color(1.0, 0.5, 0.15), 0.35)
	return base


func _draw_wounds(top: float) -> void:
	for i in _wounds:
		draw_line(Vector2(-12 + i * 6, top - 8), Vector2(-9 + i * 6, top - 14), Color(0.85, 0.15, 0.15), 2.0)
