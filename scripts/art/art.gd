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


func set_enabled(on: bool) -> void:
	enabled = on
	var any := false
	for n in get_tree().get_nodes_in_group("room_art"):
		(n as RoomArt).apply(on)
		any = true
	_paper.visible = on and any


func _on_node_added(node: Node) -> void:
	if node is Room and enabled_at_all():
		_dress.call_deferred(node)


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
