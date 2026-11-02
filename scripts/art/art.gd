extends Node
## La vraie DA, posée par-dessus le jeu gris sans le modifier.
## Chaque salle décrite dans art/zones/<zone>/zone.json reçoit son habillage (RoomArt) dès qu'elle
## apparaît ; les autres restent grises. F2 bascule entre la DA et le gris, pour juger le gameplay.

const ZONES := {"h": "hautfer"}   # préfixe des salles -> dossier de zone

var enabled := true
var _zones := {}
var _paper: CanvasLayer


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	# Sans écran (tests automatiques), rien à voir : on n'habille pas, le jeu reste exactement le gris.
	if DisplayServer.get_name() == "headless":
		enabled = false
		return
	get_tree().node_added.connect(_on_node_added)
	_paper = CanvasLayer.new()
	_paper.layer = 1
	var r := ColorRect.new()
	r.set_anchors_preset(Control.PRESET_FULL_RECT)
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var m := ShaderMaterial.new()
	m.shader = load("res://art/shaders/papier.gdshader")
	r.material = m
	_paper.add_child(r)
	_paper.visible = false
	add_child(_paper)


func _unhandled_input(event: InputEvent) -> void:
	if _paper and event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_F2:
		set_enabled(not enabled)
	elif _paper and event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_F3:
		_toggle_echelle()
	elif _paper and event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_F4:
		_cycle_zoom()


## F4 : essayer plusieurs distances de caméra (1,15 = ancienne ; 1,35 = par défaut ; 1,5 = très proche).
func _cycle_zoom() -> void:
	var cam := get_viewport().get_camera_2d()
	if cam == null:
		return
	var steps := [1.15, 1.35, 1.5]
	var i := 0
	for j in steps.size():
		if absf(cam.zoom.x - steps[j]) < 0.01:
			i = (j + 1) % steps.size()
	cam.zoom = Vector2(steps[i], steps[i])
	print("Zoom caméra : ", steps[i])


## F3 : contrôle d'échelle (grille en mètres, hitbox, silhouette de 1,80 m près de chaque décor).
func _toggle_echelle() -> void:
	var old := get_tree().get_nodes_in_group("echelle_debug")
	if not old.is_empty():
		for n in old:
			n.queue_free()
		return
	for room in get_tree().root.find_children("*", "Room", true, false):
		var d := EchelleDebug.new()
		d.add_to_group("echelle_debug")
		room.add_child(d)
		d.room = room


func set_enabled(on: bool) -> void:
	enabled = on
	var any := false
	for n in get_tree().get_nodes_in_group("room_art"):
		(n as RoomArt).apply(on)
		any = true
	for n in get_tree().get_nodes_in_group("wendel_art"):
		(n as WendelArt).show_art(on)
	_paper.visible = on and any


func _on_node_added(node: Node) -> void:
	if node is Room and enabled_at_all():
		_dress.call_deferred(node)
	elif node is Player and enabled_at_all() and WendelArt.available():
		_dress_player.call_deferred(node)


func _dress_player(p: Player) -> void:
	if not is_instance_valid(p) or p.has_node("WendelArt"):
		return
	var w := WendelArt.new()
	w.add_to_group("wendel_art")
	p.add_child(w)
	w.setup(p)
	w.show_art(enabled)


func enabled_at_all() -> bool:
	return _paper != null


func _dress(room: Room) -> void:
	if not is_instance_valid(room) or room.id == "":
		return
	var zone := _zone_for(room.id)
	var salle: Dictionary = zone.get("salles", {}).get(room.id, {})
	if salle.is_empty():
		_paper.visible = false
		return
	var art := RoomArt.new()
	art.add_to_group("room_art")
	room.add_child(art)
	room.move_child(art, 0)
	art.setup(room, zone._dir, zone, salle)
	if not enabled:
		art.apply(false)
	_paper.visible = enabled


func _zone_for(room_id: String) -> Dictionary:
	var key: String = ZONES.get(room_id.substr(0, 1), "")
	if key == "":
		return {}
	if not _zones.has(key):
		var dir := "res://art/zones/%s/" % key
		var f := FileAccess.open(dir + "zone.json", FileAccess.READ)
		var data: Dictionary = JSON.parse_string(f.get_as_text()) if f else {}
		data["_dir"] = dir
		_zones[key] = data
	return _zones[key]
