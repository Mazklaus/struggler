class_name FragileWall
extends StaticBody2D
## Mur fissuré : seule une attaque lourde chargée ou une Frappe à blanc le brise.

var rect: Rect2
var flag := ""   # clé de sauvegarde : un mur brisé le reste


func _ready() -> void:
	add_to_group("fragile")
	var shape := CollisionShape2D.new()
	var box := RectangleShape2D.new()
	box.size = rect.size
	shape.shape = box
	shape.position = rect.get_center()
	add_child(shape)


func get_rect() -> Rect2:
	return rect


func try_break(info: Dictionary) -> bool:
	if not (info.get("blanc", false) or info.get("charge", 0.0) >= 0.99):
		var msg := "Il faut une attaque lourde chargée" if World.has("lourde") else "Il faudrait un vrai marteau"
		Game.inst.fx.text(rect.get_center(), msg, Color(0.9, 0.85, 0.7), 14)
		return false
	Sfx.play("mur")
	Game.inst.shake(10.0)
	for i in 6:
		Game.inst.fx.sparks(rect.position + Vector2(rect.size.x * 0.5, randf() * rect.size.y), 6, Color(0.6, 0.58, 0.54), 380.0, 1400.0, 0.9)
	if flag != "":
		World.flags[flag] = true
	queue_free()
	return true


func _draw() -> void:
	draw_rect(rect, Color(0.42, 0.39, 0.35))
	var c := Color(0.2, 0.18, 0.16)
	var x := rect.position.x
	while x < rect.end.x:
		var y := rect.position.y
		while y < rect.end.y:
			draw_line(Vector2(x + 6, y + 4), Vector2(x + 18, y + 16), c, 2.0)
			draw_line(Vector2(x + 18, y + 16), Vector2(x + 12, y + 30), c, 2.0)
			y += 32.0
		x += 32.0
