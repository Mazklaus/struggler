class_name FondCalque
extends Node2D
## Le fond d'une ambiance dans une salle : une grande image en parallaxe (« fond ») ou des modules
## répétés (« fond_modules »), plus sa brume (« voile », couleur « brume » de la palette).
## L'ambiance du dehors couvre toute la salle ; une ambiance d'intérieur se pose par-dessus,
## découpée par son masque (voir RoomArt._build_fonds), avec un contour d'encre à son bord.
## « flou » : flou de profondeur (niveau de mipmap), pour les plans lointains.

var room: Room
var conf := {}
var dir := ""
var _bg: Sprite2D
var _mods: Node2D
var _haze: ColorRect
var _mask: Texture2D
var _shader: Shader
var _interieur := false


func setup(r: Room, zone_dir: String, amb: Dictionary, mask: Texture2D, interieur := false) -> void:
	room = r
	dir = zone_dir
	conf = amb
	_mask = mask
	_interieur = interieur
	var zb := -26 if interieur else -30
	_shader = load("res://art/shaders/fond_ambiance.gdshader")
	if amb.has("fond"):
		_bg = Sprite2D.new()
		_bg.texture = load(dir + amb.fond)
		_bg.centered = false
		_bg.region_enabled = true
		_bg.z_index = zb
		_bg.material = _mat()
		add_child(_bg)
	if amb.has("fond_modules"):
		_build_modules(amb.fond_modules)
	var pal: Dictionary = amb.get("palette", {})
	_haze = ColorRect.new()
	_haze.size = room.size
	_haze.color = Color(pal.get("brume", "000000"))
	_haze.color.a = amb.get("voile", 0.3)
	_haze.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_haze.z_index = zb + 1
	var hm := _mat()
	hm.set_shader_parameter("unie", true)
	_haze.material = hm
	add_child(_haze)


func _mat(fondu := 0.0, fondu_x := 0.0, vertical := true) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = _shader
	m.set_shader_parameter("fondu", fondu)
	m.set_shader_parameter("fondu_x", fondu_x)
	m.set_shader_parameter("vertical", vertical)
	m.set_shader_parameter("use_mask", _mask != null)
	m.set_shader_parameter("interieur", _interieur)
	m.set_shader_parameter("flou", float(conf.get("flou", 0.0)))
	var pal: Dictionary = conf.get("palette", {})
	m.set_shader_parameter("c_encre", Color(pal.get("encre", "1d1420")))
	m.set_shader_parameter("c_lumiere", Color(pal.get("lumiere", "f2a866")))
	if _mask:
		m.set_shader_parameter("mask", _mask)
		m.set_shader_parameter("room_rect", Vector4(room.global_position.x, room.global_position.y, room.size.x, room.size.y))
	return m


## Fond fait de modules : un morceau de décor à la bonne échelle, qui se raccorde à lui-même
## dans l'axe de la salle (vertical pour un puits, horizontal pour une galerie). La taille d'un
## module est fixée en pixels du monde : c'est elle qui règle l'échelle du fond par rapport à
## Wendel, quelle que soit la taille de la salle. Grille de colonnes décalées entre variantes.
func _build_modules(m: Dictionary) -> void:
	_mods = Node2D.new()
	_mods.z_index = -26 if _interieur else -30
	add_child(_mods)
	var vertical: bool = m.get("axe", "vertical") == "vertical"
	var base: Array = m.get("base", [])
	if base.is_empty():
		return
	var texs: Array[Texture2D] = []
	for b in base:
		texs.append(load(dir + b))
	var f: float = conf.get("parallaxe", 0.15)
	# Largeur couverte en travers (hauteur si horizontal) : le fond défile aussi dans cet axe, à la
	# même fraction f que dans l'autre ; il doit donc couvrir la salle entière vue à travers f.
	var cross := maxf(float(m.get("largeur", 1280.0)),
			(room.size.x if vertical else room.size.y) * f + (1280.0 if vertical else 720.0) * 1.5)
	# taille d'un module en travers. « taille_m » : ce que le module mesure en vrai, en mètres ;
	# vu derrière le plan du jeu, il paraît réduit dans le rapport de la parallaxe (plus loin =
	# défile moins vite = paraît plus petit). Sinon « taille » en pixels du monde (ancien réglage).
	var side: float = m.get("taille", cross)
	if m.has("taille_m"):
		side = float(m.taille_m) * Room.TILE * f
	var length := (room.size.y if vertical else room.size.x) * f + (720.0 if vertical else 1280.0) * 1.5
	var fondu: float = m.get("fondu", 0.15) if texs.size() > 1 else 0.0
	var cols := int(ceil(cross / (side * (1.0 - fondu)))) if m.has("taille") or m.has("taille_m") else 1
	for c in cols:
		var pos := -side * 2.0 * fmod(c * 0.37, 1.0) if c > 0 else 0.0
		var i := c * 2 + 1 if c > 0 else 0
		var first_row := true
		while pos < length:
			var t: Texture2D = texs[(i * 7 + (i / texs.size()) * 3) % texs.size()]
			i += 1
			var sp := Sprite2D.new()
			sp.texture = t
			sp.centered = false
			var k := side / (t.get_width() if vertical else t.get_height())
			sp.scale = Vector2(k, k)
			var step := t.get_height() * k if vertical else t.get_width() * k
			var cross_pos := c * side * (1.0 - fondu)
			if not first_row:
				pos -= step * fondu
			sp.material = _mat(0.0 if first_row else fondu, 0.0 if c == 0 else fondu, vertical)
			sp.position = Vector2(cross_pos, pos) if vertical else Vector2(pos, cross_pos)
			_mods.add_child(sp)
			pos += step
			first_row = false


func _process(_delta: float) -> void:
	if not is_visible_in_tree():
		return
	var cam := get_viewport().get_camera_2d()
	if cam == null:
		return
	var view := get_viewport_rect().size / cam.zoom
	var tl := cam.get_screen_center_position() - view * 0.5 - room.global_position
	var f: float = conf.get("parallaxe", 0.15)
	var night := World.night_amount()
	var tint := Color(1, 1, 1).lerp(Color(0.55, 0.6, 0.8), night)
	if _mods:
		# Les modules défilent à la fraction f de la caméra, dans les deux axes (avant, ils étaient
		# collés à la caméra en travers : en sautant, le fond d'une maison montait avec Wendel).
		_mods.position = tl * (1.0 - f)
		_mods.modulate = tint
	if _bg:
		# Le fond couvre la vue et défile au moins d'une fraction f du déplacement de la caméra.
		# S'il est plus grand que nécessaire, il défile juste assez pour qu'on en voie les bords.
		var travel := (room.size - view).max(Vector2.ZERO)
		var need := view + travel * f
		var tex := _bg.texture.get_size()
		var k := maxf(need.y / tex.y, need.x / tex.x)
		var shown := tex * k
		var fx := clampf((shown.x - view.x) / travel.x, 0.0, 1.0) if travel.x > 0.0 else 0.0
		var fy := clampf((shown.y - view.y) / travel.y, 0.0, 1.0) if travel.y > 0.0 else 0.0
		_bg.scale = Vector2(k, k)
		_bg.region_rect = Rect2(Vector2.ZERO, tex)
		_bg.position = tl - Vector2(tl.x * fx, tl.y * fy)
		_bg.modulate = tint
