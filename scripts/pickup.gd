class_name Pickup
extends Node2D
## Un objet posé dans une salle : ferraille, bandage, marteau, lettre...
## Wendel le ramasse en passant dessus. Une fois pris, il ne revient pas.

var item := {}
var flag := ""
var _t := 0.0


func _process(delta: float) -> void:
	_t += delta
	var p := Game.inst.player
	if is_instance_valid(p) and not p.is_dead() and p.get_hurt_rect().grow(6.0).has_point(position):
		_take()
	queue_redraw()


func _take() -> void:
	World.flags[flag] = true
	match item.type:
		"ferraille":
			World.scrap += int(item.amount)
			Sfx.play("enclume_doux", -4.0, 1.3)
			Game.inst.fx.text(position + Vector2(0, -30), "+%d ferraille" % item.amount, Color(0.85, 0.8, 0.7), 16)
		"pv":
			World.max_hp += 1
			Game.inst.player.max_hp = World.max_hp
			Game.inst.player.hp = World.max_hp
			Sfx.play("panse")
			Game.inst.show_text(item.title, item.text)
		"capacite":
			World.grant(item.id)
			Sfx.play("glas", -4.0)
			Game.inst.show_text(item.title, item.text)
		"quete", "note":
			World.flags["quete:" + item.id] = true
			Sfx.play("panse", -4.0, 0.8)
			Game.inst.show_text(item.title, item.text)
		"lettre":
			if not item.id in World.letters:
				World.letters.append(item.id)
			Sfx.play("panse", -4.0, 0.8)
			Game.inst.show_text(item.title, item.text)
	World.save_game()
	queue_free()


func _draw() -> void:
	var bob := sin(_t * 3.0) * 3.0
	match item.get("type", ""):
		"ferraille":
			for i in 3:
				draw_rect(Rect2(Vector2(-10 + i * 6, 4 - i * 3 + bob), Vector2(8, 5)), Color(0.6, 0.58, 0.55))
		"quete":
			draw_rect(Rect2(-12, -8 + bob, 24, 18), Color(0.85, 0.82, 0.74))
			draw_rect(Rect2(-12, -8 + bob, 24, 4), Color(0.55, 0.45, 0.32))
		"note":
			draw_rect(Rect2(-10, -8 + bob, 20, 16), Color(0.42, 0.32, 0.24))
			draw_line(Vector2(-6, -2 + bob), Vector2(6, -2 + bob), Color(0.8, 0.75, 0.65), 2.0)
		"lettre":
			draw_rect(Rect2(-9, -6 + bob, 18, 12), Color(0.92, 0.88, 0.78))
			draw_line(Vector2(-9, -6 + bob), Vector2(0, 1 + bob), Color(0.35, 0.5, 0.85), 2.0)
			draw_line(Vector2(9, -6 + bob), Vector2(0, 1 + bob), Color(0.35, 0.5, 0.85), 2.0)
		"capacite":
			draw_circle(Vector2(0, bob), 20.0, Color(1.0, 0.9, 0.7, 0.15 + 0.1 * sin(_t * 4.0)))
			draw_line(Vector2(-12, 10 + bob), Vector2(8, -8 + bob), Color(0.45, 0.35, 0.25), 4.0)
			draw_rect(Rect2(2, -16 + bob, 16, 10), Color(0.6, 0.58, 0.55))
		_:
			draw_circle(Vector2(0, bob), 9.0, Color(0.92, 0.9, 0.84))
			draw_line(Vector2(-6, bob), Vector2(6, bob), Color(0.7, 0.2, 0.2), 3.0)
